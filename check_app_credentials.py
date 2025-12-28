#!/usr/bin/env python3

"""
Web App Database Credential Checker
Check if Twilio credentials are properly stored in the web app database
"""

import sqlite3
import sys

def check_database_credentials():
    """Check credentials stored in the web app database"""
    try:
        # Connect to the database
        conn = sqlite3.connect('/opt/twilio-sms-app/twilio_sms.db')
        cursor = conn.cursor()
        
        print("🔍 Checking Web App Database...")
        print("=" * 50)
        
        # Check if users table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='users';")
        if not cursor.fetchone():
            print("❌ Users table doesn't exist!")
            return False
        
        # Get all users and their credentials
        cursor.execute("SELECT id, username, twilio_sid, twilio_token FROM users")
        users = cursor.fetchall()
        
        if not users:
            print("❌ No users found in database!")
            return False
        
        print(f"✅ Found {len(users)} user(s) in database:")
        
        for user in users:
            user_id, username, sid, token = user
            print(f"\n👤 User: {username} (ID: {user_id})")
            
            if sid and token:
                print(f"   📱 Account SID: {sid[:10]}...{sid[-4:] if len(sid) > 14 else sid}")
                print(f"   🔑 Auth Token: {'*' * 20}...{token[-4:] if len(token) > 4 else '****'}")
                
                # Validate format
                if sid.startswith('AC') and len(sid) == 34:
                    print("   ✅ Account SID format looks correct")
                else:
                    print("   ❌ Account SID format is incorrect!")
                    
                if len(token) >= 32:  # Twilio auth tokens are usually 32+ characters
                    print("   ✅ Auth Token length looks correct")
                else:
                    print("   ❌ Auth Token seems too short!")
            else:
                print("   ❌ No Twilio credentials found for this user!")
                
        conn.close()
        return True
        
    except sqlite3.Error as e:
        print(f"❌ Database error: {str(e)}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return False

def test_credential_retrieval():
    """Test the credential retrieval function from the app"""
    try:
        import sys
        sys.path.append('/opt/twilio-sms-app')
        
        from app import get_user_twilio_client
        
        print("\n🧪 Testing Credential Retrieval...")
        print("=" * 50)
        
        # Test with admin user (ID should be 1)
        client = get_user_twilio_client(1)
        
        if client:
            print("✅ Successfully retrieved Twilio client for user ID 1")
            
            # Try to get account info
            try:
                account = client.api.accounts.list(limit=1)[0]
                print(f"✅ Twilio client works - Account: {account.friendly_name}")
                return True
            except Exception as e:
                print(f"❌ Twilio client error: {str(e)}")
                return False
        else:
            print("❌ Failed to get Twilio client - credentials not found or invalid")
            return False
            
    except ImportError as e:
        print(f"❌ Could not import app module: {str(e)}")
        return False
    except Exception as e:
        print(f"❌ Error testing credential retrieval: {str(e)}")
        return False

def main():
    """Main function"""
    print("🔍 Web App Credential Diagnostics")
    print("Run this script on your EC2 instance to check credential storage\n")
    
    # Check database credentials
    db_ok = check_database_credentials()
    
    if db_ok:
        # Test credential retrieval
        test_credential_retrieval()
    
    return db_ok

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
