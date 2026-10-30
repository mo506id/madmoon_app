import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'screens/reset_password_screen.dart';
import 'dart:async';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
  );

  await NotificationService.initialize();
  await NotificationService.requestPermission();


  runApp(const MadmoonApp());
}


class MadmoonApp extends StatefulWidget {
  const MadmoonApp({super.key});

  @override
  State<MadmoonApp> createState() => _MadmoonAppState();
}

class _MadmoonAppState extends State<MadmoonApp> {
  final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          if (data.event == AuthChangeEvent.passwordRecovery) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => const ResetPasswordScreen(),
              ),
            );
          }
        });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Madmoon App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1465D8),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
