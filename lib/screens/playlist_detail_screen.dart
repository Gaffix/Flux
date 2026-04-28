import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/flux_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
    // Inicializa a lista filtrada com todas as músicas da playlist
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
        filteredTracks = widget.tracks.where((track) {
          final trackName = (track['track_name'] ?? '').toLowerCase();
          final artist = (track['artist'] ?? '').toLowerCase();
          final searchLower = query.toLowerCase();
          
          return trackName.contains(searchLower) || artist.contains(searchLower);
        }).toList();
      }
    });
  }

  void _showTrackOptions(BuildContext context, Map<String, String> track, FluxProvider provider) {
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
                title: Text(track['track_name'] ?? 'Música', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(track['artist'] ?? ''),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Adicionar a outra playlist'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showAddToPlaylistDialog(context, track, provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Baixar música'),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Baixando ${track['track_name']}...")),
                  );
                  
                  bool success = await provider.downloadTrack(track);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? "Download concluído!" : "Erro ao baixar.")),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Remover desta playlist', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  provider.removeFromPlaylist(widget.playlistName, track);
                  setState(() {
                    filteredTracks.remove(track);
                    widget.tracks.remove(track); // Keep original list in sync
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

  void _showAddToPlaylistDialog(BuildContext context, Map<String, String> track, FluxProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF242424),
        title: const Text("Adicionar a..."),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: provider.playlists.keys.map((name) {
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
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
          // Adiciona o menu de opções da playlist quando não estiver pesquisando
          if (!_isSearching)
            PopupMenuButton<String>(
              color: const Color(0xFF242424),
              onSelected: (value) async {
                if (value == 'download') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Baixando '${widget.playlistName}' em segundo plano...")),
                  );
                  
                  // Inicia o download da playlist
                  await provider.downloadEntirePlaylist(widget.playlistName);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Download da playlist concluído!")),
                    );
                  }
                } else if (value == 'delete') {
                  // Confirmação antes de apagar
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF242424),
                      title: const Text("Apagar Playlist?"),
                      content: Text("Tem certeza que deseja apagar '${widget.playlistName}'?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
                        ),
                        TextButton(
                          onPressed: () {
                            provider.deletePlaylist(widget.playlistName);
                            Navigator.pop(context); // Fecha o dialog
                            Navigator.pop(context); // Volta para a LibraryScreen
                          },
                          child: const Text("Apagar", style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.download_for_offline, color: Color(0xFF14B8A6)),
                    title: Text('Baixar Playlist'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete, color: Colors.redAccent),
                    title: Text('Apagar Playlist', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: widget.tracks.isEmpty
          ? const Center(child: Text("Nenhuma música nesta playlist"))
          : Column(
              children: [
                // --- SHUFFLE BUTTON SECTION ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6), // FluxApp.accentColor
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      icon: const Icon(Icons.shuffle),
                      label: Text(
                        _isSearching && _searchController.text.isNotEmpty
                            ? "TOCAR RESULTADOS ALEATÓRIOS"
                            : "ORDEM ALEATÓRIA",
                      ),
                      onPressed: () {
                        // Toca a lista filtrada no modo aleatório
                        provider.playPlaylist(filteredTracks, shuffle: true);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                // --- PLAYLIST ITEMS ---
                Expanded(
                  child: filteredTracks.isEmpty
                      ? const Center(child: Text("Nenhuma música encontrada."))
                      : ListView.builder(
                          itemCount: filteredTracks.length,
                          itemBuilder: (context, index) {
                            final track = filteredTracks[index];
                              return ListTile(
                              leading: Image.network(
                                track['album_image_url'] ?? '',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                    const Icon(Icons.music_note, size: 50),
                              ),
                              title: Text(
                                track['track_name'] ?? 'Desconhecido',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(track['artist'] ?? ''),
                              
                              // --- ADICIONE ESTA LINHA AQUI ---
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _showTrackOptions(context, track, provider),
                              ),
                              // --------------------------------

                              onTap: () async {
                                // (O resto do seu código onTap continua igual...)
                                // 1. CHECK LOCAL FILE FIRST
                                final localPath = await provider.getDownloadedAudioPath(track);
                                if (await File(localPath).exists()) {
                                  debugPrint("FLUX: Local file found! Playing: $localPath");
                                  provider.playTrack(track); 
                                  return;
                                }

                                // 2. IF NOT LOCAL, SEARCH YOUTUBE/SERVER
                                String? videoId = track['video_id'];
                                if (videoId == null || videoId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Buscando ${track['track_name']}...")),
                                  );
                                  
                                  final yt = YoutubeExplode();
                                  try {
                                    final searchResults = await yt.search.search("${track['track_name']} ${track['artist']} audio");
                                    if (searchResults.isNotEmpty) {
                                      videoId = searchResults.first.id.value;
                                    } else {
                                      yt.close();
                                      return; 
                                    }
                                  } catch (e) {
                                    yt.close();
                                    return;
                                  }
                                  yt.close();
                                }

                                // 3. CALL SERVER
                                final serverUrl = "${provider.baseUrl}/get_audio?id=$videoId";
                                try {
                                  final response = await http.get(Uri.parse(serverUrl), headers: {'ngrok-skip-browser-warning': 'true'});
                                  if (response.statusCode == 200) {
                                    final data = json.decode(response.body);
                                    provider.playTrack(track, data['url']); 
                                  }
                                } catch (e) {
                                  debugPrint("FLUX: Server error: $e");
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}