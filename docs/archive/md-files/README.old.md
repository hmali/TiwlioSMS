# TwilioSMS - Professional SMS Platform

Production-ready Flask application for bulk SMS campaigns and automated message handling via Twilio.

## Features

✅ **Bulk SMS Campaigns** - Upload CSV/TXT files and send to thousands of recipients  
✅ **Auto-Reply System** - Configurable automatic responses to inbound messages  
✅ **Campaign Tracking** - Real-time monitoring and detailed delivery reports  
✅ **User Management** - Secure authentication with individual Twilio credentials  
✅ **Inbound Logging** - Track and view all incoming SMS messages  
✅ **Database Driven** - SQLite backend for campaigns, messages, and settings  

## Quick Start

### Production Deployment

**See [DEPLOYMENT.md](DEPLOYMENT.md) for complete production setup guide.**

### Local Development

```bash
# Clone repository
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS

# Install dependencies
pip install -r requirements.txt

# Run application
python app.py
```

**Default Login:**
- Username: `admin`
- Password: `admin123`
- ⚠️ **Change immediately after first login!**

## Configuration

### 1. Twilio Credentials
1. Get credentials from [Twilio Console](https://console.twilio.com)
2. Login to application
3. Settings → Configure Twilio credentials
4. Enter Account SID and Auth Token

### 2. Auto-Reply Message
1. Settings → Auto-Reply Message
2. Customize message text (max 1600 characters)
3. Save changes

### 3. Webhook Setup
Configure in Twilio Console:
- **URL:** `http://your-domain.com/sms/inbound`
- **Method:** POST
- **Event:** A MESSAGE COMES IN

## Usage

### Send Bulk SMS
1. Navigate to "Send SMS Campaign"
2. Upload phone numbers file (CSV or TXT)
3. Enter campaign details and message
4. Provide Twilio phone number (from your account)
5. Send campaign

### Phone Number Formats

**CSV:**
```csv
+1234567890,+0987654321
+1111111111,+2222222222
```

**Text:**
```
+1234567890
+0987654321
+1111111111
```

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Backend | Flask 2.3.3 |
| Database | SQLite 3 |
| SMS Provider | Twilio API |
| Web Server | Gunicorn |
| Reverse Proxy | Nginx (production) |
| Authentication | Werkzeug Security |

## Project Structure

```
TiwlioSMS/
├── app.py                      # Main Flask application
├── gunicorn_config.py          # Production server config
├── requirements.txt            # Python dependencies
├── DEPLOYMENT.md               # Production deployment guide
├── static/                     # Static assets
├── templates/                  # Jinja2 templates
├── uploads/                    # Temporary uploads (auto-created)
└── scripts/                    # Utility scripts (not deployed)
```

## Security

✅ Werkzeug password hashing  
✅ Session-based authentication  
✅ Protected route decorators  
✅ Secure file upload handling  
✅ Environment variable support  
✅ SQL injection prevention  

**⚠️ Production Recommendations:**
1. Change default admin credentials
2. Set secure `SECRET_KEY` environment variable
3. Use HTTPS with SSL certificates
4. Restrict database file permissions (644)
5. Keep dependencies updated

## Monitoring

### Check Application
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

## Troubleshooting

**Auto-reply not working?**
```bash
cd scripts/diagnostics
./fix_auto_reply_update.sh
```

**Service won't start?**
```bash
sudo systemctl restart twiliosms
sudo journalctl -u twiliosms -n 50
```

**Database permission errors?**
```bash
chmod 644 twilio_sms.db
sudo systemctl restart twiliosms
```

## Updates

```bash
cd ~/TiwlioSMS
git pull origin main
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart twiliosms
```

## License

MIT License

## Author

GMADP Team  
For support, check logs or open a GitHub issue.
