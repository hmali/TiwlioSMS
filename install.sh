#!/bin/bash
#
# TwilioSMS Automated Production Installer
# Version: 2.1.0
# Last Updated: February 2, 2026
#
# This script automates the installation of TwilioSMS on Ubuntu servers
# Usage: ./install.sh
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root. Run as regular user with sudo privileges."
        exit 1
    fi
}

# Check OS
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        
        if [ "$OS" != "ubuntu" ]; then
            print_warning "This script is designed for Ubuntu. Detected: $OS $VERSION"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        print_error "Cannot detect OS version"
        exit 1
    fi
}

# Main installation
main() {
    clear
    print_header "TwilioSMS v2.1.0 - Automated Production Installer"
    echo ""
    echo "This script will install TwilioSMS on your server."
    echo "It will:"
    echo "  • Update system packages"
    echo "  • Install Python, Nginx, and dependencies"
    echo "  • Clone the TwilioSMS repository"
    echo "  • Setup virtual environment"
    echo "  • Initialize database"
    echo "  • Configure systemd service"
    echo "  • Configure Nginx reverse proxy"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    check_root
    check_os

    # Get user input
    echo ""
    print_info "Configuration:"
    read -p "Enter your domain name (or server IP): " DOMAIN
    read -p "Enter your username [$(whoami)]: " USERNAME
    USERNAME=${USERNAME:-$(whoami)}

    # Confirm
    echo ""
    print_info "Installation Summary:"
    echo "  Domain/IP: $DOMAIN"
    echo "  Username: $USERNAME"
    echo "  Install Path: /home/$USERNAME/TiwlioSMS"
    echo ""
    read -p "Proceed with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    # Start installation
    echo ""
    print_header "Step 1/9: Updating System Packages"
    sudo apt update -y
    print_success "System packages updated"

    echo ""
    print_header "Step 2/9: Installing Dependencies"
    sudo apt install -y python3 python3-pip python3-venv nginx git sqlite3 curl
    print_success "Dependencies installed"

    echo ""
    print_header "Step 3/9: Cloning Repository"
    cd /home/$USERNAME
    if [ -d "TiwlioSMS" ]; then
        print_warning "TiwlioSMS directory already exists. Backing up..."
        mv TiwlioSMS TiwlioSMS.backup.$(date +%Y%m%d_%H%M%S)
    fi
    git clone https://github.com/hmali/TiwlioSMS.git
    cd TiwlioSMS
    print_success "Repository cloned"

    echo ""
    print_header "Step 4/9: Creating Virtual Environment"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_success "Virtual environment created and dependencies installed"

    echo ""
    print_header "Step 5/9: Initializing Database"
    python3 -c "from app import init_db; init_db(); print('Database initialized successfully!')"
    print_success "Database initialized"

    echo ""
    print_header "Step 6/9: Configuring Systemd Service"
    
    # Generate random secret key
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    
    sudo tee /etc/systemd/system/twiliosms.service > /dev/null <<EOF
[Unit]
Description=TwilioSMS Bulk SMS Application
After=network.target

[Service]
User=$USERNAME
Group=www-data
WorkingDirectory=/home/$USERNAME/TiwlioSMS
Environment="PATH=/home/$USERNAME/TiwlioSMS/venv/bin"
Environment="SECRET_KEY=$SECRET_KEY"
ExecStart=/home/$USERNAME/TiwlioSMS/venv/bin/gunicorn -c gunicorn_config.py app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable twiliosms
    sudo systemctl start twiliosms
    
    # Wait for service to start
    sleep 3
    
    if sudo systemctl is-active --quiet twiliosms; then
        print_success "Systemd service configured and started"
    else
        print_error "Service failed to start. Check: sudo journalctl -u twiliosms -xe"
        exit 1
    fi

    echo ""
    print_header "Step 7/9: Configuring Nginx"
    
    sudo tee /etc/nginx/sites-available/twiliosms > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Increase timeout for long-running requests
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    # Static files
    location /static {
        alias /home/$USERNAME/TiwlioSMS/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # File uploads
    client_max_body_size 16M;
}
EOF
    
    # Enable site
    sudo ln -sf /etc/nginx/sites-available/twiliosms /etc/nginx/sites-enabled/
    
    # Test nginx config
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl reload nginx
        print_success "Nginx configured and reloaded"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi

    echo ""
    print_header "Step 8/9: Setting Up Firewall (if UFW is active)"
    
    if sudo ufw status | grep -q "Status: active"; then
        sudo ufw allow 'Nginx Full' 2>/dev/null || true
        sudo ufw allow OpenSSH 2>/dev/null || true
        print_success "Firewall rules updated"
    else
        print_info "UFW not active, skipping firewall configuration"
    fi

    echo ""
    print_header "Step 9/9: Creating Backup Script"
    
    cat > /home/$USERNAME/backup-twiliosms.sh <<'EOFBACKUP'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/TiwlioSMS/backups"
mkdir -p "$BACKUP_DIR"
cp "$HOME/TiwlioSMS/twilio_sms.db" "$BACKUP_DIR/twilio_sms.db.backup_$DATE"
# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "*.backup_*" -mtime +7 -delete
echo "Backup created: twilio_sms.db.backup_$DATE"
EOFBACKUP
    
    chmod +x /home/$USERNAME/backup-twiliosms.sh
    print_success "Backup script created"

    # Test installation
    echo ""
    print_header "Testing Installation"
    
    sleep 2
    HEALTH_CHECK=$(curl -s http://localhost/health || echo "failed")
    
    if [[ $HEALTH_CHECK == *"healthy"* ]]; then
        print_success "Health check passed!"
    else
        print_warning "Health check failed. Service may need time to start."
    fi

    # Final summary
    echo ""
    print_header "🎉 Installation Complete!"
    echo ""
    echo -e "${GREEN}TwilioSMS v2.1.0 has been successfully installed!${NC}"
    echo ""
    echo "📍 Access Information:"
    echo "  • Web Interface: http://$DOMAIN"
    echo "  • Health Check: http://$DOMAIN/health"
    echo ""
    echo "🔐 Default Login Credentials:"
    echo "  • Username: admin"
    echo "  • Password: admin123"
    echo -e "  ${RED}⚠️  CHANGE THESE IMMEDIATELY AFTER FIRST LOGIN!${NC}"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Open http://$DOMAIN in your browser"
    echo "  2. Login with default credentials"
    echo "  3. Go to Settings → Change Credentials"
    echo "  4. Update your password"
    echo "  5. Go to Settings → Configure Twilio credentials"
    echo "  6. In Twilio Console, set webhook to: http://$DOMAIN/sms/inbound"
    echo ""
    echo "📖 Documentation:"
    echo "  • Installation Guide: /home/$USERNAME/TiwlioSMS/INSTALLATION.md"
    echo "  • Beginner's Guide: /home/$USERNAME/TiwlioSMS/docs/guides/BEGINNER_GUIDE.md"
    echo "  • Documentation Index: /home/$USERNAME/TiwlioSMS/docs/INDEX.md"
    echo ""
    echo "🔧 Useful Commands:"
    echo "  • Check status: sudo systemctl status twiliosms"
    echo "  • View logs: sudo journalctl -u twiliosms -f"
    echo "  • Restart app: sudo systemctl restart twiliosms"
    echo "  • Run backup: ~/backup-twiliosms.sh"
    echo ""
    echo "🔒 Security Recommendations:"
    echo "  • Setup HTTPS with Let's Encrypt: sudo certbot --nginx -d $DOMAIN"
    echo "  • Setup automatic backups: crontab -e (add daily backup)"
    echo "  • Review firewall rules: sudo ufw status"
    echo ""
    echo -e "${BLUE}For support, see: /home/$USERNAME/TiwlioSMS/INSTALLATION.md${NC}"
    echo ""
    
    # Save installation info
    cat > /home/$USERNAME/TiwlioSMS/installation-info.txt <<EOF
TwilioSMS Installation Information
===================================
Installation Date: $(date)
Version: 2.1.0
Domain: $DOMAIN
Username: $USERNAME
Install Path: /home/$USERNAME/TiwlioSMS
Secret Key: $SECRET_KEY

Default Credentials:
  Username: admin
  Password: admin123
  ⚠️  CHANGE IMMEDIATELY!

Service Commands:
  sudo systemctl status twiliosms
  sudo systemctl restart twiliosms
  sudo journalctl -u twiliosms -f

Backup Script:
  ~/backup-twiliosms.sh
EOF
    
    print_success "Installation info saved to installation-info.txt"
    echo ""
}

# Run main function
main "$@"
