import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/flux_provider.dart';
import '../widgets/mini_player_bar.dart';
import '../main.dart';

// dart:io só existe no mobile/desktop, nunca no web
import 'dart:io' if (dart.library.html) 'dart_io_stub.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistName;
  final List<Map<String, String>> tracks;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistName,
    required this.tracks,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<Map<String, String>> filteredTracks;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    filteredTracks = List.from(widget.tracks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTracks(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredTracks = List.from(widget.tracks);
      } else {
        filteredTracks =
            widget.tracks.where((track) {
              final trackName = (track['track_name'] ?? '').toLowerCase();
              final artist = (track['artist'] ?? '').toLowerCase();
              final searchLower = query.toLowerCase();
              return trackName.contains(searchLower) ||
                  artist.contains(searchLower);
            }).toList();
      }
    });
  }

  void _showTrackOptions(
    BuildContext context,
    Map<String, String> track,
    FluxProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: (track['album_image_url'] ?? '').isNotEmpty
                        ? Image.network(
                            track['album_image_url']!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.music_note, size: 48),
                          )
                        : const Icon(Icons.music_note, size: 48),
                  ),
                ),
                title: Text(
                  track['track_name'] ?? 'Música',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(track['artist'] ?? ''),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.playlist_add,
                    color: FluxApp.accentColor),
                title: const Text('Adicionar a outra playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(context, track, provider);
                },
              ),
              // Download apenas no mobile/desktop
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.download_rounded,
                      color: FluxApp.accentColor),
                  title: const Text('Baixar música'),
                  onTap: () async {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Baixando ${track['track_name']}..."),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    bool success = await provider.downloadTrack(track);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? "Download concluído!" : "Erro ao baixar.",
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: const Text(
                  'Remover desta playlist',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  provider.removeFromPlaylist(widget.playlistName, track);
                  setState(() {
                    filteredTracks.remove(track);
                    widget.tracks.remove(track);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Música removida"),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    Map<String, String> track,
    FluxProvider provider,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text("Adicionar a..."),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    provider.playlists.keys.map((name) {
                      return ListTile(
                        leading: const Icon(Icons.playlist_add,
                            color: FluxApp.accentColor),
                        title: Text(name),
                        onTap: () {
                          provider.addTrackToPlaylist(name, track);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Adicionada a $name"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }

  // Lógica de tap na faixa: unificada para web e mobile
  Future<void> _onTrackTap(
    BuildContext context,
    Map<String, String> track,
    FluxProvider provider,
  ) async {
    // No mobile: tenta arquivo local primeiro
    if (!kIsWeb) {
      final localPath = await provider.getDownloadedAudioPath(track);
      try {
        if (await File(localPath).exists()) {
          debugPrint("FLUX: Local file found! Playing: $localPath");
          provider.currentQueue = List.from(filteredTracks);
          provider.playTrack(track);
          return;
        }
      } catch (_) {}
    }

    // No web e no mobile (sem local): usa o servidor
    if (provider.baseUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Configure o servidor primeiro nas configurações (⚙️).",
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Carregando ${track['track_name']}..."),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // playTrack já resolve o video_id e busca a URL no servidor internamente
    provider.currentQueue = List.from(filteredTracks);
    provider.playTrack(track);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar música ou artista...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  onChanged: _filterTracks,
                )
                : Text(
                    widget.playlistName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterTracks('');
                }
              });
            },
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (value) async {
                if (value == 'download') {
                  if (kIsWeb) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "Download de playlist não disponível no navegador.",
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Baixando '${widget.playlistName}' em segundo plano...",
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  final provider =
                      Provider.of<FluxProvider>(context, listen: false);
                  await provider
                      .downloadEntirePlaylist(widget.playlistName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            const Text("Download da playlist concluído!"),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } else if (value == 'delete') {
                  final provider =
                      Provider.of<FluxProvider>(context, listen: false);
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E2E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text("Apagar Playlist?"),
                          content: Text(
                            "Tem certeza que deseja apagar '${widget.playlistName}'?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Cancelar",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                provider
                                    .deletePlaylist(widget.playlistName);
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              child: const Text(
                                "Apagar",
                                style:
                                    TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                  );
                }
              },
              itemBuilder:
                  (context) => [
                    if (!kIsWeb)
                      const PopupMenuItem(
                        value: 'download',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.download_for_offline_rounded,
                            color: FluxApp.accentColor,
                          ),
                          title: Text('Baixar Playlist'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        title: Text(
                          'Apagar Playlist',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body:
          widget.tracks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off_rounded,
                          size: 64,
                          color: FluxApp.secondaryTextColor.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text(
                        "Nenhuma música nesta playlist",
                        style:
                            TextStyle(color: FluxApp.secondaryTextColor),
                      ),
                    ],
                  ),
                )
              : Column(
                children: [
                  // --- PLAY / SHUFFLE TOGGLE BUTTONS ---
                  Consumer<FluxProvider>(
                    builder: (context, provider, _) {
                      final isShuffled = provider
                          .isPlaylistShuffled(widget.playlistName);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // Tocar em Ordem
                            Expanded(
                              child: _PlayModeButton(
                                icon: Icons.play_arrow_rounded,
                                label: "Tocar",
                                isActive: !isShuffled,
                                onPressed: () {
                                  provider.setPlaylistShuffle(
                                      widget.playlistName, false);
                                  provider.playPlaylist(filteredTracks,
                                      shuffle: false);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Aleatório
                            Expanded(
                              child: _PlayModeButton(
                                icon: Icons.shuffle_rounded,
                                label: "Aleatório",
                                isActive: isShuffled,
                                onPressed: () {
                                  provider.setPlaylistShuffle(
                                      widget.playlistName, true);
                                  provider.playPlaylist(filteredTracks,
                                      shuffle: true);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.06)),
                  ),
                  Expanded(
                    child:
                        filteredTracks.isEmpty
                            ? const Center(
                              child:
                                  Text("Nenhuma música encontrada."),
                            )
                            : ListView.builder(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              itemCount: filteredTracks.length,
                              itemBuilder: (context, index) {
                                final track = filteredTracks[index];
                                final videoId =
                                    track['video_id'] ?? '';

                                return Consumer<FluxProvider>(
                                  builder:
                                      (context, provider, child) {
                                    final status = provider
                                        .getTrackStatus(videoId);
                                    final isCurrentlyPlaying =
                                        provider.currentTrack != null &&
                                            provider.currentTrack!['track_name'] ==
                                                track['track_name'] &&
                                            provider.currentTrack!['artist'] ==
                                                track['artist'];

                                    return Container(
                                      color: isCurrentlyPlaying
                                          ? FluxApp.accentColor
                                              .withOpacity(0.08)
                                          : Colors.transparent,
                                      child: ListTile(
                                        leading: Stack(
                                          alignment:
                                              Alignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(6),
                                              child: SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: (track['album_image_url'] ??
                                                            '')
                                                        .isNotEmpty
                                                    ? Image.network(
                                                        track[
                                                            'album_image_url']!,
                                                        fit: BoxFit
                                                            .cover,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            Container(
                                                          color: FluxApp
                                                              .cardColor,
                                                          child: const Icon(
                                                              Icons
                                                                  .music_note,
                                                              size:
                                                                  24,
                                                              color:
                                                                  FluxApp.accentColor),
                                                        ),
                                                      )
                                                    : Container(
                                                        color: FluxApp
                                                            .cardColor,
                                                        child: const Icon(
                                                            Icons
                                                                .music_note,
                                                            size:
                                                                24,
                                                            color:
                                                                FluxApp.accentColor),
                                                      ),
                                              ),
                                            ),
                                            // Camada de progresso por cima
                                            if (status ==
                                                    "DOWNLOADING" &&
                                                provider.getProgress(
                                                        videoId) !=
                                                    null)
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors
                                                      .black45,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              6),
                                                ),
                                                child:
                                                    ValueListenableBuilder<
                                                        double>(
                                                  valueListenable:
                                                      provider
                                                          .getProgress(
                                                              videoId)!,
                                                  builder: (context,
                                                          value,
                                                          _) =>
                                                      CircularProgressIndicator(
                                                    value: value,
                                                    color: FluxApp
                                                        .accentColor,
                                                    strokeWidth: 3,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        title: Text(
                                          track['track_name'] ?? '',
                                          style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            color: isCurrentlyPlaying
                                                ? FluxApp.accentColor
                                                : FluxApp
                                                    .primaryTextColor,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          status == "QUEUED"
                                              ? "Na fila..."
                                              : track['artist'] ??
                                                  '',
                                          style: TextStyle(
                                            color: status == "QUEUED"
                                                ? FluxApp.accentColor
                                                    .withOpacity(
                                                        0.7)
                                                : FluxApp
                                                    .secondaryTextColor,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                        trailing: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            if (status ==
                                                "DOWNLOADED")
                                              const Icon(
                                                Icons
                                                    .check_circle_rounded,
                                                color: FluxApp
                                                    .accentColor,
                                                size: 18,
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.more_vert,
                                                  size: 20),
                                              onPressed: () {
                                                _showTrackOptions(
                                                    context,
                                                    track,
                                                    provider);
                                              },
                                            ),
                                          ],
                                        ),
                                        onTap: () => _onTrackTap(
                                            context,
                                            track,
                                            provider),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                  // Mini player fixo acima dos botões do sistema
                  const SafeArea(
                      top: false, child: MiniPlayerBar()),
                ],
              ),
    );
  }
}

/// Botão estilizado para os modos Tocar/Aleatório
class _PlayModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _PlayModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color:
                isActive ? FluxApp.accentColor : FluxApp.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: isActive
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    isActive ? Colors.white : FluxApp.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isActive
                      ? Colors.white
                      : FluxApp.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
