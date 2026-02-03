# 📋 TwilioSMS - Quick Reference Card

**Version:** 2.1.0 | **Date:** February 2, 2026

---

## 🚀 Installation

### One-Line Install
```bash
curl -O https://raw.githubusercontent.com/hmali/TiwlioSMS/main/install.sh && chmod +x install.sh && ./install.sh
```

### Manual Install
```bash
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 -c "from app import init_db; init_db()"
```

---

## 🔑 Default Credentials

**Username:** `admin`  
**Password:** `admin123`  
**⚠️ Change immediately after first login!**

---

## 🛠️ Service Management

| Action | Command |
|--------|---------|
| **Start** | `sudo systemctl start twiliosms` |
| **Stop** | `sudo systemctl stop twiliosms` |
| **Restart** | `sudo systemctl restart twiliosms` |
| **Status** | `sudo systemctl status twiliosms` |
| **Enable Auto-start** | `sudo systemctl enable twiliosms` |
| **Disable Auto-start** | `sudo systemctl disable twiliosms` |

---

## 📊 Monitoring

### View Logs
```bash
# Application logs (systemd)
sudo journalctl -u twiliosms -f

# Application logs (file)
tail -f ~/TiwlioSMS/twilio_sms.log

# Last 100 lines
sudo journalctl -u twiliosms -n 100

# Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### Health Check
```bash
# Quick health check
curl http://localhost/health

# Detailed check
systemctl is-active twiliosms nginx
```

---

## 🔄 Updates

### Update Application
```bash
cd ~/TiwlioSMS
source venv/bin/activate
git pull origin main
pip install -r requirements.txt
python3 scripts/migrate_db_v2.py  # If database changes
sudo systemctl restart twiliosms
```

### Update System Packages
```bash
sudo apt update && sudo apt upgrade -y
sudo systemctl restart twiliosms nginx
```

---

## 💾 Backup & Restore

### Manual Backup
```bash
# Backup database
cp ~/TiwlioSMS/twilio_sms.db ~/TiwlioSMS/backups/backup_$(date +%Y%m%d).db

# Backup entire application
tar -czf ~/twiliosms_backup_$(date +%Y%m%d).tar.gz ~/TiwlioSMS
```

### Restore Database
```bash
cp ~/TiwlioSMS/backups/backup_YYYYMMDD.db ~/TiwlioSMS/twilio_sms.db
sudo systemctl restart twiliosms
```

### Automated Daily Backup
```bash
# Run backup script
~/backup-twiliosms.sh

# Add to crontab (daily at 2 AM)
crontab -e
# Add: 0 2 * * * /home/YOUR_USERNAME/backup-twiliosms.sh
```

---

## 🌐 Nginx

| Action | Command |
|--------|---------|
| **Test Config** | `sudo nginx -t` |
| **Reload** | `sudo systemctl reload nginx` |
| **Restart** | `sudo systemctl restart nginx` |
| **Status** | `sudo systemctl status nginx` |
| **View Config** | `sudo nano /etc/nginx/sites-available/twiliosms` |

---

## 🔒 Security

### Setup HTTPS
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
sudo certbot renew --dry-run  # Test renewal
```

### Change Admin Password
1. Login to web interface
2. Settings → Change Credentials
3. Enter new password
4. Save

### Update Secret Key
```bash
# Generate new key
python3 -c "import secrets; print(secrets.token_hex(32))"

# Update service file
sudo nano /etc/systemd/system/twiliosms.service
# Replace SECRET_KEY= line

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart twiliosms
```

### Firewall Rules
```bash
# Check status
sudo ufw status

# Allow HTTP/HTTPS
sudo ufw allow 'Nginx Full'

# Allow SSH
sudo ufw allow OpenSSH

# Enable firewall
sudo ufw enable
```

---

## 🐛 Troubleshooting

### Service Won't Start
```bash
# Check logs
sudo journalctl -u twiliosms -xe

# Check if port 8000 is in use
sudo netstat -tlnp | grep 8000

# Verify paths
ls -la ~/TiwlioSMS/venv/bin/gunicorn
```

### Database Issues
```bash
# Check permissions
ls -la ~/TiwlioSMS/twilio_sms.db

# Fix permissions
chmod 644 ~/TiwlioSMS/twilio_sms.db
chown $USER:$USER ~/TiwlioSMS/twilio_sms.db

# Verify database
sqlite3 ~/TiwlioSMS/twilio_sms.db ".tables"
```

### Auto-Reply Not Working
```bash
# Test webhook
curl -X POST http://localhost/sms/inbound \
  -d "From=+1234567890" \
  -d "To=+1987654321" \
  -d "Body=Test"

# Check Twilio webhook config
# Should be: http://your-domain.com/sms/inbound (POST)

# View auto-reply logs
tail -f ~/TiwlioSMS/twilio_sms.log | grep "Inbound"
```

### Can't Access Web Interface
```bash
# Check if services are running
sudo systemctl status twiliosms nginx

# Test locally
curl http://localhost/health

# Check firewall
sudo ufw status

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

---

## 📁 File Locations

| Item | Location |
|------|----------|
| **Application** | `/home/YOUR_USERNAME/TiwlioSMS/` |
| **Database** | `/home/YOUR_USERNAME/TiwlioSMS/twilio_sms.db` |
| **Logs** | `/home/YOUR_USERNAME/TiwlioSMS/twilio_sms.log` |
| **Backups** | `/home/YOUR_USERNAME/TiwlioSMS/backups/` |
| **Service File** | `/etc/systemd/system/twiliosms.service` |
| **Nginx Config** | `/etc/nginx/sites-available/twiliosms` |
| **Virtual Env** | `/home/YOUR_USERNAME/TiwlioSMS/venv/` |

---

## 📞 API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Login page |
| `/login` | POST | Authenticate |
| `/dashboard` | GET | User dashboard |
| `/send_sms` | GET/POST | Create SMS campaign |
| `/campaign/<id>` | GET | Campaign status |
| `/api/campaign/<id>` | GET | Campaign status (JSON) |
| `/settings` | GET/POST | Twilio credentials |
| `/settings/auto-reply` | GET/POST | Auto-reply config |
| `/inbound_messages` | GET | View inbound SMS |
| `/sms/inbound` | POST | Twilio webhook |
| `/health` | GET | Health check |

---

## 🔧 Database Queries

```bash
# Open database
sqlite3 ~/TiwlioSMS/twilio_sms.db

# View tables
.tables

# Check campaigns
SELECT id, name, status, total_numbers FROM campaigns ORDER BY created_at DESC LIMIT 5;

# Check auto-reply message
SELECT * FROM settings WHERE setting_key='auto_reply_message';

# View recent inbound messages
SELECT from_number, message_body, intent, received_at FROM inbound_messages ORDER BY received_at DESC LIMIT 10;

# Check subscriber status
SELECT phone_number, status, opted_out_at FROM subscribers WHERE status='unsubscribed';

# View auto-reply intents
SELECT intent_name, keywords, priority FROM auto_reply_intents WHERE is_active=1 ORDER BY priority;

# Exit
.quit
```

---

## 📈 Performance

### Check Resource Usage
```bash
# CPU and Memory
top -u YOUR_USERNAME

# Disk usage
df -h /home

# Database size
ls -lh ~/TiwlioSMS/twilio_sms.db

# Log file size
ls -lh ~/TiwlioSMS/twilio_sms.log
```

### Optimize Database
```bash
sqlite3 ~/TiwlioSMS/twilio_sms.db "VACUUM;"
sqlite3 ~/TiwlioSMS/twilio_sms.db "ANALYZE;"
```

### Clear Old Logs
```bash
# Rotate logs (keep last 1000 lines)
tail -n 1000 ~/TiwlioSMS/twilio_sms.log > ~/TiwlioSMS/twilio_sms.log.tmp
mv ~/TiwlioSMS/twilio_sms.log.tmp ~/TiwlioSMS/twilio_sms.log
sudo systemctl restart twiliosms
```

---

## 🧪 Testing

### Test SMS Sending
1. Login to web interface
2. Create test CSV: `phone_number\n+1234567890`
3. Upload and send
4. Check campaign status

### Test Auto-Reply
```bash
# Send SMS to your Twilio number
# Should receive auto-reply

# Check logs
tail -f ~/TiwlioSMS/twilio_sms.log | grep "Inbound"
```

### Test STOP/START
```bash
# Send "STOP" to Twilio number
# Should receive unsubscribe confirmation

# Send "START" to Twilio number
# Should receive subscription confirmation
```

---

## 📚 Documentation

| Document | Location |
|----------|----------|
| **Installation Guide** | `INSTALLATION.md` |
| **Deployment Guide** | `DEPLOYMENT.md` |
| **Beginner's Guide** | `docs/guides/BEGINNER_GUIDE.md` |
| **Developer Guide** | `docs/guides/DEVELOPER_GUIDE.md` |
| **Auto-Reply Guide** | `docs/guides/AUTO_REPLY_ENHANCEMENT.md` |
| **Documentation Index** | `docs/INDEX.md` |
| **Changelog** | `CHANGELOG.md` |
| **README** | `README.md` |

---

## ⚡ Quick Fixes

### Reset Admin Password
```bash
cd ~/TiwlioSMS
source venv/bin/activate
python3 -c "
from werkzeug.security import generate_password_hash
import sqlite3
conn = sqlite3.connect('twilio_sms.db')
cursor = conn.cursor()
new_hash = generate_password_hash('admin123')
cursor.execute('UPDATE users SET password_hash=?, is_default_password=1 WHERE username=\"admin\"', (new_hash,))
conn.commit()
conn.close()
print('Admin password reset to: admin123')
"
```

### Clear All Campaigns
```bash
sqlite3 ~/TiwlioSMS/twilio_sms.db "DELETE FROM campaigns; DELETE FROM message_status;"
```

### Reset Auto-Reply Message
```bash
sqlite3 ~/TiwlioSMS/twilio_sms.db "UPDATE settings SET setting_value='Thank you for your message.' WHERE setting_key='auto_reply_message';"
```

---

## 🌟 Features (v2.1.0)

- ✅ Bulk SMS campaigns
- ✅ CSV file upload
- ✅ Auto-reply with custom messages
- ✅ STOP/START compliance (TCPA/CTIA)
- ✅ Intent-based auto-replies
- ✅ Subscriber management
- ✅ Campaign tracking
- ✅ Real-time status updates
- ✅ Inbound message logging
- ✅ Multi-user support
- ✅ Secure authentication
- ✅ Production-ready with Gunicorn
- ✅ Nginx reverse proxy support

---

## 📞 Support

For issues or questions:
1. Check logs: `sudo journalctl -u twiliosms -f`
2. Review documentation in `docs/` directory
3. Check `INSTALLATION.md` troubleshooting section

---

**Print this card for quick reference! 🖨️**

*Last Updated: February 2, 2026*
