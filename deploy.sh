#!/bin/bash
# Quick Deployment Script for TwilioSMS v2.1.1
# Run this on your Ubuntu production server

echo "🚀 TwilioSMS v2.1.1 Deployment"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running on server
if [ ! -d ~/TiwlioSMS ]; then
    echo -e "${RED}❌ Error: TiwlioSMS directory not found at ~/TiwlioSMS${NC}"
    echo "Please run this script on your production server"
    exit 1
fi

echo -e "${BLUE}📂 Navigating to application directory...${NC}"
cd ~/TiwlioSMS || exit 1

echo -e "${BLUE}🔄 Pulling latest changes from Git...${NC}"
git pull origin main || git pull origin dev/twilioms-test

echo -e "${BLUE}🐍 Activating virtual environment...${NC}"
source venv/bin/activate

echo -e "${BLUE}📦 Installing/updating dependencies...${NC}"
pip install -r requirements.txt

echo -e "${BLUE}🗄️  Updating database schema...${NC}"
python3 -c "from app import init_db; init_db(); print('✓ Database updated successfully')"

echo ""
echo -e "${GREEN}✅ Verifying database...${NC}"
sqlite3 twilio_sms.db << EOF
.echo on
SELECT 'Checking subscribers table...';
SELECT COUNT(*) as subscriber_count FROM subscribers;
SELECT 'Checking auto_reply_intents table...';
SELECT intent_name, priority FROM auto_reply_intents ORDER BY priority;
SELECT 'Checking inbound_messages has intent column...';
SELECT COUNT(*) FROM inbound_messages WHERE intent IS NOT NULL;
EOF

echo ""
echo -e "${BLUE}🔄 Restarting application service...${NC}"
sudo systemctl restart twiliosms

sleep 2

echo -e "${BLUE}📊 Checking service status...${NC}"
sudo systemctl status twiliosms --no-pager -l

echo ""
echo -e "${BLUE}🏥 Testing health endpoint...${NC}"
curl -s http://localhost/health | python3 -m json.tool || echo "Health check failed"

echo ""
echo -e "${GREEN}=============================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}=============================${NC}"
echo ""
echo "📝 Next steps:"
echo "1. Check logs: tail -f twilio_sms.log"
echo "2. Test auto-reply: Send SMS to your Twilio number"
echo "3. Verify in dashboard:"
echo "   - Inbound Messages page shows intent column"
echo "   - Subscribers page is accessible"
echo "   - Intent badges are color-coded"
echo ""
echo "🧪 Test commands:"
echo "  # Test webhook:"
echo "  curl -X POST http://localhost/sms/inbound \\"
echo "    -d 'From=+1234567890' \\"
echo "    -d 'Body=RSVP' \\"
echo "    -d 'MessageSid=TEST123'"
echo ""
echo "  # Check recent messages:"
echo "  sqlite3 twilio_sms.db 'SELECT from_number, message_body, intent FROM inbound_messages ORDER BY received_at DESC LIMIT 5;'"
echo ""
echo "  # View subscriber stats:"
echo "  sqlite3 twilio_sms.db 'SELECT status, COUNT(*) FROM subscribers GROUP BY status;'"
echo ""
echo -e "${GREEN}🎉 TwilioSMS v2.1.1 is now running!${NC}"
