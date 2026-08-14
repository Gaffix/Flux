import 'package:flutter/material.dart';
import '../services/listening_history_service.dart';
import 'wrapped_story_screen.dart';

class WrappedLandingScreen extends StatefulWidget {
  const WrappedLandingScreen({Key? key}) : super(key: key);

  @override
  State<WrappedLandingScreen> createState() => _WrappedLandingScreenState();
}

class _WrappedLandingScreenState extends State<WrappedLandingScreen> {
  bool _isLoading = false;

  Future<void> _generateWrapped(BuildContext context, bool isYearly) async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;
      String title;
      String subtitle;

      if (isYearly) {
        start = DateTime(now.year, 1, 1);
        title = "Flux Wrapped ${now.year}";
        subtitle = "Seu ano em música.";
      } else {
        start = DateTime(now.year, now.month, 1);
        title = "Wrapped do Mês";
        subtitle = "Seu mês em música.";
      }

      final stats = await ListeningHistoryService.getWrappedStats(start, end);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (stats == null || stats['total_listens'] == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ainda não há dados suficientes para este período.")),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WrappedStoryScreen(
            stats: stats,
            title: title,
            subtitle: subtitle,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao gerar Wrapped: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flux Wrapped"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade900, Colors.black],
          ),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 64, color: Colors.amber),
                    const SizedBox(height: 24),
                    const Text(
                      "Descubra suas estatísticas",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 48),
                    _buildWrappedOption(
                      context,
                      icon: Icons.calendar_today,
                      title: "Wrapped Mensal",
                      subtitle: "Veja o que você mais ouviu este mês.",
                      onTap: () => _generateWrapped(context, false),
                    ),
                    const SizedBox(height: 24),
                    _buildWrappedOption(
                      context,
                      icon: Icons.auto_graph,
                      title: "Wrapped Anual",
                      subtitle: "Sua retrospectiva completa do ano.",
                      onTap: () => _generateWrapped(context, true),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildWrappedOption(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
