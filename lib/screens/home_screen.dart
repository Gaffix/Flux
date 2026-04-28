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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flux',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: accentColor,
      ),
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
