# OneSignal Integration - Deployment Ready ✅

## Status: READY FOR DEPLOYMENT

All code has been updated and dependencies installed. The system is ready to deploy once Firebase project is upgraded.

---

## What Was Completed

### 1. ✅ Flutter App (`automotive_mobile/lib/notifications.dart`)
- OneSignal initialization with App ID: `c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea`
- Foreground notification handling
- Notification click listeners
- DSS alerts generation based on real data
- Notification UI with role-based filtering

### 2. ✅ Cloud Functions (`automotive_mobile/functions/index.js`)
- **sendNotifications** trigger: Automatically sends notifications when documents are created in `/notifications` collection
- **sendPushNotification** callable: Sends notifications to specific users via OneSignal API
- **checkDSSAlerts** scheduled function: Runs every hour to check stock and PMS alerts
- All functions now use OneSignal HTTP API instead of Firebase Messaging

### 3. ✅ Dependencies
- `flutter pub get` - Downloaded onesignal_flutter package ✅
- `npm install` - Installed axios for OneSignal API calls ✅

---

## Next Steps to Complete Deployment

### Step 1: Upgrade Firebase Project to Blaze Plan
Your Firebase project `caltex-autopro-1e664` is currently on the Spark (free) plan. Cloud Functions require the Blaze (pay-as-you-go) plan.

**To upgrade:**
1. Go to: https://console.firebase.google.com/project/caltex-autopro-1e664/usage/details
2. Click "Upgrade to Blaze"
3. Follow the payment setup process
4. Wait for the upgrade to complete (usually 5-10 minutes)

### Step 2: Deploy Cloud Functions
Once the project is upgraded to Blaze, run:

```bash
cd automotive_mobile
firebase deploy --only functions
```

This will deploy:
- `sendNotifications` - Trigger on notification document creation
- `sendPushNotification` - Callable function for manual notifications
- `checkDSSAlerts` - Scheduled function (runs every hour)
- `deleteUser` - Existing user deletion function
- `setupNotificationsCollection` - Initialize notifications collection

### Step 3: Test the Integration

#### Test 1: Manual Notification via Firestore
1. Open Firebase Console → Firestore
2. Create a new document in `/notifications` collection with:
   ```json
   {
     "title": "Test Notification",
     "message": "This is a test notification",
     "type": "info",
     "targetRole": "admin",
     "targetUid": "",
     "createdAt": (server timestamp)
   }
   ```
3. Check your mobile device - notification should appear within seconds

#### Test 2: DSS Alerts (Automatic)
The `checkDSSAlerts` function runs automatically every hour. It will:
- Check stock levels and send alerts for out-of-stock or low-stock items
- Check PMS schedules and send alerts for overdue or upcoming maintenance
- Send notifications to admins and customers via OneSignal

#### Test 3: Manual Push via App
In your Flutter app, call:
```dart
await sendPushNotification(
  userId: 'user-id',
  title: 'Test Title',
  body: 'Test Body',
  type: 'info',
);
```

---

## OneSignal Configuration

**App ID:** `c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea`

**REST API Key:** `os_v7_app_yt4cvr2f1hkhvh5ldu4k637i51snjeyuythen3fd61ae1yhnprpy6kbxvn9kjd1pqdhygsqmlrouas4kfuydft32nkgj5flbra3oo5q`

**OneSignal Dashboard:** https://dashboard.onesignal.com/

---

## How It Works

### Notification Flow

```
1. Document created in /notifications collection
   ↓
2. sendNotifications trigger fires
   ↓
3. Query users by targetRole or targetUid
   ↓
4. Send via OneSignal HTTP API
   ↓
5. OneSignal delivers to user's device
   ↓
6. App receives notification (foreground or background)
```

### DSS Alerts Flow

```
Every 1 hour:
1. checkDSSAlerts function runs
   ↓
2. Check stock_inventory collection
   ↓
3. Calculate consumption rates from issuances
   ↓
4. Identify critical/low stock items
   ↓
5. Check vehicles for PMS schedules
   ↓
6. Send alerts to admins and customers via OneSignal
```

---

## Notification Document Schema

When creating notifications in Firestore, use this structure:

```json
{
  "title": "string - Notification title",
  "message": "string - Notification body/content",
  "type": "string - 'info', 'warning', or 'success'",
  "targetRole": "string - 'admin', 'staff', 'customer', or empty for all",
  "targetUid": "string - Specific user ID, or empty for role-based",
  "createdAt": "timestamp - Server timestamp",
  "readBy": "map - {userId: true} for tracking read status"
}
```

**Examples:**

Send to all admins:
```json
{
  "title": "Stock Alert",
  "message": "Item ABC is out of stock",
  "type": "warning",
  "targetRole": "admin",
  "targetUid": "",
  "createdAt": (server timestamp)
}
```

Send to specific user:
```json
{
  "title": "Your Service is Ready",
  "message": "Your vehicle is ready for pickup",
  "type": "success",
  "targetRole": "",
  "targetUid": "user-123",
  "createdAt": (server timestamp)
}
```

---

## Troubleshooting

### Notifications not appearing on device?

1. **Check OneSignal Dashboard:**
   - Go to https://dashboard.onesignal.com/
   - Check "Messages" tab for delivery status
   - Look for any error messages

2. **Verify user is logged in:**
   - OneSignal requires `OneSignal.login(uid)` to be called
   - This happens automatically in `_initializeOneSignal()`

3. **Check notification permissions:**
   - App requests permission in `_initializeOneSignal()`
   - User must grant notification permission on device

4. **Check Cloud Functions logs:**
   - Firebase Console → Functions → Logs
   - Look for errors in `sendNotifications` or `checkDSSAlerts`

5. **Verify Firestore document:**
   - Check that document has all required fields
   - Ensure `createdAt` is a server timestamp

### Cloud Functions not deploying?

1. **Firebase project must be on Blaze plan** (pay-as-you-go)
2. **Check Node.js version:** Should be 18 or higher
3. **Check for syntax errors:** Run `npm run lint` in functions directory

---

## Files Modified

1. `automotive_mobile/lib/notifications.dart` - OneSignal initialization and UI
2. `automotive_mobile/functions/index.js` - Cloud Functions with OneSignal API
3. `automotive_mobile/functions/package.json` - Added axios dependency
4. `automotive_mobile/pubspec.yaml` - Added onesignal_flutter dependency

---

## Important Notes

- **Firebase Messaging is still in pubspec.yaml** but not used. Can be removed later if desired.
- **OneSignal handles all push notifications** - no need for Firebase Messaging
- **DSS alerts run automatically** every hour - no manual trigger needed
- **Notifications are stored in Firestore** for audit trail and read tracking

---

## Support

For OneSignal issues, visit: https://documentation.onesignal.com/
For Firebase issues, visit: https://firebase.google.com/docs/

