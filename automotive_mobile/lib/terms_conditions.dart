import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static const _red = Color(0xFFE8001C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Terms & Conditions',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header('Terms & Conditions'),
          _subtitle('Last Updated: January 1, 2026'),
          const SizedBox(height: 20),

          _section('1. Acceptance of Terms',
              'By downloading, installing, or using the AutoPro mobile application, you agree to be bound by these Terms and Conditions. If you do not agree, do not use the application.'),

          _section('2. Use of the Application',
              'This application is intended for authorized users of JA Noble Enterprise INC only. You agree to:\n\n'
              '• Use the app only for its intended purpose of fleet and inventory management\n'
              '• Keep your login credentials secure and confidential\n'
              '• Not share your account with unauthorized individuals\n'
              '• Not attempt to access accounts or data that you are not authorized to view\n'
              '• Comply with all applicable laws and regulations'),

          _section('3. User Accounts',
              'Account creation is subject to admin approval. JA Noble reserves the right to:\n\n'
              '• Approve or reject account registration requests\n'
              '• Suspend or deactivate accounts that violate these terms\n'
              '• Modify user roles and access permissions at any time'),

          _section('4. Service Bookings',
              'Service booking requests through the application are subject to:\n\n'
              '• Availability of service slots\n'
              '• Admin approval before confirmation\n'
              '• Possible rescheduling by the service team based on operational needs\n'
              '• Cancellation at the discretion of the service team'),

          _section('5. Inventory and Data Accuracy',
              'The application displays inventory levels and maintenance schedules based on data entered by authorized staff. JA Noble does not guarantee the real-time accuracy of all displayed information and recommends verifying critical data directly with service staff.'),

          _section('6. Notifications',
              'By using this application, you consent to receiving push notifications for:\n\n'
              '• PMS due date reminders\n'
              '• Service booking updates and rescheduling notices\n'
              '• Low stock alerts (admin/staff only)\n\n'
              'You may disable notifications at any time through your device settings.'),

          _section('7. Intellectual Property',
              'All content, design, and functionality of this application are the property of JA Noble Enterprise INC. You may not reproduce, distribute, or create derivative works without written permission.'),

          _section('8. Limitation of Liability',
              'JA Noble Enterprise INC shall not be liable for any indirect, incidental, or consequential damages arising from your use of this application, including but not limited to loss of data, service interruptions, or scheduling conflicts.'),

          _section('9. Modifications',
              'We reserve the right to modify these Terms and Conditions at any time. Continued use of the application after any changes constitutes your acceptance of the new terms.'),

          _section('10. Governing Law',
              'These Terms and Conditions are governed by the laws of the Republic of the Philippines. Any disputes shall be resolved through the appropriate courts in the Philippines.'),

          _section('11. Contact',
              'For questions regarding these Terms and Conditions, contact us at:\n\n'
              'JA Noble Enterprise INC\nEmail: janobleenterprisesinc@gmail.com\nPhone: (02) 8-XXX-XXXX'),

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
