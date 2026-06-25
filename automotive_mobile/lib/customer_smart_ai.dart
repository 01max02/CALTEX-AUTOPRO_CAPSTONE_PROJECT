import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Base URL of the ai_assistant FastAPI service.
//  Android emulator → 10.0.2.2 maps to the host machine's localhost.
//  Physical device  → use your LAN IP, e.g. 192.168.1.x
//  Override: flutter run --dart-define=AI_BACKEND_URL=http://192.168.1.5:8002
// ─────────────────────────────────────────────────────────────────────────────
const _kAiBaseUrl = String.fromEnvironment(
  'AI_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:8002',
);

class CustomerSmartAI extends StatefulWidget {
  const CustomerSmartAI({super.key});

  @override
  State<CustomerSmartAI> createState() => _CustomerSmartAIState();
}

class _CustomerSmartAIState extends State<CustomerSmartAI> {
  static const _red  = Color(0xFFE8001C);
  static const _blue = Color(0xFF003087);

  final _chatCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_Msg> _messages = [];
  final List<Map<String, String>> _history = []; // legacy — kept for fallback only
  String? _sessionId;  // server-side memory key

  // Customer identity — loaded from Firebase, needed for scoped AI queries
  String _customerUid  = '';
  String _customerName = '';
  int    _vehicleCount = 0;

  bool _dataLoaded    = false;
  bool _loading       = false;
  bool _backendOnline = false;
  bool _rateLimited   = false;
  String _resetIn     = '';

  @override
  void initState() {
    super.initState();
    _loadIdentity();
    _checkBackend();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Load customer identity from Firebase ────────────────────────────────────

  Future<void> _loadIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _customerUid = user.uid;

    // Get display name from Firestore users collection
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final name = doc.data()?['name'] as String? ?? user.displayName ?? '';
    _customerName = name;

    // Count their vehicles for the welcome message
    if (name.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('owner', isEqualTo: name)
          .get();
      _vehicleCount = snap.docs.length;
    }

    if (mounted) setState(() => _dataLoaded = true);
  }

  // ── Backend health ──────────────────────────────────────────────────────────

  Future<void> _checkBackend() async {
    try {
      final r = await http
          .get(Uri.parse('$_kAiBaseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (mounted) setState(() => _backendOnline = r.statusCode == 200);
    } catch (_) {
      if (mounted) setState(() => _backendOnline = false);
    }
  }

  // ── Scroll ──────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send message ────────────────────────────────────────────────────────────

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _chatCtrl.text).trim();
    if (text.isEmpty || _loading) return;
    if (_rateLimited) return;

    if (!_dataLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Still loading your data, please wait…'),
            duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _chatCtrl.clear();
      _loading = true;
    });
    _scrollToBottom();

    final historyPayload = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : List<Map<String, String>>.from(_history);

    try {
      final resp = await http
          .post(
            Uri.parse('$_kAiBaseUrl/customer/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message':       text,
              'customer_uid':  _customerUid,
              'customer_name': _customerName,
              'session_id':    _sessionId,  // server-side memory key
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final data  = jsonDecode(resp.body) as Map<String, dynamic>;
        final reply = (data['reply'] as String? ?? '').trim();
        final answer = reply.isNotEmpty ? reply : 'No response generated.';

        // Persist session_id for memory continuity
        if (data['session_id'] != null) {
          _sessionId = data['session_id'] as String;
        }

        // Handle rate limit
        if (data['rate_limited'] == true) {
          final resetIn = data['reset_in'] as String? ?? 'some time';
          setState(() {
            _loading = false;
            _rateLimited = true;
            _resetIn = resetIn;
            _messages.add(_Msg(role: 'ai', text: data['reply'] as String? ?? ''));
          });
          return;
        }

        setState(() {
          _loading = false;
          _messages.add(_Msg(role: 'ai', text: answer));
        });
      } else {
        final err = _parseError(resp.body);
        setState(() {
          _loading = false;
          _messages.add(_Msg(
              role: 'ai',
              text: '⚠️ AI service error (${resp.statusCode}): $err'));
        });
      }
    } on http.ClientException catch (e) {
      setState(() {
        _loading = false;
        _messages.add(_Msg(
            role: 'ai',
            text: '🔌 Cannot reach the AI service.\n\n'
                'Make sure the backend is running:\n'
                '  cd ai_assistant\n'
                '  venv\\Scripts\\uvicorn main:app --port 8002\n\n'
                'Error: $e'));
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _messages.add(_Msg(role: 'ai', text: '⚠️ Unexpected error: $e'));
      });
    }
    _scrollToBottom();
  }

  String _parseError(String body) {
    try {
      final d = jsonDecode(body) as Map<String, dynamic>;
      return d['detail']?.toString() ?? d['error']?.toString() ?? body;
    } catch (_) {
      return body.length > 120 ? '${body.substring(0, 120)}…' : body;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _messages.isNotEmpty
          ? AppBar(
              backgroundColor: _red,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: const Text('Vehicle Assistant',
                  style: TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Clear chat',
                  onPressed: () {
                    // Clear server-side session memory
                    if (_sessionId != null) {
                      http.delete(Uri.parse('$_kAiBaseUrl/session/$_sessionId'))
                          .catchError((_) {});
                      _sessionId = null;
                    }
                    setState(() {
                      _messages.clear();
                      _history.clear();
                      _rateLimited = false;
                      _resetIn = '';
                    });
                  },
                ),
              ],
            )
          : null,
      body: Column(children: [
        // Offline banner
        if (!_backendOnline && _dataLoaded)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFFBEB),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: Color(0xFF975A16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI service offline — start the backend on port 8002',
                  style: TextStyle(fontSize: 11, color: Color(0xFF975A16)),
                ),
              ),
              GestureDetector(
                onTap: _checkBackend,
                child: const Text('Retry',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF975A16))),
              ),
            ]),
          ),

        // Rate-limit banner
        if (_rateLimited)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFFBEB),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Text('⚠️', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF975A16)),
                    children: [
                      const TextSpan(
                        text: 'Daily AI limit reached. ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Resets in $_resetIn. '
                            'Chat is disabled until then.',
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),

        // Chat area
        Expanded(
          child: !_dataLoaded
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: Color(0xFFE8001C)),
                    SizedBox(height: 12),
                    Text('Loading your profile…',
                        style: TextStyle(color: Color(0xFF718096), fontSize: 13)),
                  ]))
              : _messages.isEmpty
                  ? _buildWelcome()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_loading && i == _messages.length) {
                          return _buildTyping();
                        }
                        return _buildBubble(_messages[i]);
                      },
                    ),
        ),

        // Quick chips (only on empty chat)
        if (_messages.isEmpty && _dataLoaded)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _chip('🚗 My fleet',        'List all my vehicles'),
              _chip('📊 Summary',         'Give me a fleet summary'),
              _chip('🔧 Maintenance',     'Which vehicles are under maintenance?'),
              _chip('⚠️ Overdue',        'Which vehicles have PMS overdue?'),
              _chip('📅 Due soon',        'Which vehicles have PMS due soon?'),
              _chip('📋 History',         'Show my service history'),
              _chip('🗓️ Bookings',       'Show my bookings'),
              _chip('💰 Service prices',  'What services do you offer and their prices?'),
              _chip('🔍 Cost estimate',   'How much would a change oil and brake cleaning cost?'),
            ]),
          ),

        // Input bar
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
                enabled: !_loading,
                decoration: InputDecoration(
                  hintText: 'Ask about your vehicles…',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFF718096)),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loading ? null : _send,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _loading ? Colors.grey : _red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Welcome ─────────────────────────────────────────────────────────────────

  Widget _buildWelcome() {
    final sub = _customerName.isEmpty
        ? 'Ask me anything about your vehicles — PMS status, history, costs, and more.'
        : _vehicleCount > 0
            ? 'Hi ${_customerName.split(' ').first}! You have $_vehicleCount registered '
              'vehicle${_vehicleCount != 1 ? 's' : ''}. Ask me anything about them.'
            : 'Hi ${_customerName.split(' ').first}! No vehicles are registered under your account yet.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: _blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.smart_toy_outlined, color: _blue, size: 32),
        ),
        const SizedBox(height: 14),
        const Text('Vehicle Assistant',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: Color(0xFF1a202c))),
        const SizedBox(height: 6),
        Text(sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF718096), height: 1.5)),
      ]),
    );
  }

  // ── Typing indicator ─────────────────────────────────────────────────────────

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFE8001C)),
          ),
          const SizedBox(width: 10),
          Text('Thinking…',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  // ── Chat bubble ──────────────────────────────────────────────────────────────

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.role == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: _red.withOpacity(0.25), blurRadius: 6)
            ],
          ),
          child: Text(msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  height: 1.5)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _blue,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(children: [
              Text('🤖', style: TextStyle(fontSize: 13)),
              SizedBox(width: 8),
              Text('Vehicle Assistant',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              msg.text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1a202c), height: 1.6),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Chip ─────────────────────────────────────────────────────────────────────

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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF4a5568),
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _Msg {
  final String role;
  final String text;
  _Msg({required this.role, required this.text});
}
