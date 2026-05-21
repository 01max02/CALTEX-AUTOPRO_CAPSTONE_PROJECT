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
  String? _selectedVehicleId;
  DateTime? _preferredDate;
  String _notes = '';
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _submitBooking() async {
    if (_selectedVehicleId == null) {
      _snack('Please select a vehicle.'); return;
    }
    if (_selectedServices.isEmpty) {
      _snack('Please select at least one service.'); return;
    }
    if (_preferredDate == null) {
      _snack('Please select a preferred date.'); return;
    }

    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final customerName = userDoc.data()?['name'] as String? ?? '';

      final vehicle = _vehicles.firstWhere((v) => v['id'] == _selectedVehicleId);
      final plate = vehicle['plate'] as String? ?? '';
      final vehicleDesc = vehicle['desc'] as String? ?? '';

      final selectedServiceNames = _services
          .where((s) => _selectedServices.contains(s['id']))
          .map((s) => s['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      final dateStr = '${_preferredDate!.year}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}';

      // Save booking
      await FirebaseFirestore.instance.collection('service_bookings').add({
        'customerId': uid,
        'customerName': customerName,
        'vehicleId': _selectedVehicleId,
        'plate': plate,
        'vehicleDesc': vehicleDesc,
        'services': selectedServiceNames,
        'preferredDate': dateStr,
        'notes': _notes.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify admin & staff
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': '📅 New Service Booking',
        'message': '$customerName booked ${selectedServiceNames.join(", ")} for $plate on $dateStr.',
        'type': 'info',
        'targetRole': 'admin',
        'targetUid': '',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String, bool>{},
        'isRead': false,
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': '📅 New Service Booking',
        'message': '$customerName booked ${selectedServiceNames.join(", ")} for $plate on $dateStr.',
        'type': 'info',
        'targetRole': 'staff',
        'targetUid': '',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String, bool>{},
        'isRead': false,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Service booked successfully! You will be notified once confirmed.'),
          backgroundColor: Colors.green,
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
                // ── Select Vehicle ──
                _sectionTitle('Select Vehicle'),
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
                if (_selectedVehicleId != null) _buildDateSuggestion(),
                if (_selectedVehicleId != null) const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(primary: _red)),
                        child: child!),
                    );
                    if (picked != null) setState(() => _preferredDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF718096)),
                      const SizedBox(width: 10),
                      Text(
                        _preferredDate != null
                            ? _fmtDatePretty(_preferredDate!)
                            : 'Tap to select date',
                        style: TextStyle(
                          fontSize: 14,
                          color: _preferredDate != null ? const Color(0xFF1a202c) : const Color(0xFFa0aec0),
                          fontWeight: _preferredDate != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ]),
                  ),
                ),

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
      (v) => v['id'] == _selectedVehicleId,
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
    final isSelected = _selectedVehicleId == v['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedVehicleId = v['id'] as String),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
          if (isSelected)
            const Icon(Icons.check_circle, color: _red, size: 20),
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
