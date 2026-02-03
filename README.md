# 📱 TwilioSMS - Professional Bulk SMS Platform

**Version:** 2.1.1  
**Last Updated:** February 2, 2026

Production-ready Flask application for bulk SMS campaigns with intelligent auto-reply, STOP/START compliance, and comprehensive subscriber management.

---

## 🌟 Features

### Core Features
✅ **Bulk SMS Campaigns** - Send to thousands of recipients with CSV/TXT upload  
✅ **Smart Auto-Reply** - Intent-based responses (RSVP, TIME, ADDRESS, SEVA)  
✅ **STOP/START Compliance** - Full TCPA/CTIA regulatory compliance  
✅ **Subscriber Management** - Track opt-ins and opt-outs  
✅ **Campaign Tracking** - Real-time progress and delivery reports  
✅ **Inbound Message Logging** - Complete audit trail with intent detection  
✅ **User Authentication** - Secure multi-user support  
✅ **Database Driven** - SQLite backend with automatic backups  

### v2.1.1 New Features
🆕 **Intent Detection** - Automatically detect and respond to keywords  
🆕 **Subscriber Dashboard** - View all subscribers and their status  
🆕 **Enhanced Logging** - Color-coded intent badges in admin panel  
🆕 **Production Ready** - Thread-safe, tested, and documented  

---

## 📋 Table of Contents

1. [Quick Start](#-quick-start)
2. [Installation](#-installation)
3. [Configuration](#-configuration)
4. [Usage Guide](#-usage-guide)
5. [Technology Stack](#-technology-stack)
6. [Security](#-security)
7. [Troubleshooting](#-troubleshooting)
8. [Updates & Maintenance](#-updates--maintenance)

---

## 🚀 Quick Start

### Production Deployment (Ubuntu Server)

\`\`\`bash
# 1. Clone repository
cd ~
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS

# 2. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Initialize database
python3 -c "from app import init_db; init_db()"

# 5. Configure and start service
# See Installation section below for systemd configuration
sudo systemctl start twiliosms
sudo systemctl enable twiliosms
\`\`\`

### Local Development

\`\`\`bash
# Clone and setup
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS
pip install -r requirements.txt

# Run development server
python app.py

# Access at: http://localhost:5000
\`\`\`

**Default Login:**
- Username: \`admin\`
- Password: \`admin123\`
- ⚠️ **CRITICAL: Change immediately after first login!**

---

## 📦 Installation

### Prerequisites

- **Operating System:** Ubuntu 20.04/22.04 LTS (or macOS for development)
- **Python:** 3.8 or higher
- **Twilio Account:** Active account with phone number
- **Domain:** (Optional) for production with HTTPS

### System Packages

\`\`\`bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv nginx git sqlite3
\`\`\`

### Application Setup

\`\`\`bash
# 1. Clone repository
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS

# 2. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 3. Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt

# 4. Initialize database
python3 -c "from app import init_db; init_db(); print('✓ Database initialized')"
\`\`\`

### Production Setup (Systemd)

Create service file:
\`\`\`bash
sudo nano /etc/systemd/system/twiliosms.service
\`\`\`

Add content (replace YOUR_USERNAME):
\`\`\`ini
[Unit]
Description=TwilioSMS Bulk SMS Application
After=network.target

[Service]
User=YOUR_USERNAME
Group=www-data
WorkingDirectory=/home/YOUR_USERNAME/TiwlioSMS
Environment="PATH=/home/YOUR_USERNAME/TiwlioSMS/venv/bin"
Environment="SECRET_KEY=CHANGE-THIS-TO-RANDOM-STRING"
ExecStart=/home/YOUR_USERNAME/TiwlioSMS/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
\`\`\`

Start service:
\`\`\`bash
sudo systemctl daemon-reload
sudo systemctl start twiliosms
sudo systemctl enable twiliosms
sudo systemctl status twiliosms
\`\`\`

### Nginx Configuration

\`\`\`bash
sudo nano /etc/nginx/sites-available/twiliosms
\`\`\`

\`\`\`nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /static {
        alias /home/YOUR_USERNAME/TiwlioSMS/static;
        expires 30d;
    }

    client_max_body_size 16M;
}
\`\`\`

Enable site:
\`\`\`bash
sudo ln -s /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
\`\`\`

---

## ⚙️ Configuration

### 1. First Login & Security

Access application at \`http://your-domain.com\` and login with:
- Username: \`admin\`
- Password: \`admin123\`

**IMMEDIATELY:**
1. Go to Settings → Change Credentials
2. Update username and password
3. Set strong password (min 6 characters)

### 2. Twilio Credentials

Get from: https://console.twilio.com

Settings → Twilio Credentials:
- Account SID: \`ACxxxxxxxxxxxxxxxxxxxxxxxxxxxx\`
- Auth Token: \`your_auth_token_here\`
- Phone Number: \`+1234567890\`

### 3. Auto-Reply Message

Settings → Auto-Reply Message - Configure default message for unknown intents

### 4. Twilio Webhook

Configure in Twilio Console → Phone Numbers → Active Numbers

Select your number → Messaging Configuration:
- **A MESSAGE COMES IN**
- Webhook URL: \`http://your-domain.com/sms/inbound\`
- HTTP Method: \`POST\`
- **[Save]**

---

## 📖 Usage Guide

### Sending Bulk SMS Campaigns

**Prepare Phone Numbers (CSV or TXT):**
\`\`\`csv
phone_number
+1234567890
+0987654321
\`\`\`

**Create Campaign:**
1. Navigate to: **Send SMS Campaign**
2. Enter campaign name, message, from number
3. Upload phone numbers file
4. Click: **Send Campaign**

**Monitor Progress:**
- View real-time status
- Success/failure counts
- Individual message details

### Intent-Based Auto-Replies

Pre-configured Intents:

| Intent | Keywords | Auto-Reply |
|--------|----------|------------|
| **RSVP** | RSVP, YES, CONFIRM | "Thank you for your RSVP!" |
| **TIME** | TIME, WHEN, SCHEDULE | "Event timing: Check invitation" |
| **ADDRESS** | ADDRESS, WHERE, LOCATION | "Location: Check invitation" |
| **SEVA** | SEVA, VOLUNTEER, HELP | "Thank you for offering seva!" |
| **STOP** | STOP, STOPALL, UNSUBSCRIBE | "You have been unsubscribed" |
| **START** | START, YES, UNSTOP | "You have been resubscribed" |

### Subscriber Management

**View Dashboard:**  
Navigation → **Subscribers**

- Subscribed count
- Unsubscribed count  
- Full subscriber list with status

**STOP/START Compliance:**
- Automatically processes opt-out requests
- Prevents sending to unsubscribed numbers
- Full TCPA/CTIA compliance

---

## 🛠️ Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Backend** | Flask | 3.0.0 |
| **SMS Provider** | Twilio API | 8.11.1 |
| **Database** | SQLite | 3.x |
| **WSGI Server** | Gunicorn | 21.2.0 |
| **Reverse Proxy** | Nginx | 1.18+ |
| **Frontend** | Bootstrap 5 | 5.1.3 |

**Project Structure:**
\`\`\`
TiwlioSMS/
├── app.py                      # Main application
├── gunicorn_config.py          # Production config
├── requirements.txt            # Dependencies
├── twilio_sms.db              # Database
├── static/                     # CSS, JS, images
├── templates/                  # HTML templates
├── backups/                    # DB backups
└── scripts/                    # Tools
\`\`\`

---

## 🔒 Security

### Implemented Measures

✅ Password hashing (Werkzeug PBKDF2 SHA-256)  
✅ Session management (encrypted)  
✅ SQL injection prevention  
✅ File upload security  
✅ Route protection  

### Production Checklist

\`\`\`bash
# 1. Change default credentials
Settings → Change Credentials

# 2. Generate SECRET_KEY
python3 -c "import secrets; print(secrets.token_hex(32))"

# 3. Setup HTTPS
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com

# 4. Secure database
chmod 644 twilio_sms.db

# 5. Enable firewall
sudo ufw allow 'Nginx Full'
sudo ufw enable
\`\`\`

---

## �� Troubleshooting

### Auto-Reply Not Working

\`\`\`bash
# Check webhook in Twilio Console
# Verify URL: http://your-domain.com/sms/inbound

# Test webhook
curl -X POST http://localhost/sms/inbound \\
  -d "From=+1234567890" \\
  -d "Body=Test"

# Check logs
tail -f twilio_sms.log | grep "Inbound"
\`\`\`

### Service Won't Start

\`\`\`bash
# Check logs
sudo journalctl -u twiliosms -xe

# Verify configuration
sudo nano /etc/systemd/system/twiliosms.service

# Restart
sudo systemctl daemon-reload
sudo systemctl restart twiliosms
\`\`\`

### Database Locked

\`\`\`bash
# Fix permissions
chmod 644 twilio_sms.db
chown YOUR_USERNAME:YOUR_USERNAME twilio_sms.db
sudo systemctl restart twiliosms
\`\`\`

### Intent Detection Not Working

\`\`\`bash
# Verify intents in database
sqlite3 twilio_sms.db "SELECT * FROM auto_reply_intents;"

# Run migration if empty
python3 scripts/migrate_db_v2.py

# Restart service
sudo systemctl restart twiliosms
\`\`\`

---

## 🔄 Updates & Maintenance

### Updating Application

\`\`\`bash
cd ~/TiwlioSMS
source venv/bin/activate
git pull origin main
pip install -r requirements.txt
python3 scripts/migrate_db_v2.py
sudo systemctl restart twiliosms
\`\`\`

### Database Backups

\`\`\`bash
# Manual backup
cp twilio_sms.db backups/backup_\$(date +%Y%m%d).db

# Automated (add to crontab)
0 2 * * * cp ~/TiwlioSMS/twilio_sms.db ~/TiwlioSMS/backups/backup_\$(date +%Y%m%d).db
\`\`\`

### Log Management

\`\`\`bash
# View logs
tail -f twilio_sms.log
sudo journalctl -u twiliosms -f

# Search errors
grep -i error twilio_sms.log
\`\`\`

---

## 📊 Quick Reference

| Task | Command |
|------|---------|
| View logs | \`sudo journalctl -u twiliosms -f\` |
| Restart app | \`sudo systemctl restart twiliosms\` |
| Check status | \`sudo systemctl status twiliosms\` |
| Database backup | \`cp twilio_sms.db backups/backup_\$(date +%Y%m%d).db\` |
| Update app | \`git pull && pip install -r requirements.txt\` |
| Check health | \`curl http://localhost/health\` |

---

## 📞 Support

1. **Check Logs:**
   \`\`\`bash
   tail -f twilio_sms.log
   sudo journalctl -u twiliosms -n 50
   \`\`\`

2. **Review Troubleshooting** section above

3. **Additional Documentation:** See \`docs/\` directory

4. **GitHub Issues:** Report bugs or request features

---

## 🎯 Version History

- **v2.1.1** (2026-02-02) - Bug fixes, subscriber dashboard
- **v2.1.0** (2026-02-02) - STOP/START compliance, intent detection
- **v2.0.0** (2026-01-24) - Auto-reply enhancement
- **v1.0.0** (2026-01-15) - Initial release

---

## 📄 License

MIT License

---

## 👥 Credits

**Developed by:** GMADP Team  
**Purpose:** Professional SMS platform for event management and community outreach  
**Powered by:** Flask, Twilio, open-source technologies

---

## ⚖️ Compliance

- **TCPA Compliance** - Telephone Consumer Protection Act
- **CTIA Guidelines** - Industry best practices
- **Twilio Policies** - Messaging policy compliance

**Important:** Always obtain consent before sending messages. Follow all applicable laws and regulations.

---

**🚀 Ready to get started? Follow the [Installation](#-installation) guide above!**

*Version 2.1.1 | Last Updated: February 2, 2026*
