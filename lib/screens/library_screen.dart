import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; // Importe o file_picker
import '../main.dart';
import '../providers/flux_provider.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  // Nova função para abrir o explorador e ler o JSON
  Future<void> _importJsonPlaylist(BuildContext context, FluxProvider provider) async {
    try {
      // 1. Abre o explorador de arquivos focado em JSON
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // 2. Se o usuário escolheu um arquivo
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        // Lê o conteúdo do arquivo
        String jsonString = await file.readAsString();
        List<dynamic> data = json.decode(jsonString);

        // Pega o nome do arquivo e remove o ".json" para usar como nome da playlist
        String fileName = result.files.single.name;
        String playlistName = fileName.replaceAll(RegExp(r'\.json$'), '');

        // 3. Manda para o provider processar e salvar
        await provider.importPlaylistFromJson(playlistName, data);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${data.length} músicas importadas para '$playlistName'!")),
          );
        }
      }
    } catch (e) {
      debugPrint("Erro ao importar: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao importar arquivo JSON.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);
    return ListView(
      children: [
        // BOTÃO ATUALIZADO
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
        
        ...provider.playlists.keys
              .map(
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
              )
              .toList(),
    ],);
  }
}