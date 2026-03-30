import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/login_screen.dart';
import 'main_app_scaffold.dart';
import '../provider/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Artificial delay to show branding
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Wait for auth to finish loading from prefs if it's still loading
    while (auth.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      if (auth.isAuthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainAppScaffold()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Uses the dark theme aesthetic from the web's pulse-hero
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x4D000000)],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ENTERPRISE PLATFORM',
                        style: TextStyle(
                          color: Color(0xFF91D1D3),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4.0, // approx 0.25em tracking
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Task\nManagement\nOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF91D1D3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 6,
                            width: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 6,
                            width: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
