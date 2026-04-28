import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/flux_provider.dart';
import 'screens/main_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FluxProvider(),
      child: const FluxApp(),
    ),
  );
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key});

  static const Color backgroundColor = Color(0xFF121212);
  static const Color cardColor = Color(0xFF242424);
  static const Color accentColor = Color(0xFF14B8A6);
  static const Color darkAccentColor = Color(0xFF0F766E);
  static const Color primaryTextColor = Colors.white;
  static const Color secondaryTextColor = Color(0xFFA3A3A3);
  static const Color progressTrackColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flux',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: accentColor,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
          bodyMedium: TextStyle(fontSize: 14, color: secondaryTextColor),
        ),
        iconTheme: const IconThemeData(color: secondaryTextColor),
      ),
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}