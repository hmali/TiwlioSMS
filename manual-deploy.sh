#!/bin/bash

# Manual Deployment Script for Twilio SMS App on Ubuntu 24.04
# Run this after installing required packages

set -e

APP_DIR="/opt/twilio-sms-app"
APP_USER="www-data"

echo "🚀 Deploying Twilio SMS Application..."

# Create application directory
echo "📁 Setting up application directory..."
sudo mkdir -p $APP_DIR
cd $APP_DIR

# If you have the files in current directory, skip the git clone
if [ ! -f "app.py" ]; then
    echo "❌ Application files not found. Please ensure all files are in $APP_DIR"
    echo "📋 Required files:"
    echo "   - app.py"
    echo "   - requirements.txt"
    echo "   - templates/"
    echo "   - static/"
    echo "   - gunicorn_config.py"
    exit 1
fi

# Create Python virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📚 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p uploads
mkdir -p logs
sudo mkdir -p /var/log/twilio-sms-app

# Create environment file
echo "⚙️ Setting up environment..."
if [ ! -f ".env" ]; then
    cat > .env << EOF
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
FLASK_ENV=production
FLASK_APP=app.py
EOF
fi

# Initialize database
echo "🗄️ Initializing database..."
python3 -c "
import sys
sys.path.append('.')
from app import init_db
init_db()
print('Database initialized successfully!')
"

# Set proper file permissions
echo "🔒 Setting file permissions..."
sudo chown -R $APP_USER:$APP_USER $APP_DIR
sudo chmod -R 755 $APP_DIR
sudo chmod -R 755 /var/log/twilio-sms-app

# Create systemd service
echo "🔄 Creating systemd service..."
sudo tee /etc/systemd/system/twilio-sms-app.service > /dev/null << EOF
[Unit]
Description=Twilio SMS Bulk Application
After=network.target

[Service]
Type=exec
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/gunicorn --config gunicorn_config.py app:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Update Gunicorn config for proper logging
echo "📝 Updating Gunicorn configuration..."
sudo mkdir -p /var/log/twilio-sms-app
sudo chown $APP_USER:$APP_USER /var/log/twilio-sms-app

cat > gunicorn_config.py << EOF
import os

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = 4
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 50
preload_app = True

# Logging
access_logfile = "/var/log/twilio-sms-app/access.log"
error_logfile = "/var/log/twilio-sms-app/error.log"
loglevel = "info"
accesslog = "/var/log/twilio-sms-app/access.log"
errorlog = "/var/log/twilio-sms-app/error.log"

# Process naming
proc_name = "twilio-sms-app"

# Security
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190
EOF

# Configure Nginx
echo "🌐 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/twilio-sms-app > /dev/null << EOF
server {
    listen 80;
    server_name _;
    
    client_max_body_size 16M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60;
        proxy_send_timeout 60;
        proxy_read_timeout 60;
        proxy_buffering off;
    }
    
    location /static {
        alias $APP_DIR/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    location /favicon.ico {
        alias $APP_DIR/static/favicon.ico;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
EOF

# Enable the site and disable default
sudo ln -sf /etc/nginx/sites-available/twilio-sms-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "🧪 Testing Nginx configuration..."
sudo nginx -t

# Configure UFW firewall
echo "🔥 Configuring firewall..."
sudo ufw --force enable
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'

# Configure log rotation
echo "📋 Setting up log rotation..."
sudo tee /etc/logrotate.d/twilio-sms-app > /dev/null << EOF
/var/log/twilio-sms-app/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
    postrotate
        systemctl reload twilio-sms-app
    endscript
}
EOF

# Start and enable services
echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable twilio-sms-app
sudo systemctl start twilio-sms-app
sudo systemctl enable nginx
sudo systemctl restart nginx

# Wait a moment for services to start
sleep 5

# Check service status
echo "✅ Checking service status..."
echo "--- Twilio SMS App Status ---"
sudo systemctl status twilio-sms-app --no-pager

echo "--- Nginx Status ---"
sudo systemctl status nginx --no-pager

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Application Information:"
echo "   🌐 Application URL: http://$PUBLIC_IP"
echo "   👤 Default Login: admin / admin123"
echo "   📁 Application Directory: $APP_DIR"
echo ""
echo "🔧 Next Steps:"
echo "   1. Open http://$PUBLIC_IP in your browser"
echo "   2. Log in with admin/admin123"
echo "   3. Go to Settings and configure Twilio credentials"
echo "   4. Change the default admin password"
echo "   5. Test with a small phone number list first"
echo ""
echo "📖 Management Commands:"
echo "   - Restart app: sudo systemctl restart twilio-sms-app"
echo "   - View app logs: sudo journalctl -u twilio-sms-app -f"
echo "   - View access logs: sudo tail -f /var/log/twilio-sms-app/access.log"
echo "   - View error logs: sudo tail -f /var/log/twilio-sms-app/error.log"
echo "   - Check status: sudo systemctl status twilio-sms-app"
echo ""
echo "🛡️ Security:"
echo "   - Firewall is enabled (UFW)"
echo "   - Only necessary ports are open"
echo "   - Application runs as www-data user"
echo ""
EOF
