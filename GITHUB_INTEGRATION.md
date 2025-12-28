# GitHub Integration and Deployment Guide

This guide covers setting up automated deployment from GitHub for your Twilio SMS application.

## Overview

The GitHub integration provides:
- **Automated deployment** from GitHub repository
- **Real-time updates** via webhooks
- **Scheduled updates** via cron jobs
- **CI/CD pipeline** with GitHub Actions
- **Rollback capabilities** for failed deployments

## Quick Start

### 1. Setup Git Workflow
```bash
chmod +x setup-git-workflow.sh
./setup-git-workflow.sh
```

### 2. Setup GitHub Repository
1. Create a new repository on GitHub
2. Push your code to the repository
3. Note the repository URL for deployment

### 3. Configure Deployment
```bash
chmod +x github-deploy.sh setup-auto-update.sh
sudo ./setup-auto-update.sh
```

## Deployment Methods

### Method 1: Manual Deployment
Deploy the latest code from GitHub manually:

```bash
sudo ./github-deploy.sh --repo-url https://github.com/yourusername/TiwlioSMS.git
```

### Method 2: Scheduled Deployment (Cron)
Automatically update daily at 3 AM:

```bash
sudo ./setup-auto-update.sh
# Select option 1 for cron-based updates
```

### Method 3: Real-time Deployment (Webhooks)
Deploy immediately when code is pushed to GitHub:

```bash
sudo ./setup-auto-update.sh
# Select option 2 for webhook updates
```

### Method 4: GitHub Actions CI/CD
Automated deployment with testing pipeline (requires GitHub repository).

## Detailed Setup Instructions

### GitHub Repository Setup

1. **Create Repository:**
   ```bash
   # On GitHub.com
   # 1. Click "New repository"
   # 2. Name it "TiwlioSMS" or your preferred name
   # 3. Make it private for security
   # 4. Don't initialize with README (we have one)
   ```

2. **Push Code:**
   ```bash
   ./setup-git-workflow.sh
   # Follow the prompts to configure Git and push code
   ```

### Webhook Configuration

1. **Server Setup:**
   ```bash
   sudo ./setup-auto-update.sh
   # Select webhook option
   # Note the webhook port (default: 9000)
   ```

2. **GitHub Webhook Setup:**
   - Go to your repository on GitHub
   - Click Settings → Webhooks → Add webhook
   - Set Payload URL: `http://YOUR_SERVER_IP:9000`
   - Set Content type: `application/json`
   - Select "Just the push event"
   - Ensure webhook is Active

3. **Test Webhook:**
   ```bash
   # Push a change to test
   echo "# Test" >> README.md
   git add README.md
   git commit -m "Test webhook deployment"
   git push origin main
   
   # Check deployment logs
   tail -f /var/log/twilio-sms-webhook.log
   ```

### GitHub Actions Setup

1. **Configure Secrets:**
   Go to GitHub repository → Settings → Secrets and variables → Actions
   
   Add these secrets:
   - `DEPLOY_HOST`: Your server IP address
   - `DEPLOY_USER`: SSH username (usually `ubuntu`)
   - `DEPLOY_KEY`: SSH private key content

2. **SSH Key Setup:**
   ```bash
   # On your local machine
   ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""
   
   # Copy public key to server
   ssh-copy-id -i ~/.ssh/deploy_key.pub ubuntu@YOUR_SERVER_IP
   
   # Copy private key content for GitHub secret
   cat ~/.ssh/deploy_key
   # Paste this entire output as DEPLOY_KEY secret
   ```

## Configuration Files

### Environment Configuration
The deployment preserves your configuration:

```bash
# Server configuration is preserved during updates
/opt/twilio-sms/.env
/opt/twilio-sms/twilio_sms.db
/opt/twilio-sms/logs/
```

### Service Management
```bash
# Check application status
sudo systemctl status twilio-sms

# View logs
sudo journalctl -u twilio-sms -f

# Restart if needed
sudo systemctl restart twilio-sms
```

### Webhook Service Management
```bash
# Check webhook status
sudo systemctl status twilio-sms-webhook

# View webhook logs
tail -f /var/log/twilio-sms-webhook.log

# Restart webhook
sudo systemctl restart twilio-sms-webhook
```

## Security Considerations

### Webhook Security
- Use webhook secrets for signature verification
- Configure firewall to limit webhook port access
- Consider using HTTPS for webhook endpoint

### Repository Security
- Keep repository private
- Use environment variables for sensitive data
- Never commit `.env` files or database files

### Server Security
- Use SSH keys instead of passwords
- Limit SSH access to specific IPs
- Keep server packages updated

## Troubleshooting

### Common Issues

1. **Deployment Script Fails:**
   ```bash
   # Check if repository URL is correct
   sudo ./github-deploy.sh --repo-url YOUR_REPO_URL
   
   # Check logs
   tail -f /var/log/twilio-sms-update.log
   ```

2. **Webhook Not Triggering:**
   ```bash
   # Check webhook service
   sudo systemctl status twilio-sms-webhook
   
   # Check webhook logs
   tail -f /var/log/twilio-sms-webhook.log
   
   # Test webhook manually
   curl -X POST http://localhost:9000
   ```

3. **GitHub Actions Failing:**
   ```bash
   # Check GitHub Actions tab in repository
   # Verify all secrets are set correctly
   # Check SSH key permissions
   ```

4. **Application Not Starting:**
   ```bash
   # Check service status
   sudo systemctl status twilio-sms
   
   # View detailed logs
   sudo journalctl -u twilio-sms -n 50
   
   # Check file permissions
   ls -la /opt/twilio-sms/
   ```

### Log Locations
- **Deployment logs:** `/var/log/twilio-sms-update.log`
- **Webhook logs:** `/var/log/twilio-sms-webhook.log`
- **Application logs:** `journalctl -u twilio-sms`
- **Nginx logs:** `/var/log/nginx/error.log`

### Rollback Process
If deployment fails, automatic rollback is triggered:

```bash
# Manual rollback if needed
sudo systemctl stop twilio-sms
sudo mv /opt/twilio-sms-backup /opt/twilio-sms
sudo systemctl start twilio-sms
```

## Advanced Configuration

### Custom Deployment Branch
```bash
# Modify github-deploy.sh to use different branch
sed -i 's/main/your-branch/g' github-deploy.sh
```

### Multiple Environment Setup
```bash
# Production
sudo ./github-deploy.sh --repo-url https://github.com/user/repo.git

# Staging
sudo ./github-deploy.sh --repo-url https://github.com/user/repo.git --branch staging
```

### Custom Webhook Port
```bash
# Modify webhook port
sudo ./setup-auto-update.sh
# Enter custom port when prompted
```

## Monitoring and Maintenance

### Health Checks
```bash
# Check all services
sudo systemctl status twilio-sms twilio-sms-webhook nginx

# Check application response
curl http://localhost:8080

# Check webhook endpoint
curl -X POST http://localhost:9000
```

### Log Rotation
Logs are automatically rotated by systemd, but you can configure custom rotation:

```bash
# Create logrotate configuration
sudo tee /etc/logrotate.d/twilio-sms << EOF
/var/log/twilio-sms-*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
}
EOF
```

### Backup Strategy
```bash
# Automated backups are created during deployment
# Manual backup:
sudo cp -r /opt/twilio-sms /opt/twilio-sms-manual-backup
```

## Support

For issues or questions:
1. Check the logs first
2. Review this documentation
3. Test with manual deployment
4. Check GitHub repository settings
5. Verify server connectivity and permissions

The deployment system includes comprehensive error handling and automatic rollback to ensure your application remains available during updates.
