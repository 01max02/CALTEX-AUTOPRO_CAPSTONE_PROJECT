import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart';
import 'staff_dashboard.dart';
import 'customer_dashboard.dart';

/// Shown on first login when admin-created accounts must change their
/// temporary password before accessing the app.
class ChangePasswordScreen extends StatefulWidget {
  final String role;
  const ChangePasswordScreen({super.key, required this.role});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const _red  = Color(0xFFE8001C);
  static const _blue = Color(0xFF003087);

  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _showCurrent = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _loading     = false;

  double _strength     = 0;
  String _strengthText = '';
  Color  _strengthColor = Colors.transparent;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _checkStrength(String val) {
    int score = 0;
    if (val.length >= 6)  score++;
    if (val.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(val) && RegExp(r'[a-z]').hasMatch(val)) score++;
    if (RegExp(r'\d').hasMatch(val))          score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(val)) score++;

    setState(() {
      _strength = val.isEmpty ? 0 : score / 4;
      if (val.isEmpty)   { _strengthText = '';       _strengthColor = Colors.transparent; }
      else if (score <= 1) { _strengthText = 'Weak';   _strengthColor = _red; }
      else if (score == 2) { _strengthText = 'Fair';   _strengthColor = Colors.orange; }
      else if (score == 3) { _strengthText = 'Good';   _strengthColor = Colors.amber; }
      else                 { _strengthText = 'Strong'; _strengthColor = Colors.green; }
    });
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty) { _toast('Enter your current (temporary) password.'); return; }
    if (newPass.isEmpty)  { _toast('Enter a new password.'); return; }
    if (newPass.length < 6) { _toast('Password must be at least 6 characters.'); return; }
    if (newPass != confirm) { _toast('Passwords do not match.'); return; }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: current);

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);

      // Clear the flag in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'mustChangePassword': false});

      if (!mounted) return;
      _toast('Password updated! Redirecting…', success: true);

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      _navigateToDashboard();
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? 'Current password is incorrect.'
          : e.message ?? 'Error updating password.';
      _toast(msg);
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToDashboard() {
    Widget dest;
    switch (widget.role) {
      case 'admin':    dest = const AdminDashboard();    break;
      case 'staff':    dest = const StaffDashboard();    break;
      default:         dest = const CustomerDashboard(); break;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
  }

  void _toast(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // ── Red header with Caltex logo ──
            Stack(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 50),
                color: _red,
                child: Column(children: [
                  // Caltex logo badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/img/LOGO_CALTEX.png',
                          width: 40, height: 40, fit: BoxFit.contain),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Image.asset('assets/img/CALTEX_LETTER.png',
                            height: 22, fit: BoxFit.contain),
                        const SizedBox(height: 2),
                        const Text('AutoPro',
                            style: TextStyle(color: Colors.white70, fontSize: 12,
                                fontWeight: FontWeight.w700, letterSpacing: 3)),
                      ]),
                    ]),
                  ),
                ]),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28)),
                  ),
                ),
              ),
            ]),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Title ──
                const Center(
                  child: Text('Set New Password',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: Color(0xFF1a202c))),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text('You must change your temporary password\nbefore continuing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF718096), height: 1.5)),
                ),
                const SizedBox(height: 20),

                // ── Warning banner ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    border: Border.all(color: const Color(0xFFF6AD55)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Text('🔐', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Action required: This is your first login. Please set a personal password to continue.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF744210), height: 1.5),
                    )),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Form card ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Current password
                    const Text('Current (Temporary) Password',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Color(0xFF4a5568))),
                    const SizedBox(height: 6),
                    _passwordField(
                      controller: _currentCtrl,
                      hint: 'Enter temporary password',
                      visible: _showCurrent,
                      onToggle: () => setState(() => _showCurrent = !_showCurrent),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFe2e8f0)),
                    const SizedBox(height: 16),

                    // New password
                    const Text('New Password',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Color(0xFF4a5568))),
                    const SizedBox(height: 6),
                    _passwordField(
                      controller: _newCtrl,
                      hint: 'Enter new password',
                      visible: _showNew,
                      onToggle: () => setState(() => _showNew = !_showNew),
                      onChanged: _checkStrength,
                    ),
                    if (_newCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _strength.clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFFe2e8f0),
                          valueColor: AlwaysStoppedAnimation(_strengthColor),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_strengthText,
                          style: TextStyle(fontSize: 11, color: _strengthColor,
                              fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 16),

                    // Confirm password
                    const Text('Confirm New Password',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Color(0xFF4a5568))),
                    const SizedBox(height: 6),
                    _passwordField(
                      controller: _confirmCtrl,
                      hint: 'Confirm new password',
                      visible: _showConfirm,
                      onToggle: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                    const SizedBox(height: 8),
                    const Text('Must be at least 6 characters.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Submit button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Update Password',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),

                // ── Tips ──
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFe2e8f0)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Password tips',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFF4a5568))),
                    const SizedBox(height: 8),
                    ...[
                      'At least 6 characters',
                      'Mix uppercase & lowercase letters',
                      'Include numbers and symbols',
                      'Avoid using your name or email',
                    ].asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                              color: _red, shape: BoxShape.circle),
                          child: Center(child: Text('${e.key + 1}',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 10, fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 8),
                        Text(e.value,
                            style: const TextStyle(fontSize: 12,
                                color: Color(0xFF4a5568))),
                      ]),
                    )),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1a202c)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFa0aec0), fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline,
            color: Color(0xFF718096), size: 20),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF718096), size: 20),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFe2e8f0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFe2e8f0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _red, width: 1.5)),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
      ),
    );
  }
}
