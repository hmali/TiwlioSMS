#!/usr/bin/env python3
"""
Migration Script: Update DEFAULT intent to PENDING_REPLY
Version: 2.1.2
Date: February 9, 2026

This script updates the inbound_messages table to change all 'DEFAULT' 
intent values to 'PENDING_REPLY' to reflect the new behavior where
no automatic reply is sent for regular messages.

Usage: python3 scripts/update_intent_pending.py
"""

import sqlite3
import sys
from datetime import datetime

DB_PATH = 'twilio_sms.db'

def update_default_intent():
    """Update DEFAULT intent to PENDING_REPLY"""
    print("=" * 70)
    print("Migration: Update DEFAULT Intent to PENDING_REPLY")
    print("=" * 70)
    print(f"Database: {DB_PATH}")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    try:
        # Connect to database
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Check current DEFAULT count
        cursor.execute("""
            SELECT COUNT(*) FROM inbound_messages WHERE intent = 'DEFAULT'
        """)
        default_count = cursor.fetchone()[0]
        
        print(f"Found {default_count} messages with 'DEFAULT' intent")
        
        if default_count == 0:
            print("✓ No messages to update. Migration not needed.")
            conn.close()
            return True
        
        # Update DEFAULT to PENDING_REPLY
        print(f"Updating {default_count} messages...")
        cursor.execute("""
            UPDATE inbound_messages 
            SET intent = 'PENDING_REPLY' 
            WHERE intent = 'DEFAULT'
        """)
        
        updated_count = cursor.rowcount
        conn.commit()
        
        # Verify update
        cursor.execute("""
            SELECT COUNT(*) FROM inbound_messages WHERE intent = 'PENDING_REPLY'
        """)
        pending_count = cursor.fetchone()[0]
        
        cursor.execute("""
            SELECT COUNT(*) FROM inbound_messages WHERE intent = 'DEFAULT'
        """)
        remaining_default = cursor.fetchone()[0]
        
        conn.close()
        
        print()
        print("=" * 70)
        print("Migration Results:")
        print("=" * 70)
        print(f"✓ Updated: {updated_count} messages")
        print(f"✓ PENDING_REPLY messages now: {pending_count}")
        print(f"✓ DEFAULT messages remaining: {remaining_default}")
        print()
        print("✓ Migration completed successfully!")
        print("=" * 70)
        
        return True
        
    except sqlite3.Error as e:
        print(f"✖ Database error: {e}")
        return False
    except Exception as e:
        print(f"✖ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    print()
    success = update_default_intent()
    print()
    
    if success:
        print("Next steps:")
        print("  1. Restart the application: sudo systemctl restart twiliosms")
        print("  2. Test inbound messages page")
        print("  3. Verify 'Pending Reply' badges appear correctly")
        print()
        sys.exit(0)
    else:
        print("Migration failed. Please check errors above.")
        sys.exit(1)
