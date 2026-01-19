import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Splash Screen - Initial loading screen with NBRO branding
class SplashScreen extends StatefulWidget {
  final VoidCallback onInitialization;

  const SplashScreen({
    required this.onInitialization,
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _textAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  void _initializeApp() async {
    // Simulate initialization tasks
    // - Initialize Supabase
    // - Setup local database
    // - Check authentication status
    // - Setup biometric security

    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      widget.onInitialization();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NBROColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon Animation
            ScaleTransition(
              scale: _logoAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: NBROColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'NBRO',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // App Title Animation
            FadeTransition(
              opacity: _textAnimation,
              child: Column(
                children: [
                  Text(
                    'Field Surveyor',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: NBROColors.white,
                          fontSize: 32,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Structural Defect Assessment',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: NBROColors.light,
                          fontSize: 16,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Loading indicator at bottom
      bottomCenter: Positioned(
        bottom: 60,
        child: FadeTransition(
          opacity: _textAnimation,
          child: Column(
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.white),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NBROColors.light,
                    ),
              ),
            ],
          ),
        ),
      ) as Widget,
    );
  }
}
