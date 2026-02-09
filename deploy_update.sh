#!/bin/bash
###############################################################################
# TwilioSMS v2.1.1 - Quick Production Deployment Script
# 
# Usage: Run this script ON YOUR PRODUCTION SERVER after pushing code to GitHub
# 
# Steps:
# 1. SSH into your production server
# 2. cd ~/TiwlioSMS
# 3. bash deploy_update.sh
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║   TwilioSMS v2.1.1 - Production Update                   ║"
echo "║   Quick Deployment Script                                ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Confirm deployment
echo -e "${YELLOW}This will:${NC}"
echo "  1. Backup current database"
echo "  2. Stop the application"
echo "  3. Pull latest code from GitHub"
echo "  4. Update dependencies"
echo "  5. Run database migration"
echo "  6. Restart the application"
echo ""
read -p "Continue with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 0
fi

###############################################################################
# Step 1: Backup Database
###############################################################################
echo ""
echo -e "${BLUE}[1/6] Backing up database...${NC}"
mkdir -p backups
BACKUP_FILE="backups/twilio_sms.db.backup_$(date +%Y%m%d_%H%M%S)"
cp twilio_sms.db "$BACKUP_FILE"
echo -e "${GREEN}✓ Database backed up to: $BACKUP_FILE${NC}"

###############################################################################
# Step 2: Stop Service
###############################################################################
echo ""
echo -e "${BLUE}[2/6] Stopping application service...${NC}"
sudo systemctl stop twiliosms
echo -e "${GREEN}✓ Service stopped${NC}"

###############################################################################
# Step 3: Pull Latest Code
###############################################################################
echo ""
echo -e "${BLUE}[3/6] Pulling latest code from GitHub...${NC}"

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Pull updates
git pull origin dev/twilioms-test

# Show what changed
echo ""
echo -e "${YELLOW}Recent commits:${NC}"
git log --oneline -5
echo -e "${GREEN}✓ Code updated${NC}"

###############################################################################
# Step 4: Update Dependencies
###############################################################################
echo ""
echo -e "${BLUE}[4/6] Updating Python dependencies...${NC}"
source venv/bin/activate
pip install -r requirements.txt --upgrade --quiet
echo -e "${GREEN}✓ Dependencies updated${NC}"

###############################################################################
# Step 5: Run Database Migration
###############################################################################
echo ""
echo -e "${BLUE}[5/6] Running database migration...${NC}"
if [ -f "scripts/migrate_db_v2.1.1.py" ]; then
    python3 scripts/migrate_db_v2.1.1.py
else
    echo -e "${YELLOW}Migration script not found, skipping...${NC}"
fi

# Set proper permissions
chmod 664 twilio_sms.db 2>/dev/null || true
chmod 775 . 2>/dev/null || true
echo -e "${GREEN}✓ Migration complete${NC}"

###############################################################################
# Step 6: Start Service
###############################################################################
echo ""
echo -e "${BLUE}[6/6] Starting application service...${NC}"
sudo systemctl start twiliosms
sleep 2
sudo systemctl status twiliosms --no-pager || true
echo -e "${GREEN}✓ Service started${NC}"

###############################################################################
# Deployment Summary
###############################################################################
echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║   ✅  Deployment Complete!                               ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}=== Post-Deployment Checks ===${NC}"
echo ""
echo "1. View logs in real-time:"
echo -e "   ${GREEN}sudo journalctl -u twiliosms -f${NC}"
echo ""
echo "2. Check service status:"
echo -e "   ${GREEN}sudo systemctl status twiliosms${NC}"
echo ""
echo "3. View application logs:"
echo -e "   ${GREEN}tail -f twilio_sms.log${NC}"
echo ""
echo "4. Test in browser:"
echo -e "   ${GREEN}Open: http://your-domain.com${NC}"
echo ""
echo "5. Test custom reply feature:"
echo "   - Login to dashboard"
echo "   - Navigate to 'Inbound Messages'"
echo "   - Click 'Reply' button on any message"
echo "   - Verify form expands with character counter"
echo ""

echo -e "${YELLOW}=== Rollback (if needed) ===${NC}"
echo ""
echo "If something went wrong, rollback with:"
echo -e "${RED}sudo systemctl stop twiliosms${NC}"
echo -e "${RED}cp $BACKUP_FILE twilio_sms.db${NC}"
echo -e "${RED}git reset --hard HEAD~1${NC}"
echo -e "${RED}sudo systemctl start twiliosms${NC}"
echo ""

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${BLUE}Monitor logs for the next 10-15 minutes to ensure stability.${NC}"
echo ""
