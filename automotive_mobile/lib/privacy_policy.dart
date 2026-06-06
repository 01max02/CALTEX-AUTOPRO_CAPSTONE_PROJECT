import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _red = Color(0xFFE8001C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Privacy Policy',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header('Privacy Policy'),
          _subtitle('Effective Date: January 1, 2026'),
          const SizedBox(height: 20),

          _section('1. Introduction',
              'JA Noble Enterprise INC ("we", "our", or "us") is committed to protecting your personal information. This Privacy Policy explains how we collect, use, and safeguard your data when you use the AutoPro fleet management mobile application.'),

          _section('2. Information We Collect',
              'We collect the following types of information:\n\n'
              '• Account Information: Name, email address, and role (admin, staff, or customer)\n'
              '• Vehicle Information: Plate numbers, vehicle descriptions, and maintenance records\n'
              '• Service Booking Data: Preferred dates, times, and selected services\n'
              '• Device Information: Device type and push notification token (OneSignal subscription ID) for sending alerts\n'
              '• Usage Data: App interactions for improving service quality'),

          _section('3. How We Use Your Information',
              'Your information is used to:\n\n'
              '• Manage your fleet vehicles and preventive maintenance schedules\n'
              '• Process and track service bookings\n'
              '• Send push notifications and in-app alerts about PMS due dates, stock levels, and booking updates\n'
              '• Generate inventory reports and decision support insights\n'
              '• Verify your identity and manage account access'),

          _section('4. Data Sharing',
              'We do not sell or rent your personal information to third parties. Your data may be shared with:\n\n'
              '• Firebase (Google): For authentication and database storage\n'
              '• OneSignal: For push notification delivery\n'
              '• Service staff within JA Noble who need access to perform their duties'),

          _section('5. Data Security',
              'We implement industry-standard security measures including Firebase Authentication, Firestore security rules, and encrypted data transmission to protect your information from unauthorized access.'),

          _section('6. Data Retention',
              'We retain your personal data for as long as your account is active or as needed to provide our services. You may request deletion of your account and associated data by contacting us.'),

          _section('7. Your Rights',
              'You have the right to:\n\n'
              '• Access the personal information we hold about you\n'
              '• Request correction of inaccurate data\n'
              '• Request deletion of your account\n'
              '• Opt out of push notifications at any time through your device settings'),

          _section('8. Contact Us',
              'If you have questions about this Privacy Policy, please contact us at:\n\n'
              'JA Noble Enterprise INC\nEmail: support@janoblecaltex.com\nPhone: (02) 8-XXX-XXXX'),

          const SizedBox(height: 32),
          Center(child: Text('© 2026 JA Noble Enterprise INC. All rights reserved.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _header(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1a202c)));
  }

  Widget _subtitle(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF718096)));
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1a202c))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFe2e8f0)),
          ),
          child: Text(body, style: const TextStyle(fontSize: 13, color: Color(0xFF4a5568), height: 1.6)),
        ),
      ]),
    );
  }
}
