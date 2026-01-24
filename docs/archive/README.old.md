# TwilioSMS GMADP

**Production-Ready Bulk SMS Communication Platform**  
Version 2.0

---

## 🚀 Quick Start

```bash
# Install dependencies
pip3 install -r requirements.txt

# Initialize database
python3 migrate_db.py

# Deploy to production
sudo ./production-deploy.sh
```

**Default Login:** `admin` / `admin123`  
⚠️ **Change password immediately after first login!**

---

## ✨ Features

- 📱 **Bulk SMS Campaigns** - Send to thousands from CSV/TXT files
- 🔄 **Auto-Reply System** - Database-backed, configurable via web UI
- 📊 **Campaign Tracking** - Real-time monitoring and status updates
- 🔐 **Secure Authentication** - Password change tracking and warnings
- 💾 **Persistent Storage** - All settings stored in SQLite database
- 🔧 **Production Ready** - Gunicorn, auto-migration, thread-safe

---

## 📦 Installation

### Prerequisites
- Python 3.8+
- Twilio account with active phone number
- Linux/macOS server (Ubuntu 20.04+ recommended)

### Standard Installation

```bash
# Clone repository
git clone <your-repo-url>
cd TiwlioSMS

# Install dependencies
pip3 install -r requirements.txt

# Initialize database
python3 migrate_db.py

# Development mode
python3 app.py

# Production mode
sudo ./production-deploy.sh
```

---

## 🔧 Configuration

### 1. Initial Setup

After installation, access: `http://your-server-ip:5000`

- **Username:** `admin`
- **Password:** `admin123`

⚠️ **IMPORTANT:** Change password immediately via **User Menu → Change Credentials**

### 2. Twilio Credentials

1. Navigate to **Settings → Twilio Credentials**
2. Enter your Twilio Account SID
3. Enter your Twilio Auth Token
4. Enter your Twilio phone number (E.164 format: +1234567890)
5. Click **Save Credentials**

### 3. Auto-Reply Configuration

1. Navigate to **Settings → Auto-Reply Message**
2. Edit the message text
3. Preview your changes (character counter included)
4. Click **Save Auto-Reply Message**
5. Configure Twilio webhook:
   - **URL:** `https://your-domain.com/sms/inbound`
   - **Method:** `POST`
   - **Event:** `Incoming Messages`

---

## 📱 Usage

### Send Bulk SMS Campaign

1. **Prepare Phone Numbers**
   - Format: CSV or TXT file
   - One number per line or comma-separated

2. **Create Campaign**
   - Click **Send SMS** in navigation
   - Enter campaign name and message
   - Upload phone numbers file
   - Click **Send SMS**

3. **Monitor Progress**
   - Real-time status updates
   - Individual message tracking

### View Inbound Messages

- Navigate to **Inbound Messages**
- See all SMS received by your Twilio number
- Verify auto-replies were sent

---

## 📁 Project Structure

```
TiwlioSMS/
├── app.py                      # Main Flask application
├── migrate_db.py               # Database initialization
├── gunicorn_config.py          # Production server config
├── requirements.txt            # Python dependencies
├── production-deploy.sh        # Automated deployment
├── README.md                   # This file
├── PRODUCTION_DEPLOYMENT.md    # Detailed deployment guide
├── templates/                  # HTML templates
└── static/                     # Static assets
```

---

## 🗄️ Database Schema

### Tables

**users** - Authentication and Twilio credentials  
**campaigns** - SMS campaign tracking  
**message_status** - Individual message tracking  
**inbound_messages** - Incoming SMS log  
**settings** - Application configuration

**Auto-Migration:** ✅ Automatic on startup, safe for production

---

## 🔐 Security

### Production Checklist

- [ ] Change default admin password
- [ ] Set `SECRET_KEY` environment variable
- [ ] Use HTTPS/SSL
- [ ] Secure database: `chmod 600 twilio_sms.db`
- [ ] Enable firewall
- [ ] Regular backups

---

## 🐛 Troubleshooting

### Password warning persists
```bash
# Check database
sqlite3 twilio_sms.db "SELECT username, is_default_password FROM users;"
# Logout and login again
```

### Auto-reply not working
```bash
# Verify settings
sqlite3 twilio_sms.db "SELECT * FROM settings WHERE setting_key='auto_reply_message';"
# Restart service
sudo systemctl restart twiliosms
```

### Service issues
```bash
# Check logs
sudo journalctl -u twiliosms -n 50 --no-pager
# Restart
sudo systemctl restart twiliosms
```

---

## 📊 API Endpoints

**Web Routes:**
- `/` - Dashboard
- `/login` - Authentication
- `/send_sms` - Create campaign
- `/settings` - Twilio credentials
- `/settings/auto-reply` - Auto-reply config
- `/inbound-messages` - View incoming SMS

**Webhooks:**
- `/sms/inbound` - Twilio webhook (POST)

---

## 🎯 What's New in v2.0

✅ **Auto-Reply System** - Database storage with web UI  
✅ **Password Tracking** - Accurate default password warnings  
✅ **Gunicorn Fix** - Removed preload_app for proper caching  
✅ **Clean Code** - Production-ready, no unnecessary files

---

## 💡 Common Questions

**Q: Multiple Gunicorn workers supported?**  
A: Yes! All settings are database-backed and thread-safe.

**Q: Settings persist after restart?**  
A: Yes! Everything stored in SQLite database.

**Q: HTTPS required?**  
A: Recommended. See PRODUCTION_DEPLOYMENT.md for setup.

---

## 📝 Dependencies

```
Flask==3.0.0
twilio==8.10.0
gunicorn==21.2.0
Werkzeug==3.0.1
```

---

## 🚀 Post-Deployment

1. ✅ Access: `http://your-server-ip:5000`
2. ✅ Login: `admin` / `admin123`
3. ✅ **Change password immediately**
4. ✅ Configure Twilio credentials
5. ✅ Set auto-reply message
6. ✅ Test campaign
7. ✅ Configure Twilio webhook

---

## ✅ Production Ready

- ✅ Persistent database storage
- ✅ Thread-safe implementation
- ✅ Auto-migration system
- ✅ Secure authentication
- ✅ Clean codebase
- ✅ Production-tested

**Status:** Ready to deploy!

---

**Version:** 2.0  
**Last Updated:** January 23, 2026  
**Maintained By:** GMADP Team

For detailed deployment: [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)
