import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/flux_provider.dart';
import '../screens/lyrics_view.dart';
import '../main.dart';

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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FluxApp.accentColor.withOpacity(0.18),
              FluxApp.backgroundColor.withOpacity(0.95),
              FluxApp.backgroundColor,
            ],
            stops: const [0.0, 0.45, 1.0],
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
                              color: FluxApp.accentColor.withOpacity(0.15),
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
                Align(
                  alignment: Alignment.centerLeft,
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
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
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
