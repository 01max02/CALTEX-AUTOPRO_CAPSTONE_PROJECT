import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerBookService extends StatefulWidget {
  const CustomerBookService({super.key});

  @override
  State<CustomerBookService> createState() => _CustomerBookServiceState();
}

class _CustomerBookServiceState extends State<CustomerBookService> {
  static const _red = Color(0xFFE8001C);

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _vehicles = [];
  final Set<String> _selectedServices = {};
  final Set<String> _selectedVehicleIds = {};
  DateTime? _preferredDate;
  String? _preferredTime;
  String _notes = '';
  bool _loading = true;
  bool _submitting = false;

  // Calendar state
  late int _calYear;
  late int _calMonth;
  Map<String, int> _bookedDates = {};
  static const _maxBookingsPerDay = 5;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calYear = now.year;
    _calMonth = now.month;
    _loadData();
    _loadBookedDates();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Load services from item_master (type = 'Service')
    final svcSnap = await FirebaseFirestore.instance
        .collection('item_master')
        .get();
    
    final serviceItems = svcSnap.docs.where((d) {
      final data = d.data();
      final type = (data['type'] as String? ?? data['itemType'] as String? ?? '').toLowerCase();
      return type == 'service';
    }).map((d) => {'id': d.id, ...d.data()}).toList();

    // Load user's vehicles
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userName = (userDoc.data()?['name'] as String? ?? '').toLowerCase();

    final vehSnap = await FirebaseFirestore.instance.collection('vehicles').get();
    final myVehicles = vehSnap.docs
        .where((d) => (d.data()['owner'] as String? ?? '').toLowerCase() == userName)
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    if (mounted) {
      setState(() {
        _services = serviceItems;
        _vehicles = myVehicles;
        _loading = false;
      });
    }
  }

  Future<void> _loadBookedDates() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('service_bookings')
          .where('status', whereIn: ['Approved', 'Pending'])
          .get();
      final Map<String, int> counts = {};
      for (final doc in snap.docs) {
        final date = doc.data()['preferredDate'] as String?;
        if (date != null) counts[date] = (counts[date] ?? 0) + 1;
      }
      if (mounted) setState(() => _bookedDates = counts);
    } catch (_) {}
  }

  Future<void> _submitBooking() async {
    if (_selectedVehicleIds.isEmpty) {
      _snack('Please select at least one vehicle.'); return;
    }
    if (_selectedServices.isEmpty) {
      _snack('Please select at least one service.'); return;
    }
    if (_preferredDate == null) {
      _snack('Please select a preferred date.'); return;
    }
    if (_preferredTime == null) {
      _snack('Please select a preferred start time.'); return;
    }

    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(uid).get();
      final customerName = userDoc.data()?['name'] as String? ?? '';
      final userStatus = (userDoc.data()?['status'] as String? ?? 'active').toLowerCase();

      final selectedVehicles = _vehicles.where((v) => _selectedVehicleIds.contains(v['id'])).toList();

      final selectedServiceNames = _services
          .where((s) => _selectedServices.contains(s['id']))
          .map((s) => s['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      final dateStr = '${_preferredDate!.year}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}';

      // ═══════════════════════════════════════════════════════════
      // AUTO-APPROVAL CHECKLIST (same as website)
      // ═══════════════════════════════════════════════════════════
      final checks = <String>[];
      bool autoApprove = true;
      String denyReason = '';

      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      final bookDate = DateTime.parse(dateStr);
      final daysAhead = bookDate.difference(todayMidnight).inDays;

      // 1. Advance Window — 1 to 30 days ahead
      if (daysAhead < 1) {
        autoApprove = false;
        denyReason = 'Same-day bookings require admin approval.';
        checks.add('❌ Advance Window: Same-day rush');
      } else if (daysAhead > 30) {
        autoApprove = false;
        denyReason = 'Bookings more than 30 days ahead require admin approval.';
        checks.add('❌ Advance Window: Too far ahead ($daysAhead days)');
      } else {
        checks.add('✅ Advance Window: $daysAhead days ahead');
      }

      // 2. Slot Availability — max 5 bookings per day
      const maxBookingsPerDay = 5;
      final slotSnap = await db.collection('service_bookings')
          .where('preferredDate', isEqualTo: dateStr)
          .where('status', whereIn: ['Approved', 'Pending'])
          .get();
      final dayBookings = slotSnap.docs.length;
      if (dayBookings >= maxBookingsPerDay) {
        autoApprove = false;
        denyReason = 'This date is fully booked. Please choose another date.';
        checks.add('❌ Slot Availability: Full ($dayBookings/$maxBookingsPerDay)');
      } else {
        checks.add('✅ Slot Availability: $dayBookings/$maxBookingsPerDay slots used');
      }

      // 3. No Duplicate — same vehicle, same day
      final firstVehicleId = _selectedVehicleIds.first;
      final dupSnap = await db.collection('service_bookings')
          .where('vehicleId', isEqualTo: firstVehicleId)
          .where('preferredDate', isEqualTo: dateStr)
          .where('status', whereIn: ['Approved', 'Pending'])
          .get();
      if (dupSnap.docs.isNotEmpty) {
        autoApprove = false;
        denyReason = 'A selected vehicle already has a booking on ${_fmtDatePretty(bookDate)}.';
        checks.add('❌ No Duplicate: Vehicle already booked on this date');
      } else {
        checks.add('✅ No Duplicate: No conflict');
      }

      // 4. Service Type Valid
      final validServiceNames = _services.map((s) => (s['name'] as String? ?? '').toLowerCase()).toList();
      final invalidSvc = selectedServiceNames.where((n) => !validServiceNames.contains(n.toLowerCase())).toList();
      if (invalidSvc.isNotEmpty) {
        autoApprove = false;
        denyReason = 'Invalid service selected: ${invalidSvc.join(', ')}';
        checks.add('❌ Service Type: Invalid (${invalidSvc.join(', ')})');
      } else {
        checks.add('✅ Service Type: All valid');
      }

      // 5. Customer Verified — account is active
      if (userStatus == 'inactive' || userStatus == 'banned') {
        autoApprove = false;
        denyReason = 'Your account is restricted. Please contact admin.';
        checks.add('❌ Customer Verified: Account $userStatus');
      } else {
        checks.add('✅ Customer Verified: Active');
      }

      // 6. Capacity Check — Sunday is closed
      if (bookDate.weekday == DateTime.sunday) {
        autoApprove = false;
        denyReason = 'Shop is closed on Sundays.';
        checks.add('❌ Capacity: Shop closed (Sunday)');
      } else {
        checks.add('✅ Capacity: Shop open');
      }

      // ═══════════════════════════════════════════════════════════
      // DECISION
      // ═══════════════════════════════════════════════════════════
      final finalStatus = autoApprove ? 'Approved' : 'Pending';

      // Create one booking per selected vehicle
      for (final vehicle in selectedVehicles) {
        final plate = vehicle['plate'] as String? ?? '';
        final vehicleDesc = vehicle['desc'] as String? ?? '';

        await db.collection('service_bookings').add({
          'customerId': uid,
          'customerName': customerName,
          'vehicleId': vehicle['id'],
          'plate': plate,
          'vehicleDesc': vehicleDesc,
          'services': selectedServiceNames,
          'preferredDate': dateStr,
          'preferredTime': _preferredTime,
          'notes': _notes.trim(),
          'status': finalStatus,
          'autoApproved': autoApprove,
          'approvalChecks': checks,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final allPlates = selectedVehicles.map((v) => v['plate'] as String? ?? '—').join(', ');

      // Send notifications based on decision
      if (autoApprove) {
        final msg = '$customerName booked ${selectedServiceNames.join(", ")} for $allPlates on ${_fmtDatePretty(bookDate)}. (Auto-approved ✅)';
        await db.collection('notifications').add({
          'title': '📅 Booking Auto-Approved', 'message': msg, 'type': 'info',
          'targetRole': 'admin', 'targetUid': '',
          'createdAt': FieldValue.serverTimestamp(), 'readBy': <String, bool>{}, 'isRead': false,
        });
        await db.collection('notifications').add({
          'title': '📅 Booking Auto-Approved', 'message': msg, 'type': 'info',
          'targetRole': 'staff', 'targetUid': '',
          'createdAt': FieldValue.serverTimestamp(), 'readBy': <String, bool>{}, 'isRead': false,
        });
        await db.collection('notifications').add({
          'title': '✅ Booking Confirmed',
          'message': 'Your service booking for $allPlates on ${_fmtDatePretty(bookDate)} has been confirmed. Services: ${selectedServiceNames.join(", ")}',
          'type': 'success', 'targetRole': 'customer', 'targetUid': uid,
          'createdAt': FieldValue.serverTimestamp(), 'readBy': <String, bool>{}, 'isRead': false,
        });
      } else {
        final msg = '$customerName requested ${selectedServiceNames.join(", ")} for $allPlates on ${_fmtDatePretty(bookDate)}. Needs review: $denyReason';
        await db.collection('notifications').add({
          'title': '⏳ Booking Needs Review', 'message': msg, 'type': 'warning',
          'targetRole': 'admin', 'targetUid': '',
          'createdAt': FieldValue.serverTimestamp(), 'readBy': <String, bool>{}, 'isRead': false,
        });
        await db.collection('notifications').add({
          'title': '⏳ Booking Pending',
          'message': 'Your booking for $allPlates on ${_fmtDatePretty(bookDate)} is pending admin approval. Reason: $denyReason',
          'type': 'warning', 'targetRole': 'customer', 'targetUid': uid,
          'createdAt': FieldValue.serverTimestamp(), 'readBy': <String, bool>{}, 'isRead': false,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(autoApprove
            ? '✅ Booking confirmed for ${selectedVehicles.length} vehicle${selectedVehicles.length > 1 ? 's' : ''}!'
            : '⏳ Booking submitted — pending admin approval. $denyReason'),
          backgroundColor: autoApprove ? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Book a Service',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Select Vehicle(s) ──
                _sectionTitle('Select Vehicle(s)'),
                const SizedBox(height: 8),
                if (_vehicles.isEmpty)
                  _emptyCard('No vehicles found under your account.')
                else
                  ..._vehicles.map((v) => _vehicleTile(v)),

                const SizedBox(height: 20),

                // ── Select Services ──
                _sectionTitle('Select Services'),
                const SizedBox(height: 8),
                if (_services.isEmpty)
                  _emptyCard('No services available.')
                else
                  ..._services.map((s) => _serviceTile(s)),

                const SizedBox(height: 20),

                // ── Preferred Date ──
                _sectionTitle('Preferred Date'),
                const SizedBox(height: 8),
                // AI suggestion
                if (_selectedVehicleIds.isNotEmpty) _buildDateSuggestion(),
                if (_selectedVehicleIds.isNotEmpty) const SizedBox(height: 8),
                // Date display field (like website's "Tap to select date" button)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _preferredDate != null ? _red : const Color(0xFFe2e8f0)),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 18,
                      color: _preferredDate != null ? _red : const Color(0xFF718096)),
                    const SizedBox(width: 10),
                    Text(
                      _preferredDate != null
                          ? _fmtDatePretty(_preferredDate!)
                          : 'Select a date from the calendar below',
                      style: TextStyle(
                        fontSize: 14,
                        color: _preferredDate != null ? const Color(0xFF1a202c) : const Color(0xFFa0aec0),
                        fontWeight: _preferredDate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                // Custom Calendar
                _buildCalendar(),

                const SizedBox(height: 20),

                // ── Preferred Start Time ──
                _sectionTitle('Preferred Start Time'),
                const SizedBox(height: 4),
                const Text('Please arrive 15 minutes before your selected time.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ['8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM']
                    .map((time) => _timeChip(time)).toList(),
                ),
                if (_preferredTime != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC6F6D5)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF38A169)),
                      const SizedBox(width: 8),
                      Text('Arrive by: ${_getArriveBy(_preferredTime!)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF276749), fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Notes ──
                _sectionTitle('Notes (optional)'),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  onChanged: (v) => _notes = v,
                  decoration: InputDecoration(
                    hintText: 'Any special requests or details...',
                    hintStyle: const TextStyle(color: Color(0xFFa0aec0), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFe2e8f0))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFe2e8f0))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _red, width: 1.5)),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Submit ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Book Service',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
    );
  }

  Widget _buildDateSuggestion() {
    final vehicle = _vehicles.firstWhere(
      (v) => v['id'] == _selectedVehicleIds.first,
      orElse: () => <String, dynamic>{},
    );
    if (vehicle.isEmpty) return const SizedBox.shrink();

    final lastSvc = (vehicle['lastSvcDate'] ?? '').toString();
    final freq = int.tryParse((vehicle['svcFreq'] ?? '').toString()) ?? 0;
    DateTime? suggestedDate;
    String reason = '';

    if (lastSvc.isNotEmpty && freq > 0) {
      final lastDate = DateTime.tryParse(lastSvc);
      if (lastDate != null) {
        final nextPms = DateTime(lastDate.year, lastDate.month + freq, lastDate.day);
        final now = DateTime.now();
        if (nextPms.isAfter(now)) {
          // Suggest 3 days before PMS due
          suggestedDate = nextPms.subtract(const Duration(days: 3));
          if (suggestedDate.isBefore(now)) suggestedDate = now.add(const Duration(days: 1));
          reason = 'Based on your PMS schedule (due ${_fmtDatePretty(nextPms)})';
        } else {
          // Overdue — suggest tomorrow
          suggestedDate = now.add(const Duration(days: 1));
          reason = 'Your PMS is overdue — we recommend booking ASAP';
        }
      }
    }

    if (suggestedDate == null) {
      // Default: suggest next available weekday
      var next = DateTime.now().add(const Duration(days: 2));
      while (next.weekday == DateTime.saturday || next.weekday == DateTime.sunday) {
        next = next.add(const Duration(days: 1));
      }
      suggestedDate = next;
      reason = 'Next available weekday';
    }

    return GestureDetector(
      onTap: () => setState(() => _preferredDate = suggestedDate),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFbee3f8)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0xFF003087).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF003087)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI Suggested Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF003087))),
            Text(
              '${_fmtDatePretty(suggestedDate!)} — $reason',
              style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
            ),
          ])),
          const Text('Use', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF003087))),
        ]),
      ),
    );
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _monthsFull = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  Widget _buildCalendar() {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(_calYear, _calMonth, 1);
    final daysInMonth = DateTime(_calYear, _calMonth + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Column(children: [
        // Header: nav + month label
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => setState(() {
              _calMonth--;
              if (_calMonth < 1) { _calMonth = 12; _calYear--; }
            }),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFe2e8f0)),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF4a5568)),
            ),
          ),
          Text('${_monthsFull[_calMonth - 1]} $_calYear',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1a202c))),
          GestureDetector(
            onTap: () => setState(() {
              _calMonth++;
              if (_calMonth > 12) { _calMonth = 1; _calYear++; }
            }),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFe2e8f0)),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF4a5568)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Day of week headers
        Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map((d) =>
          Expanded(child: Center(child: Text(d,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFa0aec0)))))).toList()),
        const SizedBox(height: 6),
        // Calendar grid
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4, crossAxisSpacing: 4,
          children: [
            // Empty cells before first day
            ...List.generate(startWeekday, (_) => const SizedBox.shrink()),
            // Day cells
            ...List.generate(daysInMonth, (i) {
              final day = i + 1;
              final date = DateTime(_calYear, _calMonth, day);
              final dateStr = '${_calYear}-${_calMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final isPast = date.isBefore(todayMidnight);
              final isSunday = date.weekday == DateTime.sunday;
              final bookings = _bookedDates[dateStr] ?? 0;
              final isFull = bookings >= _maxBookingsPerDay;
              final isSelected = _preferredDate != null &&
                  _preferredDate!.year == _calYear &&
                  _preferredDate!.month == _calMonth &&
                  _preferredDate!.day == day;
              final isClosed = isPast || isSunday;
              final isAvailable = !isClosed && !isFull;

              Color bgColor;
              Color textColor;
              Color dotColor;
              if (isSelected) {
                bgColor = _red;
                textColor = Colors.white;
                dotColor = Colors.white70;
              } else if (isClosed) {
                bgColor = const Color(0xFFF1F5F9);
                textColor = const Color(0xFFcbd5e0);
                dotColor = const Color(0xFFcbd5e0);
              } else if (isFull) {
                bgColor = const Color(0xFFFEF3C7);
                textColor = const Color(0xFF92400E);
                dotColor = const Color(0xFFD97706);
              } else {
                bgColor = const Color(0xFFF0FDF4);
                textColor = const Color(0xFF1a202c);
                dotColor = const Color(0xFF38A169);
              }

              return GestureDetector(
                onTap: isAvailable ? () => setState(() => _preferredDate = date) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected ? Border.all(color: _red, width: 2) : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 2),
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  ]),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        // Legend
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F4F8)))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendItem(const Color(0xFF38A169), 'Available'),
            const SizedBox(width: 16),
            _legendDot(const Color(0xFFD97706), const Color(0xFFFEF3C7), 'Fully Booked'),
            const SizedBox(width: 16),
            _legendItem(const Color(0xFFe2e8f0), 'Closed / Past'),
          ]),
        ),
      ]),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
    ]);
  }

  Widget _legendDot(Color borderColor, Color bgColor, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
        color: bgColor, shape: BoxShape.circle, border: Border.all(color: borderColor, width: 2))),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
    ]);
  }

  static const _arriveByMap = {
    '8:00 AM': '7:45 AM', '9:00 AM': '8:45 AM', '10:00 AM': '9:45 AM', '11:00 AM': '10:45 AM',
    '1:00 PM': '12:45 PM', '2:00 PM': '1:45 PM', '3:00 PM': '2:45 PM', '4:00 PM': '3:45 PM',
  };

  String _getArriveBy(String time) => _arriveByMap[time] ?? time;

  Widget _timeChip(String time) {
    final isSelected = _preferredTime == time;
    return GestureDetector(
      onTap: () => setState(() => _preferredTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _red : const Color(0xFFe2e8f0),
            width: isSelected ? 2 : 1.5),
        ),
        child: Text(time, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: isSelected ? _red : const Color(0xFF4a5568))),
      ),
    );
  }

  String _fmtDatePretty(DateTime d) {
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _sectionTitle(String title) => Text(title,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1a202c)));

  Widget _emptyCard(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFe2e8f0))),
    child: Text(msg, style: const TextStyle(color: Color(0xFF718096), fontSize: 13), textAlign: TextAlign.center),
  );

  Widget _vehicleTile(Map<String, dynamic> v) {
    final id = v['id'] as String;
    final isSelected = _selectedVehicleIds.contains(id);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) { _selectedVehicleIds.remove(id); }
        else { _selectedVehicleIds.add(id); }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _red : const Color(0xFFe2e8f0),
            width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(
            ((v['type'] as String?) ?? '').toLowerCase().contains('truck')
                ? Icons.local_shipping_outlined
                : Icons.directions_car_outlined,
            color: isSelected ? _red : const Color(0xFF718096), size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v['plate'] as String? ?? '—',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                color: isSelected ? _red : const Color(0xFF1a202c))),
            Text(v['desc'] as String? ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
          ])),
          Icon(
            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            color: isSelected ? _red : const Color(0xFFcbd5e0), size: 22),
        ]),
      ),
    );
  }

  Widget _serviceTile(Map<String, dynamic> s) {
    final id = s['id'] as String;
    final isSelected = _selectedServices.contains(id);
    final name = (s['name'] ?? '').toString();
    final rawCost = (s['cost'] ?? '').toString().replaceAll('₱', '').replaceAll(',', '').trim();
    final costDisplay = rawCost.isNotEmpty ? '₱$rawCost' : '';
    final uom = (s['uom'] ?? '').toString();

    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) { _selectedServices.remove(id); }
        else { _selectedServices.add(id); }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _red : const Color(0xFFe2e8f0),
            width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isSelected ? _red.withOpacity(0.1) : const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.build_outlined,
              color: isSelected ? _red : const Color(0xFF003087), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
              color: isSelected ? _red : const Color(0xFF1a202c))),
            if (costDisplay.isNotEmpty)
              Text('$costDisplay / $uom', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
          ])),
          Icon(
            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            color: isSelected ? _red : const Color(0xFFcbd5e0), size: 22),
        ]),
      ),
    );
  }
}
