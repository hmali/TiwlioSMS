#!/bin/bash

# Twilio Bulk SMS Application Deployment Script for Amazon EC2
# This script sets up the application on a fresh Ubuntu EC2 instance

set -e

echo "🚀 Starting Twilio Bulk SMS Application Deployment..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Python 3 and pip
echo "🐍 Installing Python 3 and pip..."
sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential

# Install nginx and supervisor
echo "🌐 Installing Nginx and Supervisor..."
sudo apt install -y nginx supervisor

# Create application directory
APP_DIR="/opt/twilio-sms-app"
echo "📁 Creating application directory at $APP_DIR..."
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Copy application files (assuming current directory has the app)
echo "📋 Copying application files..."
cp -r . $APP_DIR/
cd $APP_DIR

# Create virtual environment
echo "🔧 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📚 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create uploads directory
mkdir -p uploads

# Set up environment variables
echo "⚙️ Setting up environment variables..."
cat > .env << EOF
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(16))")
FLASK_ENV=production
FLASK_APP=app.py
EOF

# Initialize database
echo "🗄️ Initializing database..."
python3 -c "from app import init_db; init_db()"

# Set proper permissions
echo "🔒 Setting file permissions..."
sudo chown -R www-data:www-data $APP_DIR
sudo chmod -R 755 $APP_DIR

# Create Gunicorn configuration
echo "🦄 Creating Gunicorn configuration..."
cat > gunicorn_config.py << EOF
bind = "127.0.0.1:8000"
workers = 4
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
preload_app = True
EOF

# Create systemd service for the application
echo "🔄 Creating systemd service..."
sudo tee /etc/systemd/system/twilio-sms-app.service > /dev/null << EOF
[Unit]
Description=Twilio SMS Bulk Application
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
echo "🌐 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/twilio-sms-app > /dev/null << EOF
server {
    listen 80;
    server_name _;

    client_max_body_size 16M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30;
        proxy_send_timeout 30;
        proxy_read_timeout 30;
    }

    location /static {
        alias $APP_DIR/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/twilio-sms-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Configure firewall
echo "🔥 Configuring UFW firewall..."
sudo ufw --force enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Start and enable services
echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable twilio-sms-app
sudo systemctl start twilio-sms-app
sudo systemctl enable nginx
sudo systemctl restart nginx

# Check service status
echo "✅ Checking service status..."
sudo systemctl status twilio-sms-app --no-pager
sudo systemctl status nginx --no-pager

echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Application Information:"
echo "   - Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'YOUR_EC2_PUBLIC_IP')"
echo "   - Default Login: admin / admin123"
echo "   - Application Directory: $APP_DIR"
echo "   - Log Files: /var/log/supervisor/ and journalctl -u twilio-sms-app"
echo ""
echo "🔧 Next Steps:"
echo "   1. Update your EC2 Security Group to allow HTTP (port 80) traffic"
echo "   2. Log in to the application and configure your Twilio credentials"
echo "   3. Consider setting up SSL/TLS with Let's Encrypt"
echo "   4. Change the default admin password"
echo ""
echo "📖 Management Commands:"
echo "   - Restart app: sudo systemctl restart twilio-sms-app"
echo "   - View logs: sudo journalctl -u twilio-sms-app -f"
echo "   - Update app: cd $APP_DIR && git pull && sudo systemctl restart twilio-sms-app"
EOF
