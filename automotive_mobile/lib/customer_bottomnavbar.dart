import 'package:flutter/material.dart';
import 'customer_smart_ai.dart';

/// Reusable bottom navigation bar for the Customer Dashboard.
/// Indices:
///   0 → My Vehicles
///   1 → Smart Reports AI (navigates to CustomerSmartAI screen)
///   2 → PMS Log
class CustomerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final IconData vehiclesIcon;

  static const _red   = Color(0xFFE8001C);
  static const _grey  = Color(0xFF718096);

  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.vehiclesIcon = Icons.directions_car_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Color(0x18000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Left + placeholder + Right ──
              Row(children: [
                _tab(index: 0, icon: vehiclesIcon, label: 'My Vehicles'),
                const Expanded(child: SizedBox()), // center placeholder
                _tab(index: 2, icon: Icons.history,   label: 'PMS History'),
              ]),

              // ── Center raised Smart Reports button ──
              Positioned(
                top: -20, left: 0, right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => onTap(1),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                          color: _red.withOpacity(0.4),
                          blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.smart_toy, color: Colors.white, size: 20),
                          Text('AI', style: TextStyle(
                            color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab({required int index, required IconData icon, required String label}) {
    final active = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22, color: active ? _red : _grey),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 10,
            color: active ? _red : _grey,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}
