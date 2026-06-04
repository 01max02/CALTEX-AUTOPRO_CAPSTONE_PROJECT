import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'barcode_scanner_screen.dart';

class StaffInventory extends StatefulWidget {
  const StaffInventory({super.key});

  @override
  State<StaffInventory> createState() => _StaffInventoryState();
}

class _StaffInventoryState extends State<StaffInventory> {
  static const _red = Color(0xFFE8001C);
  static const _stockCol = 'stock_inventory';
  static const _masterCol = 'item_master';

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searching = false;

  CollectionReference get _db => FirebaseFirestore.instance.collection(_stockCol);
  CollectionReference get _masterDb => FirebaseFirestore.instance.collection(_masterCol);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _findItemMaster(String query) async {
    if (query.isEmpty) return null;
    final q = query.trim();
    var snap = await _masterDb.where('barcode', isEqualTo: q).limit(1).get();
    if (snap.docs.isNotEmpty) return _docToMaster(snap.docs.first);
    snap = await _masterDb.where('qr', isEqualTo: q).limit(1).get();
    if (snap.docs.isNotEmpty) return _docToMaster(snap.docs.first);
    snap = await _masterDb.where('num', isEqualTo: q.toUpperCase()).limit(1).get();
    if (snap.docs.isNotEmpty) return _docToMaster(snap.docs.first);
    snap = await _masterDb.orderBy('name').startAt([q]).endAt(['$q\uf8ff']).limit(1).get();
    if (snap.docs.isNotEmpty) return _docToMaster(snap.docs.first);
    return null;
  }

  Map<String, dynamic> _docToMaster(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return {'id': doc.id, 'num': d['num'] ?? '', 'name': d['name'] ?? '',
      'group': d['group'] ?? '', 'uom': d['uom'] ?? '', 'barcode': d['barcode'] ?? '', 'qr': d['qr'] ?? ''};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
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
                  hintText: 'Search items...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              )
            : const Text('Stock Inventory',
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
        stream: _db.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final items = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final stock = (data['stock'] as num?)?.toInt() ?? 0;
            final min = (data['min'] as num?)?.toInt() ?? 0;
            final max = (data['max'] as num?)?.toInt() ?? 0;
            return {
              'id': d.id,
              'num': data['num'] as String? ?? '',
              'name': data['name'] as String? ?? '',
              'group': data['group'] as String? ?? '',
              'uom': data['uom'] as String? ?? '',
              'stock': stock, 'min': min, 'max': max,
              'reorder': (data['reorder'] as num?)?.toInt() ?? 0,
              'status': stock > min ? (stock > max ? 'Over' : 'OK') : 'Low',
            };
          }).toList()
            ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

          final filtered = _searchQuery.isEmpty
              ? items
              : items.where((i) =>
                  (i['name'] as String).toLowerCase().contains(_searchQuery) ||
                  (i['num'] as String).toLowerCase().contains(_searchQuery) ||
                  (i['group'] as String).toLowerCase().contains(_searchQuery)).toList();

          final total = items.length;
          final lowCount = items.where((i) => i['status'] == 'Low').length;
          final inStock = items.where((i) => i['status'] == 'OK').length;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                _statChip('Total Items', '$total', Colors.blue),
                const SizedBox(width: 8),
                _statChip('Low Stock', '$lowCount', _red),
                const SizedBox(width: 8),
                _statChip('In Stock', '$inStock', Colors.green),
              ]),
            ),
            Expanded(
              child: filtered.isEmpty
                ? const Center(child: Text('No items found.', style: TextStyle(color: Color(0xFF718096))))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _stockCard(filtered[i]),
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
      case 'Total Items':
        icon = Icons.inventory_2_outlined;
        break;
      case 'Low Stock':
        icon = Icons.warning_outlined;
        break;
      case 'In Stock':
        icon = Icons.check_circle_outline;
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF718096))),
        ]),
      ),
    );
  }

  Widget _stockCard(Map<String, dynamic> item) {
    final status = item['status'] as String;
    final isLow = status == 'Low';
    final isOver = status == 'Over';
    final stock = item['stock'] as int;
    final min = item['min'] as int;
    final max = item['max'] as int;
    final progress = max > 0 ? (stock / max).clamp(0.0, 1.0) : 0.0;
    final barColor = isLow ? Colors.orange : isOver ? Colors.purple : Colors.green;
    final statusLabel = isLow ? 'Low Stock' : isOver ? 'Over Max' : 'In Stock';

    return GestureDetector(
      onTap: () => _showStockDetails(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isLow ? Border.all(color: Colors.orange.shade200)
              : isOver ? Border.all(color: Colors.purple.shade200) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('${item['group']}', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$stock ${item['uom']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: barColor)),
              Text(statusLabel, style: TextStyle(fontSize: 10, color: barColor, fontWeight: FontWeight.w500)),
            ]),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFe2e8f0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Min: $min', style: const TextStyle(fontSize: 10, color: Color(0xFF718096))),
            Text('$stock / $max', style: TextStyle(fontSize: 10, color: barColor, fontWeight: FontWeight.w500)),
            Text('Max: $max', style: const TextStyle(fontSize: 10, color: Color(0xFF718096))),
          ]),
        ]),
      ),
    );
  }

  void _showStockDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.55, maxChildSize: 0.85,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(color: _red,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(item['group'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _detailRow('Item Number', item['num'] as String),
                _detailRow('Item Name', item['name'] as String),
                _detailRow('Commodity Group', item['group'] as String),
                _detailRow('Current Stock', '${item['stock']} ${item['uom']}'),
                _detailRow('Min Level', '${item['min']} ${item['uom']}'),
                _detailRow('Max Level', '${item['max']} ${item['uom']}'),
                _detailRow('Reorder Qty', '${item['reorder']} ${item['uom']}'),
                _detailRow('Status', item['status'] as String),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _showReceiveModal(item); },
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Receive Stock'),
                    style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showReceiveModal(Map<String, dynamic>? preSelected) {
    Map<String, dynamic>? selectedItem = preSelected;
    final scanCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    bool searching = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false, initialChildSize: 0.7, maxChildSize: 0.92,
          builder: (_, ctrl) => SingleChildScrollView(
            controller: ctrl,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: const BoxDecoration(color: Color(0xFF003087),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.download_outlined, color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Receive Items', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Scan or search item to receive stock', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                  GestureDetector(onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white)),
                ]),
              ),
              Padding(
                padding: EdgeInsets.only(left: 20, right: 20, top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: TextField(
                      controller: scanCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Barcode, QR, item number or name...',
                        border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
                      onSubmitted: (_) async {
                        setModal(() => searching = true);
                        final master = await _findItemMaster(scanCtrl.text);
                        if (master != null) {
                          final snap = await _db.where('num', isEqualTo: master['num']).limit(1).get();
                          selectedItem = snap.docs.isNotEmpty
                              ? {'id': snap.docs.first.id, ...snap.docs.first.data() as Map<String, dynamic>}
                              : null;
                        } else { selectedItem = null; }
                        setModal(() => searching = false);
                      },
                    )),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF003087),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.all(10)),
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                      onPressed: () async {
                        final result = await Navigator.push<String>(context,
                          MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
                        if (result != null) {
                          scanCtrl.text = result;
                          setModal(() => searching = true);
                          final master = await _findItemMaster(result);
                          if (master != null) {
                            final snap = await _db.where('num', isEqualTo: master['num']).limit(1).get();
                            selectedItem = snap.docs.isNotEmpty
                                ? {'id': snap.docs.first.id, ...snap.docs.first.data() as Map<String, dynamic>}
                                : null;
                          } else { selectedItem = null; }
                          setModal(() => searching = false);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        setModal(() => searching = true);
                        final master = await _findItemMaster(scanCtrl.text);
                        if (master != null) {
                          final snap = await _db.where('num', isEqualTo: master['num']).limit(1).get();
                          selectedItem = snap.docs.isNotEmpty
                              ? {'id': snap.docs.first.id, ...snap.docs.first.data() as Map<String, dynamic>}
                              : null;
                        } else { selectedItem = null; }
                        setModal(() => searching = false);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('Search'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (searching) const Center(child: CircularProgressIndicator()),
                  if (!searching && selectedItem != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFe2e8f0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Container(width: 44, height: 44,
                          decoration: BoxDecoration(color: const Color(0xFF003087), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(selectedItem!['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${selectedItem!['num']} • ${selectedItem!['group']}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
                          Text('Current stock: ${selectedItem!['stock']} ${selectedItem!['uom']}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF2c5282), fontWeight: FontWeight.w500)),
                        ])),
                        GestureDetector(onTap: () => setModal(() { selectedItem = null; scanCtrl.clear(); }),
                          child: const Icon(Icons.close, size: 18, color: Color(0xFF718096))),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity Received *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.add_box_outlined),
                      )),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: () async {
                          final qty = int.tryParse(qtyCtrl.text) ?? 0;
                          if (qty <= 0) return;
                          final currentStock = (selectedItem!['stock'] as num?)?.toInt() ?? 0;
                          final newStock = currentStock + qty;
                          final min = (selectedItem!['min'] as num?)?.toInt() ?? 0;
                          try {
                            await _db.doc(selectedItem!['id'] as String).update({
                              'stock': newStock,
                              'status': newStock > min ? 'OK' : 'Low',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Row(children: const [Icon(Icons.check_circle_outline, color: Colors.white, size: 18), SizedBox(width: 8), Text('Stock received successfully!')]),
                                backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                            }
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003087), foregroundColor: Colors.white),
                        child: const Text('✅ Confirm'),
                      )),
                    ]),
                  ] else if (!searching && scanCtrl.text.isNotEmpty && selectedItem == null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200)),
                      child: const Row(children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('No stock item found for that code.', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096), fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a202c)))),
      ]),
    );
  }
}
