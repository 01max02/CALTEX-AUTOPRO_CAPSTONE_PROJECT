import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'barcode_scanner_screen.dart';

/// Reusable bottom navigation bar for the Admin Dashboard.
/// Handles tab switching and the center scanner button.
class AdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _red = Color(0xFFE8001C);

  static const _navItems = [
    (icon: Icons.dashboard_outlined, label: 'Dashboard'),
    (icon: Icons.inventory_2_outlined, label: 'Inventory'),
    (icon: Icons.directions_car_outlined, label: 'Vehicles'),
    (icon: Icons.more_horiz, label: 'More'),
  ];

  const AdminBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 2 left + center placeholder + 2 right
              Row(children: [
                _navBtn(context, 0),
                _navBtn(context, 1),
                const Expanded(child: SizedBox()), // center placeholder
                _navBtn(context, 2),
                _navBtn(context, 3),
              ]),
              // Center floating scanner button
              Positioned(
                top: -20, left: 0, right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _showScanModal(context),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _red.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(BuildContext context, int i) {
    final active = currentIndex == i;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_navItems[i].icon, color: active ? _red : const Color(0xFF718096), size: 22),
          const SizedBox(height: 2),
          Text(_navItems[i].label, style: TextStyle(
            fontSize: 9,
            color: active ? _red : const Color(0xFF718096),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          )),
        ]),
      ),
    );
  }

  // ── Barcode / QR scanner modal ──
  void _showScanModal(BuildContext context) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result == null) return;

    final ctx = context;
    if (!ctx.mounted) return;

    // Look up in item_master by barcode, qr, or num
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection('item_master').where('barcode', isEqualTo: result).limit(1).get();
    if (snap.docs.isEmpty) {
      snap = await FirebaseFirestore.instance
          .collection('item_master').where('qr', isEqualTo: result).limit(1).get();
    }
    if (snap.docs.isEmpty) {
      snap = await FirebaseFirestore.instance
          .collection('item_master').where('num', isEqualTo: result.toUpperCase()).limit(1).get();
    }

    if (!ctx.mounted) return;

    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('No item found for: $result'), backgroundColor: Colors.red),
      );
      return;
    }

    final data = snap.docs.first.data() as Map<String, dynamic>;
    final item = {
      'id': snap.docs.first.id,
      'num': data['num'] as String? ?? '',
      'name': data['name'] as String? ?? '',
      'group': data['group'] as String? ?? '',
      'uom': data['uom'] as String? ?? '',
      'cost': data['cost'] as String? ?? '',
      'type': data['type'] as String? ?? '',
    };

    // Check if already in stock
    final stockSnap = await FirebaseFirestore.instance
        .collection('stock_inventory').where('num', isEqualTo: item['num']).limit(1).get();
    final inStock = stockSnap.docs.isNotEmpty;
    final stockData = inStock ? stockSnap.docs.first.data() as Map<String, dynamic>? : null;

    if (!ctx.mounted) return;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Colored header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: inStock
                    ? const Color(0xFF003087)
                    : item['type'] == 'Service' ? const Color(0xFF003087) : _red,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                    child: Icon(
                      item['type'] == 'Service' ? Icons.build_outlined : Icons.inventory_2_outlined,
                      color: Colors.white, size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['name']!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${item['num']} • ${item['group']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _scanBadge(Icons.straighten_outlined, item['uom']!),
                  const SizedBox(width: 8),
                  _scanBadge(Icons.attach_money, item['cost']!),
                  const SizedBox(width: 8),
                  _scanBadge(
                    item['type'] == 'Service' ? Icons.build_outlined : Icons.category_outlined,
                    item['type']!,
                  ),
                ]),
              ]),
            ),
            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (inStock && stockData != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('In Stock', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                        Text('Current quantity: ${stockData['stock']} ${stockData['uom']}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a202c))),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ] else if (!inStock) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Not in Stock', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w700)),
                        Text('This item has no stock record yet.', style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                if (inStock && stockData != null)
                  _ScanReceiveWidget(
                    stockId: stockSnap.docs.first.id,
                    stockData: stockData,
                    uom: item['uom']!,
                    onDone: () => Navigator.pop(ctx),
                  ),
                if (!inStock)
                  _ScanAddStockWidget(
                    itemData: item,
                    onDone: () => Navigator.pop(ctx),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _scanBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Scan: Add to Stock ──────────────────────────────────────────────────────
class _ScanAddStockWidget extends StatefulWidget {
  final Map<String, String> itemData;
  final VoidCallback onDone;
  const _ScanAddStockWidget({required this.itemData, required this.onDone});

  @override
  State<_ScanAddStockWidget> createState() => _ScanAddStockWidgetState();
}

class _ScanAddStockWidgetState extends State<_ScanAddStockWidget> {
  static const _red = Color(0xFFE8001C);
  final _stockCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _stockCtrl.dispose(); _minCtrl.dispose(); _maxCtrl.dispose(); _reorderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uom = widget.itemData['uom'] ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFbee3f8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.add_box_outlined, color: _red, size: 16),
          SizedBox(width: 6),
          Text('Stock Level Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _red)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _stockCtrl, keyboardType: TextInputType.number, autofocus: true,
          decoration: InputDecoration(labelText: 'Current Quantity *', border: const OutlineInputBorder(),
            filled: true, fillColor: Colors.white, suffixText: uom),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: _minCtrl, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Min Level *', border: const OutlineInputBorder(),
              filled: true, fillColor: Colors.white, suffixText: uom),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _maxCtrl, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Max Level *', border: const OutlineInputBorder(),
              filled: true, fillColor: Colors.white, suffixText: uom),
          )),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _reorderCtrl, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Reorder Quantity', border: const OutlineInputBorder(),
            filled: true, fillColor: Colors.white, suffixText: uom),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : () async {
              final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
              final min   = int.tryParse(_minCtrl.text.trim())   ?? 0;
              final max   = int.tryParse(_maxCtrl.text.trim())   ?? 0;
              final reorder = int.tryParse(_reorderCtrl.text.trim()) ?? 0;
              if (_stockCtrl.text.isEmpty || _minCtrl.text.isEmpty || _maxCtrl.text.isEmpty) return;
              setState(() => _loading = true);
              try {
                final existing = await FirebaseFirestore.instance
                    .collection('stock_inventory')
                    .where('num', isEqualTo: widget.itemData['num'])
                    .limit(1).get();
                if (existing.docs.isNotEmpty) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Already in stock inventory.'), backgroundColor: Colors.orange));
                  setState(() => _loading = false);
                  return;
                }
                await FirebaseFirestore.instance.collection('stock_inventory').add({
                  'num': widget.itemData['num'], 'name': widget.itemData['name'],
                  'group': widget.itemData['group'], 'uom': widget.itemData['uom'],
                  'stock': stock, 'min': min, 'max': max, 'reorder': reorder,
                  'status': stock > min ? 'OK' : 'Low',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                final byName = (userDoc.data()?['name'] as String?) ?? 'Admin';
                final now = DateTime.now();
                const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';
                await FirebaseFirestore.instance.collection('transactions').add({
                  'item': widget.itemData['name'] ?? '',
                  'desc': 'Initial stock added', 'type': 'IN', 'qty': '+$stock',
                  'date': dateStr, 'by': byName, 'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to stock inventory.'), backgroundColor: Colors.green));
                  widget.onDone();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                setState(() => _loading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.save_outlined, size: 16), SizedBox(width: 6), Text('Save to Stock'),
                  ]),
          ),
        ),
      ]),
    );
  }
}

// ── Scan: Receive Stock ─────────────────────────────────────────────────────
class _ScanReceiveWidget extends StatefulWidget {
  final String stockId;
  final Map<String, dynamic> stockData;
  final String uom;
  final VoidCallback onDone;
  const _ScanReceiveWidget({required this.stockId, required this.stockData, required this.uom, required this.onDone});

  @override
  State<_ScanReceiveWidget> createState() => _ScanReceiveWidgetState();
}

class _ScanReceiveWidgetState extends State<_ScanReceiveWidget> {
  static const _blue = Color(0xFF003087);
  final _qtyCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _qtyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final currentStock = (widget.stockData['stock'] as num?)?.toInt() ?? 0;
    final min = (widget.stockData['min'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFebf8ff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90cdf4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.download_outlined, color: _blue, size: 16),
          SizedBox(width: 6),
          Text('Receive Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _blue)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(
            controller: _qtyCtrl, keyboardType: TextInputType.number, autofocus: true,
            decoration: InputDecoration(labelText: 'Quantity to receive *', border: const OutlineInputBorder(),
              filled: true, fillColor: Colors.white, suffixText: widget.uom),
          )),
          const SizedBox(width: 10),
          SizedBox(height: 56, child: ElevatedButton(
            onPressed: _loading ? null : () async {
              final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) return;
              setState(() => _loading = true);
              try {
                final newStock = currentStock + qty;
                await FirebaseFirestore.instance.collection('stock_inventory').doc(widget.stockId).update({
                  'stock': newStock, 'status': newStock > min ? 'OK' : 'Low',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                final byName = (userDoc.data()?['name'] as String?) ?? 'Admin';
                final now = DateTime.now();
                const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';
                await FirebaseFirestore.instance.collection('transactions').add({
                  'item': widget.stockData['name'] ?? '', 'desc': 'Stock received',
                  'type': 'IN', 'qty': '+$qty', 'date': dateStr, 'by': byName,
                  'stockId': widget.stockId, 'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('+$qty ${widget.uom} received. New stock: $newStock'),
                    backgroundColor: Colors.green));
                  widget.onDone();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                setState(() => _loading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('✅ Confirm'),
          )),
        ]),
      ]),
    );
  }
}
