#!/bin/bash

# Quick Fix Script for GitHub Deployment Issues
# This script fixes common deployment issues and does a complete fresh deployment

set +e  # Don't exit on errors, we want to continue cleanup

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
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

log "GitHub Deployment Complete Reset & Fix"
log "This will completely clean up and redeploy from scratch"

# Function to safely stop services
safe_stop_service() {
    local service_name=$1
    if systemctl list-units --full -all | grep -q "$service_name.service"; then
        log "Stopping $service_name service..."
        systemctl stop "$service_name" 2>/dev/null || true
        systemctl disable "$service_name" 2>/dev/null || true
    else
        log "$service_name service not found, skipping stop"
    fi
}

# Clean up everything thoroughly
log "=== COMPLETE CLEANUP ==="

# Stop services safely
safe_stop_service "twilio-sms"
safe_stop_service "nginx"

# Remove systemd service files
log "Removing systemd service files..."
rm -f /etc/systemd/system/twilio-sms.service
systemctl daemon-reload

# Remove nginx configurations
log "Removing nginx configurations..."
rm -f /etc/nginx/sites-enabled/twilio-sms
rm -f /etc/nginx/sites-available/twilio-sms

# Remove deployment directories
log "Removing deployment directories..."
rm -rf /opt/twilio-sms
rm -rf /opt/twilio-sms-backup

# Remove any leftover processes
log "Cleaning up processes..."
pkill -f "gunicorn.*twilio" 2>/dev/null || true
pkill -f "python.*app.py" 2>/dev/null || true

success "Complete cleanup finished"

# Install basic dependencies
log "=== INSTALLING DEPENDENCIES ==="
apt update
apt install -y python3 python3-pip python3-venv nginx curl wget git

# Create deployment directory
log "Creating deployment directory..."
mkdir -p /opt/twilio-sms
cd /opt/twilio-sms

# Clone repository
log "Cloning repository..."
git clone https://github.com/hmali/TiwlioSMS.git .

# Set up Python environment
log "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create necessary directories
log "Creating application directories..."
mkdir -p uploads logs

# Initialize database
log "Initializing database..."
python3 -c "from app import init_db; init_db()" 2>/dev/null || {
    warning "Database initialization failed, will try again after service setup"
}

# Create .env file
log "Setting up environment file..."
if [[ -f ".env.example" ]]; then
    cp .env.example .env
else
    cat > .env << 'EOF'
SECRET_KEY=change-this-secret-key-in-production
FLASK_ENV=production
FLASK_APP=app.py
EOF
fi

# Set proper permissions
log "Setting file permissions..."
chown -R www-data:www-data /opt/twilio-sms
find /opt/twilio-sms -type d -exec chmod 755 {} \;
find /opt/twilio-sms -type f -exec chmod 644 {} \;
chmod +x /opt/twilio-sms/*.sh

# Create systemd service
log "Creating systemd service..."
cat > /etc/systemd/system/twilio-sms.service << 'EOF'
[Unit]
Description=Twilio SMS Application
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/twilio-sms
Environment=PATH=/opt/twilio-sms/venv/bin
ExecStart=/opt/twilio-sms/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/twilio-sms
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

# Create nginx configuration
log "Creating nginx configuration..."
cat > /etc/nginx/sites-available/twilio-sms << 'EOF'
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

# Enable nginx site
ln -sf /etc/nginx/sites-available/twilio-sms /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
log "Testing nginx configuration..."
nginx -t || {
    error "Nginx configuration test failed!"
    exit 1
}

# Reload systemd and start services
log "Starting services..."
systemctl daemon-reload

# Enable services
systemctl enable twilio-sms
systemctl enable nginx

# Start services
systemctl start twilio-sms
systemctl start nginx

# Wait a moment for services to start
sleep 5

# Verify deployment
log "=== VERIFYING DEPLOYMENT ==="

# Check service status
if systemctl is-active --quiet twilio-sms; then
    success "Twilio SMS service is running"
else
    error "Twilio SMS service failed to start"
    log "Service status:"
    systemctl status twilio-sms --no-pager
    exit 1
fi

if systemctl is-active --quiet nginx; then
    success "Nginx service is running"
else
    error "Nginx service failed to start"
    log "Nginx status:"
    systemctl status nginx --no-pager
    exit 1
fi

# Test HTTP response
log "Testing application response..."
sleep 3

if curl -s http://localhost:8000 >/dev/null 2>&1; then
    success "Application is responding on port 8000"
    
    if curl -s http://localhost >/dev/null 2>&1; then
        success "Application is accessible via Nginx on port 80"
    else
        warning "Nginx proxy may have issues"
    fi
else
    error "Application is not responding"
    log "Checking application logs..."
    journalctl -u twilio-sms -n 20 --no-pager
    exit 1
fi

# Get public IP
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "YOUR-EC2-PUBLIC-IP")

success "=== DEPLOYMENT SUCCESSFUL ==="
log ""
log "🎉 Your Twilio SMS Application is now running!"
log ""
log "📱 Access your application at: http://$PUBLIC_IP"
log "🔐 Default login: admin / admin123"
log "⚠️  IMPORTANT: Change default credentials immediately!"
log ""
log "📋 Next steps:"
log "1. Access the application in your browser"
log "2. Login and change default credentials"
log "3. Configure Twilio API credentials in Settings"
log "4. Test SMS functionality"
log ""
log "🔧 Useful commands:"
log "- View logs: sudo journalctl -u twilio-sms -f"
log "- Restart service: sudo systemctl restart twilio-sms"
log "- Check status: sudo systemctl status twilio-sms"
log ""
log "🚀 Setup auto-updates: sudo /opt/twilio-sms/setup-auto-update.sh"

exit 0
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
