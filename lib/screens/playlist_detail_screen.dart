import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/flux_provider.dart';
import '../widgets/mini_player_bar.dart';

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

    final int index = filteredTracks.indexOf(track);
    provider.currentQueue = List.from(filteredTracks);
    provider.playPlaylist(filteredTracks.sublist(index >= 0 ? index : 0));
  }
