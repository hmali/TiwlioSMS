# Auto-Reply Enhancement Guide

## 🚀 New Features in v2.1.0

The auto-reply system has been significantly enhanced with **subscriber management** and **intent-based responses**.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Subscriber Management](#subscriber-management)
3. [Intent Detection](#intent-detection)
4. [Flow Diagram](#flow-diagram)
5. [Database Changes](#database-changes)
6. [Configuration](#configuration)
7. [Testing](#testing)
8. [API Reference](#api-reference)

---

## 🎯 Overview

### What's New?

#### ✅ **Subscriber Management**
- Users can **opt-out** by sending STOP keywords
- Users can **opt-in** by sending START keywords
- Compliance with SMS regulations (TCPA, CTIA)
- Automatic tracking of subscription status

#### ✅ **Intent Detection**
- Smart keyword matching for common queries
- Custom replies based on user intent
- Default fallback for unmatched messages
- Easy to add new intents via database

#### ✅ **Enhanced Tracking**
- All messages tagged with detected intent
- Subscriber status visible in admin panel
- Better analytics and reporting

---

## 👥 Subscriber Management

### STOP Keywords (Opt-Out)

When a user sends any of these keywords, they are **unsubscribed**:

- `STOP`
- `STOPALL`
- `UNSUBSCRIBE`
- `CANCEL`
- `END`
- `QUIT`

**Response:**
```
You have been unsubscribed and will not receive further messages. Reply START to resubscribe.
```

**Database Action:**
- Status updated to `unsubscribed` in `subscribers` table
- `opted_out_at` timestamp recorded
- Message stored with intent `STOP`

### START Keywords (Opt-In)

When a user sends any of these keywords, they are **resubscribed**:

- `START`
- `YES`
- `UNSTOP`

**Response:**
```
You have been resubscribed! You will now receive messages. Jai Gajanan 🙏
```

**Database Action:**
- Status updated to `subscribed` in `subscribers` table
- `opted_in_at` timestamp recorded
- Message stored with intent `START`

### Behavior for Unsubscribed Users

**Option A (Disabled by default):** No reply sent

**Option B (Active):** One-time reminder
```
You are currently unsubscribed. Reply START to receive messages again.
```

To change this behavior, edit `app.py` line ~875:

```python
# Option A: No reply (uncomment to enable)
# logger.info(f"No reply sent to unsubscribed number {from_number}")
# return Response(str(MessagingResponse()), mimetype="text/xml")

# Option B: Reply once with resubscribe instructions (active)
reply_message = "You are currently unsubscribed. Reply START to receive messages again."
```

---

## 🧠 Intent Detection

### How It Works

1. **User sends message** → "Where is the event?"
2. **System normalizes** → "WHERE IS THE EVENT?"
3. **Checks keywords** → Matches "WHERE" in ADDRESS intent
4. **Sends custom reply** → Location details message

### Default Intents

#### 1. **RSVP Intent**
**Keywords:** `RSVP`, `YES`, `CONFIRM`, `ATTENDING`, `COUNT ME IN`

**Reply:**
```
Thank you for your RSVP! We have confirmed your attendance. Jai Gajanan 🙏
```

**Use Case:** Event confirmations

---

#### 2. **TIME Intent**
**Keywords:** `TIME`, `WHEN`, `SCHEDULE`, `TIMING`, `WHAT TIME`

**Reply:**
```
Event timing: Please check the original invitation for schedule details.
```

**Use Case:** Timing inquiries

---

#### 3. **ADDRESS Intent**
**Keywords:** `ADDRESS`, `WHERE`, `LOCATION`, `DIRECTIONS`, `HOW TO REACH`

**Reply:**
```
Location details: Please refer to the original invitation for address and directions.
```

**Use Case:** Location inquiries

---

#### 4. **SEVA Intent**
**Keywords:** `SEVA`, `VOLUNTEER`, `HELP`, `PARTICIPATE`, `SERVE`

**Reply:**
```
Thank you for offering seva! We will contact you with volunteer opportunities. Jai Gajanan 🙏
```

**Use Case:** Volunteer signups

---

#### 5. **DEFAULT Intent**
**When:** No keyword matches

**Reply:** Uses the default auto-reply message configured in Settings

---

### Adding Custom Intents

#### Via Database:

```sql
INSERT INTO auto_reply_intents (intent_name, keywords, reply_message, priority, is_active)
VALUES (
    'DONATION',  -- Intent name
    'DONATE,DONATION,CONTRIBUTE,GIVE',  -- Comma-separated keywords
    'Thank you for your interest in donating! Visit: https://example.com/donate',  -- Reply
    5,  -- Priority (lower = checked first)
    1   -- Active (1=yes, 0=no)
);
```

#### Via Python Script:

```python
import sqlite3

conn = sqlite3.connect('twilio_sms.db')
cursor = conn.cursor()

cursor.execute('''
    INSERT INTO auto_reply_intents (intent_name, keywords, reply_message, priority)
    VALUES (?, ?, ?, ?)
''', ('DONATION', 'DONATE,DONATION,CONTRIBUTE,GIVE', 
      'Thank you for your interest in donating! Visit: https://example.com/donate', 5))

conn.commit()
conn.close()
```

#### Updating Existing Intent:

```sql
UPDATE auto_reply_intents
SET reply_message = 'New reply message here'
WHERE intent_name = 'RSVP';
```

#### Deactivating Intent:

```sql
UPDATE auto_reply_intents
SET is_active = 0
WHERE intent_name = 'SEVA';
```

---

## 📊 Flow Diagram

```
User sends SMS: "Where is the event?"
      │
      ▼
Twilio receives inbound SMS
      │
      │ HTTP POST to webhook
      ▼
Flask /sms/inbound
      │
      ▼
Normalize input:
  from = "+1234567890"
  body = "Where is the event?"
  body_upper = "WHERE IS THE EVENT?"
      │
      ├──────────────────────────────────────────┐
      │                                          │
      ▼                                          ▼
Is STOP keyword?                          Is START keyword?
  STOP, STOPALL, etc.                       START, YES, UNSTOP
      │                                          │
      │ No                                       │ No
      ▼                                          ▼
      └──────────────────┬─────────────────────┘
                         │
                         ▼
              Check subscriber status
                         │
              ├──────────┴──────────┐
              │                     │
              ▼                     ▼
        Unsubscribed           Subscribed
              │                     │
              ▼                     ▼
      Send reminder          Detect intent
      (or no reply)                │
                            ┌──────┴──────┐
                            │             │
                            ▼             ▼
                    Keyword match?    No match
                            │             │
                            ▼             ▼
                    Custom reply    Default reply
                    (ADDRESS)       (Auto-reply)
                            │             │
                            └──────┬──────┘
                                   │
                                   ▼
                    Store message with intent
                                   │
                                   ▼
                    Return TwiML response
                                   │
                                   ▼
                         Twilio sends reply
                                   │
                                   ▼
                    User receives: "Location details:..."
```

---

## 💾 Database Changes

### New Tables

#### 1. **subscribers**
Tracks opt-in/opt-out status for phone numbers

```sql
CREATE TABLE subscribers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone_number TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'subscribed',
    opted_in_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    opted_out_at TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Example Data:**
```
| id | phone_number | status        | opted_in_at | opted_out_at | last_updated |
|----|--------------|---------------|-------------|--------------|--------------|
| 1  | +1234567890  | subscribed    | 2026-02-01  | NULL         | 2026-02-01   |
| 2  | +0987654321  | unsubscribed  | 2026-01-15  | 2026-02-01   | 2026-02-01   |
```

---

#### 2. **auto_reply_intents**
Stores custom intent definitions and replies

```sql
CREATE TABLE auto_reply_intents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    intent_name TEXT UNIQUE NOT NULL,
    keywords TEXT NOT NULL,
    reply_message TEXT NOT NULL,
    priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Example Data:**
```
| id | intent_name | keywords                  | reply_message          | priority | is_active |
|----|-------------|---------------------------|------------------------|----------|-----------|
| 1  | RSVP        | RSVP,YES,CONFIRM,ATTENDING| Thank you for RSVP...  | 1        | 1         |
| 2  | TIME        | TIME,WHEN,SCHEDULE        | Event timing: ...      | 2        | 1         |
| 3  | ADDRESS     | ADDRESS,WHERE,LOCATION    | Location details: ...  | 3        | 1         |
```

---

### Modified Tables

#### **inbound_messages** - Added `intent` column

```sql
ALTER TABLE inbound_messages ADD COLUMN intent TEXT;
```

**Updated Schema:**
```
| id | from_number | to_number | message_body | message_sid | reply_sent | received_at | intent  |
|----|-------------|-----------|--------------|-------------|------------|-------------|---------|
| 1  | +1234567890 | +1555...  | STOP         | SM123...    | 1          | 10:30:00    | STOP    |
| 2  | +0987654321 | +1555...  | Where?       | SM124...    | 1          | 10:31:00    | ADDRESS |
| 3  | +1122334455 | +1555...  | Hello        | SM125...    | 1          | 10:32:00    | DEFAULT |
```

---

## ⚙️ Configuration

### 1. **Configure Default Auto-Reply**

Web Interface:
1. Login to dashboard
2. Go to **Settings → Auto-Reply**
3. Update default message
4. Click **Save**

This message is used when no intent matches.

---

### 2. **Manage Intents**

Direct database access (for now):

```bash
sqlite3 twilio_sms.db
```

```sql
-- View all intents
SELECT * FROM auto_reply_intents ORDER BY priority;

-- Add new intent
INSERT INTO auto_reply_intents (intent_name, keywords, reply_message, priority)
VALUES ('PARKING', 'PARKING,PARK,CAR', 'Parking available at venue. Free parking.', 5);

-- Update intent
UPDATE auto_reply_intents
SET reply_message = 'New message'
WHERE intent_name = 'PARKING';

-- Deactivate intent
UPDATE auto_reply_intents
SET is_active = 0
WHERE intent_name = 'PARKING';

-- Delete intent
DELETE FROM auto_reply_intents WHERE intent_name = 'PARKING';
```

---

### 3. **View Subscriber Status**

```sql
-- View all subscribers
SELECT * FROM subscribers ORDER BY last_updated DESC;

-- Find unsubscribed users
SELECT * FROM subscribers WHERE status = 'unsubscribed';

-- Manually unsubscribe a number
INSERT INTO subscribers (phone_number, status, opted_out_at)
VALUES ('+1234567890', 'unsubscribed', CURRENT_TIMESTAMP);

-- Manually resubscribe a number
UPDATE subscribers
SET status = 'subscribed', opted_in_at = CURRENT_TIMESTAMP
WHERE phone_number = '+1234567890';
```

---

## 🧪 Testing

### Test STOP/START Flow

#### Test 1: Opt-Out
```
Send SMS to your Twilio number:
Message: STOP

Expected Response:
"You have been unsubscribed and will not receive further messages. Reply START to resubscribe."

Verify in database:
SELECT * FROM subscribers WHERE phone_number = '+YOUR_NUMBER';
-- Should show status = 'unsubscribed'
```

#### Test 2: Opt-In
```
Send SMS to your Twilio number:
Message: START

Expected Response:
"You have been resubscribed! You will now receive messages. Jai Gajanan 🙏"

Verify in database:
SELECT * FROM subscribers WHERE phone_number = '+YOUR_NUMBER';
-- Should show status = 'subscribed'
```

---

### Test Intent Detection

#### Test 3: RSVP Intent
```
Send SMS: "RSVP yes"

Expected Response:
"Thank you for your RSVP! We have confirmed your attendance. Jai Gajanan 🙏"

Verify:
SELECT * FROM inbound_messages ORDER BY received_at DESC LIMIT 1;
-- intent column should be 'RSVP'
```

#### Test 4: ADDRESS Intent
```
Send SMS: "Where is the location?"

Expected Response:
"Location details: Please refer to the original invitation for address and directions."

Verify intent = 'ADDRESS'
```

#### Test 5: DEFAULT Intent
```
Send SMS: "Random message abc123"

Expected Response:
Your configured default auto-reply message

Verify intent = 'DEFAULT'
```

---

### Test Unsubscribed User

#### Test 6: Message from Unsubscribed User
```
1. First unsubscribe: Send "STOP"
2. Then send: "Hello"

Expected Response:
"You are currently unsubscribed. Reply START to receive messages again."

Verify intent = 'UNSUBSCRIBED'
```

---

### Check Logs

```bash
tail -f twilio_sms.log | grep "Inbound SMS"
```

Expected log entries:
```
2026-02-02 10:30:00 - INFO - Inbound SMS: From=+1234567890 To=+1555... SID=SM123... Body=STOP
2026-02-02 10:30:00 - INFO - Subscriber +1234567890 unsubscribed via STOP
2026-02-02 10:31:00 - INFO - Inbound SMS: From=+0987654321 To=+1555... SID=SM124... Body=Where?
2026-02-02 10:31:00 - INFO - Intent detected: ADDRESS (keyword: WHERE)
2026-02-02 10:31:00 - INFO - Intent-based reply sent to +0987654321: ADDRESS
```

---

## 📚 API Reference

### Helper Functions

#### `get_subscriber_status(phone_number)`
Returns subscriber status for a phone number.

```python
status = get_subscriber_status('+1234567890')
# Returns: 'subscribed' or 'unsubscribed'
# Default: 'subscribed' if not in database
```

---

#### `update_subscriber_status(phone_number, status)`
Updates subscriber opt-in/opt-out status.

```python
success = update_subscriber_status('+1234567890', 'unsubscribed')
# Returns: True on success, False on error
```

---

#### `detect_intent(message_body)`
Detects intent from message body using keyword matching.

```python
intent_name, reply_message = detect_intent("Where is the event?")
# Returns: ('ADDRESS', 'Location details: ...')
# Or: (None, None) if no match
```

---

#### `store_inbound_message(from_number, to_number, body, msg_sid, intent=None)`
Stores inbound message in database with intent.

```python
success = store_inbound_message(
    from_number='+1234567890',
    to_number='+1555000000',
    body='Where is the event?',
    msg_sid='SM123456',
    intent='ADDRESS'
)
# Returns: True on success, False on error
```

---

## 🔄 Migration

### Upgrade Existing Database

Run the migration script:

```bash
cd /path/to/TiwlioSMS
python3 scripts/migrate_db_v2.py
```

**What it does:**
1. Creates backup: `twilio_sms.db.backup_v2_1_0`
2. Adds `intent` column to `inbound_messages`
3. Creates `subscribers` table
4. Creates `auto_reply_intents` table
5. Initializes default intents
6. Creates performance indexes

**Safe to run:** Multiple times (idempotent)

---

## 🎯 Best Practices

### 1. **Keep Keywords Simple**
- Use common words people actually type
- Include variations (WHERE, LOCATION, ADDRESS)
- Make them case-insensitive (handled automatically)

### 2. **Test Thoroughly**
- Test all STOP/START variations
- Test each intent with different keywords
- Test default fallback

### 3. **Monitor Intent Analytics**
```sql
-- See which intents are most common
SELECT intent, COUNT(*) as count
FROM inbound_messages
WHERE received_at > datetime('now', '-30 days')
GROUP BY intent
ORDER BY count DESC;
```

### 4. **Update Replies Regularly**
- Keep messages current (dates, locations, etc.)
- A/B test different responses
- Add seasonal intents

### 5. **Comply with Regulations**
- Honor STOP requests immediately
- Include opt-out info in campaigns
- Keep records of consent

---

## 🐛 Troubleshooting

### Issue: Intent not detecting

**Check:**
1. Keyword exists in database
2. Intent is active (`is_active = 1`)
3. Keyword matches message (case-insensitive)

```sql
SELECT * FROM auto_reply_intents WHERE is_active = 1;
```

---

### Issue: Subscriber status not updating

**Check logs:**
```bash
grep "Subscriber.*status updated" twilio_sms.log
```

**Verify database:**
```sql
SELECT * FROM subscribers WHERE phone_number = '+YOUR_NUMBER';
```

---

### Issue: Wrong reply sent

**Check priority:**
- Lower priority checked first
- First matching intent wins

```sql
SELECT intent_name, keywords, priority
FROM auto_reply_intents
WHERE is_active = 1
ORDER BY priority;
```

---

## 📈 Future Enhancements

Potential additions for v2.2.0:

- [ ] Web UI for managing intents
- [ ] Regex pattern matching (not just keywords)
- [ ] Machine learning intent classification
- [ ] Multi-language support
- [ ] Intent analytics dashboard
- [ ] A/B testing framework
- [ ] Scheduled auto-replies
- [ ] Drip campaigns for subscribers

---

## 📞 Support

**Questions?** Check:
- Main README.md
- DEVELOPER_GUIDE.md
- Application logs: `twilio_sms.log`

**Found a bug?** Please report with:
- Steps to reproduce
- Expected vs actual behavior
- Relevant log entries

---

**Version:** 2.1.0  
**Last Updated:** February 2, 2026  
**Status:** Production Ready ✅
