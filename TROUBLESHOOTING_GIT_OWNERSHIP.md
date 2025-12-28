# Git Ownership Error - Troubleshooting Guide

## Problem

**Error Message:**
```
fatal: detected dubious ownership in repository at '/opt/twilio-sms'
To add an exception for this directory, call:
    git config --global --add safe.directory /opt/twilio-sms
```

## Cause

This error occurs because:
1. The `/opt/twilio-sms` directory is owned by `www-data` user
2. The update script runs as `root` (via `sudo`)
3. Git's security feature prevents root from operating on directories owned by other users

## ✅ Quick Fix (Recommended)

On your EC2 instance, run:

```bash
# Step 1: Apply the fix
curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/fix-git-ownership.sh | sudo bash

# Step 2: Run the update
curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/update.sh | sudo bash
```

## 🔧 Manual Fix (Alternative)

If you prefer to fix it manually:

```bash
# Configure Git to trust the directory
sudo git config --global --add safe.directory /opt/twilio-sms

# Fix ownership
sudo chown -R www-data:www-data /opt/twilio-sms

# Retry the update
curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/update.sh | sudo bash
```

## 🛡️ Comprehensive Fix (If Above Doesn't Work)

```bash
# Become root
sudo su

# Configure Git safe directory
git config --global --add safe.directory /opt/twilio-sms

# Fix application ownership
chown -R www-data:www-data /opt/twilio-sms

# Fix .git directory ownership (for root access)
chown -R root:root /opt/twilio-sms/.git

# Exit root
exit

# Retry update
curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/update.sh | sudo bash
```

## ✅ Verification

Test that the fix worked:

```bash
cd /opt/twilio-sms
sudo git status
```

You should see git output without errors!

## 🔄 What the Update Scripts Now Do

The scripts have been updated to automatically handle this:

**update.sh:**
- Now runs `git config --global --add safe.directory /opt/twilio-sms` before pulling
- This prevents the error from occurring

**deploy.sh:**
- Configures safe directory during initial deployment
- Future deployments won't have this issue

**fix-git-ownership.sh:**
- New helper script for quick fixes on existing deployments
- Handles both Git config and ownership issues

## 📊 Expected Output After Fix

When the update succeeds, you'll see:

```
[18:41:04] Updating Twilio SMS App from GitHub...
[18:41:04] Creating backup...
[18:41:04] Configuring Git safe directory...
[18:41:04] Pulling latest code...
Already up to date.
[18:41:05] Preserving configuration...
[18:41:05] Updating dependencies...
[18:41:15] Setting permissions...
[18:41:16] Restarting service...
[SUCCESS] Update completed successfully!
```

## 🎯 What You'll Get After Update

The update deploys the GMADP rebranding:

- ✅ "GMADP" branding instead of "Twilio Bulk SMS"
- ✅ Shivam Maharaj logo in navbar
- ✅ Logo on login page
- ✅ Updated footer
- ✅ All page titles changed to GMADP

## 🆘 Still Having Issues?

If you still encounter problems:

1. **Check service status:**
   ```bash
   sudo systemctl status twilio-sms-app
   ```

2. **View logs:**
   ```bash
   sudo journalctl -u twilio-sms-app -f
   ```

3. **Manual pull:**
   ```bash
   cd /opt/twilio-sms
   sudo git config --global --add safe.directory /opt/twilio-sms
   sudo -u www-data git pull origin main
   sudo systemctl restart twilio-sms-app
   ```

4. **Nuclear option (fresh deployment):**
   ```bash
   # This will remove everything and redeploy
   curl -fsSL https://raw.githubusercontent.com/hmali/TiwlioSMS/main/deploy.sh | sudo bash
   ```
   **Warning:** This removes the existing deployment. Make sure to backup your `.env` file and database first!

## 📚 Related Files

- `update.sh` - Updated with Git safe directory config
- `deploy.sh` - Sets safe directory during initial setup
- `fix-git-ownership.sh` - Quick fix helper script

## 🎊 Summary

**Problem:** Git ownership security feature blocking updates  
**Solution:** Configure Git to trust the deployment directory  
**Status:** ✅ FIXED - All scripts updated and live on GitHub  

---

**Last Updated:** December 28, 2025  
**Fix Version:** Commit b93177b
