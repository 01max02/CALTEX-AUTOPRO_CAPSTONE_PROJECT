import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerSmartAI extends StatefulWidget {
  const CustomerSmartAI({super.key});

  @override
  State<CustomerSmartAI> createState() => _CustomerSmartAIState();
}

class _CustomerSmartAIState extends State<CustomerSmartAI> {
  static const _red = Color(0xFFE8001C);

  final List<Map<String, String>> _messages = [];
  final _chatCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Live data loaded from Firestore for this customer
  List<Map<String, dynamic>> _myVehicles    = [];
  List<Map<String, dynamic>> _myMaintenance = [];
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userName = userDoc['name'] as String? ?? '';

    final vSnap = await FirebaseFirestore.instance
        .collection('vehicles')
        .get();
    _myVehicles = vSnap.docs
        .where((d) => (d['owner'] as String? ?? '').toLowerCase() == userName.toLowerCase())
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();

    if (_myVehicles.isNotEmpty) {
      final plates = _myVehicles.map((v) => v['plate'] as String).toList();
      final mSnap = await FirebaseFirestore.instance
          .collection('maintenance')
          .where('plate', whereIn: plates)
          .get();
      _myMaintenance = mSnap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    }

    if (mounted) setState(() => _dataLoaded = true);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _send([String? preset]) {
    final text = (preset ?? _chatCtrl.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _chatCtrl.clear();
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 500), () {
      final reply = _dataLoaded ? _processQuery(text) : 'Loading your data, please try again in a moment.';
      setState(() => _messages.add({'role': 'ai', 'text': reply}));
      _scrollToBottom();
    });
  }

  String _processQuery(String query) {
    final q = query.toLowerCase();

    if (_myVehicles.isEmpty) {
      return 'No vehicles are registered under your name yet.';
    }

    // Under maintenance
    if (q.contains('maintenance') || q.contains('being serviced')) {
      final list = _myVehicles.where((v) =>
          (v['status'] as String? ?? '').toLowerCase().contains('maintenance')).toList();
      if (list.isEmpty) return 'None of your vehicles are currently under maintenance. ✅';
      return 'Under maintenance:\n${list.map((v) => '• ${v['plate']} — ${v['desc']}').join('\n')}';
    }

    // Overdue
    if (q.contains('overdue') || q.contains('past due')) {
      final list = _myVehicles.where((v) => v['status'] == 'Overdue').toList();
      if (list.isEmpty) return 'No vehicles are overdue for PMS. ✅';
      return 'PMS Overdue:\n${list.map((v) => '• ${v['plate']} — ${v['desc']}').join('\n')}\n\nPlease schedule a service soon!';
    }

    // Due soon
    if (q.contains('due soon') || q.contains('upcoming') || q.contains('schedule')) {
      final list = _myVehicles.where((v) => v['status'] == 'PMS Due Soon').toList();
      if (list.isEmpty) return 'No vehicles have PMS due soon. ✅';
      return 'PMS Due Soon:\n${list.map((v) => '• ${v['plate']} — ${v['desc']}').join('\n')}';
    }

    // History / service records
    if (q.contains('history') || q.contains('service record') || q.contains('completed')) {
      final completed = _myMaintenance.where((m) => m['status'] == 'Completed').toList();
      if (completed.isEmpty) return 'No completed service records found for your vehicles.';
      final total = completed.fold<double>(0, (sum, m) {
        final cost = (m['cost'] as String? ?? '0').replaceAll('₱', '').replaceAll(',', '');
        return sum + (double.tryParse(cost) ?? 0);
      });
      return 'You have ${completed.length} completed service record${completed.length != 1 ? 's' : ''}.\n'
          'Total spent: ₱${total.toStringAsFixed(2)}\n\n'
          'Tap "PMS Log" in the bottom nav to view full history.';
    }

    // All vehicles / fleet
    if (q.contains('vehicle') || q.contains('fleet') || q.contains('all my') || q.contains('list')) {
      final lines = _myVehicles.map((v) {
        final status = v['status'] as String? ?? 'Active';
        final emoji = status == 'Active' ? '✅'
            : status == 'Under Maintenance' ? '🔧'
            : status == 'Overdue' ? '⚠️'
            : status == 'PMS Due Soon' ? '📅'
            : '•';
        return '$emoji ${v['plate']} — ${v['desc']} ($status)';
      }).join('\n');
      return 'Your fleet (${_myVehicles.length} vehicle${_myVehicles.length != 1 ? 's' : ''}):\n$lines';
    }

    // Status summary
    if (q.contains('status') || q.contains('summary') || q.contains('report')) {
      final active = _myVehicles.where((v) => v['status'] == 'Active').length;
      final maint  = _myVehicles.where((v) => (v['status'] as String? ?? '').contains('Maintenance')).length;
      final over   = _myVehicles.where((v) => v['status'] == 'Overdue').length;
      final soon   = _myVehicles.where((v) => v['status'] == 'PMS Due Soon').length;
      return 'Fleet Summary:\n'
          '✅ Active: $active\n'
          '🔧 Under Maintenance: $maint\n'
          '⚠️ PMS Overdue: $over\n'
          '📅 Due Soon: $soon\n'
          '🚗 Total: ${_myVehicles.length}';
    }

    return 'I can help you with:\n'
        '• Vehicle status & fleet summary\n'
        '• PMS overdue or due soon\n'
        '• Vehicles under maintenance\n'
        '• Service history & total cost\n\n'
        'Try asking: "Which vehicles are overdue?"';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Smart Reports AI',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Clear chat',
              onPressed: () => setState(() => _messages.clear()),
            ),
        ],
      ),
      body: Column(children: [
        // ── Messages ──
        Expanded(
          child: !_dataLoaded
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading your fleet data...', style: TextStyle(color: Color(0xFF718096))),
                ]))
              : _messages.isEmpty
                  ? _buildWelcome()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildBubble(_messages[i]),
                    ),
        ),

        // ── Quick chips (only when empty) ──
        if (_messages.isEmpty && _dataLoaded)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _chip('🚗 My fleet', 'List all my vehicles'),
              _chip('📊 Summary', 'Give me a fleet summary'),
              _chip('🔧 Maintenance', 'Which vehicles are under maintenance?'),
              _chip('⚠️ Overdue', 'Which vehicles have PMS overdue?'),
              _chip('📅 Due soon', 'Which vehicles have PMS due soon?'),
              _chip('📋 History', 'Show my service history'),
            ]),
          ),

        // ── Input ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask about your vehicles...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF718096)),
                  filled: true, fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _red, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildWelcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFF003087).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF003087), size: 32),
        ),
        const SizedBox(height: 14),
        const Text('Smart Reports AI',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1a202c))),
        const SizedBox(height: 6),
        Text(
          _myVehicles.isEmpty
              ? 'No vehicles found under your account.'
              : 'Ask me anything about your ${_myVehicles.length} vehicle${_myVehicles.length != 1 ? 's' : ''} — PMS status, maintenance history, and more.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF718096), height: 1.5)),
      ]),
    );
  }

  Widget _buildBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? _red : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Text(msg['text']!,
            style: TextStyle(
                fontSize: 13,
                color: isUser ? Colors.white : const Color(0xFF1a202c),
                height: 1.5)),
      ),
    );
  }

  Widget _chip(String label, String query) {
    return GestureDetector(
      onTap: () => _send(query),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFe2e8f0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568), fontWeight: FontWeight.w500)),
      ),
    );
  }
}
