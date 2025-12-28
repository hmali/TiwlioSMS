#!/bin/bash

# One-Command Deployment Script for Mac to EC2
# Usage: ./deploy-to-ec2.sh YOUR_EC2_IP your-key-pair.pem

set -e

# Check arguments
if [ $# -ne 2 ]; then
    echo "❌ Usage: $0 <EC2_IP> <KEY_PAIR_FILE>"
    echo "   Example: $0 18.216.123.45 my-keypair.pem"
    exit 1
fi

EC2_IP="$1"
KEY_FILE="$2"
LOCAL_APP_DIR="/Users/hmali/Documents/GitHub/TiwlioSMS"

# Verify key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Key file '$KEY_FILE' not found!"
    exit 1
fi

# Verify local app directory exists
if [ ! -d "$LOCAL_APP_DIR" ]; then
    echo "❌ Local app directory '$LOCAL_APP_DIR' not found!"
    exit 1
fi

echo "🚀 Deploying Twilio SMS App Updates to EC2..."
echo "============================================"
echo "📍 Target: ubuntu@$EC2_IP"
echo "🔑 Key: $KEY_FILE"
echo "📁 Source: $LOCAL_APP_DIR"
echo ""

# Step 1: Upload files to EC2
echo "📤 Step 1: Uploading files to EC2..."
scp -i "$KEY_FILE" -o StrictHostKeyChecking=no -r "$LOCAL_APP_DIR"/* ubuntu@$EC2_IP:~/app-update/
echo "✅ Files uploaded successfully"

# Step 2: Execute deployment on EC2
echo ""
echo "🚀 Step 2: Executing deployment on EC2..."
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@$EC2_IP << 'ENDSSH'
    cd ~/app-update
    
    # Make deploy script executable if it exists
    if [ -f "deploy-update.sh" ]; then
        chmod +x deploy-update.sh
        echo "🔧 Running automated deployment script..."
        sudo ./deploy-update.sh
    else
        echo "📋 Running manual deployment steps..."
        
        # Manual deployment steps
        sudo systemctl stop twilio-sms-app
        sudo cp -r /opt/twilio-sms-app /opt/twilio-sms-app-backup-$(date +%Y%m%d-%H%M%S)
        
        # Copy updated files
        sudo cp app.py /opt/twilio-sms-app/ 2>/dev/null || echo "⚠️  app.py not found"
        sudo cp -r templates/* /opt/twilio-sms-app/templates/ 2>/dev/null || echo "⚠️  templates not found"
        sudo cp -r static/* /opt/twilio-sms-app/static/ 2>/dev/null || echo "⚠️  static files not found"
        
        # Set permissions
        sudo chown -R www-data:www-data /opt/twilio-sms-app
        sudo chmod -R 755 /opt/twilio-sms-app
        
        # Restart service
        sudo systemctl start twilio-sms-app
        
        # Check status
        if sudo systemctl is-active --quiet twilio-sms-app; then
            echo "✅ Application started successfully"
        else
            echo "❌ Application failed to start"
            sudo systemctl status twilio-sms-app --no-pager
        fi
    fi
ENDSSH

# Step 3: Get deployment status
echo ""
echo "📊 Step 3: Checking deployment status..."
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@$EC2_IP << 'ENDSSH'
    echo "🔍 Service Status:"
    sudo systemctl status twilio-sms-app --no-pager -l
    
    echo ""
    echo "🌐 Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
    echo "👤 Default Login: admin / admin123"
    echo ""
    echo "🎯 New Features:"
    echo "   • User credential management"
    echo "   • Change username and password"
    echo "   • Security warnings"
    echo "   • Enhanced settings page"
    echo ""
    echo "⚠️  IMPORTANT: Change the default admin password immediately!"
ENDSSH

echo ""
echo "🎉 Deployment completed!"
echo "📋 Next Steps:"
echo "   1. Open http://$EC2_IP in your browser"
echo "   2. Login with: admin / admin123"
echo "   3. Go to Settings and change your credentials"
echo "   4. Configure Twilio credentials if needed"
echo "   5. Test SMS functionality"
EOF
