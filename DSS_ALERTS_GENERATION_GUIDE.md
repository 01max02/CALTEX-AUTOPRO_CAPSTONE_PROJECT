# DSS Alerts Generation Guide

## Overview

Added a new function `generateDSSAlerts()` to notifications.dart that automatically generates and sends accurate push notifications based on real DSS data from Firestore.

---

## What It Does

### Analyzes Real Data:
1. **Stock Inventory** - Checks current stock levels
2. **Issuances** - Calculates consumption rates
3. **Vehicles** - Checks PMS schedules
4. **Users** - Gets admin and customer info

### Generates Accurate Alerts:

**For ADMINS:**
- 🚨 **Out of Stock** - When stock = 0
- ⚠️ **Low Stock** - When stock ≤ minimum
- 🚨 **PMS Overdue** - When maintenance is past due
- ⚠️ **PMS Due Soon** - When due within 7 days
- 📅 **PMS Due This Week** - When due within 14 days

**For CUSTOMERS:**
- 🚨 **Your PMS is Overdue** - Their vehicle is overdue
- ⚠️ **Your PMS is Due Soon** - Their vehicle due within 7 days
- 📅 **Your PMS is Due This Week** - Their vehicle due within 14 days

---

## How to Use

### Option 1: Call from Admin Dashboard

Add a button to trigger alerts:

```dart
// In admin_dss.dart or any admin screen
ElevatedButton(
  onPressed: () async {
    // Get notifications state
    final notificationsState = context.findAncestorStateOfType<_AppNotificationsState>();
    await notificationsState?.generateDSSAlerts();
  },
  child: const Text('Generate DSS Alerts'),
)
```

### Option 2: Call from Notifications Screen

```dart
// In notifications.dart
FloatingActionButton(
  onPressed: () => generateDSSAlerts(),
  child: const Icon(Icons.notifications_active),
)
```

### Option 3: Automatic on App Start

```dart
// In notifications.dart initState
@override
void initState() {
  super.initState();
  _initializeFCM();
  _setupNotificationsCollection();
  _refreshFCMToken();
  // Auto-generate alerts on app start
  Future.delayed(const Duration(seconds: 2), () => generateDSSAlerts());
}
```

---

## Example Usage

### Scenario 1: Admin Generates Alerts

1. Admin opens app
2. Clicks "Generate DSS Alerts" button
3. Function analyzes all data
4. Creates notifications in Firestore
5. Cloud Function sends push notifications
6. Admins receive alerts on their devices

### Scenario 2: Automatic Generation

1. App starts
2. After 2 seconds, `generateDSSAlerts()` runs
3. Checks for critical items and overdue PMS
4. Creates notifications automatically
5. Admins and customers receive alerts

---

## Data Accuracy

The function uses the **exact same logic** as admin_dss.dart:

### Stock Calculation:
```dart
// Consumption rate calculation
final records = consumptionMap[itemNum] ?? [];
final totalConsumed = records.fold(0.0, (s, r) => s + r['qty']);
final daySpan = (now.difference(earliest).inMilliseconds / 86400000).ceil();
final dailyRate = totalConsumed / daySpan;
```

### PMS Calculation:
```dart
// PMS due date calculation
final nextDate = DateTime(lastDate.year, lastDate.month + svcFreq, lastDate.day);
final daysUntil = nextMidnight.difference(today).inDays;

if (daysUntil < 0) {
  // Overdue
} else if (daysUntil <= 7) {
  // Due Soon
} else if (daysUntil <= 14) {
  // Due This Week
}
```

---

## Testing

### Test 1: Generate Alerts Manually

1. Open app
2. Go to Notifications screen
3. Call `generateDSSAlerts()`
4. Check Firestore → notifications collection
5. Verify notifications were created
6. Close app and check device notification tray

### Test 2: Verify Data Accuracy

1. Open admin_dss.dart
2. Check stock items and PMS schedules
3. Call `generateDSSAlerts()`
4. Compare generated notifications with DSS data
5. Verify they match exactly

### Test 3: Check Recipient Accuracy

1. Verify admins receive all alerts
2. Verify customers only receive their vehicle alerts
3. Check FCM tokens are saved for all users

---

## Troubleshooting

### Alerts Not Generated?

1. Check if `generateDSSAlerts()` is being called
2. Check Flutter console for errors
3. Verify Firestore has data in:
   - `stock_inventory`
   - `issuances`
   - `vehicles`
   - `users`

### Alerts Generated but Not Received?

1. Check if FCM tokens are saved
2. Check device notifications are enabled
3. Check Firebase Console → Functions → Logs
4. Verify `sendNotifications` Cloud Function is working

### Wrong Data in Alerts?

1. Verify consumption calculation matches admin_dss.dart
2. Check issuance dates are in correct format
3. Verify vehicle PMS schedules are correct
4. Check user ownerId/customerId fields

---

## Integration Points

### In admin_dss.dart:
```dart
// Add button to generate alerts
IconButton(
  icon: const Icon(Icons.notifications_active),
  onPressed: () {
    // Call generateDSSAlerts from notifications state
  },
)
```

### In admin_dashboard.dart:
```dart
// Add alert generation to dashboard
ElevatedButton(
  onPressed: () => generateDSSAlerts(),
  child: const Text('Send Alerts'),
)
```

### In main.dart or app initialization:
```dart
// Auto-generate alerts on app start
Future.delayed(const Duration(seconds: 2), () {
  notificationsState.generateDSSAlerts();
});
```

---

## Performance Notes

- Function reads from multiple collections
- May take 2-5 seconds to complete
- Creates multiple notification documents
- Triggers Cloud Function for each notification
- Best to run during off-peak hours or on-demand

---

## Next Steps

1. ✅ Function is ready to use
2. 📝 Add button to trigger alerts
3. 🧪 Test with real data
4. 🚀 Deploy to production
5. 📊 Monitor alert accuracy

