#!/bin/bash

# Twilio SMS App Update Deployment Script
# Run this script on your EC2 instance to deploy updates

set -e

APP_DIR="/opt/twilio-sms-app"
BACKUP_DIR="/opt/twilio-sms-app-backup-$(date +%Y%m%d-%H%M%S)"
APP_USER="www-data"

echo "🚀 Deploying Twilio SMS App Updates..."
echo "=================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script with sudo"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "❌ Application directory $APP_DIR not found!"
    exit 1
fi

# Stop the application service
echo "⏹️  Stopping application service..."
systemctl stop twilio-sms-app

# Create backup
echo "💾 Creating backup at $BACKUP_DIR..."
cp -r "$APP_DIR" "$BACKUP_DIR"
echo "✅ Backup created successfully"

# Check if we have updated files in current directory
if [ -f "app.py" ] && [ -d "templates" ] && [ -d "static" ]; then
    echo "📁 Deploying files from current directory..."
    
    # Copy updated files (preserve database and uploads)
    cp -r templates static *.py *.txt *.sh *.md "$APP_DIR/"
    
    # Ensure critical directories exist
    mkdir -p "$APP_DIR/uploads"
    mkdir -p "$APP_DIR/logs"
    
    echo "✅ Files copied successfully"
else
    echo "❌ Updated files not found in current directory"
    echo "   Make sure you have app.py, templates/, static/ etc."
    exit 1
fi

# Install/update Python dependencies
echo "📚 Installing Python dependencies..."
cd "$APP_DIR"
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Set proper permissions
echo "🔒 Setting file permissions..."
chown -R $APP_USER:$APP_USER "$APP_DIR"
chmod -R 755 "$APP_DIR"

# Database updates (if needed)
echo "🗄️  Checking database..."
python3 -c "
import sys
sys.path.append('.')
try:
    from app import init_db
    init_db()
    print('✅ Database updated successfully')
except Exception as e:
    print(f'⚠️  Database update info: {e}')
"

# Start the application service
echo "🚀 Starting application service..."
systemctl start twilio-sms-app

# Wait a moment for service to start
sleep 3

# Check service status
echo "✅ Checking service status..."
if systemctl is-active --quiet twilio-sms-app; then
    echo "🎉 Application deployed successfully!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "   ✅ Service: Running"
    echo "   📁 Backup: $BACKUP_DIR"
    echo "   🌐 URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)"
    echo ""
    echo "🔧 New Features Added:"
    echo "   • User credential management"
    echo "   • Change username and password"
    echo "   • Security warnings for default credentials"
    echo "   • Enhanced settings page"
else
    echo "❌ Service failed to start!"
    echo "📋 Troubleshooting:"
    echo "   • Check logs: sudo journalctl -u twilio-sms-app -n 20"
    echo "   • Restore backup: sudo mv $BACKUP_DIR $APP_DIR"
    exit 1
fi

# Optional: Clean up old backups (keep last 5)
echo "🧹 Cleaning up old backups..."
cd /opt
ls -1d twilio-sms-app-backup-* 2>/dev/null | head -n -5 | xargs -r rm -rf
echo "✅ Cleanup completed"

echo "🎯 Deployment completed successfully!"
EOF
