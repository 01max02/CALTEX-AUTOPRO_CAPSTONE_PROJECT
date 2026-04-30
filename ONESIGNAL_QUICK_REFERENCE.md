# OneSignal Integration - Quick Reference

## Credentials
```
App ID:     c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea
API Key:    os_v7_app_yt4cvr2f1hkhvh5ldu4k637i51snjeyuythen3fd61ae1yhnprpy6kbxvn9kjd1pqdhygsqmlrouas4kfuydft32nkgj5flbra3oo5q
```

## Key Files
- `lib/main.dart` - OneSignal initialization
- `lib/login.dart` - OneSignal login after auth
- `lib/notifications.dart` - Direct API calls + in-app list
- `lib/admin_dss.dart` - DSS alerts with OneSignal

## How to Send a Notification

### From Notifications Screen
```dart
// In notifications.dart
await generateDSSAlerts(); // Analyzes real data and sends alerts
```

### From Admin DSS Screen
```dart
// Automatically triggered when admin opens DSS screen
// In admin_dss.dart - _sendDSSAlerts() called in initState
```

### Direct API Call
```dart
// In any file that imports notifications.dart
await _sendViaOneSignal(
  externalUserIds: ['uid1', 'uid2'],
  title: 'Alert Title',
  message: 'Alert message',
  type: 'warning', // or 'info', 'success'
);
```

## Alert Types

### Stock Alerts (Admin Only)
- **Out of Stock**: `stock == 0`
- **Low Stock**: `stock <= min`

### PMS Alerts (Admin + Vehicle Owner)
- **Overdue**: `daysUntil < 0`
- **Due Soon**: `daysUntil <= 7`
- **Due This Week**: `daysUntil <= 14`

## Testing

### Quick Test
1. Log in as admin
2. Open DSS screen
3. Check device for notifications within 5-10 seconds

### Verify OneSignal Registration
1. Go to OneSignal Dashboard
2. Audience → Devices
3. Search for your device UID
4. Should show "Active" status

### Check Delivery Status
1. OneSignal Dashboard → Messages
2. Find your notification
3. Check "Delivered" count

## Console Logs to Look For

| Log | Meaning |
|-----|---------|
| `✅ OneSignal auto-login with UID: [uid]` | Device registered at startup |
| `✅ OneSignal login: [uid]` | Device registered after login |
| `📤 OneSignal → 200: {...}` | Notification sent successfully |
| `❌ OneSignal send error: [error]` | API call failed |
| `✅ DSS alerts sent from AdminDSS screen` | DSS alerts generated |

## Common Issues

| Issue | Solution |
|-------|----------|
| No notifications on device | Check OneSignal Dashboard → Devices for registration |
| Notifications in Firestore but not on device | Check OneSignal API response (should be 200) |
| Device not registered | Ensure `OneSignal.login(uid)` called after auth |
| Notifications not in Firestore | Check Firestore permissions |

## API Endpoint

```
POST https://onesignal.com/api/v1/notifications

Headers:
  Authorization: Basic [API_KEY]
  Content-Type: application/json

Body:
{
  "app_id": "[APP_ID]",
  "include_external_user_ids": ["uid1", "uid2"],
  "headings": {"en": "Title"},
  "contents": {"en": "Message"},
  "data": {"type": "warning"}
}
```

## Firestore Collections

### /notifications
```
{
  title: "Alert Title",
  message: "Alert message",
  type: "warning",
  targetRole: "admin",        // or empty for personal
  targetUid: "uid",           // or empty for role-based
  createdAt: Timestamp,
  readBy: {
    "uid1": true,
    "uid2": false
  }
}
```

## Dependencies

```yaml
dependencies:
  onesignal_flutter: ^5.0.0
  http: ^1.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
```

## Permissions (Android)

Already configured in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## No Cloud Functions Needed

✅ Direct API calls from Flutter
✅ No Firebase Blaze plan required
✅ Works on Spark plan
✅ Faster delivery
✅ More reliable

