#!/usr/bin/env python3
"""
Twilio Bulk SMS Web Application
Production-ready Flask application for sending bulk SMS via Twilio
Includes auto-reply functionality for inbound SMS
"""

import os
import csv
import json
import logging
from datetime import datetime, timedelta
from functools import wraps
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
import sqlite3
from threading import Thread
import time

from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify, Response
from twilio.rest import Client
from twilio.base.exceptions import TwilioException
from twilio.twiml.messaging_response import MessagingResponse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('twilio_sms.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-change-in-production')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['UPLOAD_FOLDER'] = 'uploads'

# Ensure upload directory exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

def get_auto_reply_message():
    """Get auto-reply message from database"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        cursor.execute("SELECT setting_value FROM settings WHERE setting_key = 'auto_reply_message'")
        result = cursor.fetchone()
        conn.close()
        
        if result:
            return result[0]
        else:
            # Fallback to environment variable or default
            return os.getenv(
                "AUTO_REPLY_MESSAGE",
                "Jai Gajanan, Thank you for your message. Incoming messages on this number are not monitored. "
                "Please contact us if you need additional information."
            )
    except Exception as e:
        logger.error(f"Error getting auto-reply message: {str(e)}")
        # Fallback to default
        return "Thank you for your message. Incoming messages on this number are not monitored."

def set_auto_reply_message(message):
    """Set auto-reply message in database"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        
        # Check if setting exists
        cursor.execute("SELECT id FROM settings WHERE setting_key = 'auto_reply_message'")
        exists = cursor.fetchone()
        
        if exists:
            # Update existing record
            cursor.execute('''
                UPDATE settings 
                SET setting_value = ?, updated_at = CURRENT_TIMESTAMP 
                WHERE setting_key = 'auto_reply_message'
            ''', (message,))
        else:
            # Insert new record
            cursor.execute('''
                INSERT INTO settings (setting_key, setting_value, updated_at)
                VALUES ('auto_reply_message', ?, CURRENT_TIMESTAMP)
            ''', (message,))
        
        conn.commit()
        conn.close()
        logger.info(f"Auto-reply message updated successfully: {len(message)} characters")
        return True
    except Exception as e:
        logger.error(f"Error setting auto-reply message: {str(e)}")
        return False

def get_subscriber_status(phone_number):
    """Get subscriber opt-in/opt-out status"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        cursor.execute("SELECT status FROM subscribers WHERE phone_number = ?", (phone_number,))
        result = cursor.fetchone()
        conn.close()
        
        if result:
            return result[0]  # 'subscribed' or 'unsubscribed'
        else:
            return 'subscribed'  # Default: assume subscribed if not in database
    except Exception as e:
        logger.error(f"Error getting subscriber status: {str(e)}")
        return 'subscribed'  # Safe default

def update_subscriber_status(phone_number, status):
    """Update subscriber opt-in/opt-out status"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        
        # Check if subscriber exists
        cursor.execute("SELECT id FROM subscribers WHERE phone_number = ?", (phone_number,))
        exists = cursor.fetchone()
        
        if exists:
            # Update existing subscriber
            if status == 'unsubscribed':
                cursor.execute('''
                    UPDATE subscribers 
                    SET status = ?, opted_out_at = CURRENT_TIMESTAMP, last_updated = CURRENT_TIMESTAMP
                    WHERE phone_number = ?
                ''', (status, phone_number))
            else:
                cursor.execute('''
                    UPDATE subscribers 
                    SET status = ?, opted_in_at = CURRENT_TIMESTAMP, last_updated = CURRENT_TIMESTAMP
                    WHERE phone_number = ?
                ''', (status, phone_number))
        else:
            # Insert new subscriber
            if status == 'unsubscribed':
                cursor.execute('''
                    INSERT INTO subscribers (phone_number, status, opted_out_at)
                    VALUES (?, ?, CURRENT_TIMESTAMP)
                ''', (phone_number, status))
            else:
                cursor.execute('''
                    INSERT INTO subscribers (phone_number, status)
                    VALUES (?, ?)
                ''', (phone_number, status))
        
        conn.commit()
        conn.close()
        logger.info(f"Subscriber {phone_number} status updated to: {status}")
        return True
    except Exception as e:
        logger.error(f"Error updating subscriber status: {str(e)}")
        return False

def detect_intent(message_body):
    """Detect intent from message body using keyword matching"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        
        # Get all active intents ordered by priority
        cursor.execute('''
            SELECT intent_name, keywords, reply_message 
            FROM auto_reply_intents 
            WHERE is_active = 1 
            ORDER BY priority ASC
        ''')
        intents = cursor.fetchall()
        conn.close()
        
        # Normalize message body
        body_upper = message_body.upper().strip()
        
        # Check each intent's keywords
        for intent_name, keywords, reply_message in intents:
            keyword_list = [k.strip().upper() for k in keywords.split(',')]
            
            # Check if any keyword matches
            for keyword in keyword_list:
                if keyword in body_upper:
                    logger.info(f"Intent detected: {intent_name} (keyword: {keyword})")
                    return intent_name, reply_message
        
        # No intent matched
        return None, None
    except Exception as e:
        logger.error(f"Error detecting intent: {str(e)}")
        return None, None

def store_inbound_message(from_number, to_number, body, msg_sid, intent=None):
    """Store inbound message in database with intent"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO inbound_messages (from_number, to_number, message_body, message_sid, reply_sent, intent)
            VALUES (?, ?, ?, ?, 1, ?)
        ''', (from_number, to_number, body, msg_sid, intent))
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        logger.error(f"Error storing inbound message: {str(e)}")
        return False

def ensure_database_schema():
    """Ensure database has all required columns and tables (migration helper)"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    try:
        # Check if intent column exists in inbound_messages table
        cursor.execute("PRAGMA table_info(inbound_messages)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'intent' not in columns:
            logger.info("Adding 'intent' column to inbound_messages table...")
            cursor.execute("ALTER TABLE inbound_messages ADD COLUMN intent TEXT")
            conn.commit()
            logger.info("Migration completed: intent column added")
        
        # Check if subscribers table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='subscribers'")
        if not cursor.fetchone():
            logger.info("Creating subscribers table...")
            cursor.execute('''
                CREATE TABLE subscribers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    phone_number TEXT UNIQUE NOT NULL,
                    status TEXT DEFAULT 'subscribed',
                    opted_in_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    opted_out_at TIMESTAMP,
                    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            conn.commit()
            logger.info("Subscribers table created")
        
        # Check if auto_reply_intents table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='auto_reply_intents'")
        if not cursor.fetchone():
            logger.info("Creating auto_reply_intents table...")
            cursor.execute('''
                CREATE TABLE auto_reply_intents (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    intent_name TEXT UNIQUE NOT NULL,
                    keywords TEXT NOT NULL,
                    reply_message TEXT NOT NULL,
                    priority INTEGER DEFAULT 0,
                    is_active BOOLEAN DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Insert default intents
            cursor.execute('''
                INSERT OR IGNORE INTO auto_reply_intents (intent_name, keywords, reply_message, priority)
                VALUES 
                    ('RSVP', 'RSVP,YES,CONFIRM,ATTENDING', 'Thank you for your RSVP! We look forward to seeing you at the event.', 1),
                    ('TIME', 'TIME,WHEN,SCHEDULE', 'Event timing: Please check your invitation for complete schedule details.', 2),
                    ('ADDRESS', 'ADDRESS,WHERE,LOCATION', 'Location: Please refer to your invitation for the complete address and directions.', 3),
                    ('SEVA', 'SEVA,VOLUNTEER,HELP', 'Thank you for offering seva! A coordinator will contact you with details.', 4)
            ''')
            conn.commit()
            logger.info("Auto-reply intents table created with default intents")
        
        return True
        
    except Exception as e:
        logger.error(f"Database migration error: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

# Database initialization
def init_db():
    """Initialize SQLite database"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    # Users table
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
    
    # SMS campaigns table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS campaigns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            name TEXT NOT NULL,
            message_body TEXT NOT NULL,
            total_numbers INTEGER,
            successful_sends INTEGER DEFAULT 0,
            failed_sends INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            completed_at TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Individual message status table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS message_status (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            campaign_id INTEGER,
            phone_number TEXT,
            message_sid TEXT,
            status TEXT,
            error_message TEXT,
            sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (campaign_id) REFERENCES campaigns (id)
        )
    ''')
    
    # Inbound messages table (for auto-reply tracking)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS inbound_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_number TEXT NOT NULL,
            to_number TEXT,
            message_body TEXT,
            message_sid TEXT,
            reply_sent BOOLEAN DEFAULT 0,
            intent TEXT,
            received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Settings table for application configuration
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            setting_key TEXT UNIQUE NOT NULL,
            setting_value TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Subscribers table for opt-in/opt-out management (v2.1.0)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS subscribers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT UNIQUE NOT NULL,
            status TEXT DEFAULT 'subscribed',
            opted_in_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            opted_out_at TIMESTAMP,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Auto-reply intents table for custom responses (v2.1.0)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS auto_reply_intents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            intent_name TEXT UNIQUE NOT NULL,
            keywords TEXT NOT NULL,
            reply_message TEXT NOT NULL,
            priority INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Initialize default auto-reply message if not exists
    cursor.execute("SELECT COUNT(*) FROM settings WHERE setting_key = 'auto_reply_message'")
    if cursor.fetchone()[0] == 0:
        default_auto_reply = os.getenv(
            "AUTO_REPLY_MESSAGE",
            "Jai Gajanan, Thank you for your message. Incoming messages on this number are not monitored. "
            "Please contact us if you need additional information."
        )
        cursor.execute('''
            INSERT INTO settings (setting_key, setting_value)
            VALUES ('auto_reply_message', ?)
        ''', (default_auto_reply,))
        logger.info("Default auto-reply message initialized in database")
    
    # Create default admin user if not exists
    cursor.execute('SELECT COUNT(*) FROM users WHERE username = ?', ('admin',))
    if cursor.fetchone()[0] == 0:
        admin_hash = generate_password_hash('admin123')
        cursor.execute('INSERT INTO users (username, password_hash, is_default_password) VALUES (?, ?, ?)', 
                      ('admin', admin_hash, 1))
        logger.info("Default admin user created (username: admin, password: admin123)")
    
    # Initialize default auto-reply intents if not exists (v2.1.0)
    cursor.execute("SELECT COUNT(*) FROM auto_reply_intents")
    if cursor.fetchone()[0] == 0:
        default_intents = [
            ('RSVP', 'RSVP,YES,CONFIRM,ATTENDING,COUNT ME IN', 
             'Thank you for your RSVP! We have confirmed your attendance. Jai Gajanan 🙏', 1),
            ('TIME', 'TIME,WHEN,SCHEDULE,TIMING,WHAT TIME', 
             'Event timing: Please check the original invitation for schedule details.', 2),
            ('ADDRESS', 'ADDRESS,WHERE,LOCATION,DIRECTIONS,HOW TO REACH', 
             'Location details: Please refer to the original invitation for address and directions.', 3),
            ('SEVA', 'SEVA,VOLUNTEER,HELP,PARTICIPATE,SERVE', 
             'Thank you for offering seva! We will contact you with volunteer opportunities. Jai Gajanan 🙏', 4),
        ]
        cursor.executemany('''
            INSERT INTO auto_reply_intents (intent_name, keywords, reply_message, priority)
            VALUES (?, ?, ?, ?)
        ''', default_intents)
        logger.info("Default auto-reply intents initialized (RSVP, TIME, ADDRESS, SEVA)")
    
    # Migrate existing users to add is_default_password column if needed
    try:
        cursor.execute("SELECT is_default_password FROM users LIMIT 1")
    except sqlite3.OperationalError:
        logger.info("Migrating database: Adding is_default_password column")
        cursor.execute("ALTER TABLE users ADD COLUMN is_default_password BOOLEAN DEFAULT 0")
        # Mark admin user as using default password if they haven't changed it
        cursor.execute("UPDATE users SET is_default_password = 1 WHERE username = 'admin'")
        conn.commit()
        logger.info("Database migration completed successfully")
    
    conn.commit()
    conn.close()

def login_required(f):
    """Decorator to require login for protected routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def get_user_twilio_client(user_id):
    """Get Twilio client for specific user"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    cursor.execute('SELECT twilio_sid, twilio_token FROM users WHERE id = ?', (user_id,))
    result = cursor.fetchone()
    conn.close()
    
    if result and result[0] and result[1]:
        return Client(result[0], result[1])
    return None

def parse_phone_numbers(file_path):
    """Parse phone numbers from uploaded file"""
    numbers = []
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read().strip()
            
            # Try CSV format first
            if file_path.endswith('.csv'):
                file.seek(0)
                csv_reader = csv.reader(file)
                for row in csv_reader:
                    for cell in row:
                        if cell.strip():
                            numbers.append(cell.strip())
            else:
                # Handle text format
                for line in content.split('\n'):
                    if ',' in line:
                        line_numbers = [num.strip() for num in line.split(',')]
                        numbers.extend(line_numbers)
                    else:
                        number = line.strip()
                        if number:
                            numbers.append(number)
        
        # Remove duplicates while preserving order
        clean_numbers = []
        seen = set()
        for num in numbers:
            if num and num not in seen:
                clean_numbers.append(num)
                seen.add(num)
                
        return clean_numbers
    except Exception as e:
        logger.error(f"Error parsing phone numbers: {str(e)}")
        return []

def send_bulk_sms_async(campaign_id, phone_numbers, message_body, twilio_client, from_number):
    """Send bulk SMS asynchronously"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    successful = 0
    failed = 0
    
    try:
        cursor.execute('UPDATE campaigns SET status = ? WHERE id = ?', ('sending', campaign_id))
        conn.commit()
        
        for phone_number in phone_numbers:
            try:
                message = twilio_client.messages.create(
                    from_=from_number,
                    body=message_body,
                    to=phone_number
                )
                
                cursor.execute('''
                    INSERT INTO message_status (campaign_id, phone_number, message_sid, status)
                    VALUES (?, ?, ?, ?)
                ''', (campaign_id, phone_number, message.sid, 'sent'))
                
                successful += 1
                logger.info(f"SMS sent to {phone_number}: {message.sid}")
                
                # Small delay to avoid rate limiting
                time.sleep(1)
                
            except TwilioException as e:
                cursor.execute('''
                    INSERT INTO message_status (campaign_id, phone_number, message_sid, status, error_message)
                    VALUES (?, ?, ?, ?, ?)
                ''', (campaign_id, phone_number, None, 'failed', str(e)))
                
                failed += 1
                logger.error(f"Failed to send SMS to {phone_number}: {str(e)}")
            
            except Exception as e:
                cursor.execute('''
                    INSERT INTO message_status (campaign_id, phone_number, message_sid, status, error_message)
                    VALUES (?, ?, ?, ?, ?)
                ''', (campaign_id, phone_number, None, 'failed', str(e)))
                
                failed += 1
                logger.error(f"Unexpected error sending to {phone_number}: {str(e)}")
        
        # Update campaign with final results
        cursor.execute('''
            UPDATE campaigns 
            SET successful_sends = ?, failed_sends = ?, status = ?, completed_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ''', (successful, failed, 'completed', campaign_id))
        
        conn.commit()
        logger.info(f"Campaign {campaign_id} completed: {successful} successful, {failed} failed")
        
    except Exception as e:
        cursor.execute('UPDATE campaigns SET status = ? WHERE id = ?', ('error', campaign_id))
        conn.commit()
        logger.error(f"Campaign {campaign_id} failed: {str(e)}")
    
    finally:
        conn.close()

@app.route('/')
def index():
    """Home page"""
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """User login"""
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        cursor.execute('SELECT id, password_hash, is_default_password FROM users WHERE username = ?', (username,))
        user = cursor.fetchone()
        conn.close()
        
        if user and check_password_hash(user[1], password):
            session['user_id'] = user[0]
            session['username'] = username
            session['is_default_password'] = bool(user[2]) if len(user) > 2 else False
            flash('Login successful!', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('Invalid username or password', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """User logout"""
    session.clear()
    flash('You have been logged out', 'info')
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    """User dashboard"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    # Get recent campaigns
    cursor.execute('''
        SELECT id, name, total_numbers, successful_sends, failed_sends, status, created_at
        FROM campaigns 
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT 10
    ''', (session['user_id'],))
    
    campaigns = cursor.fetchall()
    conn.close()
    
    return render_template('dashboard.html', campaigns=campaigns)

@app.route('/settings', methods=['GET', 'POST'])
@login_required
def settings():
    """User settings - Twilio credentials"""
    if request.method == 'POST':
        twilio_sid = request.form['twilio_sid']
        twilio_token = request.form['twilio_token']
        
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE users SET twilio_sid = ?, twilio_token = ? WHERE id = ?
        ''', (twilio_sid, twilio_token, session['user_id']))
        conn.commit()
        conn.close()
        
        flash('Twilio credentials updated successfully!', 'success')
        return redirect(url_for('settings'))
    
    # Get current settings
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    cursor.execute('SELECT username, twilio_sid, twilio_token FROM users WHERE id = ?', (session['user_id'],))
    result = cursor.fetchone()
    conn.close()
    
    current_username = result[0] if result else ''
    current_sid = result[1] if result else ''
    current_token = result[2] if result else ''
    
    return render_template('settings.html', 
                         current_username=current_username,
                         current_sid=current_sid, 
                         current_token=current_token)

@app.route('/change-credentials', methods=['GET', 'POST'])
@login_required
def change_credentials():
    """Change username and password"""
    if request.method == 'POST':
        current_password = request.form['current_password']
        new_username = request.form['new_username'].strip()
        new_password = request.form['new_password']
        confirm_password = request.form['confirm_password']
        
        # Validation
        if not current_password or not new_username or not new_password:
            flash('All fields are required', 'error')
            return redirect(url_for('change_credentials'))
        
        if new_password != confirm_password:
            flash('New passwords do not match', 'error')
            return redirect(url_for('change_credentials'))
        
        if len(new_password) < 6:
            flash('Password must be at least 6 characters long', 'error')
            return redirect(url_for('change_credentials'))
        
        if len(new_username) < 3:
            flash('Username must be at least 3 characters long', 'error')
            return redirect(url_for('change_credentials'))
        
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        
        # Verify current password
        cursor.execute('SELECT password_hash, username FROM users WHERE id = ?', (session['user_id'],))
        user = cursor.fetchone()
        
        if not user or not check_password_hash(user[0], current_password):
            conn.close()
            flash('Current password is incorrect', 'error')
            return redirect(url_for('change_credentials'))
        
        # Check if new username already exists (for other users)
        cursor.execute('SELECT id FROM users WHERE username = ? AND id != ?', (new_username, session['user_id']))
        if cursor.fetchone():
            conn.close()
            flash('Username already exists. Please choose a different one.', 'error')
            return redirect(url_for('change_credentials'))
        
        # Update username and password
        new_password_hash = generate_password_hash(new_password)
        cursor.execute('''
            UPDATE users SET username = ?, password_hash = ?, is_default_password = 0 WHERE id = ?
        ''', (new_username, new_password_hash, session['user_id']))
        
        conn.commit()
        conn.close()
        
        # Update session
        session['username'] = new_username
        session['is_default_password'] = False
        
        flash('Credentials updated successfully! Please log in again for security.', 'success')
        return redirect(url_for('logout'))
    
    # Get current username for display
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    cursor.execute('SELECT username FROM users WHERE id = ?', (session['user_id'],))
    result = cursor.fetchone()
    conn.close()
    
    current_username = result[0] if result else ''
    
    return render_template('change_credentials.html', current_username=current_username)

@app.route('/send_sms', methods=['GET', 'POST'])
@login_required
def send_sms():
    """Send bulk SMS"""
    if request.method == 'POST':
        campaign_name = request.form['campaign_name']
        message_body = request.form['message_body']
        from_number = request.form['from_number']
        
        # Check if file was uploaded
        if 'phone_file' not in request.files:
            flash('Please upload a phone numbers file', 'error')
            return redirect(request.url)
        
        file = request.files['phone_file']
        if file.filename == '':
            flash('Please select a file', 'error')
            return redirect(request.url)
        
        if file:
            filename = secure_filename(file.filename)
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{timestamp}_{filename}"
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(file_path)
            
            # Parse phone numbers
            phone_numbers = parse_phone_numbers(file_path)
            
            if not phone_numbers:
                flash('No valid phone numbers found in the file', 'error')
                os.remove(file_path)  # Clean up
                return redirect(request.url)
            
            # Get Twilio client
            twilio_client = get_user_twilio_client(session['user_id'])
            if not twilio_client:
                flash('Please configure your Twilio credentials in Settings first', 'error')
                os.remove(file_path)  # Clean up
                return redirect(url_for('settings'))
            
            # Create campaign record
            conn = sqlite3.connect('twilio_sms.db')
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO campaigns (user_id, name, message_body, total_numbers)
                VALUES (?, ?, ?, ?)
            ''', (session['user_id'], campaign_name, message_body, len(phone_numbers)))
            
            campaign_id = cursor.lastrowid
            conn.commit()
            conn.close()
            
            # Start async SMS sending
            thread = Thread(target=send_bulk_sms_async, args=(
                campaign_id, phone_numbers, message_body, twilio_client, from_number
            ))
            thread.start()
            
            # Clean up uploaded file
            os.remove(file_path)
            
            flash(f'SMS campaign "{campaign_name}" started! Sending to {len(phone_numbers)} numbers.', 'success')
            return redirect(url_for('campaign_status', campaign_id=campaign_id))
    
    return render_template('send_sms.html')

@app.route('/campaign/<int:campaign_id>')
@login_required
def campaign_status(campaign_id):
    """View campaign status"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    # Get campaign details
    cursor.execute('''
        SELECT name, message_body, total_numbers, successful_sends, failed_sends, status, created_at, completed_at
        FROM campaigns 
        WHERE id = ? AND user_id = ?
    ''', (campaign_id, session['user_id']))
    
    campaign = cursor.fetchone()
    
    if not campaign:
        flash('Campaign not found', 'error')
        return redirect(url_for('dashboard'))
    
    # Get individual message statuses
    cursor.execute('''
        SELECT phone_number, message_sid, status, error_message, sent_at
        FROM message_status
        WHERE campaign_id = ?
        ORDER BY sent_at DESC
    ''', (campaign_id,))
    
    messages = cursor.fetchall()
    conn.close()
    
    return render_template('campaign_status.html', campaign=campaign, messages=messages, campaign_id=campaign_id)

@app.route('/api/campaign/<int:campaign_id>/status')
@login_required
def api_campaign_status(campaign_id):
    """API endpoint for campaign status (for AJAX updates)"""
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT total_numbers, successful_sends, failed_sends, status
        FROM campaigns 
        WHERE id = ? AND user_id = ?
    ''', (campaign_id, session['user_id']))
    
    result = cursor.fetchone()
    conn.close()
    
    if result:
        return jsonify({
            'total': result[0],
            'successful': result[1],
            'failed': result[2],
            'status': result[3]
        })
    else:
        return jsonify({'error': 'Campaign not found'}), 404

# ============================================================================
# AUTO-REPLY WEBHOOK ROUTES (for inbound SMS)
# ============================================================================

@app.route('/health')
def health():
    """Health check endpoint for monitoring"""
    return jsonify({"status": "ok", "service": "TwilioSMS"}), 200

@app.route('/sms/inbound', methods=['POST'])
def sms_inbound():
    """
    Twilio webhook for inbound SMS messages
    Implements STOP/START compliance and intent-based auto-replies
    
    Twilio POST fields:
    - From: sender's phone number
    - To: recipient's phone number (your Twilio number)
    - Body: message text
    - MessageSid: unique message ID
    """
    # Get message details from Twilio POST
    from_number = request.form.get("From", "")
    to_number = request.form.get("To", "")
    body = request.form.get("Body", "").strip()
    msg_sid = request.form.get("MessageSid", "")
    
    # Log inbound message
    logger.info(f"📩 Inbound SMS: From={from_number} Body='{body}' SID={msg_sid}")
    
    # Normalize message body for keyword detection
    body_upper = body.upper().strip()
    
    # Create TwiML response
    resp = MessagingResponse()
    intent_detected = None
    reply_message = None
    
    # STEP 1: Check for STOP keywords (highest priority)
    STOP_KEYWORDS = ['STOP', 'STOPALL', 'UNSUBSCRIBE', 'CANCEL', 'END', 'QUIT']
    if body_upper in STOP_KEYWORDS:
        # Update subscriber status to unsubscribed
        update_subscriber_status(from_number, 'unsubscribed')
        intent_detected = 'STOP'
        reply_message = "You have been unsubscribed and will not receive further messages. Reply START to resubscribe."
        resp.message(reply_message)
        logger.info(f"🛑 STOP request from {from_number} - Unsubscribed")
    
    # STEP 2: Check for START keywords
    elif body_upper in ['START', 'YES', 'UNSTOP']:
        # Update subscriber status to subscribed
        update_subscriber_status(from_number, 'subscribed')
        intent_detected = 'START'
        reply_message = "You have been resubscribed and will receive messages again. Reply STOP to unsubscribe."
        resp.message(reply_message)
        logger.info(f"✅ START request from {from_number} - Resubscribed")
    
    # STEP 3: Check if user is currently unsubscribed
    elif get_subscriber_status(from_number) == 'unsubscribed':
        intent_detected = 'UNSUBSCRIBED'
        reply_message = "You are currently unsubscribed. Reply START to receive messages again."
        resp.message(reply_message)
        logger.info(f"⚠️ Message from unsubscribed user {from_number}")
    
    # STEP 4: Check for intent-based auto-replies
    else:
        detected_intent, intent_reply = detect_intent(body)
        if detected_intent and intent_reply:
            intent_detected = detected_intent
            reply_message = intent_reply
            resp.message(intent_reply)
            logger.info(f"🎯 Intent '{detected_intent}' detected for {from_number}")
        else:
            # STEP 5: Send default auto-reply message
            intent_detected = 'DEFAULT'
            reply_message = get_auto_reply_message()
            resp.message(reply_message)
            logger.info(f"💬 Default auto-reply sent to {from_number}")
    
    # Store inbound message in database with detected intent
    store_inbound_message(from_number, to_number, body, msg_sid, intent_detected)
    
    return Response(str(resp), mimetype="text/xml")

@app.route('/inbound-messages')
@login_required
def inbound_messages():
    """View inbound messages (admin only)"""
    # Ensure database schema is up to date
    ensure_database_schema()
    
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    try:
        # Check if intent column exists
        cursor.execute("PRAGMA table_info(inbound_messages)")
        columns = [column[1] for column in cursor.fetchall()]
        has_intent_column = 'intent' in columns
        
        # Query with or without intent column based on schema
        if (has_intent_column):
            cursor.execute('''
                SELECT id, from_number, to_number, message_body, message_sid, reply_sent, intent, received_at
                FROM inbound_messages 
                ORDER BY received_at DESC
                LIMIT 100
            ''')
        else:
            # Fallback for old schema - add NULL as intent placeholder
            cursor.execute('''
                SELECT id, from_number, to_number, message_body, message_sid, reply_sent, NULL as intent, received_at
                FROM inbound_messages 
                ORDER BY received_at DESC
                LIMIT 100
            ''')
        
        messages = cursor.fetchall()
        conn.close()
        
        return render_template('inbound_messages.html', messages=messages)
        
    except Exception as e:
        logger.error(f"Error fetching inbound messages: {e}")
        conn.close()
        flash('Error loading inbound messages. Please check logs.', 'error')
        return render_template('inbound_messages.html', messages=[])

@app.route('/send-custom-reply/<int:message_id>', methods=['POST'])
@login_required
def send_custom_reply(message_id):
    """Send custom reply to an inbound message (1:1 conversation)"""
    custom_message = request.form.get('custom_message', '').strip()
    
    if not custom_message:
        flash('Please enter a message to send', 'error')
        return redirect(url_for('inbound_messages'))
    
    try:
        # Get the inbound message details
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        cursor.execute('''
            SELECT from_number, to_number FROM inbound_messages WHERE id = ?
        ''', (message_id,))
        result = cursor.fetchone()
        
        if not result:
            flash('Message not found', 'error')
            conn.close()
            return redirect(url_for('inbound_messages'))
        
        from_number, to_number = result
        
        # Get Twilio credentials
        cursor.execute('''
            SELECT twilio_sid, twilio_token FROM users WHERE id = ?
        ''', (session['user_id'],))
        creds = cursor.fetchone()
        
        if not creds or not creds[0] or not creds[1]:
            flash('Twilio credentials not configured. Please add them in Settings.', 'error')
            conn.close()
            return redirect(url_for('inbound_messages'))
        
        account_sid, auth_token = creds
        
        # Send the custom reply via Twilio
        client = Client(account_sid, auth_token)
        message = client.messages.create(
            body=custom_message,
            from_=to_number,  # The original TO number becomes FROM
            to=from_number    # The original FROM number becomes TO
        )
        
        # Log the custom reply in message_status table for tracking
        cursor.execute('''
            INSERT INTO message_status (campaign_id, phone_number, message_sid, status, sent_at)
            VALUES (NULL, ?, ?, 'sent', CURRENT_TIMESTAMP)
        ''', (from_number, message.sid))
        
        # Update the inbound message to mark custom reply sent
        cursor.execute('''
            UPDATE inbound_messages SET reply_sent = 1 WHERE id = ?
        ''', (message_id,))
        
        conn.commit()
        conn.close()
        
        flash(f'✅ Custom reply sent successfully to {from_number}!', 'success')
        logger.info(f"Custom reply sent to {from_number}: {custom_message[:50]}...")
        
    except TwilioException as e:
        logger.error(f"Twilio error sending custom reply: {str(e)}")
        flash(f'Error sending message: {str(e)}', 'error')
    except Exception as e:
        logger.error(f"Error sending custom reply: {str(e)}")
        flash(f'Error sending custom reply: {str(e)}', 'error')
    
    return redirect(url_for('inbound_messages'))

@app.route('/settings/auto-reply', methods=['GET', 'POST'])
@login_required
def settings_auto_reply():
    """Configure auto-reply message (stored in database)"""
    if request.method == 'POST':
        new_message = request.form.get('auto_reply_message', '').strip()
        
        if new_message:
            if set_auto_reply_message(new_message):
                flash('Auto-reply message updated successfully!', 'success')
                logger.info(f"Auto-reply message updated by user {session['username']}")
            else:
                flash('Error updating auto-reply message. Please try again.', 'error')
        else:
            flash('Auto-reply message cannot be empty', 'error')
        
        return redirect(url_for('settings_auto_reply'))
    
    current_message = get_auto_reply_message()
    return render_template('settings_auto_reply.html', current_message=current_message)

@app.route('/subscribers')
@login_required
def subscribers():
    """View all subscribers and their opt-in/opt-out status"""
    # Ensure database schema is up to date
    ensure_database_schema()
    
    conn = sqlite3.connect('twilio_sms.db')
    cursor = conn.cursor()
    
    try:
        # Get all subscribers
        cursor.execute('''
            SELECT phone_number, status, opted_in_at, opted_out_at, last_updated
            FROM subscribers 
            ORDER BY last_updated DESC
        ''')
        
        subscribers_list = cursor.fetchall()
        
        # Get counts for summary
        cursor.execute("SELECT COUNT(*) FROM subscribers WHERE status = 'subscribed'")
        subscribed_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM subscribers WHERE status = 'unsubscribed'")
        unsubscribed_count = cursor.fetchone()[0]
        
        conn.close()
        
        return render_template('subscribers.html', 
                             subscribers=subscribers_list,
                             subscribed_count=subscribed_count,
                             unsubscribed_count=unsubscribed_count)
    
    except Exception as e:
        logger.error(f"Error fetching subscribers: {e}")
        conn.close()
        flash('Error loading subscribers. Please check logs.', 'error')
        return render_template('subscribers.html', 
                             subscribers=[],
                             subscribed_count=0,
                             unsubscribed_count=0)

if __name__ == '__main__':
    init_db()
    # For production, use a proper WSGI server like Gunicorn
    app.run(host='0.0.0.0', port=5000, debug=False)
