# 🚀 QUICK DEPLOYMENT REFERENCE

**TwilioSMS v2.1.1 - Production Deployment**

---

## 📦 OPTION 1: Automated Script (Easiest)

### **On Your Production Server:**
```bash
# 1. SSH into server
ssh username@your-server.com

# 2. Navigate to app directory
cd ~/TiwlioSMS

# 3. Pull the deployment script
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/dev/twilioms-test/deploy_update.sh

# 4. Make it executable
chmod +x deploy_update.sh

# 5. Run deployment
bash deploy_update.sh
```

**Done!** The script will:
- ✅ Backup database
- ✅ Stop service
- ✅ Pull latest code
- ✅ Update dependencies
- ✅ Run migration
- ✅ Restart service

---

## ⚡ OPTION 2: Manual Commands (Fast)

```bash
# Connect to server
ssh username@your-server.com

# Run this one-liner
cd ~/TiwlioSMS && \
  cp twilio_sms.db backups/backup_$(date +%Y%m%d).db && \
  sudo systemctl stop twiliosms && \
  git pull origin dev/twilioms-test && \
  source venv/bin/activate && \
  pip install -r requirements.txt && \
  sudo systemctl start twiliosms
```

---

## 📋 OPTION 3: Step-by-Step (Safest)

```bash
# 1. Connect
ssh username@your-server.com

# 2. Go to directory
cd ~/TiwlioSMS

# 3. Backup database
cp twilio_sms.db backups/backup_$(date +%Y%m%d).db

# 4. Stop service
sudo systemctl stop twiliosms

# 5. Pull updates
git pull origin dev/twilioms-test

# 6. Update dependencies (optional)
source venv/bin/activate
pip install -r requirements.txt

# 7. Run migration (optional)
python3 scripts/migrate_db_v2.1.1.py

# 8. Start service
sudo systemctl start twiliosms

# 9. Check status
sudo systemctl status twiliosms
```

---

## ✅ VERIFY DEPLOYMENT

```bash
# Check service is running
sudo systemctl status twiliosms

# View logs
tail -f twilio_sms.log

# Test in browser
# Open: http://your-domain.com
# Login and go to "Inbound Messages"
# Verify "Reply" buttons are visible
```

---

## 🔄 ROLLBACK (If Needed)

```bash
# Stop service
sudo systemctl stop twiliosms

# Restore database
cp backups/backup_20260209.db twilio_sms.db

# Revert code
git reset --hard HEAD~1

# Start service
sudo systemctl start twiliosms
```

---

## 🆘 TROUBLESHOOTING

### **Service won't start:**
```bash
sudo journalctl -u twiliosms -xe
```

### **Database locked:**
```bash
sudo systemctl stop twiliosms
chmod 664 twilio_sms.db
sudo systemctl start twiliosms
```

### **502 Bad Gateway:**
```bash
sudo systemctl restart twiliosms
sudo systemctl restart nginx
```

---

## 📞 USEFUL COMMANDS

| Action | Command |
|--------|---------|
| View logs | `sudo journalctl -u twiliosms -f` |
| Restart | `sudo systemctl restart twiliosms` |
| Status | `sudo systemctl status twiliosms` |
| App logs | `tail -f ~/TiwlioSMS/twilio_sms.log` |

---

## 🔗 FULL DOCUMENTATION

**Comprehensive Guide:** `/DEPLOYMENT_GUIDE.md`

---

**Last Updated:** February 9, 2026  
**Version:** v2.1.1 Hotfix
