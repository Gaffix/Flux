import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/flux_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final baseUrl = Provider.of<FluxProvider>(context, listen: false).baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/search?q=${Uri.encodeQueryComponent(query)}'),
      );
      if (response.statusCode != 200) {
        throw Exception('Search failed (${response.statusCode})');
      }
      final results =
          (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _searchResults =
            results
                .map(
                  (video) => <String, String>{
                    'track_name': video['title']?.toString() ?? 'Unknown title',
                    'artist': video['channel']?.toString() ?? 'YouTube',
                    'video_id': video['video_id']?.toString() ?? '',
                    'album_image_url':
                        'https://i.ytimg.com/vi/${video['video_id']}/hqdefault.jpg',
                  },
                )
                .where((video) => video['video_id']!.isNotEmpty)
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("FLUX: Search error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPlaylistOptions(Map<String, String> video) {
    final provider = Provider.of<FluxProvider>(context, listen: false);
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: FluxApp.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Salvar em Playlist",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // Playlists existentes
                  ...provider.playlists.keys.map(
                    (name) => ListTile(
                      leading: const Icon(
                        Icons.playlist_add,
                        color: FluxApp.accentColor,
                      ),
                      title: Text(name),
                      onTap: () {
                        provider.addTrackToPlaylist(name, video);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Adicionado a $name")),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.white),
                    title: const Text("Nova Playlist"),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text("Nome da Playlist"),
                              content: TextField(
                                controller: textController,
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancelar"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (textController.text.isNotEmpty) {
                                      provider.createPlaylist(
                                        textController.text,
                                      );
                                    }
                                    Navigator.pop(context);
                                    setModalState(() {});
                                  },
                                  child: const Text("Criar"),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onVideoTap(
    BuildContext context,
    Map<String, String> trackMap,
  ) async {
    final provider = Provider.of<FluxProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Carregando ${trackMap['track_name']}..."),
        behavior: SnackBarBehavior.floating,
      ),
    );

    provider.playPlaylist([trackMap]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onSubmitted: _performSearch,
            decoration: InputDecoration(
              hintText: 'Buscar músicas no YouTube...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                      : null,
              filled: true,
              fillColor: FluxApp.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: FluxApp.accentColor,
                    ),
                  )
                  : _searchResults.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: FluxApp.secondaryTextColor.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Pesquise por músicas ou artistas",
                          style: TextStyle(
                            color: FluxApp.secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: _searchResults.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                      final video = _searchResults[index];
                      return ListTile(
                        leading:
                            video['album_image_url']!.isNotEmpty
                                ? Image.network(
                                  video['album_image_url']!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(
                                            Icons.music_note,
                                            size: 50,
                                          ),
                                )
                                : const Icon(Icons.music_note, size: 50),
                        title: Text(
                          video['track_name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(video['artist']!),
                        trailing: Consumer<FluxProvider>(
                          builder: (context, provider, child) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    provider.isFavorite(video)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color:
                                        provider.isFavorite(video)
                                            ? FluxApp.accentColor
                                            : FluxApp.secondaryTextColor,
                                  ),
                                  onPressed:
                                      () => provider.toggleFavorite(video),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.playlist_add),
                                  onPressed: () => _showPlaylistOptions(video),
                                ),
                              ],
                            );
                          },
                        ),
                        onTap: () => _onVideoTap(context, video),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
