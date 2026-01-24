#!/usr/bin/env python3
"""
Database Migration Script
Adds is_default_password column to existing users table
"""

import sqlite3
import sys

def migrate_database():
    """Add is_default_password column to users table if it doesn't exist"""
    try:
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        
        # Check if column already exists
        cursor.execute("PRAGMA table_info(users)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'is_default_password' not in columns:
            print("Adding 'is_default_password' column to users table...")
            
            # Add the column
            cursor.execute('''
                ALTER TABLE users ADD COLUMN is_default_password BOOLEAN DEFAULT 1
            ''')
            
            # For existing users, check if they're using default credentials
            # Only the admin user with default password should have is_default_password = 1
            cursor.execute('''
                UPDATE users SET is_default_password = 0 WHERE username != 'admin'
            ''')
            
            conn.commit()
            print("✓ Migration completed successfully!")
            print("  - Column 'is_default_password' added to users table")
            print("  - Non-admin users flagged as having custom passwords")
            
        else:
            print("✓ Database is already up to date. No migration needed.")
        
        conn.close()
        return True
        
    except sqlite3.Error as e:
        print(f"✗ Database migration failed: {str(e)}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"✗ Unexpected error during migration: {str(e)}", file=sys.stderr)
        return False

if __name__ == '__main__':
    print("=" * 60)
    print("Database Migration Script")
    print("=" * 60)
    
    success = migrate_database()
    
    print("=" * 60)
    
    if success:
        print("Migration process completed successfully!")
        sys.exit(0)
    else:
        print("Migration process failed. Please check the errors above.")
        sys.exit(1)
