import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_book_service.dart';

class CustomerMyBookings extends StatefulWidget {
  /// When [embedded] is true (inside a TabBarView), the AppBar is hidden
  /// because the parent scaffold already provides one.
  final bool embedded;
  const CustomerMyBookings({super.key, this.embedded = false});

  @override
  State<CustomerMyBookings> createState() => _CustomerMyBookingsState();
}

class _CustomerMyBookingsState extends State<CustomerMyBookings> {
  static const _red = Color(0xFFE8001C);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: false,
        title: const Text('My Bookings',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CustomerBookService())),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: Color(0xFFE8001C), size: 16),
                SizedBox(width: 4),
                Text('Book Service', style: TextStyle(color: Color(0xFFE8001C), fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_bookings')
            .where('customerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading bookings:\n${snapshot.error}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Sort locally by createdAt descending
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No bookings yet.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF718096))),
                const SizedBox(height: 4),
                const Text('Book a service to get started.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFa0aec0))),
              ]),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _bookingCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> data) {
    final plate = data['plate'] as String? ?? '—';
    final vehicleDesc = data['vehicleDesc'] as String? ?? '';
    final services = (data['services'] as List<dynamic>?)?.cast<String>() ?? [];
    final date = data['preferredDate'] as String? ?? '';
    final time = data['preferredTime'] as String? ?? '';
    final status = data['status'] as String? ?? 'Pending';
    final notes = data['notes'] as String? ?? '';
    final previousDate = data['previousDate'] as String? ?? '';
    final isRescheduled = previousDate.isNotEmpty && previousDate != date;

    Color statusColor;
    IconData statusIcon;
    String displayStatus = status;

    // All booking cards use purple to match the calendar dot color
    const bookingPurple = Color(0xFF7c3aed);

    if (isRescheduled && status.toLowerCase() == 'approved') {
      statusColor = bookingPurple;
      statusIcon = Icons.update;
      displayStatus = 'Rescheduled';
    } else {
      switch (status.toLowerCase()) {
        case 'approved':
          statusColor = bookingPurple;
          statusIcon = Icons.check_circle_outline;
          break;
        case 'completed':
          statusColor = bookingPurple;
          statusIcon = Icons.task_alt;
          break;
        case 'cancelled':
        case 'rejected':
          statusColor = bookingPurple;
          statusIcon = Icons.cancel_outlined;
          break;
        default: // Pending
          statusColor = bookingPurple;
          statusIcon = Icons.schedule_outlined;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: plate + status
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plate, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1a202c))),
            if (vehicleDesc.isNotEmpty)
              Text(vehicleDesc, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 13, color: statusColor),
              const SizedBox(width: 4),
              Text(displayStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
            ]),
          ),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Services
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.build_outlined, size: 14, color: Color(0xFF718096)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            services.isNotEmpty ? services.join(', ') : '—',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568)),
          )),
        ]),

        const SizedBox(height: 8),

        // Date & Time
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF718096)),
          const SizedBox(width: 8),
          Text(date.isNotEmpty ? _fmtDate(date) : '—',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568))),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 12),
            const Icon(Icons.access_time_outlined, size: 14, color: Color(0xFF718096)),
            const SizedBox(width: 4),
            Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568))),
          ],
        ]),

        // Notes
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.notes_outlined, size: 14, color: Color(0xFF718096)),
            const SizedBox(width: 8),
            Expanded(child: Text(notes,
                style: const TextStyle(fontSize: 11, color: Color(0xFF718096), fontStyle: FontStyle.italic))),
          ]),
        ],

        // Reschedule note
        if (isRescheduled) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFF6E05E)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.update, size: 14, color: Color(0xFF92400E)),
              const SizedBox(width: 8),
              Expanded(child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  children: [
                    const TextSpan(text: 'Rescheduled from '),
                    TextSpan(text: _fmtDate(previousDate), style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough)),
                    const TextSpan(text: ' to '),
                    TextSpan(text: _fmtDate(date), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  String _fmtDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
