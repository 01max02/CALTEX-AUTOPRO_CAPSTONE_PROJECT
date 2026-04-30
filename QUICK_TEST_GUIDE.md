# Quick Test Guide - DSS Push Notifications

## Prerequisites
- ✅ Flutter app updated with OneSignal
- ✅ Cloud Functions deployed (after Blaze upgrade)
- ✅ Firebase project upgraded to Blaze plan
- ✅ OneSignal account created

---

## How DSS Alerts Work (from admin_dss.dart)

### Stock Priority Logic (3-Tier)
| Priority | Condition | Color | Decision |
|----------|-----------|-------|----------|
| **Out of Stock** | `stock == 0` | 🔴 Red | URGENT: Emergency order |
| **Low Stock** | `stock <= min` | 🟡 Yellow | SOON: Plan to order |
| **Adequate** | `stock > min` | 🟢 Green | MONITOR: No action needed |

### PMS Priority Logic
| Priority | Condition |
|----------|-----------|
| **Overdue** | `daysUntil < 0` |
| **Due Soon** | `daysUntil <= 7` |
| **Due Soon** | `daysUntil <= 14` |
| **Scheduled** | `daysUntil <= 30` |
| **On Track** | `daysUntil > 30` |

> Only **Overdue**, **Due Soon** (≤7 days), and **Due Soon** (≤14 days) trigger push notifications.

---

## Test 1: Out of Stock Alert (Admin)

Simulates a stock item with `stock = 0` → triggers **URGENT: Emergency order**.

In Firestore `/notifications`, create a document:

```
title   : "🚨 URGENT: Out of Stock"
message : "Engine Oil (ITEM-001) is out of stock. Recommend ordering 50 L."
type    : "warning"
targetRole : "admin"
targetUid  : ""
createdAt  : (server timestamp)
```

**Expected result:** All admin users receive a red-badge notification within 5–10 seconds.

---

## Test 2: Low Stock Alert (Admin)

Simulates a stock item where `stock <= min` → triggers **SOON: Plan to order**.

```
title   : "⚠️ Low Stock Alert"
message : "Air Filter (ITEM-002) is low (3 pcs). Recommend ordering 20 pcs."
type    : "warning"
targetRole : "admin"
targetUid  : ""
createdAt  : (server timestamp)
```

**Expected result:** All admin users receive a yellow-badge notification.

---

## Test 3: PMS Overdue Alert (Admin)

Simulates a vehicle where `daysUntil < 0` → triggers **Overdue** priority.

```
title   : "🚨 PMS Overdue"
message : "ABC-123 is 5 day(s) overdue for maintenance."
type    : "warning"
targetRole : "admin"
targetUid  : ""
createdAt  : (server timestamp)
```

**Expected result:** All admin users receive a red notification.

---

## Test 4: PMS Due Soon Alert (Admin)

Simulates a vehicle where `daysUntil <= 7` → triggers **Due Soon** priority.

```
title   : "⚠️ PMS Due Soon"
message : "XYZ-456 is due for maintenance in 3 day(s)."
type    : "warning"
targetRole : "admin"
targetUid  : ""
createdAt  : (server timestamp)
```

**Expected result:** All admin users receive an orange notification.

---

## Test 5: PMS Due This Week Alert (Admin)

Simulates a vehicle where `daysUntil <= 14` → triggers **Due Soon** (this week) priority.

```
title   : "📅 PMS Due This Week"
message : "DEF-789 is due for maintenance this week (10 days)."
type    : "info"
targetRole : "admin"
targetUid  : ""
createdAt  : (server timestamp)
```

**Expected result:** All admin users receive a blue notification.

---

## Test 6: Customer PMS Alert (Specific User)

Simulates a customer's own vehicle being overdue.

1. Get the customer's Firebase UID from Firebase Console → Authentication
2. Create this document:

```
title   : "🚨 Your PMS is Overdue"
message : "Your ABC-123 is 5 day(s) overdue for maintenance."
type    : "warning"
targetRole : ""
targetUid  : "CUSTOMER-UID-HERE"
createdAt  : (server timestamp)
```

**Expected result:** Only that specific customer receives the notification.

---

## Test 7: Customer PMS Due Soon (Specific User)

```
title   : "⚠️ Your PMS is Due Soon"
message : "Your XYZ-456 is due for maintenance in 3 day(s)."
type    : "warning"
targetRole : ""
targetUid  : "CUSTOMER-UID-HERE"
createdAt  : (server timestamp)
```

---

## Test 8: Automatic DSS Alerts (Runs Every Hour)

The `checkDSSAlerts` Cloud Function runs automatically every hour and checks real Firestore data — same logic as `admin_dss.dart`.

### To trigger manually (after Cloud Functions deployed):
1. Go to Firebase Console → Functions
2. Find `checkDSSAlerts`
3. Click "Test function" or wait for the next hour

### What it checks automatically:
- Reads `/stock_inventory` collection
- Reads `/issuances` collection → calculates consumption rate
- Reads `/vehicles` collection → calculates days until next PMS
- Sends alerts only for items that match the priority thresholds above

### To create test data that will trigger alerts:

**Stock test data** — add to `/stock_inventory`:
```
num   : "TEST-001"
name  : "Test Engine Oil"
stock : 0          ← triggers Out of Stock
min   : 10
max   : 50
reorder : 30
uom   : "L"
```

**PMS test data** — add to `/vehicles`:
```
plate      : "TEST-001"
desc       : "Test Vehicle"
lastSvcDate: "2025-01-01"   ← old date → triggers Overdue
svcFreq    : "3"            ← 3 months
```

---

## How to Add Documents in Firestore

1. Go to [Firebase Console](https://console.firebase.google.com/) → Firestore Database
2. Click the `notifications` collection (create it if it doesn't exist)
3. Click **Add document**
4. Leave document ID as **(auto-ID)**
5. Add each field:
   - `title` → **string**
   - `message` → **string**
   - `type` → **string** (`warning`, `info`, or `success`)
   - `targetRole` → **string** (`admin`, `staff`, `customer`, or leave empty)
   - `targetUid` → **string** (user UID or leave empty)
   - `createdAt` → **timestamp** → click "Server timestamp"
6. Click **Save**

The `sendNotifications` Cloud Function fires automatically when the document is created.

---

## Notification Type Reference

| `type` value | Color in app | Use case |
|-------------|-------------|---------|
| `warning` | 🟠 Orange | Stock alerts, PMS overdue/due soon |
| `info` | 🔵 Blue | PMS due this week, general info |
| `success` | 🟢 Green | Service complete, confirmations |

---

## Target Reference

| `targetRole` | `targetUid` | Who receives it |
|-------------|-------------|----------------|
| `"admin"` | `""` | All admins |
| `"staff"` | `""` | All staff |
| `"customer"` | `""` | All customers |
| `""` | `"uid-123"` | Specific user only |
| `""` | `""` | All users |

---

## Success Indicators

✅ **It's working when:**
1. Notification appears on device within 5–10 seconds
2. OneSignal Dashboard → Messages shows "Delivered"
3. Firebase Console → Functions → Logs shows: `Notifications sent to X users via OneSignal`
4. App shows notification in the Notifications screen
5. System notification appears when app is closed

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No notification on device | Check device notification permission, verify user is logged in |
| Cloud Functions won't deploy | Firebase must be on Blaze plan |
| "No users found" in logs | Check users have correct `role` field in Firestore |
| Notification sent but not delivered | Check OneSignal Dashboard for delivery status |
| Document created but no notification | Check Cloud Functions logs for errors |

---

## Check Logs

**Firebase Console → Functions → Logs**
Look for:
- ✅ `Notifications sent to X users via OneSignal`
- ❌ Any error messages in `sendNotifications` or `checkDSSAlerts`

**OneSignal Dashboard → Messages**
- Check delivery status per notification
- See which users received it
