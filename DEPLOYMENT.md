# TwilioSMS Production Deployment Guide

## Overview
Production-ready Flask application for sending bulk SMS via Twilio with auto-reply functionality.

## Production Structure
```
TiwlioSMS/
├── app.py                      # Main application
├── gunicorn_config.py          # Gunicorn configuration
├── requirements.txt            # Python dependencies
├── static/                     # Static assets (CSS, JS, images)
├── templates/                  # HTML templates
├── uploads/                    # Upload directory (auto-created)
└── scripts/                    # Utility scripts (not deployed)
    ├── deployment/             # Deployment scripts
    ├── diagnostics/            # Diagnostic tools
    └── migrate_db.py           # Database migration
```

## Server Requirements
- Ubuntu 20.04/22.04 LTS
- Python 3.8+
- Nginx
- Systemd

## Installation on Production Server

### 1. Clone Repository
```bash
cd ~
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS
```

### 2. Create Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 3. Initialize Database
```bash
python3 app.py
# This will initialize the database and create default admin user
# Press Ctrl+C after it starts
```

### 4. Configure Systemd Service
```bash
sudo nano /etc/systemd/system/twiliosms.service
```

Add the following content:
```ini
[Unit]
Description=Twilio SMS Gunicorn Application
After=network.target

[Service]
User=YOUR_USERNAME
Group=www-data
WorkingDirectory=/home/YOUR_USERNAME/TiwlioSMS
Environment="PATH=/home/YOUR_USERNAME/TiwlioSMS/venv/bin"
ExecStart=/home/YOUR_USERNAME/TiwlioSMS/venv/bin/gunicorn -c gunicorn_config.py app:app

[Install]
WantedBy=multi-user.target
```

Replace `YOUR_USERNAME` with your actual username.

### 5. Configure Nginx
```bash
sudo nano /etc/nginx/sites-available/twiliosms
```

Add:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static {
        alias /home/YOUR_USERNAME/TiwlioSMS/static;
        expires 30d;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. Start Services
```bash
sudo systemctl daemon-reload
sudo systemctl start twiliosms
sudo systemctl enable twiliosms
sudo systemctl status twiliosms
```

### 7. Configure Twilio Webhook
In your Twilio Console:
- Go to Phone Numbers → Active Numbers
- Select your number
- Under "Messaging", set webhook URL to: `http://your-domain.com/sms/inbound`
- Method: POST
- Save

## Default Credentials
- **Username:** admin
- **Password:** admin123
- ⚠️ **IMPORTANT:** Change these immediately after first login!

## Updating the Application

```bash
cd ~/TiwlioSMS
git pull origin dev/twilioms-test
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart twiliosms
```

## Monitoring

### Check Application Status
```bash
sudo systemctl status twiliosms
```

### View Logs
```bash
# Application logs
tail -f twilio_sms.log

# System logs
sudo journalctl -u twiliosms -f
```

### Check Database
```bash
sqlite3 twilio_sms.db "SELECT * FROM settings WHERE setting_key='auto_reply_message';"
```

## Troubleshooting

### If auto-reply update fails
```bash
cd ~/TiwlioSMS/scripts/diagnostics
chmod +x fix_auto_reply_update.sh
./fix_auto_reply_update.sh
```

### Check file permissions
```bash
ls -l twilio_sms.db
# Should be readable/writable by your user
chmod 644 twilio_sms.db
```

### Restart service
```bash
sudo systemctl restart twiliosms
```

## Security Notes

1. **Change default credentials immediately**
2. **Set a secure SECRET_KEY** in environment or app.py
3. **Use HTTPS** in production (setup Let's Encrypt)
4. **Restrict database access**
5. **Keep dependencies updated**

## Support

For issues, check:
1. Application logs: `twilio_sms.log`
2. System logs: `sudo journalctl -u twiliosms -f`
3. Nginx logs: `/var/log/nginx/error.log`
