#!/bin/bash

# Script to add logo to GMADP application
# Run this script after saving the logo file

echo "🎨 GMADP Logo Integration Script"
echo "=================================="
echo ""

LOGO_DIR="static/images"
LOGO_FILE="$LOGO_DIR/gmadp-logo.png"

# Check if static/images directory exists
if [ ! -d "$LOGO_DIR" ]; then
    echo "✅ Creating $LOGO_DIR directory..."
    mkdir -p "$LOGO_DIR"
fi

# Check if logo file exists
if [ -f "$LOGO_FILE" ]; then
    echo "✅ Logo file found: $LOGO_FILE"
    
    # Show file info
    ls -lh "$LOGO_FILE"
    file "$LOGO_FILE"
    
    echo ""
    echo "✅ Logo is ready to use!"
    echo ""
    echo "Next steps:"
    echo "1. Test locally: python3 app.py"
    echo "2. Open http://localhost:5000 in browser"
    echo "3. Check navbar and login page for logo"
    echo "4. Commit: git add static/images/gmadp-logo.png"
    echo "5. Push: git push origin main"
    
else
    echo "❌ Logo file not found: $LOGO_FILE"
    echo ""
    echo "Please save your logo file using one of these methods:"
    echo ""
    echo "Method 1: From Desktop"
    echo "  cp ~/Desktop/your-logo.png $LOGO_FILE"
    echo ""
    echo "Method 2: From Downloads"
    echo "  cp ~/Downloads/your-logo.png $LOGO_FILE"
    echo ""
    echo "Method 3: Using Finder"
    echo "  1. Open the attached image from your conversation"
    echo "  2. Right-click and 'Save Image As...'"
    echo "  3. Navigate to: $(pwd)/$LOGO_DIR"
    echo "  4. Save as: gmadp-logo.png"
    echo ""
    echo "Method 4: Drag and Drop (if in VS Code)"
    echo "  1. Open the image attachment"
    echo "  2. Drag and drop into $LOGO_DIR folder"
    echo "  3. Rename to: gmadp-logo.png"
    echo ""
    
    # Try to find potential logo files
    echo "Looking for potential logo files in common locations..."
    find ~/Desktop ~/Downloads -name "*.png" -o -name "*.jpg" 2>/dev/null | grep -i "logo\|shivam\|gmadp" | head -5
fi

echo ""
echo "📋 Files updated for logo integration:"
echo "  ✅ templates/base.html - Navbar logo"
echo "  ✅ templates/login.html - Login page logo"
echo "  ✅ static/css/style.css - Logo styling"
echo ""
