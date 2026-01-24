#!/usr/bin/env python3
"""
Auto-Reply Diagnostic Script
Run this on the server to diagnose auto-reply update issues
"""

import sqlite3
import os
import sys

def check_database():
    """Check database configuration"""
    print("=" * 70)
    print("AUTO-REPLY DIAGNOSTIC TOOL")
    print("=" * 70)
    print()
    
    db_path = 'twilio_sms.db'
    
    if not os.path.exists(db_path):
        print(f"❌ ERROR: Database file not found: {db_path}")
        print("   Run: python3 migrate_db.py")
        return False
    
    print(f"✅ Database file exists: {db_path}")
    print(f"   Size: {os.path.getsize(db_path):,} bytes")
    print(f"   Permissions: {oct(os.stat(db_path).st_mode)[-3:]}")
    print()
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if settings table exists
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='settings'
        """)
        
        if not cursor.fetchone():
            print("❌ ERROR: Settings table does not exist!")
            print("   Run: python3 migrate_db.py")
            conn.close()
            return False
        
        print("✅ Settings table exists")
        
        # Show table structure
        cursor.execute("PRAGMA table_info(settings)")
        columns = cursor.fetchall()
        print("\n   Table structure:")
        for col in columns:
            print(f"   - {col[1]:20} {col[2]:10} {'NULL' if col[3] == 0 else 'NOT NULL':10} Default: {col[4]}")
        print()
        
        # Check if auto_reply_message record exists
        cursor.execute("""
            SELECT setting_value, updated_at 
            FROM settings 
            WHERE setting_key = 'auto_reply_message'
        """)
        
        result = cursor.fetchone()
        
        if result:
            print("✅ Auto-reply message record exists")
            print(f"\n   Last updated: {result[1]}")
            print(f"   Message length: {len(result[0])} characters")
            print()
            print("   Current message:")
            print("   " + "-" * 66)
            print(f"   {result[0]}")
            print("   " + "-" * 66)
        else:
            print("❌ WARNING: No auto-reply message in database")
            print("   Initializing default message...")
            
            default_msg = "Jai Gajanan, Thank you for your message. Incoming messages on this number are not monitored. Please contact us if you need additional information."
            
            cursor.execute("""
                INSERT INTO settings (setting_key, setting_value, updated_at)
                VALUES ('auto_reply_message', ?, CURRENT_TIMESTAMP)
            """, (default_msg,))
            conn.commit()
            print("✅ Default message initialized")
        
        print()
        
        # Test UPDATE operation
        print("🧪 TESTING UPDATE OPERATION...")
        test_msg = "TEST MESSAGE - " + str(os.getpid())
        
        cursor.execute("""
            UPDATE settings 
            SET setting_value = ?, updated_at = CURRENT_TIMESTAMP 
            WHERE setting_key = 'auto_reply_message'
        """, (test_msg,))
        
        if cursor.rowcount > 0:
            print(f"✅ UPDATE successful (affected {cursor.rowcount} row)")
            conn.commit()
            
            # Verify the update
            cursor.execute("SELECT setting_value FROM settings WHERE setting_key = 'auto_reply_message'")
            verify = cursor.fetchone()
            
            if verify and verify[0] == test_msg:
                print("✅ UPDATE verified - message changed in database")
                
                # Restore original message
                if result:
                    cursor.execute("""
                        UPDATE settings 
                        SET setting_value = ?, updated_at = CURRENT_TIMESTAMP 
                        WHERE setting_key = 'auto_reply_message'
                    """, (result[0],))
                    conn.commit()
                    print("✅ Original message restored")
            else:
                print("❌ UPDATE verification failed!")
        else:
            print("❌ UPDATE failed - no rows affected")
        
        conn.close()
        print()
        print("=" * 70)
        print("DIAGNOSIS COMPLETE")
        print("=" * 70)
        return True
        
    except sqlite3.Error as e:
        print(f"❌ DATABASE ERROR: {e}")
        return False
    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_function():
    """Test the actual functions from app.py"""
    print()
    print("=" * 70)
    print("TESTING app.py FUNCTIONS")
    print("=" * 70)
    print()
    
    try:
        sys.path.insert(0, '.')
        from app import get_auto_reply_message, set_auto_reply_message
        
        print("🧪 Testing get_auto_reply_message()...")
        current = get_auto_reply_message()
        print(f"✅ Function works - returns {len(current)} characters")
        print()
        
        print("🧪 Testing set_auto_reply_message()...")
        test_msg = "TEST UPDATE - " + str(os.getpid())
        result = set_auto_reply_message(test_msg)
        
        if result:
            print("✅ set_auto_reply_message() returned True")
            
            # Verify
            verify = get_auto_reply_message()
            if verify == test_msg:
                print("✅ VERIFIED - Message was updated correctly!")
                
                # Restore original
                set_auto_reply_message(current)
                print("✅ Original message restored")
            else:
                print(f"❌ VERIFICATION FAILED - Expected: {test_msg}")
                print(f"                        Got: {verify}")
        else:
            print("❌ set_auto_reply_message() returned False")
            print("   Check application logs for errors")
        
    except ImportError as e:
        print(f"❌ Cannot import from app.py: {e}")
    except Exception as e:
        print(f"❌ Error testing functions: {e}")
        import traceback
        traceback.print_exc()

def check_permissions():
    """Check file permissions"""
    print()
    print("=" * 70)
    print("FILE PERMISSIONS CHECK")
    print("=" * 70)
    print()
    
    db_path = 'twilio_sms.db'
    
    if os.path.exists(db_path):
        stat_info = os.stat(db_path)
        print(f"Database file: {db_path}")
        print(f"  Permissions: {oct(stat_info.st_mode)[-3:]}")
        print(f"  Owner UID: {stat_info.st_uid}")
        print(f"  Group GID: {stat_info.st_gid}")
        print(f"  Readable: {os.access(db_path, os.R_OK)}")
        print(f"  Writable: {os.access(db_path, os.W_OK)}")
        print()
        
        if not os.access(db_path, os.W_OK):
            print("❌ WARNING: Database is not writable!")
            print("   Fix: chmod 644 twilio_sms.db")
            print("   Or: sudo chown $USER twilio_sms.db")
    
    # Check directory permissions
    current_dir = os.getcwd()
    print(f"Current directory: {current_dir}")
    print(f"  Writable: {os.access(current_dir, os.W_OK)}")

if __name__ == '__main__':
    print()
    success = check_database()
    
    if success:
        test_function()
        check_permissions()
    
    print()
    print("=" * 70)
    print("RECOMMENDATIONS:")
    print("=" * 70)
    print()
    
    if success:
        print("✅ Database structure is correct")
        print("✅ UPDATE operations work")
        print()
        print("If users still get errors:")
        print("  1. Check Gunicorn logs: sudo journalctl -u twiliosms -n 100")
        print("  2. Verify database permissions: ls -l twilio_sms.db")
        print("  3. Restart service: sudo systemctl restart twiliosms")
        print("  4. Check browser console for JavaScript errors")
        print("  5. Verify form is submitting correctly")
    else:
        print("❌ Issues found - fix them and run again")
    
    print()
