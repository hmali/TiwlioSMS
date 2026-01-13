# Twilio Bulk SMS Web Application

Production-ready Flask web application for sending bulk SMS messages via Twilio.

## 🚀 Features

- **Secure Authentication** - Login system with password change capability
- **Bulk SMS Sending** - Send messages to hundreds of recipients  
- **Campaign Tracking** - Real-time delivery status monitoring
- **File Upload** - CSV and TXT phone number files supported
- **Twilio Integration** - Easy credentials management
- **HTTPS Ready** - SSL certificate automation included
- **Auto Backups** - Daily database backups configured

## 📋 Prerequisites

- Ubuntu Server 20.04+ (or Debian-based Linux)
- Python 3.8+
- Domain name (for HTTPS setup)
- Twilio account (Account SID, Auth Token, Phone Number)

## 🔧 Installation

### Quick Deploy

```bash
# On your server
git clone https://github.com/yourusername/TiwlioSMS.git
cd TiwlioSMS
chmod +x production-deploy.sh
./production-deploy.sh
```

The script will:
- Install all system dependencies
- Create Python virtual environment
- Install Python packages
- Initialize database
- Configure systemd service
- Setup Nginx reverse proxy
- Install SSL certificate
- Configure automatic backups
- Setup firewall

### Manual Installation

If you prefer manual setup:

```bash
# 1. Install system packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv python3-full nginx certbot python3-certbot-nginx ufw git

# 2. Clone repository
git clone https://github.com/yourusername/TiwlioSMS.git
cd TiwlioSMS

# 3. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 4. Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt

# 5. Initialize database
python3 -c "from app import init_db; init_db()"

# 6. Run application
gunicorn -c gunicorn_config.py app:app
```

## 🔑 Default Credentials

**⚠️ CRITICAL: Change immediately after first login!**

```
Username: admin
Password: admin123
```

### Change Password:
1. Login with default credentials
2. Go to **Settings** → **Change Username & Password**
3. Enter current password
4. Set new username and password
5. Click **Update Credentials**
6. Re-login with new credentials

## 📱 Usage

### 1. Initial Setup

After deployment:

1. Access your application (http://your-server-ip or https://smsgajanannj.com)
2. **Change default password immediately**
3. Configure Twilio credentials:
   - Go to **Settings** → **Twilio Configuration**
   - Enter Account SID and Auth Token from [Twilio Console](https://console.twilio.com)
   - Click **Save Configuration**

### 2. Send Bulk SMS

1. Navigate to **Send SMS**
2. Enter campaign details:
   - **Campaign Name**: Descriptive name
   - **From Number**: Your Twilio phone number (format: +1234567890)
   - **Message**: Your SMS text (max 1600 characters)
3. Upload phone numbers file (CSV or TXT)
4. Click **Send Bulk SMS**

### 3. Phone Number File Format

**Text File (.txt):**
```
+1234567890
+1987654321
+1555666777
```

**CSV File (.csv):**
```csv
+1234567890
+1987654321
+1555666777
```

Or comma-separated on one line:
```
+1234567890,+1987654321,+1555666777
```

### 4. Monitor Campaigns

- View all campaigns on **Dashboard**
- Click campaign name for detailed delivery status
- Real-time updates show successful/failed sends

## 🔒 Security

### Production Security Checklist

- [x] Default credentials removed from login page
- [x] Password hashing (werkzeug)
- [x] SQL injection protection (parameterized queries)
- [x] Secure file uploads
- [x] HTTPS encryption
- [x] Firewall configuration
- [x] Secret key randomization

### Best Practices

1. **Change default password immediately**
2. **Use strong passwords** (min 8 chars, mixed case, numbers, symbols)
3. **Keep Twilio credentials secure**
4. **Regular backups** (automated daily at 2 AM)
5. **Monitor logs** for suspicious activity
6. **Keep system updated**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## 🔧 Maintenance

### View Logs

```bash
# Application logs
sudo journalctl -u twiliosms -f

# Nginx logs
sudo tail -f /var/log/nginx/twiliosms_error.log
sudo tail -f /var/log/nginx/twiliosms_access.log
```

### Restart Services

```bash
# Restart application
sudo systemctl restart twiliosms

# Restart Nginx
sudo systemctl restart nginx

# Check status
sudo systemctl status twiliosms
```

### Database Backup

```bash
# Manual backup
cp twilio_sms.db backup_$(date +%Y%m%d).db

# Automatic backups run daily at 2 AM
# Verify cron job:
crontab -l
```

### Update Application

```bash
cd ~/TiwlioSMS  # or /var/www/TiwlioSMS
git pull origin main
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart twiliosms
```

## 🌐 HTTPS Configuration

The deployment script automatically configures HTTPS for **smsgajanannj.com**.

### Prerequisites

1. Point DNS A records to your server IP:
   - `smsgajanannj.com` → Your-Server-IP
   - `www.smsgajanannj.com` → Your-Server-IP

2. Wait for DNS propagation (5-10 minutes)

### Manual SSL Setup

If you skipped SSL during deployment:

```bash
sudo certbot --nginx -d smsgajanannj.com -d www.smsgajanannj.com
```

### Certificate Renewal

Certificates auto-renew via systemd timer. To check:

```bash
# Check renewal timer
sudo systemctl status certbot.timer

# Test renewal
sudo certbot renew --dry-run
```

## 🐛 Troubleshooting

### Application won't start

```bash
# Check logs
sudo journalctl -u twiliosms -n 50

# Check if port is in use
sudo netstat -tlnp | grep 8000

# Verify Python environment
source venv/bin/activate
python3 -c "from app import init_db; init_db()"
```

### Can't access application

```bash
# Check Nginx
sudo systemctl status nginx
sudo nginx -t

# Check firewall
sudo ufw status

# Check DNS
dig smsgajanannj.com
```

### SMS not sending

1. Verify Twilio credentials in Settings
2. Check Twilio phone number is verified
3. Verify phone number format (+1234567890)
4. Check campaign status for error messages
5. Review Twilio Console for account issues

### Virtual Environment Issues

If you get "venv not found" error:

```bash
cd ~/TiwlioSMS
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 📊 Architecture

```
Internet (HTTPS)
    ↓
Nginx (Port 80/443) - SSL Termination & Reverse Proxy
    ↓
Gunicorn (127.0.0.1:8000) - WSGI Application Server
    ↓
Flask Application (app.py) - Web Framework
    ↓
SQLite Database (twilio_sms.db) - Data Storage
    ↓
Twilio API - SMS Delivery
```

## 📁 Project Structure

```
TiwlioSMS/
├── app.py                    # Main Flask application
├── gunicorn_config.py        # Production server config
├── requirements.txt          # Python dependencies
├── production-deploy.sh      # Automated deployment
├── README.md                 # This file
├── .gitignore               # Git configuration
├── templates/               # HTML templates
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── send_sms.html
│   ├── settings.html
│   ├── campaign_status.html
│   └── change_credentials.html
├── static/                  # Static assets
│   ├── css/style.css
│   ├── js/app.js
│   └── images/
└── uploads/                 # File upload directory
```

## 📞 Support

For issues or questions:

1. Check troubleshooting section above
2. Review application logs
3. Consult [Twilio Documentation](https://www.twilio.com/docs)
4. Check [Flask Documentation](https://flask.palletsprojects.com/)

## 📄 License

MIT License - Free for personal and commercial use

## 🙏 Credits

Built with Flask, Twilio API, Bootstrap, and Gunicorn.

---

**Production URL:** https://smsgajanannj.com  
**Default Login:** admin / admin123 (⚠️ Change immediately!)  
**Made with ❤️ for efficient bulk SMS campaigns**
