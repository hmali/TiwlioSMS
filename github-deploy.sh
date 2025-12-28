#!/bin/bash

# GitHub Deployment Script for Twilio SMS App
# This script pulls latest code from GitHub and updates the deployed application

set -e  # Exit on any error

# Configuration
APP_NAME="twilio-sms-app"
REPO_URL="https://github.com/hmali/TiwlioSMS"  # Update with your actual repo URL
DEPLOY_DIR="/opt/twilio-sms"
BACKUP_DIR="/opt/twilio-sms-backup"
SERVICE_NAME="twilio-sms"
NGINX_SITE="twilio-sms"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        log "Installing Git..."
        apt update
        apt install -y git
    fi
}

# Backup current deployment
backup_current() {
    if [[ -d "$DEPLOY_DIR" ]]; then
        log "Creating backup of current deployment..."
        
        # Remove old backup if exists
        if [[ -d "$BACKUP_DIR" ]]; then
            rm -rf "$BACKUP_DIR"
        fi
        
        # Create backup
        cp -r "$DEPLOY_DIR" "$BACKUP_DIR"
        success "Backup created at $BACKUP_DIR"
    else
        warning "No existing deployment found to backup"
    fi
}

# Clone or pull latest code from GitHub
pull_latest_code() {
    log "Pulling latest code from GitHub..."
    
    if [[ -d "$DEPLOY_DIR/.git" ]]; then
        # Directory exists and is a git repo
        cd "$DEPLOY_DIR"
        
        # Stash any local changes
        log "Stashing local changes..."
        git stash
        
        # Pull latest changes
        log "Pulling latest changes..."
        git pull origin main || git pull origin master
        
        success "Code updated from GitHub"
    else
        # Fresh clone
        log "Cloning repository..."
        
        # Remove existing directory if it's not a git repo
        if [[ -d "$DEPLOY_DIR" ]]; then
            rm -rf "$DEPLOY_DIR"
        fi
        
        # Clone the repository
        git clone "$REPO_URL" "$DEPLOY_DIR"
        cd "$DEPLOY_DIR"
        
        success "Repository cloned"
    fi
}

# Preserve configuration files
preserve_config() {
    log "Preserving configuration files..."
    
    # Restore .env file from backup if it exists
    if [[ -f "$BACKUP_DIR/.env" ]]; then
        cp "$BACKUP_DIR/.env" "$DEPLOY_DIR/.env"
        success "Environment configuration preserved"
    else
        warning "No .env file found in backup"
    fi
    
    # Restore database if it exists
    if [[ -f "$BACKUP_DIR/twilio_sms.db" ]]; then
        cp "$BACKUP_DIR/twilio_sms.db" "$DEPLOY_DIR/twilio_sms.db"
        success "Database preserved"
    else
        warning "No database found in backup"
    fi
    
    # Restore logs directory
    if [[ -d "$BACKUP_DIR/logs" ]]; then
        cp -r "$BACKUP_DIR/logs" "$DEPLOY_DIR/"
        success "Logs preserved"
    fi
}

# Install/update Python dependencies
update_dependencies() {
    log "Updating Python dependencies..."
    
    cd "$DEPLOY_DIR"
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
    fi
    
    # Activate virtual environment and install dependencies
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    
    success "Dependencies updated"
}

# Update file permissions
update_permissions() {
    log "Updating file permissions..."
    
    # Set ownership
    chown -R www-data:www-data "$DEPLOY_DIR"
    
    # Set directory permissions
    find "$DEPLOY_DIR" -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find "$DEPLOY_DIR" -type f -exec chmod 644 {} \;
    
    # Make scripts executable
    chmod +x "$DEPLOY_DIR"/*.sh
    
    success "Permissions updated"
}

# Restart services
restart_services() {
    log "Restarting services..."
    
    # Stop services
    systemctl stop "$SERVICE_NAME" || true
    
    # Start services
    systemctl start "$SERVICE_NAME"
    systemctl restart nginx
    
    # Enable services to start on boot
    systemctl enable "$SERVICE_NAME"
    systemctl enable nginx
    
    success "Services restarted"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check if service is running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Service is running"
    else
        error "Service failed to start"
    fi
    
    # Check if nginx is running
    if systemctl is-active --quiet nginx; then
        success "Nginx is running"
    else
        error "Nginx failed to start"
    fi
    
    # Test HTTP response
    sleep 5  # Wait for service to fully start
    
    if curl -s http://localhost:8080 > /dev/null; then
        success "Application is responding"
    else
        warning "Application may not be responding on port 8080"
    fi
}

# Rollback function
rollback() {
    error "Deployment failed. Rolling back..."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        systemctl stop "$SERVICE_NAME" || true
        rm -rf "$DEPLOY_DIR"
        mv "$BACKUP_DIR" "$DEPLOY_DIR"
        update_permissions
        restart_services
        success "Rollback completed"
    else
        error "No backup available for rollback"
    fi
}

# Main deployment function
main() {
    log "Starting GitHub deployment for $APP_NAME"
    
    # Set trap for error handling
    trap rollback ERR
    
    check_root
    check_git
    backup_current
    pull_latest_code
    preserve_config
    update_dependencies
    update_permissions
    restart_services
    verify_deployment
    
    success "Deployment completed successfully!"
    log "Application is running at http://YOUR_SERVER_IP:8080"
    log "Logs: journalctl -u $SERVICE_NAME -f"
}

# Show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --repo-url URL    Set repository URL"
    echo "  --help           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --repo-url https://github.com/yourusername/TiwlioSMS.git"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-url)
            REPO_URL="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate repository URL
if [[ "$REPO_URL" == *"YOUR_USERNAME"* ]]; then
    error "Please update the repository URL with your actual GitHub repository"
fi

# Run main function
main

log "GitHub deployment script completed"
