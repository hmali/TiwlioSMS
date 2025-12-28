# Quick Start: GitHub Deployment

This guide provides the fastest way to deploy your Twilio SMS app from GitHub.

## 🚀 One-Line Deployment Commands

### For New Deployments
```bash
# On your EC2 server (Ubuntu):
curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/github-deploy.sh | sudo bash -s -- --repo-url https://github.com/hmali/TiwlioSMS.git
```

### For Existing Deployments
```bash
# Update from GitHub:
sudo /opt/twilio-sms/github-deploy.sh

# Setup auto-updates:
sudo /opt/twilio-sms/setup-auto-update.sh
```

## 📋 Complete Setup Process

### 1. Server Preparation (One Time)
```bash
# Connect to your EC2 instance
ssh -i your-key.pem ubuntu@YOUR-EC2-IP

# Download and run the deployment script
wget https://raw.githubusercontent.com/hmali/TiwlioSMS/main/github-deploy.sh
chmod +x github-deploy.sh
sudo ./github-deploy.sh --repo-url https://github.com/hmali/TiwlioSMS.git
```

### 2. Access Your Application
- **URL:** `http://YOUR-EC2-IP:8080`
- **Login:** `admin` / `admin123`
- **First Steps:** 
  1. Change default credentials in Settings
  2. Configure Twilio credentials
  3. Test SMS functionality

### 3. Setup Automated Updates (Optional)
```bash
# Setup automatic deployment from GitHub
sudo ./setup-auto-update.sh

# Choose your preferred method:
# 1) Cron-based (daily at 3 AM)
# 2) Webhook-based (real-time)
# 3) Both
```

## 🔧 Development Workflow

### Local Development
```bash
# Clone your repository
git clone https://github.com/hmali/TiwlioSMS.git
cd TiwlioSMS

# Setup development environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run locally
python3 app.py
# Access at http://localhost:5000
```

### Making Changes
```bash
# Create feature branch
git checkout -b feature/my-new-feature

# Make your changes
# Edit files, test locally

# Commit and push
git add .
git commit -m "Add new feature"
git push origin feature/my-new-feature

# Create Pull Request on GitHub
# Merge to main branch triggers auto-deployment (if configured)
```

## 📊 Monitoring and Logs

### Check Application Status
```bash
# Service status
sudo systemctl status twilio-sms

# Application logs
sudo journalctl -u twilio-sms -f

# Nginx status
sudo systemctl status nginx
```

### View Deployment Logs
```bash
# Manual deployment logs
tail -f /var/log/twilio-sms-update.log

# Webhook deployment logs
tail -f /var/log/twilio-sms-webhook.log

# System logs
sudo journalctl -f
```

## 🚨 Troubleshooting

### Common Issues and Solutions

1. **Deployment Fails:**
   ```bash
   # Check logs
   tail -f /var/log/twilio-sms-update.log
   
   # Verify repository access
   git clone https://github.com/hmali/TiwlioSMS.git /tmp/test-clone
   
   # Manual fix
   sudo /opt/twilio-sms/github-deploy.sh
   ```

2. **Application Won't Start:**
   ```bash
   # Check service status
   sudo systemctl status twilio-sms
   
   # Check logs
   sudo journalctl -u twilio-sms -n 50
   
   # Restart service
   sudo systemctl restart twilio-sms
   ```

3. **Webhook Not Working:**
   ```bash
   # Check webhook service
   sudo systemctl status twilio-sms-webhook
   
   # Test webhook locally
   curl -X POST http://localhost:9000
   
   # Check GitHub webhook settings
   # Repository > Settings > Webhooks
   ```

## 🔐 Security Checklist

### After Deployment:
- [ ] Change default admin credentials
- [ ] Configure Twilio credentials
- [ ] Setup SSL certificate (recommended for production)
- [ ] Configure firewall rules
- [ ] Setup regular backups

### For GitHub Integration:
- [ ] Repository is private (recommended)
- [ ] Webhook secret is configured (if using webhooks)
- [ ] GitHub Actions secrets are set (if using CI/CD)
- [ ] SSH keys are properly configured

## 📚 Additional Resources

- **Complete Guide:** [GITHUB_INTEGRATION.md](GITHUB_INTEGRATION.md)
- **Deployment Guide:** [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md)
- **Main Documentation:** [README.md](README.md)

## 🆘 Need Help?

1. Check the logs first
2. Review troubleshooting section
3. Verify all prerequisites are met
4. Test with manual deployment
5. Check GitHub repository settings

---

**Your Twilio SMS App with GitHub integration is now ready for production!** 🎉
