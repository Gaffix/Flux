import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../main.dart';
import '../providers/flux_provider.dart';
import 'playlist_detail_screen.dart';

// dart:io só importado no nativo
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
        withData: true, // Necessário para web (lê bytes da memória)
      );

      if (result != null) {
        String jsonString;

        if (kIsWeb) {
          // Web: lê da memória (bytes)
          final bytes = result.files.single.bytes;
          if (bytes == null) {
            throw Exception("Não foi possível ler o arquivo no navegador.");
          }
          jsonString = utf8.decode(bytes);
        } else {
          // Mobile/Desktop: lê do sistema de arquivos
          final path = result.files.single.path;
          if (path == null) {
            throw Exception("Caminho do arquivo não encontrado.");
          }
          jsonString = await File(path).readAsString();
        }

        List<dynamic> data = json.decode(jsonString);
        String fileName = result.files.single.name;
        String playlistName = fileName.replaceAll(RegExp(r'\.json$'), '');

        await provider.importPlaylistFromJson(playlistName, data);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${data.length} músicas importadas para '$playlistName'!",
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Erro ao importar: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao importar: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: FluxApp.cardColor,
              foregroundColor: FluxApp.accentColor,
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
          ...provider.playlists.keys.map(
            (name) => ListTile(
              leading: const Icon(
                Icons.library_music,
                color: FluxApp.accentColor,
              ),
              title: Text(name),
              subtitle: Text("${provider.playlists[name]!.length} músicas"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PlaylistDetailScreen(
                          playlistName: name,
                          tracks: provider.playlists[name]!,
                        ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}