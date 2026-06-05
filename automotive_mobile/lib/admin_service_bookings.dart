import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminServiceBookings extends StatefulWidget {
  const AdminServiceBookings({super.key});

  @override
  State<AdminServiceBookings> createState() => _AdminServiceBookingsState();
}

class _AdminServiceBookingsState extends State<AdminServiceBookings> {
  static const _red = Color(0xFFE8001C);
  static const _blue = Color(0xFF003087);
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  String _filter = 'Approved'; // Approved or Dismissed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Service Bookings',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // Tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _tabBtn('Approved', 'Approved', const Color(0xFF38a169)),
            _tabBtn('Cancelled', 'Dismissed', const Color(0xFF718096)),
          ]),
        ),
        // List
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _tabBtn(String label, String filter, Color activeColor) {
    final active = _filter == filter;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? activeColor : Colors.transparent, width: 2))),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active ? activeColor : const Color(0xFF718096))),
      ),
    ));
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_bookings')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snapshot.data?.docs ?? [];
        final filtered = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == _filter;
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No ${_filter == 'Approved' ? 'approved' : 'cancelled'} bookings.',
                style: const TextStyle(color: Color(0xFF718096), fontSize: 13)),
          ]));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final doc = filtered[i];
            final data = doc.data() as Map<String, dynamic>;
            return _buildCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildCard(String docId, Map<String, dynamic> data) {
    final plate = data['plate'] as String? ?? '—';
    final customerName = data['customerName'] as String? ?? '—';
    final services = (data['services'] as List?)?.join(', ') ?? '—';
    final preferredDate = data['preferredDate'] as String? ?? '';
    final preferredTime = data['preferredTime'] as String? ?? '—';
    final previousDate = data['previousDate'] as String? ?? '';
    final isRescheduled = previousDate.isNotEmpty && previousDate != preferredDate;
    final isApproved = data['status'] == 'Approved';

    Color statusColor;
    String statusLabel;
    if (isRescheduled && isApproved) {
      statusColor = _blue;
      statusLabel = 'Rescheduled';
    } else if (isApproved) {
      statusColor = const Color(0xFF38a169);
      statusLabel = 'Approved';
    } else {
      statusColor = const Color(0xFF718096);
      statusLabel = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: plate + status badge
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plate, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1a202c))),
            const SizedBox(height: 2),
            Text(customerName, style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 10),
        // Services
        Text(services, style: const TextStyle(fontSize: 12, color: Color(0xFF718096)), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        // Date and time
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF718096)),
          const SizedBox(width: 5),
          Text(_formatDate(preferredDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1a202c))),
          const SizedBox(width: 12),
          const Icon(Icons.access_time_outlined, size: 13, color: Color(0xFF718096)),
          const SizedBox(width: 5),
          Text(preferredTime, style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568))),
        ]),
        // Reschedule note
        if (isRescheduled) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF6E05E)),
            ),
            child: Row(children: [
              const Icon(Icons.history, size: 12, color: Color(0xFF92400E)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Rescheduled from ${_formatDate(previousDate)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
              )),
            ]),
          ),
        ],
        // Actions for Approved bookings
        if (isApproved) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => _showRescheduleModal(docId, data),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: Color(0xFF003087)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Reschedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(
              onPressed: () => _dismissBooking(docId, plate),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: Color(0xFFE8001C)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            )),
          ]),
        ],
      ]),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '—';
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return dateStr;
    return '${_months[m - 1]} $d, $y';
  }

  void _dismissBooking(String docId, String plate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text('Cancel service booking for $plate?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('service_bookings').doc(docId).update({'status': 'Dismissed'});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Booking cancelled.'), backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating));
              }
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRescheduleModal(String docId, Map<String, dynamic> data) {
    final plate = data['plate'] as String? ?? '—';
    final currentDate = data['preferredDate'] as String? ?? '';
    final customerId = data['customerId'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RescheduleSheet(
        docId: docId,
        plate: plate,
        currentDate: currentDate,
        customerId: customerId,
      ),
    );
  }
}

class _RescheduleSheet extends StatefulWidget {
  final String docId;
  final String plate;
  final String currentDate;
  final String customerId;

  const _RescheduleSheet({
    required this.docId,
    required this.plate,
    required this.currentDate,
    required this.customerId,
  });

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  static const _blue = Color(0xFF003087);
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  static const _maxPerDay = 5;

  late int _year;
  late int _month;
  String? _selectedDate;
  Map<String, int> _bookedDates = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadBookedDates();
  }

  Future<void> _loadBookedDates() async {
    final snap = await FirebaseFirestore.instance
        .collection('service_bookings')
        .where('status', whereIn: ['Approved', 'Pending'])
        .get();
    final counts = <String, int>{};
    for (final d in snap.docs) {
      final date = (d.data())['preferredDate'] as String? ?? '';
      if (date.isNotEmpty) counts[date] = (counts[date] ?? 0) + 1;
    }
    if (mounted) setState(() { _bookedDates = counts; _loading = false; });
  }

  void _navMonth(int dir) {
    setState(() {
      _month += dir;
      if (_month > 12) { _month = 1; _year++; }
      if (_month < 1) { _month = 12; _year--; }
    });
  }

  Future<void> _confirm() async {
    if (_selectedDate == null) return;
    final db = FirebaseFirestore.instance;

    await db.collection('service_bookings').doc(widget.docId).update({
      'preferredDate': _selectedDate,
      'previousDate': widget.currentDate,
      'rescheduledBy': 'admin',
      'rescheduledAt': FieldValue.serverTimestamp(),
    });

    // Notify customer
    if (widget.customerId.isNotEmpty) {
      await db.collection('notifications').add({
        'title': '📅 Booking Rescheduled',
        'message': 'Your booking for ${widget.plate} has been rescheduled from ${_fmt(widget.currentDate)} to ${_fmt(_selectedDate!)}.',
        'type': 'warning',
        'targetRole': 'customer',
        'targetUid': widget.customerId,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String, bool>{},
        'isRead': false,
      });
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking rescheduled to ${_fmt(_selectedDate!)}'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
    }
  }

  String _fmt(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    final y = int.tryParse(parts[0]) ?? 2026;
    return '${_months[m - 1]} $d, $y';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF003087), Color(0xFF001d52)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              const Expanded(child: Text('Reschedule Booking',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close, color: Colors.white, size: 16)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.plate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1a202c))),
              if (widget.currentDate.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Current: ${_fmt(widget.currentDate)}', style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
              ],
              const SizedBox(height: 16),
              const Text('Select new date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4a5568))),
              const SizedBox(height: 10),

              // Month nav
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(onTap: () => _navMonth(-1),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFe2e8f0)), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF4a5568)))),
                Text('${_months[_month - 1]} $_year', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                GestureDetector(onTap: () => _navMonth(1),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFe2e8f0)), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF4a5568)))),
              ]),
              const SizedBox(height: 10),

              // Calendar
              _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  : _buildCalendar(),

              const SizedBox(height: 12),
              // Legend
              Wrap(spacing: 12, runSpacing: 4, children: [
                _legend(const Color(0xFF38a169), 'Available'),
                _legend(const Color(0xFFd97706), 'Full'),
                _legend(const Color(0xFFe2e8f0), 'Closed'),
                _legend(_blue, 'Current'),
              ]),

              const SizedBox(height: 16),
              // Selected date info
              if (_selectedDate != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF38a169))),
                  child: Text('📅 New Date: ${_fmt(_selectedDate!)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF38a169))),
                ),

              // Buttons
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _selectedDate != null ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: _blue.withOpacity(0.4),
                  ),
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF718096))),
    ]);
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(_year, _month, 1);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;

    final dow = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
    final cells = <Widget>[];

    for (final d in dow) {
      cells.add(Center(child: Text(d, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFa0aec0)))));
    }

    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final dt = DateTime(_year, _month, d);
      final key = '$_year-${_month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final isPast = dt.isBefore(today);
      final isSunday = dt.weekday == 7;
      final isCurrent = key == widget.currentDate;
      final isSelected = key == _selectedDate;
      final bookings = _bookedDates[key] ?? 0;
      final isFull = bookings >= _maxPerDay;
      final isDisabled = isPast || isSunday || isFull;

      Color bg;
      Color textColor;
      BoxBorder? border;
      if (isSelected) {
        bg = _blue;
        textColor = Colors.white;
      } else if (isCurrent && !isPast) {
        bg = const Color(0xFFEBF8FF);
        textColor = _blue;
        border = Border.all(color: _blue, width: 2);
      } else if (isPast || isSunday) {
        bg = const Color(0xFFF1F5F9);
        textColor = const Color(0xFFcbd5e0);
      } else if (isFull) {
        bg = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
      } else {
        bg = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF1a202c);
      }

      cells.add(GestureDetector(
        onTap: isDisabled ? null : () => setState(() => _selectedDate = key),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: border,
            boxShadow: isSelected ? [BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 6)] : null,
          ),
          child: Center(child: Text('$d', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor))),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1.2,
      children: cells,
    );
  }
}
