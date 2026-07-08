import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Tracks listening history and generates personalized recommendations.
class ListeningHistoryService {

  /// Log a listening event to Supabase
  static Future<void> logListen(Map<String, String> track) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('listening_history').insert({
        'user_id': user.id,
        'track_name': track['track_name'] ?? '',
        'artist': track['artist'] ?? '',
        'album_image_url': track['album_image_url'] ?? '',
        'video_id': track['video_id'] ?? '',
        'listened_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("FLUX HISTORY: Error logging listen: $e");
    }
  }

  /// Get the user's top artists based on listening frequency
  static Future<List<Map<String, dynamic>>> getTopArtists({int limit = 20}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .rpc('get_top_artists', params: {
        'uid': user.id,
        'lim': limit,
      });
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint("FLUX HISTORY: Error fetching top artists: $e");
      return [];
    }
  }

  /// Get the user's top tracks based on listening frequency
  static Future<List<Map<String, dynamic>>> getTopTracks({int limit = 50}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .rpc('get_top_tracks', params: {
        'uid': user.id,
        'lim': limit,
      });
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint("FLUX HISTORY: Error fetching top tracks: $e");
      return [];
    }
  }

  /// Get what a friend is currently listening to (most recent listen within last 5 min)
  static Future<Map<String, dynamic>?> getFriendNowPlaying(String friendId) async {
    try {
      final response = await Supabase.instance.client
          .from('listening_history')
          .select()
          .eq('user_id', friendId)
          .order('listened_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final listenedAt = DateTime.tryParse(response['listened_at'] ?? '');
      if (listenedAt == null) return null;

      // Only return if listened within the last 5 minutes
      if (DateTime.now().difference(listenedAt).inMinutes <= 5) {
        return response;
      }
      return null;
    } catch (e) {
      debugPrint("FLUX HISTORY: Error fetching friend now playing: $e");
      return null;
    }
  }

  /// Broadcast current listening status for real-time friend activity
  static Future<void> broadcastNowPlaying(Map<String, String> track) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('now_playing').upsert({
        'user_id': user.id,
        'track_name': track['track_name'] ?? '',
        'artist': track['artist'] ?? '',
        'album_image_url': track['album_image_url'] ?? '',
        'video_id': track['video_id'] ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint("FLUX HISTORY: Error broadcasting now playing: $e");
    }
  }
}

/// AI-powered playlist generation
class AIPlaylistService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Generate a playlist from a natural language prompt by searching YouTube
  Future<List<Map<String, String>>> generateFromPrompt(String prompt, {int count = 25}) async {
    final List<Map<String, String>> results = [];

    try {
      // Generate diverse search queries from the prompt
      final queries = _expandPrompt(prompt);

      for (final query in queries) {
        if (results.length >= count) break;

        try {
          final searchResults = await _yt.search.search(query);
          for (final video in searchResults.whereType<Video>()) {
            if (results.length >= count) break;

            // Avoid duplicates
            final isDuplicate = results.any((r) =>
                r['video_id'] == video.id.value ||
                (r['track_name'] == video.title && r['artist'] == video.author));
            if (isDuplicate) continue;

            results.add({
              'track_name': video.title,
              'artist': video.author,
              'album_image_url': video.thumbnails.lowResUrl,
              'video_id': video.id.value,
            });
          }
        } catch (e) {
          debugPrint("FLUX AI: Search error for query '$query': $e");
        }
      }
    } catch (e) {
      debugPrint("FLUX AI: Error generating playlist: $e");
    }

    return results;
  }

  /// Generate smart daily mixes based on user's top artists
  Future<List<Map<String, String>>> generateDailyMix({
    required List<String> seedArtists,
    int count = 30,
  }) async {
    final List<Map<String, String>> results = [];

    for (final artist in seedArtists) {
      if (results.length >= count) break;

      try {
        final searchResults = await _yt.search.search('$artist music audio');
        for (final video in searchResults.whereType<Video>()) {
          if (results.length >= count) break;

          final isDuplicate = results.any((r) => r['video_id'] == video.id.value);
          if (isDuplicate) continue;

          results.add({
            'track_name': video.title,
            'artist': video.author,
            'album_image_url': video.thumbnails.lowResUrl,
            'video_id': video.id.value,
          });
        }
      } catch (e) {
        debugPrint("FLUX AI: Error generating daily mix for $artist: $e");
      }
    }

    // Shuffle to mix artists together
    results.shuffle();
    return results;
  }

  /// Expand a natural language prompt into multiple search queries
  List<String> _expandPrompt(String prompt) {
    final promptLower = prompt.toLowerCase();
    final queries = <String>[];

    // Direct search with the prompt
    queries.add('$prompt music playlist');
    queries.add('$prompt songs');
    queries.add('$prompt audio');

    // Mood-based expansions
    if (promptLower.contains('study') || promptLower.contains('focus') || promptLower.contains('estudar')) {
      queries.addAll([
        'lofi hip hop study beats',
        'calm instrumental study music',
        'ambient focus music',
      ]);
    }
    if (promptLower.contains('workout') || promptLower.contains('gym') || promptLower.contains('treino')) {
      queries.addAll([
        'workout motivation music',
        'gym pump up playlist',
        'high energy workout songs',
      ]);
    }
    if (promptLower.contains('chill') || promptLower.contains('relax') || promptLower.contains('relaxar')) {
      queries.addAll([
        'chill vibes music playlist',
        'relaxing ambient music',
        'calm acoustic playlist',
      ]);
    }
    if (promptLower.contains('party') || promptLower.contains('festa') || promptLower.contains('dance')) {
      queries.addAll([
        'party dance hits playlist',
        'club bangers 2024',
        'top party songs',
      ]);
    }
    if (promptLower.contains('sad') || promptLower.contains('triste') || promptLower.contains('melancholy')) {
      queries.addAll([
        'sad songs playlist',
        'melancholic indie music',
        'emotional songs 2024',
      ]);
    }
    if (promptLower.contains('happy') || promptLower.contains('alegre') || promptLower.contains('feel good')) {
      queries.addAll([
        'feel good songs playlist',
        'happy vibes music',
        'upbeat positive songs',
      ]);
    }
    if (promptLower.contains('sleep') || promptLower.contains('dormir') || promptLower.contains('lullaby')) {
      queries.addAll([
        'sleep music ambient',
        'calming sleep sounds',
        'gentle instrumental lullaby',
      ]);
    }
    if (promptLower.contains('road trip') || promptLower.contains('driving') || promptLower.contains('viagem')) {
      queries.addAll([
        'road trip playlist songs',
        'driving music mix',
        'highway songs classic',
      ]);
    }
    if (promptLower.contains('coffee') || promptLower.contains('café') || promptLower.contains('morning')) {
      queries.addAll([
        'coffee shop playlist',
        'morning vibes acoustic',
        'jazz cafe background music',
      ]);
    }
    if (promptLower.contains('rain') || promptLower.contains('chuva') || promptLower.contains('rainy')) {
      queries.addAll([
        'rainy day music playlist',
        'songs for rainy days',
        'cozy rain day indie',
      ]);
    }

    // Take up to 8 unique queries
    return queries.toSet().take(8).toList();
  }

  void dispose() {
    _yt.close();
  }
}
