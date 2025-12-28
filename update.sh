#!/bin/bash

# Simple Update Script for Twilio SMS App
# This script updates an existing deployment from GitHub

set -e

# Configuration
DEPLOY_DIR="/opt/twilio-sms"
BACKUP_DIR="/opt/twilio-sms-backup"
SERVICE_NAME="twilio-sms"
REPO_URL="https://github.com/hmali/TiwlioSMS"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# Check if running as root
[[ $EUID -eq 0 ]] || error "This script must be run as root (use sudo)"

# Check if deployment exists
[[ -d "$DEPLOY_DIR" ]] || error "No existing deployment found. Run deploy.sh first."

log "Updating Twilio SMS App from GitHub..."

# Create backup
log "Creating backup..."
rm -rf "$BACKUP_DIR"
cp -r "$DEPLOY_DIR" "$BACKUP_DIR"

# Update code
cd "$DEPLOY_DIR"
log "Pulling latest code..."
git stash >/dev/null 2>&1 || true
git pull origin main || git pull origin master

# Preserve configuration
log "Preserving configuration..."
[[ -f "$BACKUP_DIR/.env" ]] && cp "$BACKUP_DIR/.env" "$DEPLOY_DIR/.env"
[[ -f "$BACKUP_DIR/twilio_sms.db" ]] && cp "$BACKUP_DIR/twilio_sms.db" "$DEPLOY_DIR/twilio_sms.db"

# Update dependencies
log "Updating dependencies..."
source venv/bin/activate
pip install --upgrade pip >/dev/null 2>&1
pip install -r requirements.txt >/dev/null 2>&1

# Fix permissions
log "Setting permissions..."
chown -R www-data:www-data "$DEPLOY_DIR"
find "$DEPLOY_DIR/venv/bin" -type f -exec chmod +x {} \;

# Restart service
log "Restarting service..."
systemctl restart "$SERVICE_NAME"

# Wait and verify
sleep 5
if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "Update completed successfully!"
    log "Application is running at: http://$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo 'YOUR-IP')"
else
    error "Service failed to start after update"
fi
