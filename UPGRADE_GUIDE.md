# 🚀 Quick Upgrade Guide - TwilioSMS Production

## ⚡ ONE-COMMAND UPGRADE

### **Method 1: Direct on Server (Recommended)**
```bash
# SSH to production server
ssh username@your-server.com

# Download and run upgrade script
cd ~/TiwlioSMS
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/dev/twilioms-test/upgrade_production.sh
chmod +x upgrade_production.sh
./upgrade_production.sh
```

### **Method 2: From Local Machine**
```bash
# Download script
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/dev/twilioms-test/upgrade_production.sh

# Run on remote server via SSH
ssh username@your-server.com 'bash -s' < upgrade_production.sh
```

### **Method 3: If Already Installed**
```bash
# If script already exists in application directory
cd ~/TiwlioSMS
./upgrade_production.sh
```

---

## 📋 What the Script Does

### **Automatic Steps:**
1. ✅ Pre-flight checks (service exists, database present)
2. ✅ Backs up database to `backups/` directory
3. ✅ Backs up current code (git commit hash)
4. ✅ Stops application service safely
5. ✅ Pulls latest code from GitHub
6. ✅ Updates Python dependencies
7. ✅ Runs database migration
8. ✅ Fixes file permissions
9. ✅ Starts application service
10. ✅ Runs health checks (HTTP, database, syntax)
11. ✅ **Automatic rollback if anything fails!**

### **Safety Features:**
- 🔒 Automatic backup before any changes
- 🔄 One-click rollback if upgrade fails
- 🏥 Health checks after deployment
- 📊 Detailed progress logging
- ⚠️ Error detection and handling

---

## 🎯 Example Usage

### **Typical Upgrade Session:**
```bash
# 1. SSH to server
ssh admin@smsgajanannj.com

# 2. Navigate to application
cd ~/TiwlioSMS

# 3. Run upgrade (if script exists)
./upgrade_production.sh

# OR download first
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/dev/twilioms-test/upgrade_production.sh
chmod +x upgrade_production.sh
./upgrade_production.sh
```

### **Expected Output:**
```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        TwilioSMS v2.1.1 Production Upgrade Script             ║
║        Safe Deployment with Automatic Rollback                ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

Upgrade Details:
  Application: TwilioSMS v2.1.1
  Directory:   /home/admin/TiwlioSMS
  Service:     twiliosms
  Branch:      dev/twilioms-test
  Timestamp:   Sun Feb  9 14:30:00 EST 2026

Continue with upgrade? [y/N]: y

▶ Running pre-flight checks...
✔ Pre-flight checks passed

▶ Creating backups...
ℹ Backing up database...
✔ Database backed up: backups/twilio_sms.db.backup_20260209_143000
ℹ Backing up current code...
✔ Code backed up at commit: 8ea65ae
✔ Backup complete

▶ Stopping application service...
✔ Service stopped

▶ Updating application code...
ℹ Fetching from GitHub...
ℹ Changes to be applied:
8ea65ae - Docs: Add comprehensive status report
d7cf003 - Docs: Add comprehensive documentation for custom 1:1 reply
✔ Code updated successfully

▶ Updating Python dependencies...
ℹ Upgrading pip...
ℹ Installing requirements...
✔ Dependencies updated

▶ Running database migration...
ℹ Executing migration script...
✔ Database migration complete

▶ Fixing file permissions...
✔ Permissions fixed

▶ Starting application service...
✔ Service started successfully

▶ Running health checks...
ℹ 1. Checking service status...
✔ Service is running
ℹ 2. Checking HTTP response...
✔ Application responding (HTTP 200)
ℹ 3. Checking database...
✔ Database accessible
ℹ 4. Checking Python syntax...
✔ Python code valid
ℹ 5. Checking template files...
✔ Templates present
✔ All health checks passed ✓

▶ Upgrade Summary

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              ✅  UPGRADE COMPLETED SUCCESSFULLY               ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

ℹ What was updated:
8ea65ae - Docs: Add comprehensive status report
d7cf003 - Docs: Add comprehensive documentation for custom 1:1 reply
34fe778 - Feature: Add custom 1:1 reply to inbound messages

ℹ New Features in v2.1.1:
  ✅ Custom 1:1 reply to inbound messages
  ✅ Enhanced auto-reply with intent detection
  ✅ Subscriber management dashboard
  ✅ Improved STOP/START compliance

ℹ Next Steps:
  1. Access: http://your-domain.com
  2. Login with admin credentials
  3. Test Inbound Messages → Reply feature
  4. Monitor logs: sudo journalctl -u twiliosms -f

ℹ Backup Location:
  Database: backups/twilio_sms.db.backup_20260209_143000
  All backups: backups/

✔ Upgrade complete! 🎉
```

---

## ⚙️ Configuration Options

### **Custom Installation Directory:**
```bash
# If installed in different location
export APP_DIR=/opt/twiliosms
./upgrade_production.sh
```

### **Custom Service Name:**
```bash
# Edit script if service has different name
nano upgrade_production.sh
# Change: SERVICE_NAME="twiliosms"
# To:     SERVICE_NAME="your-service-name"
```

---

## 🐛 Troubleshooting

### **Problem: Script Not Found**
```bash
# Download it fresh
cd ~/TiwlioSMS
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/dev/twilioms-test/upgrade_production.sh
chmod +x upgrade_production.sh
```

### **Problem: Permission Denied**
```bash
# Make executable
chmod +x upgrade_production.sh

# Don't run with sudo!
./upgrade_production.sh  # Correct
sudo ./upgrade_production.sh  # Wrong!
```

### **Problem: Upgrade Failed & Rolled Back**
```bash
# Check the error logs
sudo journalctl -u twiliosms -n 50

# Try manual update
cd ~/TiwlioSMS
git pull origin dev/twilioms-test
sudo systemctl restart twiliosms
```

### **Problem: Health Check Failed**
```bash
# Check service status
sudo systemctl status twiliosms

# Check application logs
tail -50 ~/TiwlioSMS/twilio_sms.log

# Restart service
sudo systemctl restart twiliosms
```

---

## 🔄 Manual Rollback

If you need to manually rollback:

```bash
# 1. Stop service
sudo systemctl stop twiliosms

# 2. List backups
ls -lh ~/TiwlioSMS/backups/

# 3. Restore database
cd ~/TiwlioSMS
cp backups/twilio_sms.db.backup_YYYYMMDD_HHMMSS twilio_sms.db

# 4. Restore code (find commit hash)
cat backups/last_commit_YYYYMMDD_HHMMSS.txt
git reset --hard COMMIT_HASH

# 5. Restart
sudo systemctl start twiliosms
```

---

## 📊 Post-Upgrade Verification

### **1. Check Service Status:**
```bash
sudo systemctl status twiliosms
# Should show: active (running)
```

### **2. Check Application Logs:**
```bash
tail -30 ~/TiwlioSMS/twilio_sms.log
# Should not show recent errors
```

### **3. Test Web Interface:**
```bash
curl -I http://localhost:8000
# Should return: HTTP/1.1 200 OK or 302
```

### **4. Test Custom Reply Feature:**
1. Open browser: `http://your-domain.com`
2. Login with credentials
3. Go to "Inbound Messages"
4. Click "Reply" button on any message
5. Verify form expands with character counter
6. (Optional) Send a test reply

---

## 📅 When to Upgrade

### **Immediate Upgrade Recommended If:**
- 🔴 Security patches released
- 🔴 Critical bug fixes available
- 🔴 Production issues identified

### **Schedule Upgrade If:**
- 🟡 New features available
- 🟡 Performance improvements
- 🟡 Minor bug fixes

### **Best Practice:**
- ⚡ Upgrade during low-traffic hours
- ⚡ Test in staging first (if available)
- ⚡ Have rollback plan ready
- ⚡ Monitor for 15-30 minutes after upgrade

---

## 🔒 Security Notes

### **The script is safe because:**
- ✅ Creates automatic backups
- ✅ Runs as non-root user
- ✅ Validates before applying changes
- ✅ Automatic rollback on failure
- ✅ Health checks after deployment
- ✅ No destructive operations without confirmation

### **What gets backed up:**
- ✅ Database file (`twilio_sms.db`)
- ✅ Git commit hash (for code rollback)
- ✅ Environment files (if present)

### **Backups are kept:**
- 📁 Location: `~/TiwlioSMS/backups/`
- 📅 Retention: Last 10 backups
- 🔐 Owner: Your user account

---

## 💡 Pro Tips

### **Tip 1: Monitor During Upgrade**
```bash
# In separate terminal, watch logs
ssh username@server
sudo journalctl -u twiliosms -f
```

### **Tip 2: Test Before Production**
```bash
# If you have staging server
ssh staging-server
./upgrade_production.sh
# Test thoroughly, then upgrade production
```

### **Tip 3: Schedule Regular Upgrades**
```bash
# Add to crontab for weekly check (doesn't auto-upgrade)
# 0 2 * * 0 cd /home/admin/TiwlioSMS && git fetch origin dev/twilioms-test
```

### **Tip 4: Keep Backups Safe**
```bash
# Periodically copy backups offsite
scp username@server:~/TiwlioSMS/backups/*.db ~/local-backups/
```

---

## 📞 Support

### **If Upgrade Fails:**
1. **Don't panic** - automatic rollback should restore service
2. **Check logs**: `sudo journalctl -u twiliosms -n 100`
3. **Try manual steps** from DEPLOYMENT_GUIDE.md
4. **Contact support** with error logs

### **Documentation:**
- Full Guide: `DEPLOYMENT_GUIDE.md`
- Feature Docs: `CUSTOM_REPLY_FEATURE.md`
- Status Report: `STATUS_REPORT.md`

### **Contact:**
- GitHub Issues: https://github.com/hmali/TiwlioSMS/issues
- Email: support@gmadp.org

---

## ✅ Upgrade Checklist

```
BEFORE UPGRADE:
□ Latest code pushed to GitHub
□ Tested locally or in staging
□ Low-traffic time scheduled
□ Backup server access verified
□ Team notified of maintenance window

DURING UPGRADE:
□ Script downloaded and executable
□ Upgrade initiated
□ Progress monitored
□ Logs checked for errors

AFTER UPGRADE:
□ Service running (systemctl status)
□ Web interface accessible
□ Login working
□ Inbound messages page loads
□ Custom reply feature tested
□ Logs clean (no errors)
□ Team notified of completion

IF ISSUES:
□ Rollback completed
□ Previous version verified working
□ Error logs collected
□ Support contacted if needed
```

---

**Last Updated:** February 9, 2026  
**Script Version:** 2.1.1  
**Tested On:** Ubuntu 20.04/22.04 LTS  
**Status:** ✅ Production Ready
