#!/bin/bash
#####################################################################
# TwilioSMS v2.1.1 Hotfix - Production Installation Script
# One-command automated deployment for Ubuntu 20.04/22.04
#
# Usage: sudo bash install_production.sh
#####################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}Please run as root: sudo bash install_production.sh${NC}"
   exit 1
fi

# Get the actual user (not root)
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║   TwilioSMS v2.1.1 Production Installation               ║"
echo "║   Automated End-to-End Deployment                        ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Prompt for configuration
echo -e "${YELLOW}=== Configuration ===${NC}"
read -p "Enter your domain name (or IP address): " DOMAIN_NAME
read -p "Enter the installation directory [$USER_HOME/TiwlioSMS]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$USER_HOME/TiwlioSMS}
read -p "Setup HTTPS with Let's Encrypt? (y/n): " SETUP_HTTPS
read -p "Configure firewall (UFW)? (y/n): " SETUP_FIREWALL

echo ""
echo -e "${GREEN}Installation Configuration:${NC}"
echo "  User: $ACTUAL_USER"
echo "  Install Directory: $INSTALL_DIR"
echo "  Domain: $DOMAIN_NAME"
echo "  HTTPS: $SETUP_HTTPS"
echo "  Firewall: $SETUP_FIREWALL"
echo ""
read -p "Continue with installation? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Installation cancelled."
    exit 0
fi

#####################################################################
# Step 1: System Updates & Dependencies
#####################################################################
echo ""
echo -e "${BLUE}[1/10] Updating system and installing dependencies...${NC}"
apt update
apt upgrade -y
apt install -y python3 python3-pip python3-venv nginx git sqlite3 ufw certbot python3-certbot-nginx

#####################################################################
# Step 2: Clone Repository
#####################################################################
echo ""
echo -e "${BLUE}[2/10] Cloning TwilioSMS repository...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Directory $INSTALL_DIR already exists. Skipping clone.${NC}"
    cd "$INSTALL_DIR"
    sudo -u $ACTUAL_USER git pull origin dev/twilioms-test || true
else
    cd $(dirname "$INSTALL_DIR")
    sudo -u $ACTUAL_USER git clone https://github.com/hmali/TiwlioSMS.git $(basename "$INSTALL_DIR")
    cd "$INSTALL_DIR"
    sudo -u $ACTUAL_USER git checkout dev/twilioms-test
fi

#####################################################################
# Step 3: Python Virtual Environment
#####################################################################
echo ""
echo -e "${BLUE}[3/10] Setting up Python virtual environment...${NC}"
sudo -u $ACTUAL_USER python3 -m venv venv
sudo -u $ACTUAL_USER bash -c "source venv/bin/activate && pip install --upgrade pip"
sudo -u $ACTUAL_USER bash -c "source venv/bin/activate && pip install -r requirements.txt"

#####################################################################
# Step 4: Database Initialization
#####################################################################
echo ""
echo -e "${BLUE}[4/10] Initializing database...${NC}"
sudo -u $ACTUAL_USER bash -c "source venv/bin/activate && python3 -c 'from app import init_db; init_db()'"
echo -e "${GREEN}✓ Database initialized${NC}"

#####################################################################
# Step 5: Database Migration
#####################################################################
echo ""
echo -e "${BLUE}[5/10] Running database migration...${NC}"
sudo -u $ACTUAL_USER bash -c "source venv/bin/activate && python3 scripts/migrate_db_v2.1.1.py"

#####################################################################
# Step 6: Generate SECRET_KEY
#####################################################################
echo ""
echo -e "${BLUE}[6/10] Generating SECRET_KEY...${NC}"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
echo -e "${GREEN}✓ SECRET_KEY generated${NC}"

#####################################################################
# Step 7: Create Systemd Service
#####################################################################
echo ""
echo -e "${BLUE}[7/10] Creating systemd service...${NC}"
cat > /etc/systemd/system/twiliosms.service << EOF
[Unit]
Description=TwilioSMS Bulk SMS Application
After=network.target

[Service]
User=$ACTUAL_USER
Group=www-data
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
Environment="SECRET_KEY=$SECRET_KEY"
ExecStart=$INSTALL_DIR/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
chown -R $ACTUAL_USER:www-data "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"
[ -f "$INSTALL_DIR/twilio_sms.db" ] && chmod 664 "$INSTALL_DIR/twilio_sms.db"

# Reload and start service
systemctl daemon-reload
systemctl enable twiliosms
systemctl start twiliosms
sleep 3
systemctl status twiliosms --no-pager || true
echo -e "${GREEN}✓ Service created and started${NC}"

#####################################################################
# Step 8: Configure Nginx
#####################################################################
echo ""
echo -e "${BLUE}[8/10] Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/twiliosms << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static {
        alias $INSTALL_DIR/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    client_max_body_size 16M;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
echo -e "${GREEN}✓ Nginx configured and reloaded${NC}"

#####################################################################
# Step 9: Setup HTTPS (Optional)
#####################################################################
if [ "$SETUP_HTTPS" = "y" ]; then
    echo ""
    echo -e "${BLUE}[9/10] Setting up HTTPS with Let's Encrypt...${NC}"
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --register-unsafely-without-email || {
        echo -e "${YELLOW}Note: Certbot requires a valid email. Run manually: sudo certbot --nginx -d $DOMAIN_NAME${NC}"
    }
else
    echo ""
    echo -e "${BLUE}[9/10] Skipping HTTPS setup${NC}"
fi

#####################################################################
# Step 10: Configure Firewall (Optional)
#####################################################################
if [ "$SETUP_FIREWALL" = "y" ]; then
    echo ""
    echo -e "${BLUE}[10/10] Configuring firewall...${NC}"
    ufw --force enable
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw status
    echo -e "${GREEN}✓ Firewall configured${NC}"
else
    echo ""
    echo -e "${BLUE}[10/10] Skipping firewall setup${NC}"
fi

#####################################################################
# Installation Complete
#####################################################################
echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║   ✅  Installation Complete!                             ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}=== Next Steps ===${NC}"
echo ""
echo "1. Access your application:"
echo -e "   ${GREEN}http://$DOMAIN_NAME${NC}"
echo ""
echo "2. Default Login:"
echo "   Username: admin"
echo "   Password: admin123"
echo -e "   ${RED}⚠️  CHANGE IMMEDIATELY!${NC}"
echo ""
echo "3. Configure Twilio:"
echo "   - Go to Settings → Twilio Credentials"
echo "   - Enter Account SID, Auth Token, Phone Number"
echo "   - Get from: https://console.twilio.com"
echo ""
echo "4. Setup Twilio Webhook:"
echo "   - Twilio Console → Phone Numbers → Your Number"
echo -e "   - Webhook URL: ${GREEN}http://$DOMAIN_NAME/sms/inbound${NC}"
echo "   - Method: POST"
echo ""
echo -e "${YELLOW}=== Useful Commands ===${NC}"
echo ""
echo "View logs:        sudo journalctl -u twiliosms -f"
echo "Restart service:  sudo systemctl restart twiliosms"
echo "Check status:     sudo systemctl status twiliosms"
echo "App directory:    cd $INSTALL_DIR"
echo "Database backup:  cp $INSTALL_DIR/twilio_sms.db $INSTALL_DIR/backups/"
echo ""
echo -e "${YELLOW}=== Configuration Files ===${NC}"
echo ""
echo "App directory:     $INSTALL_DIR"
echo "Service file:      /etc/systemd/system/twiliosms.service"
echo "Nginx config:      /etc/nginx/sites-available/twiliosms"
echo "Database:          $INSTALL_DIR/twilio_sms.db"
echo "Logs:              $INSTALL_DIR/twilio_sms.log"
echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"
echo ""
