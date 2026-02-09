# 🔧 v2.1.2 Hotfix - Auto-Reply Behavior Change

**Date:** February 9, 2026  
**Version:** 2.1.2 Hotfix  
**Issue:** Unwanted default auto-reply messages sent to users

---

## 🎯 WHAT CHANGED

### **Previous Behavior (v2.1.1):**
When someone sends an inbound message that is NOT a STOP, START, or recognized intent (like RSVP, TIME, etc.), the system would automatically send a **default auto-reply message**.

**Example:**
```
User sends: "Hello, I have a question"
System auto-replies: "Thank you for your message. We will get back to you soon."
```

### **New Behavior (v2.1.2):**
When someone sends an inbound message that is NOT a STOP, START, or recognized intent, the system **does NOT send any automatic reply**. The message is marked as "Pending Reply" and **only the admin can send a custom 1:1 reply**.

**Example:**
```
User sends: "Hello, I have a question"
System: (No automatic reply sent)
Admin: (Can manually send custom reply via dashboard)
```

---

## 📋 AUTO-REPLY LOGIC NOW

### **Messages That Still Get Automatic Replies:**
1. ✅ **STOP keywords** → "You have been unsubscribed..."
2. ✅ **START keywords** → "You have been resubscribed..."
3. ✅ **Unsubscribed users** → "You are currently unsubscribed..."
4. ✅ **Recognized intents** (RSVP, TIME, ADDRESS, SEVA) → Custom intent response

### **Messages That Do NOT Get Automatic Replies:**
❌ **All other messages** → Marked as "Pending Reply", admin must respond manually

---

## 🔄 CHANGES MADE

### **1. Updated `/sms/inbound` Route (app.py)**

**Before:**
```python
else:
    # STEP 5: Send default auto-reply message
    intent_detected = 'DEFAULT'
    reply_message = get_auto_reply_message()
    resp.message(reply_message)
    logger.info(f"💬 Default auto-reply sent to {from_number}")
```

**After:**
```python
else:
    # STEP 5: No automatic reply - wait for admin to send custom 1:1 reply
    intent_detected = 'PENDING_REPLY'
    reply_message = None  # No auto-reply sent
    logger.info(f"📥 Message received from {from_number} - No auto-reply (waiting for custom reply)")
```

### **2. Updated Inbound Messages Template**

Added new badge for "Pending Reply" status:
```html
{% elif msg[6] == 'PENDING_REPLY' %}
    <span class="badge bg-warning"><i class="fas fa-clock"></i> Pending Reply</span>
```

### **3. Created Migration Script**

**File:** `scripts/update_intent_pending.py`
- Updates all existing `DEFAULT` messages to `PENDING_REPLY`
- Safe to run multiple times
- Automatic execution during upgrade

---

## 🚀 HOW TO UPGRADE

### **Option 1: Automatic (Recommended)**
```bash
# Use the upgrade script (includes migration)
cd ~/TiwlioSMS
./upgrade_production.sh
```

### **Option 2: Manual**
```bash
# 1. Stop service
sudo systemctl stop twiliosms

# 2. Pull latest code
cd ~/TiwlioSMS
git pull origin dev/twilioms-test

# 3. Run migration
source venv/bin/activate
python3 scripts/update_intent_pending.py

# 4. Start service
sudo systemctl start twiliosms
```

---

## 📊 WHAT YOU'LL SEE

### **In Inbound Messages Dashboard:**

**Before (v2.1.1):**
```
┌────────────────────────────────────────────────────┐
│ Message: "Need directions"                        │
│ Intent: [Default]  (gray badge)                   │
│ Auto-Reply: ✓ Sent                                │
└────────────────────────────────────────────────────┘
```

**After (v2.1.2):**
```
┌────────────────────────────────────────────────────┐
│ Message: "Need directions"                        │
│ Intent: [Pending Reply]  (yellow/orange badge)   │
│ Auto-Reply: ✗ Not Sent                            │
│ [Reply] button ← Admin can send custom reply     │
└────────────────────────────────────────────────────┘
```

---

## 🎯 USE CASES

### **Scenario 1: General Question**
```
User: "What time is the event?"
System: (No auto-reply)
Admin: Sees message in dashboard
Admin: Clicks "Reply" → Types custom response
Admin: "Event starts at 6 PM. See you there! 🙏"
```

### **Scenario 2: STOP Request (Still Auto-Replies)**
```
User: "STOP"
System: (Automatic reply) "You have been unsubscribed..."
Admin: Sees in dashboard with STOP badge
```

### **Scenario 3: RSVP Intent (Still Auto-Replies)**
```
User: "YES to Diwali celebration"
System: (Automatic reply based on RSVP intent)
Admin: Can still send additional custom reply if needed
```

---

## ✅ BENEFITS

### **Why This Change?**
1. ✅ **No spam** - Users don't get generic auto-replies
2. ✅ **Personal touch** - Admin sends thoughtful, contextual responses
3. ✅ **Better engagement** - Real conversations instead of automated responses
4. ✅ **Compliance** - Only send messages when there's real value
5. ✅ **Flexibility** - Admin chooses what/when to reply

---

## 🔍 VERIFICATION

After upgrade, verify the change:

### **1. Check Code Update:**
```bash
cd ~/TiwlioSMS
grep -n "PENDING_REPLY" app.py
# Should show line with: intent_detected = 'PENDING_REPLY'
```

### **2. Check Migration:**
```bash
sqlite3 twilio_sms.db "SELECT COUNT(*) FROM inbound_messages WHERE intent = 'PENDING_REPLY';"
# Should show count of updated messages
```

### **3. Test New Behavior:**
1. Send test SMS to your Twilio number: "Test message"
2. Check your phone - should NOT receive auto-reply ✓
3. Login to dashboard → Inbound Messages
4. See message with yellow "Pending Reply" badge ✓
5. Click "Reply" button → Send custom response ✓
6. Check phone - receive your custom reply ✓

### **4. Verify Auto-Replies Still Work:**
1. Send SMS: "STOP"
2. Should receive: "You have been unsubscribed..." ✓
3. Send SMS: "START"
4. Should receive: "You have been resubscribed..." ✓

---

## 🐛 TROUBLESHOOTING

### **Problem: Still seeing DEFAULT messages**
```bash
# Run migration manually
cd ~/TiwlioSMS
source venv/bin/activate
python3 scripts/update_intent_pending.py
sudo systemctl restart twiliosms
```

### **Problem: Auto-reply still being sent**
```bash
# Verify code updated
cd ~/TiwlioSMS
git log --oneline -5
# Should show recent commit with "auto-reply" change

# Force pull if needed
git pull origin dev/twilioms-test
sudo systemctl restart twiliosms
```

### **Problem: Badge not showing correctly**
```bash
# Clear browser cache
Ctrl+Shift+R (hard refresh)

# Or restart service
sudo systemctl restart twiliosms
```

---

## 📝 TECHNICAL DETAILS

### **Files Modified:**
1. **app.py** (lines ~926-930)
   - Changed: `intent_detected = 'DEFAULT'` → `'PENDING_REPLY'`
   - Removed: `resp.message(reply_message)` for default case

2. **templates/inbound_messages.html** (lines ~48-52)
   - Added: `PENDING_REPLY` badge condition

3. **upgrade_production.sh** (lines ~268-281)
   - Added: Intent update migration execution

4. **scripts/update_intent_pending.py** (NEW)
   - Migrates existing DEFAULT to PENDING_REPLY

### **Database Changes:**
```sql
-- Migration updates intent column
UPDATE inbound_messages 
SET intent = 'PENDING_REPLY' 
WHERE intent = 'DEFAULT';
```

---

## 📞 SUPPORT

**Documentation:**
- This file: `CHANGELOG_v2.1.2.md`
- Upgrade guide: `HOW_TO_UPGRADE.md`
- Feature docs: `CUSTOM_REPLY_FEATURE.md`

**Issues:**
- GitHub: https://github.com/hmali/TiwlioSMS/issues
- Check logs: `sudo journalctl -u twiliosms -n 100`

---

## ✅ SUMMARY

### **What's Different:**
- ❌ No more automatic default replies for regular messages
- ✅ Messages marked as "Pending Reply" (yellow badge)
- ✅ Admin manually sends custom 1:1 replies
- ✅ STOP/START/intents still auto-reply (unchanged)

### **How to Upgrade:**
```bash
cd ~/TiwlioSMS
./upgrade_production.sh
```

### **Migration Included:**
- ✅ Automatic update of existing DEFAULT messages
- ✅ Safe, reversible, tested

---

**Version:** 2.1.2 Hotfix  
**Date:** February 9, 2026  
**Status:** ✅ Ready for Production  
**Breaking Changes:** No (backward compatible)
