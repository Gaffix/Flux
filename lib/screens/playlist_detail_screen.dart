import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/flux_provider.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistName;
  final List<Map<String, String>> tracks;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistName,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FluxProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        backgroundColor: Colors.transparent,
      ),
      body: tracks.isEmpty
          ? const Center(child: Text("Nenhuma mÃºsica nesta playlist"))
          : ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  leading: Image.network(
                    track['album_image_url'] ?? '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.music_note, size: 50),
                  ),
                  title: Text(
                    track['track_name'] ?? 'Desconhecido',
                    maxLines: 1,
                  ),
                  subtitle: Text(track['artist'] ?? ''),
                  onTap: () async {
                    String? videoId = track['video_id'];
                    if (videoId == null || videoId.isEmpty) return;

                    final serverUrl =
                        "${provider.baseUrl}/get_audio?id=$videoId";
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
                      debugPrint("Erro ao tocar: $e");
                    }
                  },
                );
              },
            ),
    );
  }
}
