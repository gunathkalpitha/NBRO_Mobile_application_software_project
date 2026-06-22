import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/services/first_login_guide_service.dart';
import 'package:nbro_mobile_application/core/services/session_security_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/presentation/screens/auth/first_login_guide_screen.dart';

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
    if (kIsWeb) {
      debugPrint('[LoginScreen] Biometric authentication not supported on web');
      return;
    }

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
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login is not available on web')),
        );
      }
      return;
    }

    if (Supabase.instance.client.auth.currentSession == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login once with email/password before using biometric unlock.'),
          ),
        );
      }
      return;
    }

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
        _navigateToPostLoginDestination();
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
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      debugPrint('[LoginScreen] Attempting login with email: $email');
      
      // Authenticate with Supabase
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        debugPrint('[LoginScreen] Login successful for user: ${response.user!.id}');

        await SessionSecurityService.recordPasswordLogin();
        
        // Check if the account is active
        try {
          final profileResponse = await Supabase.instance.client
              .from('profile')
              .select('is_active')
              .eq('id', response.user!.id)
              .single();
          
          final isActive = profileResponse['is_active'] as bool? ?? true;
          
          if (!isActive) {
            // Account is disabled, sign out immediately
            await Supabase.instance.client.auth.signOut();
            debugPrint('[LoginScreen] Account is disabled - signing out user');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Your account has been disabled. Please contact an administrator.'),
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
          
          if (mounted) {
            _navigateToPostLoginDestination();
          }
        } catch (e) {
          debugPrint('[LoginScreen] Error checking account status: $e');
          // If we can't check, allow login to proceed
          if (mounted) {
            _navigateToPostLoginDestination();
          }
        }
      } else {
        debugPrint('[LoginScreen] Login failed - no user returned');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid email or password')),
          );
        }
      }
    } on AuthException catch (e) {
      debugPrint('[LoginScreen] Authentication error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message}')),
        );
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

  Future<void> _navigateToPostLoginDestination() async {
    final shouldShowGuide = await FirstLoginGuideService.shouldShowForCurrentUser();

    if (!mounted) {
      return;
    }

    if (shouldShowGuide) {
      debugPrint('[LoginScreen] First login detected - opening guide');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const FirstLoginGuideScreen(),
        ),
      );
      return;
    }

    debugPrint('[LoginScreen] Guide already seen - navigating to /home');
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
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.4; // Responsive header height

    return Scaffold(
      backgroundColor: NBROColors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Background Image
            Stack(
              children: [
                // Background Image
                Container(
                  width: double.infinity,
                  height: headerHeight,
                  decoration: const BoxDecoration(
                    color: NBROColors.primary,
                  ),
                  child: Image.asset(
                    'assets/images/login_bg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: NBROColors.primary);
                    },
                  ),
                ),
                // Gradient Overlay for visibility
                Container(
                  height: headerHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        NBROColors.primary.withOpacity(0.4),
                        NBROColors.primaryDark.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
                // Header Content
                SizedBox(
                  height: headerHeight,
                  width: double.infinity,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: NBROColors.white.withOpacity(1),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/icons/nbro_logo_login.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Secure Access',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: NBROColors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'National Building Research Organization',
                            style: TextStyle(
                              fontSize: 13,
                              color: NBROColors.white,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'Field Surveyor',
                            style: TextStyle(
                              fontSize: 11,
                              color: NBROColors.white,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Login Form
            Container(
              transform: Matrix4.translationValues(0, -25, 0),
              decoration: const BoxDecoration(
                color: NBROColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 15,
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
                      prefixIcon: const Icon(Icons.email_outlined, color: NBROColors.primary),
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
                      prefixIcon: const Icon(Icons.lock_outlined, color: NBROColors.primary),
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                NBROColors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Biometric Login
                  if (_biometricAvailable)
                    Column(
                      children: [
                        const Row(
                          children: [
                            Expanded(child: Divider(color: NBROColors.light)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: NBROColors.grey, fontSize: 12)),
                            ),
                            Expanded(child: Divider(color: NBROColors.light)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: _authenticateWithBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Use Biometric Login'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Forgot Password Link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/forgot-password');
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: NBROColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
