import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../main.dart';
import '../providers/flux_provider.dart';
import 'playlist_detail_screen.dart';
import 'dart:io' if (dart.library.html) 'dart_io_stub.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<void> _importJsonPlaylist(
    BuildContext context,
    FluxProvider provider,
  ) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null) {
        String jsonString;
        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes == null) throw Exception("Erro ao ler bytes");
          jsonString = utf8.decode(bytes);
        } else {
          final path = result.files.single.path;
          if (path == null) throw Exception("Caminho não encontrado");
          jsonString = await File(path).readAsString();
        }

        final Map<String, dynamic> data = json.decode(jsonString);
        data.forEach((key, value) {
          if (value is List) {
            List<Map<String, String>> tracks =
                (value).map((t) => Map<String, String>.from(t)).toList();
            provider.playlists[key] = tracks;
          }
        });
        provider.saveToPrefs();
        provider.notifyListeners();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: FluxApp.cardColor,
              foregroundColor: FluxApp.primaryTextColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.file_upload),
            label: const Text("Importar Playlist (.json)"),
            onPressed: () => _importJsonPlaylist(context, provider),
          ),
        ),
        const Divider(height: 1),
        if (provider.playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                "Nenhuma playlist ainda.\nImporte um .json para começar!",
                textAlign: TextAlign.center,
                style: TextStyle(color: FluxApp.secondaryTextColor),
              ),
            ),
          )
        else
          ...provider.playlists.keys.map((name) {
            final tracks = provider.playlists[name]!;
            // Busca a imagem da primeira música
            final String? imageUrl =
                tracks.isNotEmpty ? tracks[0]['album_image_url'] : null;

            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child:
                      (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (c, e, s) => const _LibraryPlaceholder(),
                          )
                          : const _LibraryPlaceholder(),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("${tracks.length} músicas"),
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
            );
          }),
      ],
    );
  }
}

class _LibraryPlaceholder extends StatelessWidget {
  const _LibraryPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: FluxApp.cardColor,
      child: const Icon(Icons.library_music, color: FluxApp.accentColor),
    );
  }
}
