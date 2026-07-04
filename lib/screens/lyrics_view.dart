import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flux_provider.dart';
import '../providers/lyrics.dart'; // Certifique-se do caminho correto
import '../main.dart';

class LyricLine {
  final Duration time;
  final String text;
  LyricLine(this.time, this.text);
}

class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  List<LyricLine> _parseLyrics(String lyricsStr) {
    List<LyricLine> lines = [];
    final RegExp regex = RegExp(r'\[(\d+):(\d+\.\d+)\](.*)');
    for (var line in lyricsStr.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        final time = Duration(milliseconds: (minutes * 60000 + seconds * 1000).round());
        if (text.isNotEmpty) {
          lines.add(LyricLine(time, text));
        }
      }
    }
    return lines;
  }

  int _getActiveLineIndex(Duration pos, List<LyricLine> lines) {
    for (int i = lines.length - 1; i >= 0; i--) {
      if (pos >= lines[i].time) {
        return i;
      }
    }
    return -1;
  }

  void _scrollToIndex(int index, int totalLines) {
    if (index == _lastActiveIndex || index < 0 || !_scrollController.hasClients) return;
    _lastActiveIndex = index;
    
    // Approximate scroll position to center the line
    final targetOffset = (index * 60.0) - (MediaQuery.of(context).size.height / 2) + 100;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

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
          final String syncedLyrics = lyricsData['syncedLyrics'] ?? "";
          final String plainLyrics = lyricsData['plainLyrics'] ?? "";

          // Se tem lyrics sincronizados, parse!
          if (syncedLyrics.isNotEmpty && syncedLyrics.contains('[')) {
            final lines = _parseLyrics(syncedLyrics);
            if (lines.isNotEmpty) {
              return StreamBuilder<Duration>(
                stream: provider.player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final activeIndex = _getActiveLineIndex(position, lines);

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToIndex(activeIndex, lines.length);
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: MediaQuery.of(context).size.height / 2 - 100,
                    ),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final isActive = index == activeIndex;
                      final isPast = index < activeIndex;

                      return Container(
                        height: 60,
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: isActive ? 24 : 18,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : (isPast ? Colors.white38 : Colors.white54),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                          child: Text(
                            lines[index].text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }
          }

          // Fallback para texto plano se não houver tempo
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              plainLyrics,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1.8, color: Colors.white70),
            ),
          );
        },
      ),
    );
  }
}