import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/services/session_security_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final incomingUri = _getIncomingAuthUri();
    if (incomingUri != null) {
      final type = (incomingUri.queryParameters['type'] ?? '').toLowerCase();
      if (type == 'recovery') {
        await _handlePasswordRecoveryLink(incomingUri);
        return;
      }

      if (type == 'invite') {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/auth-callback');
        }
        return;
      }
    }

    // Listen for auth state changes (including password recovery)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      
      debugPrint('[SplashScreen] Auth state change: $event');
      
      if (event == AuthChangeEvent.passwordRecovery) {
        // User clicked the password reset link from email
        debugPrint('[SplashScreen] Password recovery detected, navigating to reset screen');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/reset-password');
        }
      }
    });

    // Keep splash visible briefly for UX continuity.
    await Future.delayed(const Duration(seconds: 2));

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    final withinPeriod = await SessionSecurityService.isSessionWithinAllowedPeriod();
    if (!withinPeriod) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    final needsAppLock = await SessionSecurityService.shouldRequireAppLockOnLaunch();
    if (needsAppLock) {
      final unlocked = await SessionSecurityService.authenticateForUnlock();
      if (!unlocked) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Uri? _getIncomingAuthUri() {
    final routeName = WidgetsBinding.instance.platformDispatcher.defaultRouteName;

    if (routeName.isNotEmpty && routeName != '/') {
      final routeUri = Uri.tryParse(routeName);
      if (routeUri != null &&
          (routeUri.path != '/' ||
              routeUri.queryParameters.isNotEmpty ||
              routeUri.fragment.isNotEmpty)) {
        return routeUri;
      }
    }

    final baseUri = Uri.base;
    if (baseUri.queryParameters.isNotEmpty || baseUri.fragment.isNotEmpty) {
      return baseUri;
    }

    return null;
  }

  Future<void> _handlePasswordRecoveryLink(Uri uri) async {
    final hasRecoveryError =
        (uri.queryParameters['error'] ?? '').isNotEmpty ||
        (uri.queryParameters['error_code'] ?? '').isNotEmpty;

    if (hasRecoveryError) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed('/forgot-password');
      return;
    }

    final code = uri.queryParameters['code'];

    if (code != null && code.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      } catch (e) {
        debugPrint('[SplashScreen] Code exchange failed: $e');
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed('/reset-password');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              NBROColors.primary,
              NBROColors.primaryDark,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: NBROColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 60,
                  color: NBROColors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // App Title
              const Text(
                'NBRO Field Surveyor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: NBROColors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              const Text(
                'Structural Defect Assessment Tool',
                style: TextStyle(
                  fontSize: 14,
                  color: NBROColors.white,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 80),
              
              // Loading Indicator
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    NBROColors.accent,
                  ),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
