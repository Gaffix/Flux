import 'package:flutter/material.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 80,
            color: FluxApp.accentColor.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          const Text(
            "FLUX",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: FluxApp.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Busque músicas ou importe uma playlist para começar.",
            textAlign: TextAlign.center,
            style: TextStyle(color: FluxApp.secondaryTextColor),
          ),
        ],
      ),
    );
  }
}