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

# Check if this is initial deployment
is_initial_deployment() {
    [[ ! -f "/etc/systemd/system/$SERVICE_NAME.service" ]]
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    apt update
    apt install -y python3 python3-pip python3-venv nginx curl wget
    
    success "System dependencies installed"
}

# Create systemd service file
create_systemd_service() {
    log "Creating systemd service file..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Twilio SMS Application
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$DEPLOY_DIR
Environment=PATH=$DEPLOY_DIR/venv/bin
ExecStart=$DEPLOY_DIR/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$DEPLOY_DIR
PrivateDevices=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictAddressFamilies=AF_INET AF_INET6
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    success "Systemd service created"
}

# Create nginx configuration
create_nginx_config() {
    log "Creating Nginx configuration..."
    
    cat > "/etc/nginx/sites-available/$NGINX_SITE" << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout       300;
        proxy_send_timeout          300;
        proxy_read_timeout          300;
        send_timeout                300;
    }
    
    location /static {
        alias /opt/twilio-sms/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /uploads {
        alias /opt/twilio-sms/uploads;
        expires 1h;
        add_header Cache-Control "private";
    }
}
EOF
    
    # Enable the site
    ln -sf "/etc/nginx/sites-available/$NGINX_SITE" "/etc/nginx/sites-enabled/"
    
    # Remove default nginx site if it exists
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    nginx -t
    
    success "Nginx configuration created"
}

# Initialize application database and setup
initialize_application() {
    log "Initializing application..."
    
    cd "$DEPLOY_DIR"
    
    # Create uploads directory
    mkdir -p uploads logs
    
    # Initialize database if it doesn't exist
    if [[ ! -f "twilio_sms.db" ]]; then
        log "Initializing database..."
        source venv/bin/activate
        python3 -c "from app import init_db; init_db()"
        success "Database initialized"
    fi
    
    # Create .env file if it doesn't exist
    if [[ ! -f ".env" ]]; then
        log "Creating default .env file..."
        cp .env.example .env
        success "Default .env file created"
    fi
    
    success "Application initialized"
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
    
    # Check if systemd service exists before trying to stop it
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        log "Stopping existing service..."
        systemctl stop "$SERVICE_NAME" || true
    else
        log "Service not found, will start fresh..."
    fi
    
    # Start services
    log "Starting $SERVICE_NAME service..."
    systemctl start "$SERVICE_NAME"
    
    log "Restarting nginx..."
    systemctl restart nginx
    
    # Enable services to start on boot
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    
    success "Services started and enabled"
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
    
    # Test both direct application port and nginx proxy
    if curl -s http://localhost:8000 > /dev/null; then
        success "Application is responding on port 8000"
        
        if curl -s http://localhost > /dev/null; then
            success "Application is accessible via Nginx on port 80"
        else
            warning "Nginx proxy may not be working properly"
        fi
    else
        warning "Application may not be responding on port 8000"
        
        # Show some diagnostic info
        log "Checking application status..."
        systemctl status "$SERVICE_NAME" --no-pager -l
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
    
    # Check if this is initial deployment
    local initial_deploy=false
    if is_initial_deployment; then
        initial_deploy=true
        log "Detected initial deployment"
    else
        log "Detected update deployment"
    fi
    
    # Set trap for error handling
    trap rollback ERR
    
    check_root
    check_git
    
    # For initial deployments, install system dependencies
    if [[ "$initial_deploy" == "true" ]]; then
        install_dependencies
    fi
    
    backup_current
    pull_latest_code
    
    # For initial deployments, set up system services
    if [[ "$initial_deploy" == "true" ]]; then
        create_systemd_service
        create_nginx_config
        initialize_application
    else
        preserve_config
    fi
    
    update_dependencies
    update_permissions
    restart_services
    verify_deployment
    
    success "Deployment completed successfully!"
    
    if [[ "$initial_deploy" == "true" ]]; then
        log "=== INITIAL DEPLOYMENT COMPLETE ==="
        log "Application URL: http://$(curl -s http://checkip.amazonaws.com):80"
        log "Default Login: admin / admin123"
        log "Please change default credentials immediately!"
        log ""
        log "Next steps:"
        log "1. Access the application and change default login"
        log "2. Configure Twilio credentials in Settings"
        log "3. Test SMS functionality"
        log ""
        log "Setup auto-updates with: sudo $DEPLOY_DIR/setup-auto-update.sh"
    else
        log "Application updated and running at http://YOUR_SERVER_IP:80"
    fi
    
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
