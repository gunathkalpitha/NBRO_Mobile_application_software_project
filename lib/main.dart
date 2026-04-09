import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'core/services/session_security_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/officer/home_screen.dart';
import 'presentation/screens/auth/auth_callback_screen.dart';
import 'presentation/screens/password/forgot_password_screen.dart';
import 'presentation/screens/password/reset_password_screen.dart';
import 'presentation/state/inspection_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ CRITICAL FIX: Must AWAIT Supabase init before runApp.
  // Without await, currentSession is null when officers_screen calls the
  // Edge Function, which sends "Bearer " with no token → 401 error.
  await _initSupabase();

  runApp(const MyApp());
}

Future<void> _initSupabase() async {
  try {
    if (supabaseAnonKey.startsWith('sb_secret_') ||
        supabaseAnonKey.startsWith('sb_secret__')) {
      throw StateError(
        'Invalid Supabase client key: use anon/publishable key in Flutter app',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
      debug: false,
    );
    debugPrint('[Main] Supabase initialized successfully');
  } catch (e) {
    debugPrint('[Main] Supabase init error: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isUnlockInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (SessionSecurityService.isBiometricPromptActive) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      SessionSecurityService.markAppBackgrounded();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _enforceAppLockOnResume();
    }
  }

  Future<void> _enforceAppLockOnResume() async {
    if (_isUnlockInProgress) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final needsLock = await SessionSecurityService.shouldRequireAppLock();
    if (!needsLock) return;

    _isUnlockInProgress = true;
    final unlocked = await SessionSecurityService.authenticateForUnlock();
    _isUnlockInProgress = false;

    if (unlocked) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InspectionBloc>(
          create: (context) => InspectionBloc(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'NBRO Field Surveyor',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/auth-callback': (context) => const AuthCallbackScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
        },
      ),
    );
  }
}