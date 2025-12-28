# Twilio Bulk SMS Web Application

A production-ready Flask web application for sending bulk SMS messages via Twilio with a user-friendly interface, campaign tracking, and delivery status monitoring.

## Features

- 🔐 **User Authentication** - Secure login system
- 📱 **Bulk SMS Sending** - Send messages to hundreds of recipients
- 📊 **Campaign Tracking** - Monitor message delivery status
- 📁 **File Upload** - Support for CSV and TXT phone number files
- 📈 **Real-time Updates** - Live campaign progress monitoring
- 🎯 **Message Statistics** - Character count and SMS count calculator
- 🔧 **Easy Configuration** - Web-based Twilio credentials setup
- 📱 **Mobile Responsive** - Works on all devices
- 🛡️ **Production Ready** - Built for EC2 deployment

## Screenshots

### Login Page
Clean, secure login interface with default admin credentials.

### Dashboard
Overview of campaigns with success/failure statistics and quick actions.

### Send SMS Campaign
User-friendly form with file upload, message composition, and validation.

### Campaign Status
Real-time monitoring of message delivery with detailed status for each number.

## Quick Start

### Prerequisites

- Amazon EC2 instance (Ubuntu 20.04+ recommended)
- Twilio account with Account SID and Auth Token
- Verified Twilio phone number for sending

### One-Click Deployment

1. **Launch EC2 Instance**
   ```bash
   # Connect to your EC2 instance
   ssh -i your-key.pem ubuntu@your-ec2-public-ip
   ```

2. **Download and Run Deployment Script**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/twilio-sms-app/main/deploy.sh
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. **Access Application**
   - Open `http://your-ec2-public-ip` in browser
   - Login with: `admin` / `admin123`
   - Configure Twilio credentials in Settings

### Manual Installation

1. **Clone Repository**
   ```bash
   git clone https://github.com/your-repo/twilio-sms-app.git
   cd twilio-sms-app
   ```

2. **Install Dependencies**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Initialize Database**
   ```bash
   python3 -c "from app import init_db; init_db()"
   ```

4. **Run Application**
   ```bash
   # Development
   python3 app.py
   
   # Production
   gunicorn -c gunicorn_config.py app:app
   ```

## Usage Guide

### 1. Configure Twilio Credentials
- Go to Settings page
- Enter your Twilio Account SID and Auth Token
- Save configuration

### 2. Prepare Phone Numbers File
Create a file with phone numbers in one of these formats:

**Text File (.txt)**
```
+1234567890
+1987654321
+1555123456
```

**CSV File (.csv)**
```
+1234567890,+1987654321
+1555123456
```

### 3. Send SMS Campaign
- Go to Send SMS page
- Enter campaign name and sender phone number
- Upload phone numbers file
- Compose your message
- Confirm and send

### 4. Monitor Campaign
- View real-time progress on campaign status page
- Check individual message delivery status
- Download results for reporting

## File Structure

```
twilio-sms-app/
├── app.py                 # Main Flask application
├── requirements.txt       # Python dependencies
├── deploy.sh             # EC2 deployment script
├── gunicorn_config.py    # Gunicorn configuration
├── templates/            # HTML templates
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── send_sms.html
│   ├── campaign_status.html
│   └── settings.html
├── static/               # Static files
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── app.js
└── uploads/              # File upload directory
```

## Configuration

### Environment Variables
```bash
SECRET_KEY=your-secret-key-here
FLASK_ENV=production
FLASK_APP=app.py
```

### Database
Uses SQLite for simplicity. Tables:
- `users` - User accounts and Twilio credentials
- `campaigns` - SMS campaign records
- `message_status` - Individual message delivery status

## Security Features

- Password hashing with Werkzeug
- Session management
- File upload validation
- SQL injection prevention
- XSS protection
- CSRF protection

## Production Considerations

### SSL/TLS Setup
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com
```

### Monitoring
```bash
# View application logs
sudo journalctl -u twilio-sms-app -f

# Check service status
sudo systemctl status twilio-sms-app
```

### Backup
```bash
# Backup database
cp /opt/twilio-sms-app/twilio_sms.db /backup/location/

# Backup uploads
cp -r /opt/twilio-sms-app/uploads /backup/location/
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Home page (redirects to login/dashboard) |
| `/login` | GET/POST | User login |
| `/logout` | GET | User logout |
| `/dashboard` | GET | Main dashboard |
| `/settings` | GET/POST | Twilio configuration |
| `/send_sms` | GET/POST | Send SMS campaign |
| `/campaign/<id>` | GET | Campaign status page |
| `/api/campaign/<id>/status` | GET | Campaign status API |

## Troubleshooting

### Common Issues

1. **Application won't start**
   ```bash
   sudo journalctl -u twilio-sms-app -n 50
   ```

2. **Nginx errors**
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   ```

3. **Permission issues**
   ```bash
   sudo chown -R www-data:www-data /opt/twilio-sms-app
   ```

### Log Files
- Application: `journalctl -u twilio-sms-app`
- Nginx: `/var/log/nginx/error.log`
- System: `/var/log/syslog`

## Support

For issues and feature requests, please:
1. Check the troubleshooting section
2. Review application logs
3. Create an issue with detailed information

## License

This project is licensed under the MIT License. See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Note**: This application is designed for legitimate bulk SMS use cases. Please ensure compliance with local regulations and obtain proper consent before sending messages.
