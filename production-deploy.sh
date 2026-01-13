#!/bin/bash
# Production Deployment Script for Twilio SMS App
# Domain: smsgajanannj.com

set -e

echo "=========================================="
echo "Twilio SMS App - Production Deployment"
echo "=========================================="

# Configuration
APP_DIR="/var/www/TiwlioSMS"
APP_USER="ubuntu"
DOMAIN="smsgajanannj.com"
SUBDOMAIN="www.smsgajanannj.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run this script as root. Run as ubuntu user.${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${GREEN}Step 2: Installing system dependencies...${NC}"
sudo apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx ufw git

echo -e "${GREEN}Step 3: Creating application directory...${NC}"
if [ ! -d "$APP_DIR" ]; then
    sudo mkdir -p "$APP_DIR"
    sudo chown -R $APP_USER:$APP_USER "$APP_DIR"
fi

cd "$APP_DIR"

echo -e "${GREEN}Step 4: Setting up Python virtual environment...${NC}"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

echo -e "${GREEN}Step 5: Installing Python dependencies...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${GREEN}Step 6: Initializing database...${NC}"
python3 -c "from app import init_db; init_db()"
echo -e "${YELLOW}Default login - Username: admin, Password: admin123${NC}"
echo -e "${RED}IMPORTANT: Change these credentials after first login!${NC}"

echo -e "${GREEN}Step 7: Creating systemd service...${NC}"
sudo tee /etc/systemd/system/twiliosms.service > /dev/null <<EOF
[Unit]
Description=Twilio SMS Gunicorn Application
After=network.target

[Service]
User=$APP_USER
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="SECRET_KEY=$(openssl rand -hex 32)"
ExecStart=$APP_DIR/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}Step 8: Starting application service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable twiliosms
sudo systemctl start twiliosms
sudo systemctl status twiliosms --no-pager

echo -e "${GREEN}Step 9: Configuring Nginx...${NC}"
sudo tee /etc/nginx/sites-available/twiliosms > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN $SUBDOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }

    client_max_body_size 16M;
    
    access_log /var/log/nginx/twiliosms_access.log;
    error_log /var/log/nginx/twiliosms_error.log;
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/

# Remove default site if exists
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

echo -e "${GREEN}Step 10: Restarting Nginx...${NC}"
sudo systemctl restart nginx

echo -e "${GREEN}Step 11: Configuring firewall...${NC}"
sudo ufw --force enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status

echo -e "${GREEN}Step 12: Setting up SSL certificate...${NC}"
echo -e "${YELLOW}Make sure your domain DNS is pointing to this server's IP address!${NC}"
read -p "Do you want to setup SSL certificate now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo certbot --nginx -d $DOMAIN -d $SUBDOMAIN --non-interactive --agree-tos --register-unsafely-without-email --redirect || {
        echo -e "${YELLOW}SSL setup failed. You can run it manually later:${NC}"
        echo -e "sudo certbot --nginx -d $DOMAIN -d $SUBDOMAIN"
    }
    
    # Setup auto-renewal
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
else
    echo -e "${YELLOW}Skipping SSL setup. You can set it up later with:${NC}"
    echo -e "sudo certbot --nginx -d $DOMAIN -d $SUBDOMAIN"
fi

echo -e "${GREEN}Step 13: Setting up automatic backups...${NC}"
# Create backup script
sudo tee /usr/local/bin/backup-twiliosms-db.sh > /dev/null <<'EOF'
#!/bin/bash
BACKUP_DIR="/var/www/TiwlioSMS/backups"
mkdir -p $BACKUP_DIR
cp /var/www/TiwlioSMS/twilio_sms.db $BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).db
# Keep only last 30 backups
cd $BACKUP_DIR && ls -t | tail -n +31 | xargs -r rm --
EOF

sudo chmod +x /usr/local/bin/backup-twiliosms-db.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-twiliosms-db.sh") | crontab -

echo -e "${GREEN}=========================================="
echo -e "Deployment Complete!"
echo -e "==========================================${NC}"
echo ""
echo -e "${GREEN}Your Twilio SMS application is now running!${NC}"
echo ""
echo -e "📱 Access URL: ${YELLOW}http://$DOMAIN${NC}"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "🔒 HTTPS URL: ${GREEN}https://$DOMAIN${NC}"
fi
echo ""
echo -e "${RED}🔑 DEFAULT LOGIN CREDENTIALS:${NC}"
echo -e "   Username: ${YELLOW}admin${NC}"
echo -e "   Password: ${YELLOW}admin123${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANT: Change these credentials immediately after first login!${NC}"
echo ""
echo -e "${GREEN}Useful Commands:${NC}"
echo -e "  View logs: ${YELLOW}sudo journalctl -u twiliosms -f${NC}"
echo -e "  Restart app: ${YELLOW}sudo systemctl restart twiliosms${NC}"
echo -e "  Check status: ${YELLOW}sudo systemctl status twiliosms${NC}"
echo -e "  Nginx logs: ${YELLOW}sudo tail -f /var/log/nginx/twiliosms_error.log${NC}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo -e "  1. Login to the application"
echo -e "  2. Change the default password (Settings → Change Username & Password)"
echo -e "  3. Configure Twilio credentials (Settings → Twilio Configuration)"
echo -e "  4. Start sending SMS campaigns!"
echo ""
echo -e "${GREEN}For support, check the README.md file${NC}"
