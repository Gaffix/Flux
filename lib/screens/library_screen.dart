import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context);

    return ListView(
      children: provider.playlists.keys
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
                    builder: (context) => PlaylistDetailScreen(
                      playlistName: name,
                      tracks: provider.playlists[name]!,
                    ),
                  ),
                );
              },
            ),
          )
          .toList(),
    );
  }
}
