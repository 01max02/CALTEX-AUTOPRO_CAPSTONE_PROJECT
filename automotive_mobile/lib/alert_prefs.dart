/// alert_prefs.dart
///
/// Shared helper for reading user alert preferences from Firestore
/// and filtering recipient lists based on those preferences.
///
/// Used by admin_dss.dart, background_dss.dart, and notifications.dart
/// so that push notifications respect each user's Manage Alerts settings.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Loads alert preferences for a single user from Firestore.
/// Returns a map of prefKey → bool (defaults to true if not set).
Future<Map<String, bool>> loadAlertPrefs(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('alerts')
        .get();
    final data = doc.data() ?? {};
    return {
      'pmsOverdue':     data['pmsOverdue']     as bool? ?? true,
      'pmsDueSoon':     data['pmsDueSoon']     as bool? ?? true,
      'pmsDueThisWeek': data['pmsDueThisWeek'] as bool? ?? true,
      'lowStock':       data['lowStock']       as bool? ?? true,
      'serviceUpdate':  data['serviceUpdate']  as bool? ?? true,
      'newAssignment':  data['newAssignment']  as bool? ?? true,
    };
  } catch (e) {
    debugPrint('⚠️ loadAlertPrefs($uid) error: $e');
    // Default all to true on error so alerts are not silently dropped
    return {
      'pmsOverdue': true, 'pmsDueSoon': true, 'pmsDueThisWeek': true,
      'lowStock': true, 'serviceUpdate': true, 'newAssignment': true,
    };
  }
}

/// Given a list of Firebase UIDs, returns only those whose alert preference
/// for [prefKey] is true (or not set — defaults to true).
///
/// Loads prefs for each UID individually so each user's setting is respected.
Future<List<String>> filterByPref(
  List<String> uids,
  String prefKey,
) async {
  if (uids.isEmpty) return [];
  final enabled = <String>[];
  for (final uid in uids) {
    final prefs = await loadAlertPrefs(uid);
    if (prefs[prefKey] == true) enabled.add(uid);
  }
  return enabled;
}
