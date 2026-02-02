# TwilioSMS Application Architecture

## 🏗️ System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          CLIENT (Web Browser)                           │
│                                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐│
│  │  Login   │  │Dashboard │  │ Send SMS │  │ Settings │  │  Inbox   ││
│  │   Page   │  │   Page   │  │   Page   │  │   Page   │  │   Page   ││
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘│
│                                                                         │
│                          (HTML/CSS/JavaScript)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ HTTP Requests/Responses
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     WEB SERVER (Gunicorn + Flask)                       │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                       Flask Application (app.py)                 │  │
│  │                                                                  │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌───────────┐│  │
│  │  │   Routes   │  │   Auth     │  │  Business  │  │  Twilio   ││  │
│  │  │  Handlers  │  │   System   │  │   Logic    │  │  Client   ││  │
│  │  └────────────┘  └────────────┘  └────────────┘  └───────────┘│  │
│  │                                                                  │  │
│  │  /login → login()                                               │  │
│  │  /dashboard → dashboard()                                       │  │
│  │  /send_sms → send_sms()                                         │  │
│  │  /sms/inbound → sms_inbound() [Webhook]                         │  │
│  │  /settings/auto-reply → settings_auto_reply()                   │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                    │                              │
                    │ Database Queries             │ API Calls
                    ▼                              ▼
    ┌───────────────────────────┐    ┌──────────────────────────┐
    │   SQLite Database         │    │    Twilio Cloud API       │
    │   (twilio_sms.db)         │    │   (api.twilio.com)        │
    │                           │    │                           │
    │  ┌─────────────────────┐ │    │  • Send SMS               │
    │  │ Tables:             │ │    │  • Receive SMS            │
    │  │ • users             │ │    │  • Message Status         │
    │  │ • campaigns         │ │    │  • Webhooks               │
    │  │ • message_status    │ │    │                           │
    │  │ • inbound_messages  │ │    └──────────────────────────┘
    │  │ • settings          │ │
    │  └─────────────────────┘ │
    └───────────────────────────┘
```

---

## 🔄 Data Flow Diagrams

### 1. User Login Flow

```
┌──────┐
│ User │
└──┬───┘
   │
   │ 1. Navigate to /login
   ▼
┌────────────────┐
│ Flask: login() │
└───────┬────────┘
        │
        │ 2. Display login.html
        ▼
   ┌─────────┐
   │ Browser │ ← User enters username/password
   └────┬────┘
        │
        │ 3. POST username/password
        ▼
┌────────────────┐
│ Flask: login() │
└───────┬────────┘
        │
        │ 4. Query database
        ▼
   ┌──────────┐
   │ Database │
   └─────┬────┘
        │
        │ 5. Return user record
        ▼
┌────────────────────┐
│ check_password_hash│ ← Verify password
└────────┬───────────┘
         │
         │ 6. Password correct?
         ▼
    ┌─────────┐
    │ Session │ ← Store user_id
    └────┬────┘
         │
         │ 7. Redirect to /dashboard
         ▼
    ┌───────────┐
    │ Dashboard │
    └───────────┘
```

---

### 2. Send SMS Campaign Flow

```
┌──────┐
│ User │ Uploads CSV file with 1000 phone numbers
└──┬───┘
   │
   │ 1. POST /send_sms with form data
   ▼
┌─────────────────┐
│ Flask:          │
│ send_sms()      │
└───────┬─────────┘
        │
        │ 2. Save uploaded file
        ▼
   ┌────────────────┐
   │ parse_phone_   │ ← Extract phone numbers from CSV
   │ numbers()      │
   └────┬───────────┘
        │
        │ 3. Create campaign record
        ▼
   ┌──────────┐
   │ Database │ ← INSERT INTO campaigns
   └─────┬────┘
        │
        │ 4. Get campaign_id
        ▼
┌─────────────────────┐
│ Start Background    │
│ Thread              │
└──────┬──────────────┘
       │
       │ 5. Return immediately to user
       │    (User sees "Campaign started!")
       │
       ├─► Main Thread: Show success page
       │
       └─► Background Thread:
           │
           │ For each phone number (1000 times):
           ▼
       ┌─────────────────┐
       │ Twilio API Call │ ← Send SMS
       └────┬────────────┘
            │
            │ Success/Failure
            ▼
       ┌──────────┐
       │ Database │ ← INSERT INTO message_status
       └──────────┘
            │
            │ Sleep 1 second (rate limiting)
            │
            └─► Next number...
```

---

### 3. Auto-Reply Webhook Flow

```
┌─────────────┐
│ Person sends│
│ SMS to your │
│ Twilio #    │
└──────┬──────┘
       │
       ▼
┌────────────────┐
│ Twilio Server  │ ← Receives SMS
└───────┬────────┘
        │
        │ POST to your webhook
        │ http://your-site.com/sms/inbound
        │
        │ POST Data:
        │ • From: +1234567890
        │ • To: +1555000000
        │ • Body: "Hello!"
        │ • MessageSid: SM123...
        ▼
┌─────────────────────┐
│ Flask:              │
│ sms_inbound()       │
└──────┬──────────────┘
       │
       │ 1. Extract POST data
       │
       │ 2. Log inbound message
       ▼
  ┌──────────┐
  │ Database │ ← INSERT INTO inbound_messages
  └─────┬────┘
        │
        │ 3. Get auto-reply message
        ▼
  ┌──────────────────┐
  │ get_auto_reply_  │ ← Query settings table
  │ message()        │
  └────┬─────────────┘
       │
       │ 4. Create TwiML response
       ▼
  ┌──────────────────┐
  │ <Response>       │
  │   <Message>      │
  │   Thank you...   │
  │   </Message>     │
  │ </Response>      │
  └────┬─────────────┘
       │
       │ 5. Return TwiML to Twilio
       ▼
┌────────────────┐
│ Twilio Server  │ ← Sends reply SMS
└───────┬────────┘
        │
        ▼
   ┌─────────┐
   │ Person  │ ← Receives auto-reply
   │ receives│
   │ reply   │
   └─────────┘
```

---

## 🗄️ Database Schema

### Entity Relationship Diagram

```
┌─────────────────────────────┐
│          USERS              │
├─────────────────────────────┤
│ PK id                       │
│    username (UNIQUE)        │
│    password_hash            │
│    twilio_sid               │
│    twilio_token             │
│    is_default_password      │
│    created_at               │
└──────────┬──────────────────┘
           │
           │ 1:N (one user has many campaigns)
           │
           ▼
┌─────────────────────────────┐
│       CAMPAIGNS             │
├─────────────────────────────┤
│ PK id                       │
│ FK user_id ─────────────────┼─┐
│    name                     │ │
│    message_body             │ │
│    total_numbers            │ │
│    successful_sends         │ │
│    failed_sends             │ │
│    status                   │ │
│    created_at               │ │
│    completed_at             │ │
└──────────┬──────────────────┘ │
           │                    │
           │ 1:N                │
           │                    │
           ▼                    │
┌─────────────────────────────┐ │
│    MESSAGE_STATUS           │ │
├─────────────────────────────┤ │
│ PK id                       │ │
│ FK campaign_id ─────────────┼─┘
│    phone_number             │
│    message_sid              │
│    status (sent/failed)     │
│    error_message            │
│    sent_at                  │
└─────────────────────────────┘


┌─────────────────────────────┐
│    INBOUND_MESSAGES         │
├─────────────────────────────┤
│ PK id                       │
│    from_number              │
│    to_number                │
│    message_body             │
│    message_sid              │
│    reply_sent (0/1)         │
│    received_at              │
└─────────────────────────────┘


┌─────────────────────────────┐
│        SETTINGS             │
├─────────────────────────────┤
│ PK id                       │
│    setting_key (UNIQUE)     │
│    setting_value            │
│    updated_at               │
└─────────────────────────────┘
```

---

## 🔐 Security Architecture

### 1. Authentication Flow

```
┌────────────┐
│   Login    │
└─────┬──────┘
      │
      │ 1. User submits username/password
      ▼
┌────────────────────┐
│ Password Hashing   │
│ (Werkzeug)         │
└─────┬──────────────┘
      │
      │ 2. Hash comparison
      │    Stored: pbkdf2:sha256:...
      │    Entered: converted to hash
      ▼
┌────────────────────┐
│ Session Created    │
│ session['user_id'] │
└─────┬──────────────┘
      │
      │ 3. Encrypted session cookie
      │    stored in browser
      ▼
┌────────────────────┐
│ Protected Routes   │
│ @login_required    │
└─────┬──────────────┘
      │
      │ 4. Each request checks session
      ▼
┌────────────────────┐
│ Allow/Deny Access  │
└────────────────────┘
```

### 2. SQL Injection Prevention

```
❌ VULNERABLE CODE:
cursor.execute(f"SELECT * FROM users WHERE username = '{username}'")

If username = "admin' OR '1'='1"
Query becomes: SELECT * FROM users WHERE username = 'admin' OR '1'='1'
Result: Returns ALL users! (Security breach)

✅ SECURE CODE:
cursor.execute("SELECT * FROM users WHERE username = ?", (username,))

If username = "admin' OR '1'='1"
Query treats it as literal string: WHERE username = "admin' OR '1'='1"
Result: No match, safe!
```

---

## 📦 Component Architecture

### Flask Application Structure

```
app.py (Main Application)
│
├─► Configuration
│   ├─ Secret Key
│   ├─ Upload Folder
│   ├─ Max File Size
│   └─ Logging Setup
│
├─► Database Layer
│   ├─ init_db()
│   ├─ Connection Management
│   └─ Schema Creation
│
├─► Authentication
│   ├─ login_required decorator
│   ├─ Password hashing
│   └─ Session management
│
├─► Business Logic
│   ├─ get_auto_reply_message()
│   ├─ set_auto_reply_message()
│   ├─ parse_phone_numbers()
│   ├─ send_bulk_sms_async()
│   └─ get_user_twilio_client()
│
├─► HTTP Routes
│   ├─ / → index()
│   ├─ /login → login()
│   ├─ /dashboard → dashboard()
│   ├─ /send_sms → send_sms()
│   ├─ /campaign/<id> → campaign_status()
│   ├─ /settings → settings()
│   ├─ /settings/auto-reply → settings_auto_reply()
│   ├─ /sms/inbound → sms_inbound() [Webhook]
│   └─ /inbound-messages → inbound_messages()
│
└─► Template Rendering
    ├─ Jinja2 Templates
    ├─ Static Assets (CSS/JS)
    └─ Flash Messages
```

---

## 🔄 Request/Response Cycle

### Example: Viewing Dashboard

```
1. CLIENT REQUEST
   ┌─────────────────────────────────────┐
   │ GET /dashboard                      │
   │ Cookie: session=encrypted_data...   │
   └─────────────────────────────────────┘
                    │
                    ▼
2. FLASK ROUTING
   ┌─────────────────────────────────────┐
   │ @app.route('/dashboard')            │
   │ @login_required                     │
   │ def dashboard():                    │
   └─────────────────────────────────────┘
                    │
                    ▼
3. AUTHENTICATION CHECK
   ┌─────────────────────────────────────┐
   │ if 'user_id' not in session:        │
   │     redirect('/login')              │
   │ else:                               │
   │     continue                        │
   └─────────────────────────────────────┘
                    │
                    ▼
4. DATABASE QUERY
   ┌─────────────────────────────────────┐
   │ SELECT * FROM campaigns             │
   │ WHERE user_id = ?                   │
   │ ORDER BY created_at DESC            │
   └─────────────────────────────────────┘
                    │
                    ▼
5. TEMPLATE RENDERING
   ┌─────────────────────────────────────┐
   │ render_template('dashboard.html',   │
   │   campaigns=campaigns,              │
   │   username=session['username']      │
   │ )                                   │
   └─────────────────────────────────────┘
                    │
                    ▼
6. HTML GENERATION
   ┌─────────────────────────────────────┐
   │ Jinja2 processes template:          │
   │ • Inserts campaign data             │
   │ • Generates table rows              │
   │ • Includes CSS/JS links             │
   └─────────────────────────────────────┘
                    │
                    ▼
7. HTTP RESPONSE
   ┌─────────────────────────────────────┐
   │ HTTP/1.1 200 OK                     │
   │ Content-Type: text/html             │
   │ Set-Cookie: session=...             │
   │                                     │
   │ <html>...rendered content...</html> │
   └─────────────────────────────────────┘
                    │
                    ▼
8. BROWSER DISPLAY
   ┌─────────────────────────────────────┐
   │ User sees dashboard with campaigns  │
   └─────────────────────────────────────┘
```

---

## 🧵 Threading Architecture

### Background SMS Sending

```
┌────────────────────────────────────────────────────────────┐
│                      MAIN THREAD                           │
│  (Handles web requests, remains responsive)                │
│                                                            │
│  User submits campaign → Returns immediately               │
│  "Campaign started!"                                       │
└──────────────┬─────────────────────────────────────────────┘
               │
               │ Spawns
               ▼
┌────────────────────────────────────────────────────────────┐
│                   BACKGROUND THREAD                        │
│  (Sends SMS, doesn't block web interface)                  │
│                                                            │
│  Loop: 1000 phone numbers                                  │
│    │                                                        │
│    ├─► Call Twilio API (send SMS)                         │
│    ├─► Wait for response                                   │
│    ├─► Log success/failure to database                     │
│    ├─► Sleep 1 second                                      │
│    └─► Next number...                                      │
│                                                            │
│  After all sent:                                           │
│    └─► UPDATE campaigns SET status='completed'            │
└────────────────────────────────────────────────────────────┘

Benefits:
• Web interface stays responsive
• User can navigate away
• Campaign runs to completion
• Progress tracked in database
```

---

## 📊 Performance Considerations

### Database Optimization

```python
# ❌ SLOW: Multiple queries
for campaign in campaigns:
    cursor.execute("SELECT COUNT(*) FROM message_status WHERE campaign_id = ?", (campaign.id,))

# ✅ FAST: Single query with JOIN
cursor.execute('''
    SELECT c.*, COUNT(m.id) as message_count
    FROM campaigns c
    LEFT JOIN message_status m ON m.campaign_id = c.id
    GROUP BY c.id
''')
```

### Rate Limiting

```python
# Twilio rate limits: ~1 message per second
for phone_number in phone_numbers:
    send_sms(phone_number)
    time.sleep(1)  # Prevent API throttling
```

---

## 🔍 Debugging Guide

### Log Levels

```python
logger.debug("Detailed debugging info")       # Development only
logger.info("General information")            # What we use
logger.warning("Something unusual happened")  # Potential issues
logger.error("Error occurred")                # Actual errors
logger.critical("System failure!")            # Severe issues
```

### Tracing a Request

```
1. Check access logs:
   tail -f twilio_sms.log

2. Find the request:
   INFO - Inbound SMS: From=+1234567890

3. Trace execution:
   INFO - Auto-reply message updated successfully

4. Check database:
   sqlite3 twilio_sms.db "SELECT * FROM inbound_messages WHERE from_number='+1234567890'"
```

---

This architecture document provides the big picture view of how all components work together!
