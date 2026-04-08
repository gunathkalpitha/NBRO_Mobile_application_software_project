import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordReset = false;

  Future<void> _handlePasswordUpdate() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('[ResetPasswordScreen] Updating password');
      
      // Update the user's password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      debugPrint('[ResetPasswordScreen] Password updated successfully');
      
      setState(() {
        _passwordReset = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: NBROColors.success,
          ),
        );
        
        // Navigate to login after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        });
      }
    } on AuthException catch (e) {
      debugPrint('[ResetPasswordScreen] Password update error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ResetPasswordScreen] Password update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating password: $e'),
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
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
                              Icons.vpn_key,
                              size: 40,
                              color: NBROColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Create New Password',
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
                              'Your new password must be different from previously used passwords',
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
                        child: _passwordReset
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
          'Set New Password',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NBROColors.black,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Must be at least 6 characters',
          style: TextStyle(
            fontSize: 14,
            color: NBROColors.grey,
          ),
        ),
        const SizedBox(height: 32),

        // New Password Field
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            hintText: 'New Password',
            hintStyle: const TextStyle(color: NBROColors.grey),
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscureNewPassword = !_obscureNewPassword);
              },
            ),
            enabled: !_isLoading,
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password Field
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            hintText: 'Confirm New Password',
            hintStyle: const TextStyle(color: NBROColors.grey),
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
            enabled: !_isLoading,
          ),
        ),
        const SizedBox(height: 32),

        // Update Password Button
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePasswordUpdate,
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
              : const Text('Update Password'),
        ),
        const SizedBox(height: 24),

        // Password Requirements
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NBROColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Requirements:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: NBROColors.grey,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: NBROColors.grey),
                  SizedBox(width: 8),
                  Text(
                    'At least 6 characters',
                    style: TextStyle(fontSize: 12, color: NBROColors.grey),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: NBROColors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Both passwords must match',
                    style: TextStyle(fontSize: 12, color: NBROColors.grey),
                  ),
                ],
              ),
            ],
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
          Icons.check_circle_outline,
          size: 80,
          color: NBROColors.success,
        ),
        const SizedBox(height: 24),
        const Text(
          'Password Updated!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: NBROColors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Your password has been successfully updated. You can now log in with your new password.',
          style: TextStyle(
            fontSize: 14,
            color: NBROColors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const Text(
          'Redirecting to login...',
          style: TextStyle(
            fontSize: 13,
            color: NBROColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
