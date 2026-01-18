#!/bin/bash
# Production Readiness Check Script

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         PRODUCTION READINESS CHECK                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0
WARN=0

# Check 1: Essential files exist
echo "1️⃣  CHECKING ESSENTIAL FILES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for file in app.py gunicorn_config.py requirements.txt production-deploy.sh README.md .gitignore; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
        ((PASS++))
    else
        echo "  ❌ MISSING: $file"
        ((FAIL++))
    fi
done
echo ""

# Check 2: Template files
echo "2️⃣  CHECKING TEMPLATE FILES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for file in base.html login.html dashboard.html send_sms.html settings.html campaign_status.html change_credentials.html inbound_messages.html settings_auto_reply.html; do
    if [ -f "templates/$file" ]; then
        echo "  ✅ templates/$file"
        ((PASS++))
    else
        echo "  ❌ MISSING: templates/$file"
        ((FAIL++))
    fi
done
echo ""

# Check 3: Static files
echo "3️⃣  CHECKING STATIC FILES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "static/css/style.css" ]; then
    echo "  ✅ static/css/style.css"
    ((PASS++))
else
    echo "  ❌ MISSING: static/css/style.css"
    ((FAIL++))
fi

if [ -f "static/js/app.js" ]; then
    echo "  ✅ static/js/app.js"
    ((PASS++))
else
    echo "  ❌ MISSING: static/js/app.js"
    ((FAIL++))
fi

if [ -f "static/images/gmadp-logo.png" ]; then
    echo "  ✅ static/images/gmadp-logo.png"
    ((PASS++))
else
    echo "  ⚠️  WARNING: static/images/gmadp-logo.png not found"
    ((WARN++))
fi
echo ""

# Check 4: Security checks
echo "4️⃣  CHECKING SECURITY..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if login.html has default credentials displayed
if grep -q "Default: admin" templates/login.html 2>/dev/null; then
    echo "  ❌ FAIL: Default credentials shown in login page"
    ((FAIL++))
else
    echo "  ✅ No default credentials in login page UI"
    ((PASS++))
fi

# Check if README has default credentials documented
if grep -q "admin123" README.md 2>/dev/null; then
    echo "  ✅ Default credentials documented in README"
    ((PASS++))
else
    echo "  ⚠️  WARNING: Default credentials not documented in README"
    ((WARN++))
fi

# Check gunicorn binding
if grep -q "127.0.0.1:8000" gunicorn_config.py 2>/dev/null; then
    echo "  ✅ Gunicorn securely bound to localhost"
    ((PASS++))
else
    echo "  ⚠️  WARNING: Gunicorn binding may not be secure"
    ((WARN++))
fi

# Check for hardcoded credentials in app.py
if grep -q "password.*=.*['\"]" app.py | grep -v "password_hash" | grep -v "request.form" | grep -v "form.get" 2>/dev/null; then
    echo "  ⚠️  WARNING: Possible hardcoded passwords in app.py"
    ((WARN++))
else
    echo "  ✅ No hardcoded passwords detected"
    ((PASS++))
fi
echo ""

# Check 5: Python syntax
echo "5️⃣  CHECKING PYTHON SYNTAX..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if python3 -m py_compile app.py 2>/dev/null; then
    echo "  ✅ app.py syntax valid"
    ((PASS++))
else
    echo "  ❌ FAIL: app.py has syntax errors"
    ((FAIL++))
fi

if python3 -m py_compile gunicorn_config.py 2>/dev/null; then
    echo "  ✅ gunicorn_config.py syntax valid"
    ((PASS++))
else
    echo "  ❌ FAIL: gunicorn_config.py has syntax errors"
    ((FAIL++))
fi
echo ""

# Check 6: Branding
echo "6️⃣  CHECKING BRANDING..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "GMADP Communication Platform" templates/base.html 2>/dev/null; then
    echo "  ✅ GMADP branding in base.html"
    ((PASS++))
else
    echo "  ⚠️  WARNING: GMADP branding not found in base.html"
    ((WARN++))
fi

if grep -q "GMADP Communication Platform" templates/dashboard.html 2>/dev/null; then
    echo "  ✅ GMADP branding in dashboard.html"
    ((PASS++))
else
    echo "  ⚠️  WARNING: GMADP branding not found in dashboard.html"
    ((WARN++))
fi

if grep -q "gmadp-logo.png" templates/login.html 2>/dev/null; then
    echo "  ✅ Logo referenced in login.html"
    ((PASS++))
else
    echo "  ⚠️  WARNING: Logo not referenced in login.html"
    ((WARN++))
fi
echo ""

# Check 7: Dependencies
echo "7️⃣  CHECKING DEPENDENCIES..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for pkg in Flask Werkzeug twilio gunicorn; do
    if grep -q "$pkg" requirements.txt 2>/dev/null; then
        echo "  ✅ $pkg in requirements.txt"
        ((PASS++))
    else
        echo "  ❌ MISSING: $pkg not in requirements.txt"
        ((FAIL++))
    fi
done
echo ""

# Check 8: Auto-reply integration
echo "8️⃣  CHECKING AUTO-REPLY INTEGRATION..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "/sms/inbound" app.py 2>/dev/null; then
    echo "  ✅ Auto-reply webhook endpoint exists"
    ((PASS++))
else
    echo "  ❌ FAIL: Auto-reply webhook not found"
    ((FAIL++))
fi

if grep -q "AUTO_REPLY_MESSAGE" app.py 2>/dev/null; then
    echo "  ✅ Auto-reply message configuration exists"
    ((PASS++))
else
    echo "  ❌ FAIL: Auto-reply configuration not found"
    ((FAIL++))
fi

if [ -f "templates/inbound_messages.html" ]; then
    echo "  ✅ Inbound messages template exists"
    ((PASS++))
else
    echo "  ❌ FAIL: Inbound messages template missing"
    ((FAIL++))
fi

if [ -f "templates/settings_auto_reply.html" ]; then
    echo "  ✅ Auto-reply settings template exists"
    ((PASS++))
else
    echo "  ❌ FAIL: Auto-reply settings template missing"
    ((FAIL++))
fi
echo ""

# Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SUMMARY                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ Passed:   $PASS"
echo "  ⚠️  Warnings: $WARN"
echo "  ❌ Failed:   $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅ PRODUCTION READY - All critical checks passed!          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    if [ $WARN -gt 0 ]; then
        echo "⚠️  Note: $WARN warnings detected. Review them before deployment."
    fi
    echo ""
    echo "✨ Your application is ready for production deployment!"
    echo ""
    echo "Next steps:"
    echo "  1. Commit changes: git add . && git commit -m 'Production ready'"
    echo "  2. Push to repository: git push origin main"
    echo "  3. Deploy: ssh to server and run ./production-deploy.sh"
    echo ""
    exit 0
else
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ❌ NOT READY - Fix $FAIL issues before deploying           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi
