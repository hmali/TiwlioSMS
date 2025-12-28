#!/usr/bin/env python3
"""
Twilio Bulk SMS Web Application
Production-ready Flask application for sending bulk SMS via Twilio
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

from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from twilio.rest import Client
from twilio.base.exceptions import TwilioException

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
    
    # Create default admin user if not exists
    cursor.execute('SELECT COUNT(*) FROM users WHERE username = ?', ('admin',))
    if cursor.fetchone()[0] == 0:
        admin_hash = generate_password_hash('admin123')
        cursor.execute('INSERT INTO users (username, password_hash) VALUES (?, ?)', 
                      ('admin', admin_hash))
        logger.info("Default admin user created (username: admin, password: admin123)")
    
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
        cursor.execute('SELECT id, password_hash FROM users WHERE username = ?', (username,))
        user = cursor.fetchone()
        conn.close()
        
        if user and check_password_hash(user[1], password):
            session['user_id'] = user[0]
            session['username'] = username
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
            UPDATE users SET username = ?, password_hash = ? WHERE id = ?
        ''', (new_username, new_password_hash, session['user_id']))
        
        conn.commit()
        conn.close()
        
        # Update session
        session['username'] = new_username
        
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

if __name__ == '__main__':
    init_db()
    # For production, use a proper WSGI server like Gunicorn
    app.run(host='0.0.0.0', port=5000, debug=False)
