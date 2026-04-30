# Mobile Push Notifications - Troubleshooting Guide

## Problem: Push Notifications Not Appearing on Mobile Device

### Root Cause
Push notifications require an **FCM token** to be saved in Firestore. Without it, Firebase can't send notifications to your device.

---

## Step 1: Check if FCM Token is Saved

### In Firebase Console:

1. Go to **Firebase Console** → **Firestore Database**
2. Click **`users`** collection
3. Find your user document (click on it)
4. Look for **`fcmToken`** field

**Expected:**
```
fcmToken: "eJxdUMtuwjAM/BXLZ0qgQOGGNEhTN..."
fcmTokenUpdatedAt: (timestamp)
```

**If missing:**
- ❌ Token was not saved
- ❌ Notifications won't work

---

## Step 2: Force Save FCM Token

### Option A: Restart App (Easiest)

1. **Close the app completely** (swipe it away)
2. **Wait 5 seconds**
3. **Reopen the app**
4. **Check Firestore again** - token should now be saved

The updated code now forces token refresh on app start.

### Option B: Check Console Logs

1. **Run the app in debug mode**
2. **Open Flutter console**
3. **Look for these messages:**

```
✅ FCM token saved successfully for user: abc123
Token: eJxdUMtuwjAM/BXLZ0qgQOGNEhTN...
```

**If you see:**
```
❌ Error saving FCM token: ...
```

Then there's a Firestore permission issue.

---

## Step 3: Check Firestore Rules

Your Firestore rules must allow users to update their own documents.

### Go to Firebase Console:

1. **Firestore Database** → **Rules** tab
2. Make sure rules allow:
   ```
   allow update: if request.auth.uid == resource.id
   ```

**Default rules should work**, but if custom rules are set, verify they allow user updates.

---

## Step 4: Test Push Notification

### Once FCM Token is Saved:

1. **Close app completely** (swipe away)
2. **Go to Firebase Console** → **Firestore**
3. **Create a test notification:**

```
Collection: notifications
Document ID: (auto-generate)

Fields:
- title: "Test Notification"
- message: "This is a test"
- type: "info"
- targetRole: "admin"
- createdAt: (current timestamp)
```

4. **Save**
5. **Check device notification tray** - notification should appear in 5-10 seconds

---

## Step 5: Verify Cloud Function Trigger

The `sendNotifications` Cloud Function should trigger automatically.

### Check Function Logs:

1. **Firebase Console** → **Functions**
2. **Click `sendNotifications`**
3. **Click "Logs" tab**
4. **Look for:**
   - ✅ "Notification sent to user..."
   - ❌ "No FCM token for user..."
   - ❌ "Error sending notification..."

---

## Common Issues & Solutions

### Issue 1: "No FCM token for user"

**Cause:** Token not saved in Firestore

**Solution:**
1. Restart app
2. Check Firestore for `fcmToken` field
3. If still missing, check Firestore rules

### Issue 2: "Error sending notification"

**Cause:** FCM service error or invalid token

**Solution:**
1. Restart app (gets new token)
2. Check Firebase Console → Functions → Logs
3. Look for specific error message

### Issue 3: Notification appears in app but not on device

**Cause:** App is open (foreground message)

**Solution:**
- Close app completely
- Create notification
- Check device notification tray

### Issue 4: Notification never appears

**Cause:** Multiple possible reasons

**Checklist:**
- ✅ App is completely closed
- ✅ FCM token is saved in Firestore
- ✅ Device notifications are enabled
- ✅ Firestore rules allow user updates
- ✅ Cloud Function logs show no errors
- ✅ Waited 5-10 seconds after creating notification

---

## Debug Checklist

Before testing, verify:

- [ ] App is running (at least once) to save FCM token
- [ ] User is logged in
- [ ] Firestore has `users` collection with your user
- [ ] Your user document has `fcmToken` field
- [ ] Device notifications are enabled (Settings → Notifications)
- [ ] App is completely closed when testing
- [ ] Waited 5-10 seconds after creating notification

---

## Testing Workflow

### Complete Test:

1. **Open app** → Logs in → Saves FCM token
2. **Check Firestore** → Verify `fcmToken` is saved
3. **Close app** → Swipe away completely
4. **Create notification** in Firestore Console
5. **Wait 5-10 seconds**
6. **Check device notification tray**
7. **Notification should appear** ✅

---

## If Still Not Working

### Check These Files:

1. **notifications.dart** - FCM initialization
2. **android/app/src/main/AndroidManifest.xml** - Permissions
3. **ios/Runner/Info.plist** - Permissions
4. **firebase.json** - Configuration

### Enable Debug Logging:

Add to notifications.dart:
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  debugPrint('🔔 Foreground message received');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  _showNotificationDialog(message);
});
```

---

## Next Steps

1. ✅ Restart app
2. ✅ Check Firestore for FCM token
3. ✅ Create test notification
4. ✅ Check device notification tray
5. 📝 If working, create real notifications
6. 🚀 Deploy to production

