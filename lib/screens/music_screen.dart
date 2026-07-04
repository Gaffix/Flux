import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/flux_provider.dart';
import '../screens/lyrics_view.dart';
import '../main.dart';
import 'package:share_plus/share_plus.dart';

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);
    final track = provider.currentTrack;

    // Se por algum motivo não houver música tocando
    if (track == null) {
      return Scaffold(
        backgroundColor: FluxApp.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text("Nenhuma música tocando no momento."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FluxApp.backgroundColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              provider.dominantColor.withOpacity(0.6),
              FluxApp.backgroundColor.withOpacity(0.95),
              FluxApp.backgroundColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- TOP BAR ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.lyrics,
                              color: FluxApp.accentColor, size: 24),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LyricsView()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.timer_outlined,
                              color: FluxApp.accentColor, size: 24),
                          onPressed: () => _showSleepTimerDialog(context, provider),
                        ),
                      ],
                    ),
                    Text(
                      "TOCANDO AGORA",
                      style: GoogleFonts.inter(
                        color: FluxApp.secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- CAPA DO ÁLBUM ---
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: provider.dominantColor.withOpacity(0.3),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: (track['album_image_url'] != null &&
                                  track['album_image_url']!.isNotEmpty)
                              ? Image.network(
                                  track['album_image_url']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const _FallbackImage(),
                                )
                              : const _FallbackImage(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // --- INFORMAÇÕES DA MÚSICA ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track['track_name'] ?? 'Música Desconhecida',
                            style: GoogleFonts.inter(
                              color: FluxApp.primaryTextColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            track['artist'] ?? 'Artista Desconhecido',
                            style: GoogleFonts.inter(
                              color: FluxApp.secondaryTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        provider.isFavorite(track) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: provider.isFavorite(track) ? FluxApp.accentColor : FluxApp.secondaryTextColor,
                        size: 28,
                      ),
                      onPressed: () {
                        provider.toggleFavorite(track);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- BARRA DE PROGRESSO (SLIDER) ---
                StreamBuilder<Duration>(
                  stream: provider.player.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration?>(
                      stream: provider.player.durationStream,
                      builder: (context, durationSnapshot) {
                        final duration =
                            durationSnapshot.data ?? Duration.zero;
                        final double maxDuration =
                            duration.inMilliseconds.toDouble() > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1.0;
                        final double currentPosition = position
                            .inMilliseconds
                            .toDouble()
                            .clamp(0.0, maxDuration);

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: FluxApp.accentColor,
                                inactiveTrackColor:
                                    Colors.white.withOpacity(0.1),
                                thumbColor: FluxApp.accentColor,
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7.0,
                                ),
                                overlayShape:
                                    const RoundSliderOverlayShape(
                                  overlayRadius: 14.0,
                                ),
                                overlayColor:
                                    FluxApp.accentColor.withOpacity(0.15),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: maxDuration,
                                value: currentPosition,
                                onChanged: (value) {
                                  provider.player.seek(
                                    Duration(
                                        milliseconds: value.round()),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: GoogleFonts.inter(
                                      color: FluxApp.secondaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: GoogleFonts.inter(
                                      color: FluxApp.secondaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // --- CONTROLES DE MÍDIA ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botão Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: provider.isShuffled ? FluxApp.accentColor : FluxApp.secondaryTextColor,
                      ),
                      onPressed: () {
                        provider.toggleShuffle();
                      },
                    ),
                    
                    // Botão Voltar
                    IconButton(
                      iconSize: 44,
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: FluxApp.primaryTextColor,
                      ),
                      onPressed: () {
                        provider.skipPrevious();
                      },
                    ),

                    // Botão Play/Pause
                    StreamBuilder<bool>(
                      stream: provider.player.playingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return Container(
                          decoration: BoxDecoration(
                            color: FluxApp.accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    FluxApp.accentColor.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IconButton(
                            iconSize: 56,
                            padding: const EdgeInsets.all(14),
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                provider.player.pause();
                              } else {
                                provider.player.play();
                              }
                            },
                          ),
                        );
                      },
                    ),

                    // Botão Avançar
                    IconButton(
                      iconSize: 44,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: FluxApp.primaryTextColor,
                      ),
                      onPressed: () {
                        provider.skipNext();
                      },
                    ),
                    
                    // Botão Repeat
                    IconButton(
                      icon: Icon(
                        provider.repeatMode == PlaybackRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: provider.repeatMode != PlaybackRepeatMode.off
                            ? FluxApp.accentColor
                            : FluxApp.secondaryTextColor,
                      ),
                      onPressed: () {
                        provider.toggleRepeatMode();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                
                // --- SHARE AND QUEUE ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: FluxApp.secondaryTextColor),
                      onPressed: () {
                        Share.share('Estou ouvindo ${track['track_name']} de ${track['artist']} no Flux App!');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.queue_music_rounded, color: FluxApp.secondaryTextColor),
                      onPressed: () => _showQueueBottomSheet(context, provider),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context, FluxProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FluxApp.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Fila de Reprodução",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: provider.currentQueue.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        provider.reorderQueue(oldIndex, newIndex);
                      });
                    },
                    itemBuilder: (context, index) {
                      final track = provider.currentQueue[index];
                      final isPlaying = track['track_name'] == provider.currentTrack?['track_name'] && 
                                        track['artist'] == provider.currentTrack?['artist'];
                      return ListTile(
                        key: ValueKey('${track['track_name']}_${track['artist']}_$index'),
                        leading: (track['album_image_url'] != null && track['album_image_url']!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(track['album_image_url']!, width: 40, height: 40, fit: BoxFit.cover),
                              )
                            : Container(width: 40, height: 40, color: FluxApp.cardColor),
                        title: Text(
                          track['track_name'] ?? 'Desconhecido',
                          style: TextStyle(
                            color: isPlaying ? FluxApp.accentColor : Colors.white,
                            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track['artist'] ?? 'Desconhecido',
                          style: TextStyle(color: FluxApp.secondaryTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.drag_handle, color: FluxApp.secondaryTextColor),
                        onTap: () {
                          // Play this track specifically if tapped?
                          // (Requires playTrack update or skipping until found. We can just skip for now, or just play Track directly but we need to ensure currentQueue handles it properly).
                          provider.playTrack(track); // this might mess up the queue sequence if playTrack doesn't maintain currentQueue. 
                          // Actually, playTrack updates currentTrack. And skips will follow.
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context, FluxProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FluxApp.cardColor,
          title: const Text("Sleep Timer", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.sleepTimerEndTime != null) ...[
                const Text(
                  "Timer ativo. A música irá parar em breve.",
                  style: TextStyle(color: FluxApp.secondaryTextColor),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: FluxApp.accentColor),
                  onPressed: () {
                    provider.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancelar Timer", style: TextStyle(color: Colors.white)),
                ),
              ] else ...[
                _timerOption(context, provider, 15, "15 Minutos"),
                _timerOption(context, provider, 30, "30 Minutos"),
                _timerOption(context, provider, 45, "45 Minutos"),
                _timerOption(context, provider, 60, "1 Hora"),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _timerOption(BuildContext context, FluxProvider provider, int minutes, String label) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        provider.startSleepTimer(Duration(minutes: minutes));
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sleep timer definido para $label")),
        );
      },
    );
  }
}

// Widget auxiliar para quando não houver imagem
class _FallbackImage extends StatelessWidget {
  const _FallbackImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FluxApp.cardColor,
            FluxApp.accentColor.withOpacity(0.2),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 80,
          color: FluxApp.secondaryTextColor,
        ),
      ),
    );
  }
}
