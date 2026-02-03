# TwilioSMS v2.1.1 - Hotfix Deployment Guide

## Issue Fixed
**Inbound Messages Page Error**: "Internal server error" caused by missing `intent` column in the database.

## What Changed in v2.1.1 Hotfix

### Code Changes
1. **Added `ensure_database_schema()` function** - Automatic migration helper
2. **Updated `/inbound-messages` route** - Backward-compatible with missing columns
3. **Updated `/subscribers` route** - Better error handling
4. **Created migration script** - Standalone script to update database

### Database Changes
- Added `intent` column to `inbound_messages` table
- Created `subscribers` table (if missing)
- Created `auto_reply_intents` table (if missing)

---

## Deployment Steps for Production Server

### Option 1: Quick Fix (Recommended)

**Step 1:** Upload the migration script to your server
```bash
# From your local machine
scp scripts/migrate_db_v2.1.1.py hmali@your-server:~/TiwlioSMS/scripts/
```

**Step 2:** Run the migration on the server
```bash
# SSH to your server
ssh hmali@your-server

# Navigate to app directory
cd ~/TiwlioSMS

# Run migration (it will backup your database first)
python3 scripts/migrate_db_v2.1.1.py
```

**Step 3:** Upload the updated app.py
```bash
# From your local machine
scp app.py hmali@your-server:~/TiwlioSMS/
```

**Step 4:** Restart the application
```bash
# On your server
sudo systemctl restart twilio_sms
sudo systemctl status twilio_sms
```

**Step 5:** Test the fix
```bash
# Open browser and test:
1. Inbound Messages page - should now work
2. Subscribers page - should display correctly
3. Send a test message to verify auto-reply works
```

---

### Option 2: Full Deployment

**Step 1:** Commit and push changes
```bash
# From your local machine, in the TiwlioSMS directory
git add .
git commit -m "v2.1.1 hotfix - Fix inbound messages error with database migration"
git push origin dev/twilioms-test
```

**Step 2:** Pull on production server
```bash
# SSH to your server
ssh hmali@your-server
cd ~/TiwlioSMS

# Backup current version
cp app.py app.py.backup_$(date +%Y%m%d_%H%M%S)

# Pull latest changes
git pull origin dev/twilioms-test
```

**Step 3:** Run migration
```bash
# Run the migration script
python3 scripts/migrate_db_v2.1.1.py
```

**Step 4:** Restart application
```bash
sudo systemctl restart twilio_sms
sudo systemctl status twilio_sms
```

---

## Verification Steps

### 1. Check Application Logs
```bash
# View recent logs
tail -f ~/TiwlioSMS/twilio_sms.log

# Look for migration messages:
# - "Adding 'intent' column to inbound_messages table..."
# - "Migration completed: intent column added"
```

### 2. Verify Database Schema
```bash
# Check if intent column was added
sqlite3 ~/TiwlioSMS/twilio_sms.db "PRAGMA table_info(inbound_messages);"

# Expected output should include:
# 6|intent|TEXT|0||0
```

### 3. Test Web Interface
Open your browser and test:

1. **Inbound Messages Page** (`/inbound-messages`)
   - Should load without errors
   - Should display messages with intent badges (STOP, START, etc.)

2. **Subscribers Page** (`/subscribers`)
   - Should display subscriber list
   - Should show subscribed/unsubscribed counts

3. **Auto-Reply Functionality**
   - Send "STOP" to your number → Should unsubscribe
   - Send "START" to your number → Should resubscribe
   - Send "RSVP" to your number → Should get custom RSVP reply

---

## Rollback Plan (If Needed)

If something goes wrong, you can rollback:

```bash
# The migration script creates automatic backups
# List backups
ls -la ~/TiwlioSMS/*.backup_*

# Restore from backup (replace timestamp with your backup)
cp ~/TiwlioSMS/twilio_sms.db.backup_20260203_HHMMSS ~/TiwlioSMS/twilio_sms.db

# Restore app.py (if you made a backup)
cp ~/TiwlioSMS/app.py.backup_20260203_HHMMSS ~/TiwlioSMS/app.py

# Restart service
sudo systemctl restart twilio_sms
```

---

## Troubleshooting

### Issue: Migration script fails with "Permission denied"
**Solution:**
```bash
chmod +x scripts/migrate_db_v2.1.1.py
```

### Issue: "Database is locked" error
**Solution:**
```bash
# Stop the application first
sudo systemctl stop twilio_sms

# Run migration
python3 scripts/migrate_db_v2.1.1.py

# Start application
sudo systemctl start twilio_sms
```

### Issue: Inbound Messages page still shows error
**Solution:**
```bash
# Check logs for specific error
tail -100 ~/TiwlioSMS/twilio_sms.log

# Verify database schema was updated
sqlite3 ~/TiwlioSMS/twilio_sms.db "PRAGMA table_info(inbound_messages);"

# Clear browser cache and try again
```

### Issue: Subscribers page shows "0 subscribers"
**Solution:** This is normal if:
- No one has sent STOP or START yet
- The subscribers table is new and empty
- Wait for incoming messages to populate the table

---

## What's New in v2.1.1

### Features
1. **Automatic Database Migration** - App now checks and updates schema on startup
2. **Backward Compatibility** - Works with old and new database schemas
3. **Better Error Handling** - Graceful fallback if columns are missing
4. **Migration Script** - Standalone script for manual database updates

### Bug Fixes
1. ✓ Fixed: Inbound Messages page "Internal server error"
2. ✓ Fixed: Missing intent column in database
3. ✓ Fixed: Subscribers page not handling missing table

---

## Support

If you encounter any issues:

1. **Check logs:** `tail -100 ~/TiwlioSMS/twilio_sms.log`
2. **Check database:** `sqlite3 twilio_sms.db "SELECT * FROM inbound_messages LIMIT 5;"`
3. **Contact:** Document the error and check GitHub issues

---

**Version:** 2.1.1 Hotfix  
**Date:** February 3, 2026  
**Priority:** High - Production Bug Fix
