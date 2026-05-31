import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum HelpSupportRole { customer, staff, admin }

class HelpSupportScreen extends StatefulWidget {
  final HelpSupportRole role;
  const HelpSupportScreen({super.key, this.role = HelpSupportRole.customer});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const _red  = Color(0xFFE8001C);
  static const _blue = Color(0xFF003087);

  int? _expandedIndex;

  List<Map<String, String>> get _faqs {
    switch (widget.role) {
      case HelpSupportRole.admin:
        return const [
          {
            'q': 'How do I add a new vehicle?',
            'a': 'Go to the Vehicles tab in the bottom navigation, then tap the red + button at the bottom right. Fill in the plate number, description, vehicle type, owner, odometer, last service date, and service frequency, then save.',
          },
          {
            'q': 'How do I edit or delete a vehicle?',
            'a': 'In the Vehicles tab, tap the three-dot menu on any vehicle card and select Edit or Delete. You can update all vehicle details including odometer and service schedule.',
          },
          {
            'q': 'How does vehicle status get computed?',
            'a': 'Status is automatically calculated based on the last service date and service frequency. It will show Active, PMS Due Soon, Overdue, or Under Maintenance depending on how close or past the next due date is.',
          },
          {
            'q': 'How do I use the QR/barcode scanner?',
            'a': 'Tap the red scanner button at the center of the bottom navigation bar. Point the camera at an item barcode to view its stock details and perform Receive Stock or Add Stock actions.',
          },
          {
            'q': 'How do I manage inventory?',
            'a': 'Go to the Inventory tab. It has three sections: Item Master (manage items), Transactions (view stock movements), and Stock (current stock levels).',
          },
          {
            'q': 'How do I change my password?',
            'a': 'Tap your profile avatar at the top right, then go to Change Password. Enter your current password, then your new password (minimum 6 characters), and confirm it.',
          },
        ];
      case HelpSupportRole.staff:
        return const [
          {
            'q': 'How do I view vehicles due for service?',
            'a': 'The dashboard shows stat cards for vehicles that are Overdue or Due Soon. You can also browse the Vehicles tab and filter by status to see which ones need attention.',
          },
          {
            'q': 'How do I update a vehicle\'s service record?',
            'a': 'Tap on a vehicle card to open its details, then use the edit option to update the last service date, odometer, and service frequency. The status will be recalculated automatically.',
          },
          {
            'q': 'How do I use the barcode scanner?',
            'a': 'Tap the red scanner button at the center of the bottom navigation. Scan an item barcode to view its stock info and perform stock operations like Receive Stock or Add Stock.',
          },
          {
            'q': 'How do I change my profile photo?',
            'a': 'Tap your profile avatar at the top right of the screen. On the Profile page, tap your avatar photo to open the gallery and select a new image.',
          },
          {
            'q': 'How do I change my password?',
            'a': 'Go to your Profile page and tap Change Password. Enter your current password, then your new password (minimum 6 characters), and confirm it to save.',
          },
          {
            'q': 'I forgot my password. What should I do?',
            'a': 'On the login screen, tap "Forgot Password". Enter your email address to receive a 6-digit OTP. Enter the OTP to verify, then check your email for the password reset link.',
          },
        ];
      case HelpSupportRole.customer:
        return const [
          {
            'q': 'How do I view my vehicles?',
            'a': 'Your vehicles are shown on the My Vehicles tab (the car icon at the bottom left). Each card shows the plate number, description, odometer, last service date, and current status.',
          },
          {
            'q': 'Why is my vehicle showing "Overdue"?',
            'a': 'Your vehicle\'s next PMS due date has already passed based on the last service date and service frequency recorded in the system. Contact the service center to schedule a maintenance.',
          },
          {
            'q': 'How do I view my service history?',
            'a': 'Tap the PMS History tab (the history icon at the bottom right). Tap any vehicle card to see a full list of completed services including date, mechanic, services rendered, materials used, and total cost.',
          },
          {
            'q': 'What is Smart Reports AI?',
            'a': 'Smart Reports AI is the center button at the bottom of the screen (robot icon). You can ask it about your vehicles, check which ones are overdue or due soon, and get a summary of your service history.',
          },
          {
            'q': 'How do I change my profile photo?',
            'a': 'Tap your profile avatar at the top right of the screen. On the Profile page, tap your avatar photo to open the gallery and select a new image.',
          },
          {
            'q': 'I forgot my password. What should I do?',
            'a': 'On the login screen, tap "Forgot Password". Enter your email to receive a 6-digit OTP. Enter the OTP to verify, then check your email for the password reset link.',
          },
        ];
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Help & Support',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_red, Color(0xFFC41E3A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.support_agent_outlined, color: Colors.white, size: 32),
              SizedBox(height: 10),
              Text('How can we help?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Browse FAQs or reach out to our support team.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 20),

          // FAQs
          _sectionLabel('FREQUENTLY ASKED QUESTIONS'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Column(
              children: List.generate(_faqs.length, (i) {
                final isLast = i == _faqs.length - 1;
                final isOpen = _expandedIndex == i;
                return Column(children: [
                  InkWell(
                    onTap: () => setState(() => _expandedIndex = isOpen ? null : i),
                    borderRadius: isLast && !isOpen
                        ? const BorderRadius.vertical(bottom: Radius.circular(14))
                        : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.help_outline, size: 16, color: _red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_faqs[i]['q']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isOpen ? FontWeight.w700 : FontWeight.w600,
                            color: const Color(0xFF1a202c)))),
                        Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                          size: 20, color: const Color(0xFF718096)),
                      ]),
                    ),
                  ),
                  if (isOpen)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(60, 0, 16, 14),
                      child: Text(_faqs[i]['a']!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF4a5568), height: 1.5)),
                    ),
                  if (!isLast) const Divider(height: 1, indent: 60),
                ]);
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Contact
          _sectionLabel('CONTACT US'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Column(children: [
              _contactTile(
                icon: Icons.phone_outlined,
                color: Colors.green,
                label: 'Call Us',
                value: '+63 912 345 6789',
                onTap: () => _launch('tel:+639123456789'),
              ),
              const Divider(height: 1, indent: 66),
              _contactTile(
                icon: Icons.email_outlined,
                color: _blue,
                label: 'Email Support',
                value: 'support@janoblecaltex.com',
                onTap: () => _launch('mailto:support@janoblecaltex.com'),
              ),
              const Divider(height: 1, indent: 66),
              _contactTile(
                icon: Icons.location_on_outlined,
                color: _red,
                label: 'Visit Us',
                value: 'JA Noble Caltex, Philippines',
                onTap: null,
                isLast: true,
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Hours
          _sectionLabel('BUSINESS HOURS'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Column(children: [
              _hoursRow('Monday – Friday', '8:00 AM – 5:00 PM'),
              const SizedBox(height: 8),
              _hoursRow('Saturday', '8:00 AM – 12:00 PM'),
              const SizedBox(height: 8),
              _hoursRow('Sunday', 'Closed'),
            ]),
          ),
          const SizedBox(height: 24),

          const Center(
            child: Text('v1.0.0 • JA Noble Enterprise',
              style: TextStyle(fontSize: 11, color: Color(0xFFa0aec0))),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      color: Color(0xFF718096), letterSpacing: 0.8));

  Widget _contactTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback? onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(14))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a202c))),
          ])),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF718096)),
        ]),
      ),
    );
  }

  Widget _hoursRow(String day, String hours) {
    final isClosed = hours == 'Closed';
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(day, style: const TextStyle(fontSize: 13, color: Color(0xFF4a5568))),
      Text(hours, style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isClosed ? Colors.red : const Color(0xFF1a202c))),
    ]);
  }
}
