#!/bin/bash

# Ultimate Twilio SMS App Deployment Script
# This script handles complete deployment from GitHub with proper error handling

set -e  # Exit on any error

# Configuration
APP_NAME="twilio-sms-app"
REPO_URL="https://github.com/hmali/TiwlioSMS"
DEPLOY_DIR="/opt/twilio-sms"
BACKUP_DIR="/opt/twilio-sms-backup"
SERVICE_NAME="twilio-sms"
NGINX_SITE="twilio-sms"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Complete cleanup of any existing installation
complete_cleanup() {
    log "=== COMPLETE SYSTEM CLEANUP ==="
    
    # Stop and disable services
    systemctl stop twilio-sms 2>/dev/null || true
    systemctl disable twilio-sms 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    
    # Kill any running processes
    pkill -f "gunicorn.*twilio" 2>/dev/null || true
    pkill -f "python.*app.py" 2>/dev/null || true
    
    # Remove systemd service
    rm -f /etc/systemd/system/twilio-sms.service
    systemctl daemon-reload
    
    # Remove nginx config
    rm -f /etc/nginx/sites-enabled/twilio-sms
    rm -f /etc/nginx/sites-available/twilio-sms
    
    # Remove directories
    rm -rf /opt/twilio-sms
    rm -rf /opt/twilio-sms-backup
    
    success "Complete cleanup finished"
}

# Install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        nginx \
        curl \
        wget \
        git \
        build-essential \
        supervisor
    
    success "System dependencies installed"
}

# Clone repository and setup directory structure
setup_application() {
    log "Setting up application..."
    
    # Create deployment directory
    mkdir -p $DEPLOY_DIR
    cd $DEPLOY_DIR
    
    # Clone repository
    log "Cloning repository from $REPO_URL"
    git clone $REPO_URL .
    
    # Configure Git safe directory
    log "Configuring Git safe directory..."
    git config --global --add safe.directory "$DEPLOY_DIR"
    
    # Create necessary directories
    mkdir -p uploads logs
    
    success "Application directory setup complete"
}

# Setup Python environment with proper permissions
setup_python_environment() {
    log "Setting up Python virtual environment..."
    
    cd $DEPLOY_DIR
    
    # Create virtual environment as root first
    python3 -m venv venv
    
    # Activate and install dependencies
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # Ensure gunicorn is installed
    pip install gunicorn
    
    # Verify gunicorn installation
    if [[ ! -f "venv/bin/gunicorn" ]]; then
        error "Gunicorn installation failed"
        exit 1
    fi
    
    success "Python environment setup complete"
}

# Initialize application database and config
initialize_application() {
    log "Initializing application..."
    
    cd $DEPLOY_DIR
    source venv/bin/activate
    
    # Create .env file
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp .env.example .env
        else
            cat > .env << 'EOF'
SECRET_KEY=change-this-secret-key-in-production-please
FLASK_ENV=production
FLASK_APP=app.py
EOF
        fi
    fi
    
    # Initialize database
    log "Initializing database..."
    python3 -c "from app import init_db; init_db()" || {
        warning "Database initialization failed, will create manually"
        python3 -c "
import sqlite3
import os
import hashlib
from werkzeug.security import generate_password_hash

# Create database
conn = sqlite3.connect('twilio_sms.db')
cursor = conn.cursor()

# Create tables
cursor.execute('''
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    twilio_account_sid TEXT,
    twilio_auth_token TEXT
)
''')

cursor.execute('''
CREATE TABLE IF NOT EXISTS campaigns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    sender_phone TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_numbers INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending'
)
''')

cursor.execute('''
CREATE TABLE IF NOT EXISTS message_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    campaign_id INTEGER,
    phone_number TEXT,
    status TEXT,
    error_message TEXT,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (campaign_id) REFERENCES campaigns (id)
)
''')

# Insert default admin user
password_hash = generate_password_hash('admin123')
cursor.execute('''
INSERT OR IGNORE INTO users (username, password_hash) 
VALUES (?, ?)
''', ('admin', password_hash))

conn.commit()
conn.close()
print('Database initialized successfully')
"
    }
    
    success "Application initialized"
}

# Create optimized gunicorn configuration
create_gunicorn_config() {
    log "Creating Gunicorn configuration..."
    
    cat > $DEPLOY_DIR/gunicorn_config.py << 'EOF'
import os

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = 2
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Restart workers
max_requests = 1000
max_requests_jitter = 100
preload_app = True

# Logging
access_logfile = "/opt/twilio-sms/logs/access.log"
error_logfile = "/opt/twilio-sms/logs/error.log"
loglevel = "info"

# Process naming
proc_name = "twilio-sms-app"

# User and group
user = "www-data"
group = "www-data"
EOF
    
    success "Gunicorn configuration created"
}

# Create systemd service with proper configuration
create_systemd_service() {
    log "Creating systemd service..."
    
    cat > /etc/systemd/system/twilio-sms.service << EOF
[Unit]
Description=Twilio SMS Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$DEPLOY_DIR
Environment=PATH=/opt/twilio-sms/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONPATH=/opt/twilio-sms
Environment=FLASK_APP=app.py
Environment=FLASK_ENV=production

# Ensure logs directory exists
ExecStartPre=/bin/mkdir -p /opt/twilio-sms/logs
ExecStartPre=/bin/chown www-data:www-data /opt/twilio-sms/logs

# Start application
ExecStart=/opt/twilio-sms/venv/bin/gunicorn --config gunicorn_config.py app:app

# Restart configuration
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=5

# Output to journal
StandardOutput=journal
StandardError=journal
SyslogIdentifier=twilio-sms

# Security settings (relaxed for functionality)
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
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
    
    cat > /etc/nginx/sites-available/twilio-sms << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 50M;
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout       300;
        proxy_send_timeout          300;
        proxy_read_timeout          300;
        send_timeout                300;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # Static files
    location /static {
        alias /opt/twilio-sms/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Upload files (protected)
    location /uploads {
        alias /opt/twilio-sms/uploads;
        expires 1h;
        add_header Cache-Control "private, no-cache";
        
        # Only allow specific file types
        location ~* \.(txt|csv)$ {
            add_header Content-Type text/plain;
        }
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Enable site and remove default
    ln -sf /etc/nginx/sites-available/twilio-sms /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    nginx -t || {
        error "Nginx configuration test failed"
        exit 1
    }
    
    success "Nginx configuration created"
}

# Set proper file permissions
set_permissions() {
    log "Setting file permissions..."
    
    # Set ownership
    chown -R www-data:www-data $DEPLOY_DIR
    
    # Set directory permissions
    find $DEPLOY_DIR -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find $DEPLOY_DIR -type f -exec chmod 644 {} \;
    
    # Make scripts executable
    find $DEPLOY_DIR -name "*.sh" -exec chmod +x {} \;
    
    # Make venv binaries executable
    find $DEPLOY_DIR/venv/bin -type f -exec chmod +x {} \;
    
    # Ensure log directory has proper permissions
    chmod 755 $DEPLOY_DIR/logs
    
    success "File permissions set"
}

# Start all services
start_services() {
    log "Starting services..."
    
    # Enable and start twilio-sms service
    systemctl enable twilio-sms
    systemctl start twilio-sms
    
    # Enable and start nginx
    systemctl enable nginx
    systemctl restart nginx
    
    success "Services started"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Wait for services to start
    sleep 10
    
    # Check twilio-sms service
    if systemctl is-active --quiet twilio-sms; then
        success "Twilio SMS service is running"
    else
        error "Twilio SMS service failed to start"
        systemctl status twilio-sms --no-pager
        journalctl -u twilio-sms -n 20 --no-pager
        exit 1
    fi
    
    # Check nginx service
    if systemctl is-active --quiet nginx; then
        success "Nginx service is running"
    else
        error "Nginx service failed to start"
        systemctl status nginx --no-pager
        exit 1
    fi
    
    # Test application response
    log "Testing application response..."
    sleep 5
    
    if curl -f -s http://localhost:8000 >/dev/null; then
        success "Application responding on port 8000"
        
        if curl -f -s http://localhost >/dev/null; then
            success "Application accessible via Nginx on port 80"
        else
            warning "Nginx proxy may have issues"
        fi
    else
        error "Application not responding"
        log "Checking application logs..."
        journalctl -u twilio-sms -n 30 --no-pager
        exit 1
    fi
    
    success "Deployment verification complete"
}

# Show final status and instructions
show_completion_message() {
    # Get public IP
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || curl -s http://ipinfo.io/ip 2>/dev/null || echo "YOUR-EC2-IP")
    
    echo ""
    echo "=================================================================="
    success "🎉 TWILIO SMS APP DEPLOYMENT COMPLETE!"
    echo "=================================================================="
    echo ""
    log "📱 Application URL: http://$PUBLIC_IP"
    log "🔐 Default Login: admin / admin123"
    log "⚠️  CRITICAL: Change default credentials immediately!"
    echo ""
    log "📋 Next Steps:"
    log "1. Open http://$PUBLIC_IP in your browser"
    log "2. Login with admin/admin123"
    log "3. Go to Settings and change your credentials"
    log "4. Configure your Twilio Account SID and Auth Token"
    log "5. Test SMS functionality"
    echo ""
    log "🔧 Management Commands:"
    log "- View logs: sudo journalctl -u twilio-sms -f"
    log "- Restart app: sudo systemctl restart twilio-sms"
    log "- Check status: sudo systemctl status twilio-sms"
    log "- Update app: sudo $DEPLOY_DIR/deploy.sh"
    echo ""
    log "📁 Important Files:"
    log "- Application: $DEPLOY_DIR"
    log "- Database: $DEPLOY_DIR/twilio_sms.db"
    log "- Logs: $DEPLOY_DIR/logs/"
    log "- Config: $DEPLOY_DIR/.env"
    echo ""
    success "Deployment completed successfully! 🚀"
    echo "=================================================================="
}

# Main deployment function
main() {
    log "=== TWILIO SMS APP ULTIMATE DEPLOYMENT ==="
    log "Starting fresh deployment from GitHub..."
    
    check_root
    complete_cleanup
    install_system_dependencies
    setup_application
    setup_python_environment
    initialize_application
    create_gunicorn_config
    create_systemd_service
    create_nginx_config
    set_permissions
    start_services
    verify_deployment
    show_completion_message
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Twilio SMS App Ultimate Deployment Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --repo URL     Use custom repository URL"
        echo ""
        echo "This script will:"
        echo "- Clean up any existing installation"
        echo "- Install system dependencies"
        echo "- Deploy from GitHub repository"
        echo "- Configure all services"
        echo "- Verify deployment"
        echo ""
        exit 0
        ;;
    --repo)
        REPO_URL="$2"
        shift 2
        ;;
esac

# Run main deployment
main

log "Ultimate deployment script completed successfully!"
