#!/bin/bash

# Quick fix for Git ownership error
# Run this on your EC2 instance to fix the immediate issue

echo "🔧 Fixing Git ownership issue..."
echo ""

# Fix Git safe directory
sudo git config --global --add safe.directory /opt/twilio-sms

# Fix directory ownership
echo "Setting correct ownership..."
sudo chown -R www-data:www-data /opt/twilio-sms

# Verify fix
echo ""
echo "Testing Git access..."
cd /opt/twilio-sms
if sudo -u www-data git status > /dev/null 2>&1; then
    echo "✅ Git access fixed!"
    echo ""
    echo "Now you can run the update script:"
    echo "curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/update.sh | sudo bash"
else
    echo "❌ Issue persists. Trying alternative fix..."
    
    # Alternative: Change ownership to root for git operations
    sudo chown -R root:root /opt/twilio-sms/.git
    
    echo "✅ Applied alternative fix. Try the update again."
fi

echo ""
echo "Done!"
