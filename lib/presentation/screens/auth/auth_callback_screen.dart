import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/services/first_login_guide_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/presentation/screens/auth/first_login_guide_screen.dart';
import 'package:nbro_mobile_application/presentation/screens/password/reset_password_screen.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  late String _statusMessage = 'Processing your invitation...';
  late bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    try {
      final incomingUri = _getIncomingAuthUri();
      if (incomingUri != null) {
        final type = (incomingUri.queryParameters['type'] ?? '').toLowerCase();
        if (type == 'recovery') {
          await _handlePasswordRecovery(incomingUri);
          return;
        }
      }

      // Supabase automatically handles the OAuth/invitation callback
      // Check if we have a valid session
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        setState(() {
          _statusMessage = 'Invitation accepted! Setting up your account...';
          _isSuccess = true;
        });

        // Wait a moment then navigate to home
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          await _navigateToPostLoginDestination();
        }
      } else {
        // No session yet, try to recover from the callback
        await _tryRecoverSession();
      }
    } catch (e) {
      debugPrint('[AuthCallback] Error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: ${e.toString()}';
          _isSuccess = false;
        });
      }
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

  Future<void> _handlePasswordRecovery(Uri uri) async {
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
        debugPrint('[AuthCallback] Recovery code exchange failed: $e');
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ResetPasswordScreen(),
      ),
    );
  }

  Future<void> _tryRecoverSession() async {
    try {
      // The OAuth callback URL parameters are handled by Supabase SDK
      // If there's a valid session after auth redirect, it should be set
      await Future.delayed(const Duration(milliseconds: 500));

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        setState(() {
          _statusMessage = 'Welcome! Redirecting...';
          _isSuccess = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          await _navigateToPostLoginDestination();
        }
      } else if (mounted) {
        setState(() {
          _statusMessage =
              'Session could not be established. Please try again or contact support.';
          _isSuccess = false;
        });
      }
    } catch (e) {
      debugPrint('[AuthCallback] Recovery error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error recovering session: $e';
          _isSuccess = false;
        });
      }
    }
  }

  Future<void> _navigateToPostLoginDestination() async {
    final shouldShowGuide = await FirstLoginGuideService.shouldShowForCurrentUser();
    if (!mounted) {
      return;
    }

    if (shouldShowGuide) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const FirstLoginGuideScreen(),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NBROColors.light,
      appBar: AppBar(
        title: const Text('Processing Invitation'),
        backgroundColor: NBROColors.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSuccess)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NBROColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: NBROColors.success,
                  size: 64,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NBROColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(NBROColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: NBROColors.darkGrey,
              ),
            ),
            if (!_isSuccess)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NBROColors.primary,
                  ),
                  child: const Text('Return to Login'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
