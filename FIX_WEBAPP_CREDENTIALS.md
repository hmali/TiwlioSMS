# 🚨 **FIXING WEB APP CREDENTIAL ISSUE**

## ✅ **Manual Test Works, Web App Doesn't**

Since your manual test works, the credentials are correct, but the web app isn't using them properly.

## 🔍 **Step 1: Diagnose the Issue**

Run this on your EC2 instance to check credential storage:

```bash
# On your EC2 instance
cd /opt/twilio-sms-app
source venv/bin/activate
python3 check_app_credentials.py
```

## 🛠️ **Step 2: Common Fixes**

### **Fix 1: Ensure Credentials Are Saved in Database**

1. **Access your web app:**
   ```
   http://YOUR_EC2_PUBLIC_IP
   ```

2. **Login:**
   - Username: `admin`
   - Password: `admin123`

3. **Go to Settings page and re-enter credentials:**
   - Account SID: `YOUR_WORKING_ACCOUNT_SID`
   - Auth Token: `YOUR_WORKING_AUTH_TOKEN`
   - Click "Save Configuration"

4. **Verify you see "Twilio credentials updated successfully!" message**

### **Fix 2: Check Database Manually**

```bash
# On EC2 instance
cd /opt/twilio-sms-app
sqlite3 twilio_sms.db

# Check if credentials are stored
.tables
SELECT id, username, twilio_sid, twilio_token FROM users;

# Exit sqlite
.quit
```

### **Fix 3: Force Update Credentials in Database**

If the web interface isn't saving properly, update directly:

```bash
# On EC2 instance
cd /opt/twilio-sms-app
source venv/bin/activate

python3 -c "
import sqlite3
conn = sqlite3.connect('twilio_sms.db')
cursor = conn.cursor()
cursor.execute('UPDATE users SET twilio_sid = ?, twilio_token = ? WHERE username = ?', 
               ('YOUR_ACCOUNT_SID', 'YOUR_AUTH_TOKEN', 'admin'))
conn.commit()
print(f'Updated {cursor.rowcount} row(s)')
conn.close()
"
```

### **Fix 4: Restart Application After Changes**

```bash
# Restart the web application
sudo systemctl restart twilio-sms-app

# Check if it's running
sudo systemctl status twilio-sms-app
```

### **Fix 5: Check Application Logs**

```bash
# Check for errors in the logs
sudo journalctl -u twilio-sms-app -f

# Or check error log file
sudo tail -f /var/log/twilio-sms-app/error.log
```

## 🧪 **Step 3: Test the Fix**

### **Test 1: Verify Settings Page**

1. Go to Settings in web app
2. You should see your Account SID displayed (partially masked)
3. The Auth Token field should show dots/asterisks

### **Test 2: Send Test SMS via Web App**

1. Create a test file:
   ```bash
   echo "+YOUR_PHONE_NUMBER" > /tmp/test.txt
   ```

2. In web app:
   - Go to "Send SMS"
   - Upload the test.txt file
   - Enter "Test from web app" as message
   - Use your Twilio number as "From" number
   - Send campaign

### **Test 3: Check Campaign Status**

1. Go to Dashboard
2. You should see the test campaign
3. Click "View" to see delivery status
4. Status should show "Completed" with 1 successful send

## 🔧 **Advanced Debugging**

### **Check Twilio Client Creation**

```bash
# On EC2 instance
cd /opt/twilio-sms-app
source venv/bin/activate

python3 -c "
import sys
sys.path.append('.')
from app import get_user_twilio_client

# Test getting client for admin user (ID=1)
client = get_user_twilio_client(1)
if client:
    print('✅ Client created successfully')
    try:
        account = client.api.accounts.list(limit=1)[0]
        print(f'✅ Account accessible: {account.friendly_name}')
    except Exception as e:
        print(f'❌ Client error: {e}')
else:
    print('❌ Failed to create client')
"
```

### **Check Session Management**

The web app uses sessions. Make sure you're logged in as the user who saved the credentials:

1. **Clear browser cache/cookies**
2. **Log out and log back in**
3. **Try from an incognito/private browser window**

### **Check File Permissions**

```bash
# Ensure the app can read/write the database
sudo chown -R www-data:www-data /opt/twilio-sms-app
sudo chmod 664 /opt/twilio-sms-app/twilio_sms.db
```

## 🚨 **Most Likely Causes**

1. **Credentials not saved:** Web interface didn't actually save to database
2. **Session issue:** User session doesn't match the user who saved credentials  
3. **Database permissions:** App can't read the database file
4. **Application not restarted:** Changes not picked up by running app

## ✅ **Quick Fix Command Sequence**

Run these commands on your EC2 instance:

```bash
# Navigate to app directory
cd /opt/twilio-sms-app
source venv/bin/activate

# Force update credentials (replace with your actual values)
python3 -c "
import sqlite3
conn = sqlite3.connect('twilio_sms.db')
cursor = conn.cursor()
cursor.execute('UPDATE users SET twilio_sid = ?, twilio_token = ? WHERE username = ?', 
               ('YOUR_ACTUAL_ACCOUNT_SID', 'YOUR_ACTUAL_AUTH_TOKEN', 'admin'))
conn.commit()
print('Credentials updated in database')
conn.close()
"

# Fix permissions
sudo chown -R www-data:www-data /opt/twilio-sms-app
sudo chmod 664 twilio_sms.db

# Restart application
sudo systemctl restart twilio-sms-app

# Verify it's running
sudo systemctl status twilio-sms-app
```

After running these commands, try sending a test SMS through the web interface again.

## 📞 **If Still Not Working**

Share the output of these commands:

```bash
# Check database contents
cd /opt/twilio-sms-app
sqlite3 twilio_sms.db "SELECT id, username, length(twilio_sid), length(twilio_token) FROM users;"

# Check application logs
sudo journalctl -u twilio-sms-app -n 20 --no-pager

# Test credential retrieval
source venv/bin/activate
python3 check_app_credentials.py
```

The issue should be resolved after forcing the credentials update and restarting the application.
