# Twilio Bulk SMS Web Application

A production-ready Flask web application for sending bulk SMS messages via Twilio with a user-friendly interface, campaign tracking, and delivery status monitoring.

## 🚀 Features

- 🔐 **Secure Authentication** - Login system with password change capability
- 📱 **Bulk SMS Sending** - Send messages to hundreds of recipients
- 📊 **Campaign Tracking** - Monitor message delivery status in real-time
- 📁 **File Upload Support** - CSV and TXT phone number files
- 📈 **Live Updates** - Real-time campaign progress monitoring
- 🎯 **Message Statistics** - Character count and SMS count calculator
- 🔧 **Easy Configuration** - Web-based Twilio credentials management
- 📱 **Responsive Design** - Works on all devices
- 🛡️ **Production Ready** - Built for deployment with HTTPS support

## 📋 Prerequisites

- Ubuntu Server 20.04+ (or similar Linux distribution)
- Python 3.8+
- Twilio account with Account SID and Auth Token
- Verified Twilio phone number for sending SMS
- Domain name (for HTTPS setup)

## 🔧 Installation

### 1. System Setup

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required system packages
sudo apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx
```

### 2. Application Setup

```bash
# Clone the repository
cd /var/www
sudo git clone https://github.com/yourusername/TiwlioSMS.git
cd TiwlioSMS

# Set proper permissions
sudo chown -R $USER:$USER /var/www/TiwlioSMS

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Initialize database
python3 -c "from app import init_db; init_db()"
```

### 3. Configure Gunicorn Service

Create systemd service file:

```bash
sudo nano /etc/systemd/system/twiliosms.service
```

Add the following content:

```ini
[Unit]
Description=Twilio SMS Gunicorn Application
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/var/www/TiwlioSMS
Environment="PATH=/var/www/TiwlioSMS/venv/bin"
Environment="SECRET_KEY=your-super-secret-key-change-this-in-production"
ExecStart=/var/www/TiwlioSMS/venv/bin/gunicorn -c gunicorn_config.py app:app

[Install]
WantedBy=multi-user.target
```

**Important:** Change `your-super-secret-key-change-this-in-production` to a strong random string!

Start and enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl start twiliosms
sudo systemctl enable twiliosms
sudo systemctl status twiliosms
```

### 4. Configure Nginx for HTTPS

Create Nginx configuration:

```bash
sudo nano /etc/nginx/sites-available/twiliosms
```

Add the following content:

```nginx
server {
    listen 80;
    server_name smsgajanannj.com www.smsgajanannj.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    client_max_body_size 16M;
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 5. Setup SSL Certificate (HTTPS)

```bash
# Get SSL certificate from Let's Encrypt
sudo certbot --nginx -d smsgajanannj.com -d www.smsgajanannj.com

# Follow the prompts and select option 2 to redirect HTTP to HTTPS

# Test auto-renewal
sudo certbot renew --dry-run
```

Your application will now be accessible at: **https://smsgajanannj.com**

## 🔑 Default Login Credentials

**⚠️ IMPORTANT: Change these immediately after first login!**

- **Username:** `admin`
- **Password:** `admin123`

### Changing Default Credentials

1. Login with default credentials
2. Navigate to **Settings** → **Account Information**
3. Click **Change Username & Password**
4. Enter current password and set new credentials
5. You will be logged out and need to login with new credentials

## 📱 Usage Guide

### 1. Initial Setup

1. Login to the application at https://smsgajanannj.com
2. **Change default password immediately** (Settings → Change Username & Password)
3. Configure Twilio credentials (Settings → Twilio Configuration):
   - Enter your Twilio Account SID
   - Enter your Twilio Auth Token
   - Click "Save Twilio Configuration"

### 2. Sending Bulk SMS

1. Navigate to **Send SMS** from the dashboard
2. Enter campaign details:
   - **Campaign Name:** Descriptive name for this campaign
   - **From Number:** Your Twilio phone number (format: +1234567890)
   - **Message:** Your SMS text (max 1600 characters)
3. Upload phone numbers file (CSV or TXT format)
4. Click "Send Bulk SMS"

### 3. Phone Numbers File Format

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

Or comma-separated:
```
+1234567890,+1987654321,+1555666777
```

### 4. Monitoring Campaigns

- View all campaigns on the **Dashboard**
- Click on any campaign to see detailed delivery status
- Real-time updates show successful/failed sends
- Export campaign data for reporting

## 🔒 Security Best Practices

1. **Change default credentials immediately**
2. **Use strong passwords** (minimum 8 characters, mix of letters, numbers, symbols)
3. **Keep Twilio credentials secure** - never share or commit to version control
4. **Regular backups** of the SQLite database (`twilio_sms.db`)
5. **Monitor logs** for suspicious activity
6. **Keep system updated**: `sudo apt update && sudo apt upgrade`
7. **Firewall configuration**:
   ```bash
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw enable
   ```

## 🔧 Maintenance

### View Application Logs

```bash
# Application logs
sudo journalctl -u twiliosms -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Restart Service

```bash
sudo systemctl restart twiliosms
sudo systemctl restart nginx
```

### Update Application

```bash
cd /var/www/TiwlioSMS
git pull origin main
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart twiliosms
```

### Backup Database

```bash
# Create backup
cp /var/www/TiwlioSMS/twilio_sms.db /var/www/TiwlioSMS/backup_$(date +%Y%m%d).db

# Automated daily backup (add to crontab)
echo "0 2 * * * cp /var/www/TiwlioSMS/twilio_sms.db /var/www/TiwlioSMS/backup_\$(date +\%Y\%m\%d).db" | crontab -
```

## 🐛 Troubleshooting

### Application won't start

```bash
# Check service status
sudo systemctl status twiliosms

# Check logs
sudo journalctl -u twiliosms -n 50
```

### Can't access via domain

```bash
# Check Nginx status
sudo systemctl status nginx

# Test Nginx configuration
sudo nginx -t

# Check DNS records
dig smsgajanannj.com
```

### SMS not sending

1. Verify Twilio credentials in Settings
2. Ensure Twilio phone number is verified
3. Check phone number formats (+1234567890)
4. Review campaign status for error messages
5. Check Twilio console for account issues

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review application logs
3. Consult Twilio documentation: https://www.twilio.com/docs

## 📄 License

MIT License - Feel free to use for personal or commercial projects

## 🙏 Credits

Built with Flask, Twilio API, and Bootstrap for a modern, responsive interface.

---

**Made with ❤️ for efficient bulk SMS campaigns**
