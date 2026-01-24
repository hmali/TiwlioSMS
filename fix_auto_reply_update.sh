#!/bin/bash
# Fix Auto-Reply Update Error
# Run this on your Ubuntu server to fix the auto-reply update issue

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   FIX AUTO-REPLY UPDATE ERROR                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if in correct directory
if [ ! -f "app.py" ]; then
    echo -e "${RED}❌ Error: app.py not found${NC}"
    echo "Please run from TiwlioSMS directory:"
    echo "  cd ~/TiwlioSMS && ./fix_auto_reply_update.sh"
    exit 1
fi

echo -e "${BLUE}Step 1: Checking database file...${NC}"

if [ ! -f "twilio_sms.db" ]; then
    echo -e "${RED}❌ Database not found!${NC}"
    echo -e "${GREEN}Creating database...${NC}"
    python3 migrate_db.py
    echo -e "${GREEN}✅ Database created${NC}"
else
    echo -e "${GREEN}✅ Database exists${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Checking database permissions...${NC}"

# Check if database is writable
if [ -w "twilio_sms.db" ]; then
    echo -e "${GREEN}✅ Database is writable${NC}"
else
    echo -e "${YELLOW}⚠️  Database is not writable - fixing...${NC}"
    chmod 644 twilio_sms.db
    echo -e "${GREEN}✅ Permissions fixed${NC}"
fi

# Show current permissions
PERMS=$(stat -c "%a" twilio_sms.db 2>/dev/null || stat -f "%A" twilio_sms.db 2>/dev/null)
echo "   Current permissions: $PERMS"

echo ""
echo -e "${BLUE}Step 3: Running diagnostic script...${NC}"
python3 diagnose_auto_reply.py

echo ""
echo -e "${BLUE}Step 4: Checking Gunicorn service...${NC}"

if sudo systemctl is-active --quiet twiliosms; then
    echo -e "${GREEN}✅ Service is running${NC}"
    
    echo -e "${YELLOW}Restarting service to apply fixes...${NC}"
    sudo systemctl restart twiliosms
    sleep 2
    
    if sudo systemctl is-active --quiet twiliosms; then
        echo -e "${GREEN}✅ Service restarted successfully${NC}"
    else
        echo -e "${RED}❌ Service failed to start${NC}"
        echo "Check logs: sudo journalctl -u twiliosms -n 50"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Service is not running${NC}"
    echo "Starting service..."
    sudo systemctl start twiliosms
    sleep 2
    
    if sudo systemctl is-active --quiet twiliosms; then
        echo -e "${GREEN}✅ Service started${NC}"
    else
        echo -e "${RED}❌ Service failed to start${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}Step 5: Checking application logs...${NC}"
echo "Recent errors (if any):"
echo "─────────────────────────────────────────────────────────────"
sudo journalctl -u twiliosms -n 20 --no-pager | grep -i "error\|fail" || echo "No recent errors found"
echo "─────────────────────────────────────────────────────────────"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   ✅ FIX COMPLETE                                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}The auto-reply update issue should now be fixed.${NC}"
echo ""
echo "Next steps:"
echo "  1. Access web interface: http://$(hostname -I | awk '{print $1}'):5000"
echo "  2. Login and go to: Settings → Auto-Reply Message"
echo "  3. Try updating the message"
echo "  4. If still failing, check logs: sudo journalctl -u twiliosms -f"
echo ""
echo "Common issues:"
echo "  • Database permissions - Fixed ✅"
echo "  • Service needs restart - Fixed ✅"
echo "  • Form submission error - Check browser console"
echo ""
