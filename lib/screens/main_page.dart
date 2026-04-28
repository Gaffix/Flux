import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/mini_player_bar.dart';
import 'package:provider/provider.dart';
import '../providers/flux_provider.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FLUX', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      // MiniPlayer agora é injetado automaticamente pelo Provider
      bottomSheet: const MiniPlayerBar(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_outlined),
            activeIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: FluxApp.accentColor,
        unselectedItemColor: FluxApp.secondaryTextColor,
        backgroundColor: const Color(0xFF181818),
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
    void _showSettingsDialog(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context, listen: false);
    final controller = TextEditingController(text: provider.baseUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configurar Servidor"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "https://seu-ngrok.ngrok-free.app"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              provider.setBaseUrl(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }
}