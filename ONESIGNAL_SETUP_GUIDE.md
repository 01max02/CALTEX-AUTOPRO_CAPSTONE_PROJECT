# OneSignal Push Notifications Setup

## Overview
OneSignal is a push notification service that's easier to set up than Firebase Cloud Messaging. It handles all the complexity for you.

---

## Step 1: Create OneSignal Account

1. Go to https://onesignal.com
2. Click **"Sign Up"**
3. Create account with email
4. Verify email
5. Create new app

---

## Step 2: Configure OneSignal App

### For Flutter Mobile App:

1. **Select Platform:** Choose "Flutter"
2. **Android Setup:**
   - Get Google Server API Key from Firebase Console
   - Paste in OneSignal
3. **iOS Setup:**
   - Get Apple Push Certificate
   - Upload to OneSignal

### For Web:

1. **Select Platform:** Choose "Web"
2. Get OneSignal App ID and REST API Key

---

## Step 3: Install OneSignal in Flutter

### Add to pubspec.yaml:

```yaml
dependencies:
  onesignal_flutter: ^5.0.0
```

### Run:
```bash
flutter pub get
```

---

## Step 4: Update notifications.dart

Replace Firebase messaging with OneSignal:

```dart
import 'package:onesignal_flutter/onesignal_flutter.dart';

class _AppNotificationsState extends State<AppNotifications> {
  @override
  void initState() {
    super.initState();
    _initializeOneSignal();
  }

  Future<void> _initializeOneSignal() async {
    // Initialize OneSignal
    OneSignal.initialize("YOUR_ONESIGNAL_APP_ID");
    
    // Request permission
    await OneSignal.Notifications.requestPermission(true);
    
    // Set external user ID (your Firebase UID)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      OneSignal.login(uid);
    }
    
    // Handle notification received
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('Notification received: ${event.notification.title}');
      _showNotificationDialog(event.notification);
    });
    
    // Handle notification clicked
    OneSignal.Notifications.addClickListener((event) {
      debugPrint('Notification clicked: ${event.notification.title}');
      _handleNotificationTap(event.notification);
    });
  }

  void _showNotificationDialog(OSNotification notification) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notification.title ?? 'Notification'),
        content: Text(notification.body ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(OSNotification notification) {
    debugPrint('Notification tapped: ${notification.additionalData}');
  }
}
```

---

## Step 5: Send Notifications from Cloud Function

### Update functions/index.js:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

const ONESIGNAL_APP_ID = 'YOUR_ONESIGNAL_APP_ID';
const ONESIGNAL_REST_API_KEY = 'YOUR_ONESIGNAL_REST_API_KEY';

exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { userId, title, body, type = 'info' } = data;

  if (!title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Title and body required.');
  }

  try {
    // Send via OneSignal
    const response = await axios.post(
      'https://onesignal.com/api/v1/notifications',
      {
        app_id: ONESIGNAL_APP_ID,
        include_external_user_ids: [userId],
        headings: { en: title },
        contents: { en: body },
        data: { type: type },
      },
      {
        headers: {
          'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
          'Content-Type': 'application/json; charset=utf-8',
        },
      }
    );

    console.log(`Push notification sent: ${response.data.body.id}`);
    return { success: true, messageId: response.data.body.id };
  } catch (error) {
    console.error('Error sending push notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

exports.sendDSSAlerts = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
  }

  try {
    const db = admin.firestore();
    
    // Get all admins
    const adminSnapshot = await db.collection('users')
      .where('role', '==', 'admin')
      .get();

    // Get stock data
    const stockSnapshot = await db.collection('stock_inventory').get();
    const issuancesSnapshot = await db.collection('issuances').get();

    // Build consumption map
    const consumptionMap = {};
    issuancesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const itemNum = data.itemNum || '';
      const qty = typeof data.qty === 'number' ? data.qty : parseFloat(data.qty) || 0;
      if (itemNum && qty > 0) {
        if (!consumptionMap[itemNum]) consumptionMap[itemNum] = [];
        consumptionMap[itemNum].push({ date: data.date, qty });
      }
    });

    // Check stock items
    const criticalItems = [];
    const lowItems = [];

    stockSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const itemNum = data.num || data.itemNum || doc.id;
      const stock = parseInt(data.stock) || 0;
      const min = parseInt(data.min) || 0;
      const max = parseInt(data.max) || 0;
      const reorder = parseInt(data.reorder) || 0;
      const name = data.name || itemNum;
      const uom = data.uom || '';

      if (stock === 0) {
        criticalItems.push({ name, stock, uom, reorder });
      } else if (stock <= min) {
        lowItems.push({ name, stock, uom, reorder });
      }
    });

    // Send alerts to admins
    const adminIds = adminSnapshot.docs.map(doc => doc.id);

    if (criticalItems.length > 0) {
      const item = criticalItems[0];
      await axios.post(
        'https://onesignal.com/api/v1/notifications',
        {
          app_id: ONESIGNAL_APP_ID,
          include_external_user_ids: adminIds,
          headings: { en: '🚨 URGENT: Out of Stock' },
          contents: { en: `${item.name} is out of stock. Recommend ordering ${item.reorder} ${item.uom}.` },
          data: { type: 'critical_stock' },
        },
        {
          headers: {
            'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
            'Content-Type': 'application/json; charset=utf-8',
          },
        }
      );
    }

    if (lowItems.length > 0) {
      const item = lowItems[0];
      await axios.post(
        'https://onesignal.com/api/v1/notifications',
        {
          app_id: ONESIGNAL_APP_ID,
          include_external_user_ids: adminIds,
          headings: { en: '⚠️ Low Stock Alert' },
          contents: { en: `${item.name} is low (${item.stock} ${item.uom}). Recommend ordering ${item.reorder} ${item.uom}.` },
          data: { type: 'low_stock' },
        },
        {
          headers: {
            'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
            'Content-Type': 'application/json; charset=utf-8',
          },
        }
      );
    }

    return { success: true, alertsSent: true };
  } catch (error) {
    console.error('Error sending DSS alerts:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send alerts');
  }
});
```

---

## Step 6: Update pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_auth: ^4.0.0
  cloud_firestore: ^4.0.0
  onesignal_flutter: ^5.0.0
  cloud_functions: ^4.0.0
  http: ^1.0.0
```

---

## Step 7: Get OneSignal Credentials

1. Go to OneSignal Dashboard
2. Click **Settings** → **Keys & IDs**
3. Copy:
   - **App ID** (for Flutter)
   - **REST API Key** (for Cloud Functions)

---

## Step 8: Update Android Manifest

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

---

## Step 9: Test

### Send Test Notification:

1. Go to OneSignal Dashboard
2. Click **New Message**
3. Select **Push Notification**
4. Enter title and message
5. Select **Specific Users** → Enter user ID
6. Click **Send**

---

## Advantages of OneSignal

✅ **Easier Setup** - No Firebase Cloud Messaging complexity
✅ **Better UI** - Dashboard is more intuitive
✅ **Segmentation** - Easy to target specific users/groups
✅ **Analytics** - Built-in tracking and reporting
✅ **Free Tier** - Generous free plan
✅ **Multi-Platform** - Works on iOS, Android, Web
✅ **No Server Setup** - Everything handled by OneSignal

---

## Next Steps

1. ✅ Create OneSignal account
2. ✅ Get App ID and REST API Key
3. ✅ Update Flutter app with OneSignal SDK
4. ✅ Update Cloud Functions
5. ✅ Test push notifications
6. ✅ Deploy to production

