import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localAuth = LocalAuthentication();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      setState(() {
        _biometricAvailable = canCheckBiometrics && isDeviceSupported;
      });
      
      if (_biometricAvailable) {
        debugPrint('[LoginScreen] Biometric authentication available');
      }
    } catch (e) {
      debugPrint('[LoginScreen] Error checking biometrics: $e');
    }
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access NBRO Field Surveyor',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (isAuthenticated && mounted) {
        debugPrint('[LoginScreen] Biometric authentication successful');
        _navigateToDashboard();
      }
    } catch (e) {
      debugPrint('[LoginScreen] Biometric authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric authentication failed: $e')),
        );
      }
    }
  }

  Future<void> _handleEmailPasswordLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Implement Supabase authentication
      debugPrint('[LoginScreen] Attempting login with email: ${_emailController.text}');
      
      // Instant login (TODO: replace with actual Supabase auth)
      if (mounted) {
        debugPrint('[LoginScreen] Login successful');
        _navigateToDashboard();
      }
    } catch (e) {
      debugPrint('[LoginScreen] Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
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
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(top: 60, bottom: 40),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: NBROColors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          size: 40,
                          color: NBROColors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Secure Access',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: NBROColors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'NBRO Field Surveyor',
                        style: TextStyle(
                          fontSize: 14,
                          color: NBROColors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),

                // Login Form
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: NBROColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to continue',
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
                            hintText: 'Email Address',
                            hintStyle: const TextStyle(color: NBROColors.grey),
                            prefixIcon: const Icon(Icons.email_outlined),
                            enabled: !_isLoading,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: NBROColors.grey),
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            enabled: !_isLoading,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleEmailPasswordLogin,
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
                              : const Text('Sign In'),
                        ),
                        const SizedBox(height: 16),

                        // Biometric Login
                        if (_biometricAvailable)
                          Column(
                            children: [
                              const Divider(
                                color: NBROColors.light,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _authenticateWithBiometric,
                                icon: const Icon(Icons.fingerprint),
                                label: const Text('Use Biometric Login'),
                              ),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Forgot Password Link
                        Center(
                          child: TextButton(
                            onPressed: () {
                              // TODO: Implement forgot password
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password recovery coming soon',
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: NBROColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
