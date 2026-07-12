import 'package:flutter/material.dart';
import 'theme/lumina_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LuminaApp());
}

class LuminaApp extends StatelessWidget {
  const LuminaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home',
      debugShowCheckedModeBanner: false,
      theme: LuminaTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
