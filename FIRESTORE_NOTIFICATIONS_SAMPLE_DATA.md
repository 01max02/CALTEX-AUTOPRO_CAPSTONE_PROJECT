# Firestore Notifications Collection - Sample Data (d2)

## How to Add Sample Documents to Notifications Collection

### Method 1: Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → Firestore Database
3. Click on the `notifications` collection
4. Click **"Add document"**
5. Click **"Auto ID"** to generate a document ID
6. Add the fields below

---

## Sample Document 1 (d1) - Admin Welcome

**Document ID**: Auto-generated (e.g., `abc123xyz`)

| Field | Type | Value |
|-------|------|-------|
| title | String | Welcome Admin |
| message | String | Welcome to AutoPro Admin Dashboard. You can now manage vehicles, users, and maintenance records. |
| type | String | info |
| targetRole | String | admin |
| createdAt | Timestamp | 2024-04-30 12:00:00 UTC |

**JSON Format:**
```json
{
  "title": "Welcome Admin",
  "message": "Welcome to AutoPro Admin Dashboard. You can now manage vehicles, users, and maintenance records.",
  "type": "info",
  "targetRole": "admin",
  "createdAt": "2024-04-30T12:00:00Z"
}
```

---

## Sample Document 2 (d2) - Maintenance Alert

**Document ID**: Auto-generated (e.g., `def456uvw`)

| Field | Type | Value |
|-------|------|-------|
| title | String | Maintenance Due |
| message | String | Vehicle ABC-123 requires scheduled maintenance. Please schedule it as soon as possible. |
| type | String | warning |
| targetRole | String | staff |
| createdAt | Timestamp | 2024-04-30 12:30:00 UTC |

**JSON Format:**
```json
{
  "title": "Maintenance Due",
  "message": "Vehicle ABC-123 requires scheduled maintenance. Please schedule it as soon as possible.",
  "type": "warning",
  "targetRole": "staff",
  "createdAt": "2024-04-30T12:30:00Z"
}
```

---

## Sample Document 3 (d3) - Service Complete

**Document ID**: Auto-generated (e.g., `ghi789rst`)

| Field | Type | Value |
|-------|------|-------|
| title | String | Service Complete |
| message | String | Your vehicle service has been completed. Please pick it up at your earliest convenience. |
| type | String | success |
| targetRole | String | customer |
| createdAt | Timestamp | 2024-04-30 13:00:00 UTC |

**JSON Format:**
```json
{
  "title": "Service Complete",
  "message": "Your vehicle service has been completed. Please pick it up at your earliest convenience.",
  "type": "success",
  "targetRole": "customer",
  "createdAt": "2024-04-30T13:00:00Z"
}
```

---

## Sample Document 4 (d4) - System Maintenance Warning

**Document ID**: Auto-generated (e.g., `jkl012mno`)

| Field | Type | Value |
|-------|------|-------|
| title | String | System Maintenance |
| message | String | System maintenance scheduled for tonight at 10 PM. Please save your work. |
| type | String | warning |
| targetRole | String | admin |
| createdAt | Timestamp | 2024-04-30 14:00:00 UTC |

**JSON Format:**
```json
{
  "title": "System Maintenance",
  "message": "System maintenance scheduled for tonight at 10 PM. Please save your work.",
  "type": "warning",
  "targetRole": "admin",
  "createdAt": "2024-04-30T14:00:00Z"
}
```

---

## Sample Document 5 (d5) - New Vehicle Added

**Document ID**: Auto-generated (e.g., `pqr345stu`)

| Field | Type | Value |
|-------|------|-------|
| title | String | New Vehicle Added |
| message | String | A new vehicle (Toyota Camry 2024) has been added to the system. Please review it. |
| type | String | info |
| targetRole | String | staff |
| createdAt | Timestamp | 2024-04-30 14:30:00 UTC |

**JSON Format:**
```json
{
  "title": "New Vehicle Added",
  "message": "A new vehicle (Toyota Camry 2024) has been added to the system. Please review it.",
  "type": "info",
  "targetRole": "staff",
  "createdAt": "2024-04-30T14:30:00Z"
}
```

---

## Sample Document 6 (d6) - Special Offer

**Document ID**: Auto-generated (e.g., `vwx678yza`)

| Field | Type | Value |
|-------|------|-------|
| title | String | Special Offer |
| message | String | Get 20% off on your next service! Use code SAVE20 at checkout. |
| type | String | success |
| targetRole | String | customer |
| createdAt | Timestamp | 2024-04-30 15:00:00 UTC |

**JSON Format:**
```json
{
  "title": "Special Offer",
  "message": "Get 20% off on your next service! Use code SAVE20 at checkout.",
  "type": "success",
  "targetRole": "customer",
  "createdAt": "2024-04-30T15:00:00Z"
}
```

---

## Sample Document 7 (d7) - Personal User Notification

**Document ID**: Auto-generated (e.g., `bcd901efg`)

| Field | Type | Value |
|-------|------|-------|
| title | String | Account Alert |
| message | String | Unusual activity detected on your account. Please verify your recent actions. |
| type | String | warning |
| targetUid | String | user_id_here |
| createdAt | Timestamp | 2024-04-30 15:30:00 UTC |

**JSON Format:**
```json
{
  "title": "Account Alert",
  "message": "Unusual activity detected on your account. Please verify your recent actions.",
  "type": "warning",
  "targetUid": "user_id_here",
  "createdAt": "2024-04-30T15:30:00Z"
}
```

---

## Step-by-Step Instructions to Add d2

### Using Firebase Console:

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com
   - Select your AutoPro project
   - Click on **Firestore Database**

2. **Navigate to Notifications Collection**
   - Click on the `notifications` collection in the left sidebar
   - If it doesn't exist, click **"Create collection"** first

3. **Add Document d2**
   - Click **"Add document"** button
   - Click **"Auto ID"** to generate a document ID automatically
   - Add these fields:

   **Field 1:**
   - Field name: `title`
   - Type: String
   - Value: `Maintenance Due`

   **Field 2:**
   - Field name: `message`
   - Type: String
   - Value: `Vehicle ABC-123 requires scheduled maintenance. Please schedule it as soon as possible.`

   **Field 3:**
   - Field name: `type`
   - Type: String
   - Value: `warning`

   **Field 4:**
   - Field name: `targetRole`
   - Type: String
   - Value: `staff`

   **Field 5:**
   - Field name: `createdAt`
   - Type: Timestamp
   - Value: `2024-04-30 12:30:00 UTC` (or current date/time)

4. **Click "Save"**

---

## Verification

After adding the documents, you should see:

```
notifications/
├── abc123xyz/
│   ├── title: "Welcome Admin"
│   ├── message: "Welcome to AutoPro Admin Dashboard..."
│   ├── type: "info"
│   ├── targetRole: "admin"
│   └── createdAt: 2024-04-30 12:00:00 UTC
├── def456uvw/
│   ├── title: "Maintenance Due"
│   ├── message: "Vehicle ABC-123 requires scheduled maintenance..."
│   ├── type: "warning"
│   ├── targetRole: "staff"
│   └── createdAt: 2024-04-30 12:30:00 UTC
├── ghi789rst/
│   ├── title: "Service Complete"
│   ├── message: "Your vehicle service has been completed..."
│   ├── type: "success"
│   ├── targetRole: "customer"
│   └── createdAt: 2024-04-30 13:00:00 UTC
└── ... (more documents)
```

---

## Testing the Notifications

### Test on App:

1. **Open the app** on a real device
2. **Go to Notifications screen**
3. **You should see:**
   - d1: "Welcome Admin" (if logged in as admin)
   - d2: "Maintenance Due" (if logged in as staff)
   - d3: "Service Complete" (if logged in as customer)
   - etc.

### Test Push Notifications:

1. **Close the app** (background/terminated state)
2. **Create a new notification** in Firestore
3. **Check device notification tray** - you should see a push notification
4. **Tap the notification** - it should open the app

### Check Cloud Function Logs:

```bash
firebase functions:log
```

You should see:
```
Notification sent to user user_id_1
Notification sent to user user_id_2
Notifications sent to 2 users
```

---

## Notification Types Reference

| Type | Color | Icon | Use Case |
|------|-------|------|----------|
| info | Blue (#003087) | info_outline | General information |
| warning | Orange | warning_amber_outlined | Important alerts |
| success | Teal (#2c7a7b) | check_circle_outline | Successful actions |

---

## Summary

✅ **Firestore Rules**: Already configured to allow read/write for authenticated users
✅ **Notifications Collection**: Ready to receive documents
✅ **Sample Data**: 7 sample documents provided above
✅ **Cloud Function**: Automatically sends push notifications when documents are created

**Next Steps:**
1. Add the sample documents to Firestore
2. Deploy Cloud Functions (if not already done)
3. Test on real device
4. Monitor Cloud Function logs

---

**Status**: Ready to add sample data
**Last Updated**: April 30, 2024
