# OneSignal Testing - Visual Guide

## 🎯 Quick Test (5 minutes)

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: Run Flutter App                                     │
├─────────────────────────────────────────────────────────────┤
│ $ cd automotive_mobile                                      │
│ $ flutter run                                               │
│                                                              │
│ Expected: App launches on device/emulator                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: Log In as Admin                                     │
├─────────────────────────────────────────────────────────────┤
│ Email: [admin test account]                                 │
│ Password: [password]                                        │
│                                                              │
│ Console Output:                                             │
│ ✅ OneSignal login: [uid]                                   │
│                                                              │
│ Expected: Login successful, device registered               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: Open DSS Screen                                     │
├─────────────────────────────────────────────────────────────┤
│ Navigate to: Decision Support System                        │
│                                                              │
│ Console Output:                                             │
│ ✅ DSS alerts sent from AdminDSS screen                     │
│ 📤 OneSignal → 200: {...}                                   │
│                                                              │
│ Expected: Alerts generated and sent                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 4: Wait for Notification                              │
├─────────────────────────────────────────────────────────────┤
│ Wait: 5-10 seconds                                          │
│                                                              │
│ Expected: Notification appears on device                   │
│                                                              │
│ Device Screen:                                              │
│ ┌─────────────────────────────────────────┐                │
│ │ 🚨 URGENT: Out of Stock                 │                │
│ │ Item X is out of stock. Recommend...    │                │
│ └─────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 5: Verify in App                                       │
├─────────────────────────────────────────────────────────────┤
│ Open: Notifications screen                                  │
│                                                              │
│ Expected: Notification appears in list                      │
│                                                              │
│ App Screen:                                                 │
│ ┌─────────────────────────────────────────┐                │
│ │ 1 unread notification                   │                │
│ │                                         │                │
│ │ 🚨 URGENT: Out of Stock                 │                │
│ │ Item X is out of stock. Recommend...    │                │
│ │ Just now                                │                │
│ └─────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    ✅ TEST PASSED
```

---

## 🔍 Full Verification (15 minutes)

### Check 1: Device Registration

```
OneSignal Dashboard → Audience → Devices

Expected:
┌─────────────────────────────────────────┐
│ Device ID: [your-device-uid]            │
│ Status: Active                          │
│ Last Seen: Just now                     │
│ Platform: Android / iOS                 │
│ Subscribed: Yes                         │
└─────────────────────────────────────────┘
```

### Check 2: Message Delivery

```
OneSignal Dashboard → Messages

Expected:
┌─────────────────────────────────────────┐
│ Message: 🚨 URGENT: Out of Stock        │
│ Status: Delivered                       │
│ Sent: 1                                 │
│ Delivered: 1                            │
│ Failed: 0                               │
└─────────────────────────────────────────┘
```

### Check 3: Firestore Documents

```
Firebase Console → Firestore → /notifications

Expected:
┌─────────────────────────────────────────┐
│ Document ID: [auto-generated]           │
│ {                                       │
│   "title": "🚨 URGENT: Out of Stock",   │
│   "message": "Item X is out of stock...",
│   "type": "warning",                    │
│   "targetRole": "admin",                │
│   "createdAt": Timestamp(...)           │
│ }                                       │
└─────────────────────────────────────────┘
```

### Check 4: Console Logs

```
Expected Output:
✅ OneSignal auto-login with UID: [uid]
✅ OneSignal login: [uid]
✅ DSS alerts sent from AdminDSS screen
📤 OneSignal → 200: {"id":"[notification-id]",...}
```

---

## 🐛 Troubleshooting Flowchart

```
No notification on device?
│
├─ Check 1: Device Registered?
│  │
│  ├─ YES → Check 2
│  │
│  └─ NO → 
│     ├─ Console shows "✅ OneSignal login"?
│     │  ├─ NO → Check login.dart
│     │  └─ YES → Check OneSignal Dashboard
│     │
│     └─ Fix: Ensure OneSignal.login(uid) called
│
├─ Check 2: OneSignal API Called?
│  │
│  ├─ YES (200 response) → Check 3
│  │
│  └─ NO (error response) →
│     ├─ Check API Key
│     ├─ Check App ID
│     └─ Check OneSignal Dashboard for errors
│
├─ Check 3: Firestore Document Created?
│  │
│  ├─ YES → Check 4
│  │
│  └─ NO →
│     ├─ Check Firestore permissions
│     ├─ Check user role
│     └─ Check console for errors
│
└─ Check 4: Push Permissions on Device?
   │
   ├─ YES → Device should receive notification
   │
   └─ NO →
      ├─ Android: Settings → Apps → Caltex AutoPro → Notifications
      ├─ iOS: Settings → Notifications → Caltex AutoPro
      └─ Enable notifications
```

---

## 📊 Expected Alert Types

### Stock Alerts (Admin Only)

```
┌─────────────────────────────────────────┐
│ 🚨 URGENT: Out of Stock                 │
│ Item X is out of stock. Recommend       │
│ ordering Y units.                       │
│                                         │
│ Condition: stock == 0                   │
│ Recipients: All admins                  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ⚠️ Low Stock Alert                       │
│ Item X is low (5 units). Recommend      │
│ ordering Y units.                       │
│                                         │
│ Condition: stock <= min                 │
│ Recipients: All admins                  │
└─────────────────────────────────────────┘
```

### PMS Alerts (Admin + Vehicle Owner)

```
┌─────────────────────────────────────────┐
│ 🚨 PMS Overdue                          │
│ Vehicle ABC-1234 is 5 day(s) overdue    │
│ for maintenance.                        │
│                                         │
│ Condition: daysUntil < 0                │
│ Recipients: Admins + Vehicle Owner      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ⚠️ PMS Due Soon                         │
│ Vehicle ABC-1234 is due for             │
│ maintenance in 3 day(s).                │
│                                         │
│ Condition: daysUntil <= 7               │
│ Recipients: Admins + Vehicle Owner      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 📅 PMS Due This Week                    │
│ Vehicle ABC-1234 is due for             │
│ maintenance this week (10 days).        │
│                                         │
│ Condition: daysUntil <= 14              │
│ Recipients: Admins + Vehicle Owner      │
└─────────────────────────────────────────┘
```

---

## 🎬 Test Scenarios

### Scenario 1: Admin Receives Stock Alert

```
Setup:
  - Log in as admin
  - Open DSS screen
  - System finds item with stock == 0

Expected:
  1. Firestore document created
  2. OneSignal API called (200 response)
  3. Notification appears on device (5-10 sec)
  4. Notification appears in app list
  5. OneSignal Dashboard shows "Delivered"
```

### Scenario 2: Customer Receives PMS Alert

```
Setup:
  - Log in as customer
  - Customer owns vehicle ABC-1234
  - Vehicle is 3 days overdue for PMS

Expected:
  1. Admin opens DSS screen
  2. System detects overdue PMS
  3. Firestore document created with targetUid
  4. OneSignal API called with customer UID
  5. Customer receives notification
  6. Notification only visible to that customer
```

### Scenario 3: Multiple Alerts

```
Setup:
  - Log in as admin
  - Open DSS screen
  - System finds multiple issues:
    - 2 out of stock items
    - 3 overdue vehicles
    - 5 low stock items

Expected:
  1. 10 Firestore documents created
  2. 10 OneSignal API calls made
  3. Multiple notifications on device
  4. All appear in notification list
  5. OneSignal Dashboard shows 10 delivered
```

---

## ✅ Success Criteria

| Criterion | Status |
|-----------|--------|
| Device registers with OneSignal | ✅ |
| OneSignal API returns 200 | ✅ |
| Firestore documents created | ✅ |
| Notification appears on device | ✅ |
| Notification appears in app | ✅ |
| OneSignal Dashboard shows delivery | ✅ |
| Admin receives all alerts | ✅ |
| Customer receives only their alerts | ✅ |
| Alerts appear within 5-10 seconds | ✅ |

---

## 📝 Test Report Template

```
Test Date: _______________
Tester: ___________________
Device: ___________________
OS Version: _______________

Test Results:
[ ] Device registration successful
[ ] OneSignal API responding (200)
[ ] Firestore documents created
[ ] Notifications appear on device
[ ] Notifications appear in app
[ ] OneSignal Dashboard shows delivery
[ ] Admin alerts working
[ ] Customer alerts working
[ ] Alert latency < 10 seconds

Issues Found:
_________________________________
_________________________________
_________________________________

Notes:
_________________________________
_________________________________
_________________________________

Overall Status: [ ] PASS [ ] FAIL
```

---

## 🚀 Ready to Test!

All implementation is complete. Follow the quick test above to verify functionality.

**Expected Time**: 5-15 minutes  
**Success Rate**: Should be 100% if all steps followed  
**Support**: Check troubleshooting flowchart if issues arise

