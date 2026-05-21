import 'package:flutter/material.dart';
import 'login.dart';
import 'register.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _red = Color(0xFFE8001C);
  static const _blue = Color(0xFF003087);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_red, Color(0xFFB80018)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo + Branding ──
              Image.asset(
                'assets/img/LOGO_CALTEX.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              const Text(
                'JA NOBLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'In partnership with Caltex Philippines',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your trusted automotive\nservice partner.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              // ── Buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 6,
                          shadowColor: Colors.black.withOpacity(0.2),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Create Account button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Footer ──
              Text(
                '© 2026 JA Noble Enterprise INC',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
