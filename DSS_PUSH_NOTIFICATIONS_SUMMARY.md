# DSS Push Notifications - Implementation Summary

## What's Been Set Up

### ✅ Automated DSS Alerts (Cloud Function)
A scheduled Cloud Function that runs **every hour** to check for critical alerts and automatically sends push notifications.

---

## Alert Types

### For ADMINS 👨‍💼

**Stock Alerts:**
- 🚨 **Out of Stock** - When item stock = 0
  - Message: "Item name is out of stock. Immediate reorder needed."
  - Recommended action: Emergency order

- ⚠️ **Low Stock** - When item stock ≤ minimum level
  - Message: "Item name is low (X UOM). Recommend ordering Y UOM."
  - Recommended action: Plan to order

**PMS Alerts:**
- 🚨 **PMS Overdue** - When vehicle maintenance is past due date
  - Message: "Plate is X day(s) overdue for maintenance."
  - Recommended action: Schedule immediately

- ⚠️ **PMS Due Soon** - When vehicle maintenance due within 7 days
  - Message: "Plate is due for maintenance in X day(s)."
  - Recommended action: Schedule soon

- 📅 **PMS Due This Week** - When vehicle maintenance due within 14 days
  - Message: "Plate is due for maintenance this week (X days)."
  - Recommended action: Monitor

---

### For CUSTOMERS 👤

**PMS Alerts (Only for their own vehicles):**
- 🚨 **Your PMS is Overdue** - When their vehicle maintenance is past due
  - Message: "Your Plate is X day(s) overdue for maintenance."

- ⚠️ **Your PMS is Due Soon** - When their vehicle maintenance due within 7 days
  - Message: "Your Plate is due for maintenance in X day(s)."

- 📅 **Your PMS is Due This Week** - When their vehicle maintenance due within 14 days
  - Message: "Your Plate is due for maintenance this week (X days)."

---

## How It Works

### Data Flow

```
1. Every hour (scheduled)
   ↓
2. Cloud Function `checkDSSAlerts` runs
   ↓
3. Reads from Firestore:
   - stock_inventory collection (for stock levels)
   - issuances collection (for consumption rates)
   - vehicles collection (for PMS schedules)
   - users collection (for FCM tokens)
   ↓
4. Calculates:
   - Stock priority (Out of Stock, Low Stock, Adequate)
   - PMS status (Overdue, Due Soon, Due This Week, On Track)
   ↓
5. Sends push notifications via FCM
   - To admins: All alerts
   - To customers: Only their vehicle PMS alerts
   ↓
6. Notifications appear on device
   (even if app is closed)
```

---

## Firestore Collections Required

### 1. `stock_inventory`
```json
{
  "num": "ITEM-001",
  "name": "Engine Oil 5L",
  "stock": 10,
  "min": 5,
  "max": 50,
  "reorder": 20,
  "uom": "L",
  "group": "Lubricants"
}
```

### 2. `issuances`
```json
{
  "itemNum": "ITEM-001",
  "qty": 2,
  "date": "2026-04-29"
}
```

### 3. `vehicles`
```json
{
  "plate": "ABC-123",
  "desc": "Toyota Camry 2024",
  "lastSvcDate": "2026-03-15",
  "svcFreq": "3",
  "ownerId": "customer-user-id"
}
```

### 4. `users`
```json
{
  "role": "admin",
  "fcmToken": "token-from-firebase-messaging"
}
```

---

## Testing

### Manual Test (Firebase Console)

1. Go to **Firebase Console** → **Functions**
2. Click on `checkDSSAlerts`
3. Click **"Testing"** tab
4. Click **"Execute"**
5. Check your device notification tray

### Automatic Test

1. Make sure app is closed
2. Wait for the next hour mark
3. Check device notification tray
4. You should see alerts for critical items

---

## Configuration

### Change Alert Frequency

To change from every 1 hour to a different schedule:

**In `functions/index.js`:**
```javascript
// Current: every 1 hour
exports.checkDSSAlerts = functions.pubsub.schedule('every 1 hours').onRun(...)

// Change to:
// Every 30 minutes
exports.checkDSSAlerts = functions.pubsub.schedule('every 30 minutes').onRun(...)

// Every 6 hours
exports.checkDSSAlerts = functions.pubsub.schedule('every 6 hours').onRun(...)

// Daily at 8 AM
exports.checkDSSAlerts = functions.pubsub.schedule('0 8 * * *').onRun(...)
```

### Change Alert Thresholds

**For PMS alerts:**
```javascript
// Current: 7 days for "Due Soon", 14 days for "Due This Week"
if (daysUntil < 0) {
  // Overdue
} else if (daysUntil <= 7) {
  // Due Soon
} else if (daysUntil <= 14) {
  // Due This Week
}

// Change to:
// 3 days for "Due Soon", 7 days for "Due This Week"
if (daysUntil < 0) {
  // Overdue
} else if (daysUntil <= 3) {
  // Due Soon
} else if (daysUntil <= 7) {
  // Due This Week
}
```

---

## Troubleshooting

### Notifications Not Appearing?

1. **Check FCM Token**
   - Go to Firestore → users collection
   - Verify user has `fcmToken` field
   - If empty, restart the app

2. **Check Permissions**
   - Android: Settings → Notifications → App enabled
   - iOS: Settings → Notifications → App enabled

3. **Check Cloud Function Logs**
   - Firebase Console → Functions → Logs
   - Look for errors in `checkDSSAlerts`

4. **Check Data**
   - Verify `stock_inventory` has items with stock ≤ min
   - Verify `vehicles` has items with PMS due soon
   - Verify `users` have `fcmToken` saved

5. **Check Firestore Rules**
   - Cloud Function needs read access to all collections
   - Default rules should allow this

---

## Next Steps

1. ✅ Cloud Function deployed
2. ✅ Scheduled to run every hour
3. 📝 Verify Firestore collections have data
4. 🧪 Test on your device
5. 🔧 Adjust alert thresholds if needed
6. 🚀 Monitor logs for any issues

---

## Files Modified

- `automotive_mobile/functions/index.js` - Added `checkDSSAlerts` function
- `PUSH_NOTIFICATIONS_SETUP.md` - Updated documentation

