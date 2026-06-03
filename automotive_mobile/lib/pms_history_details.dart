import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PmsHistoryDetails extends StatelessWidget {
  final String plate;
  final String desc;
  final String type;

  static const _red = Color(0xFFE8001C);
  static const _bg = Color(0xFFF7F8FA);

  const PmsHistoryDetails({super.key, required this.plate, required this.desc, required this.type});

  IconData get _vehicleIcon {
    final t = type.toLowerCase();
    if (t.contains('car')) return Icons.directions_car_outlined;
    if (t.contains('truck')) return Icons.local_shipping_outlined;
    return Icons.directions_car_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<QuerySnapshot>(
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
            final cost = (d['cost'] as String? ?? '0')
                .replaceAll('₱', '')
                .replaceAll(',', '');
            return sum + (double.tryParse(cost) ?? 0);
          });

          return CustomScrollView(
            slivers: [
              // ── App Bar ──
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: _red,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                // Only show plate in the toolbar when collapsed
                title: _CollapsedTitle(plate: plate),
                flexibleSpace: FlexibleSpaceBar(
                  // No title here — avoids the overlap
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE8001C), Color(0xFFC41E3A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 44),
                          Text(plate,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(desc,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Summary strip ──
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(children: [
                    _summaryChip(
                      Icons.receipt_long_outlined,
                      '${docs.length}',
                      'Service${docs.length != 1 ? 's' : ''}',
                      const Color(0xFF003087),
                    ),
                    const SizedBox(width: 12),
                    _summaryChip(
                      Icons.payments_outlined,
                      '₱${totalCost.toStringAsFixed(2)}',
                      'Total Spent',
                      _red,
                    ),
                  ]),
                ),
              ),

              // ── Section header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(children: [
                    const Icon(Icons.history, color: _red, size: 16),
                    const SizedBox(width: 6),
                    const Text('Service Records',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1a202c))),
                  ]),
                ),
              ),

              // ── Records list ──
              snap.connectionState == ConnectionState.waiting
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()))
                  : docs.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text('No completed services yet.',
                                style: TextStyle(color: Color(0xFF718096))),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _ServiceRecordCard(
                                      data: docs[i].data()
                                          as Map<String, dynamic>),
                                );
                              },
                              childCount: docs.length,
                            ),
                          ),
                        ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryChip(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF718096))),
          ]),
        ]),
      ),
    );
  }
}

// ── Individual service record card ──────────────────────────────────────────
class _ServiceRecordCard extends StatelessWidget {
  final Map<String, dynamic> data;
  static const _red = Color(0xFFE8001C);

  const _ServiceRecordCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final svcRows = (data['svcRows'] as List<dynamic>? ?? [])
        .where((x) => (x['name'] as String? ?? '').isNotEmpty)
        .toList();
    final matRows = (data['matRows'] as List<dynamic>? ?? [])
        .where((x) => (x['name'] as String? ?? '').isNotEmpty)
        .toList();
    final issues = (data['issues'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
                bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: Color(0xFF718096)),
            const SizedBox(width: 6),
            Text(data['date'] as String? ?? '—',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1a202c))),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Completed',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // ── Body ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 13, color: Color(0xFF718096)),
              const SizedBox(width: 5),
              Text('Mechanic: ${data['mechanic'] ?? '—'}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF718096))),
            ]),

            if (issues.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionLabel(Icons.warning_amber_outlined, 'Vehicle Issues Reported', const Color(0xFFE8001C)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: issues.map((issue) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFED7D7), width: 1.5),
                  ),
                  child: Text(issue,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE8001C))),
                )).toList(),
              ),
            ],

            if (svcRows.isNotEmpty) ...[
              const SizedBox(height: 14),
              _sectionLabel(Icons.build_outlined, 'Services Rendered',
                  const Color(0xFF2b6cb0)),
              const SizedBox(height: 8),
              ...svcRows.map(
                  (s) => _lineItem(s as Map<String, dynamic>, const Color(0xFF2b6cb0))),
            ],

            if (matRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionLabel(
                  Icons.inventory_2_outlined, 'Materials Used', Colors.teal),
              const SizedBox(height: 8),
              ...matRows.map(
                  (m) => _lineItem(m as Map<String, dynamic>, Colors.teal)),
            ],

            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF4a5568))),
              Text(data['cost'] as String? ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _red)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(IconData icon, String label, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 7),
      Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  Widget _lineItem(Map<String, dynamic> item, Color color) {
    final unitCost =
        double.tryParse((item['cost'] as String? ?? '0').replaceAll('₱', '')) ??
            0;
    final qty =
        double.tryParse(item['qty'] as String? ?? '1') ?? 1;
    final subtotal = unitCost * qty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(item['name'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF1a202c)))),
        Text('${item['qty']} ${item['uom']}',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF718096))),
        const SizedBox(width: 10),
        Text('₱${subtotal.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a202c))),
      ]),
    );
  }
}

// ── Collapsed title — fades in only when the SliverAppBar is scrolled up ──
class _CollapsedTitle extends StatelessWidget {
  final String plate;
  const _CollapsedTitle({required this.plate});

  @override
  Widget build(BuildContext context) {
    // FlexibleSpaceBar collapses when scroll offset reaches expandedHeight - kToolbarHeight.
    // We read the FlexibleSpaceBar's collapse ratio via the ancestor ScrollView.
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final double opacity = settings == null
        ? 1.0
        : (1.0 -
                ((settings.currentExtent - settings.minExtent) /
                    (settings.maxExtent - settings.minExtent)))
            .clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Text(
        plate,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
