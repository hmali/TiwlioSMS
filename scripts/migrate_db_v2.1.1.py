#!/usr/bin/env python3
"""
Database Migration Script for TwilioSMS v2.1.1

This script adds the missing 'intent' column to inbound_messages table
and creates the subscribers and auto_reply_intents tables if they don't exist.

Usage:
    python3 scripts/migrate_db_v2.1.1.py
"""

import sqlite3
import sys
import os
from datetime import datetime

def backup_database(db_path):
    """Create a backup of the database before migration"""
    backup_path = f"{db_path}.backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    try:
        import shutil
        shutil.copy2(db_path, backup_path)
        print(f"✓ Database backed up to: {backup_path}")
        return True
    except Exception as e:
        print(f"✗ Error backing up database: {e}")
        return False

def migrate_database(db_path='twilio_sms.db'):
    """Run database migrations for v2.1.1"""
    
    if not os.path.exists(db_path):
        print(f"✗ Database not found: {db_path}")
        return False
    
    # Backup first
    if not backup_database(db_path):
        response = input("Continue without backup? (yes/no): ")
        if response.lower() != 'yes':
            print("Migration cancelled.")
            return False
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        print("\n=== TwilioSMS v2.1.1 Database Migration ===\n")
        
        # 1. Check and add intent column to inbound_messages
        print("Checking inbound_messages table...")
        cursor.execute("PRAGMA table_info(inbound_messages)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'intent' not in columns:
            print("  → Adding 'intent' column...")
            cursor.execute("ALTER TABLE inbound_messages ADD COLUMN intent TEXT")
            conn.commit()
            print("  ✓ Intent column added successfully")
        else:
            print("  ✓ Intent column already exists")
        
        # 2. Check and create subscribers table
        print("\nChecking subscribers table...")
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='subscribers'")
        if not cursor.fetchone():
            print("  → Creating subscribers table...")
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
            print("  ✓ Subscribers table created successfully")
        else:
            print("  ✓ Subscribers table already exists")
        
        # 3. Check and create auto_reply_intents table
        print("\nChecking auto_reply_intents table...")
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='auto_reply_intents'")
        if not cursor.fetchone():
            print("  → Creating auto_reply_intents table...")
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
            print("  → Adding default intents...")
            cursor.execute('''
                INSERT INTO auto_reply_intents (intent_name, keywords, reply_message, priority)
                VALUES 
                    ('RSVP', 'RSVP,YES,CONFIRM,ATTENDING', 'Thank you for your RSVP! We look forward to seeing you at the event.', 1),
                    ('TIME', 'TIME,WHEN,SCHEDULE', 'Event timing: Please check your invitation for complete schedule details.', 2),
                    ('ADDRESS', 'ADDRESS,WHERE,LOCATION', 'Location: Please refer to your invitation for the complete address and directions.', 3),
                    ('SEVA', 'SEVA,VOLUNTEER,HELP', 'Thank you for offering seva! A coordinator will contact you with details.', 4)
            ''')
            conn.commit()
            print("  ✓ Auto-reply intents table created with 4 default intents")
        else:
            print("  ✓ Auto-reply intents table already exists")
        
        # 4. Verify migrations
        print("\n=== Verification ===\n")
        
        cursor.execute("PRAGMA table_info(inbound_messages)")
        columns = [column[1] for column in cursor.fetchall()]
        print(f"✓ inbound_messages columns: {', '.join(columns)}")
        
        cursor.execute("SELECT COUNT(*) FROM subscribers")
        sub_count = cursor.fetchone()[0]
        print(f"✓ Subscribers table: {sub_count} records")
        
        cursor.execute("SELECT COUNT(*) FROM auto_reply_intents")
        intent_count = cursor.fetchone()[0]
        print(f"✓ Auto-reply intents table: {intent_count} intents")
        
        print("\n=== Migration Complete ===")
        print("✓ All database migrations applied successfully!")
        print("\nNext steps:")
        print("  1. Restart your application: sudo systemctl restart twilio_sms")
        print("  2. Test the Inbound Messages page")
        print("  3. Test the Subscribers page")
        
        return True
        
    except Exception as e:
        print(f"\n✗ Migration error: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

if __name__ == '__main__':
    # Check if custom database path provided
    db_path = sys.argv[1] if len(sys.argv) > 1 else 'twilio_sms.db'
    
    print(f"Database path: {db_path}\n")
    
    if migrate_database(db_path):
        sys.exit(0)
    else:
        sys.exit(1)
