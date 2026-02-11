import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/state/inspection_bloc.dart';


const supabaseUrl = 'https://bazelkzuwxcrmapbuzyp.supabase.co';
const supabaseAnonKey = 'sb_publishable_5Bnp_FgN1eleESr03wE6tg_ZqrRqptl';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase in background (non-blocking)
  _initSupabaseAsync();

  runApp(const MyApp());
}

Future<void> _initSupabaseAsync() async {
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: false,
    ).timeout(
      const Duration(seconds: 2),
    );
    debugPrint('[Main] Supabase initialized');
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
