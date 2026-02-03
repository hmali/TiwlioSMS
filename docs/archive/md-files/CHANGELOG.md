# Changelog

All notable changes to TwilioSMS will be documented in this file.

## [2.1.1] - 2026-02-02

### 🐛 Bug Fixes - Production Issues Resolved

**Critical fixes for auto-reply and subscriber management features**

#### Fixed Issues

1. **Custom Auto-Reply Not Working**
   - ❌ Problem: Messages other than STOP/START were not receiving configured auto-reply
   - ✅ Solution: Implemented full 5-step auto-reply processing flow
   - Impact: All inbound messages now properly routed through intent detection

2. **Inbound Messages Not Recording**
   - ❌ Problem: Incoming messages were not being stored in database
   - ✅ Solution: Added missing helper functions and fixed storage logic
   - Impact: Full message tracking with intent detection now working

3. **No Subscribers Dashboard**
   - ❌ Problem: No way to view STOP/START compliance data
   - ✅ Solution: Created comprehensive subscribers dashboard
   - Impact: Full visibility into opt-in/opt-out management

#### Added
- **4 Helper Functions** to `app.py`:
  - `get_subscriber_status()` - Check subscription status
  - `update_subscriber_status()` - Update opt-in/opt-out
  - `detect_intent()` - Keyword-based intent detection
  - `store_inbound_message()` - Save messages with intent tracking

- **Subscribers Dashboard** (`/subscribers` route)
  - View all subscribed/unsubscribed users
  - Opt-in/opt-out timestamps
  - STOP/START keyword reference
  - TCPA/CTIA compliance summary
  - Color-coded status indicators

- **Enhanced Inbound Messages View**
  - Added "Intent" column with color-coded badges
  - Visual indicators for STOP (red), START (green), intents (blue)
  - Better message tracking and analytics

- **Navigation Enhancement**
  - Added "Subscribers" link to main navigation
  - Easy access to compliance dashboard

#### Changed
- **Rewrote `/sms/inbound` webhook** with 5-step processing:
  1. Check STOP keywords → Unsubscribe
  2. Check START keywords → Resubscribe
  3. Check if unsubscribed → Send reminder
  4. Detect intent → Send custom reply
  5. Default → Send configured auto-reply

- **Enhanced logging** with emoji indicators:
  - 📩 Inbound message received
  - 🛑 STOP request (unsubscribe)
  - ✅ START request (resubscribe)
  - 🎯 Intent detected
  - 💬 Default auto-reply sent

- **Database initialization** now creates:
  - `subscribers` table with indexes
  - `auto_reply_intents` table with default intents
  - `intent` column in `inbound_messages` table

#### Documentation
- Created `BUGFIX_v2.1.1.md` - Complete testing and deployment guide
- Updated templates with intent tracking
- Added comprehensive troubleshooting section

#### Migration
- Run `python3 scripts/migrate_db_v2.py` to upgrade from v2.1.0
- Or reinitialize with `from app import init_db; init_db()`

---

## [2.0.0] - 2026-01-24

### 🎉 Production Release - Clean Codebase

This is a clean production release with all fixes applied and proper organization.

### ✨ Added
- **Clean project structure** - Scripts organized in `scripts/` directory
- **Production deployment guide** - New `DEPLOYMENT.md` with complete setup instructions
- **Diagnostic tools** - Auto-reply troubleshooting scripts in `scripts/diagnostics/`
- **Documentation archive** - Old docs moved to `docs/archive/`

### 🔧 Fixed
- **Auto-reply message update** - Fixed critical database UPDATE issue
  - Changed from `INSERT OR REPLACE` to explicit UPDATE/INSERT logic
  - Added proper error handling and logging
  - Timestamps now update correctly
  - Thread-safe for multiple Gunicorn workers

### 📁 Changed
- **Repository organization:**
  - `scripts/deployment/` - Deployment automation scripts
  - `scripts/diagnostics/` - Diagnostic and troubleshooting tools
  - `scripts/migrate_db.py` - Database migration utility
  - `docs/archive/` - Historical documentation
  
### 🗑️ Removed
- Diagnostic scripts from root directory (moved to `scripts/diagnostics/`)
- Deployment scripts from root directory (moved to `scripts/deployment/`)
- Old documentation files (archived in `docs/archive/`)

### 📝 Technical Details

**Database Fix:**
```python
# BEFORE (problematic)
INSERT OR REPLACE INTO settings (setting_key, setting_value, updated_at)
VALUES ('auto_reply_message', ?, CURRENT_TIMESTAMP)

# AFTER (production-ready)
# Check if exists, then UPDATE or INSERT accordingly
# Preserves record ID and properly updates timestamp
```

**Files Modified:**
- `app.py` - `set_auto_reply_message()` function (lines 66-95)
- `README.md` - Clean production documentation
- Project structure reorganized for production deployment

### 🚀 Deployment

To deploy this version:

```bash
cd ~/TiwlioSMS
git pull origin dev/twilioms-test
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart twiliosms
```

### 🔐 Security
- All production security features intact
- No new vulnerabilities introduced
- Clean code without temporary/diagnostic scripts in production paths

---

## [1.x.x] - Previous Versions

See `docs/archive/` for historical documentation and changelog.
