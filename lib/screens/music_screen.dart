import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flux_provider.dart';
import '../screens/lyrics_view.dart';
import '../main.dart';

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  // Função auxiliar para formatar a duração (ex: 03:45)
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

    // Se por algum motivo não houver música tocando, exibe uma tela vazia
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
        body: const Center(child: Text("Nenhuma música tocando no momento.")),
      );
    }

    return Scaffold(
      backgroundColor: FluxApp.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- TOP BAR (TÍTULO E BOTÃO FECHAR) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- NOVO BOTÃO DE LETRAS ---
                  IconButton(
                    icon: const Icon(Icons.lyrics, color: FluxApp.accentColor, size: 24),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LyricsView()),
                      );
                    },
                  ),
                  const Text(
                    "TOCANDO AGORA",
                    style: TextStyle(
                      color: FluxApp.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- CAPA DO ÁLBUM ---
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0, // Mantém a imagem quadrada
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child:
                            (track['album_image_url'] != null &&
                                    track['album_image_url']!.isNotEmpty)
                                ? Image.network(
                                  track['album_image_url']!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const _FallbackImage(),
                                )
                                : const _FallbackImage(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // --- INFORMAÇÕES DA MÚSICA ---
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track['track_name'] ?? 'Música Desconhecida',
                      style: const TextStyle(
                        color: FluxApp.primaryTextColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track['artist'] ?? 'Artista Desconhecido',
                      style: const TextStyle(
                        color: FluxApp.secondaryTextColor,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- BARRA DE PROGRESSO (SLIDER) ---
              StreamBuilder<Duration>(
                stream: provider.player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;

                  return StreamBuilder<Duration?>(
                    stream: provider.player.durationStream,
                    builder: (context, durationSnapshot) {
                      final duration = durationSnapshot.data ?? Duration.zero;

                      // Garante que o slider não quebre se a duração for nula ou menor que a posição
                      final double maxDuration =
                          duration.inMilliseconds.toDouble() > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1.0;
                      final double currentPosition = position.inMilliseconds
                          .toDouble()
                          .clamp(0.0, maxDuration);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: FluxApp.accentColor,
                              inactiveTrackColor: FluxApp.progressTrackColor,
                              thumbColor: FluxApp.accentColor,
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14.0,
                              ),
                            ),
                            child: Slider(
                              min: 0.0,
                              max: maxDuration,
                              value: currentPosition,
                              onChanged: (value) {
                                provider.player.seek(
                                  Duration(milliseconds: value.round()),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(
                                  color: FluxApp.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                  color: FluxApp.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // --- CONTROLES DE MÍDIA ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botão Voltar
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(
                      Icons.skip_previous,
                      color: FluxApp.primaryTextColor,
                    ),
                    onPressed: () {
                      provider.skipPrevious();
                    },
                  ),

                  // Botão Play/Pause (com tamanho maior)
                  StreamBuilder<bool>(
                    stream: provider.player.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return Container(
                        decoration: const BoxDecoration(
                          color: FluxApp.accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 64,
                          padding: const EdgeInsets.all(16),
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
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
                    iconSize: 48,
                    icon: const Icon(
                      Icons.skip_next,
                      color: FluxApp.primaryTextColor,
                    ),
                    onPressed: () {
                      provider.skipNext();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
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
      color: FluxApp.cardColor,
      child: const Center(
        child: Icon(
          Icons.music_note,
          size: 100,
          color: FluxApp.secondaryTextColor,
        ),
      ),
    );
  }
}
