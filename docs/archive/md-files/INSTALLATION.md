# 🚀 TwilioSMS - Simple Production Installation Guide

**Version:** 2.1.0  
**Last Updated:** February 2, 2026  
**Installation Time:** ~15 minutes

---

## 📋 What You'll Need

✅ **Ubuntu Server** (20.04 or 22.04 LTS)  
✅ **Root/Sudo Access**  
✅ **Internet Connection**  
✅ **Twilio Account** (with phone number)  
✅ **Domain Name** (optional, but recommended)

---

## 🎯 Quick Start (Copy & Paste)

### Option 1: Automated Installation (Recommended)

```bash
# Download and run automated installer
cd ~
curl -O https://raw.githubusercontent.com/hmali/TiwlioSMS/main/scripts/deployment/production-deploy.sh
chmod +x production-deploy.sh
./production-deploy.sh
```

### Option 2: Manual Installation (Step-by-Step Below)

Continue reading for detailed manual installation instructions.

---

## 📝 Step-by-Step Manual Installation

### Step 1: Update System

```bash
# Update package lists and upgrade existing packages
sudo apt update && sudo apt upgrade -y

# Install required system packages
sudo apt install -y python3 python3-pip python3-venv nginx git sqlite3
```

**Expected Output:**
```
Reading package lists... Done
Building dependency tree... Done
...
Setting up python3-venv ... Done
```

✅ **Checkpoint:** Run `python3 --version` - should show Python 3.8 or higher

---

### Step 2: Clone Repository

```bash
# Navigate to home directory
cd ~

# Clone the TwilioSMS repository
git clone https://github.com/hmali/TiwlioSMS.git

# Enter the project directory
cd TiwlioSMS

# Verify files exist
ls -la
```

**Expected Output:**
```
drwxr-xr-x  app.py
drwxr-xr-x  requirements.txt
drwxr-xr-x  templates/
drwxr-xr-x  static/
...
```

✅ **Checkpoint:** You should see `app.py` and `requirements.txt`

---

### Step 3: Create Virtual Environment

```bash
# Create Python virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Your prompt should now show (venv) at the beginning
# (venv) user@server:~/TiwlioSMS$

# Upgrade pip
pip install --upgrade pip

# Install Python dependencies
pip install -r requirements.txt
```

**Expected Output:**
```
Collecting Flask==3.0.0
Collecting twilio==8.11.1
Collecting gunicorn==21.2.0
...
Successfully installed Flask-3.0.0 twilio-8.11.1 gunicorn-21.2.0 ...
```

✅ **Checkpoint:** Run `pip list` - should show Flask, twilio, gunicorn

---

### Step 4: Initialize Database

```bash
# Initialize the database (this creates twilio_sms.db)
python3 -c "from app import init_db; init_db(); print('Database initialized!')"

# Verify database was created
ls -lh twilio_sms.db
```

**Expected Output:**
```
Database initialized!
-rw-r--r-- 1 user user 20K Feb  2 10:00 twilio_sms.db
```

✅ **Checkpoint:** Database file should exist and be around 20KB

---

### Step 5: Test Application Locally

```bash
# Start the application in test mode
python3 app.py
```

**Expected Output:**
```
 * Running on http://127.0.0.1:5000
 * Debug mode: on
WARNING: This is a development server. Do not use it in production.
```

🧪 **Test in Another Terminal:**
```bash
# Open new terminal and test
curl http://127.0.0.1:5000/health

# Should return: {"status":"healthy"}
```

Press **Ctrl+C** to stop the test server.

✅ **Checkpoint:** Health check should return JSON response

---

### Step 6: Configure Systemd Service

```bash
# Create systemd service file
sudo nano /etc/systemd/system/twiliosms.service
```

**Copy and paste this (replace YOUR_USERNAME with your actual username):**

```ini
[Unit]
Description=TwilioSMS Bulk SMS Application
After=network.target

[Service]
User=YOUR_USERNAME
Group=www-data
WorkingDirectory=/home/YOUR_USERNAME/TiwlioSMS
Environment="PATH=/home/YOUR_USERNAME/TiwlioSMS/venv/bin"
Environment="SECRET_KEY=CHANGE-THIS-TO-RANDOM-STRING-IN-PRODUCTION"
ExecStart=/home/YOUR_USERNAME/TiwlioSMS/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Replace YOUR_USERNAME:**
```bash
# Find your username
whoami
# Example output: ubuntu

# Then replace YOUR_USERNAME with your actual username in the file above
```

**Save and exit:** Press `Ctrl+X`, then `Y`, then `Enter`

✅ **Checkpoint:** File saved to `/etc/systemd/system/twiliosms.service`

---

### Step 7: Start the Service

```bash
# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Start the service
sudo systemctl start twiliosms

# Enable auto-start on boot
sudo systemctl enable twiliosms

# Check service status
sudo systemctl status twiliosms
```

**Expected Output:**
```
● twiliosms.service - TwilioSMS Bulk SMS Application
   Loaded: loaded (/etc/systemd/system/twiliosms.service; enabled)
   Active: active (running) since Sun 2026-02-02 10:15:30 UTC
   ...
   Main PID: 12345
   ...
```

**Look for:** `Active: active (running)` in green

✅ **Checkpoint:** Service should be "active (running)"

---

### Step 8: Configure Nginx Reverse Proxy

```bash
# Create nginx configuration
sudo nano /etc/nginx/sites-available/twiliosms
```

**Copy and paste this (replace YOUR_USERNAME and your-domain.com):**

```nginx
server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain or server IP

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Increase timeout for long-running requests
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    # Static files (CSS, JS, images)
    location /static {
        alias /home/YOUR_USERNAME/TiwlioSMS/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # File uploads
    client_max_body_size 16M;
}
```

**Save and exit:** Press `Ctrl+X`, then `Y`, then `Enter`

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t
```

**Expected Output:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

```bash
# Reload nginx
sudo systemctl reload nginx

# Check nginx status
sudo systemctl status nginx
```

✅ **Checkpoint:** Nginx configuration test should pass

---

### Step 9: Configure Firewall (If Enabled)

```bash
# Check if firewall is active
sudo ufw status

# If active, allow HTTP and HTTPS
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH

# Verify rules
sudo ufw status numbered
```

✅ **Checkpoint:** Ports 80 and 443 should be allowed

---

### Step 10: Test Installation

```bash
# Test health endpoint
curl http://localhost/health

# Should return: {"status":"healthy"}

# Test from another computer (replace with your server IP)
curl http://YOUR_SERVER_IP/health
```

**Open in browser:** `http://your-domain.com` or `http://YOUR_SERVER_IP`

**You should see:** The TwilioSMS login page

✅ **Checkpoint:** Login page should load in browser

---

### Step 11: First Login & Setup

1. **Login with default credentials:**
   - Username: `admin`
   - Password: `admin123`

2. **⚠️ IMMEDIATELY Change Password:**
   - Click "Settings" → "Change Credentials"
   - Set a strong password
   - Update password

3. **Configure Twilio Credentials:**
   - Click "Settings" in navigation
   - Enter your Twilio Account SID
   - Enter your Twilio Auth Token
   - Enter your Twilio Phone Number
   - Click "Save"

✅ **Checkpoint:** You should be logged in and credentials updated

---

### Step 12: Configure Twilio Webhook

1. **Login to Twilio Console:** https://console.twilio.com

2. **Navigate to Phone Numbers:**
   - Click "Phone Numbers" → "Manage" → "Active Numbers"
   - Select your Twilio phone number

3. **Configure Messaging Webhook:**
   - Scroll to "Messaging" section
   - Under "A MESSAGE COMES IN"
   - Set webhook URL: `http://your-domain.com/sms/inbound`
   - Set HTTP Method: `POST`
   - Click "Save"

✅ **Checkpoint:** Webhook should be configured in Twilio

---

## 🎉 Installation Complete!

Your TwilioSMS application is now running in production!

**Access your application:**
- Web Interface: `http://your-domain.com`
- Health Check: `http://your-domain.com/health`

---

## 🔒 Security Hardening (Recommended)

### 1. Setup HTTPS with Let's Encrypt

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate (replace your-domain.com)
sudo certbot --nginx -d your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

**After SSL setup, your site will be:** `https://your-domain.com`

### 2. Change SECRET_KEY

```bash
# Generate random secret key
python3 -c "import secrets; print(secrets.token_hex(32))"

# Copy the output, then edit the service file
sudo nano /etc/systemd/system/twiliosms.service

# Replace SECRET_KEY line with:
# Environment="SECRET_KEY=YOUR_GENERATED_KEY_HERE"

# Restart service
sudo systemctl daemon-reload
sudo systemctl restart twiliosms
```

### 3. Setup Automatic Backups

```bash
# Create backup script
nano ~/backup-twiliosms.sh
```

**Add this content:**
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
cp ~/TiwlioSMS/twilio_sms.db ~/TiwlioSMS/backups/twilio_sms.db.backup_$DATE
# Keep only last 7 days of backups
find ~/TiwlioSMS/backups/ -name "*.backup_*" -mtime +7 -delete
```

```bash
# Make executable
chmod +x ~/backup-twiliosms.sh

# Add to crontab (daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * /home/YOUR_USERNAME/backup-twiliosms.sh
```

---

## 📊 Monitoring & Maintenance

### Check Application Status

```bash
# Service status
sudo systemctl status twiliosms

# View recent logs
sudo journalctl -u twiliosms -n 50

# Follow logs in real-time
sudo journalctl -u twiliosms -f

# Application logs
tail -f ~/TiwlioSMS/twilio_sms.log
```

### Common Commands

```bash
# Restart application
sudo systemctl restart twiliosms

# Stop application
sudo systemctl stop twiliosms

# Start application
sudo systemctl start twiliosms

# Reload nginx
sudo systemctl reload nginx

# Check database size
ls -lh ~/TiwlioSMS/twilio_sms.db
```

---

## 🔄 Updating the Application

```bash
# Navigate to application directory
cd ~/TiwlioSMS

# Activate virtual environment
source venv/bin/activate

# Pull latest changes
git pull origin main

# Install any new dependencies
pip install -r requirements.txt

# Run database migrations (if any)
python3 scripts/migrate_db_v2.py

# Restart service
sudo systemctl restart twiliosms

# Check status
sudo systemctl status twiliosms
```

---

## 🧪 Testing Your Installation

### Test 1: Send Test SMS

1. Login to web interface
2. Go to "Send SMS"
3. Create a test CSV with your phone number:
   ```csv
   phone_number
   +1234567890
   ```
4. Upload and send
5. Check if you receive the SMS

### Test 2: Auto-Reply

1. Send an SMS to your Twilio number
2. You should receive an auto-reply
3. Check "Inbound Messages" in web interface

### Test 3: STOP/START Compliance

1. Send "STOP" to your Twilio number
2. Should receive unsubscribe confirmation
3. Send "START" to re-subscribe
4. Should receive subscription confirmation

---

## ❗ Troubleshooting

### Service Won't Start

```bash
# Check detailed logs
sudo journalctl -u twiliosms -xe

# Common issues:
# 1. Wrong username in service file
# 2. Virtual environment not activated
# 3. Missing dependencies

# Fix: Verify paths
ls -la /home/YOUR_USERNAME/TiwlioSMS/venv/bin/gunicorn
```

### Can't Access Web Interface

```bash
# Check if service is running
sudo systemctl status twiliosms

# Check if nginx is running
sudo systemctl status nginx

# Check if port 8000 is listening
sudo netstat -tlnp | grep 8000

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

### Auto-Reply Not Working

```bash
# Check webhook configuration in Twilio Console
# Verify URL is correct: http://your-domain.com/sms/inbound

# Test webhook manually
curl -X POST http://localhost/sms/inbound \
  -d "From=+1234567890" \
  -d "To=+1987654321" \
  -d "Body=Test" \
  -d "MessageSid=SM123"

# Check logs
tail -f ~/TiwlioSMS/twilio_sms.log | grep "Inbound"
```

### Database Locked Errors

```bash
# Check file permissions
ls -la ~/TiwlioSMS/twilio_sms.db

# Fix permissions
chmod 644 ~/TiwlioSMS/twilio_sms.db
chown YOUR_USERNAME:YOUR_USERNAME ~/TiwlioSMS/twilio_sms.db

# Restart service
sudo systemctl restart twiliosms
```

---

## 📞 Support & Resources

### Documentation
- **Main README:** [README.md](README.md)
- **Beginner's Guide:** [docs/guides/BEGINNER_GUIDE.md](docs/guides/BEGINNER_GUIDE.md)
- **Developer Guide:** [docs/guides/DEVELOPER_GUIDE.md](docs/guides/DEVELOPER_GUIDE.md)
- **Documentation Index:** [docs/INDEX.md](docs/INDEX.md)

### Quick Reference

| Task | Command |
|------|---------|
| View logs | `sudo journalctl -u twiliosms -f` |
| Restart app | `sudo systemctl restart twiliosms` |
| Check status | `sudo systemctl status twiliosms` |
| View app logs | `tail -f ~/TiwlioSMS/twilio_sms.log` |
| Database backup | `cp twilio_sms.db backups/backup_$(date +%Y%m%d).db` |
| Update app | `git pull && pip install -r requirements.txt` |

### Health Checks

```bash
# Quick health check script
cat > ~/health-check.sh << 'EOF'
#!/bin/bash
echo "=== TwilioSMS Health Check ==="
echo "1. Service Status:"
systemctl is-active twiliosms
echo "2. Nginx Status:"
systemctl is-active nginx
echo "3. Application Health:"
curl -s http://localhost/health
echo ""
echo "4. Disk Usage:"
df -h /home
echo "5. Database Size:"
ls -lh ~/TiwlioSMS/twilio_sms.db
EOF

chmod +x ~/health-check.sh
./health-check.sh
```

---

## ✅ Installation Checklist

Print this and check off as you complete each step:

- [ ] Ubuntu server prepared
- [ ] System packages installed (python3, nginx, git)
- [ ] Repository cloned
- [ ] Virtual environment created
- [ ] Dependencies installed
- [ ] Database initialized
- [ ] Systemd service configured
- [ ] Service started and enabled
- [ ] Nginx configured
- [ ] Nginx reloaded
- [ ] Firewall configured (if applicable)
- [ ] Web interface accessible
- [ ] Default password changed
- [ ] Twilio credentials configured
- [ ] Twilio webhook configured
- [ ] Test SMS sent successfully
- [ ] Auto-reply tested
- [ ] HTTPS configured (optional)
- [ ] Backup script setup (optional)
- [ ] Monitoring setup

---

## 🎓 Next Steps

1. **Read the Beginner's Guide:** Learn all features in detail
2. **Configure Auto-Reply Intents:** Customize auto-reply responses
3. **Setup Backups:** Implement automated database backups
4. **Enable HTTPS:** Secure your installation with SSL
5. **Monitor Logs:** Set up log monitoring and alerts

---

## 🌟 You're Ready!

Your TwilioSMS v2.1.0 installation is complete and production-ready!

**Features Available:**
- ✅ Bulk SMS campaigns
- ✅ Auto-reply with STOP/START compliance
- ✅ Intent-based auto-replies
- ✅ Subscriber management
- ✅ Campaign tracking
- ✅ Inbound message logging

**Happy texting! 📱💬**

---

*Installation Guide Version: 2.1.0*  
*Last Updated: February 2, 2026*
