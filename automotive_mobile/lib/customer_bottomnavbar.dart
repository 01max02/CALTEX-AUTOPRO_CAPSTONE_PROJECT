import 'package:flutter/material.dart';

/// Reusable bottom navigation bar for the Customer Dashboard.
/// Indices:
///   0 → Home (My Vehicles)
///   1 → My Bookings
///   2 → Smart AI  (center raised FAB)
///   3 → PMS History
///   4 → Profile
class CustomerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _red  = Color(0xFFE8001C);
  static const _grey = Color(0xFF718096);

  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
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
              // ── 2 left tabs | placeholder | 2 right tabs ──
              Row(children: [
                _tab(index: 0, icon: Icons.home_outlined,      label: 'Home'),
                _tab(index: 1, icon: Icons.list_alt_outlined,  label: 'Bookings'),
                const Expanded(child: SizedBox()),              // space for center FAB
                _tab(index: 3, icon: Icons.history,            label: 'PMS History'),
                _tab(index: 4, icon: Icons.person_outline,     label: 'Profile'),
              ]),

              // ── Center raised Smart AI FAB ──
              Positioned(
                top: -20, left: 0, right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => onTap(2),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: currentIndex == 2
                            ? const Color(0xFFc0001a)
                            : _red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                            color: _red.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4))],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.smart_toy, color: Colors.white, size: 20),
                          Text('Smart AI',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? _red : _grey),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active ? _red : _grey,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
