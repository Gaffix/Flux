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

  Future<void> _renamePlaylist(
      BuildContext context, String oldName, FluxProvider provider) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Renomear Playlist"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Novo nome...",
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Salvar",
                style: TextStyle(color: FluxApp.accentColor)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      provider.renamePlaylist(oldName, newName);
    }
  }

  Future<String?> _showNameDialog(
      BuildContext context, String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Nome da Playlist"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Digite o nome aqui...",
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FluxApp.accentColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Importar"),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(
      BuildContext context, FluxProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nova Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nome da playlist...',
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createPlaylist(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Criar',
                style: TextStyle(color: FluxApp.accentColor)),
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
          final Map<String, List<Map<String, String>>> importData = {};
          decodedData.forEach((key, value) {
            if (value is List) {
              List<Map<String, String>> tracks = value.map((t) {
                final item = t as Map;
                return item.map(
                    (k, v) => MapEntry(k.toString(), v?.toString() ?? ""));
              }).toList();
              importData[key] = tracks;
            }
          });
          provider.importPlaylistsData(importData);
        } else if (decodedData is List) {
          final fileName = result.files.single.name.replaceAll('.json', '');
          final String? playlistName =
              await _showNameDialog(context, fileName);

          if (playlistName != null && playlistName.isNotEmpty) {
            List<Map<String, String>> tracks = decodedData.map((t) {
              final item = t as Map;
              return item.map(
                  (k, v) => MapEntry(k.toString(), v?.toString() ?? ""));
            }).toList();

            provider.importPlaylistsData({playlistName: tracks});
          } else {
            return;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro: $e"),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // --- ACTION BUTTONS ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_rounded,
                  label: "Criar Playlist",
                  onPressed: () =>
                      _showCreatePlaylistDialog(context, provider),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.file_upload_outlined,
                  label: "Importar JSON",
                  onPressed: () => _importJsonPlaylist(context, provider),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
              height: 1, color: Colors.white.withOpacity(0.06)),
        ),
        if (provider.playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.library_music_outlined,
                      size: 64,
                      color: FluxApp.secondaryTextColor.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    "Nenhuma playlist ainda.\nCrie uma nova ou importe um .json!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FluxApp.secondaryTextColor),
                  ),
                ],
              ),
            ),
          )
        else
          ...provider.playlists.keys.map((name) {
            final tracks = provider.playlists[name]!;
            final String? imageUrl = provider.getPlaylistCover(name);

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const _LibraryPlaceholder(),
                        )
                      : const _LibraryPlaceholder(),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                "${tracks.length} música${tracks.length != 1 ? 's' : ''}",
                style: const TextStyle(
                  color: FluxApp.secondaryTextColor,
                  fontSize: 13,
                ),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                color: const Color(0xFF1E1E2E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'rename') {
                    _renamePlaylist(context, name, provider);
                  } else if (value == 'delete') {
                    provider.deletePlaylist(name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Playlist '$name' apagada"),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined, size: 20),
                      title: Text('Renomear'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      title: Text('Apagar',
                          style: TextStyle(color: Colors.redAccent)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FluxApp.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: FluxApp.accentColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: FluxApp.primaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryPlaceholder extends StatelessWidget {
  const _LibraryPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FluxApp.cardColor,
            FluxApp.accentColor.withOpacity(0.15),
          ],
        ),
      ),
      child: const Icon(Icons.library_music_rounded,
          color: FluxApp.accentColor, size: 24),
    );
  }
}
