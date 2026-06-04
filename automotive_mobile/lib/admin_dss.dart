import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'alert_prefs.dart';

// ── OneSignal credentials ──
const _kOneSignalAppId  = 'c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea';
const _kOneSignalApiKey = 'os_v7_app_yt4cvr2f1hkhvh5ldu4k637i51snjeyuythen3fd61ae1yhnprpy6kbxvn9kjd1pqdhygsqmlrouas4kfuydft32nkgj5flbra3oo5q';

/// Resolves Firebase UIDs → OneSignal subscription IDs stored in Firestore,
/// then sends a push notification via the OneSignal REST API.
///
/// Uses `include_subscription_ids` (free plan compatible) instead of
/// `include_external_user_ids` (requires paid plan).
Future<void> _sendViaOneSignal({
  required List<String> userIds,   // Firebase UIDs
  required String title,
  required String message,
  String type = 'info',
}) async {
  if (userIds.isEmpty) return;
  try {
    // Look up OneSignal subscription IDs from Firestore
    final subIds = <String>[];
    for (final uid in userIds) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final subId = doc.data()?['oneSignalId'] as String?;
      if (subId != null && subId.isNotEmpty) subIds.add(subId);
    }

    if (subIds.isEmpty) {
      debugPrint('⚠️ OneSignal: no subscription IDs found for UIDs: $userIds');
      return;
    }

    final res = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Authorization': 'Basic $_kOneSignalApiKey',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'app_id': _kOneSignalAppId,
        'include_subscription_ids': subIds,
        'headings': {'en': title},
        'contents': {'en': message},
        'data': {'type': type},
      }),
    );
    debugPrint('📤 OneSignal → ${res.statusCode}: ${res.body}');
  } catch (e) {
    debugPrint('❌ OneSignal send error: $e');
  }
}

class AdminDSS extends StatefulWidget {
  final int initialTab;
  const AdminDSS({super.key, this.initialTab = 0});

  @override
  State<AdminDSS> createState() => _AdminDSSState();
}

class _AdminDSSState extends State<AdminDSS> {
  static const _red = Color(0xFFE8001C);
  static const _blue = Color(0xFF003087);
  late int _tab;

  static List<Map<String, String>> _stockItemsCache = [];
  static List<Map<String, String>> _pmsAssetsCache = [];

  static bool _alertsSentThisSession = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendDSSAlerts());
  }

  /// Force-resend DSS alerts (bypasses both in-memory and Firestore dedup).
  Future<void> _forceResendAlerts() async {
    _alertsSentThisSession = false;
    // Delete today's sentinel so Firestore dedup is also bypassed
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await FirebaseFirestore.instance
        .collection('dss_alert_log')
        .doc(todayKey)
        .delete();
    await _sendDSSAlerts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DSS alerts refreshed and sent')),
      );
    }
  }

  /// Reads stock + PMS data and sends alerts directly via OneSignal + Firestore.
  /// No Cloud Functions needed - direct API calls.
  Future<void> _sendDSSAlerts() async {
    if (_alertsSentThisSession) return;
    _alertsSentThisSession = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;

    // ── Deduplication: only send alerts once per calendar day ──
    // Check if we already wrote alerts today by looking for a sentinel doc.
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final sentinelRef =
        db.collection('dss_alert_log').doc(todayKey);
    final sentinelSnap = await sentinelRef.get();
    if (sentinelSnap.exists) {
      debugPrint('⏭ DSS alerts already sent today ($todayKey), skipping');
      return;
    }
    // Mark as sent for today immediately (before writing alerts, to prevent
    // race conditions if the user opens the screen twice quickly)
    await sentinelRef.set({'sentAt': FieldValue.serverTimestamp()});
    try {
      // Get all admin UIDs for push targeting
      final adminSnap = await db.collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      final adminIds = adminSnap.docs.map((d) => d.id).toList();

      // ── STOCK ALERTS ──
      final stockSnap = await db.collection('stock_inventory').get();
      final issuancesSnap = await db.collection('issuances').get();

      // Build consumption map
      final consumptionMap = <String, List<Map<String, dynamic>>>{};
      for (final d in issuancesSnap.docs) {
        final data = d.data();
        final itemNum = data['itemNum'] as String? ?? '';
        final rawQty = data['qty'] ?? data['quantity'];
        final qty = rawQty is num
            ? rawQty.toDouble()
            : double.tryParse(rawQty?.toString() ?? '') ?? 0.0;
        final dateStr = data['date'] as String? ?? '';
        if (itemNum.isEmpty || qty <= 0) continue;
        consumptionMap.putIfAbsent(itemNum, () => []);
        consumptionMap[itemNum]!.add({'date': dateStr, 'qty': qty});
      }

      final now = DateTime.now();

      for (final doc in stockSnap.docs) {
        final data = doc.data();
        final itemNum = (data['num'] as String?) ?? (data['itemNum'] as String?) ?? doc.id;
        final stock   = (data['stock']  as num?)?.toInt() ?? 0;
        final min     = (data['min']    as num?)?.toInt() ?? 0;
        final max     = (data['max']    as num?)?.toInt() ?? 0;
        final reorder = (data['reorder'] as num?)?.toInt() ?? 0;
        final name    = data['name'] as String? ?? itemNum;
        final uom     = data['uom'] as String? ?? '';

        final records = consumptionMap[itemNum] ?? [];
        final totalConsumed = records.fold<double>(0.0, (s, r) => s + (r['qty'] as num).toDouble());

        DateTime? earliest;
        for (final r in records) {
          final d2 = _parseIssuanceDate(r['date'] as String? ?? '');
          if (d2 != null && (earliest == null || d2.isBefore(earliest!))) earliest = d2;
        }

        final daySpan = earliest != null
            ? (now.difference(earliest!).inMilliseconds / 86400000).ceil().clamp(1, 999999)
            : 30;
        final dailyRate = totalConsumed > 0 ? totalConsumed / daySpan : 0.0;
        final deficit = (max - stock).clamp(0, 999999);
        final recommendQty = deficit > reorder ? deficit : reorder;

        if (stock == 0) {
          // Only push to admins who have lowStock alerts enabled
          final targets = await filterByPref(adminIds, 'lowStock');
          await db.collection('notifications').add({
            'title': '🚨 URGENT: Out of Stock',
            'message': '$name is out of stock. Recommend ordering $recommendQty $uom.',
            'type': 'warning',
            'targetRole': 'admin',
            'targetUid': '',
            'createdAt': FieldValue.serverTimestamp(),
            'readBy': <String, bool>{},
            'isRead': false,
          });
          if (targets.isNotEmpty) {
            await _sendViaOneSignal(
              userIds: targets,
              title: '🚨 URGENT: Out of Stock',
              message: '$name is out of stock. Recommend ordering $recommendQty $uom.',
              type: 'warning',
            );
          }
        } else if (stock <= min) {
          // Only push to admins who have lowStock alerts enabled
          final targets = await filterByPref(adminIds, 'lowStock');
          await db.collection('notifications').add({
            'title': '⚠️ Low Stock Alert',
            'message': '$name is low ($stock $uom). Recommend ordering $recommendQty $uom.',
            'type': 'warning',
            'targetRole': 'admin',
            'targetUid': '',
            'createdAt': FieldValue.serverTimestamp(),
            'readBy': <String, bool>{},
            'isRead': false,
          });
          if (targets.isNotEmpty) {
            await _sendViaOneSignal(
              userIds: targets,
              title: '⚠️ Low Stock Alert',
              message: '$name is low ($stock $uom). Recommend ordering $recommendQty $uom.',
              type: 'warning',
            );
          }
        }
      }

      // ── PMS ALERTS ──
      final vehiclesSnap = await db.collection('vehicles').get();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      for (final vDoc in vehiclesSnap.docs) {
        final data = vDoc.data();
        final plate       = data['plate'] as String? ?? '';
        final lastSvcDate = data['lastSvcDate'] as String? ?? '';
        final svcFreq     = int.tryParse(data['svcFreq']?.toString() ?? '');

        if (lastSvcDate.isEmpty || svcFreq == null || plate.isEmpty) continue;

        final lastDate = DateTime.tryParse(lastSvcDate);
        if (lastDate == null) continue;

        final nextDate     = DateTime(lastDate.year, lastDate.month + svcFreq, lastDate.day);
        final nextMidnight = DateTime(nextDate.year, nextDate.month, nextDate.day);
        final daysUntil    = nextMidnight.difference(todayMidnight).inDays;

        // Admin PMS alerts — filter by pref before pushing
        if (daysUntil < 0) {
          final targets = await filterByPref(adminIds, 'pmsOverdue');
          await db.collection('notifications').add({
            'title': '🚨 PMS Overdue',
            'message': '$plate is ${(-daysUntil)} day(s) overdue for maintenance.',
            'type': 'warning',
            'targetRole': 'admin',
            'targetUid': '',
            'createdAt': FieldValue.serverTimestamp(),
            'readBy': <String, bool>{},
            'isRead': false,
          });
          if (targets.isNotEmpty) {
            await _sendViaOneSignal(
              userIds: targets,
              title: '🚨 PMS Overdue',
              message: '$plate is ${(-daysUntil)} day(s) overdue for maintenance.',
              type: 'warning',
            );
          }
        } else if (daysUntil == 0) {
          final targets = await filterByPref(adminIds, 'pmsDueThisWeek');
          await db.collection('notifications').add({
            'title': '🔔 PMS Due Today',
            'message': '$plate is due for maintenance today.',
            'type': 'warning',
            'targetRole': 'admin',
            'targetUid': '',
            'createdAt': FieldValue.serverTimestamp(),
            'readBy': <String, bool>{},
            'isRead': false,
          });
          if (targets.isNotEmpty) {
            await _sendViaOneSignal(
              userIds: targets,
              title: '🔔 PMS Due Today',
              message: '$plate is due for maintenance today.',
              type: 'warning',
            );
          }
        } else if (daysUntil <= 7) {
          final targets = await filterByPref(adminIds, 'pmsDueThisWeek');
          await db.collection('notifications').add({
            'title': '📅 PMS Due This Week',
            'message': '$plate is due for maintenance this week ($daysUntil day(s)).',
            'type': 'warning',
            'targetRole': 'admin',
            'targetUid': '',
            'createdAt': FieldValue.serverTimestamp(),
            'readBy': <String, bool>{},
            'isRead': false,
          });
          if (targets.isNotEmpty) {
            await _sendViaOneSignal(
              userIds: targets,
              title: '📅 PMS Due This Week',
              message: '$plate is due for maintenance this week ($daysUntil day(s)).',
              type: 'warning',
            );
          }
        } else if (daysUntil <= 14) {
          final targets = await filterByPref(adminIds, 'pmsDueSoon');
          await db.collection('notifications').add({
            'title': '⚠️ PMS Due Soon',
            'message': '$plate is due for maintenance in $daysUntil day(s).',
            'type': 'info',
            'targetRole': 'admin',
            'targetUid': '',
            'createdAt': FieldValue.serverTimestamp(),
            'readBy': <String, bool>{},
            'isRead': false,
          });
          if (targets.isNotEmpty) {
            await _sendViaOneSignal(
              userIds: targets,
              title: '⚠️ PMS Due Soon',
              message: '$plate is due for maintenance in $daysUntil day(s).',
              type: 'info',
            );
          }
        }

        // Customer PMS alerts — respect their own pref settings
        final ownerId = data['ownerId'] as String? ?? data['customerId'] as String?;
        if (ownerId != null && ownerId.isNotEmpty) {
          final ownerDoc = await db.collection('users').doc(ownerId).get();
          if (!ownerDoc.exists) continue;

          if (daysUntil < 0) {
            final targets = await filterByPref([ownerId], 'pmsOverdue');
            await db.collection('notifications').add({
              'title': '🚨 Your PMS is Overdue',
              'message': 'Your $plate is ${(-daysUntil)} day(s) overdue for maintenance.',
              'type': 'warning',
              'targetRole': '',
              'targetUid': ownerId,
              'createdAt': FieldValue.serverTimestamp(),
              'readBy': <String, bool>{},
              'isRead': false,
            });
            if (targets.isNotEmpty) {
              await _sendViaOneSignal(
                userIds: targets,
                title: '🚨 Your PMS is Overdue',
                message: 'Your $plate is ${(-daysUntil)} day(s) overdue for maintenance.',
                type: 'warning',
              );
            }
          } else if (daysUntil == 0) {
            final targets = await filterByPref([ownerId], 'pmsDueThisWeek');
            await db.collection('notifications').add({
              'title': '🔔 Your PMS is Due Today',
              'message': 'Your $plate is due for maintenance today.',
              'type': 'warning',
              'targetRole': '',
              'targetUid': ownerId,
              'createdAt': FieldValue.serverTimestamp(),
              'readBy': <String, bool>{},
              'isRead': false,
            });
            if (targets.isNotEmpty) {
              await _sendViaOneSignal(
                userIds: targets,
                title: '🔔 Your PMS is Due Today',
                message: 'Your $plate is due for maintenance today.',
                type: 'warning',
              );
            }
          } else if (daysUntil <= 7) {
            final targets = await filterByPref([ownerId], 'pmsDueThisWeek');
            await db.collection('notifications').add({
              'title': '📅 Your PMS is Due This Week',
              'message': 'Your $plate is due for maintenance this week ($daysUntil day(s)).',
              'type': 'warning',
              'targetRole': '',
              'targetUid': ownerId,
              'createdAt': FieldValue.serverTimestamp(),
              'readBy': <String, bool>{},
              'isRead': false,
            });
            if (targets.isNotEmpty) {
              await _sendViaOneSignal(
                userIds: targets,
                title: '📅 Your PMS is Due This Week',
                message: 'Your $plate is due for maintenance this week ($daysUntil day(s)).',
                type: 'warning',
              );
            }
          } else if (daysUntil <= 14) {
            final targets = await filterByPref([ownerId], 'pmsDueSoon');
            await db.collection('notifications').add({
              'title': '⚠️ Your PMS is Due Soon',
              'message': 'Your $plate is due for maintenance in $daysUntil day(s).',
              'type': 'info',
              'targetRole': '',
              'targetUid': ownerId,
              'createdAt': FieldValue.serverTimestamp(),
              'readBy': <String, bool>{},
              'isRead': false,
            });
            if (targets.isNotEmpty) {
              await _sendViaOneSignal(
                userIds: targets,
                title: '⚠️ Your PMS is Due Soon',
                message: 'Your $plate is due for maintenance in $daysUntil day(s).',
                type: 'info',
              );
            }
          }
        }
      }

      debugPrint('✅ DSS alerts sent from AdminDSS screen');
    } catch (e) {
      debugPrint('❌ Error sending DSS alerts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Decision Support System',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            tooltip: 'Print Report',
            onPressed: () {
              if (_tab == 0) {
                _printCriticalItems(_stockItemsCache);
              } else {
                _printPMSReport(_pmsAssetsCache);
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _tabBtn('Stock Replenishment', 0),
            _tabBtn('PMS Scheduling', 1),
          ]),
        ),
        Expanded(child: _tab == 0 ? _buildStockDSS() : _buildPMSDSS()),
      ]),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final active = _tab == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? _red : Colors.transparent, width: 2))),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active ? _red : const Color(0xFF718096))),
      ),
    ));
  }

  Widget _buildStockDSS() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('stock_inventory').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('issuances').snapshots(),
          builder: (context, issSnap) {
            // Build consumption map: itemNum -> list of {date, qty}
            final consumptionMap = <String, List<Map<String, dynamic>>>{};
            if (issSnap.hasData) {
              for (final d in issSnap.data!.docs) {
                final data = d.data() as Map<String, dynamic>;
                final itemNum = data['itemNum'] as String? ?? '';
                // qty stored as String or num
                final rawQty = data['qty'] ?? data['quantity'];
                final qty = rawQty is num
                    ? rawQty.toDouble()
                    : double.tryParse(rawQty?.toString() ?? '') ?? 0.0;
                final dateStr = data['date'] as String? ?? '';
                if (itemNum.isEmpty || qty <= 0) continue;
                consumptionMap.putIfAbsent(itemNum, () => []);
                consumptionMap[itemNum]!.add({'date': dateStr, 'qty': qty});
              }
            }

            final today = DateTime.now();
            // Keep todayMidnight only for PMS date comparisons elsewhere
            final todayMidnight = DateTime(today.year, today.month, today.day);

            final items = docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final itemNum = (data['num'] as String?)
                           ?? (data['itemNum'] as String?)
                           ?? d.id;
              final stock   = (data['stock']  as num?)?.toInt() ?? 0;
              final min     = (data['min']    as num?)?.toInt() ?? 0;
              final max     = (data['max']    as num?)?.toInt() ?? 0;
              final reorder = (data['reorder'] as num?)?.toInt() ?? 0;
              final uom     = data['uom'] as String? ?? '';

              // ── Consumption rate — mirrors website dssAnalyze() ──
              final records = consumptionMap[itemNum] ?? [];

              // totalConsumed: sum all qty records
              final double totalConsumed = records.fold(
                0.0, (s, r) => s + (r['qty'] as num).toDouble());

              // earliest date among all issuance records for this item
              DateTime? earliest;
              for (final r in records) {
                final d2 = _parseIssuanceDate(r['date'] as String? ?? '');
                if (d2 != null && (earliest == null || d2.isBefore(earliest!))) {
                  earliest = d2;
                }
              }

              // daySpan: Math.max(1, Math.ceil((today - earliest) / 86400000))
              // Website uses full timestamp for today (new Date()), earliest is UTC midnight
              // from ISO date string. We mirror this: today has time, earliest is midnight.
              final int daySpan = earliest != null
                  ? (today.difference(earliest!).inMilliseconds / 86400000)
                        .ceil()
                        .clamp(1, 999999)
                  : 30;

              // dailyRate: totalConsumed / daySpan  (0 if no data)
              final double dailyRate =
                  totalConsumed > 0 ? totalConsumed / daySpan : 0.0;

              // daysLeft: Math.floor(stock / dailyRate)
              final int daysLeft = dailyRate > 0
                  ? (stock / dailyRate).floor()
                  : (stock > 0 ? 999 : 0);

              // ── Priority — 3-Tier Color-Coded System ──
              // 0 = Out of Stock  🔴 Red    (stock = 0)
              // 1 = Low Stock     🟡 Yellow (stock ≤ min qty)
              // 2 = Adequate      🟢 Green  (stock > min qty)
              final int priorityScore;
              final String priorityLabel;
              if (stock == 0) {
                priorityScore = 0;
                priorityLabel = 'Out of Stock';
              } else if (stock <= min) {
                priorityScore = 1;
                priorityLabel = 'Low Stock';
              } else {
                priorityScore = 2;
                priorityLabel = 'Adequate';
              }

              // Lead time demand (7-day buffer)
              final int leadTimeDemand = dailyRate > 0 ? (dailyRate * 7).ceil() : 0;

              // Recommended order qty — shown for Out of Stock and Low Stock only
              final int deficit      = (max - stock).clamp(0, 999999);
              final int recommendQty = priorityScore <= 1
                  ? (deficit > reorder ? deficit : reorder)
                  : 0;

              return {
                'name':            data['name'] as String? ?? '—',
                'itemNum':         itemNum,
                'uom':             uom,
                'stock':           '$stock $uom',
                'max':             '$max',
                'min':             '$min',
                'reorderQty':      '$reorder',
                'days':            daysLeft < 999
                    ? '$daysLeft days'
                    : (stock > 0 ? '—' : '0 days'),
                'order':           priorityScore <= 1 && recommendQty > 0
                    ? '$recommendQty $uom'
                    : '—',
                'priority':        priorityLabel,
                'priorityScore':   '$priorityScore',
                'group':           data['group'] as String? ?? '—',
                'consumptionRate': dailyRate > 0
                    ? '${dailyRate.toStringAsFixed(2)} $uom/day'
                    : '—',
                'totalConsumed':   totalConsumed > 0
                    ? '${totalConsumed % 1 == 0 ? totalConsumed.toInt() : totalConsumed.toStringAsFixed(1)} $uom'
                    : '—',
                'leadNeed':        leadTimeDemand > 0 ? '$leadTimeDemand $uom' : '—',
              };
            }).toList()
              ..sort((a, b) {
                // Sort: Out of Stock(0) > Critical(1) > Low Stock(2) > Adequate(3) > Overstock(4)
                final aScore = int.tryParse(a['priorityScore'] ?? '3') ?? 3;
                final bScore = int.tryParse(b['priorityScore'] ?? '3') ?? 3;
                return aScore.compareTo(bScore);
              });

            _stockItemsCache = items;
            return _buildStockDSSContent(items);
          },
        );
      },
    );
  }

  Widget _buildStockDSSContent(List<Map<String, String>> items) {
    return Column(children: [
      // ── KPI chips ──
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(children: [
          Row(children: [
            _kpiChip('Out of Stock', '${items.where((i) => i['priority'] == 'Out of Stock').length}', const Color(0xFFe53e3e), Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            _kpiChip('Low Stock', '${items.where((i) => i['priority'] == 'Low Stock').length}', const Color(0xFFd69e2e), Icons.trending_down_outlined),
            const SizedBox(width: 8),
            _kpiChip('Adequate', '${items.where((i) => i['priority'] == 'Adequate').length}', const Color(0xFF38a169), Icons.check_circle_outline),
          ]),
        ]),
      ),
      // ── Item list ──
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _buildStockCard(items[i]),
        ),
      ),
    ]);
  }

  /// Card layout that mirrors the website table row:
  /// Item name/num/group | Stock bar | Consumption | Days Left | Order | Priority | Decision
  Widget _buildStockCard(Map<String, String> item) {
    final priority = item['priority'] ?? 'Adequate';
    final color = _priorityColor(priority);
    final isCritical = priority == 'Out of Stock';
    // Parse stock numbers for the progress bar
    final stockRaw   = item['stock'] ?? '0';
    final stockNum   = int.tryParse(stockRaw.split(' ').first) ?? 0;
    final maxRaw     = item['max'] ?? '0';
    final maxNum     = int.tryParse(maxRaw) ?? 0;
    final minRaw     = item['min'] ?? '0';
    final reorderRaw = item['reorderQty'] ?? '0';
    final stockPct   = (maxNum > 0) ? (stockNum / maxNum).clamp(0.0, 1.0) : 0.0;

    // Decision text — 3-tier system
    final String decision;
    final IconData decisionIcon;
    switch (priority) {
      case 'Out of Stock':
        decision = 'URGENT: Emergency order';
        decisionIcon = Icons.warning_rounded;
        break;
      case 'Low Stock':
        decision = 'SOON: Plan to order';
        decisionIcon = Icons.schedule_outlined;
        break;
      default:
        decision = 'MONITOR: No action needed';
        decisionIcon = Icons.check_circle_outline;
    }

    return GestureDetector(
      onTap: () => _showStockDetails(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isCritical ? Border.all(color: _red.withOpacity(0.25)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Row 1: Item name + priority badge ──
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  '${item['itemNum'] ?? ''}${item['itemNum'] != null && item['group'] != null ? '  ·  ' : ''}${item['group'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
                ),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(priority.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFe2e8f0)),
            const SizedBox(height: 12),

            // ── Row 2: Stock status ──
            _sectionLabel('STOCK STATUS'),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                stockRaw.split(' ').first,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ ${item['max'] ?? '—'} ${item['uom'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stockPct,
                minHeight: 6,
                backgroundColor: const Color(0xFFe2e8f0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Min: ${item['min'] ?? '—'}  ·  Reorder pt: ${item['reorderQty'] ?? '—'}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF718096)),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFe2e8f0)),
            const SizedBox(height: 12),

            // ── Row 3: Consumption | Days Left | Order ──
            Row(children: [
              // Consumption Rate
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionLabel('CONSUMPTION RATE'),
                const SizedBox(height: 4),
                RichText(text: TextSpan(
                  children: [
                    TextSpan(
                      // consumptionRate is "0.25 L/day" — extract just the number
                      text: (item['consumptionRate'] ?? '—') != '—'
                          ? (item['consumptionRate']!.split(' ').first)
                          : '—',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1a202c)),
                    ),
                    if ((item['consumptionRate'] ?? '—') != '—')
                      const TextSpan(
                        text: ' /day',
                        style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
                      ),
                  ],
                )),
                const SizedBox(height: 2),
                Text(
                  'Used: ${item['totalConsumed'] ?? '—'}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF718096)),
                ),
              ])),

              // Days Left
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionLabel('DAYS OF STOCK LEFT'),
                const SizedBox(height: 4),
                Text(
                  item['days'] ?? '—',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: (item['days'] ?? '—') == '—' ? const Color(0xFF718096) : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lead need: ${item['leadNeed'] ?? '—'}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF718096)),
                ),
              ])),

              // Recommended Order
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionLabel('RECOMMENDED ORDER'),
                const SizedBox(height: 4),
                Text(
                  item['order'] ?? '—',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: (item['order'] ?? '—') == '—'
                        ? const Color(0xFF718096)
                        : color,
                  ),
                ),
              ])),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFe2e8f0)),
            const SizedBox(height: 10),

            // ── Row 4: Decision ──
            Row(children: [
              Icon(decisionIcon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(decision, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Out of Stock':
        return const Color(0xFFe53e3e);   // 🔴 Red
      case 'Low Stock':
        return const Color(0xFFd69e2e);   // 🟡 Yellow
      default:
        return const Color(0xFF38a169);   // 🟢 Green (Adequate)
    }
  }

  Widget _sectionLabel(String text) {
    return Text(text,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
        color: Color(0xFF718096), letterSpacing: 0.5));
  }

  Future<void> _printCriticalItems(List<Map<String, String>> items) async {
    final critical = items.where((i) => i['priority'] == 'Critical').toList();
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    // Load logo
    final logoBytes = await rootBundle.load('assets/img/LOGO_CALTEX.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final letterBytes = await rootBundle.load('assets/img/CALTEX_LETTER.png');
    final letterImage = pw.MemoryImage(letterBytes.buffer.asUint8List());

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(children: [
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 10),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Image(letterImage, height: 18),
                    pw.SizedBox(height: 2),
                    pw.Text('AutoPro Fleet Management',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ]),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Stock Replenishment Report',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1a202c))),
                  pw.SizedBox(height: 2),
                  pw.Text('Date Generated: $dateStr',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ]),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: const PdfColor.fromInt(0xFFE8001C), thickness: 1.5),
            pw.SizedBox(height: 16),

            // ── Report Title ──
            pw.Text('Critical Stock Items — Immediate Reorder Required',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF1a202c))),
            pw.SizedBox(height: 4),
            pw.Text(
              'The following ${critical.length} item(s) have critically low stock levels and require immediate procurement action.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 18),

            // ── Table ──
            pw.Table(
              border: pw.TableBorder(
                top: const pw.BorderSide(color: PdfColor.fromInt(0xFF003087), width: 1.5),
                bottom: const pw.BorderSide(color: PdfColor.fromInt(0xFF003087), width: 1.5),
                horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF003087)),
                  children: ['Item Name', 'Commodity Group', 'Recommended Order Qty']
                    .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9,
                          letterSpacing: 0.3)),
                    )).toList(),
                ),
                // Rows
                ...critical.asMap().entries.map((e) {
                  final item = e.value;
                  final isEven = e.key % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF7F8FA),
                    ),
                    children: [item['name']!, item['group']!, item['order']!]
                      .asMap().entries.map((ce) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: pw.Text(ce.value,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: ce.key == 2 ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: ce.key == 2
                              ? const PdfColor.fromInt(0xFFE8001C)
                              : const PdfColor.fromInt(0xFF1a202c),
                          )),
                      )).toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── Note ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border(left: const pw.BorderSide(color: PdfColor.fromInt(0xFFE8001C), width: 3)),
                color: const PdfColor.fromInt(0xFFFFF5F5),
              ),
              child: pw.Text(
                'Note: Items listed above are critically low. Immediate reordering is recommended to avoid service disruption.',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF4a5568)),
              ),
            ),

            pw.Spacer(),

            // ── Footer ──
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Caltex AutoPro — Decision Support System',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
                pw.Text('Page 1 of 1  •  $dateStr',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
              ],
            ),
          ],
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _printPMSReport(List<Map<String, String>> assets) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    final logoBytes = await rootBundle.load('assets/img/LOGO_CALTEX.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final letterBytes = await rootBundle.load('assets/img/CALTEX_LETTER.png');
    final letterImage = pw.MemoryImage(letterBytes.buffer.asUint8List());

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(children: [
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 10),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Image(letterImage, height: 18),
                    pw.SizedBox(height: 2),
                    pw.Text('AutoPro Fleet Management',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ]),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('PMS Scheduling Report',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1a202c))),
                  pw.SizedBox(height: 2),
                  pw.Text('Date Generated: $dateStr',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ]),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: const PdfColor.fromInt(0xFFE8001C), thickness: 1.5),
            pw.SizedBox(height: 16),
            pw.Text('Preventive Maintenance Schedule',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF1a202c))),
            pw.SizedBox(height: 4),
            pw.Text('${assets.length} vehicle(s) listed below.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 18),
            pw.Table(
              border: pw.TableBorder(
                top: const pw.BorderSide(color: PdfColor.fromInt(0xFF003087), width: 1.5),
                bottom: const pw.BorderSide(color: PdfColor.fromInt(0xFF003087), width: 1.5),
                horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF003087)),
                  children: ['Plate', 'Description', 'Last Service', 'Next PMS Due', 'Priority']
                    .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                      child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    )).toList(),
                ),
                ...assets.asMap().entries.map((e) {
                  final a = e.value;
                  final isEven = e.key % 2 == 0;
                  final priorityColor = a['priority'] == 'Overdue'
                    ? const PdfColor.fromInt(0xFFE8001C)
                    : a['priority'] == 'Due Today'
                      ? const PdfColor.fromInt(0xFFc05621)
                    : a['priority'] == 'Due This Week'
                      ? const PdfColor.fromInt(0xFFdd6b20)
                    : a['priority'] == 'Due Soon'
                      ? const PdfColor.fromInt(0xFFb7791f)
                      : const PdfColor.fromInt(0xFF276749);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF7F8FA)),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: pw.Text(a['plate']!, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: pw.Text(a['desc']!, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: pw.Text(a['lastService']!, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: pw.Text(a['nextPMS']!, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: pw.Text(a['priority']!,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: priorityColor))),
                    ],
                  );
                }),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Caltex AutoPro — Decision Support System',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
                pw.Text('Page 1 of 1  •  $dateStr',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
              ],
            ),
          ],
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  pw.Widget _pdfChip(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(value, style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
      ]),
    );
  }

  void _showStockDetails(Map<String, String> item) {
    final priority = item['priority'] ?? 'Adequate';
    final color = _priorityColor(priority);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.55, maxChildSize: 0.8,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['name']!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(item['group'] ?? '—', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFe2e8f0))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('📦  STOCK INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF718096), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _detailRow('Item Name', item['name']!),
                    _detailRow('Commodity Group', item['group']!),
                    _detailRow('Priority', item['priority']!),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFe2e8f0))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('📊  ANALYSIS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF718096), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _statBox('Current Stock', item['stock']!, const Color(0xFFebf8ff), const Color(0xFF003087)),
                      const SizedBox(width: 8),
                      _statBox('Consumption', item['consumptionRate']!, const Color(0xFFfff5f5), const Color(0xFFE8001C)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _statBox('Days Left', item['days']!, const Color(0xFFfffaf0), const Color(0xFFdd6b20)),
                      const SizedBox(width: 8),
                      _statBox('Order Qty', item['order']!, const Color(0xFFe6fffa), const Color(0xFF2c7a7b)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Close'),
                  )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPMSDSS() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final assets = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final plate = data['plate'] as String? ?? '';
          final desc = data['desc'] as String? ?? '';
          final lastSvcDate = data['lastSvcDate'] as String? ?? '';
          final svcFreq = data['svcFreq'] as String? ?? '';
          final lastDate = DateTime.tryParse(lastSvcDate);
          final months = int.tryParse(svcFreq);

          String due = '—';
          String priority = 'Active';
          String nextPMS = '—';
          String lastService = lastSvcDate.isNotEmpty ? lastSvcDate : '—';

          if (lastDate != null && months != null) {
            final next = DateTime(lastDate.year, lastDate.month + months, lastDate.day);
            nextPMS = '${next.year}-${next.month.toString().padLeft(2,'0')}-${next.day.toString().padLeft(2,'0')}';
            // Strip time from both dates (midnight) to match website calculation
            final today = DateTime(now.year, now.month, now.day);
            final nextMidnight = DateTime(next.year, next.month, next.day);
            final daysUntil = nextMidnight.difference(today).inDays;
            if (daysUntil < 0) {
              due = 'Overdue ${(-daysUntil)} day(s)';
              priority = 'Overdue';
            } else if (daysUntil == 0) {
              due = 'Due today';
              priority = 'Due Today';
            } else if (daysUntil <= 7) {
              due = 'Due in $daysUntil day(s)';
              priority = 'Due This Week';
            } else if (daysUntil <= 14) {
              due = 'Due in $daysUntil days';
              priority = 'Due Soon';
            } else {
              due = 'Due in $daysUntil days';
              priority = 'Active';
            }
          }

          return {
            'plate': plate,
            'desc': desc,
            'due': due,
            'priority': priority,
            'lastService': lastService,
            'nextPMS': nextPMS,
          };
        }).toList()
          ..sort((a, b) {
            const order = {'Overdue': 0, 'Due Today': 1, 'Due This Week': 2, 'Due Soon': 3, 'Active': 4};
            return (order[a['priority']] ?? 5).compareTo(order[b['priority']] ?? 5);
          });

        _pmsAssetsCache = assets;
        return _buildPMSDSSContent(assets);
      },
    );
  }

  Widget _buildPMSDSSContent(List<Map<String, String>> assets) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(children: [
          Row(children: [
            _kpiChip('Overdue', '${assets.where((a) => a['priority'] == 'Overdue').length}', _red, Icons.error_outline),
            const SizedBox(width: 8),
            _kpiChip('Due Today', '${assets.where((a) => a['priority'] == 'Due Today').length}', const Color(0xFFc05621), Icons.schedule_outlined),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _kpiChip('Due This Week', '${assets.where((a) => a['priority'] == 'Due This Week').length}', const Color(0xFFdd6b20), Icons.calendar_today_outlined),
            const SizedBox(width: 8),
            _kpiChip('Due Soon', '${assets.where((a) => a['priority'] == 'Due Soon').length}', const Color(0xFFb7791f), Icons.event_outlined),
            const SizedBox(width: 8),
            _kpiChip('Active', '${assets.where((a) => a['priority'] == 'Active').length}', const Color(0xFF276749), Icons.check_circle_outline),
          ]),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: assets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = assets[i];
            final color = a['priority'] == 'Overdue' ? _red
                : a['priority'] == 'Due Today' ? const Color(0xFFc05621)
                : a['priority'] == 'Due This Week' ? const Color(0xFFdd6b20)
                : a['priority'] == 'Due Soon' ? const Color(0xFFb7791f)
                : const Color(0xFF276749); // Active
            return GestureDetector(
              onTap: () => _showPMSDetails(a),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a['plate']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(a['desc']!, style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568))),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.schedule_outlined, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(a['due']!, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                        ]),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(a['priority']!, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 18, color: Color(0xFFa0aec0)),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  void _showPMSDetails(Map<String, String> a) {
    final color = a['priority'] == 'Overdue' ? _red
        : a['priority'] == 'Due Today' ? const Color(0xFFc05621)
        : a['priority'] == 'Due This Week' ? const Color(0xFFdd6b20)
        : a['priority'] == 'Due Soon' ? const Color(0xFFb7791f)
        : const Color(0xFF276749); // Active
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.55, maxChildSize: 0.8,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['plate']!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(a['desc']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFe2e8f0))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🚗  VEHICLE INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF718096), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _detailRow('Plate Number', a['plate']!),
                    _detailRow('Description', a['desc']!),
                    _detailRow('Priority', a['priority']!),
                    _detailRow('Status', a['due']!),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFe2e8f0))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🔧  MAINTENANCE SCHEDULE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF718096), letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _statBox('Last Service', a['lastService']!, const Color(0xFFF7F8FA), const Color(0xFF1a202c)),
                      const SizedBox(width: 8),
                      _statBox('Next PMS Due', a['nextPMS']!, color.withOpacity(0.08), color),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Close'),
                  )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// Parses issuance date strings in multiple formats:
  /// - "YYYY-MM-DD"  (website HTML date input, ISO — JS parses as UTC midnight)
  /// - "M/D/YYYY"   (mobile app: '${now.month}/${now.day}/${now.year}')
  /// - "Jan 1, 2025" (JS toLocaleDateString fallback)
  ///
  /// Returns UTC midnight to match JS `new Date("YYYY-MM-DD")` behaviour,
  /// so that `today.difference(earliest)` mirrors `today - earliest` in JS.
  static DateTime? _parseIssuanceDate(String s) {
    if (s.isEmpty) return null;
    // Try ISO first: "2025-04-29" → UTC midnight (matches JS new Date("2025-04-29"))
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      // DateTime.tryParse on "YYYY-MM-DD" returns local midnight in Dart.
      // Convert to UTC midnight to match JS behaviour.
      return DateTime.utc(iso.year, iso.month, iso.day);
    }
    // Try M/D/YYYY or MM/DD/YYYY: "4/29/2026", "04/29/2026"
    final slashParts = s.split('/');
    if (slashParts.length == 3) {
      final m = int.tryParse(slashParts[0]);
      final d = int.tryParse(slashParts[1]);
      final y = int.tryParse(slashParts[2]);
      if (m != null && d != null && y != null) {
        return DateTime.utc(y, m, d);
      }
    }
    // Try "Jan 1, 2025" (JS en-US locale format)
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final localeMatch = RegExp(r'^(\w+)\s+(\d+),\s+(\d{4})$').firstMatch(s.trim());
    if (localeMatch != null) {
      final mon = months[localeMatch.group(1)!.toLowerCase().substring(0, 3)];
      final day = int.tryParse(localeMatch.group(2)!);
      final yr  = int.tryParse(localeMatch.group(3)!);
      if (mon != null && day != null && yr != null) {
        return DateTime.utc(yr, mon, day);
      }
    }
    return null;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096), fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1a202c)))),
      ]),
    );
  }

  Widget _statBox(String label, String value, Color bg, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF718096), fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: valueColor), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF718096)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _kpiChip(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF718096)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _dssInfo(String label, String value) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF718096))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]));
  }
}
