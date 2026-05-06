import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flux_provider.dart';
import '../providers/lyrics.dart'; // Certifique-se do caminho correto
import '../main.dart';

class LyricsView extends StatelessWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);
    final track = provider.currentTrack;

    if (track == null) return const Scaffold(body: Center(child: Text("Sem música")));

    return Scaffold(
      appBar: AppBar(
        title: Text(track['track_name'] ?? 'Letras'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: Lyrics().getLyrics(
          videoId: track['video_id'] ?? '',
          title: track['track_name'] ?? '',
          durationInSeconds: provider.player.duration?.inSeconds ?? 0,
          artist: track['artist'],
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: FluxApp.accentColor));
          }
          if (!snapshot.hasData || snapshot.data!['success'] == false) {
            return const Center(child: Text("Letras não encontradas."));
          }

          final lyricsData = snapshot.data!;
          // Prioriza letras sincronizadas, senão usa a letra simples
          final String content = lyricsData['syncedLyrics'] ?? lyricsData['plainLyrics'] ?? "";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              content.replaceAll(RegExp(r'\[.*?\]'), ''), // Remove os timestamps [00:00.00]
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, height: 1.8, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}