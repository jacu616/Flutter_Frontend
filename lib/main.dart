import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url:     'https://tqmrytzypqsuxjwdrihh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
             '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxbXJ5dHp5cHFzdXhqd2RyaWhoIiwi'
             'cm9sZSI6ImFub24iLCJpYXQiOjE3NzI5Mzk0MjIsImV4cCI6MjA4ODUxNTQyMn0'
             '.SXDr2pA7Bt1fPy9Tg14nhCF0oGz9hQJe1G4_8nA-5tU',
  );

  // Check for existing DRF token
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');

  final String initialRoute = (token != null) ? AppRoutes.home : AppRoutes.login;

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SeeMe',
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      routes: AppRoutes.routes,
    );
  }
}