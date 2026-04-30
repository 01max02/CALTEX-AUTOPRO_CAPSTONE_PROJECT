/// background_dss.dart
///
/// Runs entirely in a background isolate (via workmanager).
/// NO Flutter widgets, NO BuildContext — only Dart + Firebase + HTTP.
///
/// Called by workmanager every ~15 minutes even when the app is closed/killed.
/// Respects each user's alert preferences from users/{uid}/settings/alerts.

import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

// ── OneSignal credentials ──
const _kOneSignalAppId  = 'c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea';
const _kOneSignalApiKey =
    'os_v7_app_yt4cvr2f1hkhvh5ldu4k637i51snjeyuythen3fd61ae1yhnprpy6kbxvn9kjd1pqdhygsqmlrouas4kfuydft32nkgj5flbra3oo5q';

@pragma('vm:entry-point')
void backgroundDSSCallback() {}

/// The actual work. Called by workmanager's executeTask callback in main.dart.
Future<bool> runBackgroundDSSCheck() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⏭ Background DSS: no user signed in, skipping');
      return true;
    }

    final db  = FirebaseFirestore.instance;
    final now = DateTime.now();

    // ── Deduplication: once per calendar day ──
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sentinelRef  = db.collection('dss_alert_log').doc('bg_$todayKey');
    final sentinelSnap = await sentinelRef.get();
    if (sentinelSnap.exists) {
      debugPrint('⏭ Background DSS: already ran today ($todayKey), skipping');
      return true;
    }
    await sentinelRef.set({'sentAt': FieldValue.serverTimestamp()});

    // ── Get all admin UIDs ──
    final adminSnap = await db.collection('users').where('role', isEqualTo: 'admin').get();
    final adminIds  = adminSnap.docs.map((d) => d.id).toList();
    if (adminIds.isEmpty) {
      debugPrint('⏭ Background DSS: no admin users found');
      return true;
    }

    // ── STOCK ALERTS ──
    final stockSnap     = await db.collection('stock_inventory').get();
    final issuancesSnap = await db.collection('issuances').get();

    final consumptionMap = <String, List<Map<String, dynamic>>>{};
    for (final d in issuancesSnap.docs) {
      final data    = d.data();
      final itemNum = data['itemNum'] as String? ?? '';
      final rawQty  = data['qty'] ?? data['quantity'];
      final qty     = rawQty is num
          ? rawQty.toDouble()
          : double.tryParse(rawQty?.toString() ?? '') ?? 0.0;
      final dateStr = data['date'] as String? ?? '';
      if (itemNum.isEmpty || qty <= 0) continue;
      consumptionMap.putIfAbsent(itemNum, () => []);
      consumptionMap[itemNum]!.add({'date': dateStr, 'qty': qty});
    }

    for (final doc in stockSnap.docs) {
      final data    = doc.data();
      final itemNum = (data['num'] as String?) ?? (data['itemNum'] as String?) ?? doc.id;
      final stock   = (data['stock']  as num?)?.toInt() ?? 0;
      final min     = (data['min']    as num?)?.toInt() ?? 0;
      final max     = (data['max']    as num?)?.toInt() ?? 0;
      final reorder = (data['reorder'] as num?)?.toInt() ?? 0;
      final name    = data['name'] as String? ?? itemNum;
      final uom     = data['uom'] as String? ?? '';

      final records       = consumptionMap[itemNum] ?? [];
      final totalConsumed = records.fold<double>(0.0, (s, r) => s + (r['qty'] as num).toDouble());

      DateTime? earliest;
      for (final r in records) {
        final d2 = _parseDate(r['date'] as String? ?? '');
        if (d2 != null && (earliest == null || d2.isBefore(earliest!))) earliest = d2;
      }

      final daySpan      = earliest != null
          ? (now.difference(earliest!).inMilliseconds / 86400000).ceil().clamp(1, 999999)
          : 30;
      final deficit      = (max - stock).clamp(0, 999999);
      final recommendQty = deficit > reorder ? deficit : reorder;

      if (stock == 0) {
        final targets = await _filterByPref(db, adminIds, 'lowStock');
        await _sendAlert(
          db: db, targets: targets,
          title: '🚨 URGENT: Out of Stock',
          message: '$name is out of stock. Recommend ordering $recommendQty $uom.',
          type: 'warning', targetRole: 'admin',
        );
      } else if (stock <= min) {
        final targets = await _filterByPref(db, adminIds, 'lowStock');
        await _sendAlert(
          db: db, targets: targets,
          title: '⚠️ Low Stock Alert',
          message: '$name is low ($stock $uom). Recommend ordering $recommendQty $uom.',
          type: 'warning', targetRole: 'admin',
        );
      }
    }

    // ── PMS ALERTS ──
    final vehiclesSnap  = await db.collection('vehicles').get();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    for (final vDoc in vehiclesSnap.docs) {
      final data        = vDoc.data();
      final plate       = data['plate'] as String? ?? '';
      final lastSvcDate = data['lastSvcDate'] as String? ?? '';
      final svcFreq     = int.tryParse(data['svcFreq']?.toString() ?? '');

      if (lastSvcDate.isEmpty || svcFreq == null || plate.isEmpty) continue;
      final lastDate = DateTime.tryParse(lastSvcDate);
      if (lastDate == null) continue;

      final nextDate     = DateTime(lastDate.year, lastDate.month + svcFreq, lastDate.day);
      final nextMidnight = DateTime(nextDate.year, nextDate.month, nextDate.day);
      final daysUntil    = nextMidnight.difference(todayMidnight).inDays;

      // Admin PMS alerts — respect pmsOverdue / pmsDueSoon prefs
      if (daysUntil < 0) {
        final targets = await _filterByPref(db, adminIds, 'pmsOverdue');
        await _sendAlert(
          db: db, targets: targets,
          title: '🚨 PMS Overdue',
          message: '$plate is ${(-daysUntil)} day(s) overdue for maintenance.',
          type: 'warning', targetRole: 'admin',
        );
      } else if (daysUntil <= 7) {
        final targets = await _filterByPref(db, adminIds, 'pmsDueThisWeek');
        await _sendAlert(
          db: db, targets: targets,
          title: '📅 PMS Due This Week',
          message: '$plate is due for maintenance this week ($daysUntil day(s)).',
          type: 'warning', targetRole: 'admin',
        );
      } else if (daysUntil <= 14) {
        final targets = await _filterByPref(db, adminIds, 'pmsDueSoon');
        await _sendAlert(
          db: db, targets: targets,
          title: '⚠️ PMS Due Soon',
          message: '$plate is due for maintenance in $daysUntil day(s).',
          type: 'info', targetRole: 'admin',
        );
      }

      // Customer PMS alerts — respect their own prefs
      final ownerId = data['ownerId'] as String? ?? data['customerId'] as String?;
      if (ownerId != null && ownerId.isNotEmpty) {
        final ownerDoc = await db.collection('users').doc(ownerId).get();
        if (!ownerDoc.exists) continue;

        if (daysUntil < 0) {
          final targets = await _filterByPref(db, [ownerId], 'pmsOverdue');
          await _sendAlert(
            db: db, targets: targets,
            title: '🚨 Your PMS is Overdue',
            message: 'Your $plate is ${(-daysUntil)} day(s) overdue for maintenance.',
            type: 'warning', targetRole: '', targetUid: ownerId,
          );
        } else if (daysUntil <= 7) {
          final targets = await _filterByPref(db, [ownerId], 'pmsDueThisWeek');
          await _sendAlert(
            db: db, targets: targets,
            title: '📅 Your PMS is Due This Week',
            message: 'Your $plate is due for maintenance this week ($daysUntil day(s)).',
            type: 'warning', targetRole: '', targetUid: ownerId,
          );
        } else if (daysUntil <= 14) {
          final targets = await _filterByPref(db, [ownerId], 'pmsDueSoon');
          await _sendAlert(
            db: db, targets: targets,
            title: '⚠️ Your PMS is Due Soon',
            message: 'Your $plate is due for maintenance in $daysUntil day(s).',
            type: 'info', targetRole: '', targetUid: ownerId,
          );
        }
      }
    }

    debugPrint('✅ Background DSS check complete');
    return true;
  } catch (e) {
    debugPrint('❌ Background DSS error: $e');
    return false;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Filters UIDs to only those who have [prefKey] enabled in their alert prefs.
/// Defaults to true (included) if the pref doc doesn't exist.
Future<List<String>> _filterByPref(
  FirebaseFirestore db,
  List<String> uids,
  String prefKey,
) async {
  if (uids.isEmpty) return [];
  final enabled = <String>[];
  for (final uid in uids) {
    try {
      final doc = await db
          .collection('users').doc(uid)
          .collection('settings').doc('alerts')
          .get();
      final val = doc.data()?[prefKey] as bool? ?? true;
      if (val) enabled.add(uid);
    } catch (_) {
      enabled.add(uid); // include on error — don't silently drop
    }
  }
  return enabled;
}

/// Writes to Firestore (in-app display) and pushes via OneSignal.
/// Only pushes to [targets] — already filtered by pref.
Future<void> _sendAlert({
  required FirebaseFirestore db,
  required List<String> targets,   // pref-filtered Firebase UIDs
  required String title,
  required String message,
  required String type,
  String targetRole = '',
  String targetUid  = '',
}) async {
  // Always write to Firestore so in-app list shows it
  await db.collection('notifications').add({
    'title':      title,
    'message':    message,
    'type':       type,
    'targetRole': targetRole,
    'targetUid':  targetUid,
    'createdAt':  FieldValue.serverTimestamp(),
  });

  if (targets.isEmpty) return;

  // Resolve UIDs → OneSignal subscription IDs
  final subIds = <String>[];
  for (final uid in targets) {
    try {
      final doc   = await db.collection('users').doc(uid).get();
      final subId = doc.data()?['oneSignalId'] as String?;
      if (subId != null && subId.isNotEmpty) subIds.add(subId);
    } catch (_) {}
  }

  if (subIds.isEmpty) {
    debugPrint('⚠️ OneSignal BG: no subscription IDs for $targets');
    return;
  }

  try {
    final res = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Authorization': 'Basic $_kOneSignalApiKey',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'app_id':                    _kOneSignalAppId,
        'include_subscription_ids':  subIds,
        'headings':                  {'en': title},
        'contents':                  {'en': message},
        'data':                      {'type': type},
      }),
    );
    debugPrint('📤 OneSignal BG → ${res.statusCode}: ${res.body}');
  } catch (e) {
    debugPrint('❌ OneSignal BG send error: $e');
  }
}

DateTime? _parseDate(String s) {
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return DateTime.utc(iso.year, iso.month, iso.day);
  final parts = s.split('/');
  if (parts.length == 3) {
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (m != null && d != null && y != null) return DateTime.utc(y, m, d);
  }
  const months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  final m = RegExp(r'^(\w+)\s+(\d+),\s+(\d{4})$').firstMatch(s.trim());
  if (m != null) {
    final mon = months[m.group(1)!.toLowerCase().substring(0, 3)];
    final day = int.tryParse(m.group(2)!);
    final yr  = int.tryParse(m.group(3)!);
    if (mon != null && day != null && yr != null) return DateTime.utc(yr, mon, day);
  }
  return null;
}
