# 🚀 Production Deployment Guide - TwilioSMS v2.1.1

**How to Push Updated Code to Production VM**

---

## 📋 DEPLOYMENT OPTIONS

### **Option 1: Git Pull (Recommended - Zero Downtime)**
### **Option 2: Fresh Installation (For new servers)**
### **Option 3: Manual File Transfer (Not recommended)**

---

## ⚡ OPTION 1: Git Pull Deployment (Recommended)

This is the **fastest and safest** way to deploy updates to your existing production server.

### **📝 Prerequisites:**
- ✅ Production server already running TwilioSMS
- ✅ SSH access to production server
- ✅ Code already pushed to GitHub (`dev/twilioms-test` branch)

---

### **🔄 Step-by-Step Deployment:**

#### **Step 1: SSH into Production Server**
```bash
# Replace with your actual server details
ssh username@your-server.com
# OR
ssh username@123.45.67.89
```

#### **Step 2: Navigate to Application Directory**
```bash
cd ~/TiwlioSMS
# OR wherever you installed it
cd /home/yourusername/TiwlioSMS
```

#### **Step 3: Backup Current Database (Important!)**
```bash
# Create backup directory if it doesn't exist
mkdir -p backups

# Backup database with timestamp
cp twilio_sms.db backups/twilio_sms.db.backup_$(date +%Y%m%d_%H%M%S)

# Verify backup was created
ls -lh backups/
```

#### **Step 4: Stop the Application Service**
```bash
sudo systemctl stop twiliosms
```

#### **Step 5: Pull Latest Code from GitHub**
```bash
# Make sure you're on the correct branch
git branch

# Pull the latest changes
git pull origin dev/twilioms-test
```

**Expected Output:**
```
From https://github.com/hmali/TiwlioSMS
 * branch            dev/twilioms-test -> FETCH_HEAD
Updating 34fe778..8ea65ae
Fast-forward
 CUSTOM_REPLY_FEATURE.md | 431 ++++++++++++++++++++++
 FEATURE_DEMO.md         | 400 ++++++++++++++++++++
 README.md               |   8 +-
 STATUS_REPORT.md        | 418 +++++++++++++++++++++
 4 files changed, 1254 insertions(+), 3 deletions(-)
```

#### **Step 6: Update Python Dependencies (if needed)**
```bash
# Activate virtual environment
source venv/bin/activate

# Update dependencies
pip install -r requirements.txt --upgrade
```

#### **Step 7: Run Database Migration (if needed)**
```bash
# Check if migration is needed
python3 scripts/migrate_db_v2.1.1.py
```

**Note:** The migration script is safe to run multiple times - it only adds missing columns/tables.

#### **Step 8: Set Proper Permissions**
```bash
# Ensure correct ownership
sudo chown -R $USER:www-data ~/TiwlioSMS

# Ensure database is writable
chmod 664 twilio_sms.db

# Ensure database directory is writable
chmod 775 .
```

#### **Step 9: Start the Application Service**
```bash
sudo systemctl start twiliosms
```

#### **Step 10: Verify Deployment**
```bash
# Check service status
sudo systemctl status twiliosms

# View recent logs
sudo journalctl -u twiliosms -n 50

# Check application logs
tail -f twilio_sms.log
```

#### **Step 11: Test the Application**
```bash
# Test from command line
curl -I http://localhost:8000

# Expected: HTTP/1.1 200 OK or 302 Found (redirect to login)
```

#### **Step 12: Test in Browser**
1. Open browser: `http://your-domain.com`
2. Login with admin credentials
3. Navigate to "Inbound Messages"
4. Verify "Reply" buttons are visible
5. Test sending a custom reply

---

## 📊 QUICK DEPLOYMENT SCRIPT

Copy and paste this **one-command deployment**:

```bash
# Connect to server and deploy in one go
ssh username@your-server.com 'cd ~/TiwlioSMS && \
  mkdir -p backups && \
  cp twilio_sms.db backups/twilio_sms.db.backup_$(date +%Y%m%d_%H%M%S) && \
  sudo systemctl stop twiliosms && \
  git pull origin dev/twilioms-test && \
  source venv/bin/activate && \
  pip install -r requirements.txt --upgrade && \
  python3 scripts/migrate_db_v2.1.1.py && \
  chmod 664 twilio_sms.db && \
  sudo systemctl start twiliosms && \
  sudo systemctl status twiliosms --no-pager'
```

**Replace:** `username@your-server.com` with your actual details

---

## 🆕 OPTION 2: Fresh Installation (New Server)

If deploying to a **brand new server**, use the automated installer:

### **Step 1: Connect to New Server**
```bash
ssh username@new-server.com
```

### **Step 2: Run One-Command Installer**
```bash
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/dev/twilioms-test/install_production.sh
sudo bash install_production.sh
```

### **Step 3: Follow Interactive Prompts**
- Enter domain name
- Choose installation directory
- Enable HTTPS (y/n)
- Enable firewall (y/n)

### **Step 4: Configure Twilio Credentials**
1. Access: `http://your-domain.com`
2. Login: `admin` / `admin123`
3. Go to Settings → Twilio Credentials
4. Enter SID, Token, Phone Number
5. Save

---

## 🔍 VERIFICATION CHECKLIST

After deployment, verify everything works:

### **✅ Service Status:**
```bash
sudo systemctl status twiliosms
# Should show: active (running)
```

### **✅ Application Accessible:**
```bash
curl -I http://localhost:8000
# Should return: HTTP/1.1 200 OK or 302
```

### **✅ Nginx Working:**
```bash
sudo systemctl status nginx
# Should show: active (running)
```

### **✅ Database Accessible:**
```bash
sqlite3 twilio_sms.db "SELECT COUNT(*) FROM users;"
# Should return a number (at least 1)
```

### **✅ Logs Clean:**
```bash
tail -30 twilio_sms.log
# Should not show recent errors
```

### **✅ Custom Reply Feature:**
1. Login to dashboard
2. Go to "Inbound Messages"
3. Verify "Reply" buttons visible
4. Click "Reply" on any message
5. Verify form expands with character counter
6. (Optional) Send a test reply

---

## 🐛 TROUBLESHOOTING

### **Problem: Git Pull Shows Conflicts**
```bash
# Stash local changes
git stash

# Pull updates
git pull origin dev/twilioms-test

# Apply stashed changes (if needed)
git stash pop
```

### **Problem: Service Won't Start**
```bash
# Check detailed error logs
sudo journalctl -u twiliosms -xe

# Check Python syntax errors
cd ~/TiwlioSMS
source venv/bin/activate
python3 -c "import app"

# Restart service
sudo systemctl restart twiliosms
```

### **Problem: Database Locked**
```bash
# Stop service
sudo systemctl stop twiliosms

# Check file permissions
ls -lh twilio_sms.db

# Fix permissions
chmod 664 twilio_sms.db
chown $USER:www-data twilio_sms.db

# Start service
sudo systemctl start twiliosms
```

### **Problem: 502 Bad Gateway**
```bash
# Check if application is running
sudo systemctl status twiliosms

# Check Nginx configuration
sudo nginx -t

# Restart both services
sudo systemctl restart twiliosms
sudo systemctl restart nginx
```

### **Problem: Custom Reply Not Working**
```bash
# Check if latest code deployed
cd ~/TiwlioSMS
git log --oneline -5
# Should show commits: 8ea65ae, d7cf003, 34fe778

# Check if template updated
grep -n "send_custom_reply" templates/inbound_messages.html
# Should return line numbers

# Restart to reload templates
sudo systemctl restart twiliosms
```

---

## 🔄 ROLLBACK PROCEDURE

If something goes wrong, rollback to previous version:

### **Step 1: Stop Service**
```bash
sudo systemctl stop twiliosms
```

### **Step 2: Restore Database Backup**
```bash
# List available backups
ls -lh backups/

# Restore latest backup
cp backups/twilio_sms.db.backup_20260209_143000 twilio_sms.db
```

### **Step 3: Revert Code to Previous Commit**
```bash
# View recent commits
git log --oneline -10

# Revert to previous commit (replace COMMIT_HASH)
git reset --hard COMMIT_HASH

# Example:
git reset --hard 34fe778
```

### **Step 4: Restart Service**
```bash
sudo systemctl start twiliosms
sudo systemctl status twiliosms
```

---

## 📊 DEPLOYMENT MONITORING

### **Watch Logs in Real-Time:**
```bash
# Application logs
tail -f ~/TiwlioSMS/twilio_sms.log

# Service logs
sudo journalctl -u twiliosms -f

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### **Monitor Service Status:**
```bash
# Check service status every 5 seconds
watch -n 5 'sudo systemctl status twiliosms --no-pager'

# Monitor resource usage
htop

# Check disk space
df -h
```

---

## 🔐 SECURITY CHECKLIST

After deployment, verify security:

### **✅ File Permissions:**
```bash
# Application directory
ls -ld ~/TiwlioSMS
# Should be: drwxr-xr-x (755)

# Database file
ls -l ~/TiwlioSMS/twilio_sms.db
# Should be: -rw-rw-r-- (664)

# Virtual environment
ls -ld ~/TiwlioSMS/venv
# Should be: drwxr-xr-x (755)
```

### **✅ Firewall:**
```bash
sudo ufw status
# Should show: 22/tcp, 80/tcp, 443/tcp ALLOW
```

### **✅ HTTPS:**
```bash
# Verify SSL certificate
sudo certbot certificates

# Test HTTPS
curl -I https://your-domain.com
```

### **✅ Change Default Credentials:**
1. Login to dashboard
2. Settings → Change Credentials
3. Update admin password
4. Save changes

---

## 📅 DEPLOYMENT CHECKLIST

Print and use this checklist for each deployment:

```
PRE-DEPLOYMENT:
□ Code pushed to GitHub (dev/twilioms-test branch)
□ Local testing completed
□ Documentation updated
□ Git status clean (no uncommitted changes)

DEPLOYMENT:
□ SSH into production server
□ Navigate to application directory
□ Create database backup
□ Stop twiliosms service
□ Pull latest code from GitHub
□ Update Python dependencies
□ Run database migration
□ Set proper permissions
□ Start twiliosms service
□ Check service status
□ Review logs for errors

POST-DEPLOYMENT:
□ Test login functionality
□ Test inbound messages page
□ Test custom reply feature
□ Verify Twilio webhook working
□ Check campaign functionality
□ Monitor logs for 15 minutes
□ Notify team of deployment

DOCUMENTATION:
□ Update version number
□ Document changes made
□ Note any issues encountered
□ Update runbook if needed
```

---

## 🚨 EMERGENCY CONTACTS

**If deployment fails:**

1. **Rollback immediately** (see Rollback Procedure above)
2. **Check logs** for error messages
3. **Contact support:**
   - GitHub Issues: https://github.com/hmali/TiwlioSMS/issues
   - Email: support@gmadp.org

---

## 📈 DEPLOYMENT BEST PRACTICES

### **✅ DO:**
- Always backup database before deployment
- Test in staging environment first (if available)
- Deploy during low-traffic hours
- Monitor logs after deployment
- Have rollback plan ready
- Document changes

### **❌ DON'T:**
- Deploy during peak hours
- Skip database backup
- Deploy untested code
- Ignore warning messages
- Forget to restart service
- Leave default credentials

---

## 🎯 QUICK REFERENCE COMMANDS

### **Connect to Server:**
```bash
ssh username@your-server.com
```

### **Deploy Updates:**
```bash
cd ~/TiwlioSMS && \
git pull origin dev/twilioms-test && \
sudo systemctl restart twiliosms
```

### **Check Status:**
```bash
sudo systemctl status twiliosms
```

### **View Logs:**
```bash
tail -f ~/TiwlioSMS/twilio_sms.log
```

### **Restart Service:**
```bash
sudo systemctl restart twiliosms
```

### **Backup Database:**
```bash
cp twilio_sms.db backups/backup_$(date +%Y%m%d).db
```

---

## 📞 SUPPORT

**Documentation:**
- Main README: `/README.md`
- Feature Guide: `/CUSTOM_REPLY_FEATURE.md`
- Status Report: `/STATUS_REPORT.md`

**Help:**
- GitHub: https://github.com/hmali/TiwlioSMS
- Issues: https://github.com/hmali/TiwlioSMS/issues

---

**Last Updated:** February 9, 2026  
**Version:** 2.1.1 Hotfix  
**Branch:** dev/twilioms-test
