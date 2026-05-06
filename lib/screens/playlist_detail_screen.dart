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
      backgroundColor: const Color(0xFF242424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  track['track_name'] ?? 'Música',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(track['artist'] ?? ''),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Adicionar a outra playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(context, track, provider);
                },
              ),
              // Download apenas no mobile/desktop
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Baixar música'),
                  onTap: () async {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Baixando ${track['track_name']}..."),
                      ),
                    );
                    bool success = await provider.downloadTrack(track);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? "Download concluído!" : "Erro ao baixar.",
                          ),
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
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
                    const SnackBar(content: Text("Música removida")),
                  );
                },
              ),
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
            backgroundColor: const Color(0xFF242424),
            title: const Text("Adicionar a..."),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    provider.playlists.keys.map((name) {
                      return ListTile(
                        title: Text(name),
                        onTap: () {
                          provider.addTrackToPlaylist(name, track);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Adicionada a $name")),
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
          provider.playTrack(track);
          return;
        }
      } catch (_) {}
    }

    // No web e no mobile (sem local): usa o servidor
    if (provider.baseUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Configure o servidor primeiro nas configurações (⚙️).",
            ),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Carregando ${track['track_name']}...")),
      );
    }

    // playTrack já resolve o video_id e busca a URL no servidor internamente
    provider.playTrack(track);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context, listen: false);

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
                : Text(widget.playlistName),
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
              color: const Color(0xFF242424),
              onSelected: (value) async {
                if (value == 'download') {
                  if (kIsWeb) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Download de playlist não disponível no navegador.",
                        ),
                      ),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Baixando '${widget.playlistName}' em segundo plano...",
                      ),
                    ),
                  );
                  await provider.downloadEntirePlaylist(widget.playlistName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Download da playlist concluído!"),
                      ),
                    );
                  }
                } else if (value == 'delete') {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          backgroundColor: const Color(0xFF242424),
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
                                provider.deletePlaylist(widget.playlistName);
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              child: const Text(
                                "Apagar",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                  );
                }
              },
              itemBuilder:
                  (context) => [
                    // Esconde download no web
                    if (!kIsWeb)
                      const PopupMenuItem(
                        value: 'download',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.download_for_offline,
                            color: Color(0xFF14B8A6),
                          ),
                          title: Text('Baixar Playlist'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete, color: Colors.redAccent),
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
              ? const Center(child: Text("Nenhuma música nesta playlist"))
              : Column(
                children: [
                  // Shuffle button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.shuffle),
                        label: Text(
                          _isSearching && _searchController.text.isNotEmpty
                              ? "TOCAR RESULTADOS ALEATÓRIOS"
                              : "ORDEM ALEATÓRIA",
                        ),
                        onPressed: () {
                          provider.playPlaylist(filteredTracks, shuffle: true);
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child:
                        filteredTracks.isEmpty
                            ? const Center(
                              child: Text("Nenhuma música encontrada."),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: filteredTracks.length,
                              // Dentro do ListView.builder da PlaylistDetailScreen
                              itemBuilder: (context, index) {
                                final track = filteredTracks[index];
                                final videoId = track['video_id'] ?? '';
                                
                                return Consumer<FluxProvider>(
                                  builder: (context, provider, child) {
                                    final status = provider.getTrackStatus(videoId);
                                    
                                    return ListTile(
                                      leading: Stack(
  alignment: Alignment.center,
  children: [
    // Este é o código de imagem que você já tem no seu arquivo original:
    (track['album_image_url'] ?? '').isNotEmpty
        ? Image.network(
            track['album_image_url']!,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.music_note, size: 50),
          )
        : const Icon(Icons.music_note, size: 50),
        
    // Camada de progresso por cima da imagem
    if (status == "DOWNLOADING" && provider.getProgress(videoId) != null)
      Container(
        width: 50,
        height: 50,
        color: Colors.black45,
        child: ValueListenableBuilder<double>(
          valueListenable: provider.getProgress(videoId)!,
          builder: (context, value, _) => CircularProgressIndicator(
            value: value,
            color: FluxApp.accentColor,
            strokeWidth: 3,
          ),
        ),
      ),
  ],
),
                                      title: Text(track['track_name'] ?? ''),
                                      subtitle: Text(status == "QUEUED" ? "Na fila..." : track['artist'] ?? ''),
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    // Show a checkmark if downloaded, otherwise nothing
    if (status == "DOWNLOADED")
      Icon(Icons.check_circle, color: FluxApp.accentColor),
    
    // The clickable "Three Dots" button
    IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () {
        // This calls the menu logic you already defined in your class
        _showTrackOptions(context, track, provider);
      },
    ),
  ],
),
                                      onTap: () => _onTrackTap(context, track, provider),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                  // Mini player fixo acima dos botões do sistema
                  SafeArea(top: false, child: MiniPlayerBar()),
                ],
              ),
    );
  }
}
