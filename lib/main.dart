import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes.dart';
import 'theme/app_theme.dart';
import 'home/profile/other_profile.dart';
import 'home/tabs/groups/group_details.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:     'https://tqmrytzypqsuxjwdrihh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
             '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxbXJ5dHp5cHFzdXhqd2RyaWhoIiwi'
             'cm9sZSI6ImFub24iLCJpYXQiOjE3NzI5Mzk0MjIsImV4cCI6MjA4ODUxNTQyMn0'
             '.SXDr2pA7Bt1fPy9Tg14nhCF0oGz9hQJe1G4_8nA-5tU',
  );

  final prefs         = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  final String initialRoute = token != null ? AppRoutes.home : AppRoutes.login;

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
      routes:       AppRoutes.routes,

      onGenerateRoute: (settings) {
        // ── Other user profile ───────────────────────────────────────────
        if (settings.name == AppRoutes.otherProfile) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => OtherUserProfilePage(
              userId:   args['user_id']   as int,
              userName: args['user_name'] as String,
            ),
          );
        }

        // ── Group details ────────────────────────────────────────────────
        if (settings.name == AppRoutes.groupDetails) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => GroupDetailsPage(
              groupId:   args['group_id']   as int,
              groupName: args['group_name'] as String,
              adminId:   args['admin_id']   as int,
            ),
          );
        }

        return null;
      },
    );
  }
}