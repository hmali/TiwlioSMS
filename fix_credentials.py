#!/usr/bin/env python3

"""
Quick Fix Script for Web App Twilio Credentials
Run this script to directly update credentials in the database
"""

import sqlite3
import sys
import getpass

def update_credentials():
    """Update Twilio credentials in the database"""
    print("🔧 Twilio Credential Update Script")
    print("=" * 40)
    
    # Get credentials from user
    print("Enter your working Twilio credentials:")
    account_sid = input("Account SID: ").strip()
    auth_token = getpass.getpass("Auth Token: ").strip()
    
    if not account_sid or not auth_token:
        print("❌ Both Account SID and Auth Token are required!")
        return False
    
    # Validate Account SID format
    if not account_sid.startswith('AC') or len(account_sid) != 34:
        print("❌ Invalid Account SID format!")
        return False
    
    try:
        # Connect to database
        conn = sqlite3.connect('/opt/twilio-sms-app/twilio_sms.db')
        cursor = conn.cursor()
        
        # Update credentials for admin user
        cursor.execute('''
            UPDATE users 
            SET twilio_sid = ?, twilio_token = ? 
            WHERE username = 'admin'
        ''', (account_sid, auth_token))
        
        if cursor.rowcount > 0:
            conn.commit()
            print("✅ Credentials updated successfully!")
            print(f"   Updated {cursor.rowcount} user(s)")
            
            # Verify the update
            cursor.execute("SELECT username, twilio_sid FROM users WHERE username = 'admin'")
            result = cursor.fetchone()
            if result:
                print(f"   Account SID: {result[1][:10]}...{result[1][-4:]}")
            
            conn.close()
            return True
        else:
            print("❌ No admin user found to update!")
            conn.close()
            return False
            
    except sqlite3.Error as e:
        print(f"❌ Database error: {str(e)}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return False

def main():
    """Main function"""
    print("This script will update Twilio credentials in the web app database.")
    print("Make sure you have the working credentials from your manual test.\n")
    
    if update_credentials():
        print("\n🎉 Success! Now restart the web application:")
        print("   sudo systemctl restart twilio-sms-app")
        print("\nThen test sending SMS through the web interface.")
        return True
    else:
        print("\n❌ Failed to update credentials. Check the error messages above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
