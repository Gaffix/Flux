import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import '../screens/lyrics_view.dart';
import '../screens/music_screen.dart';

class MiniPlayerBar extends StatefulWidget {
  const MiniPlayerBar({super.key});

  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<MiniPlayerBar> with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;

  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);
    if (provider.currentTrack == null) return const SizedBox.shrink();

    final track = provider.currentTrack!;
    final imageUrl = track['album_image_url'] ?? '';
    final dominantColor = provider.dominantColor;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MusicScreen(),
            fullscreenDialog: true,
          ),
        );
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -300) {
            provider.skipNext();
          } else if (details.primaryVelocity! > 300) {
            provider.skipPrevious();
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    dominantColor.withValues(alpha: 0.35),
                    const Color(0xFF1A1A2E).withValues(alpha: 0.75),
                    const Color(0xFF0D0D1A).withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: dominantColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress slider — thin bar at top
                  StreamBuilder<Duration>(
                    stream: provider.player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final total = provider.player.duration ?? Duration.zero;
                      final maxVal = total.inMilliseconds.toDouble() > 0
                          ? total.inMilliseconds.toDouble()
                          : 1.0;

                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 0,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                          activeTrackColor: FluxApp.accentColor,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                          thumbColor: Colors.transparent,
                        ),
                        child: SizedBox(
                          height: 3,
                          child: Slider(
                            min: 0.0,
                            max: maxVal,
                            value: position.inMilliseconds
                                .toDouble()
                                .clamp(0.0, maxVal),
                            onChanged: (value) {
                              provider.player
                                  .seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
                    child: Row(
                      children: [
                        // Album art with rounded corners and glow
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: dominantColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        color: FluxApp.cardColor,
                                        child: const Icon(Icons.music_note,
                                            color: FluxApp.accentColor,
                                            size: 22),
                                      ),
                                    )
                                  : Container(
                                      color: FluxApp.cardColor,
                                      child: const Icon(Icons.music_note,
                                          color: FluxApp.accentColor,
                                          size: 22),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Track info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track['track_name'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track['artist'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Controls
                        IconButton(
                          icon: const Icon(Icons.lyrics_outlined,
                              size: 20, color: FluxApp.accentColor),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LyricsView()),
                            );
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, size: 24),
                          onPressed: () => provider.skipPrevious(),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: provider.player.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            
                            if (playing) {
                              _playPauseController.forward();
                            } else {
                              _playPauseController.reverse();
                            }
                            
                            return IconButton(
                              icon: AnimatedIcon(
                                icon: AnimatedIcons.play_pause,
                                progress: _playPauseController,
                                size: 30,
                                color: FluxApp.accentColor,
                              ),
                              onPressed: () => provider.togglePlayPause(),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 24),
                          onPressed: () => provider.skipNext(),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
