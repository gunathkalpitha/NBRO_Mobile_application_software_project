import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/state/inspection_bloc.dart';

const supabaseUrl = 'https://bazelkzuwxcrmapbuzyp.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhemVsa3p1d3hjcm1hcGJ1enlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4MjY0NTYsImV4cCI6MjA4NDQwMjQ1Nn0.bCuiTsDIXKKQaqPRVBcTfrp44APXtCAp8QpovVaBywk';

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
        },
      ),
    );
  }
}