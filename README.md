# TwilioSMS GMADP - Production Ready ✅

**Bulk SMS Communication Platform with Auto-Reply**  
Version 2.0 | Production Ready | Database-Backed

---

## 🚀 Quick Start

```bash
pip3 install -r requirements.txt
python3 migrate_db.py
sudo ./production-deploy.sh
```

**Login:** `admin` / `admin123` ⚠️ **Change immediately!**

---

## ✨ Features

- 📱 **Bulk SMS Campaigns** - Send to thousands from CSV/TXT files
- 🔄 **Auto-Reply System** - Configurable via web UI, database-backed
- 📊 **Campaign Tracking** - Real-time monitoring
- 🔐 **Password Warnings** - Tracks default password usage
- 💾 **Persistent Config** - All settings in database
- 🔧 **Production Ready** - Gunicorn + auto-migration + thread-safe

---

## 🎯 What's Fixed (v2.0)

### ✅ Issue #1: Auto-Reply Configuration - FIXED
**Before:** Hardcoded in environment variable, no GUI, lost on restart  
**After:** Database storage with web interface at `/settings/auto-reply`

**Benefits:**
- Thread-safe for multiple Gunicorn workers
- Persists across server restarts
- Easy configuration via web UI
- Real-time preview and character counter

### ✅ Issue #2: Password Warning Tracking - FIXED
**Before:** Warning based on `username == 'admin'` (always showed)  
**After:** Database flag `is_default_password` column

**Benefits:**
- Warning only shows when using default password
- Disappears immediately after password change
- Session-based tracking
- Database-backed persistence

---

## 📦 Installation

### Prerequisites
- Python 3.8+
- Twilio account with active phone number
- Linux/macOS server (Ubuntu 20.04+ recommended)

### Quick Deploy

```bash
# Clone repository
git clone <your-repo-url>
cd TiwlioSMS

# Install dependencies
pip3 install -r requirements.txt

# Set environment variables (optional)
export SECRET_KEY='your-random-secret-key-here'

# Initialize database (auto-migrates if exists)
python3 migrate_db.py

# Deploy to production
sudo ./production-deploy.sh
```

---

## 🔧 Configuration

### 1. Initial Login
- URL: `http://your-server-ip:5000`
- Username: `admin`
- Password: `admin123`
- ⚠️ **Change password immediately via User Menu → Change Credentials**

### 2. Twilio Setup
1. Navigate to **Settings → Twilio Credentials**
2. Enter your Twilio Account SID
3. Enter your Twilio Auth Token
4. Enter your Twilio phone number
5. Click **Save**

### 3. Auto-Reply Configuration
1. Navigate to **Settings → Auto-Reply Message**
2. Edit the message text (character counter shows length)
3. Preview your changes
4. Click **Save Changes**
5. Configure Twilio webhook:
   - URL: `https://your-domain.com/sms/inbound`
   - Method: `POST`
   - Event: `Incoming Messages`

---

## 📱 Usage

### Send Bulk SMS Campaign

1. **Prepare phone numbers file**
   - Format: CSV or TXT
   - One number per line or comma-separated
   - Example: `+1234567890` or `1234567890`

2. **Create campaign**
   - Click **Send SMS** in navigation
   - Enter campaign name
   - Write message (160 chars recommended for single SMS)
   - Enter your Twilio phone number
   - Upload phone numbers file
   - Click **Send SMS**

3. **Monitor progress**
   - Real-time status updates
   - View successful/failed sends
   - Check individual message statuses
   - Export results

### Configure Auto-Reply

1. Navigate to **Settings → Auto-Reply Message**
2. Edit message in the text area
3. View live preview and character count
4. Click **Save Changes**
5. Test by sending SMS to your Twilio number

### Change Credentials

1. Click username dropdown → **Change Credentials**
2. Enter current password
3. Enter new username (optional)
4. Enter new password (minimum 6 characters)
5. Confirm new password
6. Click **Save** (will logout for security)

---

## 📁 File Structure

```
TiwlioSMS/
├── app.py                      # Main Flask application (651 lines)
├── migrate_db.py               # Database initialization
├── gunicorn_config.py          # Production server config
├── requirements.txt            # Python dependencies
├── production-deploy.sh        # Deployment automation script
├── commit-and-push.sh          # Git helper script
├── README.md                   # This file
├── PRODUCTION_DEPLOYMENT.md    # Detailed deployment guide
├── .env                        # Environment variables
├── .env.example                # Environment template
├── .gitignore                  # Git ignore patterns
├── twilio_sms.db              # SQLite database
├── templates/                  # HTML templates (9 files)
│   ├── base.html              # Base with navigation
│   ├── dashboard.html         # Main dashboard
│   ├── login.html             # Login page
│   ├── send_sms.html          # Send SMS form
│   ├── campaign_status.html   # Campaign details
│   ├── settings.html          # Twilio credentials
│   ├── settings_auto_reply.html  # ⭐ NEW: Auto-reply config
│   ├── change_credentials.html   # Password change
│   └── inbound_messages.html     # Incoming SMS log
└── static/                    # Static assets
    ├── css/style.css          # Custom styles
    ├── js/app.js              # JavaScript
    └── images/
        └── gmadp-logo.png     # Logo
```

---

## 🗄️ Database

### Auto-Migration
✅ **Built into app.py** - Automatically runs on startup  
✅ **Upgrades existing databases** - No manual migration needed  
✅ **Safe** - Checks for existing columns before adding

### Tables

**users** - User accounts
- `id`, `username`, `password_hash`
- `twilio_sid`, `twilio_token`
- `is_default_password` ⭐ NEW - Tracks default password
- `created_at`

**campaigns** - SMS campaigns
- `id`, `user_id`, `name`, `message_body`
- `total_numbers`, `successful_sends`, `failed_sends`
- `status`, `created_at`, `completed_at`

**message_status** - Individual SMS tracking
- `id`, `campaign_id`, `phone_number`
- `message_sid`, `status`, `error_message`
- `sent_at`

**inbound_messages** - Incoming SMS log
- `id`, `from_number`, `to_number`
- `message_body`, `message_sid`
- `reply_sent`, `received_at`

**settings** - Application configuration ⭐ NEW
- `id`, `setting_key`, `setting_value`
- `updated_at`

---

## 🔐 Security

### Production Checklist
- [ ] Change default admin password
- [ ] Set `SECRET_KEY` environment variable
- [ ] Use HTTPS/SSL (Let's Encrypt recommended)
- [ ] Secure database: `chmod 600 twilio_sms.db`
- [ ] Enable firewall (allow ports 80, 443 only)
- [ ] Regular database backups
- [ ] Keep dependencies updated

### Password Security
- ✅ PBKDF2 hashing (Werkzeug)
- ✅ Session-based authentication
- ✅ Auto-logout on password change
- ✅ Default password warnings

---

## 📊 API Endpoints

### Web Routes
- `GET /` - Home (redirects to dashboard)
- `GET/POST /login` - User login
- `GET /logout` - User logout
- `GET /dashboard` - Main dashboard
- `GET/POST /settings` - Twilio credentials
- `GET/POST /settings/auto-reply` - ⭐ Auto-reply config
- `GET/POST /change-credentials` - Password change
- `GET/POST /send_sms` - Send bulk SMS
- `GET /campaign/<id>` - Campaign status
- `GET /inbound-messages` - View incoming SMS

### Webhook Routes
- `POST /sms/inbound` - Twilio webhook for incoming SMS
- `GET /health` - Health check endpoint

### API Routes
- `GET /api/campaign/<id>/status` - Campaign status (JSON)

---

## 🐛 Troubleshooting

### Password warning still shows after change
```bash
# Check database
sqlite3 twilio_sms.db "SELECT username, is_default_password FROM users;"
# Should show 0 after password change

# Solution: Logout and login again
```

### Auto-reply not persisting
```bash
# Check settings table
sqlite3 twilio_sms.db "SELECT * FROM settings WHERE setting_key = 'auto_reply_message';"

# Verify database permissions
ls -l twilio_sms.db
chmod 644 twilio_sms.db
```

### Database errors
```bash
# Backup and reinitialize
cp twilio_sms.db twilio_sms.db.backup
python3 migrate_db.py
```

### Gunicorn not starting
```bash
# Check service logs
sudo journalctl -u twiliosms -n 50

# Test manually
gunicorn -c gunicorn_config.py app:app
```

---

## 📚 Documentation

- **README.md** (this file) - Quick start and overview
- **PRODUCTION_DEPLOYMENT.md** - Complete deployment guide with Nginx/SSL setup

---

## 🤝 Common Questions

**Q: Can multiple users have different Twilio accounts?**  
A: Yes! Each user can configure their own Twilio credentials in Settings.

**Q: How many SMS can I send at once?**  
A: Limited by your Twilio account. The app includes 1-second delay between sends to prevent rate limiting.

**Q: Is auto-reply customizable?**  
A: Yes! Navigate to Settings → Auto-Reply Message for full web-based configuration.

**Q: Does it work with multiple Gunicorn workers?**  
A: Yes! All settings are database-backed (thread-safe).

**Q: What happens to settings when I restart the server?**  
A: All settings persist in the database - nothing is lost on restart.

---

## 🎉 Version History

### v2.0 (Current - Production Ready)
- ✅ Database-backed auto-reply configuration
- ✅ Password change tracking with warnings
- ✅ Settings table for persistent config
- ✅ Auto-migration system
- ✅ Thread-safe for production
- ✅ Removed all global variables
- ✅ Clean codebase (no duplicates)

### v1.0 (Legacy)
- Basic bulk SMS functionality
- Hardcoded auto-reply message
- Username-based password warnings

---

## 📝 Dependencies

```
Flask==3.0.0
twilio==8.10.0
gunicorn==21.2.0
Werkzeug==3.0.1
```

See `requirements.txt` for complete list.

---

## 🚀 Post-Deployment Steps

After running `./production-deploy.sh`:

1. ✅ Access web interface: `http://your-server-ip:5000`
2. ✅ Login with `admin` / `admin123`
3. ✅ Change password immediately
4. ✅ Configure Twilio credentials
5. ✅ Set auto-reply message
6. ✅ Test with sample SMS campaign
7. ✅ Configure Twilio webhook URL
8. ✅ Test auto-reply by sending SMS

---

## ✨ Status: Production Ready ✅

All critical issues fixed with database-backed solutions:
- ✅ Persistent auto-reply configuration
- ✅ Password change tracking
- ✅ Thread-safe implementation
- ✅ Auto-migration
- ✅ Clean codebase
- ✅ Complete documentation

**Ready to deploy!**

---

**Last Updated:** January 19, 2026  
**Version:** 2.0 (Production)  
**Maintained By:** GMADP Team

For detailed deployment instructions, see [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)
