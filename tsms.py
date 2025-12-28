from twilio.rest import Client
import time
import os
import sys

account_sid = ''
auth_token = ''
client = Client(account_sid, auth_token)

def read_phone_numbers_from_file(file_path):
    """
    Read phone numbers from a file.
    Supports multiple formats:
    - One number per line
    - Comma-separated numbers on single line
    - Mixed format
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read().strip()
            
        # Split by both newlines and commas, then clean up
        numbers = []
        for line in content.split('\n'):
            if ',' in line:
                # Handle comma-separated numbers in a line
                line_numbers = [num.strip() for num in line.split(',')]
                numbers.extend(line_numbers)
            else:
                # Handle single number per line
                number = line.strip()
                if number:
                    numbers.append(number)
        
        # Remove empty strings and duplicates while preserving order
        clean_numbers = []
        seen = set()
        for num in numbers:
            if num and num not in seen:
                clean_numbers.append(num)
                seen.add(num)
                
        return clean_numbers
        
    except FileNotFoundError:
        print(f"❌ Error: File '{file_path}' not found.")
        return None
    except Exception as e:
        print(f"❌ Error reading file: {str(e)}")
        return None

# Specify the phone numbers file path directly in the script
PHONE_NUMBERS_FILE = '/Users/hmali/Documents/GitHub/TiwlioSMS/phone_numbers.txt'

# Load phone numbers from the specified file
print(f"📞 Loading phone numbers from: {PHONE_NUMBERS_FILE}")
number_list = read_phone_numbers_from_file(PHONE_NUMBERS_FILE)

if not number_list:
    print(f"❌ Failed to load phone numbers from {PHONE_NUMBERS_FILE}")
    print("Please check if the file exists and contains valid phone numbers.")
    sys.exit(1)

print(f"✅ Successfully loaded {len(number_list)} phone numbers from file")

# SMS message content
sms_body = '''🙏💐🙏
Jai Gajanan Dear Devotees, 🙏
 
The most awaited and divinely cherished day in every Gajanan devotee's heart is approaching swiftly. Yes, we are blessed once again to celebrate the sacred and joyous occasion of "Gajanan Maharaj Prakat Din – 2026" (Magh Mahina, Krushna Saptami).

This is the holy day when our Sadguru Gajanan Maharaj compassionately appeared for His devotees, blessing the world with His eternal presence, grace, and guidance. Every devotee celebrates this day with deep devotion, immense joy, and heartfelt gratitude.
 

In 2026, this supremely auspicious day falls on Sunday, February 8th, and with immense joy and devotion, we cordially invite you and your family to Mauli's Temple
📍 420 Towne Center Drive, North Brunswick, NJ
to participate in the sacred "Gajanan Maharaj Prakat Din Sohala."


This divine celebration is a time for spiritual upliftment, collective devotion, and surrender at Mauli's lotus feet, as we gather to seek His blessings and experience His living presence among us.
To ensure smooth darshan and proper arrangements, darshan will be available by RSVP.
Without RSVP, additional waiting time for darshan may be required.

👉 Kindly RSVP here:
https://tinyurl.com/PrakatDin2026
Program Schedule (for each slot):
Gajanan Avahan, Puja & Archana
Maha-Naivadhyam
Maha-Aarti (devotees will have the blessed opportunity to offer Aarti)
We humbly look forward to your presence and blessings as we celebrate this sacred Prakat Din together, immersed in devotion and Mauli's grace.

🙏 Jai Gajanan 🙏'''

# Convert comma-separated string to list and remove whitespace
if not number_list:
    print("❌ No phone numbers provided. Exiting...")
    sys.exit(1)

print(f"\n📱 Phone numbers to send SMS:")
for i, num in enumerate(number_list, 1):
    print(f"   {i}. {num}")

# Confirmation before sending
print(f"\n📨 Ready to send SMS to {len(number_list)} numbers")
confirm = input("Do you want to proceed? (yes/y to confirm): ").strip().lower()

if confirm not in ['yes', 'y']:
    print("❌ SMS sending cancelled by user.")
    sys.exit(0)

print(f"Sending SMS to {len(number_list)} numbers...")
print("=" * 50)

successful_sends = 0
failed_sends = 0

# Send SMS to each number in the list
for i, phone_number in enumerate(number_list, 1):
    try:
        print(f"Sending to {phone_number} ({i}/{len(number_list)})...")
        
        message = client.messages.create(
            from_='+18042077514',
            body=sms_body,
            to=phone_number
        )
        
        print(f"✅ Success! Message SID: {message.sid}")
        successful_sends += 1
        
        # Add a small delay between messages to avoid rate limiting
        if i < len(number_list):
            time.sleep(1)
            
    except Exception as e:
        print(f"❌ Failed to send to {phone_number}: {str(e)}")
        failed_sends += 1

print("=" * 50)
print(f"📊 Summary:")
print(f"   Successful: {successful_sends}")
print(f"   Failed: {failed_sends}")
print(f"   Total: {len(number_list)}")


