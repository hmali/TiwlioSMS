# 🐛 QA Bug Fix - Intent Not Updating After Custom Reply

**Date:** February 9, 2026  
**Version:** 2.1.2 Hotfix  
**Bug ID:** QA-001  
**Severity:** Medium  
**Status:** ✅ Fixed

---

## 🐛 BUG DESCRIPTION

**Issue Found in QA:**
After admin sends a custom reply using the "Reply" button, the intent badge remains stuck as "Pending Reply" (yellow/orange) instead of changing to show that a custom reply was sent.

**Expected Behavior:**
- Message starts as: "Pending Reply" (yellow badge)
- After admin sends custom reply: Badge changes to "Custom Reply" (blue badge)

**Actual Behavior:**
- Message starts as: "Pending Reply" (yellow badge)
- After admin sends custom reply: Badge stays as "Pending Reply" ❌

---

## 🔍 ROOT CAUSE

### **Problem in `/send-custom-reply` Route:**

**File:** `app.py` (Line 1037)

**Before (Buggy Code):**
```python
# Update the inbound message to mark custom reply sent
cursor.execute('''
    UPDATE inbound_messages SET reply_sent = 1 WHERE id = ?
''', (message_id,))
```

**Issue:**
- Only updates `reply_sent = 1` ✓
- Does NOT update `intent` column ❌
- Intent remains as `PENDING_REPLY`

---

## ✅ THE FIX

### **1. Updated Database Query (app.py)**

**After (Fixed Code):**
```python
# Update the inbound message to mark custom reply sent and change intent
cursor.execute('''
    UPDATE inbound_messages 
    SET reply_sent = 1, intent = 'CUSTOM_REPLY' 
    WHERE id = ?
''', (message_id,))
```

**Changes:**
- ✅ Sets `reply_sent = 1` (already working)
- ✅ Sets `intent = 'CUSTOM_REPLY'` (NEW - fixes the bug)

### **2. Added Badge Display (inbound_messages.html)**

**Before:**
```html
{% elif msg[6] == 'PENDING_REPLY' %}
    <span class="badge bg-warning"><i class="fas fa-clock"></i> Pending Reply</span>
{% elif msg[6] == 'DEFAULT' %}
    <span class="badge bg-light text-dark"><i class="fas fa-comment"></i> Default</span>
```

**After:**
```html
{% elif msg[6] == 'PENDING_REPLY' %}
    <span class="badge bg-warning"><i class="fas fa-clock"></i> Pending Reply</span>
{% elif msg[6] == 'CUSTOM_REPLY' %}
    <span class="badge bg-info"><i class="fas fa-paper-plane"></i> Custom Reply</span>
{% elif msg[6] == 'DEFAULT' %}
    <span class="badge bg-light text-dark"><i class="fas fa-comment"></i> Default</span>
```

**Changes:**
- ✅ Added new condition for `CUSTOM_REPLY`
- ✅ Shows blue badge with paper plane icon
- ✅ Clearly indicates custom reply was sent

---

## 🎨 BADGE STATUS FLOW

### **Complete Intent Badge System:**

```
┌─────────────────────────────────────────────────────────────┐
│  MESSAGE LIFECYCLE                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Inbound SMS Received                                    │
│     ↓                                                       │
│     Intent: [Pending Reply] (yellow/orange) ⏰             │
│     Action: Admin can send custom reply                     │
│                                                             │
│  2. Admin Clicks "Reply" Button                             │
│     ↓                                                       │
│     Form expands with custom message field                  │
│                                                             │
│  3. Admin Sends Custom Reply                                │
│     ↓                                                       │
│     Intent: [Custom Reply] (blue) ✈️                        │
│     Status: Reply sent ✓                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### **All Intent Badge Types:**

| Intent | Badge Color | Icon | Description |
|--------|-------------|------|-------------|
| **STOP** | Red (`bg-danger`) | 🚫 ban | User unsubscribed |
| **START** | Green (`bg-success`) | ✓ check-circle | User resubscribed |
| **UNSUBSCRIBED** | Gray (`bg-secondary`) | 👤 user-slash | Message from unsubscribed user |
| **PENDING_REPLY** | Yellow/Orange (`bg-warning`) | ⏰ clock | Waiting for admin reply |
| **CUSTOM_REPLY** | Blue (`bg-info`) | ✈️ paper-plane | Admin sent custom reply |
| **DEFAULT** | Light Gray (`bg-light`) | 💬 comment | Default auto-reply (legacy) |
| **RSVP/TIME/ADDRESS/SEVA** | Blue (`bg-primary`) | 🧠 brain | Custom intent detected |

---

## 🧪 TESTING THE FIX

### **Test Case 1: Send Custom Reply**

**Steps:**
1. Send test SMS to Twilio number: "Hello, I need help"
2. Message appears in dashboard with yellow "Pending Reply" badge
3. Click "Reply" button
4. Type custom message: "Hi! How can I help you today?"
5. Click "Send Custom Reply"
6. **Expected Result:** Badge changes to blue "Custom Reply" ✓
7. **Actual Result:** ✅ PASS (after fix)

### **Test Case 2: Multiple Replies**

**Steps:**
1. Send test SMS: "Question 1"
2. Badge shows: "Pending Reply" (yellow)
3. Admin sends custom reply: "Answer 1"
4. Badge shows: "Custom Reply" (blue) ✓
5. Same user sends another SMS: "Question 2"
6. New message shows: "Pending Reply" (yellow) ✓
7. Admin sends another custom reply: "Answer 2"
8. Badge shows: "Custom Reply" (blue) ✓
9. **Expected:** Each message tracks independently
10. **Actual:** ✅ PASS

### **Test Case 3: Database Verification**

**Query:**
```sql
-- Check intent changes after custom reply
SELECT id, from_number, body, intent, reply_sent, received_at 
FROM inbound_messages 
ORDER BY received_at DESC 
LIMIT 10;
```

**Expected Results:**
```
id  | from_number   | body          | intent        | reply_sent
----|---------------|---------------|---------------|------------
42  | +15551234567 | Need help     | CUSTOM_REPLY  | 1
41  | +15559876543 | Question      | PENDING_REPLY | 0
40  | +15551112222 | STOP          | STOP          | 0
```

**Actual Results:** ✅ PASS

---

## 📊 FILES CHANGED

| File | Lines Changed | Change Type |
|------|---------------|-------------|
| `app.py` | 1037-1040 | Modified UPDATE query |
| `templates/inbound_messages.html` | 51-53 | Added CUSTOM_REPLY badge condition |
| `BUGFIX_QA_001.md` | NEW | Documentation |

---

## 🚀 DEPLOYMENT INSTRUCTIONS

### **For Production:**

**Option 1: Use Upgrade Script (Recommended)**
```bash
ssh username@production-server
cd ~/TiwlioSMS
./upgrade_production.sh
```

**Option 2: Manual Deployment**
```bash
# 1. SSH to server
ssh username@production-server

# 2. Navigate to app
cd ~/TiwlioSMS

# 3. Backup database
cp twilio_sms.db backups/twilio_sms.db.backup_$(date +%Y%m%d_%H%M%S)

# 4. Stop service
sudo systemctl stop twiliosms

# 5. Pull latest code
git pull origin dev/twilioms-test

# 6. Start service
sudo systemctl start twiliosms

# 7. Verify
sudo systemctl status twiliosms
```

---

## ✅ VERIFICATION CHECKLIST

After deployment:

```
□ Service running (sudo systemctl status twiliosms)
□ No errors in logs (tail -30 twilio_sms.log)
□ Send test inbound message
□ Message shows "Pending Reply" (yellow badge)
□ Click "Reply" button
□ Send custom reply
□ Badge changes to "Custom Reply" (blue badge) ✓
□ Auto-Reply still sent to +15551234567
□ Test STOP message → Still auto-replies ✓
```

---

## 🔄 ROLLBACK PLAN

If issue occurs after deployment:

```bash
# 1. Stop service
sudo systemctl stop twiliosms

# 2. Restore backup
cd ~/TiwlioSMS
cp backups/twilio_sms.db.backup_YYYYMMDD_HHMMSS twilio_sms.db

# 3. Revert code
git log --oneline -5
git reset --hard PREVIOUS_COMMIT_HASH

# 4. Restart
sudo systemctl start twiliosms
```

---

## 📈 IMPACT ANALYSIS

### **Before Fix:**
- ❌ Admins confused about reply status
- ❌ Can't tell which messages were already replied to
- ❌ May send duplicate replies
- ❌ Poor UX

### **After Fix:**
- ✅ Clear visual indication of reply status
- ✅ Easy to identify pending vs. completed messages
- ✅ Prevents duplicate replies
- ✅ Better admin workflow

---

## 💡 LESSONS LEARNED

### **Why Bug Occurred:**
1. Initial implementation focused on `reply_sent` flag for backend
2. Didn't update `intent` column for frontend display
3. Missing in QA test coverage initially

### **Prevention for Future:**
1. ✅ Always update both backend flags AND frontend display columns
2. ✅ Test complete user workflow end-to-end
3. ✅ Add automated tests for intent changes
4. ✅ Document expected state transitions

---

## 📞 SUPPORT

**If Issues After Fix:**
1. Check logs: `sudo journalctl -u twiliosms -n 100`
2. Verify database: `sqlite3 twilio_sms.db "SELECT * FROM inbound_messages ORDER BY id DESC LIMIT 5;"`
3. Contact: GitHub Issues or support@gmadp.org

---

## ✅ SUMMARY

**Bug:** Intent stays "Pending Reply" after custom reply sent  
**Root Cause:** Missing `intent` column update in database query  
**Fix:** Update both `reply_sent` AND `intent` columns  
**Status:** ✅ Fixed and tested  
**Version:** 2.1.2 Hotfix  
**Ready:** ✅ Production deployment

---

**Bug Fixed By:** Development Team  
**Reported By:** QA Team  
**Date Fixed:** February 9, 2026  
**Git Commit:** (Will be added after commit)
