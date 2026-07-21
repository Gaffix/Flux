import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/flux_provider.dart';
import 'services/equalizer_service.dart';
import 'screens/main_page.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.flux.channel.audio',
    androidNotificationChannelName: 'Flux Audio',
    androidNotificationOngoing: true,
  );
  await Supabase.initialize(
    url: 'https://sfnmgxwhkyimblejgtrs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNmbm1neHdoa3lpbWJsZWpndHJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMxMTM1MjcsImV4cCI6MjA5ODY4OTUyN30.bKE7eRCZ32AAym14LKvk2xCWw03EBySz8z8a8YK-TEA',
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EqualizerService()),
        ChangeNotifierProxyProvider<EqualizerService, FluxProvider>(
          create: (context) => FluxProvider()..attachEqualizerService(Provider.of<EqualizerService>(context, listen: false)),
          update: (context, eqService, fluxProvider) => fluxProvider!..attachEqualizerService(eqService),
        ),
      ],
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
  static const Color surfaceColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flux',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: accentColor,
        textTheme: GoogleFonts.interTextTheme(
          const TextTheme(
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
            bodySmall: TextStyle(fontSize: 12, color: secondaryTextColor),
          ),
        ),
        iconTheme: const IconThemeData(color: secondaryTextColor),
        colorScheme: ColorScheme.dark(
          primary: accentColor,
          secondary: accentColor,
          surface: cardColor,
        ),
      ),
      home: Supabase.instance.client.auth.currentUser == null
          ? const AuthScreen()
          : const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
