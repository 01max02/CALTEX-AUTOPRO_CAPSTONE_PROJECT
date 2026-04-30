# OneSignal Push Notifications - Quick Reference Card

## 🚀 Quick Start

### 1. Upgrade Firebase to Blaze
```
https://console.firebase.google.com/project/caltex-autopro-1e664/usage/details
→ Click "Upgrade to Blaze"
```

### 2. Deploy Cloud Functions
```bash
cd automotive_mobile
firebase deploy --only functions
```

### 3. Test Notification
Create document in Firestore `/notifications`:
```json
{
  "title": "Test",
  "message": "Hello World",
  "type": "info",
  "targetRole": "admin",
  "targetUid": "",
  "createdAt": (server timestamp)
}
```

---

## 📱 OneSignal Credentials

| Item | Value |
|------|-------|
| **App ID** | `c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea` |
| **REST API Key** | `os_v7_app_yt4cvr2f1hkhvh5ldu4k637i51snjeyuythen3fd61ae1yhnprpy6kbxvn9kjd1pqdhygsqmlrouas4kfuydft32nkgj5flbra3oo5q` |
| **Dashboard** | https://dashboard.onesignal.com/ |

---

## 📋 Notification Schema

```json
{
  "title": "Notification Title",
  "message": "Notification Body",
  "type": "info|warning|success",
  "targetRole": "admin|staff|customer|''",
  "targetUid": "user-id|''",
  "createdAt": (server timestamp)
}
```

---

## 🎯 Notification Types

| Type | Use Case | Icon |
|------|----------|------|
| **info** | General information | ℹ️ |
| **warning** | Alerts, stock low, PMS due | ⚠️ |
| **success** | Confirmations, completed | ✅ |

---

## 👥 Target Options

| Option | Example | Result |
|--------|---------|--------|
| **targetRole** | `"admin"` | All admins |
| **targetRole** | `"staff"` | All staff |
| **targetRole** | `"customer"` | All customers |
| **targetUid** | `"user-123"` | Specific user |
| **Both empty** | `""` | All users |

---

## 🔄 Cloud Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| **sendNotifications** | Document created in `/notifications` | Auto-send notifications |
| **checkDSSAlerts** | Every 1 hour | Check stock & PMS |
| **sendPushNotification** | Called from app | Manual notification |

---

## 📊 DSS Alerts

### Stock Alerts
- **Out of Stock:** stock = 0
- **Low Stock:** stock ≤ minimum
- **Sent to:** All admins

### PMS Alerts
- **Overdue:** Past due date
- **Due Soon:** Within 7 days
- **Due This Week:** Within 14 days
- **Sent to:** Admins (all vehicles) + Customers (their vehicles)

---

## 🧪 Quick Tests

### Test 1: Manual Notification
1. Create document in `/notifications`
2. Check device within 5-10 seconds
3. Verify in OneSignal Dashboard

### Test 2: Specific User
1. Set `targetUid` to user ID
2. Only that user receives it

### Test 3: All Admins
1. Set `targetRole` to `"admin"`
2. All admins receive it

### Test 4: DSS Alerts
1. Wait for hourly run (or manually trigger)
2. Check for stock/PMS alerts

---

## 🔍 Monitoring

### Cloud Functions Logs
```
Firebase Console → Functions → Logs
```
Look for: "Notifications sent to X users via OneSignal"

### OneSignal Dashboard
```
https://dashboard.onesignal.com/ → Messages
```
Check: Delivery status, engagement

### Firestore
```
Firebase Console → Firestore → notifications
```
Check: Documents created, fields present

---

## ❌ Troubleshooting

| Problem | Solution |
|---------|----------|
| Notifications not appearing | Check device permissions, user logged in |
| Cloud Functions won't deploy | Firebase must be on Blaze plan |
| No delivery in OneSignal | Check REST API Key, user IDs correct |
| Notifications appear but no content | Check title/message fields not empty |
| Function errors in logs | Check Firestore query syntax, user roles |

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `automotive_mobile/lib/notifications.dart` | Flutter app integration |
| `automotive_mobile/functions/index.js` | Cloud Functions |
| `automotive_mobile/pubspec.yaml` | Flutter dependencies |
| `automotive_mobile/functions/package.json` | Node.js dependencies |

---

## 🎓 Documentation

| Document | Content |
|----------|---------|
| `ONESIGNAL_DEPLOYMENT_READY.md` | Deployment guide |
| `QUICK_TEST_GUIDE.md` | Testing procedures |
| `ONESIGNAL_SYSTEM_ARCHITECTURE.md` | System design |
| `IMPLEMENTATION_SUMMARY.md` | What was done |
| `QUICK_REFERENCE.md` | This file |

---

## ✅ Deployment Checklist

- [ ] Firebase upgraded to Blaze
- [ ] Cloud Functions deployed
- [ ] Test 1: Manual notification
- [ ] Test 2: Specific user
- [ ] Test 3: All admins
- [ ] Test 4: DSS alerts
- [ ] Logs reviewed
- [ ] OneSignal Dashboard checked

---

## 🚨 Important Notes

1. **Firebase must be on Blaze plan** - Required for Cloud Functions
2. **OneSignal login required** - User must be logged in with Firebase UID
3. **Notification permissions** - Device must allow notifications
4. **Firestore document required** - All fields must be present
5. **DSS alerts run hourly** - Automatic, no manual trigger needed

---

## 📞 Quick Links

- **Firebase Console:** https://console.firebase.google.com/
- **OneSignal Dashboard:** https://dashboard.onesignal.com/
- **OneSignal Docs:** https://documentation.onesignal.com/
- **Firebase Functions Docs:** https://firebase.google.com/docs/functions

---

## 🎯 Next Steps

1. Upgrade Firebase to Blaze
2. Deploy Cloud Functions
3. Run Test 1 (manual notification)
4. Monitor logs and dashboard
5. Run remaining tests

**See `ONESIGNAL_DEPLOYMENT_READY.md` for detailed instructions.**

