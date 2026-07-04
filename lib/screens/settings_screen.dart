import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  late String _selectedQuality;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FluxProvider>(context, listen: false);
    _urlController = TextEditingController(text: provider.baseUrl);
    _selectedQuality = provider.audioQuality;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final provider = Provider.of<FluxProvider>(context, listen: false);
    provider.setBaseUrl(_urlController.text.trim());
    provider.setAudioQuality(_selectedQuality);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas!')),
    );
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userEmail = user?.email ?? 'Usuário não logado';

    return Scaffold(
      backgroundColor: FluxApp.backgroundColor,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: FluxApp.surfaceColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // SEÇÃO: CONTA
          const Text(
            'CONTA',
            style: TextStyle(
              color: FluxApp.accentColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: FluxApp.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: FluxApp.surfaceColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(userEmail, style: const TextStyle(color: Colors.white)),
                  subtitle: const Text('Plano Free', style: TextStyle(color: FluxApp.secondaryTextColor)),
                ),
                const Divider(color: FluxApp.surfaceColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined, color: Colors.white),
                  title: const Text('Amigos', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: FluxApp.secondaryTextColor),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Em breve: Adicione seus amigos!')),
                    );
                  },
                ),
                const Divider(color: FluxApp.surfaceColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Sair da Conta', style: TextStyle(color: Colors.redAccent)),
                  onTap: _signOut,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // SEÇÃO: TÉCNICO
          const Text(
            'TÉCNICO / SERVIDOR',
            style: TextStyle(
              color: FluxApp.accentColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FluxApp.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Servidor Ngrok', style: TextStyle(color: FluxApp.secondaryTextColor, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'https://xxx.ngrok.app',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: FluxApp.primaryTextColor),
                  onChanged: (_) => _saveSettings(), // Autosave
                ),
                const SizedBox(height: 20),
                const Text('Qualidade de Áudio', style: TextStyle(color: FluxApp.secondaryTextColor, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedQuality,
                  dropdownColor: FluxApp.surfaceColor,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Baixa (Economia)')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal (Padrão)')),
                    DropdownMenuItem(value: 'high', child: Text('Alta (Melhor áudio)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedQuality = val);
                      _saveSettings(); // Autosave
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
