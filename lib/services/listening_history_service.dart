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
          .from('now_playing')
          .select()
          .eq('user_id', friendId)
          .maybeSingle();

      if (response == null) return null;

      // Supabase timestamps may lack the 'Z' suffix, causing DateTime.tryParse
      // to interpret them as local time. We ensure UTC by appending 'Z' if missing.
      String rawTimestamp = response['updated_at']?.toString() ?? '';
      if (rawTimestamp.isNotEmpty && !rawTimestamp.endsWith('Z') && !rawTimestamp.contains('+')) {
        rawTimestamp = '${rawTimestamp}Z';
      }
      final updatedAt = DateTime.tryParse(rawTimestamp);
      if (updatedAt == null) return null;

      // Only return if updated within the last 5 minutes
      if (DateTime.now().toUtc().difference(updatedAt.toUtc()).inMinutes <= 5) {
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint("FLUX HISTORY: Error broadcasting now playing: $e");
    }
  }

  /// Get wrapped stats for a specific date range
  static Future<Map<String, dynamic>?> getWrappedStats(DateTime start, DateTime end) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final response = await Supabase.instance.client
          .from('listening_history')
          .select()
          .eq('user_id', user.id)
          .gte('listened_at', start.toUtc().toIso8601String())
          .lte('listened_at', end.toUtc().toIso8601String());

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return null;

      final Map<String, int> trackCounts = {};
      final Map<String, int> artistCounts = {};
      final Map<String, Map<String, String>> trackDetails = {};

      for (var row in data) {
        final videoId = row['video_id']?.toString() ?? '';
        final artist = row['artist']?.toString() ?? 'Desconhecido';
        final trackName = row['track_name']?.toString() ?? 'Desconhecido';
        final albumImageUrl = row['album_image_url']?.toString() ?? '';

        if (videoId.isNotEmpty) {
          trackCounts[videoId] = (trackCounts[videoId] ?? 0) + 1;
          trackDetails[videoId] ??= {
            'track_name': trackName,
            'artist': artist,
            'album_image_url': albumImageUrl,
            'video_id': videoId,
          };
        }
        
        if (artist.isNotEmpty && artist != 'Desconhecido') {
          artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
        }
      }

      final sortedTracks = trackCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final sortedArtists = artistCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      final topTracks = sortedTracks.take(5).map((e) {
        final details = trackDetails[e.key]!;
        details['listen_count'] = e.value.toString();
        return details;
      }).toList();

      final topArtists = sortedArtists.take(5).map((e) {
        return {
          'artist': e.key,
          'listen_count': e.value.toString(),
        };
      }).toList();

      // Assuming average song length is 3.5 minutes
      final totalMinutes = (data.length * 3.5).toInt();

      return {
        'total_listens': data.length,
        'total_minutes': totalMinutes,
        'top_tracks': topTracks,
        'top_artists': topArtists,
      };
    } catch (e) {
      debugPrint("FLUX HISTORY: Error generating wrapped stats: $e");
      return null;
    }
  }
}
