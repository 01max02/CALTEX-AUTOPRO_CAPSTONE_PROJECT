# Firestore Notifications Collection Setup

## Overview
This guide explains how to set up the `notifications` collection in Firestore and add sample notification documents.

## Collection Structure

### Collection Name
```
notifications
```

### Document Fields

Each notification document should have the following structure:

```json
{
  "title": "string",                    // Required: Notification title
  "message": "string",                  // Required: Notification body/message
  "type": "info|warning|success",       // Optional: Type of notification (default: "info")
  "targetRole": "admin|staff|customer", // Optional: Send to all users with this role
  "targetUid": "user_id",               // Optional: Send to specific user by UID
  "createdAt": "timestamp",             // Auto-generated: When notification was created
  "readBy": {                           // Auto-generated: Track who read the notification
    "user_id_1": true,
    "user_id_2": false
  }
}
```

## How to Add Notifications

### Method 1: Firebase Console (Easiest)

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com
   - Select your project
   - Go to Firestore Database

2. **Create Collection**
   - Click "Create collection"
   - Collection ID: `notifications`
   - Click "Next"

3. **Add First Document**
   - Click "Auto ID" to generate a document ID
   - Add the following fields:

   | Field | Type | Value |
   |-------|------|-------|
   | title | String | "Welcome to AutoPro" |
   | message | String | "Welcome to the AutoPro notification system" |
   | type | String | "info" |
   | targetRole | String | "admin" |
   | createdAt | Timestamp | (current date/time) |

   - Click "Save"

### Method 2: Add Sample Documents

Here are some sample notification documents you can add:

#### Sample 1: Admin Welcome Notification
```json
{
  "title": "Welcome Admin",
  "message": "Welcome to AutoPro Admin Dashboard. You can now manage vehicles, users, and maintenance records.",
  "type": "info",
  "targetRole": "admin",
  "createdAt": "2024-04-30T12:00:00Z"
}
```

#### Sample 2: Staff Maintenance Alert
```json
{
  "title": "Maintenance Due",
  "message": "Vehicle ABC-123 requires scheduled maintenance. Please schedule it as soon as possible.",
  "type": "warning",
  "targetRole": "staff",
  "createdAt": "2024-04-30T12:30:00Z"
}
```

#### Sample 3: Customer Service Update
```json
{
  "title": "Service Complete",
  "message": "Your vehicle service has been completed. Please pick it up at your earliest convenience.",
  "type": "success",
  "targetRole": "customer",
  "createdAt": "2024-04-30T13:00:00Z"
}
```

#### Sample 4: Personal Notification to Specific User
```json
{
  "title": "Important Update",
  "message": "Your account settings have been updated. Please review them.",
  "type": "info",
  "targetUid": "user_id_here",
  "createdAt": "2024-04-30T13:30:00Z"
}
```

## Firestore Security Rules

Add these rules to your Firestore to allow authenticated users to read and write notifications:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Notifications collection - allow authenticated users to read/write
    match /notifications/{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Users collection - allow users to read their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId || request.auth.uid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## Testing Notifications

### Step 1: Create a Test Notification
1. Go to Firebase Console → Firestore
2. In the `notifications` collection, click "Add document"
3. Use Auto ID for the document ID
4. Add these fields:
   - `title`: "Test Notification"
   - `message`: "This is a test push notification"
   - `type`: "info"
   - `targetRole`: "admin"
   - `createdAt`: (current timestamp)

### Step 2: Verify on App
1. Open the app on a real device
2. Go to the Notifications screen
3. You should see the notification appear
4. The Cloud Function will automatically send a push notification to all admin users

### Step 3: Check Cloud Function Logs
```bash
firebase functions:log
```

You should see output like:
```
Notification sent to user user_id_1
Notification sent to user user_id_2
Notifications sent to 2 users
```

## Notification Types and Colors

The app displays notifications with different colors based on type:

| Type | Color | Icon |
|------|-------|------|
| info | Blue (#003087) | info_outline |
| warning | Orange | warning_amber_outlined |
| success | Teal (#2c7a7b) | check_circle_outline |

## Common Use Cases

### 1. Send to All Admins
```json
{
  "title": "System Maintenance",
  "message": "System maintenance scheduled for tonight at 10 PM",
  "type": "warning",
  "targetRole": "admin",
  "createdAt": "2024-04-30T14:00:00Z"
}
```

### 2. Send to All Staff
```json
{
  "title": "New Vehicle Added",
  "message": "A new vehicle has been added to the system. Please review it.",
  "type": "info",
  "targetRole": "staff",
  "createdAt": "2024-04-30T14:30:00Z"
}
```

### 3. Send to All Customers
```json
{
  "title": "Special Offer",
  "message": "Get 20% off on your next service! Use code SAVE20",
  "type": "success",
  "targetRole": "customer",
  "createdAt": "2024-04-30T15:00:00Z"
}
```

### 4. Send to Specific User
```json
{
  "title": "Account Alert",
  "message": "Unusual activity detected on your account. Please verify.",
  "type": "warning",
  "targetUid": "specific_user_uid_here",
  "createdAt": "2024-04-30T15:30:00Z"
}
```

### 5. Send to Everyone
```json
{
  "title": "Important Announcement",
  "message": "Please read the latest company announcement.",
  "type": "info",
  "createdAt": "2024-04-30T16:00:00Z"
}
```
(No targetRole or targetUid = sends to all users)

## Troubleshooting

### Notifications Not Appearing

1. **Check FCM Token**
   - Go to Firestore → users collection
   - Check if user document has `fcmToken` field
   - If missing, open the app to trigger token generation

2. **Check Cloud Function Logs**
   ```bash
   firebase functions:log
   ```
   - Look for errors in the sendNotifications function

3. **Check Firestore Rules**
   - Ensure notifications collection allows read/write for authenticated users
   - Ensure users collection is readable by admins

4. **Check App Permissions**
   - Ensure user granted notification permissions when app started
   - On Android: Check Settings → Apps → AutoPro → Notifications

### Push Notification Not Received

1. **Device Requirements**
   - Must be a real device (not emulator/simulator)
   - Must have internet connection
   - Must have Google Play Services installed (Android)

2. **App State**
   - Foreground: Notification appears in dialog
   - Background: Push notification appears in system tray
   - Terminated: Push notification appears in system tray

3. **Check Device Logs**
   - Android: `adb logcat | grep firebase`
   - iOS: Check Xcode console

## Database Structure Summary

```
Firestore Database
├── notifications/
│   ├── doc1/
│   │   ├── title: "Welcome Admin"
│   │   ├── message: "Welcome to AutoPro..."
│   │   ├── type: "info"
│   │   ├── targetRole: "admin"
│   │   ├── createdAt: timestamp
│   │   └── readBy: {}
│   ├── doc2/
│   │   ├── title: "Maintenance Due"
│   │   ├── message: "Vehicle ABC-123..."
│   │   ├── type: "warning"
│   │   ├── targetRole: "staff"
│   │   ├── createdAt: timestamp
│   │   └── readBy: {}
│   └── ...
└── users/
    ├── user1/
    │   ├── email: "admin@example.com"
    │   ├── role: "admin"
    │   ├── fcmToken: "token_here"
    │   └── ...
    └── ...
```

## Next Steps

1. ✅ Create the `notifications` collection in Firestore
2. ✅ Add sample notification documents
3. ✅ Update Firestore security rules
4. ✅ Deploy Cloud Functions (if not already done)
5. ✅ Test on real device
6. ✅ Monitor Cloud Function logs

---

**Status**: Ready to set up
**Last Updated**: April 30, 2024
