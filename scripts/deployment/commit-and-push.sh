#!/bin/bash
# Final commit and push script for production deployment

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         GMADP Communication Platform                        ║"
echo "║         Final Commit & Push to Production                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're in git repo
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository"
    exit 1
fi

# Run production checks first
echo "🔍 Running production readiness checks..."
echo ""
if [ -f "production-check.sh" ]; then
    ./production-check.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo "❌ Production checks failed. Please fix issues before committing."
        exit 1
    fi
else
    echo "⚠️  Warning: production-check.sh not found, skipping checks"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Git Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
git status --short
echo ""

# Ask for confirmation
read -p "📝 Ready to commit? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Stage all changes
echo ""
echo "📦 Staging all changes..."
git add .

# Show what will be committed
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Files to be committed:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
git diff --cached --name-status
echo ""

# Commit
COMMIT_MSG="Production ready v2.0: GMADP branding + Auto-reply integrated

Features:
- GMADP Communication Platform branding throughout
- Organization logo integrated in UI
- Auto-reply functionality for inbound SMS
- Bulk SMS sending with campaign tracking
- Secure authentication with password change
- HTTPS/SSL ready for smsgajanannj.com
- One-command deployment script
- Automatic database backups

Security:
- Default credentials removed from login UI
- Credentials documented in README only
- Password hashing and secure sessions
- SQL injection protection
- Firewall and SSL configuration

Ready for production deployment!"

echo "💬 Commit message:"
echo "$COMMIT_MSG"
echo ""

git commit -m "$COMMIT_MSG"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Commit successful!"
    echo ""
    
    # Ask about pushing
    read -p "🚀 Push to remote repository? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "📤 Pushing to remote..."
        
        # Get current branch
        BRANCH=$(git rev-parse --abbrev-ref HEAD)
        echo "   Branch: $BRANCH"
        
        git push origin $BRANCH
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║  ✅ SUCCESS! Code pushed to production                      ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo ""
            echo "📋 Next Steps:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "1️⃣  SSH to your server:"
            echo "   ssh ubuntu@your-server-ip"
            echo ""
            echo "2️⃣  Clone repository (if first time):"
            echo "   cd ~"
            echo "   git clone https://github.com/yourusername/TiwlioSMS.git"
            echo "   cd TiwlioSMS"
            echo ""
            echo "   OR pull updates (if already deployed):"
            echo "   cd ~/TiwlioSMS"
            echo "   git pull origin $BRANCH"
            echo ""
            echo "3️⃣  Run deployment script:"
            echo "   chmod +x production-deploy.sh"
            echo "   ./production-deploy.sh"
            echo ""
            echo "4️⃣  Post-deployment:"
            echo "   • Visit: https://smsgajanannj.com"
            echo "   • Login: admin / admin123"
            echo "   • Change password immediately!"
            echo "   • Configure Twilio credentials"
            echo "   • Set webhook: https://smsgajanannj.com/sms/inbound"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "🎉 Your GMADP Communication Platform is ready to deploy!"
            echo ""
        else
            echo ""
            echo "❌ Push failed. Please check your remote repository settings."
            exit 1
        fi
    else
        echo ""
        echo "ℹ️  Committed locally but not pushed."
        echo "   Run 'git push origin $BRANCH' when ready to push."
    fi
else
    echo ""
    echo "❌ Commit failed. Please check for errors."
    exit 1
fi
