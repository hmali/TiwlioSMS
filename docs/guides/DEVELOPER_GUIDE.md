# TwilioSMS Developer Guide

## 📚 For New Developers

This guide explains the TwilioSMS application architecture, code structure, and key concepts.

---

## 🎯 What Does This Application Do?

**TwilioSMS** is a web-based SMS campaign management system that allows users to:
1. Send bulk SMS messages to thousands of phone numbers
2. Automatically reply to incoming SMS messages
3. Track campaign progress and message delivery status
4. Manage user authentication and Twilio credentials
5. View logs of all inbound messages

---

## 🏗️ Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Browser   │ ───► │  Flask App   │ ───► │   SQLite    │
│  (Client)   │ ◄─── │  (Server)    │ ◄─── │  Database   │
└─────────────┘      └──────────────┘      └─────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  Twilio API  │
                     │ (SMS Service)│
                     └──────────────┘
```

**Technology Stack:**
- **Backend:** Flask (Python web framework)
- **Database:** SQLite (file-based SQL database)
- **SMS Provider:** Twilio (cloud communications platform)
- **Frontend:** HTML, CSS, JavaScript (Jinja2 templates)
- **Server:** Gunicorn (production WSGI server)

---

## 📁 File Structure Explained

### Core Application Files

**`app.py`** (Main application - 724 lines)
- Contains all Flask routes and business logic
- Database operations
- Twilio integration
- Authentication system

**`gunicorn_config.py`**
- Production server configuration
- Worker processes, binding, logging

**`requirements.txt`**
- Python package dependencies
- Flask, Twilio, Gunicorn, etc.

### Database File

**`twilio_sms.db`**
- SQLite database storing all data
- Tables: users, campaigns, messages, settings

### Templates (HTML)

Located in `templates/` directory:
- `base.html` - Master template (all pages extend this)
- `login.html` - Login page
- `dashboard.html` - Main dashboard
- `send_sms.html` - Campaign creation form
- `campaign_status.html` - Campaign progress tracking
- `settings.html` - Twilio credentials
- `settings_auto_reply.html` - Auto-reply configuration
- `inbound_messages.html` - Received messages log

### Static Assets

Located in `static/` directory:
- `css/style.css` - Application styling
- `js/app.js` - Client-side JavaScript
- `images/` - Logo and images

---

## 🔍 Code Walkthrough

### 1. **Application Setup (Lines 1-42)**

```python
#!/usr/bin/env python3
"""Application docstring"""

# IMPORTS
import os                    # Operating system operations
import csv                   # CSV file parsing
import sqlite3               # Database operations
import logging               # Error and info logging
from flask import Flask      # Web framework
from twilio.rest import Client  # Twilio SMS API

# LOGGING CONFIGURATION
logging.basicConfig(
    level=logging.INFO,      # Log INFO level and above
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('twilio_sms.log'),  # Write to file
        logging.StreamHandler()                  # Print to console
    ]
)
logger = logging.getLogger(__name__)

# FLASK APP INITIALIZATION
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'default-key')  # Session encryption
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024          # 16MB max upload
app.config['UPLOAD_FOLDER'] = 'uploads'                       # Upload directory

# Create upload directory if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
```

**Key Concepts:**
- **Logging:** Records application events for debugging
- **Flask App:** Web server instance that handles HTTP requests
- **Configuration:** Settings loaded from environment or defaults

---

### 2. **Auto-Reply Functions (Lines 44-95)**

#### `get_auto_reply_message()` - Retrieve Message

```python
def get_auto_reply_message():
    """Get auto-reply message from database"""
    try:
        # Connect to database
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        
        # Query the settings table
        cursor.execute("SELECT setting_value FROM settings WHERE setting_key = 'auto_reply_message'")
        result = cursor.fetchone()  # Get first result
        conn.close()
        
        if result:
            return result[0]  # Return the message text
        else:
            # Fallback to default if not in database
            return os.getenv("AUTO_REPLY_MESSAGE", "Default message...")
    except Exception as e:
        logger.error(f"Error getting auto-reply message: {str(e)}")
        return "Thank you for your message..."  # Safe fallback
```

**What This Does:**
1. Opens database connection
2. Queries `settings` table for auto-reply message
3. Returns message if found, otherwise returns default
4. Handles errors gracefully with fallback

---

#### `set_auto_reply_message()` - Save Message

```python
def set_auto_reply_message(message):
    """Set auto-reply message in database"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        
        # Check if setting already exists
        cursor.execute("SELECT id FROM settings WHERE setting_key = 'auto_reply_message'")
        exists = cursor.fetchone()
        
        if exists:
            # UPDATE existing record (preserves ID, updates timestamp)
            cursor.execute('''
                UPDATE settings 
                SET setting_value = ?, updated_at = CURRENT_TIMESTAMP 
                WHERE setting_key = 'auto_reply_message'
            ''', (message,))
        else:
            # INSERT new record
            cursor.execute('''
                INSERT INTO settings (setting_key, setting_value, updated_at)
                VALUES ('auto_reply_message', ?, CURRENT_TIMESTAMP)
            ''', (message,))
        
        conn.commit()  # Save changes
        conn.close()
        logger.info(f"Auto-reply message updated successfully: {len(message)} characters")
        return True
    except Exception as e:
        logger.error(f"Error setting auto-reply message: {str(e)}")
        return False  # Indicate failure
```

**Why Explicit UPDATE/INSERT?**

❌ **Old Approach (Problematic):**
```python
# INSERT OR REPLACE - can cause issues with AUTOINCREMENT
cursor.execute('''
    INSERT OR REPLACE INTO settings (setting_key, setting_value, updated_at)
    VALUES ('auto_reply_message', ?, CURRENT_TIMESTAMP)
''', (message,))
```

✅ **New Approach (Production-Ready):**
- **Check if exists first**
- **UPDATE** preserves the record ID and properly updates timestamp
- **INSERT** only if new record needed
- **Better error handling** with detailed logging

---

### 3. **Database Initialization (Lines 96-211)**

```python
def init_db():
    """Initialize SQLite database"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    # Create tables if they don't exist
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            twilio_sid TEXT,
            twilio_token TEXT,
            is_default_password BOOLEAN DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # ... more tables ...
    
    conn.commit()
    conn.close()
```

**Database Schema:**

**1. `users` Table**
```
┌────┬──────────┬───────────────┬─────────────┬───────────────┬──────────────────────┬────────────┐
│ id │ username │ password_hash │ twilio_sid  │ twilio_token  │ is_default_password │ created_at │
├────┼──────────┼───────────────┼─────────────┼───────────────┼──────────────────────┼────────────┤
│ 1  │ admin    │ hashed_pwd... │ AC1234...   │ token123...   │ 1 (yes)              │ 2026-01-24 │
└────┴──────────┴───────────────┴─────────────┴───────────────┴──────────────────────┴────────────┘
```
Stores user accounts and their Twilio credentials

**2. `campaigns` Table**
```
┌────┬─────────┬──────────────┬──────────────┬──────────────┬───────────────────┬────────────────┬────────┬────────────┬──────────────┐
│ id │ user_id │ name         │ message_body │ total_numbers│ successful_sends  │ failed_sends   │ status │ created_at │ completed_at │
├────┼─────────┼──────────────┼──────────────┼──────────────┼───────────────────┼────────────────┼────────┼────────────┼──────────────┤
│ 1  │ 1       │ New Year SMS │ Happy 2026!  │ 1000         │ 995               │ 5              │ done   │ 2026-01-24 │ 2026-01-24   │
└────┴─────────┴──────────────┴──────────────┴──────────────┴───────────────────┴────────────────┴────────┴────────────┴──────────────┘
```
Tracks each SMS campaign

**3. `message_status` Table**
```
┌────┬─────────────┬──────────────┬─────────────┬────────┬───────────────┬──────────┐
│ id │ campaign_id │ phone_number │ message_sid │ status │ error_message │ sent_at  │
├────┼─────────────┼──────────────┼─────────────┼────────┼───────────────┼──────────┤
│ 1  │ 1           │ +1234567890  │ SM123...    │ sent   │ NULL          │ 10:15:30 │
│ 2  │ 1           │ +0987654321  │ SM124...    │ failed │ Invalid number│ 10:15:31 │
└────┴─────────────┴──────────────┴─────────────┴────────┴───────────────┴──────────┘
```
Individual message delivery status

**4. `inbound_messages` Table**
```
┌────┬──────────────┬──────────────┬──────────────┬─────────────┬────────────┬─────────────┐
│ id │ from_number  │ to_number    │ message_body │ message_sid │ reply_sent │ received_at │
├────┼──────────────┼──────────────┼──────────────┼─────────────┼────────────┼─────────────┤
│ 1  │ +1234567890  │ +1555000000  │ Hello!       │ SM125...    │ 1 (yes)    │ 11:30:00    │
└────┴──────────────┴──────────────┴──────────────┴─────────────┴────────────┴─────────────┘
```
Log of received messages and auto-replies

**5. `settings` Table**
```
┌────┬──────────────────────┬────────────────────────────────┬────────────┐
│ id │ setting_key          │ setting_value                  │ updated_at │
├────┼──────────────────────┼────────────────────────────────┼────────────┤
│ 1  │ auto_reply_message   │ Thank you for your message...  │ 2026-01-24 │
└────┴──────────────────────┴────────────────────────────────┴────────────┘
```
Application configuration

---

### 4. **Authentication System**

#### Login Decorator (Lines 213-220)

```python
def login_required(f):
    """Decorator to require login for protected routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))  # Redirect to login
        return f(*args, **kwargs)  # Allow access
    return decorated_function
```

**How It Works:**
```python
@app.route('/dashboard')
@login_required  # ← This decorator checks if user is logged in
def dashboard():
    # Only runs if user is authenticated
    return render_template('dashboard.html')
```

If user is NOT logged in → redirects to login page  
If user IS logged in → allows access to route

---

#### Password Security

```python
# STORING PASSWORD (Registration/Change)
from werkzeug.security import generate_password_hash
password_hash = generate_password_hash('mypassword123')
# Stores: 'pbkdf2:sha256:600000$xyz...' (hashed, not plain text!)

# VERIFYING PASSWORD (Login)
from werkzeug.security import check_password_hash
if check_password_hash(stored_hash, entered_password):
    # Password correct!
```

**Why Hash Passwords?**
- ❌ **Never store plain text:** `password = 'admin123'` ← DANGEROUS!
- ✅ **Store hashed:** `password_hash = 'pbkdf2:sha256:...'` ← SECURE!
- Even if database is stolen, passwords are unreadable

---

### 5. **Flask Routes Explained**

Flask uses decorators to map URLs to functions:

```python
@app.route('/dashboard')
@login_required
def dashboard():
    """User dashboard"""
    # This function runs when user visits: http://your-site.com/dashboard
    
    # Get data from database
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM campaigns WHERE user_id = ?', (session['user_id'],))
    campaigns = cursor.fetchall()
    conn.close()
    
    # Render HTML template with data
    return render_template('dashboard.html', campaigns=campaigns)
```

**Request Flow:**
```
1. User visits: http://localhost:5000/dashboard
2. Flask finds route: @app.route('/dashboard')
3. Checks @login_required decorator
4. If logged in → runs dashboard() function
5. Function queries database
6. Renders HTML template with data
7. Returns HTML to browser
```

---

### 6. **Bulk SMS Sending (Lines 493-608)**

#### Upload and Parse Phone Numbers

```python
@app.route('/send_sms', methods=['GET', 'POST'])
@login_required
def send_sms():
    if request.method == 'POST':
        # Get form data
        campaign_name = request.form['campaign_name']
        message_body = request.form['message_body']
        from_number = request.form['from_number']
        
        # Get uploaded file
        file = request.files['phone_file']
        
        # Save file temporarily
        filename = secure_filename(file.filename)
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(file_path)
        
        # Parse phone numbers from file
        phone_numbers = parse_phone_numbers(file_path)
        
        # Start sending in background thread
        thread = Thread(target=send_bulk_sms_async, args=(...))
        thread.start()
```

#### Background SMS Sending

```python
def send_bulk_sms_async(campaign_id, phone_numbers, message_body, twilio_client, from_number):
    """Send SMS in background (doesn't block web interface)"""
    
    for phone_number in phone_numbers:
        try:
            # Call Twilio API to send SMS
            message = twilio_client.messages.create(
                from_=from_number,      # Your Twilio number
                body=message_body,      # Message text
                to=phone_number         # Recipient
            )
            
            # Log success
            logger.info(f"SMS sent to {phone_number}: {message.sid}")
            
            # Wait 1 second (avoid rate limiting)
            time.sleep(1)
            
        except TwilioException as e:
            # Log failure
            logger.error(f"Failed to send to {phone_number}: {str(e)}")
```

**Why Threading?**
- Sending 1000 SMS takes 1000+ seconds (16+ minutes!)
- Without threading: User waits, browser times out ❌
- With threading: User sees confirmation immediately, SMS sends in background ✅

---

### 7. **Auto-Reply Webhook (Lines 644-683)**

```python
@app.route('/sms/inbound', methods=['POST'])
def sms_inbound():
    """Twilio webhook for inbound SMS"""
    
    # Twilio sends data as POST request
    from_number = request.form.get("From")      # Sender's phone
    to_number = request.form.get("To")          # Your Twilio number
    body = request.form.get("Body")             # Message text
    msg_sid = request.form.get("MessageSid")    # Unique ID
    
    # Log the message
    logger.info(f"Inbound SMS from {from_number}: {body}")
    
    # Store in database
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO inbound_messages (from_number, to_number, message_body, message_sid, reply_sent)
        VALUES (?, ?, ?, ?, 1)
    ''', (from_number, to_number, body, msg_sid))
    conn.commit()
    conn.close()
    
    # Create auto-reply
    resp = MessagingResponse()
    resp.message(get_auto_reply_message())  # Get message from database
    
    # Return TwiML (Twilio Markup Language) response
    return Response(str(resp), mimetype="text/xml")
```

**How Webhooks Work:**

```
┌──────────┐         ┌──────────┐         ┌──────────────┐
│  Person  │  ────►  │  Twilio  │  ────►  │  Your Flask  │
│  Sends   │  (SMS)  │  Server  │ (HTTP)  │  Application │
│   SMS    │         │          │  POST   │              │
└──────────┘         └──────────┘         └──────────────┘
                           │                      │
                           │  ◄───────────────────┘
                           │    (TwiML Response)
                           ▼
                     ┌──────────┐
                     │  Person  │
                     │ Receives │
                     │  Reply   │
                     └──────────┘
```

1. Person sends SMS to your Twilio number
2. Twilio receives SMS
3. Twilio makes HTTP POST to your webhook URL
4. Your Flask app responds with TwiML
5. Twilio sends auto-reply SMS

---

## 🔐 Security Features

### 1. **Password Hashing**
```python
# Never stored as plain text
password_hash = generate_password_hash('password123')
```

### 2. **Session-Based Authentication**
```python
# After login, user_id stored in encrypted session cookie
session['user_id'] = user[0]
session['username'] = username
```

### 3. **SQL Injection Prevention**
```python
# ❌ DANGEROUS (SQL injection vulnerable)
cursor.execute(f"SELECT * FROM users WHERE username = '{username}'")

# ✅ SAFE (parameterized query)
cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
```

### 4. **Secure File Uploads**
```python
# Sanitize filename to prevent directory traversal attacks
from werkzeug.utils import secure_filename
filename = secure_filename(file.filename)  # '../../etc/passwd' → 'etc_passwd'
```

---

## 🎨 Frontend (Templates)

### Jinja2 Template Engine

**base.html** (Master Template):
```html
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}TwilioSMS{% endblock %}</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body>
    {% block content %}{% endblock %}
</body>
</html>
```

**dashboard.html** (Child Template):
```html
{% extends "base.html" %}

{% block title %}Dashboard - TwilioSMS{% endblock %}

{% block content %}
<h1>Dashboard</h1>

{% for campaign in campaigns %}
    <div class="campaign">
        <h3>{{ campaign[1] }}</h3>  <!-- campaign name -->
        <p>Status: {{ campaign[5] }}</p>  <!-- campaign status -->
    </div>
{% endfor %}
{% endblock %}
```

**Variables in Templates:**
- `{{ variable }}` - Output variable
- `{% for item in list %}` - Loop
- `{% if condition %}` - Conditional
- `{{ url_for('route_name') }}` - Generate URL

---

## 📊 Data Flow Example

### Sending an SMS Campaign:

```
1. USER ACTION
   └─► User fills form on /send_sms
       • Campaign name: "Holiday Sale"
       • Message: "50% off today!"
       • Uploads: phones.csv (1000 numbers)

2. FLASK RECEIVES REQUEST
   └─► POST /send_sms
       • Validates file upload
       • Parses CSV file
       • Creates campaign in database

3. DATABASE INSERT
   └─► INSERT INTO campaigns
       • id: 5
       • user_id: 1
       • name: "Holiday Sale"
       • total_numbers: 1000
       • status: "pending"

4. BACKGROUND THREAD STARTS
   └─► send_bulk_sms_async()
       • Loops through 1000 numbers
       • Calls Twilio API for each
       • Updates database after each send

5. TWILIO API CALLS
   └─► For each number:
       • POST to api.twilio.com/Messages
       • Returns message SID
       • Logs success/failure

6. DATABASE UPDATES
   └─► INSERT INTO message_status
       • phone_number: +1234567890
       • message_sid: SM1234...
       • status: "sent"
       
   └─► UPDATE campaigns
       • successful_sends: 995
       • failed_sends: 5
       • status: "completed"

7. USER SEES RESULTS
   └─► GET /campaign/5
       • Displays campaign status
       • Shows delivery statistics
       • Lists failed numbers
```

---

## 🛠️ Development Workflow

### Running Locally:

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run application
python app.py

# 3. Access in browser
http://localhost:5000

# 4. Login
Username: admin
Password: admin123
```

### Checking Logs:

```bash
# Application logs
tail -f twilio_sms.log

# See what's happening in real-time
```

### Database Queries:

```bash
# Open database
sqlite3 twilio_sms.db

# View tables
.tables

# Query data
SELECT * FROM campaigns;
SELECT * FROM users;

# Exit
.quit
```

---

## 🚀 Production Deployment

### Using Gunicorn:

```bash
# Start production server
gunicorn -c gunicorn_config.py app:app

# Runs with:
# - 4 worker processes
# - Binds to 0.0.0.0:8000
# - Access logs enabled
```

### Systemd Service:

```ini
[Unit]
Description=Twilio SMS Application

[Service]
WorkingDirectory=/home/user/TiwlioSMS
ExecStart=/home/user/TiwlioSMS/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## 🧪 Testing Tips

### Test Auto-Reply:

```python
# 1. Set auto-reply message in web UI
# 2. Send SMS to your Twilio number
# 3. Check logs:
tail -f twilio_sms.log | grep "Inbound SMS"

# 4. Verify database:
sqlite3 twilio_sms.db "SELECT * FROM inbound_messages ORDER BY received_at DESC LIMIT 5;"
```

### Test Campaign:

```python
# 1. Create test CSV with 2-3 numbers
# 2. Send campaign
# 3. Monitor logs
# 4. Check campaign status page
# 5. Verify in database:
sqlite3 twilio_sms.db "SELECT * FROM campaigns ORDER BY created_at DESC LIMIT 1;"
```

---

## 📝 Common Issues & Solutions

### 1. **Auto-reply not working**
```bash
# Check webhook configuration in Twilio Console
# URL should be: http://your-domain.com/sms/inbound
# Method: POST

# Check logs
tail -f twilio_sms.log | grep "Inbound"
```

### 2. **Database locked**
```python
# Too many simultaneous connections
# Solution: Close connections properly
conn.close()  # Always close!
```

### 3. **Session data not persisting**
```python
# Check SECRET_KEY is set
app.secret_key = os.environ.get('SECRET_KEY', 'change-me')
```

---

## 🎓 Key Learning Points

### For Junior Developers:

1. **Flask Basics**
   - Routes map URLs to functions
   - Templates render HTML with data
   - Sessions store user state

2. **Database Operations**
   - Always use parameterized queries (prevent SQL injection)
   - Close connections after use
   - Use transactions (commit/rollback)

3. **Security**
   - Hash passwords (never plain text!)
   - Validate user input
   - Use HTTPS in production

4. **API Integration**
   - Twilio API sends SMS
   - Webhooks receive inbound messages
   - Handle errors gracefully

5. **Asynchronous Processing**
   - Threading for long-running tasks
   - Prevents blocking the web interface
   - Monitor with logging

---

## 📚 Resources

- **Flask Documentation:** https://flask.palletsprojects.com/
- **Twilio Python SDK:** https://www.twilio.com/docs/libraries/python
- **SQLite Tutorial:** https://www.sqlitetutorial.net/
- **Python Threading:** https://docs.python.org/3/library/threading.html

---

## 🤝 Contributing

When making changes:
1. Understand the existing code first
2. Test locally before deploying
3. Check logs for errors
4. Update documentation
5. Follow existing code style

---

**Questions?** Check the main README.md or review the DEPLOYMENT.md guide!

**Happy coding! 🚀**
