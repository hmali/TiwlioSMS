# Production Deployment Checklist

## Pre-Deployment Checklist

### ✅ Code Review
- [x] Remove default credentials from login page UI
- [x] Password change functionality implemented
- [x] Proper error handling in place
- [x] Database initialization working
- [x] File upload validation working
- [x] Twilio API integration tested

### ✅ Security
- [x] No hardcoded credentials in code
- [x] Secret key environment variable configured
- [x] Password hashing implemented (werkzeug)
- [x] SQL injection protection (parameterized queries)
- [x] File upload restrictions (16MB limit, secure filenames)
- [x] Session management secure
- [x] HTTPS configuration ready

### ✅ Configuration Files
- [x] `gunicorn_config.py` - Production ready (bind to 0.0.0.0:8000)
- [x] `requirements.txt` - All dependencies listed
- [x] `.gitignore` - Excludes sensitive files
- [x] `README.md` - Updated with default credentials and instructions
- [x] `production-deploy.sh` - Automated deployment script

## Deployment Steps

### 1. Server Setup
```bash
# Update server
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx ufw git
```

### 2. Deploy Application
```bash
# Clone repository
cd /var/www
sudo git clone https://github.com/yourusername/TiwlioSMS.git
cd TiwlioSMS

# Run deployment script
chmod +x production-deploy.sh
./production-deploy.sh
```

### 3. DNS Configuration
- [ ] Point A record for `smsgajanannj.com` to server IP
- [ ] Point A record for `www.smsgajanannj.com` to server IP
- [ ] Wait for DNS propagation (can take up to 48 hours, usually 5-10 minutes)

### 4. SSL Certificate
```bash
# After DNS is configured
sudo certbot --nginx -d smsgajanannj.com -d www.smsgajanannj.com
```

### 5. Post-Deployment Security
- [ ] Change default admin credentials immediately
  - Login with `admin` / `admin123`
  - Go to Settings → Change Username & Password
  - Set strong password (min 8 chars, mixed case, numbers, symbols)

- [ ] Configure Twilio credentials
  - Get Account SID from Twilio Console
  - Get Auth Token from Twilio Console
  - Save in Settings → Twilio Configuration

- [ ] Configure firewall
  ```bash
  sudo ufw allow 22/tcp    # SSH
  sudo ufw allow 80/tcp    # HTTP
  sudo ufw allow 443/tcp   # HTTPS
  sudo ufw enable
  ```

### 6. Testing
- [ ] Access application via HTTPS: https://smsgajanannj.com
- [ ] Login with default credentials
- [ ] Change password successfully
- [ ] Configure Twilio credentials
- [ ] Upload phone numbers file
- [ ] Send test SMS campaign (to your own number first)
- [ ] Verify campaign tracking works
- [ ] Check logs for errors

### 7. Monitoring Setup
- [ ] Setup log monitoring
  ```bash
  # View application logs
  sudo journalctl -u twiliosms -f
  
  # View Nginx logs
  sudo tail -f /var/log/nginx/twiliosms_error.log
  ```

- [ ] Setup database backups (automatic via cron)
  ```bash
  # Verify backup cron job
  crontab -l
  
  # Manual backup
  /usr/local/bin/backup-twiliosms-db.sh
  ```

## Post-Deployment Maintenance

### Daily
- [ ] Check application logs for errors
- [ ] Monitor Twilio console for delivery issues

### Weekly
- [ ] Review campaign success rates
- [ ] Check disk space: `df -h`
- [ ] Verify SSL certificate validity: `sudo certbot certificates`

### Monthly
- [ ] Update system packages: `sudo apt update && sudo apt upgrade -y`
- [ ] Review and rotate old database backups
- [ ] Check application performance

## Useful Commands

### Application Management
```bash
# View status
sudo systemctl status twiliosms

# Restart application
sudo systemctl restart twiliosms

# Stop application
sudo systemctl stop twiliosms

# Start application
sudo systemctl start twiliosms

# View logs (follow mode)
sudo journalctl -u twiliosms -f

# View last 100 lines
sudo journalctl -u twiliosms -n 100
```

### Nginx Management
```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# View error logs
sudo tail -f /var/log/nginx/twiliosms_error.log

# View access logs
sudo tail -f /var/log/nginx/twiliosms_access.log
```

### Database Management
```bash
# Backup database
cp /var/www/TiwlioSMS/twilio_sms.db /var/www/TiwlioSMS/backup_$(date +%Y%m%d).db

# View database size
ls -lh /var/www/TiwlioSMS/twilio_sms.db

# Access database (SQLite CLI)
sqlite3 /var/www/TiwlioSMS/twilio_sms.db
```

### SSL Certificate
```bash
# Renew certificates (automatic via cron)
sudo certbot renew

# Force renewal test
sudo certbot renew --dry-run

# View certificate info
sudo certbot certificates
```

## Troubleshooting

### Application won't start
```bash
# Check logs
sudo journalctl -u twiliosms -n 50

# Check if port is in use
sudo netstat -tlnp | grep 8000

# Verify Python environment
source /var/www/TiwlioSMS/venv/bin/activate
python3 -c "from app import init_db; init_db()"
```

### Can't access via domain
```bash
# Check Nginx status
sudo systemctl status nginx

# Test Nginx config
sudo nginx -t

# Check DNS
dig smsgajanannj.com
nslookup smsgajanannj.com

# Check firewall
sudo ufw status
```

### SMS not sending
1. Verify Twilio credentials in Settings
2. Check Twilio Console for account status
3. Verify phone number format (+1234567890)
4. Check campaign status page for error messages
5. Review application logs for Twilio API errors

## Emergency Procedures

### Roll back deployment
```bash
cd /var/www/TiwlioSMS
git log  # Find previous commit
git checkout <previous-commit-hash>
sudo systemctl restart twiliosms
```

### Restore database backup
```bash
cd /var/www/TiwlioSMS
sudo systemctl stop twiliosms
cp backups/backup_YYYYMMDD_HHMMSS.db twilio_sms.db
sudo systemctl start twiliosms
```

### Emergency shutdown
```bash
sudo systemctl stop twiliosms
sudo systemctl stop nginx
```

## Success Criteria

- ✅ Application accessible via HTTPS
- ✅ No default credentials in UI
- ✅ Password change functionality works
- ✅ Twilio integration functional
- ✅ SMS sending successful
- ✅ Campaign tracking accurate
- ✅ Logs accessible and informative
- ✅ Automatic backups working
- ✅ SSL certificate valid and auto-renewing
- ✅ Firewall configured properly

---

**Last Updated:** January 13, 2026
**Version:** 1.0 Production
**Domain:** smsgajanannj.com
