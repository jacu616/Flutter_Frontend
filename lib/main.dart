import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // <--- 1. Add Firebase Import
import 'package:shared_preferences/shared_preferences.dart';
import 'routes.dart';
import 'theme/app_theme.dart';
// import 'firebase_options.dart'; // <--- Uncomment this if you generated this file using 'flutterfire configure'

Future<void> main() async {
  // 1. Initialize binding (Required for both Firebase and SharedPreferences)
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // 2. Initialize Firebase (Fixes the [core/no-app] crash)
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // <--- Add this argument if you are using firebase_options.dart
  );

  // 3. Check for the token (Your existing logic)
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  
  // 4. Decide the starting page
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