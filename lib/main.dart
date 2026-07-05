import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campuslink/core/theme/app_theme.dart';
import 'package:campuslink/core/router/app_router.dart';
  
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CampusLinkApp()));
}

class CampusLinkApp extends StatelessWidget {
  const CampusLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CampusLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light, // user can change in settings later
      routerConfig: appRouter,
    );
  }
}