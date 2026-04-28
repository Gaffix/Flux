import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/flux_provider.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);
    if (provider.currentTrack == null) return const SizedBox.shrink();

    final track = provider.currentTrack!;
    final imageUrl = track['album_image_url'] ?? '';

    return Container(
      color: const Color(0xFF181818),
      height: 75,
      child: Column(
        children: [
          // Barra de progresso
          StreamBuilder<Duration>(
            stream: provider.player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final total = provider.player.duration ?? Duration.zero;
              final progress =
                  total.inMilliseconds > 0
                      ? position.inMilliseconds / total.inMilliseconds
                      : 0.0;
              return LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: FluxApp.progressTrackColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  FluxApp.accentColor,
                ),
                minHeight: 2,
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
    );
  }
}