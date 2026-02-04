# 📱 TwilioSMS - Bulk SMS Platform

**Version:** 2.1.1 Hotfix  
**Production-ready Flask application for bulk SMS campaigns with auto-reply and STOP/START compliance**

---

## 🚀 Quick Installation (Production)

### Prerequisites
- Ubuntu 20.04/22.04 LTS  
- Python 3.8+  
- Twilio Account with active phone number  
- Domain name or IP address  

---

### ⚡ Option 1: One-Command Installation (Recommended)

**Complete automated deployment in 5-10 minutes:**

```bash
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/dev/twilioms-test/install_production.sh
sudo bash install_production.sh
```

**What it does automatically:**
- ✅ Installs all system dependencies  
- ✅ Clones repository and sets up Python environment  
- ✅ Initializes and migrates database  
- ✅ Configures systemd service  
- ✅ Sets up Nginx reverse proxy  
- ✅ Optional: HTTPS with Let's Encrypt  
- ✅ Optional: Firewall configuration  

**Interactive prompts for:**
- Domain name/IP address
- Installation directory
- HTTPS setup (y/n)
- Firewall setup (y/n)

---

### 🔧 Option 2: Manual Installation

<details>
<summary>Click to expand manual installation steps</summary>

```bash
# 1. System packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv nginx git sqlite3

# 2. Clone repository
cd ~
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS
git checkout dev/twilioms-test

# 3. Setup virtual environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 4. Initialize database
python3 -c "from app import init_db; init_db()"

# 5. Run database migration
python3 scripts/migrate_db_v2.1.1.py

# 6. Create systemd service
sudo nano /etc/systemd/system/twiliosms.service
```

**Service file content** (replace YOUR_USERNAME):
```ini
[Unit]
Description=TwilioSMS Application
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
```

```bash
# 7. Start service
sudo systemctl daemon-reload
sudo systemctl start twiliosms
sudo systemctl enable twiliosms

# 8. Configure Nginx
sudo nano /etc/nginx/sites-available/twiliosms
```

**Nginx config:**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /static {
        alias /home/YOUR_USERNAME/TiwlioSMS/static;
        expires 30d;
    }

    client_max_body_size 16M;
}
```

```bash
# 9. Enable site
sudo ln -s /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 10. Setup HTTPS (optional)
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

</details>

---

## ⚙️ Configuration

### First Login
- Access: `http://your-domain.com`
- Username: `admin`
- Password: `admin123`
- **⚠️ CHANGE IMMEDIATELY:** Settings → Change Credentials

### Twilio Setup
1. Get credentials from: https://console.twilio.com
2. Settings → Twilio Credentials:
   - Account SID
   - Auth Token
   - Phone Number

3. Configure webhook in Twilio Console → Phone Numbers:
   - Webhook URL: `http://your-domain.com/sms/inbound`
   - Method: POST

---

## 📖 Features

✅ Bulk SMS campaigns with CSV upload  
✅ Auto-reply with intent detection (RSVP, TIME, ADDRESS, SEVA)  
✅ STOP/START compliance (TCPA/CTIA)  
✅ Subscriber management dashboard  
✅ Campaign tracking and reports  
✅ Inbound message logging  

---

## 🛠️ Troubleshooting

### Inbound Messages Error
```bash
cd ~/TiwlioSMS
python3 scripts/migrate_db_v2.1.1.py
sudo systemctl restart twiliosms
```

### Service Issues
```bash
# Check logs
sudo journalctl -u twiliosms -xe
tail -f ~/TiwlioSMS/twilio_sms.log

# Restart service
sudo systemctl restart twiliosms
```

### Database Locked
```bash
sudo systemctl stop twiliosms
chmod 644 twilio_sms.db
sudo systemctl start twiliosms
```

---

## �� Updates

```bash
cd ~/TiwlioSMS
source venv/bin/activate
git pull origin dev/twilioms-test
pip install -r requirements.txt
python3 scripts/migrate_db_v2.1.1.py
sudo systemctl restart twiliosms
```

---

## 📊 Quick Commands

| Task | Command |
|------|---------|
| View logs | `sudo journalctl -u twiliosms -f` |
| Restart | `sudo systemctl restart twiliosms` |
| Status | `sudo systemctl status twiliosms` |
| Backup DB | `cp twilio_sms.db backups/backup_$(date +%Y%m%d).db` |

---

**Developed by GMADP Team** | Version 2.1.1 Hotfix | February 4, 2026
