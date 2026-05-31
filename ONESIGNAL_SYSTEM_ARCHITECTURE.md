# OneSignal Push Notifications - System Architecture

## Overview

The push notification system uses **OneSignal** as the delivery platform, with **Firebase Cloud Functions** as the backend orchestrator and **Flutter** as the mobile client.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     MOBILE APP (Flutter)                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ OneSignal SDK                                            │  │
│  │ - Initialize with App ID                                │  │
│  │ - Login with Firebase UID                               │  │
│  │ - Handle foreground notifications                       │  │
│  │ - Handle notification clicks                            │  │
│  │ - Display notification UI                               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↑
                              │ (Receive notifications)
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    ONESIGNAL PLATFORM                           │
│  - Stores user subscriptions                                    │
│  - Manages device tokens                                        │
│  - Delivers notifications to devices                            │
│  - Tracks delivery and engagement                               │
└─────────────────────────────────────────────────────────────────┘
                              ↑
                              │ (Send notifications via HTTP API)
                              │
┌─────────────────────────────────────────────────────────────────┐
│              FIREBASE CLOUD FUNCTIONS (Node.js)                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ sendNotifications (Trigger)                              │  │
│  │ - Listens to /notifications collection                   │  │
│  │ - Queries users by role or UID                           │  │
│  │ - Sends via OneSignal API                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ checkDSSAlerts (Scheduled - Every 1 hour)                │  │
│  │ - Checks stock levels                                    │  │
│  │ - Checks PMS schedules                                   │  │
│  │ - Sends alerts to admins and customers                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ sendPushNotification (Callable)                           │  │
│  │ - Called from app or website                             │  │
│  │ - Sends to specific user or role                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↑
                              │ (Read/Write data)
                              │
┌─────────────────────────────────────────────────────────────────┐
│                  FIREBASE FIRESTORE                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Collections:                                             │  │
│  │ - /users (user profiles with roles)                      │  │
│  │ - /notifications (notification documents)                │  │
│  │ - /stock_inventory (inventory items)                     │  │
│  │ - /issuances (stock consumption records)                 │  │
│  │ - /vehicles (vehicle maintenance schedules)              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Mobile App (Flutter)

**File:** `automotive_mobile/lib/notifications.dart`

**Responsibilities:**
- Initialize OneSignal with App ID
- Request notification permissions
- Login user with Firebase UID
- Handle foreground notifications
- Handle notification clicks
- Display notification UI
- Generate DSS alerts based on real data

**Key Methods:**
```dart
_initializeOneSignal()      // Initialize OneSignal
_showNotificationDialog()   // Show notification dialog
_handleNotificationTap()    // Handle notification click
generateDSSAlerts()         // Generate alerts from data
sendPushNotification()      // Send notification via Cloud Function
```

**Notification Flow:**
1. App starts → `_initializeOneSignal()` called
2. OneSignal initialized with App ID
3. User logged in with Firebase UID
4. Listeners set up for foreground and click events
5. When notification arrives → `_showNotificationDialog()` or `_handleNotificationTap()`

---

### 2. Cloud Functions (Node.js)

**File:** `automotive_mobile/functions/index.js`

**Responsibilities:**
- Listen for new notifications in Firestore
- Query users by role or UID
- Send notifications via OneSignal API
- Check DSS alerts on schedule
- Provide callable function for manual notifications

#### Function 1: `sendNotifications` (Trigger)

**Trigger:** Document created in `/notifications` collection

**Flow:**
```
1. Document created in /notifications
   ↓
2. Extract title, message, targetRole, targetUid
   ↓
3. Query users:
   - If targetUid: send to that user
   - If targetRole: send to all users with that role
   - If neither: send to all users
   ↓
4. Call OneSignal API with user IDs
   ↓
5. OneSignal delivers to devices
```

**Example:**
```javascript
// When this document is created:
{
  title: "Stock Alert",
  message: "Item ABC is out of stock",
  targetRole: "admin",
  targetUid: ""
}

// Function queries: users where role == 'admin'
// Then sends to all admin user IDs via OneSignal
```

#### Function 2: `checkDSSAlerts` (Scheduled)

**Trigger:** Every 1 hour

**Flow:**
```
1. Get current time and today's date
   ↓
2. Check Stock Levels:
   - Read /stock_inventory collection
   - Read /issuances collection
   - Calculate consumption rates
   - Identify critical/low stock items
   ↓
3. Check PMS Schedules:
   - Read /vehicles collection
   - Calculate days until next maintenance
   - Identify overdue/due soon/due this week
   ↓
4. Send Alerts:
   - Send admin alerts for all issues
   - Send customer alerts for their vehicles only
   ↓
5. Log results
```

**Stock Alert Logic:**
```
For each stock item:
  stock = current quantity
  min = minimum threshold
  max = maximum threshold
  
  If stock == 0:
    → Send "Out of Stock" alert to admins
  Else if stock <= min:
    → Send "Low Stock" alert to admins
```

**PMS Alert Logic:**
```
For each vehicle:
  lastSvcDate = last service date
  svcFreq = service frequency (months)
  nextDate = lastSvcDate + svcFreq months
  daysUntil = days until nextDate
  
  If daysUntil < 0:
    → Send "Overdue" alert
  Else if daysUntil <= 7:
    → Send "Due Soon" alert
  Else if daysUntil <= 14:
    → Send "Due This Week" alert
```

#### Function 3: `sendPushNotification` (Callable)

**Trigger:** Called from app or website

**Parameters:**
```javascript
{
  userId: "user-id",        // Optional: specific user
  title: "Notification Title",
  body: "Notification Body",
  type: "info"              // Optional: 'info', 'warning', 'success'
}
```

**Flow:**
```
1. Verify caller is authenticated
   ↓
2. If userId provided: send to that user
   Else: send to current user
   ↓
3. Call OneSignal API
   ↓
4. Return success/error
```

---

### 3. OneSignal Platform

**Role:** Notification delivery service

**Responsibilities:**
- Store user subscriptions
- Manage device tokens
- Deliver notifications to devices
- Track delivery status
- Track engagement metrics

**Integration Points:**
- Receives HTTP API calls from Cloud Functions
- Sends notifications to mobile devices
- Tracks delivery and opens

**API Endpoint:**
```
POST https://onesignal.com/api/v1/notifications
```

**Request Format:**
```javascript
{
  app_id: "c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea",
  include_external_user_ids: ["user-id-1", "user-id-2"],
  headings: { en: "Notification Title" },
  contents: { en: "Notification Body" },
  data: { type: "info" }
}
```

---

### 4. Firebase Firestore

**Collections:**

#### `/users`
```json
{
  "uid": "user-id",
  "email": "user@example.com",
  "role": "admin|staff|customer",
  "name": "User Name",
  "createdAt": "timestamp"
}
```

#### `/notifications`
```json
{
  "title": "Notification Title",
  "message": "Notification Body",
  "type": "info|warning|success",
  "targetRole": "admin|staff|customer|''",
  "targetUid": "user-id|''",
  "createdAt": "timestamp",
  "readBy": { "user-id": true }
}
```

#### `/stock_inventory`
```json
{
  "num": "ITEM-001",
  "name": "Engine Oil",
  "stock": 50,
  "min": 10,
  "max": 100,
  "reorder": 50,
  "uom": "liters"
}
```

#### `/issuances`
```json
{
  "itemNum": "ITEM-001",
  "qty": 5,
  "date": "2025-04-29",
  "issuedBy": "staff-id"
}
```

#### `/vehicles`
```json
{
  "plate": "ABC-123",
  "desc": "Toyota Camry 2024",
  "lastSvcDate": "2025-03-29",
  "svcFreq": 3,
  "ownerId": "customer-id"
}
```

---

## Data Flow Examples

### Example 1: Manual Notification to Admin

```
1. Admin creates document in /notifications:
   {
     title: "Stock Alert",
     message: "Item ABC is out of stock",
     type: "warning",
     targetRole: "admin",
     targetUid: "",
     createdAt: (server timestamp)
   }

2. sendNotifications trigger fires

3. Query: users where role == 'admin'
   Result: [admin-user-1, admin-user-2, admin-user-3]

4. Call OneSignal API:
   POST https://onesignal.com/api/v1/notifications
   {
     app_id: "c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea",
     include_external_user_ids: ["admin-user-1", "admin-user-2", "admin-user-3"],
     headings: { en: "Stock Alert" },
     contents: { en: "Item ABC is out of stock" },
     data: { type: "warning" }
   }

5. OneSignal sends to all 3 admin devices

6. Notifications appear on devices within 5-10 seconds
```

### Example 2: Automatic DSS Alert (Stock)

```
1. checkDSSAlerts runs (every hour)

2. Read /stock_inventory:
   [
     { num: "ITEM-001", name: "Engine Oil", stock: 0, min: 10 },
     { num: "ITEM-002", name: "Filter", stock: 5, min: 10 }
   ]

3. Identify alerts:
   - ITEM-001: stock == 0 → CRITICAL
   - ITEM-002: stock <= min → LOW

4. Query admins: [admin-user-1, admin-user-2]

5. Send to OneSignal:
   - "🚨 URGENT: Out of Stock" for ITEM-001
   - "⚠️ Low Stock Alert" for ITEM-002

6. Admins receive notifications
```

### Example 3: Automatic DSS Alert (PMS)

```
1. checkDSSAlerts runs (every hour)

2. Read /vehicles:
   [
     { plate: "ABC-123", lastSvcDate: "2025-03-29", svcFreq: 3 }
   ]

3. Calculate:
   - nextDate = 2025-03-29 + 3 months = 2025-06-29
   - daysUntil = 2025-06-29 - today = 60 days

4. No alert (60 days > 14 days threshold)

5. But if lastSvcDate was "2025-04-15":
   - nextDate = 2025-04-15 + 3 months = 2025-07-15
   - daysUntil = 2025-07-15 - today = 75 days
   - Still no alert

6. If lastSvcDate was "2025-03-15":
   - nextDate = 2025-03-15 + 3 months = 2025-06-15
   - daysUntil = 2025-06-15 - today = 45 days
   - Still no alert

7. If lastSvcDate was "2025-04-22":
   - nextDate = 2025-04-22 + 3 months = 2025-07-22
   - daysUntil = 2025-07-22 - today = 82 days
   - Still no alert

8. If lastSvcDate was "2025-04-24":
   - nextDate = 2025-04-24 + 3 months = 2025-07-24
   - daysUntil = 2025-07-24 - today = 84 days
   - Still no alert

9. If lastSvcDate was "2025-04-25":
   - nextDate = 2025-04-25 + 3 months = 2025-07-25
   - daysUntil = 2025-07-25 - today = 85 days
   - Still no alert

10. If lastSvcDate was "2025-04-26":
    - nextDate = 2025-04-26 + 3 months = 2025-07-26
    - daysUntil = 2025-07-26 - today = 86 days
    - Still no alert

11. If lastSvcDate was "2025-04-27":
    - nextDate = 2025-04-27 + 3 months = 2025-07-27
    - daysUntil = 2025-07-27 - today = 87 days
    - Still no alert

12. If lastSvcDate was "2025-04-28":
    - nextDate = 2025-04-28 + 3 months = 2025-07-28
    - daysUntil = 2025-07-28 - today = 88 days
    - Still no alert

13. If lastSvcDate was "2025-04-29":
    - nextDate = 2025-04-29 + 3 months = 2025-07-29
    - daysUntil = 2025-07-29 - today = 89 days
    - Still no alert

14. If lastSvcDate was "2025-04-30":
    - nextDate = 2025-04-30 + 3 months = 2025-07-30
    - daysUntil = 2025-07-30 - today = 90 days
    - Still no alert

15. If lastSvcDate was "2025-03-29":
    - nextDate = 2025-03-29 + 3 months = 2025-06-29
    - daysUntil = 2025-06-29 - today = 59 days
    - Still no alert

16. If lastSvcDate was "2025-03-28":
    - nextDate = 2025-03-28 + 3 months = 2025-06-28
    - daysUntil = 2025-06-28 - today = 58 days
    - Still no alert

17. If lastSvcDate was "2025-03-15":
    - nextDate = 2025-03-15 + 3 months = 2025-06-15
    - daysUntil = 2025-06-15 - today = 45 days
    - Still no alert

18. If lastSvcDate was "2025-03-01":
    - nextDate = 2025-03-01 + 3 months = 2025-06-01
    - daysUntil = 2025-06-01 - today = 31 days
    - Still no alert

19. If lastSvcDate was "2025-02-15":
    - nextDate = 2025-02-15 + 3 months = 2025-05-15
    - daysUntil = 2025-05-15 - today = 14 days
    - Alert: "📅 PMS Due This Week"

20. If lastSvcDate was "2025-02-01":
    - nextDate = 2025-02-01 + 3 months = 2025-05-01
    - daysUntil = 2025-05-01 - today = 0 days
    - Alert: "⚠️ PMS Due Soon"

21. If lastSvcDate was "2025-01-15":
    - nextDate = 2025-01-15 + 3 months = 2025-04-15
    - daysUntil = 2025-04-15 - today = -16 days
    - Alert: "🚨 PMS Overdue"
```

---

## Security Considerations

1. **Authentication:**
   - All Cloud Functions require Firebase authentication
   - OneSignal login uses Firebase UID

2. **Authorization:**
   - Only authenticated users can call functions
   - Users can only see their own notifications

3. **Data Privacy:**
   - Notifications stored in Firestore for audit trail
   - Read status tracked per user
   - No sensitive data in notification body

4. **API Security:**
   - OneSignal REST API Key stored in Cloud Functions
   - Not exposed to client
   - HTTPS only

---

## Performance Considerations

1. **Notification Delivery:**
   - OneSignal handles delivery (typically 5-10 seconds)
   - Batch sending for multiple users

2. **DSS Alerts:**
   - Runs every hour (configurable)
   - Processes all stock and vehicles
   - Sends alerts in parallel

3. **Firestore Queries:**
   - Indexed by role for fast queries
   - Batch operations for efficiency

---

## Monitoring & Debugging

### Cloud Functions Logs
```
Firebase Console → Functions → Logs
```

Look for:
- ✅ "Notifications sent to X users via OneSignal"
- ❌ Error messages
- ⏱️ Execution time

### OneSignal Dashboard
```
https://dashboard.onesignal.com/
```

Check:
- Messages tab for delivery status
- Delivery rate and engagement
- Error messages

### Firestore
```
Firebase Console → Firestore → Collections
```

Check:
- Notification documents created
- User documents have correct roles
- Stock and vehicle data

---

## Troubleshooting Checklist

- [ ] Firebase project upgraded to Blaze plan
- [ ] Cloud Functions deployed successfully
- [ ] OneSignal App ID correct in code
- [ ] OneSignal REST API Key correct
- [ ] Users have correct role field
- [ ] Users logged in with Firebase UID
- [ ] Notification documents have all required fields
- [ ] Device has notification permission enabled
- [ ] Check Cloud Functions logs for errors
- [ ] Check OneSignal Dashboard for delivery status

