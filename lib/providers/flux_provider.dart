import 'dart:convert';
import 'dart:collection';
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

  // --- DOWNLOAD QUEUE ---
  final Queue<Map<String, String>> _downloadQueue = Queue();
  final Set<String> _activeDownloads = {};
  final Map<String, ValueNotifier<double>> _progressNotifiers = {};
  final int _maxConcurrent = 3;
  final Map<String, String> _trackStatuses = {};

  ValueNotifier<double>? getProgress(String videoId) => _progressNotifiers[videoId];
  String getTrackStatus(String videoId) => _trackStatuses[videoId] ?? "NONE";

  // --- CORE STATE ---
  Map<String, String>? currentTrack;
  List<Map<String, String>> currentQueue = [];
  Map<String, List<Map<String, String>>> playlists = {"Favoritas": []};

  // --- RECENTLY PLAYED ---
  List<Map<String, String>> _recentlyPlayed = [];
  List<Map<String, String>> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);

  // --- PER-PLAYLIST SHUFFLE MODE ---
  Map<String, bool> _playlistShuffleMode = {};

  // --- CUSTOM PLAYLIST COVERS ---
  Map<String, String> _playlistCovers = {};

  bool _playerListenerRegistered = false;

  FluxProvider() {
    _loadFromPrefs();
    _loadBaseUrl();
    _loadPlaylistCovers();
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

  // --- RECENTLY PLAYED ---
  void _addToRecentlyPlayed(Map<String, String> track) {
    _recentlyPlayed.removeWhere(
      (t) =>
          t['track_name'] == track['track_name'] &&
          t['artist'] == track['artist'],
    );
    _recentlyPlayed.insert(0, Map<String, String>.from(track));
    if (_recentlyPlayed.length > 20) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 20);
    }
    _saveRecentlyPlayed();
    notifyListeners();
  }

  Future<void> _saveRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_recently_played', json.encode(_recentlyPlayed));
  }

  Future<void> _loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('flux_recently_played');
    if (savedData != null) {
      try {
        final List<dynamic> decoded = json.decode(savedData);
        _recentlyPlayed =
            decoded.map((item) => Map<String, String>.from(item)).toList();
      } catch (e) {
        debugPrint("Erro ao carregar recentes: $e");
      }
    }
  }

  // --- SHUFFLE MODE ---
  bool isPlaylistShuffled(String name) => _playlistShuffleMode[name] ?? true;

  void togglePlaylistShuffle(String name) {
    _playlistShuffleMode[name] = !isPlaylistShuffled(name);
    _saveShuffleMode();
    notifyListeners();
  }

  void setPlaylistShuffle(String name, bool shuffle) {
    _playlistShuffleMode[name] = shuffle;
    _saveShuffleMode();
    notifyListeners();
  }

  Future<void> _saveShuffleMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'flux_shuffle_mode', json.encode(_playlistShuffleMode));
  }

  Future<void> _loadShuffleMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('flux_shuffle_mode');
    if (savedData != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(savedData);
        _playlistShuffleMode =
            decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (e) {
        debugPrint("Erro ao carregar shuffle mode: $e");
      }
    }
  }

  // --- PLAYLIST COVERS ---
  String? getPlaylistCover(String playlistName) {
    // Custom cover first, then fall back to first track's album art
    if (_playlistCovers.containsKey(playlistName) && _playlistCovers[playlistName]!.isNotEmpty) {
      return _playlistCovers[playlistName];
    }
    // Fallback: first track's album art
    final tracks = playlists[playlistName];
    if (tracks != null && tracks.isNotEmpty) {
      final url = tracks.first['album_image_url'];
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  void setPlaylistCover(String playlistName, String imageUrl) {
    _playlistCovers[playlistName] = imageUrl;
    _savePlaylistCovers();
    notifyListeners();
  }

  void removePlaylistCover(String playlistName) {
    _playlistCovers.remove(playlistName);
    _savePlaylistCovers();
    notifyListeners();
  }

  Future<void> _savePlaylistCovers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_playlist_covers', json.encode(_playlistCovers));
  }

  Future<void> _loadPlaylistCovers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('flux_playlist_covers');
    if (savedData != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(savedData);
        _playlistCovers = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (e) {
        debugPrint("Erro ao carregar capas: $e");
      }
    }
  }

  // --- ARTIST HELPERS ---
  /// Returns all unique artists across all playlists, sorted by track count desc
  List<MapEntry<String, int>> getAllArtistsSorted() {
    Map<String, int> artistCount = {};
    for (var list in playlists.values) {
      for (var track in list) {
        String artist = track['artist'] ?? 'Desconhecido';
        artistCount[artist] = (artistCount[artist] ?? 0) + 1;
      }
    }
    var sorted = artistCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  /// Returns all unique tracks by a given artist across all playlists
  List<Map<String, String>> getTracksForArtist(String artist) {
    final Set<String> seen = {};
    final List<Map<String, String>> result = [];
    for (var list in playlists.values) {
      for (var track in list) {
        if (track['artist'] == artist) {
          final key = '${track['track_name']}||${track['artist']}';
          if (!seen.contains(key)) {
            seen.add(key);
            result.add(Map<String, String>.from(track));
          }
        }
      }
    }
    return result;
  }

  /// Returns the album image URL for the artist's most common track
  String? getArtistImageUrl(String artist) {
    for (var list in playlists.values) {
      for (var track in list) {
        if (track['artist'] == artist) {
          final url = track['album_image_url'];
          if (url != null && url.isNotEmpty) return url;
        }
      }
    }
    return null;
  }

  // --- PERSISTENCE ---
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_data', json.encode(playlists));
  }

  Future<void> enqueueDownload(Map<String, String> track) async {
    final videoId = await _resolveVideoId(track);
    if (videoId == null) return;

    if (await isTrackDownloaded(track)) {
      _trackStatuses[videoId] = "DOWNLOADED";
      notifyListeners();
      return;
    }

    if (_activeDownloads.contains(videoId) ||
        _downloadQueue.any((t) => t['video_id'] == videoId)) {
      return; // Já está na fila ou baixando
    }

    _trackStatuses[videoId] = "QUEUED";
    _downloadQueue.add(track);
    notifyListeners();
    _processNextDownload();
  }

  Future<void> _processNextDownload() async {
    if (_activeDownloads.length >= _maxConcurrent || _downloadQueue.isEmpty) {
      return;
    }

    final track = _downloadQueue.removeFirst();
    final videoId = track['video_id']!;

    _activeDownloads.add(videoId);
    _trackStatuses[videoId] = "DOWNLOADING";
    _progressNotifiers[videoId] = ValueNotifier(0.0);
    notifyListeners();

    try {
      await _executeDownload(track, videoId);
      _trackStatuses[videoId] = "DOWNLOADED";
    } catch (e) {
      _trackStatuses[videoId] = "NONE";
      debugPrint("Erro no download: $e");
    } finally {
      _activeDownloads.remove(videoId);
      _progressNotifiers[videoId]?.dispose();
      _progressNotifiers.remove(videoId);
      notifyListeners();
      _processNextDownload(); // Tenta o próximo da fila
    }
  }

  Future<void> _executeDownload(
      Map<String, String> track, String videoId) async {
    final savePath = await getDownloadedAudioPath(track);
    final file = File(savePath);

    final streamUrl = await _fetchStreamUrl(videoId);
    if (streamUrl == null) throw Exception("URL não encontrada");

    final request = http.Request('GET', Uri.parse(streamUrl));
    request.headers['ngrok-skip-browser-warning'] = 'true';

    final response = await http.Client().send(request);
    final total = response.contentLength ?? 0;
    int received = 0;

    final bytes = <int>[];
    await for (var chunk in response.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (total > 0) {
        _progressNotifiers[videoId]?.value = received / total;
      }
    }
    await file.writeAsBytes(bytes);
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
      } catch (e) {
        debugPrint("Erro ao carregar dados: $e");
      }
    }
    await _loadRecentlyPlayed();
    await _loadShuffleMode();
    notifyListeners();
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

    final safeTrackName = (track['track_name'] ?? 'track').replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '',
    );
    final safeArtist = (track['artist'] ?? 'artist').replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '',
    );

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

  void importPlaylistsData(Map<String, List<Map<String, String>>> data) {
    data.forEach((key, value) {
      playlists[key] = value;
    });
    saveToPrefs();
    notifyListeners();
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
      _playlistShuffleMode.remove(playlistName);
      _playlistCovers.remove(playlistName);
      _savePlaylistCovers();
      saveToPrefs();
      _saveShuffleMode();
      notifyListeners();
    }
  }

  void renamePlaylist(String oldName, String newName) {
    if (newName.isEmpty || playlists.containsKey(newName) || !playlists.containsKey(oldName)) return;
    playlists[newName] = List.from(playlists[oldName]!);
    playlists.remove(oldName);
    // Transfer shuffle mode
    if (_playlistShuffleMode.containsKey(oldName)) {
      _playlistShuffleMode[newName] = _playlistShuffleMode[oldName]!;
      _playlistShuffleMode.remove(oldName);
      _saveShuffleMode();
    }
    // Transfer cover
    if (_playlistCovers.containsKey(oldName)) {
      _playlistCovers[newName] = _playlistCovers[oldName]!;
      _playlistCovers.remove(oldName);
      _savePlaylistCovers();
    }
    saveToPrefs();
    notifyListeners();
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
    await enqueueDownload(track); // Apenas coloca na fila
    return true;
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
      final search = await yt.search.search(
        "${track['track_name']} ${track['artist']} audio",
      );
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
    _addToRecentlyPlayed(track);
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
    _addToRecentlyPlayed(track);
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

  void playPlaylist(List<Map<String, String>> tracks, {bool shuffle = false}) {
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
