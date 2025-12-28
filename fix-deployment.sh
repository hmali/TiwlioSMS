#!/bin/bash

# Quick Fix Script for GitHub Deployment Issues
# This script fixes common deployment issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

log "GitHub Deployment Quick Fix"
log "This will fix common deployment issues and restart the deployment process"

# Clean up any partial deployment
log "Cleaning up partial deployment..."
systemctl stop twilio-sms 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Remove partial deployment directory
if [[ -d "/opt/twilio-sms" ]]; then
    log "Removing partial deployment..."
    rm -rf /opt/twilio-sms
fi

# Remove systemd service file if it exists but is broken
if [[ -f "/etc/systemd/system/twilio-sms.service" ]]; then
    log "Removing broken service file..."
    rm -f /etc/systemd/system/twilio-sms.service
    systemctl daemon-reload
fi

# Remove nginx config if it exists
if [[ -f "/etc/nginx/sites-enabled/twilio-sms" ]]; then
    log "Removing nginx config..."
    rm -f /etc/nginx/sites-enabled/twilio-sms
    rm -f /etc/nginx/sites-available/twilio-sms
fi

success "Cleanup completed"

# Now run the updated GitHub deployment script
log "Running updated GitHub deployment script..."

# Download the latest version of the deployment script
wget -O /tmp/github-deploy.sh https://raw.githubusercontent.com/hmali/TiwlioSMS/main/github-deploy.sh
chmod +x /tmp/github-deploy.sh

# Run the deployment
/tmp/github-deploy.sh --repo-url https://github.com/hmali/TiwlioSMS.git

success "Deployment should now be working!"
log "Access your application at: http://$(curl -s http://checkip.amazonaws.com)"
