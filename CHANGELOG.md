# Changelog

All notable changes to TwilioSMS will be documented in this file.

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
