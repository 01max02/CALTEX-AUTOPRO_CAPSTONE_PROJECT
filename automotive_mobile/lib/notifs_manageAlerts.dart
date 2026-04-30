import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ManageAlertsRole { customer, staff, admin }

class ManageAlertsScreen extends StatefulWidget {
  final ManageAlertsRole role;
  const ManageAlertsScreen({super.key, this.role = ManageAlertsRole.customer});

  @override
  State<ManageAlertsScreen> createState() => _ManageAlertsScreenState();
}

class _ManageAlertsScreenState extends State<ManageAlertsScreen> {
  static const _red = Color(0xFFE8001C);

  bool _loading = true;
  bool _saving  = false;

  // Alert preferences
  bool _pmsOverdue    = true;
  bool _pmsDueSoon    = true;
  bool _pmsDueThisWeek = true;
  bool _serviceUpdate = true;
  bool _lowStock      = true;
  bool _newAssignment = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('settings').doc('alerts')
        .get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    setState(() {
      _pmsOverdue     = data['pmsOverdue']     as bool? ?? true;
      _pmsDueSoon     = data['pmsDueSoon']     as bool? ?? true;
      _pmsDueThisWeek = data['pmsDueThisWeek'] as bool? ?? true;
      _serviceUpdate  = data['serviceUpdate']  as bool? ?? true;
      _lowStock       = data['lowStock']       as bool? ?? true;
      _newAssignment  = data['newAssignment']  as bool? ?? true;
      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'pmsOverdue':     _pmsOverdue,
        'pmsDueSoon':     _pmsDueSoon,
        'pmsDueThisWeek': _pmsDueThisWeek,
        'updatedAt':      FieldValue.serverTimestamp(),
      };
      if (widget.role == ManageAlertsRole.staff || widget.role == ManageAlertsRole.admin) {
        payload['serviceUpdate'] = _serviceUpdate;
        payload['newAssignment'] = _newAssignment;
      }
      if (widget.role == ManageAlertsRole.admin) {
        payload['lowStock'] = _lowStock;
      }

      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('settings').doc('alerts')
          .set(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Alert preferences saved!'),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaffOrAdmin = widget.role == ManageAlertsRole.staff || widget.role == ManageAlertsRole.admin;
    final isAdmin = widget.role == ManageAlertsRole.admin;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Manage Alerts',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _savePrefs,
              child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Vehicle Alerts (all roles) ──
                _sectionLabel('VEHICLE ALERTS'),
                const SizedBox(height: 8),
                _alertCard([
                  _alertTile(
                    icon: Icons.error_outline,
                    color: Colors.red,
                    title: 'PMS Overdue',
                    sub: 'Notify when a vehicle is overdue for maintenance (< 0 days)',
                    value: _pmsOverdue,
                    onChanged: (v) => setState(() => _pmsOverdue = v),
                  ),
                  _alertTile(
                    icon: Icons.calendar_today_outlined,
                    color: Colors.orange,
                    title: 'PMS Due This Week',
                    sub: 'Notify when PMS is due within 7 days',
                    value: _pmsDueThisWeek,
                    onChanged: (v) => setState(() => _pmsDueThisWeek = v),
                  ),
                  _alertTile(
                    icon: Icons.schedule_outlined,
                    color: Colors.amber.shade700,
                    title: 'PMS Due Soon',
                    sub: 'Notify when PMS is due within 14 days',
                    value: _pmsDueSoon,
                    onChanged: (v) => setState(() => _pmsDueSoon = v),
                    isLast: true,
                  ),
                ]),

                // ── Service Alerts (staff & admin only) ──
                if (isStaffOrAdmin) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('SERVICE ALERTS'),
                  const SizedBox(height: 8),
                  _alertCard([
                    _alertTile(
                      icon: Icons.build_outlined,
                      color: Colors.green,
                      title: 'Service Updates',
                      sub: 'Notify on service status changes',
                      value: _serviceUpdate,
                      onChanged: (v) => setState(() => _serviceUpdate = v),
                    ),
                    _alertTile(
                      icon: Icons.assignment_outlined,
                      color: const Color(0xFF003087),
                      title: 'New Assignment',
                      sub: 'Notify when a service is assigned to you',
                      value: _newAssignment,
                      onChanged: (v) => setState(() => _newAssignment = v),
                      isLast: true,
                    ),
                  ]),
                ],

                // ── Inventory Alerts (admin only) ──
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('INVENTORY ALERTS'),
                  const SizedBox(height: 8),
                  _alertCard([
                    _alertTile(
                      icon: Icons.inventory_2_outlined,
                      color: Colors.orange,
                      title: 'Low Stock',
                      sub: 'Notify when stock falls below minimum level',
                      value: _lowStock,
                      onChanged: (v) => setState(() => _lowStock = v),
                      isLast: true,
                    ),
                  ]),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _savePrefs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Preferences',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _sectionLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label, style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: Color(0xFF718096), letterSpacing: 0.8)),
  );

  Widget _alertCard(List<Widget> tiles) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Column(children: tiles),
  );

  Widget _alertTile({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a202c))),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
          ])),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: _red,
          ),
        ]),
      ),
      if (!isLast) const Divider(height: 1, indent: 66),
    ]);
  }
}
