# Adding the GMADP Logo to Your Application

## Step 1: Save the Logo File

You need to save your logo image to the static/images directory. The logo you attached shows the "Shivam Maharaj America Defense Fund" emblem.

### Option A: Using Finder (macOS)
1. Save the attached logo image from your conversation
2. Rename it to `gmadp-logo.png`
3. Move it to: `/Users/hmali/Documents/GitHub/TiwlioSMS/static/images/gmadp-logo.png`

### Option B: Using Terminal
```bash
cd /Users/hmali/Documents/GitHub/TiwlioSMS/static/images

# If your logo is on Desktop
cp ~/Desktop/your-logo-file.png gmadp-logo.png

# Or if it's in Downloads
cp ~/Downloads/your-logo-file.png gmadp-logo.png
```

## Step 2: Verify the Changes

The following files have been updated to use the logo:

### 1. `templates/base.html` - Navigation Bar
```html
<a class="navbar-brand d-flex align-items-center" href="{{ url_for('dashboard') }}">
    <img src="{{ url_for('static', filename='images/gmadp-logo.png') }}" alt="GMADP Logo" class="navbar-logo me-2">
    <span>GMADP</span>
</a>
```

### 2. `templates/login.html` - Login Page
```html
<div class="card-header bg-primary text-white text-center py-4">
    <img src="{{ url_for('static', filename='images/gmadp-logo.png') }}" alt="GMADP Logo" class="login-logo mb-3">
    <h4><i class="fas fa-sign-in-alt"></i> Login to GMADP</h4>
</div>
```

### 3. `static/css/style.css` - Logo Styling
Added styles for:
- `.navbar-logo` - Logo in navigation bar (40px height, circular border, hover effect)
- `.login-logo` - Logo on login page (100px height, circular border, shadow)

## Step 3: Test Locally

```bash
cd /Users/hmali/Documents/GitHub/TiwlioSMS
python3 app.py
```

Then open `http://localhost:5000` in your browser to see:
- Logo in the top navigation bar
- Larger logo on the login page

## Step 4: Logo Specifications

### Current Setup Expects:
- **File Name**: `gmadp-logo.png`
- **Location**: `static/images/`
- **Format**: PNG (supports transparency)
- **Recommended Size**: 200x200px or similar square ratio

### Your Logo:
The attached logo is a circular emblem with:
- Border with decorative pattern
- Central figure in meditation pose
- Text around the border
- Gold/bronze color scheme on blue background

This will work perfectly as a circular logo with the CSS styling applied.

## Step 5: Customization Options

If you want to adjust the logo size, edit `static/css/style.css`:

```css
/* For navbar logo */
.navbar-logo {
    height: 40px;  /* Change this value */
}

/* For login page logo */
.login-logo {
    height: 100px;  /* Change this value */
}
```

## Step 6: Commit and Deploy

Once you've added the logo file:

```bash
cd /Users/hmali/Documents/GitHub/TiwlioSMS

# Add the logo file and updated templates
git add static/images/gmadp-logo.png
git add templates/base.html
git add templates/login.html
git add static/css/style.css

# Commit the changes
git commit -m "Add GMADP logo to navigation and login page"

# Push to GitHub
git push origin main
```

## Step 7: EC2 Deployment

If using auto-update, the changes will deploy automatically. Otherwise:

```bash
ssh -i your-key.pem ubuntu@YOUR-EC2-IP
cd /opt/twilio-sms
sudo git pull
sudo systemctl restart twilio-sms-app
```

## Troubleshooting

### Logo not showing?
1. Check file exists: `ls -la static/images/gmadp-logo.png`
2. Check file permissions: `chmod 644 static/images/gmadp-logo.png`
3. Clear browser cache (Ctrl+Shift+R or Cmd+Shift+R)

### Logo too big/small?
Adjust the `height` values in `static/css/style.css`

### Want different logo shapes?
- **Circular**: Keep `border-radius: 50%`
- **Square**: Change to `border-radius: 8px`
- **No border**: Remove the `border` property

## Next Steps

1. ✅ **Save logo file** to `static/images/gmadp-logo.png`
2. ✅ **Test locally** to verify it looks good
3. ✅ **Adjust sizing** if needed in CSS
4. ✅ **Commit and push** to GitHub
5. ✅ **Deploy to EC2** and verify

---

**Note**: The logo you've chosen (Shivam Maharaj emblem) will be displayed as a circular badge throughout the application, providing a professional and branded look to GMADP.
