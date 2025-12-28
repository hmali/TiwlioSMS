#!/bin/bash

# Emergency Fix Script for Systemd Service Issues
# This script fixes specific systemd and gunicorn execution issues

set +e  # Don't exit on errors

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

log "Emergency Fix for Systemd Service Issues"

# Stop the failing service
log "Stopping failing service..."
systemctl stop twilio-sms 2>/dev/null || true

# Check if gunicorn is properly installed in venv
log "Checking gunicorn installation..."
cd /opt/twilio-sms

if [[ ! -d "venv" ]]; then
    error "Virtual environment not found!"
    exit 1
fi

# Activate venv and check gunicorn
source venv/bin/activate

# Check if gunicorn exists
if [[ ! -f "venv/bin/gunicorn" ]]; then
    log "Gunicorn not found, installing..."
    pip install gunicorn
fi

# Test gunicorn path
log "Testing gunicorn executable..."
venv/bin/gunicorn --version || {
    error "Gunicorn installation failed"
    exit 1
}

# Create proper systemd service file
log "Creating corrected systemd service file..."
cat > /etc/systemd/system/twilio-sms.service << 'EOF'
[Unit]
Description=Twilio SMS Application
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/twilio-sms
Environment=PATH=/opt/twilio-sms/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONPATH=/opt/twilio-sms
ExecStartPre=/bin/mkdir -p /opt/twilio-sms/logs
ExecStart=/opt/twilio-sms/venv/bin/gunicorn --config gunicorn_config.py app:app
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

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

# Update gunicorn config to use correct log paths
log "Updating gunicorn configuration..."
cat > /opt/twilio-sms/gunicorn_config.py << 'EOF'
bind = "127.0.0.1:8000"
workers = 2
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
preload_app = True
access_logfile = "/opt/twilio-sms/logs/access.log"
error_logfile = "/opt/twilio-sms/logs/error.log"
loglevel = "info"
EOF

# Ensure log directory exists with proper permissions
log "Setting up log directory..."
mkdir -p /opt/twilio-sms/logs
chown -R www-data:www-data /opt/twilio-sms/logs
chmod 755 /opt/twilio-sms/logs

# Test the application manually first
log "Testing application manually..."
cd /opt/twilio-sms
source venv/bin/activate

# Test if app.py can be imported
python3 -c "import app; print('App import successful')" || {
    error "Application import failed"
    log "Checking for missing dependencies..."
    pip install -r requirements.txt
    python3 -c "import app; print('App import successful after reinstall')" || {
        error "Application still failing to import"
        exit 1
    }
}

# Test gunicorn manually (background process for testing)
log "Testing gunicorn startup..."
timeout 10s venv/bin/gunicorn --config gunicorn_config.py app:app --daemon --pid /tmp/test-gunicorn.pid || {
    error "Gunicorn test failed"
    # Show more detailed error
    log "Trying gunicorn with verbose output..."
    venv/bin/gunicorn --config gunicorn_config.py app:app --check-config
    exit 1
}

# Kill test gunicorn
if [[ -f /tmp/test-gunicorn.pid ]]; then
    kill $(cat /tmp/test-gunicorn.pid) 2>/dev/null || true
    rm -f /tmp/test-gunicorn.pid
fi

success "Manual gunicorn test passed"

# Set proper permissions
log "Setting final permissions..."
chown -R www-data:www-data /opt/twilio-sms
find /opt/twilio-sms -type d -exec chmod 755 {} \;
find /opt/twilio-sms -type f -exec chmod 644 {} \;
chmod +x /opt/twilio-sms/*.sh
chmod +x /opt/twilio-sms/venv/bin/*

# Reload systemd and start service
log "Reloading systemd and starting service..."
systemctl daemon-reload
systemctl enable twilio-sms

# Start the service
log "Starting twilio-sms service..."
systemctl start twilio-sms

# Wait a moment for startup
sleep 5

# Check service status
if systemctl is-active --quiet twilio-sms; then
    success "Service is now running!"
    
    # Test HTTP response
    sleep 3
    if curl -s http://localhost:8000 >/dev/null; then
        success "Application is responding on port 8000"
        
        # Test nginx
        systemctl restart nginx
        sleep 2
        
        if curl -s http://localhost >/dev/null; then
            success "Application is accessible via nginx on port 80"
        else
            warning "Nginx may have issues, but application is running directly"
        fi
        
        # Get public IP
        PUBLIC_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "YOUR-EC2-IP")
        
        log ""
        success "🎉 DEPLOYMENT FIXED!"
        log "Application URL: http://$PUBLIC_IP"
        log "Default login: admin / admin123"
        log ""
        
    else
        warning "Service running but not responding to HTTP requests"
        log "Checking service logs..."
        journalctl -u twilio-sms -n 20 --no-pager
    fi
    
else
    error "Service failed to start"
    log "Service status:"
    systemctl status twilio-sms --no-pager -l
    log ""
    log "Service logs:"
    journalctl -u twilio-sms -n 30 --no-pager
    log ""
    log "Checking if ports are in use..."
    netstat -tlnp | grep :8000 || echo "Port 8000 is free"
    exit 1
fi

log "Emergency fix completed"
