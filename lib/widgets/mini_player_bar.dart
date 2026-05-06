import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import '../screens/lyrics_view.dart';
import '../screens/music_screen.dart'; // Importe a tela de música aqui

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);
    if (provider.currentTrack == null) return const SizedBox.shrink();

    final track = provider.currentTrack!;
    final imageUrl = track['album_image_url'] ?? '';

    return GestureDetector(
      // Implementação do onTap para abrir a MusicScreen
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MusicScreen(),
            fullscreenDialog: true, // Faz a tela deslizar de baixo para cima
          ),
        );
      },
      // Comportamento para garantir que o clique seja reconhecido em toda a barra
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: const Color(0xFF181818),
        height: 80, // Slightly increased height to accommodate the slider thumb
        child: Column(
          children: [
            // Interactive Progress/Seek Bar
            StreamBuilder<Duration>(
              stream: provider.player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = provider.player.duration ?? Duration.zero;

                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    // Customizing the thumb to be small so it doesn't break the "bar" look
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10.0,
                    ),
                    activeTrackColor: FluxApp.accentColor,
                    inactiveTrackColor: FluxApp.progressTrackColor,
                    thumbColor: FluxApp.accentColor,
                  ),
                  child: SizedBox(
                    height: 10, // Limits the vertical space of the slider
                    child: Slider(
                      min: 0.0,
                      // Ensure max is at least 1.0 to avoid errors if duration is null
                      max:
                          total.inMilliseconds.toDouble() > 0
                              ? total.inMilliseconds.toDouble()
                              : 1.0,
                      value: position.inMilliseconds.toDouble().clamp(
                        0.0,
                        total.inMilliseconds.toDouble() > 0
                            ? total.inMilliseconds.toDouble()
                            : 1.0,
                      ),
                      onChanged: (value) {
                        // Actually control the player position
                        provider.player.seek(
                          Duration(milliseconds: value.toInt()),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              dense: true,
              leading:
                  imageUrl.isNotEmpty
                      ? Image.network(
                        imageUrl,
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              width: 45,
                              height: 45,
                              color: FluxApp.cardColor,
                              child: const Icon(
                                Icons.music_note,
                                color: FluxApp.accentColor,
                              ),
                            ),
                      )
                      : Container(
                        width: 45,
                        height: 45,
                        color: FluxApp.cardColor,
                        child: const Icon(
                          Icons.music_note,
                          color: FluxApp.accentColor,
                        ),
                      ),
              title: Text(
                track['track_name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                track['artist'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- NOVO BOTÃO DE LETRAS NO PLAYER BAR ---
                    IconButton(
                      icon: const Icon(Icons.lyrics_outlined, size: 22),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LyricsView()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: () => provider.skipPrevious(),
                    ),
                  StreamBuilder<PlayerState>(
                    stream: provider.player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          size: 30,
                        ),
                        onPressed:
                            () =>
                                playing
                                    ? provider.player.pause()
                                    : provider.player.play(),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => provider.skipNext(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
