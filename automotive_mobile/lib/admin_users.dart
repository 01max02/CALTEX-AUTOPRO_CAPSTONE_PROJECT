import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

// ── EmailJS config ────────────────────────────────────────────────────────
// Same service as forgot_password.dart — no server needed, works on any network.
const _ejsServiceId  = 'service_i906b4o';
const _ejsPublicKey  = 'DqRrjCkUnf9w2L_sv';
// Template for welcome / credentials email.
// See setup instructions below in _sendWelcomeEmail.
const _ejsWelcomeTemplateId = 'template_ovrow3w';

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  static const _red = Color(0xFFE8001C);
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _roleColor(String role) {
    if (role == 'admin') return _red;
    if (role == 'staff') return const Color(0xFF003087);
    return Colors.green;
  }

  String _roleLabel(String role) =>
      role[0].toUpperCase() + role.substring(1);

  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    final base = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    return '${base}@1'; // ensures uppercase, lowercase, digit, special char
  }

  Future<bool> _sendWelcomeEmail({
    required String toEmail,
    required String toName,
    required String tempPassword,
    required String role,
  }) async {
    // Uses EmailJS — no local server required, works on any network.
    // Variable mapping matches the "Welcome" template in EmailJS dashboard:
    //   To Email field:  {{email}}
    //   Subject:         {{name}}
    //   Body variables:  {{to_name}}, {{to_email}}, {{temp_password}}, {{role}}

    final roleLabel = role[0].toUpperCase() + role.substring(1);
    try {
      final res = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'https://dashboard.emailjs.com',
        },
        body: jsonEncode({
          'service_id':  _ejsServiceId,
          'template_id': _ejsWelcomeTemplateId,
          'user_id':     _ejsPublicKey,
          'template_params': {
            'email':         toEmail,      // → To Email field: {{email}}
            'name':          toName,       // → Subject: {{name}}
            'to_name':       toName,       // → Body greeting: {{to_name}}
            'to_email':      toEmail,      // → Credentials box: {{to_email}}
            'temp_password': tempPassword, // → {{temp_password}}
            'role':          roleLabel,    // → {{role}}
          },
        }),
      );

      debugPrint('EmailJS welcome ${res.statusCode}: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Welcome email error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserModal(),
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
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
                  hintText: 'Search users...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              )
            : const Text('User Management',
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
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final users = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return {
              'uid': d.id,
              'name': data['name'] as String? ?? '—',
              'username': data['username'] as String? ?? '—',
              'email': data['email'] as String? ?? '—',
              'role': data['role'] as String? ?? '—',
              'status': data['status'] as String? ?? 'Active',
            };
          }).toList();

          final filtered = _searchQuery.isEmpty
              ? users
              : users.where((u) =>
                  u['name']!.toLowerCase().contains(_searchQuery) ||
                  u['username']!.toLowerCase().contains(_searchQuery) ||
                  u['role']!.toLowerCase().contains(_searchQuery)).toList();

          final total = users.length;
          final customers = users.where((u) => u['role'] == 'customer').length;
          final staff = users.where((u) => u['role'] == 'staff').length;
          final admins = users.where((u) => u['role'] == 'admin').length;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                _statChip('Total', '$total', Colors.blue),
                const SizedBox(width: 8),
                _statChip('Admin', '$admins', _red),
                const SizedBox(width: 8),
                _statChip('Customer', '$customers', Colors.green),
                const SizedBox(width: 8),
                _statChip('Staff', '$staff', const Color(0xFF003087)),
              ]),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No users found.', style: TextStyle(color: Color(0xFF718096))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _userCard(filtered[i]),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    final icon = label == 'Total'
        ? Icons.people_outline
        : Icons.person_outline;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
        child: Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF718096))),
        ]),
      ),
    );
  }

  Widget _userCard(Map<String, String> u) {
    final rc = _roleColor(u['role']!);
    return GestureDetector(
      onTap: () => _showUserDetails(u),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: rc.withOpacity(0.15),
            child: Text(u['name']![0].toUpperCase(),
              style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('${u['username']}', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
            Text(u['email']!, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_roleLabel(u['role']!), style: TextStyle(fontSize: 10, color: rc, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(u['status']!,
              style: TextStyle(fontSize: 10,
                color: u['status'] == 'Active' ? Colors.green : const Color(0xFF718096),
                fontWeight: FontWeight.w500)),
          ]),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF718096)),
            onSelected: (val) {
              if (val == 'edit') _showAddUserModal(user: u);
              if (val == 'toggle') _confirmDelete(u);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit')])),
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                    u['status']?.toLowerCase() == 'active'
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    size: 16,
                    color: u['status']?.toLowerCase() == 'active' ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    u['status']?.toLowerCase() == 'active' ? 'Deactivate' : 'Activate',
                    style: TextStyle(
                      color: u['status']?.toLowerCase() == 'active' ? Colors.orange : Colors.green,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  void _showUserDetails(Map<String, String> u) {
    final rc = _roleColor(u['role']!);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.55, maxChildSize: 0.8,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(color: rc, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Row(children: [
                CircleAvatar(radius: 26, backgroundColor: Colors.white24,
                  child: Text(u['name']![0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u['name']!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${u['username']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _detailRow('Full Name', u['name']!),
                _detailRow('Username', '${u['username']}'),
                _detailRow('Email', u['email']!),
                _detailRow('Role', _roleLabel(u['role']!)),
                _detailRow('Status', u['status']!),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(context); _showAddUserModal(user: u); },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096), fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a202c)))),
      ]),
    );
  }

  void _showAddUserModal({Map<String, String>? user}) {
    final isEdit = user != null;
    final nameCtrl     = TextEditingController(text: user?['name']     ?? '');
    final usernameCtrl = TextEditingController(text: user?['username'] ?? '');
    final emailCtrl    = TextEditingController(text: user?['email']    ?? '');
    String selectedRole   = isEdit
        ? (user!['role']![0].toUpperCase() + user['role']!.substring(1))
        : 'Staff';
    String selectedStatus = user?['status'] ?? 'Active';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.97,
          builder: (_, ctrl) => SingleChildScrollView(
            controller: ctrl,
            child: Column(children: [
              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: const BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                        isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                        color: Colors.white, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isEdit ? 'Edit User' : 'Add User',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      if (!isEdit)
                        const Text(
                            'Login credentials will be sent to the user\'s email.',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  )),
                  GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, color: Colors.white)),
                ]),
              ),

              // ── Form ──
              Padding(
                padding: EdgeInsets.only(
                    left: 20, right: 20, top: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
                child: Column(children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Username *',
                        border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Role *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14)),
                    items: const [
                      DropdownMenuItem(value: 'Admin',    child: Text('Admin')),
                      DropdownMenuItem(value: 'Staff',    child: Text('Staff')),
                      DropdownMenuItem(value: 'Customer', child: Text('Customer')),
                    ],
                    onChanged: (v) => setModal(() => selectedRole = v!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FFF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(children: [
                        Icon(Icons.email_outlined, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'A temporary password will be auto-generated and sent to the user\'s email.',
                          style: TextStyle(fontSize: 11, color: Colors.green),
                        )),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Buttons ──
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white),
                      onPressed: saving ? null : () async {
                        // Validate
                        if (nameCtrl.text.trim().isEmpty ||
                            usernameCtrl.text.trim().isEmpty ||
                            emailCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Please fill in all required fields.'),
                            backgroundColor: Colors.orange));
                          return;
                        }

                        setModal(() => saving = true);

                        try {
                          if (isEdit) {
                            // ── Edit existing user ──
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user!['uid'])
                                .update({
                              'name':     nameCtrl.text.trim(),
                              'username': usernameCtrl.text.trim(),
                              'email':    emailCtrl.text.trim(),
                              'role':     selectedRole.toLowerCase(),
                              'status':   selectedStatus,
                            });
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Row(children: [
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('User updated successfully!'),
                                ]),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          } else {
                            // ── Add new user ──
                            final tempPass = _generateTempPassword();

                            // Check if user already exists by email
                            final existingSnap = await FirebaseFirestore.instance
                                .collection('users')
                                .where('email', isEqualTo: emailCtrl.text.trim())
                                .limit(1)
                                .get();
                            
                            if (existingSnap.docs.isNotEmpty) {
                              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('A user with this email already exists.'),
                                  backgroundColor: Colors.orange));
                              setModal(() => saving = false);
                              return;
                            }

                            // Use a secondary Firebase app so the admin
                            // session is NOT replaced by the new user's session
                            FirebaseApp? secondaryApp;
                            try {
                              secondaryApp = await Firebase.initializeApp(
                                name: 'secondary_${DateTime.now().millisecondsSinceEpoch}',
                                options: DefaultFirebaseOptions.currentPlatform,
                              );
                              final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

                              // 1. Create account in secondary app (doesn't touch admin session)
                              final cred = await secondaryAuth.createUserWithEmailAndPassword(
                                email: emailCtrl.text.trim(),
                                password: tempPass,
                              );

                              // 2. Save to Firestore using the new UID
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(cred.user!.uid)
                                  .set({
                                'name':      nameCtrl.text.trim(),
                                'username':  usernameCtrl.text.trim(),
                                'email':     emailCtrl.text.trim(),
                                'role':      selectedRole.toLowerCase(),
                                'status':    selectedStatus,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              // 3. Sign out from secondary app
                              await secondaryAuth.signOut();
                            } finally {
                              // Always delete the secondary app to free resources
                              await secondaryApp?.delete();
                            }

                            // 4. Send welcome email
                            bool sent = false;
                            String emailError = '';
                            try {
                              sent = await _sendWelcomeEmail(
                                toEmail:      emailCtrl.text.trim(),
                                toName:       nameCtrl.text.trim(),
                                tempPassword: tempPass,
                                role:         selectedRole,
                              );
                            } catch (e) {
                              emailError = e.toString();
                              debugPrint('Email send caught: $e');
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              // Always show green success — user was created regardless of email
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(
                                      sent
                                        ? 'User added! Credentials sent to ${emailCtrl.text.trim()}.'
                                        : 'User added! Email failed: ${emailError.isNotEmpty ? emailError.substring(0, emailError.length.clamp(0, 120)) : "unknown error"}')),
                                ]),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                                content: Text(e.code == 'email-already-in-use'
                                    ? 'This email is already registered. Use a different email.'
                                    : e.code == 'invalid-email'
                                        ? 'Invalid email address format.'
                                        : e.code == 'weak-password'
                                            ? 'Password is too weak.'
                                            : e.message ?? 'Firebase error'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red));
                        } finally {
                          if (ctx.mounted) setModal(() => saving = false);
                        }
                      },
                      child: saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(isEdit ? Icons.save_outlined : Icons.send_outlined, size: 16),
                              const SizedBox(width: 6),
                              Text(isEdit ? 'Update' : 'Add & Send'),
                            ]),
                    )),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, String> u) {
    final isActive = (u['status'] ?? '').toLowerCase() == 'active';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(isActive ? Icons.block_outlined : Icons.check_circle_outline,
              color: isActive ? Colors.orange : Colors.green, size: 22),
          const SizedBox(width: 8),
          Text(isActive ? 'Deactivate User' : 'Activate User'),
        ]),
        content: Text(
          isActive
            ? 'Deactivate "${u['name']}"? They will no longer be able to log in.'
            : 'Activate "${u['name']}"? They will be able to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final newStatus = isActive ? 'Inactive' : 'Active';
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(u['uid'])
                    .update({'status': newStatus});

                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    Icon(
                      isActive ? Icons.block_outlined : Icons.check_circle_outline,
                      color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('User ${isActive ? 'deactivated' : 'activated'} successfully.'),
                  ]),
                  backgroundColor: isActive ? Colors.orange : Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}
