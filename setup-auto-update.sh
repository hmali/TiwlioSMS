#!/bin/bash

# GitHub Auto-Update Script
# This script sets up automatic updates from GitHub using webhooks or cron jobs

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_DEPLOY_SCRIPT="$SCRIPT_DIR/github-deploy.sh"
CRON_JOB_FILE="/etc/cron.d/twilio-sms-update"
WEBHOOK_PORT="9000"
WEBHOOK_SECRET=""

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
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Setup cron job for regular updates
setup_cron() {
    log "Setting up cron job for regular updates..."
    
    cat > "$CRON_JOB_FILE" << EOF
# Twilio SMS App Auto-Update
# Run every day at 3 AM
0 3 * * * root $GITHUB_DEPLOY_SCRIPT >> /var/log/twilio-sms-update.log 2>&1
EOF
    
    # Reload cron
    systemctl reload cron
    
    success "Cron job created: Daily updates at 3 AM"
    success "Logs will be written to: /var/log/twilio-sms-update.log"
}

# Create webhook listener script
create_webhook_listener() {
    log "Creating webhook listener..."
    
    cat > /opt/twilio-sms/webhook-listener.py << 'EOF'
#!/usr/bin/env python3
"""
GitHub Webhook Listener for Twilio SMS App
Listens for push events and triggers deployment
"""

import json
import hashlib
import hmac
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import logging

# Configuration
PORT = int(os.environ.get('WEBHOOK_PORT', 9000))
SECRET = os.environ.get('WEBHOOK_SECRET', '').encode()
DEPLOY_SCRIPT = '/opt/twilio-sms/github-deploy.sh'
LOG_FILE = '/var/log/twilio-sms-webhook.log'

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        
        if content_length == 0:
            self.send_error(400, 'Empty request')
            return
        
        # Read the payload
        payload = self.rfile.read(content_length)
        
        # Verify signature if secret is set
        if SECRET:
            signature = self.headers.get('X-Hub-Signature-256', '')
            if not self.verify_signature(payload, signature):
                logger.warning('Invalid signature')
                self.send_error(401, 'Invalid signature')
                return
        
        # Parse payload
        try:
            data = json.loads(payload.decode())
        except json.JSONDecodeError:
            self.send_error(400, 'Invalid JSON')
            return
        
        # Check if it's a push event to main/master branch
        if self.is_valid_push_event(data):
            logger.info('Valid push event received, triggering deployment')
            self.trigger_deployment()
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'deployment triggered'}).encode())
        else:
            logger.info('Event ignored (not a push to main/master)')
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ignored'}).encode())
    
    def verify_signature(self, payload, signature):
        """Verify GitHub webhook signature"""
        if not signature.startswith('sha256='):
            return False
        
        expected_signature = 'sha256=' + hmac.new(
            SECRET,
            payload,
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(signature, expected_signature)
    
    def is_valid_push_event(self, data):
        """Check if this is a push event to main or master branch"""
        if data.get('zen'):  # GitHub ping event
            return False
        
        ref = data.get('ref', '')
        return ref in ['refs/heads/main', 'refs/heads/master']
    
    def trigger_deployment(self):
        """Trigger the deployment script"""
        try:
            subprocess.Popen([DEPLOY_SCRIPT], 
                           stdout=subprocess.DEVNULL, 
                           stderr=subprocess.DEVNULL)
            logger.info('Deployment script triggered')
        except Exception as e:
            logger.error(f'Failed to trigger deployment: {e}')
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(format % args)

def main():
    server = HTTPServer(('', PORT), WebhookHandler)
    logger.info(f'Starting webhook server on port {PORT}')
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info('Webhook server stopped')
        server.server_close()

if __name__ == '__main__':
    main()
EOF
    
    chmod +x /opt/twilio-sms/webhook-listener.py
    success "Webhook listener created"
}

# Create systemd service for webhook
create_webhook_service() {
    log "Creating webhook systemd service..."
    
    cat > /etc/systemd/system/twilio-sms-webhook.service << EOF
[Unit]
Description=Twilio SMS App GitHub Webhook Listener
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/twilio-sms
ExecStart=/usr/bin/python3 /opt/twilio-sms/webhook-listener.py
Environment=WEBHOOK_PORT=$WEBHOOK_PORT
Environment=WEBHOOK_SECRET=$WEBHOOK_SECRET
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log /opt/twilio-sms
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
    
    systemctl daemon-reload
    systemctl enable twilio-sms-webhook
    systemctl start twilio-sms-webhook
    
    success "Webhook service created and started on port $WEBHOOK_PORT"
}

# Configure nginx for webhook endpoint
configure_nginx_webhook() {
    log "Configuring Nginx for webhook endpoint..."
    
    # Create webhook nginx configuration
    cat > /etc/nginx/sites-available/twilio-sms-webhook << EOF
server {
    listen 80;
    server_name webhook.yourdomain.com;  # Update with your domain
    
    location /webhook {
        proxy_pass http://localhost:$WEBHOOK_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/twilio-sms-webhook /etc/nginx/sites-enabled/
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    
    success "Nginx webhook configuration created"
    warning "Update server_name in /etc/nginx/sites-available/twilio-sms-webhook with your domain"
}

# Show configuration instructions
show_instructions() {
    cat << EOF

${GREEN}GitHub Auto-Update Setup Complete!${NC}

${BLUE}Configuration Options:${NC}

1. ${YELLOW}Cron-based Updates (Scheduled):${NC}
   - Updates run daily at 3 AM
   - Logs: /var/log/twilio-sms-update.log
   - To change schedule: edit /etc/cron.d/twilio-sms-update

2. ${YELLOW}Webhook Updates (Real-time):${NC}
   - Webhook server running on port $WEBHOOK_PORT
   - Service: twilio-sms-webhook
   - Logs: /var/log/twilio-sms-webhook.log
   - Status: systemctl status twilio-sms-webhook

${BLUE}GitHub Webhook Setup:${NC}
1. Go to your GitHub repository settings
2. Click "Webhooks" → "Add webhook"
3. Set Payload URL: http://YOUR_SERVER_IP:$WEBHOOK_PORT/webhook
4. Set Content type: application/json
5. Set Secret: $WEBHOOK_SECRET (if configured)
6. Select events: Just the push event
7. Make sure webhook is active

${BLUE}Testing:${NC}
- Manual update: sudo $GITHUB_DEPLOY_SCRIPT
- Test webhook: curl -X POST http://localhost:$WEBHOOK_PORT
- View logs: tail -f /var/log/twilio-sms-*.log

${BLUE}Security:${NC}
- Webhook runs as www-data user
- Set WEBHOOK_SECRET for signature verification
- Consider using HTTPS for webhook endpoint

EOF
}

# Main setup function
main() {
    log "Setting up GitHub auto-update system..."
    
    check_root
    
    # Make sure github-deploy.sh is executable
    chmod +x "$GITHUB_DEPLOY_SCRIPT"
    
    echo "Select update method:"
    echo "1) Cron-based updates (scheduled)"
    echo "2) Webhook updates (real-time)"
    echo "3) Both"
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            setup_cron
            ;;
        2)
            read -p "Enter webhook port (default: 9000): " port
            WEBHOOK_PORT=${port:-9000}
            
            read -p "Enter webhook secret (optional): " secret
            WEBHOOK_SECRET="$secret"
            
            create_webhook_listener
            create_webhook_service
            configure_nginx_webhook
            ;;
        3)
            setup_cron
            
            read -p "Enter webhook port (default: 9000): " port
            WEBHOOK_PORT=${port:-9000}
            
            read -p "Enter webhook secret (optional): " secret
            WEBHOOK_SECRET="$secret"
            
            create_webhook_listener
            create_webhook_service
            configure_nginx_webhook
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    show_instructions
    success "GitHub auto-update system configured!"
}

# Show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script sets up automatic updates from GitHub using:"
    echo "- Cron jobs for scheduled updates"
    echo "- Webhook listeners for real-time updates"
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

main
