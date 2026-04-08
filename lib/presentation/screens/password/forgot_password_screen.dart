import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      
      debugPrint('[ForgotPasswordScreen] Requesting password reset for: $email');
      
      // Request password reset from Supabase
      // Uses GitHub hosted page for email compatibility, then redirects to app
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://gunathkalpitha.github.io/nbro-auth-redirect/',
      );
      
      debugPrint('[ForgotPasswordScreen] Password reset email sent');
      
      setState(() {
        _emailSent = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent! Check your email.'),
            backgroundColor: NBROColors.success,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on AuthException catch (e) {
      debugPrint('[ForgotPasswordScreen] Password reset error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ForgotPasswordScreen] Password reset error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reset email: $e'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 40),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: NBROColors.white,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.lock_reset,
                              size: 40,
                              color: NBROColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: NBROColors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Enter your email address and we\'ll send you a link to reset your password',
                              style: TextStyle(
                                fontSize: 14,
                                color: NBROColors.white,
                                fontWeight: FontWeight.w300,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form Container
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: NBROColors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        padding: const EdgeInsets.all(32),
                        child: _emailSent
                            ? _buildSuccessView()
                            : _buildFormView(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NBROColors.black,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'We\'ll send you reset instructions',
          style: TextStyle(
            fontSize: 14,
            color: NBROColors.grey,
          ),
        ),
        const SizedBox(height: 32),

        // Email Field
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: const TextStyle(color: NBROColors.grey),
            prefixIcon: const Icon(Icons.email_outlined),
            enabled: !_isLoading,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),

        // Send Reset Link Button
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePasswordReset,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      NBROColors.white,
                    ),
                  ),
                )
              : const Text('Send Reset Link'),
        ),
        const SizedBox(height: 24),

        // Back to Login Button
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Login'),
            style: TextButton.styleFrom(
              foregroundColor: NBROColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: NBROColors.success,
        ),
        const SizedBox(height: 24),
        const Text(
          'Check Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: NBROColors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent a password reset link to:\n${_emailController.text}',
          style: const TextStyle(
            fontSize: 14,
            color: NBROColors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NBROColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.info_outline,
                color: NBROColors.primary,
                size: 24,
              ),
              SizedBox(height: 8),
              Text(
                'Click the link in the email to reset your password. The link will expire in 1 hour.',
                style: TextStyle(
                  fontSize: 13,
                  color: NBROColors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _emailSent = false;
              _emailController.clear();
            });
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Send Again'),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Login'),
            style: TextButton.styleFrom(
              foregroundColor: NBROColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
