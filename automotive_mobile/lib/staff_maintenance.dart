import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'barcode_scanner_screen.dart';

class StaffMaintenance extends StatefulWidget {
  const StaffMaintenance({super.key});

  @override
  State<StaffMaintenance> createState() => _StaffMaintenanceState();
}

class _StaffMaintenanceState extends State<StaffMaintenance> {
  static const _red = Color(0xFFE8001C);
  static const _col = 'maintenance';

  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _searchQuery = '';

  CollectionReference get _db => FirebaseFirestore.instance.collection(_col);

  Map<String, Map<String, dynamic>> _vehicleMap = {};
  Map<String, Map<String, dynamic>> _itemMasterMap = {};
  List<String> _serviceItems = [];
  bool _lookupLoaded = false;
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final vSnap = await FirebaseFirestore.instance.collection('vehicles').get();
    final iSnap = await FirebaseFirestore.instance.collection('item_master').get();
    if (!mounted) return;
    _vehicleMap = {
      for (final d in vSnap.docs)
        (d['plate'] as String? ?? ''): d.data() as Map<String, dynamic>
    };
    _itemMasterMap = {
      for (final d in iSnap.docs)
        (d['name'] as String? ?? ''): d.data() as Map<String, dynamic>
    };
    _serviceItems = _itemMasterMap.entries
        .where((e) => e.value['type'] == 'Service')
        .map((e) => e.key).toList()..sort();
    // Fetch logged-in staff name
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _currentUserName = (userDoc.data()?['name'] as String?) ?? '';
    }
    setState(() => _lookupLoaded = true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed': return Colors.green;
      case 'Ongoing':   return Colors.orange;
      default:          return const Color(0xFF718096);
    }
  }

  Future<String> _nextSvcId() async {
    final snap = await _db.orderBy('createdAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return 'SVC-001';
    final last = snap.docs.first['id'] as String? ?? 'SVC-000';
    final n = int.tryParse(last.replaceAll('SVC-', '')) ?? 0;
    return 'SVC-${(n + 1).toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!_lookupLoaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Loading data, please wait...'), duration: Duration(seconds: 1)));
            return;
          }
          _showAddServiceModal();
        },
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search services...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              )
            : const Text('Vehicle Maintenance',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) { _searchCtrl.clear(); _searchQuery = ''; }
            }),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          final services = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return {
              'docId': d.id,
              'id': data['id'] as String? ?? d.id,
              'plate': data['plate'] as String? ?? '',
              'desc': data['desc'] as String? ?? '',
              'mechanic': data['mechanic'] as String? ?? '',
              'date': data['date'] as String? ?? '',
              'cost': data['cost'] as String? ?? '0',
              'status': data['status'] as String? ?? 'Pending',
              'svcRows': data['svcRows'],
              'matRows': data['matRows'],
              'issues': data['issues'],
            };
          }).toList();

          final filtered = _searchQuery.isEmpty
              ? services
              : services.where((s) =>
                  (s['id'] as String).toLowerCase().contains(_searchQuery) ||
                  (s['plate'] as String).toLowerCase().contains(_searchQuery) ||
                  (s['mechanic'] as String).toLowerCase().contains(_searchQuery)).toList();

          final total = services.length;
          final ongoing = services.where((s) => s['status'] == 'Ongoing').length;
          final completed = services.where((s) => s['status'] == 'Completed').length;
          final pending = services.where((s) => s['status'] == 'Pending').length;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                _statChip('Total', '$total', Colors.blue),
                const SizedBox(width: 8),
                _statChip('Ongoing', '$ongoing', Colors.orange),
                const SizedBox(width: 8),
                _statChip('Completed', '$completed', Colors.green),
                const SizedBox(width: 8),
                _statChip('Pending', '$pending', const Color(0xFF718096)),
              ]),
            ),
            Expanded(
              child: filtered.isEmpty
                ? const Center(child: Text('No services found.', style: TextStyle(color: Color(0xFF718096))))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _serviceCard(filtered[i]),
                  ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    IconData icon;
    switch (label) {
      case 'Total':
        icon = Icons.build_circle_outlined;
        break;
      case 'Ongoing':
        icon = Icons.autorenew_outlined;
        break;
      case 'Completed':
        icon = Icons.check_circle_outline;
        break;
      case 'Pending':
        icon = Icons.pending_outlined;
        break;
      default:
        icon = Icons.info_outline;
    }
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF718096))),
        ]),
      ),
    );
  }

  Widget _serviceCard(Map<String, dynamic> s) {
    final sc = _statusColor(s['status'] as String);
    return GestureDetector(
      onTap: () => _showServiceDetails(s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.build_outlined, color: _red, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['plate'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text((s['desc'] as String).isNotEmpty ? s['desc'] as String : s['plate'] as String,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568))),
            Text('${s['mechanic']} - ${s['date']}', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_formatCost(s['cost'] as String), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(s['status'] as String, style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showServiceDetails(Map<String, dynamic> s) {
    final sc = _statusColor(s['status'] as String);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => AnimatedPadding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          duration: const Duration(milliseconds: 150),
          child: SingleChildScrollView(
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: const BoxDecoration(color: _red, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.build_outlined, color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['plate'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(s['desc'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                  GestureDetector(onTap: () => Navigator.pop(sheetCtx),
                    child: const Icon(Icons.close, color: Colors.white)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _detailRow('Plate Number', s['plate'] as String),
                  _detailRow('Mechanic', s['mechanic'] as String),
                  _detailRow('Service Date', s['date'] as String),
                  _detailRow('Total Cost', _formatCost(s['cost'] as String)),
                  Row(children: [
                    const SizedBox(width: 130, child: Text('Status', style: TextStyle(fontSize: 12, color: Color(0xFF718096), fontWeight: FontWeight.w500))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(s['status'] as String, style: TextStyle(fontSize: 12, color: sc, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // ── Issues Tags ──
                  if ((s['issues'] as List?)?.isNotEmpty == true) ...[
                    const Text('Vehicle Issues Reported', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4a5568))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (s['issues'] as List).map<Widget>((issue) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFED7D7), width: 1.5),
                        ),
                        child: Text(issue.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE8001C))),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if ((s['svcRows'] as List?)?.isNotEmpty == true) ...[
                    const Text('Services Rendered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4a5568))),
                    const SizedBox(height: 8),
                    ...(s['svcRows'] as List).where((r) => (r['name'] as String? ?? '').isNotEmpty).map((r) => _rowDetailCard(r, isService: true)),
                    const SizedBox(height: 12),
                  ],
                  if ((s['matRows'] as List?)?.isNotEmpty == true) ...[
                    const Text('Materials Used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4a5568))),
                    const SizedBox(height: 8),
                    ...(s['matRows'] as List).where((r) => (r['name'] as String? ?? '').isNotEmpty).map((r) => _rowDetailCard(r, isService: false)),
                    const SizedBox(height: 12),
                  ],
                  if (s['status'] == 'Pending')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('Waiting for admin approval.',
                          style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  if (s['status'] == 'Ongoing') ...[
                    SizedBox(width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Complete Service'),
                              content: Text('Mark service for ${s['plate']} as Completed?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Complete', style: TextStyle(color: Colors.green))),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          await _db.doc(s['docId'] as String).update({'status': 'Completed'});
                          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                          final byName = (userDoc.data()?['name'] as String?) ?? 'Staff';
                          final now = DateTime.now();
                          final dateStr = '${now.month}/${now.day}/${now.year}';
                          final plate = (s['plate'] as String).trim().toUpperCase();
                          final matRows = s['matRows'] as List<dynamic>? ?? [];
                          for (final r in matRows) {
                            final name = r['name'] as String? ?? '';
                            final qty = int.tryParse(r['qty'] as String? ?? '1') ?? 1;
                            final uom = r['uom'] as String? ?? '';
                            final cost = double.tryParse(r['cost'] as String? ?? '0') ?? 0;
                            if (name.isEmpty || qty <= 0) continue;
                            final iSnap = await FirebaseFirestore.instance
                                .collection('item_master').where('name', isEqualTo: name).limit(1).get();
                            final iData = iSnap.docs.isNotEmpty ? iSnap.docs.first.data() as Map<String, dynamic> : <String, dynamic>{};
                            await FirebaseFirestore.instance.collection('issuances').add({
                              'id': 'ISS-AUTO-${DateTime.now().millisecondsSinceEpoch}',
                              'date': dateStr, 'plate': plate,
                              'assetDesc': s['desc'] ?? '', 'itemNum': iData['num'] ?? '',
                              'itemName': name, 'itemType': 'Material',
                              'commodityGroup': iData['group'] ?? '', 'uom': uom,
                              'qty': '$qty', 'unitCost': cost.toStringAsFixed(2),
                              'subtotal': (cost * qty).toStringAsFixed(2),
                              'createdBy': byName, 'maintenanceId': s['id'],
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            final stockSnap = await FirebaseFirestore.instance
                                .collection('stock_inventory').where('name', isEqualTo: name).limit(1).get();
                            if (stockSnap.docs.isNotEmpty) {
                              final stockDoc = stockSnap.docs.first;
                              final currentStock = (stockDoc['stock'] as num?)?.toInt() ?? 0;
                              final newStock = (currentStock - qty).clamp(0, 99999);
                              final minLevel = (stockDoc['min'] as num?)?.toInt() ?? 0;
                              await stockDoc.reference.update({
                                'stock': newStock,
                                'status': newStock >= minLevel ? 'OK' : 'Low',
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            }
                            await FirebaseFirestore.instance.collection('transactions').add({
                              'item': name,
                              'desc': 'Issued for maintenance ${s['id']} - $plate',
                              'type': 'OUT', 'qty': '-$qty', 'date': dateStr, 'by': byName,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }
                          final svcRows = s['svcRows'] as List<dynamic>? ?? [];
                          for (final r in svcRows) {
                            final name = r['name'] as String? ?? '';
                            final qty = int.tryParse(r['qty'] as String? ?? '1') ?? 1;
                            final uom = r['uom'] as String? ?? '';
                            final cost = double.tryParse(r['cost'] as String? ?? '0') ?? 0;
                            if (name.isEmpty) continue;
                            final iSnap = await FirebaseFirestore.instance
                                .collection('item_master').where('name', isEqualTo: name).limit(1).get();
                            final iData = iSnap.docs.isNotEmpty ? iSnap.docs.first.data() as Map<String, dynamic> : <String, dynamic>{};
                            await FirebaseFirestore.instance.collection('issuances').add({
                              'id': 'ISS-AUTO-${DateTime.now().millisecondsSinceEpoch}-S',
                              'date': dateStr, 'plate': plate,
                              'assetDesc': s['desc'] ?? '', 'itemNum': iData['num'] ?? '',
                              'itemName': name, 'itemType': 'Service',
                              'commodityGroup': iData['group'] ?? '', 'uom': uom,
                              'qty': '$qty', 'unitCost': cost.toStringAsFixed(2),
                              'subtotal': (cost * qty).toStringAsFixed(2),
                              'createdBy': byName, 'maintenanceId': s['id'],
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }
                          final vSnap = await FirebaseFirestore.instance
                              .collection('vehicles').where('plate', isEqualTo: plate).limit(1).get();
                          if (vSnap.docs.isNotEmpty) {
                            await vSnap.docs.first.reference.update({
                              'status': 'Completed',
                              'completedAt': FieldValue.serverTimestamp(),
                              'lastSvcDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                            });
                          }
                          if (mounted) {
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Row(children: const [Icon(Icons.check_circle_outline, color: Colors.white, size: 18), SizedBox(width: 8), Text('Service marked as Completed!')]),
                              backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                          }
                        },
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Mark as Completed'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      )),
                    const SizedBox(height: 8),
                  ],
                  if (s['status'] != 'Completed')
                    SizedBox(width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () { Navigator.pop(sheetCtx); _showAddServiceModal(service: s); },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _rowDetailCard(dynamic r, {required bool isService}) {
    final name = r['name'] as String? ?? '';
    final qty = r['qty'] as String? ?? '1';
    final uom = r['uom'] as String? ?? '';
    final cost = r['cost'] as String? ?? '0';
    final subtotal = (double.tryParse(cost) ?? 0) * (double.tryParse(qty) ?? 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Row(children: [
        Icon(isService ? Icons.build_outlined : Icons.inventory_2_outlined,
          size: 16, color: isService ? const Color(0xFF003087) : _red),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('$qty $uom  -  $cost / unit', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
        ])),
        Text(subtotal.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1a202c))),
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096), fontWeight: FontWeight.w500))),
        Expanded(child: Text(value.isNotEmpty ? value : '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a202c)))),
      ]),
    );
  }

  void _showAddServiceModal({Map<String, dynamic>? service}) async {
    final isEdit = service != null;
    final plateCtrl = TextEditingController(text: service?['plate'] as String? ?? '');
    final mechanicCtrl = TextEditingController(text: service?['mechanic'] as String? ?? (isEdit ? '' : _currentUserName));
    final dateCtrl = TextEditingController(
      text: service?['date'] as String? ?? '${_monthName(DateTime.now().month)} ${DateTime.now().day}, ${DateTime.now().year}',
    );
    Map<String, dynamic>? foundVehicle = isEdit ? _vehicleMap[service!['plate']] : null;

    // ── Issue tags ──
    const presetIssues = [
      'Engine Problem', 'Brake Issue', 'Tire/Wheel', 'Battery', 'Overheating',
      'Oil Leak', 'Transmission', 'Suspension', 'Electrical', 'AC/Cooling',
      'Exhaust', 'Steering', 'Fuel System', 'Body Damage', 'Lights/Signals',
    ];
    final selectedIssues = List<String>.from(
      (service?['issues'] as List<dynamic>?)?.map((e) => e.toString()) ?? [],
    );
    final customIssueCtrl = TextEditingController();

    List<Map<String, TextEditingController>> makeRows(List<dynamic>? saved) {
      if (saved != null && saved.isNotEmpty) {
        return saved.map<Map<String, TextEditingController>>((r) => {
          'name': TextEditingController(text: r['name'] ?? ''),
          'qty':  TextEditingController(text: r['qty']  ?? ''),
          'uom':  TextEditingController(text: r['uom']  ?? ''),
          'cost': TextEditingController(text: r['cost'] ?? ''),
        }).toList();
      }
      return [{'name': TextEditingController(), 'qty': TextEditingController(), 'uom': TextEditingController(), 'cost': TextEditingController()}];
    }

    final svcRows = makeRows(service?['svcRows'] as List<dynamic>?);
    final matRows = makeRows(service?['matRows'] as List<dynamic>?);

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          double totalCost() {
            double t = 0;
            for (final r in [...svcRows, ...matRows]) {
              t += (double.tryParse(r['cost']!.text) ?? 0) * (double.tryParse(r['qty']!.text) ?? 1);
            }
            return t;
          }
          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            duration: const Duration(milliseconds: 150),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: const BoxDecoration(color: _red, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                      child: Icon(isEdit ? Icons.edit_outlined : Icons.add, color: Colors.white, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(isEdit ? 'Edit Service' : 'New Service',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                    GestureDetector(onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Plate Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4a5568))),
                    const SizedBox(height: 6),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: plateCtrl.text),
                      optionsBuilder: (value) {
                        final q = value.text.trim().toUpperCase();
                        if (q.isEmpty) return _vehicleMap.keys;
                        return _vehicleMap.keys.where((p) => p.contains(q));
                      },
                      onSelected: (plate) {
                        plateCtrl.text = plate;
                        setModal(() => foundVehicle = _vehicleMap[plate]);
                      },
                      fieldViewBuilder: (ctx2, ctrl, focusNode, onSubmit) => TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (v) => setModal(() => foundVehicle = _vehicleMap[v.trim().toUpperCase()]),
                        decoration: InputDecoration(
                          hintText: 'Search or scan plate number...',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF718096)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF718096)),
                            onPressed: () async {
                              final result = await Navigator.push<String>(context,
                                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
                              if (result != null) {
                                ctrl.text = result.toUpperCase();
                                plateCtrl.text = result.toUpperCase();
                                setModal(() => foundVehicle = _vehicleMap[result.toUpperCase()]);
                              }
                            },
                          ),
                        ),
                      ),
                      optionsViewBuilder: (ctx2, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.separated(
                              padding: EdgeInsets.zero, shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final plate = options.elementAt(i);
                                final v = _vehicleMap[plate];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.directions_car_outlined, size: 18, color: Color(0xFF003087)),
                                  title: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text(v?['desc'] as String? ?? '', style: const TextStyle(fontSize: 11)),
                                  onTap: () => onSelected(plate),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (foundVehicle != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFe2e8f0)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.directions_car_outlined, color: _red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(foundVehicle!['desc'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(foundVehicle!['owner'] as String? ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
                          ])),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(controller: mechanicCtrl,
                      decoration: const InputDecoration(labelText: 'Mechanic Name *', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dateCtrl, readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Service Date *', border: const OutlineInputBorder(), hintText: 'Select date',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF718096)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx, initialDate: DateTime.now(),
                              firstDate: DateTime(2020), lastDate: DateTime(2030),
                              builder: (c, child) => Theme(
                                data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _red)),
                                child: child!),
                            );
                            if (picked != null) {
                              dateCtrl.text = '${_monthName(picked.month)} ${picked.day}, ${picked.year}';
                              setModal(() {});
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Vehicle Issues ──
                    const Text('Vehicle Issues', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4a5568))),
                    const SizedBox(height: 4),
                    Text('Select all that apply', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...presetIssues.map((issue) {
                          final sel = selectedIssues.contains(issue);
                          return GestureDetector(
                            onTap: () => setModal(() {
                              if (sel) selectedIssues.remove(issue);
                              else selectedIssues.add(issue);
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? _red : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? _red : const Color(0xFFe2e8f0), width: 1.5),
                              ),
                              child: Text(issue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF4a5568))),
                            ),
                          );
                        }),
                        // Custom issues not in preset
                        ...selectedIssues.where((i) => !presetIssues.contains(i)).map((issue) =>
                          GestureDetector(
                            onTap: () => setModal(() => selectedIssues.remove(issue)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(20), border: Border.all(color: _red, width: 1.5)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(issue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                const SizedBox(width: 4),
                                const Icon(Icons.close, size: 12, color: Colors.white),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextField(
                        controller: customIssueCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add custom issue...',
                          hintStyle: TextStyle(fontSize: 12),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (v) {
                          final val = v.trim();
                          if (val.isNotEmpty && !selectedIssues.contains(val)) {
                            setModal(() { selectedIssues.add(val); customIssueCtrl.clear(); });
                          }
                        },
                      )),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final val = customIssueCtrl.text.trim();
                          if (val.isNotEmpty && !selectedIssues.contains(val)) {
                            setModal(() { selectedIssues.add(val); customIssueCtrl.clear(); });
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        child: const Text('+ Add', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Services Rendered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4a5568))),
                      TextButton.icon(
                        onPressed: () => setModal(() => svcRows.add({'name': TextEditingController(), 'qty': TextEditingController(), 'uom': TextEditingController(), 'cost': TextEditingController()})),
                        icon: const Icon(Icons.add, size: 16), label: const Text('Add Row', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                    ...svcRows.asMap().entries.map((e) => _svcRow(e.value, () => setModal(() => svcRows.removeAt(e.key)), setModal)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Materials Used', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4a5568))),
                      TextButton.icon(
                        onPressed: () => setModal(() => matRows.add({'name': TextEditingController(), 'qty': TextEditingController(), 'uom': TextEditingController(), 'cost': TextEditingController()})),
                        icon: const Icon(Icons.add, size: 16), label: const Text('Add Row', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                    ...matRows.asMap().entries.map((e) => _matRow(e.value, () => setModal(() => matRows.removeAt(e.key)), setModal, ctx)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total Cost:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2c5282), fontSize: 14)),
                      Text('₱${totalCost().toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2b6cb0))),
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: () async {
                          if (plateCtrl.text.trim().isEmpty || mechanicCtrl.text.trim().isEmpty) return;

                          // Validate material quantities against stock
                          for (final r in matRows) {
                            final name = r['name']!.text.trim();
                            final qty = int.tryParse(r['qty']!.text.trim()) ?? 0;
                            if (name.isEmpty || qty <= 0) continue;
                            final stockSnap = await FirebaseFirestore.instance
                                .collection('stock_inventory').where('name', isEqualTo: name).limit(1).get();
                            if (stockSnap.docs.isNotEmpty) {
                              final available = (stockSnap.docs.first['stock'] as num?)?.toInt() ?? 0;
                              if (qty > available) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Insufficient stock for "$name". Available: $available, Requested: $qty'),
                                  backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                                return;
                              }
                            }
                          }

                          final svcId = isEdit ? service!['id'] as String : await _nextSvcId();
                          final data = <String, dynamic>{
                            'id': svcId,
                            'plate': plateCtrl.text.trim().toUpperCase(),
                            'desc': foundVehicle?['desc'] as String? ?? '',
                            'mechanic': mechanicCtrl.text.trim(),
                            'date': dateCtrl.text.trim(),
                            'cost': '₱${totalCost().toStringAsFixed(2)}',
                            'status': isEdit ? service!['status'] as String : 'Pending',
                            'issues': selectedIssues,
                            'svcRows': svcRows.map((r) => {'name': r['name']!.text, 'qty': r['qty']!.text, 'uom': r['uom']!.text, 'cost': r['cost']!.text}).toList(),
                            'matRows': matRows.map((r) => {'name': r['name']!.text, 'qty': r['qty']!.text, 'uom': r['uom']!.text, 'cost': r['cost']!.text}).toList(),
                          };
                          try {
                            if (isEdit) {
                              await _db.doc(service!['docId'] as String).update(data);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Row(children: const [Icon(Icons.check_circle_outline, color: Colors.white, size: 18), SizedBox(width: 8), Text('Service updated successfully!')]),
                                  backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                              }
                            } else {
                              data['createdAt'] = FieldValue.serverTimestamp();
                              await _db.add(data);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Row(children: const [Icon(Icons.check_circle_outline, color: Colors.white, size: 18), SizedBox(width: 8), Text('Service added successfully!')]),
                                  backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                              }
                            }
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
                        child: Text(isEdit ? 'Update' : 'Save'),
                      )),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _svcRow(Map<String, TextEditingController> row, VoidCallback onRemove, StateSetter setModal) {
    final currentVal = _serviceItems.contains(row['name']!.text) ? row['name']!.text : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: currentVal,
            hint: const Text('Select service...', style: TextStyle(fontSize: 11)),
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true),
            items: _serviceItems.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) {
              if (v != null) {
                row['name']!.text = v;
                final d = _itemMasterMap[v];
                row['uom']!.text = d?['uom'] as String? ?? 'job';
                row['cost']!.text = (d?['cost'] as String? ?? '0').replaceAll('₱', '').replaceAll(',', '').trim();
                if (row['qty']!.text.isEmpty) row['qty']!.text = '1';
              }
              setModal(() {});
            },
          )),
          SizedBox(width: 32, child: IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), padding: EdgeInsets.zero, onPressed: onRemove)),
        ]),
        if (row['name']!.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFe2e8f0)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('UOM: ${row['uom']!.text}  -  Unit Cost: ${row['cost']!.text}', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
              const SizedBox(height: 8),
              TextField(controller: row['qty'], keyboardType: TextInputType.number, onChanged: (_) => setModal(() {}),
                decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _matRow(Map<String, TextEditingController> row, VoidCallback onRemove, StateSetter setModal, BuildContext ctx) {
    row.putIfAbsent('maxStock', () => TextEditingController(text: '99999'));
    row.putIfAbsent('searchText', () => TextEditingController());

    // Material names from item master (type == Material)
    final materialNames = _itemMasterMap.entries
        .where((e) => (e.value['type'] as String? ?? '').toLowerCase() == 'material')
        .map((e) => e.key)
        .toList()..sort();

    Future<void> applyMaterial(String name) async {
      final d = _itemMasterMap[name];
      if (d == null) return;
      row['name']!.text = name;
      row['searchText']!.text = name;
      row['uom']!.text = d['uom'] as String? ?? '';
      row['cost']!.text = (d['cost'] as String? ?? '0').replaceAll('₱', '').replaceAll(',', '').trim();
      if (row['qty']!.text.isEmpty) row['qty']!.text = '1';
      final stockSnap = await FirebaseFirestore.instance
          .collection('stock_inventory').where('name', isEqualTo: name).limit(1).get();
      final available = stockSnap.docs.isNotEmpty
          ? (stockSnap.docs.first['stock'] as num?)?.toInt() ?? 99999
          : 99999;
      row['maxStock']!.text = '$available';
      final currentQty = int.tryParse(row['qty']!.text) ?? 1;
      if (currentQty > available) row['qty']!.text = '$available';
      setModal(() {});
    }

    final maxStock = int.tryParse(row['maxStock']!.text) ?? 99999;
    final isSelected = row['name']!.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: isSelected
              ? Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFe2e8f0)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF003087)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(row['name']!.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      GestureDetector(
                        onTap: () {
                          row['name']!.text = '';
                          row['searchText']!.text = '';
                          row['uom']!.text = '';
                          row['cost']!.text = '';
                          row['maxStock']!.text = '99999';
                          setModal(() {});
                        },
                        child: const Icon(Icons.close, size: 14, color: Color(0xFF718096)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('UOM: ${row['uom']!.text}  •  Unit Cost: ₱${row['cost']!.text}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
                    if (maxStock < 99999) ...[
                      const SizedBox(height: 4),
                      Text('Available stock: $maxStock',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: maxStock == 0 ? Colors.red : maxStock <= 5 ? Colors.orange : Colors.green)),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: row['qty'],
                      keyboardType: TextInputType.number,
                      enabled: maxStock > 0,
                      onChanged: (v) {
                        final entered = int.tryParse(v) ?? 0;
                        if (maxStock < 99999 && entered > maxStock) {
                          row['qty']!.text = '$maxStock';
                          row['qty']!.selection = TextSelection.collapsed(offset: '$maxStock'.length);
                        }
                        setModal(() {});
                      },
                      decoration: InputDecoration(
                        labelText: maxStock == 99999 ? 'Quantity *' : 'Quantity * (max $maxStock)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        errorText: maxStock == 0 ? 'Out of stock' : null,
                      ),
                    ),
                  ]),
                )
              : RawAutocomplete<String>(
                  textEditingController: row['searchText']!,
                  focusNode: FocusNode(),
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return materialNames;
                    return materialNames.where((n) => n.toLowerCase().contains(q));
                  },
                  onSelected: (name) => applyMaterial(name),
                  fieldViewBuilder: (ctx2, ctrl, focusNode, onSubmit) => TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search material name...',
                      hintStyle: const TextStyle(fontSize: 11),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF718096)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF003087)),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final result = await Navigator.push<String>(ctx,
                            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
                          if (result != null) {
                            final match = _itemMasterMap.entries.firstWhere(
                              (e) => e.value['barcode'] == result || e.value['qr'] == result,
                              orElse: () => MapEntry('', {}),
                            );
                            if (match.key.isNotEmpty) applyMaterial(match.key);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (v) {
                      final q = v.trim().toLowerCase();
                      final match = materialNames.firstWhere(
                        (n) => n.toLowerCase() == q, orElse: () => '');
                      if (match.isNotEmpty) applyMaterial(match);
                    },
                  ),
                  optionsViewBuilder: (ctx2, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final name = options.elementAt(i);
                            final d = _itemMasterMap[name];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF003087)),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: d != null
                                ? Text('${d['uom'] ?? ''}  •  ₱${(d['cost'] as String? ?? '0').replaceAll('₱', '').replaceAll(',', '').trim()}',
                                    style: const TextStyle(fontSize: 11))
                                : null,
                              onTap: () => onSelected(name),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
          ),
          SizedBox(width: 32, child: IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            onPressed: onRemove,
          )),
        ]),
      ]),
    );
  }

  String _formatCost(String raw) {
    final clean = raw.replaceAll('₱', '').replaceAll(',', '').trim();
    final val = double.tryParse(clean);
    if (val == null) return raw.startsWith('₱') ? raw : '₱$raw';
    return '₱${val.toStringAsFixed(2)}';
  }

  String _monthName(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}
