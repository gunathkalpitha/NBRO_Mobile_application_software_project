import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth_callback_screen.dart';
import 'presentation/screens/forgot_password_screen.dart';
import 'presentation/screens/reset_password_screen.dart';
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
      debug: false,
    );
    debugPrint('[Main] Supabase initialized successfully');
  } catch (e) {
    debugPrint('[Main] Supabase init error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InspectionBloc>(
          create: (context) => InspectionBloc(),
        ),
      ],
      child: MaterialApp(
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