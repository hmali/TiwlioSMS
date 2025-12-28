# 🚀 **DEPLOYMENT UPDATE GUIDE**

## 📋 **What's New in This Update**

- ✅ **User Management**: Change username and password
- ✅ **Security Warnings**: Alert for default credentials
- ✅ **Enhanced Settings**: Better UI for account management
- ✅ **Password Strength Checker**: Real-time password validation
- ✅ **Improved Security**: Better credential management

---

## 🎯 **Quick Deployment (Recommended)**

### **Step 1: Upload Files to EC2**

```bash
# From your Mac terminal
scp -i "your-key-pair.pem" -r /Users/hmali/Documents/GitHub/TiwlioSMS/* ubuntu@YOUR_EC2_IP:~/app-update/
```

### **Step 2: Deploy Updates**

```bash
# SSH into EC2
ssh -i "your-key-pair.pem" ubuntu@YOUR_EC2_IP

# Navigate to uploaded files
cd ~/app-update

# Run deployment script
sudo ./deploy-update.sh
```

---

## 🔧 **Manual Deployment (Step-by-Step)**

### **Step 1: Backup Current Application**

```bash
# SSH into your EC2 instance
ssh -i "your-key-pair.pem" ubuntu@YOUR_EC2_IP

# Create backup
sudo cp -r /opt/twilio-sms-app /opt/twilio-sms-app-backup-$(date +%Y%m%d)
```

### **Step 2: Stop Application Service**

```bash
# Stop the service
sudo systemctl stop twilio-sms-app

# Verify it's stopped
sudo systemctl status twilio-sms-app
```

### **Step 3: Upload and Replace Files**

```bash
# Upload from your Mac (from another terminal)
scp -i "your-key-pair.pem" /Users/hmali/Documents/GitHub/TiwlioSMS/app.py ubuntu@YOUR_EC2_IP:~/
scp -i "your-key-pair.pem" -r /Users/hmali/Documents/GitHub/TiwlioSMS/templates ubuntu@YOUR_EC2_IP:~/
scp -i "your-key-pair.pem" -r /Users/hmali/Documents/GitHub/TiwlioSMS/static ubuntu@YOUR_EC2_IP:~/

# Back on EC2, copy files
sudo cp ~/app.py /opt/twilio-sms-app/
sudo cp -r ~/templates/* /opt/twilio-sms-app/templates/
sudo cp -r ~/static/* /opt/twilio-sms-app/static/
```

### **Step 4: Set Permissions**

```bash
# Fix ownership and permissions
sudo chown -R www-data:www-data /opt/twilio-sms-app
sudo chmod -R 755 /opt/twilio-sms-app
```

### **Step 5: Update Dependencies (if needed)**

```bash
# Activate virtual environment and update
cd /opt/twilio-sms-app
sudo -u www-data bash -c "source venv/bin/activate && pip install --upgrade pip"
```

### **Step 6: Start Application**

```bash
# Start the service
sudo systemctl start twilio-sms-app

# Check status
sudo systemctl status twilio-sms-app

# Check logs if there are issues
sudo journalctl -u twilio-sms-app -f
```

---

## ✅ **Verify Deployment**

### **1. Check Service Status**

```bash
# Service should be active (running)
sudo systemctl status twilio-sms-app
```

### **2. Test Web Access**

```bash
# Get your EC2 public IP
curl http://169.254.169.254/latest/meta-data/public-ipv4

# Test web access
curl -I http://YOUR_EC2_IP
```

### **3. Test New Features**

1. **Access the app**: `http://YOUR_EC2_IP`
2. **Login with**: `admin` / `admin123`
3. **Look for security warning** on dashboard
4. **Go to Settings** - should show current username
5. **Try "Change Credentials"** link

---

## 🔍 **What You'll See After Update**

### **Dashboard Changes**
- Security warning banner for default admin user
- Username indicator in navigation with warning badge

### **Settings Page Changes**
- Account Information section showing current username
- Link to change credentials
- Improved Twilio configuration section

### **New Page: Change Credentials**
- Form to change username and password
- Password strength checker
- Security validation
- Automatic logout after change

---

## 🛠️ **Troubleshooting**

### **Service Won't Start**

```bash
# Check detailed logs
sudo journalctl -u twilio-sms-app -n 50

# Try running manually
cd /opt/twilio-sms-app
sudo -u www-data bash -c "source venv/bin/activate && python3 app.py"
```

### **Template Errors**

```bash
# Check if all template files exist
ls -la /opt/twilio-sms-app/templates/
# Should include: change_credentials.html

# Check file permissions
sudo chown -R www-data:www-data /opt/twilio-sms-app/templates/
```

### **Database Issues**

```bash
# Reinitialize database if needed
cd /opt/twilio-sms-app
sudo -u www-data bash -c "source venv/bin/activate && python3 -c 'from app import init_db; init_db()'"
```

### **Rollback if Needed**

```bash
# Stop current service
sudo systemctl stop twilio-sms-app

# Restore backup
sudo rm -rf /opt/twilio-sms-app
sudo mv /opt/twilio-sms-app-backup-YYYYMMDD /opt/twilio-sms-app

# Restart service
sudo systemctl start twilio-sms-app
```

---

## 🔒 **Post-Deployment Security Steps**

### **1. Change Default Credentials**

1. Access your app at `http://YOUR_EC2_IP`
2. Login with `admin` / `admin123`
3. Click the warning banner or go to Settings
4. Click "Change Username & Password"
5. Set secure credentials
6. You'll be logged out - login with new credentials

### **2. Update Twilio Settings**

1. Go to Settings page
2. Verify Twilio credentials are saved
3. Test SMS functionality

### **3. Test Everything**

1. Create a test campaign with your phone number
2. Send a test message
3. Verify message delivery
4. Check campaign status page

---

## 📋 **Summary Commands**

```bash
# Quick deployment (all in one)
scp -i "your-key-pair.pem" -r /Users/hmali/Documents/GitHub/TiwlioSMS/* ubuntu@YOUR_EC2_IP:~/app-update/ && \
ssh -i "your-key-pair.pem" ubuntu@YOUR_EC2_IP "cd ~/app-update && sudo ./deploy-update.sh"

# Or manual step by step
ssh -i "your-key-pair.pem" ubuntu@YOUR_EC2_IP
sudo systemctl stop twilio-sms-app
sudo cp -r /opt/twilio-sms-app /opt/twilio-sms-app-backup-$(date +%Y%m%d)
# ... copy files ...
sudo chown -R www-data:www-data /opt/twilio-sms-app
sudo systemctl start twilio-sms-app
```

**🎉 Your updated Twilio Bulk SMS app with user management is now deployed!**
