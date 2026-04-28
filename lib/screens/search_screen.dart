import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import 'package:path_provider/path_provider.dart';

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
                  // Listar Playlists Existentes
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
                                    provider.createPlaylist(
                                      textController.text,
                                    );
                                      Future<void> findMyFiles() async {
                                        Directory? directory;
                                        if (Platform.isAndroid) {
                                          directory = await getExternalStorageDirectory();
                                        } else {
                                          directory = await getApplicationDocumentsDirectory();
                                        }
                                        debugPrint("FLUX AUDIO FOLDER IS EXACTLY HERE: ${directory?.path}");
                                      }
                                    findMyFiles();
                                    Navigator.pop(context);
                                    setModalState(() {}); // Atualiza o modal
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
            decoration: InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: const Icon(Icons.search),
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
                  : ListView.builder(
                    itemCount: _searchResults.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                      final video = _searchResults[index];
                      return ListTile(
                        leading: Image.network(
                          video.thumbnails.lowResUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(video.author),
                        trailing: IconButton(
                          icon: const Icon(Icons.playlist_add),
                          onPressed: () => _showPlaylistOptions(video),
                        ),
                        onTap: () async {
                          debugPrint(
                            "FLUX: 1. Cliquei na música: ${video.title}",
                          );

                          final serverUrl =
                              "${provider.baseUrl}/get_audio?id=${video.id.value}";

                          try {
                            debugPrint(
                              "FLUX: 2. Chamando servidor: $serverUrl",
                            );
                            final response = await http.get(
                              Uri.parse(serverUrl),
                              headers: {'ngrok-skip-browser-warning': 'true'},
                            );

                            debugPrint(
                              "FLUX: 3. Resposta recebida! Status: ${response.statusCode}",
                            );

// ... dentro do onTap no final de search_screen.dart
                          if (response.statusCode == 200) {
                              final data = json.decode(response.body);
                              debugPrint("FLUX: 4. Deu bom! URL recebida, dando play...");
                              
                              // Transformamos o Video no seu modelo JSON antes de tocar
                              final trackMap = {
                                "track_name": video.title,
                                "artist": video.author,
                                "album_image_url": video.thumbnails.lowResUrl,
                                "video_id": video.id.value,
                              };
                              
                              provider.playTrack(trackMap, data['url']); // Alterado de playVideo para playTrack
                            } 
// ...
                          } catch (e) {
                            debugPrint("FLUX: ERRO DE CONEXÃO/FLUTTER: $e");
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
