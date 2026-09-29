import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../screens/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5), // Professional academic blue
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/// Backwards compatibility typedef for default Flutter project templates
typedef MyApp = App;
