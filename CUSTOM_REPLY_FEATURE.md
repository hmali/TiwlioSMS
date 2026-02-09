# 📱 Custom 1:1 Reply Feature - Complete Guide

**Status:** ✅ **PRODUCTION READY** (Implemented in v2.1.1)  
**Date:** February 9, 2026

---

## 🎯 Feature Overview

Allows admins to send personalized 1:1 SMS replies to individual inbound messages, enabling ongoing conversations beyond automated responses.

---

## 🚀 How to Use

### **1. Access Inbound Messages**
- Login to admin dashboard
- Navigate to **"Inbound Messages"** (top menu)

### **2. View All Messages**
You'll see a table with:
- Date/Time received
- From Number (sender's phone)
- To Number (your Twilio number)
- Message content
- Intent detected (STOP, START, RSVP, etc.)
- Auto-Reply status
- **Actions column with "Reply" button**

### **3. Send Custom Reply**
1. Click **"Reply"** button next to any message
2. Form expands showing:
   - **Original message** in gray box
   - **Text area** for your custom response
   - **Character counter** (max 1600)
3. Type your personalized message
4. Click **"Send Custom Reply"**
5. Success message appears: *"✅ Custom reply sent successfully!"*

---

## 📊 Use Cases

### **Example 1: RSVP Confirmation**
**Inbound:** *"YES attending Ganesh festival on Saturday"*  
**Custom Reply:** *"Great! We've reserved your spot. Arrive by 5 PM. Bring family! 🙏"*

### **Example 2: Directions Request**
**Inbound:** *"Need directions to temple"*  
**Custom Reply:** *"Temple address: 123 Main St, City, NJ 07001. GPS: 40.7128,-74.0060. Parking available."*

### **Example 3: Seva Inquiry**
**Inbound:** *"Want to volunteer for food seva"*  
**Custom Reply:** *"Thank you! Food seva is Sunday 9 AM. Contact Rajesh at +1-555-0100 to coordinate."*

### **Example 4: Follow-up Question**
**Inbound:** *"What time does the event start?"*  
**Custom Reply:** *"Event starts at 6 PM with aarti. Dinner at 7:30 PM. See you there!"*

---

## 🛠️ Technical Details

### **Backend Route**
- **Endpoint:** `POST /send-custom-reply/<message_id>`
- **Authentication:** Login required
- **Location:** Lines 986-1063 in `app.py`

### **Frontend Template**
- **File:** `templates/inbound_messages.html`
- **Features:**
  - Collapsible reply forms
  - Character counter with color warnings
  - Real-time validation
  - Bootstrap 5 styling

### **Database Tables Used**
```sql
-- Tracks custom replies sent
message_status (campaign_id, phone_number, message_sid, status, sent_at)

-- Marks inbound message as replied
inbound_messages (id, reply_sent)
```

### **Character Limits**
- **Maximum:** 1600 characters
- **Warning (Yellow):** > 1200 characters
- **Alert (Red):** > 1500 characters
- **Why 1600?** Allows for long messages that may be split by Twilio

---

## 🔒 Security Features

✅ **Authentication Required:** Only logged-in admins can send replies  
✅ **Input Validation:** Form validation prevents empty messages  
✅ **Error Handling:** Graceful handling of Twilio API errors  
✅ **Audit Trail:** All custom replies logged in database  
✅ **Rate Limiting:** Controlled by Twilio account limits  

---

## 📈 Tracking & Analytics

### **What's Logged:**
1. **Message SID** - Unique Twilio message identifier
2. **Recipient Phone Number** - Who received the reply
3. **Timestamp** - When reply was sent
4. **Status** - 'sent', 'delivered', 'failed'
5. **Reply Flag** - `reply_sent = 1` on original inbound message

### **View Logs:**
```bash
# Application logs
tail -f ~/TiwlioSMS/twilio_sms.log | grep "Custom reply"

# Database query
sqlite3 twilio_sms.db "SELECT * FROM message_status WHERE campaign_id IS NULL ORDER BY sent_at DESC LIMIT 10;"
```

---

## 🧪 Testing the Feature

### **Test Scenario 1: Simple Reply**
1. Send test SMS to your Twilio number: *"Hello, I have a question"*
2. Message appears in Inbound Messages dashboard
3. Click "Reply" button
4. Type: *"Hi! How can I help you today?"*
5. Click "Send Custom Reply"
6. Verify SMS received on test phone

### **Test Scenario 2: Long Message**
1. Send test SMS: *"Need more information"*
2. Click "Reply"
3. Type a 1400+ character response
4. Watch character counter turn yellow/red
5. Send and verify delivery

### **Test Scenario 3: Error Handling**
1. Temporarily remove Twilio credentials (Settings)
2. Try sending a reply
3. Verify error message: *"Twilio credentials not configured"*
4. Re-add credentials and retry successfully

---

## 🐛 Troubleshooting

### **Issue: "Twilio credentials not configured"**
**Solution:**
1. Go to Settings → Twilio Credentials
2. Enter Account SID, Auth Token, Phone Number
3. Click "Save Changes"
4. Retry sending reply

### **Issue: Reply not received**
**Check:**
1. Twilio account balance (funds available?)
2. Recipient's phone number format (+1234567890)
3. Twilio phone number is active and SMS-enabled
4. Check Twilio console for message status

### **Issue: Character counter not working**
**Solution:**
- Refresh browser page (Ctrl+F5)
- Clear browser cache
- Verify JavaScript is enabled

---

## 🔄 Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Inbound SMS Received                                       │
│  "Need directions to temple"                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Stored in Database                                         │
│  - Phone number: +1234567890                                │
│  - Message: "Need directions to temple"                     │
│  - Intent: DEFAULT                                          │
│  - Auto-reply: Sent (generic response)                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Admin Views in Dashboard                                   │
│  - Sees message in Inbound Messages table                   │
│  - Clicks "Reply" button                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Reply Form Opens                                           │
│  - Shows original message                                   │
│  - Text area for custom reply                               │
│  - Character counter                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Admin Types Custom Response                                │
│  "Temple: 123 Main St, GPS: 40.7128,-74.0060"               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Form Submits to /send-custom-reply/42                      │
│  - Validates message not empty                              │
│  - Retrieves recipient phone number                         │
│  - Gets Twilio credentials                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Twilio API Call                                            │
│  - From: Your Twilio number                                 │
│  - To: +1234567890                                          │
│  - Body: Custom reply text                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Database Updated                                           │
│  - message_status: New record with SID                      │
│  - inbound_messages: reply_sent = 1                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Success Message Displayed                                  │
│  "✅ Custom reply sent successfully to +1234567890!"        │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  SMS Delivered to Recipient                                 │
│  Recipient receives personalized response                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 Code References

### **Backend Implementation**
**File:** `app.py` (Lines 986-1063)
```python
@app.route('/send-custom-reply/<int:message_id>', methods=['POST'])
@login_required
def send_custom_reply(message_id):
    """Send custom reply to an inbound message (1:1 conversation)"""
    # ... implementation ...
```

### **Frontend Implementation**
**File:** `templates/inbound_messages.html` (Lines 70-115)
```html
<button class="btn btn-sm btn-primary" data-bs-toggle="collapse">
    <i class="fas fa-reply"></i> Reply
</button>
<form method="POST" action="{{ url_for('send_custom_reply', message_id=msg[0]) }}">
    <!-- Reply form with character counter -->
</form>
```

---

## 🎓 Best Practices

### **DO:**
✅ Keep messages professional and clear  
✅ Personalize responses based on context  
✅ Include specific details (times, addresses, contacts)  
✅ Use emojis sparingly for warmth (🙏 ✨ 📍)  
✅ Proofread before sending  

### **DON'T:**
❌ Send generic auto-reply style messages  
❌ Include sensitive information (passwords, SSNs)  
❌ Use ALL CAPS (seems aggressive)  
❌ Send excessively long messages (>160 chars may split)  
❌ Reply to STOP messages (illegal per TCPA)  

---

## 🔮 Future Enhancements (Optional)

1. **Message Templates:** Pre-saved reply templates
2. **Bulk Reply:** Send same custom reply to multiple recipients
3. **Scheduled Replies:** Send at specific time
4. **Conversation History:** View full SMS thread per person
5. **Rich Media:** MMS support with images
6. **AI Suggestions:** Auto-suggest replies based on intent

---

## 📞 Support

**Issue Tracking:**
- GitHub: https://github.com/hmali/TiwlioSMS/issues
- Email: support@gmadp.org

**Twilio Support:**
- Console: https://console.twilio.com
- Docs: https://www.twilio.com/docs/sms

---

**Feature Status:** ✅ **PRODUCTION READY**  
**Version:** v2.1.1 Hotfix  
**Last Updated:** February 9, 2026  
**Tested:** ✅ Fully Functional
