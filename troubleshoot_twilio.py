#!/usr/bin/env python3

"""
Twilio Authentication Troubleshooting Script
Run this to diagnose Twilio credential issues
"""

import sys
import os

def test_twilio_credentials():
    """Test Twilio credentials"""
    try:
        from twilio.rest import Client
        from twilio.base.exceptions import TwilioException
    except ImportError:
        print("❌ Twilio library not installed. Run: pip install twilio")
        return False
    
    print("🔍 Testing Twilio Credentials...")
    print("=" * 50)
    
    # Get credentials from user input
    account_sid = input("Enter your Twilio Account SID: ").strip()
    auth_token = input("Enter your Twilio Auth Token: ").strip()
    
    if not account_sid or not auth_token:
        print("❌ Please provide both Account SID and Auth Token")
        return False
    
    if not account_sid.startswith('AC') or len(account_sid) != 34:
        print("❌ Invalid Account SID format. Should start with 'AC' and be 34 characters long")
        return False
    
    try:
        # Test credentials
        client = Client(account_sid, auth_token)
        
        # Test 1: Get account information
        print("🧪 Test 1: Fetching account information...")
        account = client.api.accounts(account_sid).fetch()
        print(f"✅ Account Name: {account.friendly_name}")
        print(f"✅ Account Status: {account.status}")
        
        # Test 2: List phone numbers
        print("\n🧪 Test 2: Checking available phone numbers...")
        phone_numbers = client.incoming_phone_numbers.list(limit=5)
        
        if phone_numbers:
            print(f"✅ Found {len(phone_numbers)} phone number(s):")
            for number in phone_numbers:
                print(f"   📞 {number.phone_number} - {number.friendly_name}")
        else:
            print("⚠️  No phone numbers found in your account")
            print("   You need to purchase a phone number from Twilio Console")
        
        # Test 3: Check account balance (if available)
        try:
            balance = client.api.accounts(account_sid).balance.fetch()
            print(f"\n💰 Account Balance: {balance.balance} {balance.currency}")
        except Exception as e:
            print(f"\n⚠️  Could not fetch balance: {str(e)}")
        
        print("\n✅ Twilio credentials are valid!")
        return True
        
    except TwilioException as e:
        print(f"❌ Twilio API Error: {str(e)}")
        
        if "authenticate" in str(e).lower():
            print("\n🔧 Authentication Issues - Possible Causes:")
            print("   1. Incorrect Account SID or Auth Token")
            print("   2. Auth Token has been regenerated")
            print("   3. Account has been suspended")
            print("   4. API credentials have expired")
            
        elif "forbidden" in str(e).lower():
            print("\n🔧 Permission Issues - Possible Causes:")
            print("   1. Account doesn't have SMS permissions")
            print("   2. Trial account limitations")
            print("   3. Account needs verification")
            
        return False
        
    except Exception as e:
        print(f"❌ Unexpected Error: {str(e)}")
        return False

def get_fresh_credentials_guide():
    """Show how to get fresh Twilio credentials"""
    print("\n🔑 How to Get Fresh Twilio Credentials:")
    print("=" * 50)
    print("1. Go to: https://console.twilio.com")
    print("2. Log in to your Twilio account")
    print("3. On the dashboard, you'll see:")
    print("   - Account SID (starts with 'AC')")
    print("   - Auth Token (click 'Show' to reveal)")
    print("4. Copy both values exactly as shown")
    print("5. If Auth Token doesn't work, click 'Create new Auth Token'")
    print("\n📞 To get a phone number:")
    print("1. Go to Phone Numbers > Manage > Buy a number")
    print("2. Choose a number with SMS capabilities")
    print("3. Purchase the number")

def main():
    """Main function"""
    print("🚀 Twilio Credential Troubleshooter")
    print("This script will help diagnose authentication issues\n")
    
    if not test_twilio_credentials():
        get_fresh_credentials_guide()
        return False
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
