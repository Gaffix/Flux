import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FluxProvider extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  String _baseUrl = "";
  String get baseUrl => _baseUrl;

  Map<String, String>? currentTrack;
  List<Map<String, String>> currentQueue = [];
  Map<String, List<Map<String, String>>> playlists = {"Favoritas": []};

  bool _playerListenerRegistered = false;

  FluxProvider() {
    _loadFromPrefs();
    _loadBaseUrl();
    _registerPlayerListener();
  }

  void _registerPlayerListener() {
    if (_playerListenerRegistered) return;
    _playerListenerRegistered = true;
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipNext();
      }
    });
  }

  // --- PERSISTENCE ---
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_data', json.encode(playlists));
  }

  // --- IMPORT PLAYLIST ---
  Future<void> importPlaylistFromJson(
    String playlistName,
    List<dynamic> jsonList,
  ) async {
    if (!playlists.containsKey(playlistName)) {
      playlists[playlistName] = [];
    }

    for (var item in jsonList) {
      playlists[playlistName]!.add({
        "track_name": item["track_name"]?.toString() ?? "Unknown",
        "artist": item["artist"]?.toString() ?? "Unknown",
        "album_image_url": item["album_image_url"]?.toString() ?? "",
        "video_id": item["video_id"]?.toString() ?? "",
      });
    }

    await saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? "";
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString('server_url', _baseUrl);
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('flux_data');

    if (savedData != null) {
      try {
        Map<String, dynamic> decoded = json.decode(savedData);
        playlists = decoded.map((key, value) {
          return MapEntry(
            key,
            (value as List)
                .map((item) => Map<String, String>.from(item))
                .toList(),
          );
        });
        notifyListeners();
      } catch (e) {
        debugPrint("Erro ao carregar dados: $e");
      }
    }
  }

  // --- FILE SYSTEM PATHS (native only) ---
  Future<String> getDownloadedAudioPath(Map<String, String> track) async {
    if (kIsWeb) return "";

    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    directory ??= await getApplicationDocumentsDirectory();

    final safeTrackName = (track['track_name'] ?? 'track')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final safeArtist =
        (track['artist'] ?? 'artist').replaceAll(RegExp(r'[\\/:*?"<>|]'), '');

    return '${directory.path}/$safeTrackName - $safeArtist.mp3';
  }

  Future<bool> isTrackDownloaded(Map<String, String> track) async {
    if (kIsWeb) return false;
    final localPath = await getDownloadedAudioPath(track);
    return File(localPath).exists();
  }

  // --- PLAYLIST MANAGEMENT ---
  void createPlaylist(String name) {
    if (name.isNotEmpty && !playlists.containsKey(name)) {
      playlists[name] = [];
      saveToPrefs();
      notifyListeners();
    }
  }

  void addTrackToPlaylist(String playlistName, Map<String, String> track) {
    if (playlists.containsKey(playlistName)) {
      bool exists = playlists[playlistName]!.any(
        (m) =>
            m["track_name"] == track["track_name"] &&
            m["artist"] == track["artist"],
      );
      if (!exists) {
        playlists[playlistName]!.add(Map<String, String>.from(track));
        saveToPrefs();
        notifyListeners();
      }
    }
  }

  void removeFromPlaylist(String playlistName, Map<String, String> track) {
    if (playlists.containsKey(playlistName)) {
      playlists[playlistName]!.removeWhere(
        (m) =>
            m["track_name"] == track["track_name"] &&
            m["artist"] == track["artist"],
      );
      saveToPrefs();
      notifyListeners();
    }
  }

  void deletePlaylist(String playlistName) {
    if (playlists.containsKey(playlistName)) {
      playlists.remove(playlistName);
      saveToPrefs();
      notifyListeners();
    }
  }

  void addToPlaylist(String playlistName, Video video) {
    if (playlists.containsKey(playlistName)) {
      final musicData = {
        "track_name": video.title,
        "artist": video.author,
        "album_image_url": video.thumbnails.lowResUrl,
        "video_id": video.id.value,
      };

      bool exists = playlists[playlistName]!.any(
        (m) => m["video_id"] == video.id.value,
      );

      if (!exists) {
        playlists[playlistName]!.add(musicData);
        saveToPrefs();
        notifyListeners();
      }
    }
  }

  // --- DOWNLOAD LOGIC (native only) ---
  Future<bool> downloadTrack(Map<String, String> track) async {
    if (kIsWeb) return false;

    try {
      String? videoId = track['video_id'];

      if (videoId == null || videoId.isEmpty) {
        final yt = YoutubeExplode();
        final search = await yt.search
            .search("${track['track_name']} ${track['artist']} audio");
        if (search.isNotEmpty) {
          videoId = search.first.id.value;
          track['video_id'] = videoId;
        }
        yt.close();
      }

      if (videoId == null) return false;

      final savePath = await getDownloadedAudioPath(track);
      final file = File(savePath);

      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      if (await file.exists()) return true;

      final downloadUrl = "$_baseUrl/get_audio?id=$videoId";
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("FLUX Download Error: $e");
      return false;
    }
  }

  Future<void> downloadEntirePlaylist(String playlistName) async {
    if (kIsWeb) return;
    if (!playlists.containsKey(playlistName)) return;

    final tracks = List<Map<String, String>>.from(playlists[playlistName]!);
    final int total = tracks.length;
    int completed = 0;

    debugPrint("FLUX: Starting download of '$playlistName' ($total tracks)");

    const int batchSize = 5;

    for (int i = 0; i < total; i += batchSize) {
      final end = (i + batchSize < total) ? i + batchSize : total;
      final batch = tracks.sublist(i, end);

      await Future.wait(
        batch.map((track) async {
          await downloadTrack(track);
          completed++;
          debugPrint("FLUX: Download progress $completed/$total");
        }),
      );
    }

    debugPrint("FLUX: Download of '$playlistName' complete.");
  }

  // --- THE CORE PLAYBACK ENGINE ---

  Future<String?> _resolveVideoId(Map<String, String> track) async {
    String? videoId = track['video_id'];
    if (videoId != null && videoId.isNotEmpty) return videoId;

    debugPrint("FLUX: Missing video_id. Searching YouTube...");
    try {
      final yt = YoutubeExplode();
      final search = await yt.search
          .search("${track['track_name']} ${track['artist']} audio");
      if (search.isNotEmpty) {
        videoId = search.first.id.value;
        track['video_id'] = videoId;
      }
      yt.close();
    } catch (e) {
      debugPrint("FLUX: YouTube search error: $e");
    }
    return videoId;
  }

  Future<String?> _fetchStreamUrl(String videoId) async {
    if (_baseUrl.isEmpty) {
      debugPrint("FLUX: baseUrl not configured!");
      return null;
    }
    try {
      final url = "$_baseUrl/get_audio?id=$videoId";
      final response = await http.get(
        Uri.parse(url),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'] as String?;
      } else {
        debugPrint("FLUX: Server error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("FLUX: Error fetching stream URL: $e");
    }
    return null;
  }

  Future<void> _playFromQueueIndex(int index) async {
    if (index < 0 || index >= currentQueue.length) return;

    final track = currentQueue[index];
    currentTrack = track;
    notifyListeners();

    try {
      if (!kIsWeb) {
        final localPath = await getDownloadedAudioPath(track);
        if (await File(localPath).exists()) {
          debugPrint("FLUX: Playing local file.");
          await _setAndPlaySource(AudioSource.uri(Uri.file(localPath)));
          return;
        }
      }

      final videoId = await _resolveVideoId(track);
      if (videoId == null) {
        debugPrint("FLUX: Could not resolve video_id.");
        return;
      }

      final streamUrl = await _fetchStreamUrl(videoId);
      if (streamUrl != null) {
        await _setAndPlaySource(AudioSource.uri(Uri.parse(streamUrl)));
      }
    } catch (e) {
      debugPrint("FLUX ENGINE ERROR: $e");
    }
  }

  Future<void> _setAndPlaySource(AudioSource source) async {
    await player.stop();
    await player.setAudioSource(source);
    player.play();
  }

  Future<void> playTrack(
    Map<String, String> track, [
    String? serverStreamUrl,
  ]) async {
    currentTrack = track;
    notifyListeners();

    try {
      await player.stop();

      AudioSource? source;

      if (!kIsWeb) {
        final localPath = await getDownloadedAudioPath(track);
        if (await File(localPath).exists()) {
          source = AudioSource.uri(Uri.file(localPath));
        }
      }

      if (source == null && serverStreamUrl != null) {
        source = AudioSource.uri(Uri.parse(serverStreamUrl));
      }

      if (source == null) {
        final videoId = await _resolveVideoId(track);
        if (videoId != null) {
          final streamUrl = await _fetchStreamUrl(videoId);
          if (streamUrl != null) {
            source = AudioSource.uri(Uri.parse(streamUrl));
          }
        }
      }

      if (source == null) {
        debugPrint("FLUX: No audio source found for track.");
        return;
      }

      await player.setAudioSource(source);
      player.play();
    } catch (e) {
      debugPrint("FLUX: Error during playback: $e");
    }
  }

  void playPlaylist(
    List<Map<String, String>> tracks, {
    bool shuffle = false,
  }) {
    if (tracks.isEmpty) return;

    currentQueue = List.from(tracks);
    if (shuffle) currentQueue.shuffle();

    _playFromQueueIndex(0);
  }

  // --- QUEUE CONTROLS ---
  void skipNext() {
    if (currentTrack == null || currentQueue.isEmpty) return;
    int currentIndex = currentQueue.indexWhere(
      (t) =>
          t['track_name'] == currentTrack!['track_name'] &&
          t['artist'] == currentTrack!['artist'],
    );
    if (currentIndex != -1 && currentIndex < currentQueue.length - 1) {
      _playFromQueueIndex(currentIndex + 1);
    }
  }

  void skipPrevious() {
    if (currentTrack == null || currentQueue.isEmpty) return;
    int currentIndex = currentQueue.indexWhere(
      (t) =>
          t['track_name'] == currentTrack!['track_name'] &&
          t['artist'] == currentTrack!['artist'],
    );
    if (currentIndex > 0) {
      _playFromQueueIndex(currentIndex - 1);
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}