import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await yt.search.search(query);
      setState(() {
        _searchResults = results.whereType<Video>().toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showPlaylistOptions(Video video) {
    final provider = Provider.of<FluxProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: FluxApp.cardColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.playlists.keys
                .map(
                  (name) => ListTile(
                    title: Text("Adicionar a $name"),
                    onTap: () {
                      provider.addTrackToPlaylist(name, {
                        "track_name": video.title,
                        "artist": video.author,
                        "album_image_url": video.thumbnails.lowResUrl,
                        "video_id": video.id.value,
                      });
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context, listen: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onSubmitted: _performSearch,
            decoration: const InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: FluxApp.cardColor,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final video = _searchResults[index];
                    return ListTile(
                      leading: Image.network(
                        video.thumbnails.lowResUrl,
                        width: 50,
                        height: 50,
                      ),
                      title: Text(video.title, maxLines: 1),
                      subtitle: Text(video.author),
                      trailing: IconButton(
                        icon: const Icon(Icons.playlist_add),
                        onPressed: () => _showPlaylistOptions(video),
                      ),
                      onTap: () async {
                        final serverUrl =
                            "${provider.baseUrl}/get_audio?id=${video.id.value}";
                        try {
                          final response = await http.get(
                            Uri.parse(serverUrl),
                            headers: {'ngrok-skip-browser-warning': 'true'},
                          );
                          if (response.statusCode == 200) {
                            final data = json.decode(response.body);
                            provider.playTrack(data['url']);
                          }
                        } catch (e) {
                          debugPrint("Erro: $e");
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
