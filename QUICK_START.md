# Quick Start: Twilio SMS App Deployment

## 🚀 One-Command Deployment

### Deploy in Under 5 Minutes

```bash
# Connect to your EC2 instance
ssh -i your-key.pem ubuntu@YOUR-EC2-IP

# Deploy with one command
curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/deploy.sh | sudo bash
```

**That's it!** The script automatically:
- ✅ Installs all system dependencies
- ✅ Clones the latest code from GitHub
- ✅ Sets up Python environment properly
- ✅ Configures database and application
- ✅ Creates systemd service with correct permissions
- ✅ Sets up Nginx reverse proxy
- ✅ Starts all services and verifies deployment

### After Deployment

1. **Access:** `http://YOUR-EC2-IP`
2. **Login:** `admin` / `admin123`
3. **⚠️ CRITICAL:** Change default credentials immediately!
4. **Configure:** Add your Twilio credentials in Settings

## 🔧 Management Commands

### Update Application
```bash
sudo /opt/twilio-sms/update.sh
```

### View Logs
```bash
sudo journalctl -u twilio-sms -f
```

### Restart Service
```bash
sudo systemctl restart twilio-sms
```

### Check Status
```bash
sudo systemctl status twilio-sms
```

## 📊 Monitoring

- **Service Status:** `sudo systemctl status twilio-sms`
- **Application Logs:** `sudo journalctl -u twilio-sms -f`
- **Nginx Status:** `sudo systemctl status nginx`
- **Application Files:** `/opt/twilio-sms/`

## 🆘 Troubleshooting

### If Deployment Fails
```bash
# Check the deployment logs
sudo journalctl -u twilio-sms -n 50

# Re-run deployment (it will clean up and start fresh)
curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/deploy.sh | sudo bash
```

### Common Issues
1. **Port 80 blocked:** Check EC2 security group settings
2. **Service won't start:** Check logs with `sudo journalctl -u twilio-sms -f`
3. **Permission errors:** The script handles all permissions automatically

---

**Your production-ready Twilio SMS app is now deployed!** 🎉
