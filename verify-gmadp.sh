#!/bin/bash

# GMADP Deployment Verification Script
# Run this after deploying to verify everything is working

echo "🎨 GMADP Rebranding & Logo Deployment Verification"
echo "=================================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running locally or on server
if [ -f "venv/bin/activate" ]; then
    echo "📍 Running in local development environment"
    BASE_URL="http://localhost:5000"
else
    echo "📍 Running on production server"
    BASE_URL="http://localhost"
fi

echo ""
echo "1️⃣  Checking Files..."
echo "----------------------------------------"

# Check logo file
if [ -f "static/images/gmadp-logo.png" ]; then
    echo -e "${GREEN}✅ Logo file exists${NC}"
    ls -lh static/images/gmadp-logo.png
else
    echo -e "${RED}❌ Logo file missing!${NC}"
fi

# Check templates
echo ""
echo "2️⃣  Checking Templates..."
echo "----------------------------------------"

templates=(
    "templates/base.html"
    "templates/login.html"
    "templates/dashboard.html"
    "templates/send_sms.html"
    "templates/campaign_status.html"
    "templates/settings.html"
    "templates/change_credentials.html"
)

for template in "${templates[@]}"; do
    if grep -q "GMADP" "$template"; then
        echo -e "${GREEN}✅ $template - GMADP branding found${NC}"
    else
        echo -e "${RED}❌ $template - GMADP branding missing${NC}"
    fi
done

# Check CSS
echo ""
echo "3️⃣  Checking CSS Styles..."
echo "----------------------------------------"

if grep -q ".navbar-logo" "static/css/style.css"; then
    echo -e "${GREEN}✅ Navbar logo styles found${NC}"
else
    echo -e "${RED}❌ Navbar logo styles missing${NC}"
fi

if grep -q ".login-logo" "static/css/style.css"; then
    echo -e "${GREEN}✅ Login logo styles found${NC}"
else
    echo -e "${RED}❌ Login logo styles missing${NC}"
fi

# Check branding in templates
echo ""
echo "4️⃣  Verifying Branding Details..."
echo "----------------------------------------"

# Check base.html for logo image tag
if grep -q "gmadp-logo.png" "templates/base.html"; then
    echo -e "${GREEN}✅ Logo integrated in navbar${NC}"
else
    echo -e "${YELLOW}⚠️  Logo may not be in navbar${NC}"
fi

# Check login.html for logo
if grep -q "gmadp-logo.png" "templates/login.html"; then
    echo -e "${GREEN}✅ Logo integrated in login page${NC}"
else
    echo -e "${YELLOW}⚠️  Logo may not be in login page${NC}"
fi

# Check footer
if grep -q "GMADP - Global Messaging" "templates/base.html"; then
    echo -e "${GREEN}✅ Footer updated with GMADP branding${NC}"
else
    echo -e "${YELLOW}⚠️  Footer may not be updated${NC}"
fi

# Test application import
echo ""
echo "5️⃣  Testing Application..."
echo "----------------------------------------"

if python3 -c "from app import app; print('✅ App imports successfully')" 2>/dev/null; then
    echo -e "${GREEN}✅ Application imports without errors${NC}"
else
    echo -e "${YELLOW}⚠️  Application import issues (may need dependencies)${NC}"
fi

# Check if service is running (production only)
echo ""
echo "6️⃣  Service Status..."
echo "----------------------------------------"

if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet twilio-sms-app 2>/dev/null; then
        echo -e "${GREEN}✅ Service is running${NC}"
        systemctl status twilio-sms-app --no-pager -l | head -5
    else
        echo -e "${YELLOW}⚠️  Service not running (or not in production)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Not a systemd environment (local development)${NC}"
fi

# Git status
echo ""
echo "7️⃣  Git Status..."
echo "----------------------------------------"

if git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Git repository${NC}"
    echo "Current branch: $(git branch --show-current)"
    echo "Latest commit: $(git log -1 --oneline)"
    
    # Check if there are uncommitted changes
    if [ -z "$(git status --porcelain)" ]; then
        echo -e "${GREEN}✅ No uncommitted changes${NC}"
    else
        echo -e "${YELLOW}⚠️  Uncommitted changes found:${NC}"
        git status --short
    fi
fi

# Summary
echo ""
echo "=================================================="
echo "📊 VERIFICATION SUMMARY"
echo "=================================================="
echo ""

# Count checks
total_checks=10
passed_checks=0

[ -f "static/images/gmadp-logo.png" ] && ((passed_checks++))
grep -q "GMADP" "templates/base.html" && ((passed_checks++))
grep -q "GMADP" "templates/login.html" && ((passed_checks++))
grep -q ".navbar-logo" "static/css/style.css" && ((passed_checks++))
grep -q ".login-logo" "static/css/style.css" && ((passed_checks++))
grep -q "gmadp-logo.png" "templates/base.html" && ((passed_checks++))
grep -q "gmadp-logo.png" "templates/login.html" && ((passed_checks++))
grep -q "GMADP - Global Messaging" "templates/base.html" && ((passed_checks++))

echo "✅ Passed Checks: $passed_checks/$total_checks"
echo ""

if [ $passed_checks -eq $total_checks ]; then
    echo -e "${GREEN}🎉 ALL CHECKS PASSED!${NC}"
    echo ""
    echo "Your GMADP rebranding is complete and ready!"
    echo ""
    echo "Next steps:"
    echo "1. Access application at: $BASE_URL"
    echo "2. Verify logo appears in navbar"
    echo "3. Check login page for large logo"
    echo "4. Test all pages for GMADP branding"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠️  SOME CHECKS FAILED${NC}"
    echo ""
    echo "Please review the issues above and fix them."
    echo ""
    exit 1
fi
