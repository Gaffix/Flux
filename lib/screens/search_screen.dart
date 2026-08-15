import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../providers/flux_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final YoutubeExplode yt = YoutubeExplode();
  final TextEditingController _searchController = TextEditingController();
  List<Video> _searchResults = [];
  bool _isLoading = false;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('flux_recent_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    if (_recentSearches.contains(query)) {
      _recentSearches.remove(query);
    }
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    await prefs.setStringList('flux_recent_searches', _recentSearches);
    setState(() {});
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    await prefs.setStringList('flux_recent_searches', _recentSearches);
    setState(() {});
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await yt.search.search(query);
      setState(() {
        _searchResults = results.whereType<Video>().toList();
        _isLoading = false;
      });
      _saveRecentSearch(query);
    } catch (e) {
      debugPrint("FLUX: Search error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    yt.close();
    _searchController.dispose();
    super.dispose();
  }

  void _showPlaylistOptions(Video video) {
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                        provider.addToPlaylist(name, video);
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

  Future<void> _onVideoTap(BuildContext context, Video video) async {
    final provider = Provider.of<FluxProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Carregando ${video.title}..."),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final trackMap = {
      "track_name": video.title,
      "artist": video.author,
      "album_image_url": video.thumbnails.lowResUrl,
      "video_id": video.id.value,
    };

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
                  ? _recentSearches.isNotEmpty
                    ? ListView.builder(
                        itemCount: _recentSearches.length,
                        itemBuilder: (context, index) {
                          final query = _recentSearches[index];
                          return ListTile(
                            leading: const Icon(Icons.history, color: FluxApp.secondaryTextColor),
                            title: Text(query, style: const TextStyle(color: Colors.white)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: FluxApp.secondaryTextColor, size: 20),
                              onPressed: () => _removeRecentSearch(query),
                            ),
                            onTap: () {
                              _searchController.text = query;
                              _performSearch(query);
                            },
                          );
                        },
                      )
                    : Center(
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
                          'Pesquise por músicas, artistas ou álbuns',
                          style: TextStyle(
                            color: FluxApp.secondaryTextColor.withOpacity(0.6),
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
                            video.thumbnails.lowResUrl.isNotEmpty
                                ? Image.network(
                                  video.thumbnails.lowResUrl,
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
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(video.author),
                        trailing: Consumer<FluxProvider>(
                          builder: (context, provider, child) {
                            final trackMap = {
                              "track_name": video.title,
                              "artist": video.author,
                              "album_image_url": video.thumbnails.lowResUrl,
                              "video_id": video.id.value,
                            };
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    provider.isFavorite(trackMap) ? Icons.favorite : Icons.favorite_border,
                                    color: provider.isFavorite(trackMap) ? FluxApp.accentColor : FluxApp.secondaryTextColor,
                                  ),
                                  onPressed: () => provider.toggleFavorite(trackMap),
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