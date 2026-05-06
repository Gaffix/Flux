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

  Future<void> _renamePlaylist(BuildContext context, String oldName, FluxProvider provider) async {
  final controller = TextEditingController(text: oldName);
  final newName = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF242424),
      title: const Text("Renomear Playlist"),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: "Novo nome..."),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text("Salvar", style: TextStyle(color: Color(0xFF14B8A6))),
        ),
      ],
    ),
  );

  if (newName != null && newName.isNotEmpty && newName != oldName) {
    // Adiciona as músicas ao novo nome e remove o antigo
    provider.playlists[newName] = List.from(provider.playlists[oldName]!);
    provider.deletePlaylist(oldName); 
    provider.saveToPrefs();
    provider.notifyListeners();
  }
}

  // Função auxiliar para mostrar o diálogo de nome
  Future<String?> _showNameDialog(BuildContext context, String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nome da Playlist"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Digite o nome aqui..."),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Importar"),
          ),
        ],
      ),
    );
  }

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

        final dynamic decodedData = json.decode(jsonString);

        if (decodedData is Map<String, dynamic>) {
          // Se o JSON já tem chaves, importa todas
          decodedData.forEach((key, value) {
            if (value is List) {
              List<Map<String, String>> tracks = value.map((t) {
                final item = t as Map;
                return item.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ""));
              }).toList();
              provider.playlists[key] = tracks;
            }
          });
        } else if (decodedData is List) {
          // Se for uma lista, pergunta o nome ao usuário
          final fileName = result.files.single.name.replaceAll('.json', '');
          final String? playlistName = await _showNameDialog(context, fileName);

          // Se o usuário não cancelou o diálogo
          if (playlistName != null && playlistName.isNotEmpty) {
            List<Map<String, String>> tracks = decodedData.map((t) {
              final item = t as Map;
              return item.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ""));
            }).toList();

            provider.playlists[playlistName] = tracks;
          } else {
            return; // Usuário cancelou
          }
        }

        provider.saveToPrefs();
        provider.notifyListeners();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
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
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const _LibraryPlaceholder(),
                        )
                      : const _LibraryPlaceholder(),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("${tracks.length} músicas"),
              // --- INÍCIO DA MUDANÇA: BOTÃO DE TRÊS PONTOS ---
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                color: const Color(0xFF242424),
                onSelected: (value) {
                  if (value == 'rename') {
                    _renamePlaylist(context, name, provider);
                  } else if (value == 'delete') {
                    provider.deletePlaylist(name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Playlist '$name' apagada")),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit, size: 20),
                      title: Text('Renomear'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      title: Text('Apagar', style: TextStyle(color: Colors.redAccent)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              // --- FIM DA MUDANÇA ---
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaylistDetailScreen(
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
