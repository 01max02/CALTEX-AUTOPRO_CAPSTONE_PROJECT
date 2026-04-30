import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pms_history_details.dart';

class CustomerPms extends StatefulWidget {
  const CustomerPms({super.key});

  @override
  State<CustomerPms> createState() => _CustomerPmsState();
}

class _CustomerPmsState extends State<CustomerPms> {
  static const _red = Color(0xFFE8001C);
  static const _bg = Color(0xFFF7F8FA);

  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) setState(() => _userName = doc['name'] as String? ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_userName.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: _bg,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vehicles')
            .snapshots(),
        builder: (context, vSnap) {
          if (vSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final myVehicles = (vSnap.data?.docs ?? [])
              .where((d) => (d['owner'] as String? ?? '').toLowerCase() == _userName.toLowerCase())
              .toList();

          if (myVehicles.isEmpty) {
            return const Center(child: Text('No vehicles registered under your name.',
              style: TextStyle(color: Color(0xFF718096))));
          }

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(children: [
                const Icon(Icons.history, color: _red, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('PMS History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1a202c)))),
                Text('${myVehicles.length} vehicle${myVehicles.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: myVehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final vData = myVehicles[i].data() as Map<String, dynamic>;
                  final plate = vData['plate'] as String? ?? '';
                  final desc = vData['desc'] as String? ?? '';
                  final type = vData['type'] as String? ?? '';
                  return _VehicleHistoryCard(plate: plate, desc: desc, type: type);
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _VehicleHistoryCard extends StatelessWidget {
  final String plate;
  final String desc;
  final String type;
  static const _red = Color(0xFFE8001C);

  const _VehicleHistoryCard({required this.plate, required this.desc, required this.type});

  IconData get _vehicleIcon {
    final t = type.toLowerCase();
    if (t.contains('car')) return Icons.directions_car_outlined;
    if (t.contains('truck')) return Icons.local_shipping_outlined;
    return Icons.directions_car_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('maintenance')
          .where('plate', isEqualTo: plate)
          .where('status', isEqualTo: 'Completed')
          .snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final aTime = (a.data() as Map)['createdAt'];
            final bTime = (b.data() as Map)['createdAt'];
            if (aTime == null || bTime == null) return 0;
            return (bTime as Timestamp).compareTo(aTime as Timestamp);
          });
        final totalCost = docs.fold<double>(0, (sum, d) {
          final cost = (d['cost'] as String? ?? '0').replaceAll('₱', '').replaceAll(',', '');
          return sum + (double.tryParse(cost) ?? 0);
        });

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PmsHistoryDetails(plate: plate, desc: desc, type: type),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: _red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Icon(_vehicleIcon, color: _red, size: 22),
              ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1a202c))),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.receipt_long_outlined, size: 12, color: Color(0xFF718096)),
                  const SizedBox(width: 4),
                  Text('${docs.length} service record${docs.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₱${totalCost.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1a202c))),
                const Text('total spent', style: TextStyle(fontSize: 9, color: Color(0xFF718096))),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right, color: Color(0xFF718096), size: 18),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
