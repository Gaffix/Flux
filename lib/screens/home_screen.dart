import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import 'playlist_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Gera uma cor baseada no nome do artista para o fundo da bolinha
  Color _getArtistColor(String name) {
    final colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.tealAccent,
      Colors.redAccent,
      Colors.indigoAccent,
    ];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);
    final playlists = provider.playlists;

    // Estado Vazio: Se não houver playlists ou músicas nas favoritas
    if (playlists.isEmpty ||
        (playlists.length == 1 && playlists["Favoritas"]!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 80,
                color: FluxApp.accentColor.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                "Crie suas playlists pesquisando músicas!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: FluxApp.secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pega as 6 primeiras playlists para o grid (preenche melhor a tela)
    final topPlaylists = playlists.keys.take(6).toList();

    // Lógica para calcular artistas favoritos baseado nas playlists
    Map<String, int> artistCount = {};
    for (var list in playlists.values) {
      for (var track in list) {
        String artist = track['artist'] ?? 'Desconhecido';
        artistCount[artist] = (artistCount[artist] ?? 0) + 1;
      }
    }
    var sortedArtists =
        artistCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(10).map((e) => e.key).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Suas Playlists",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: FluxApp.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 3,
            ),
            itemCount: topPlaylists.length,
            itemBuilder: (context, index) {
              String name = topPlaylists[index];
              final tracks = playlists[name]!;
              // Pega a foto da primeira música da playlist
              final String? imageUrl =
                  tracks.isNotEmpty ? tracks[0]['album_image_url'] : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PlaylistDetailScreen(
                            playlistName: name,
                            tracks: tracks,
                          ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: FluxApp.cardColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 55,
                        height: 55,
                        child:
                            (imageUrl != null && imageUrl.isNotEmpty)
                                ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (c, e, s) => const _PlaylistPlaceholder(),
                                )
                                : const _PlaylistPlaceholder(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          const Text(
            "Seus Artistas Favoritos",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: FluxApp.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: topArtists.length,
              itemBuilder: (context, index) {
                String artist = topArtists[index];
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _getArtistColor(artist),
                        child: Text(
                          artist.isNotEmpty ? artist[0].toUpperCase() : "?",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artist,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FluxApp.primaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 100), // Espaço para o mini player não cobrir
        ],
      ),
    );
  }
}

class _PlaylistPlaceholder extends StatelessWidget {
  const _PlaylistPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: FluxApp.accentColor.withOpacity(0.3),
      child: const Icon(Icons.music_note, color: FluxApp.accentColor),
    );
  }
}
