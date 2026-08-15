import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/listening_history_service.dart';
import '../services/equalizer_service.dart';

enum PlaybackRepeatMode { off, all, one }

class FluxProvider extends ChangeNotifier {
  late final AudioPlayer player;
  AndroidEqualizer? androidEqualizer;

  String baseUrl = "";

  // --- DOWNLOAD QUEUE ---
  final Queue<Map<String, String>> _downloadQueue = Queue();
  final Set<String> _activeDownloads = {};
  final Map<String, ValueNotifier<double>> _progressNotifiers = {};
  final int _maxConcurrent = 5;
  final Map<String, String> _trackStatuses = {};
  
  int _totalGlobalDownloads = 0;
  int _completedGlobalDownloads = 0;
  bool _isBatchQueueing = false;

  ValueNotifier<double>? getProgress(String videoId) => _progressNotifiers[videoId];
  String getTrackStatus(String videoId) => _trackStatuses[videoId] ?? "NONE";

  // --- SLEEP TIMER ---
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _stopAfterCurrentTrack = false;

  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;
  bool get isStoppingAfterCurrentTrack => _stopAfterCurrentTrack;

  void startSleepTimer(Duration duration, {bool stopAtEnd = false}) {
    _sleepTimer?.cancel();
    _stopAfterCurrentTrack = false;
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      if (stopAtEnd) {
        _stopAfterCurrentTrack = true;
      } else {
        player.stop();
        _sleepTimerEndTime = null;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _stopAfterCurrentTrack = false;
    notifyListeners();
  }

  // --- NOW PLAYING HEARTBEAT ---
  Timer? _nowPlayingHeartbeat;

  void _startHeartbeat() {
    _nowPlayingHeartbeat?.cancel();
    _nowPlayingHeartbeat = Timer.periodic(const Duration(minutes: 2), (_) {
      if (currentTrack != null && player.playing) {
        ListeningHistoryService.broadcastNowPlaying(currentTrack!);
      }
    });
  }

  void _stopHeartbeat() {
    _nowPlayingHeartbeat?.cancel();
    _nowPlayingHeartbeat = null;
  }

  // --- PLAYLISTS ---
  List<String> _collaborativePlaylists = [];
  List<String> get collaborativePlaylists => _collaborativePlaylists;

  // --- CORE STATE ---
  Map<String, String>? currentTrack;
  List<Map<String, String>> currentQueue = [];
  Map<String, List<Map<String, String>>> playlists = {"Favoritas": []};
  
  // --- USER PROFILE ---
  String username = "";
  String avatarUrl = "";
  bool isPublic = true;
  List<String> friends = [];
  
  // --- SETTINGS ---
  bool _showTrending = true;
  bool get showTrending => _showTrending;

  bool _crossfadeEnabled = false;
  bool get crossfadeEnabled => _crossfadeEnabled;

  String _audioQuality = 'normal';
  String get audioQuality => _audioQuality;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  double _playbackPitch = 1.0;
  double get playbackPitch => _playbackPitch;

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await player.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setPlaybackPitch(double pitch) async {
    _playbackPitch = pitch;
    await player.setPitch(pitch);
    notifyListeners();
  }
  
  Color dominantColor = const Color(0xFF1DB954);

  Future<void> _updatePalette(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      dominantColor = const Color(0xFF1DB954);
      notifyListeners();
      return;
    }
    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
      );
      dominantColor = palette.dominantColor?.color ?? palette.vibrantColor?.color ?? const Color(0xFF1DB954);
      notifyListeners();
    } catch (e) {
      dominantColor = const Color(0xFF1DB954);
      notifyListeners();
    }
  }

  // --- RECENTLY PLAYED ---
  List<Map<String, String>> _recentlyPlayed = [];
  List<Map<String, String>> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);

  // --- PER-PLAYLIST SHUFFLE MODE ---
  Map<String, bool> _playlistShuffleMode = {};

  // --- CUSTOM PLAYLIST COVERS ---
  Map<String, String> _playlistCovers = {};

  bool _playerListenerRegistered = false;
  EqualizerService? _eqService;

  void attachEqualizerService(EqualizerService eqService) {
    if (_eqService == eqService) return;
    
    _eqService?.removeListener(_applyEqualizerSettings);
    _eqService = eqService;
    _eqService?.addListener(_applyEqualizerSettings);
    
    _applyEqualizerSettings();
  }

  Future<void> _applyEqualizerSettings() async {
    if (androidEqualizer == null || _eqService == null) return;
    try {
      final parameters = await androidEqualizer!.parameters;
      await androidEqualizer!.setEnabled(_eqService!.isEnabled);
      
      final bands = _eqService!.currentBands;
      for (int i = 0; i < bands.length && i < parameters.bands.length; i++) {
        await parameters.bands[i].setGain(bands[i]);
      }
    } catch (e) {
      debugPrint("FLUX EQ ERROR: $e");
    }
  }

  FluxProvider() {
    if (!kIsWeb && Platform.isAndroid) {
      androidEqualizer = AndroidEqualizer();
      player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [androidEqualizer!]),
      );
    } else {
      player = AudioPlayer();
    }

    _loadFromPrefs();

    _loadPlaylistCovers();
    _registerPlayerListener();

    // Listen to playing state to manage heartbeat
    player.playingStream.listen((isPlaying) {
      if (isPlaying && currentTrack != null) {
        _startHeartbeat();
      } else {
        _stopHeartbeat();
      }
    });
  }

  bool _isFadingOutForCrossfade = false;

  void _registerPlayerListener() {
    if (_playerListenerRegistered) return;
    _playerListenerRegistered = true;
    
    player.positionStream.listen((pos) {
      if (player.duration != null && _crossfadeEnabled && player.playing) {
        final remaining = player.duration! - pos;
        if (remaining.inSeconds <= 4 && !_isFadingOutForCrossfade) {
          _isFadingOutForCrossfade = true;
          _performFadeOut(4); // fade out over 4 seconds
        }
      }
    });

    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_stopAfterCurrentTrack) {
          _stopAfterCurrentTrack = false;
          _sleepTimerEndTime = null;
          player.stop();
          notifyListeners();
          return;
        }

        if (_repeatMode != PlaybackRepeatMode.one) {
          skipNext();
        } else {
          player.seek(Duration.zero);
          player.play();
        }
      }
    });

    player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState == null || sequenceState.currentSource == null) return;
      
      final currentItem = sequenceState.currentSource!.tag as MediaItem?;
      if (currentItem != null) {
        debugPrint("FLUX EVENT: sequenceStateStream fired. Current Item from tag is: ${currentItem.title}");
        final newTrack = {
          'video_id': currentItem.id,
          'track_name': currentItem.title,
          'artist': currentItem.artist ?? 'Artista Desconhecido',
          'album_image_url': currentItem.artUri?.toString() ?? '',
        };

        final isSameTrack = currentTrack != null && 
                            currentTrack!['track_name'] == newTrack['track_name'] && 
                            currentTrack!['artist'] == newTrack['artist'];
        
        if (!isSameTrack) {
          debugPrint("FLUX EVENT: sequenceStateStream fired. Updating currentTrack to ${newTrack['track_name']}");
          
          // The notification is perfectly in sync because it uses the MediaItem tag.
          // We must use the exact same data to guarantee the UI is in sync.
          currentTrack = newTrack;
          _isFadingOutForCrossfade = false;
          
          if (_crossfadeEnabled) {
            _performFadeIn(3); // fade in over 3 seconds
          } else {
            player.setVolume(1.0);
          }
          
          final index = sequenceState.currentIndex;
          if (index != null && index >= 0 && index < currentQueue.length) {
             _preloadNextTracks(index);
          }
          
          _addToRecentlyPlayed(currentTrack!);
          _updatePalette(currentTrack!['album_image_url']);
          // Log listening history and broadcast to friends
          ListeningHistoryService.logListen(currentTrack!);
          ListeningHistoryService.broadcastNowPlaying(currentTrack!);
          notifyListeners();
        } else {
          // Apenas garanta que a UI atualize caso algo mais tenha mudado (ex: isPlaying state não pegou)
          notifyListeners();
        }
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

  // --- PINNED PLAYLISTS ---
  List<String> _pinnedPlaylists = [];
  bool isPinned(String name) => _pinnedPlaylists.contains(name);

  void togglePin(String name) {
    if (_pinnedPlaylists.contains(name)) {
      _pinnedPlaylists.remove(name);
    } else {
      _pinnedPlaylists.add(name);
    }
    _savePinnedPlaylists();
    notifyListeners();
  }

  Future<void> _savePinnedPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_pinned_playlists', json.encode(_pinnedPlaylists));
  }

  Future<void> _loadPinnedPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('flux_pinned_playlists');
    if (savedData != null) {
      try {
        final List<dynamic> decoded = json.decode(savedData);
        _pinnedPlaylists = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        debugPrint("Erro ao carregar pinned: \$e");
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
    final jsonString = json.encode(playlists);
    await prefs.setString('flux_data', jsonString);
    // Also persist social data locally for offline access
    await prefs.setString('flux_username', username);
    await prefs.setBool('flux_is_public', isPublic);
    await prefs.setString('flux_friends', json.encode(friends));
    await prefs.setString('flux_avatar_url', avatarUrl);
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('user_data').upsert({
          'user_id': user.id,
          'playlists_json': json.decode(jsonString),
          'username': username,
          'is_public': isPublic,
          'friends': friends,
          'avatar_url': avatarUrl,
        }, onConflict: 'user_id');
      } catch (e) {
        debugPrint("FLUX: Error syncing to Supabase: $e");
      }
    }
  }

  Future<void> enqueueDownload(Map<String, String> track) async {
    if (await isTrackDownloaded(track)) {
      String vid = track['video_id'] ?? '';
      if (vid.isNotEmpty) {
        _trackStatuses[vid] = "DOWNLOADED";
        notifyListeners();
      }
      return;
    }

    if (_downloadQueue.any((t) => t['track_name'] == track['track_name'] && t['artist'] == track['artist'])) {
      return; // Já está na fila
    }

    String videoId = track['video_id'] ?? '';
    if (videoId.isEmpty) {
      videoId = "pending_${track['track_name']}";
      track['video_id'] = videoId;
    }

    if (_activeDownloads.contains(videoId)) {
      return;
    }

    _trackStatuses[videoId] = "QUEUED";
    _downloadQueue.add(Map<String, String>.from(track));
    _totalGlobalDownloads++;
    
    if (_totalGlobalDownloads == 1) {
      _completedGlobalDownloads = 0;
      await _updateDownloadNotification('Preparando Download', 'Iniciando...', 0, 0);
    } else {
      await _updateDownloadNotification('Baixando Músicas', '$_completedGlobalDownloads de $_totalGlobalDownloads concluídas', _completedGlobalDownloads, _totalGlobalDownloads);
    }
    
    notifyListeners();
    _processNextDownload();
  }

  Future<void> _processNextDownload() async {
    if (_activeDownloads.length >= _maxConcurrent || _downloadQueue.isEmpty) {
      return;
    }

    final track = _downloadQueue.removeFirst();
    String videoId = track['video_id']!;

    if (videoId.startsWith("pending_")) {
      _activeDownloads.add(videoId);
      _trackStatuses[videoId] = "RESOLVING";
      notifyListeners();

      final realVideoId = await _resolveVideoId(track);
      
      _activeDownloads.remove(videoId);
      _trackStatuses.remove(videoId);

      if (realVideoId == null) {
        _completedGlobalDownloads++;
        _checkAndCompleteGlobalDownload();
        _processNextDownload();
        return;
      }
      
      videoId = realVideoId;
      track['video_id'] = videoId;
    }

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
      
      _completedGlobalDownloads++;
      
      await _checkAndCompleteGlobalDownload();
      
      notifyListeners();
      _processNextDownload(); // Tenta o próximo da fila
    }
  }

  Future<void> _checkAndCompleteGlobalDownload() async {
    if (_downloadQueue.isNotEmpty || _activeDownloads.isNotEmpty || _isBatchQueueing) {
      final percentage = _totalGlobalDownloads > 0 ? ((_completedGlobalDownloads / _totalGlobalDownloads) * 100).toInt() : 0;
      await _updateDownloadNotification(
        'Baixando Músicas', 
        '$_completedGlobalDownloads de $_totalGlobalDownloads concluídas ($percentage%)', 
        _completedGlobalDownloads, 
        _totalGlobalDownloads
      );
    } else {
      await _stopForegroundAndShowCompletion('Download Concluído', '$_completedGlobalDownloads músicas baixadas com sucesso.');
      _totalGlobalDownloads = 0;
      _completedGlobalDownloads = 0;
    }
  }

  Future<void> _executeDownload(
      Map<String, String> track, String videoId) async {
    final savePath = await getDownloadedAudioPath(track);
    final file = File(savePath);

    final yt = YoutubeExplode();
    Stream<List<int>> audioStream;
    int totalBytes = 0;

    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      audioStream = yt.videos.streamsClient.get(streamInfo);
      totalBytes = streamInfo.size.totalBytes;
    } catch (e) {
      debugPrint("FLUX: YoutubeExplode failed to get stream, trying backend: $e");
      
      // Fallback for backend
      final streamUrl = await _fetchStreamUrl(videoId);
      if (streamUrl == null) {
        yt.close();
        throw Exception("URL não encontrada no backend");
      }

      final request = http.Request('GET', Uri.parse(streamUrl));
      request.headers['ngrok-skip-browser-warning'] = 'true';

      final response = await http.Client().send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        yt.close();
        throw Exception("Falha no download. Status: ${response.statusCode}");
      }
      
      audioStream = response.stream;
      totalBytes = response.contentLength ?? 0;
    }

    final sink = file.openWrite();
    bool hasData = false;
    int received = 0;

    try {
      await for (var chunk in audioStream) {
        hasData = true;
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          _progressNotifiers[videoId]?.value = received / totalBytes;
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
      yt.close();
    }
    
    if (!hasData) {
      if (await file.exists()) await file.delete();
      throw Exception("Arquivo vazio (0 bytes).");
    }
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



  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // ── STEP 1: Load everything from local storage FIRST (instant, works offline) ──
    final String? localData = prefs.getString('flux_data');
    if (localData != null) {
      try {
        Map<String, dynamic> decoded = json.decode(localData);
        playlists = decoded.map((key, value) {
          return MapEntry(
            key,
            (value as List)
                .map((item) => Map<String, String>.from(item))
                .toList(),
          );
        });
      } catch (e) {
        debugPrint("Erro ao carregar dados locais: $e");
      }
    }

    // Load locally persisted social data
    username = prefs.getString('flux_username') ?? "Usuário";
    avatarUrl = prefs.getString('flux_avatar_url') ?? "";
    isPublic = prefs.getBool('flux_is_public') ?? true;
    final String? friendsJson = prefs.getString('flux_friends');
    if (friendsJson != null) {
      try {
        friends = List<String>.from(json.decode(friendsJson));
      } catch (_) {}
    }

    baseUrl = prefs.getString('flux_server_url') ?? "";
    _audioQuality = prefs.getString('flux_audio_quality') ?? 'normal';
    _showTrending = prefs.getBool('flux_show_trending') ?? true;
    _crossfadeEnabled = prefs.getBool('flux_crossfade_enabled') ?? false;
    _collaborativePlaylists = prefs.getStringList('flux_collaborative_playlists') ?? [];

    await _loadRecentlyPlayed();
    await _loadShuffleMode();
    await _loadPinnedPlaylists();
    notifyListeners(); // UI renders instantly with local data

    // ── STEP 2: Sync from Supabase in the background (if online) ──
    _syncFromSupabase(prefs);
  }

  Future<void> _syncFromSupabase(SharedPreferences prefs) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('user_data')
          .select('playlists_json, username, is_public, friends')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (response == null) return;

      bool hasChanges = false;

      if (response['playlists_json'] != null) {
        final cloudData = json.encode(response['playlists_json']);
        final localData = prefs.getString('flux_data');
        if (cloudData != localData) {
          await prefs.setString('flux_data', cloudData);
          try {
            Map<String, dynamic> decoded = json.decode(cloudData);
            playlists = decoded.map((key, value) {
              return MapEntry(
                key,
                (value as List)
                    .map((item) => Map<String, String>.from(item))
                    .toList(),
              );
            });
            hasChanges = true;
          } catch (e) {
            debugPrint("FLUX: Error parsing cloud playlists: $e");
          }
        }
      }

      final cloudUsername = response['username']?.toString() ?? "";
      if (cloudUsername.isNotEmpty && cloudUsername != username) {
        username = cloudUsername;
        await prefs.setString('flux_username', username);
        hasChanges = true;
      }

      final cloudIsPublic = response['is_public'] ?? false;
      if (cloudIsPublic != isPublic) {
        isPublic = cloudIsPublic;
        await prefs.setBool('flux_is_public', isPublic);
        hasChanges = true;
      }

      final friendsData = response['friends'];
      if (friendsData != null && friendsData is List) {
        final cloudFriends = List<String>.from(friendsData);
        if (cloudFriends.toString() != friends.toString()) {
          friends = cloudFriends;
          await prefs.setString('flux_friends', json.encode(friends));
          hasChanges = true;
        }
      }

      if (hasChanges) {
        debugPrint("FLUX: Synced new data from Supabase");
        notifyListeners();
      }
    } catch (e) {
      debugPrint("FLUX: Background Supabase sync failed (offline?): $e");
    }
  }

  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_audio_quality', quality);
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_server_url', url);
    notifyListeners();
  }

  Future<void> toggleShowTrending(bool value) async {
    _showTrending = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flux_show_trending', value);
    notifyListeners();
  }

  Future<void> toggleCrossfade(bool value) async {
    _crossfadeEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flux_crossfade_enabled', value);
    notifyListeners();
  }

  Future<void> updateUsername(String newUsername) async {
    username = newUsername;
    await saveToPrefs();
    notifyListeners();
  }

  Future<void> updateAvatarUrl(String newUrl) async {
    avatarUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_avatar_url', newUrl);
    await saveToPrefs();
    notifyListeners();
  }

  Future<void> toggleIsPublic(bool value) async {
    isPublic = value;
    await saveToPrefs();
    notifyListeners();
  }

  Future<void> toggleFriend(String friendId) async {
    if (friends.contains(friendId)) {
      friends.remove(friendId);
    } else {
      friends.add(friendId);
    }
    await saveToPrefs();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];
      final response = await Supabase.instance.client
          .rpc('search_users', params: {'query_text': query});
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error searching users: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getFriendData(String friendId) async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_friend_profile', params: {'friend_uid': friendId});
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint("Error getting friend data: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getFriendsList() async {
    if (friends.isEmpty) return [];
    try {
      final response = await Supabase.instance.client
          .rpc('get_friends_list', params: {'friend_ids': friends});
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching friends list: $e");
      return [];
    }
  }

  // --- FILE SYSTEM PATHS (native only) ---
  Future<String> getDownloadedAudioPath(Map<String, String> track) async {
    if (kIsWeb) return "";

    final safeTrackName = (track['track_name'] ?? 'track').replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '',
    );
    final safeArtist = (track['artist'] ?? 'artist').replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '',
    );
    final fileName = '$safeTrackName - $safeArtist.mp3';

    if (Platform.isAndroid) {
      bool hasPermission = await Permission.storage.isGranted || await Permission.audio.isGranted;
      if (!hasPermission) {
        try {
          await Permission.storage.request();
          await Permission.audio.request();
          hasPermission = await Permission.storage.isGranted || await Permission.audio.isGranted;
        } catch (e) {
          debugPrint("FLUX: Concurrent permission request ignored: $e");
        }
      }

      if (hasPermission) {
        final fluxDir = Directory('/storage/emulated/0/Music/Flux');
        if (!await fluxDir.exists()) {
          await fluxDir.create(recursive: true);
        }
        return '${fluxDir.path}/$fileName';
      }
    }

    // Fallback to internal app data if permissions are denied
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    directory ??= await getApplicationDocumentsDirectory();

    return '${directory.path}/$fileName';
  }

  Future<bool> isTrackDownloaded(Map<String, String> track) async {
    if (kIsWeb) return false;
    final localPath = await getDownloadedAudioPath(track);
    return File(localPath).exists();
  }

  Future<void> deleteDownloadedTrack(Map<String, String> track) async {
    if (kIsWeb) return;
    try {
      final localPath = await getDownloadedAudioPath(track);
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        final videoId = await _resolveVideoId(track);
        if (videoId != null) {
          _trackStatuses[videoId] = "NONE";
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error deleting track: $e");
    }
  }

  Future<String> calculateStorageSpace() async {
    if (kIsWeb) return "0 MB";
    int totalBytes = 0;
    
    // Check Music/Flux directory
    if (Platform.isAndroid) {
      final fluxDir = Directory('/storage/emulated/0/Music/Flux');
      if (await fluxDir.exists()) {
        await for (var file in fluxDir.list(recursive: true)) {
          if (file is File) totalBytes += await file.length();
        }
      }
    }
    
    // Check app docs directory
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    directory ??= await getApplicationDocumentsDirectory();
    
    if (await directory.exists()) {
      await for (var file in directory.list(recursive: true)) {
        if (file is File && file.path.endsWith('.mp3')) {
          totalBytes += await file.length();
        }
      }
    }

    if (totalBytes == 0) return "0 MB";
    return "${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  Future<void> clearAllDownloads() async {
    if (kIsWeb) return;
    
    if (Platform.isAndroid) {
      final fluxDir = Directory('/storage/emulated/0/Music/Flux');
      if (await fluxDir.exists()) {
        await for (var file in fluxDir.list(recursive: true)) {
          if (file is File) await file.delete();
        }
      }
    }
    
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    directory ??= await getApplicationDocumentsDirectory();
    
    if (await directory.exists()) {
      await for (var file in directory.list(recursive: true)) {
        if (file is File && file.path.endsWith('.mp3')) {
          await file.delete();
        }
      }
    }

    _trackStatuses.clear();
    notifyListeners();
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

  // --- NOTIFICATION SETUP ---
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);
    _notificationsInitialized = true;
  }

  Future<void> _updateDownloadNotification(String title, String body, int current, int total) async {
    await _initNotifications();
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Progresso de downloads',
      importance: Importance.low, 
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: total > 0,
      maxProgress: total > 0 ? total : 0,
      progress: current,
      ongoing: true, // Keep it from being swiped away
    );

    if (Platform.isAndroid) {
      // Run as Foreground Service to keep isolate alive
      await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.startForegroundService(
        id: 888, 
        title: title,
        body: body,
        notificationDetails: androidDetails,
        payload: 'download',
      );
    } else {
      await _notificationsPlugin.show(
        id: 888, 
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    }
  }

  Future<void> _stopForegroundAndShowCompletion(String title, String body) async {
    if (Platform.isAndroid) {
      await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.stopForegroundService();
    }
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Progresso de downloads',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    
    await _notificationsPlugin.show(
      id: 889, // Different ID so it doesn't overwrite the stopping foreground service instantly
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  // --- DOWNLOAD LOGIC (native only) ---

  Future<bool> downloadTrack(Map<String, String> track) async {
    if (kIsWeb) return false;
    await enqueueDownload(track);
    return true;
  }

  Future<void> downloadEntirePlaylist(String playlistName) async {
    if (kIsWeb) return;
    if (!playlists.containsKey(playlistName)) return;

    final tracks = List<Map<String, String>>.from(playlists[playlistName]!);
    final int total = tracks.length;

    debugPrint("FLUX: Starting download of '$playlistName' ($total tracks)");

    _isBatchQueueing = true;
    for (var track in tracks) {
      await enqueueDownload(track);
    }
    _isBatchQueueing = false;
    
    // Se todos os downloads já acabaram enquanto enfileirava
    if (_downloadQueue.isEmpty && _activeDownloads.isEmpty && _totalGlobalDownloads > 0) {
      await _stopForegroundAndShowCompletion('Download Concluído', '$_completedGlobalDownloads músicas baixadas com sucesso.');
      _totalGlobalDownloads = 0;
      _completedGlobalDownloads = 0;
      notifyListeners();
    }
    
    debugPrint("FLUX: All tracks from '$playlistName' queued.");
  }

  // --- THE CORE PLAYBACK ENGINE ---

  Future<String?> _resolveVideoId(Map<String, String> track) async {
    String? videoId = track['video_id'];
    if (videoId != null && videoId.isNotEmpty && !videoId.startsWith("pending_")) return videoId;

    debugPrint("FLUX: Missing video_id. Searching...");
    try {
      final yt = YoutubeExplode();
      final query = "${track['track_name']} ${track['artist']} audio";
      final searchResults = await yt.search.search(query);
      if (searchResults.isNotEmpty) {
        videoId = searchResults.first.id.value;
        track['video_id'] = videoId!;
        saveToPrefs();
      }
      yt.close();
      if (videoId != null) return videoId;
    } catch (e) {
      debugPrint("FLUX: YoutubeExplode search error: $e");
    }

    if (baseUrl.isNotEmpty) {
      try {
        final query = "${track['track_name']} ${track['artist']} audio";
        final searchUrl = "$baseUrl/search?q=${Uri.encodeComponent(query)}";
        final response = await http.get(
          Uri.parse(searchUrl),
          headers: {'ngrok-skip-browser-warning': 'true'},
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          videoId = data['video_id']?.toString();
          if (videoId != null) {
             track['video_id'] = videoId;
             saveToPrefs();
          }
        }
      } catch (e) {
        debugPrint("FLUX: Backend search error: $e");
      }
    }
    return videoId;
  }

  Future<String?> _fetchStreamUrl(String videoId) async {
    try {
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final url = streamInfo.url.toString();
      yt.close();
      return url;
    } catch (e) {
      debugPrint("FLUX: YoutubeExplode stream error: $e");
    }

    if (baseUrl.isNotEmpty) {
      try {
        final serverUrl = "$baseUrl/get_audio?id=$videoId&quality=$_audioQuality";
        final response = await http.get(
          Uri.parse(serverUrl),
          headers: {'ngrok-skip-browser-warning': 'true'},
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['url']?.toString();
        } else {
          debugPrint("FLUX: Server returned status code ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("FLUX: Error fetching from Python server: $e");
      }
    }
    
    return null;
  }

  ConcatenatingAudioSource? _queueSource;

  Future<void> _performFadeOut(int seconds) async {
    int steps = seconds * 10; // 10 steps per second
    double stepSize = 1.0 / steps;
    double currentVolume = player.volume;

    for (int i = 0; i < steps; i++) {
      if (!_isFadingOutForCrossfade) break;
      currentVolume -= stepSize;
      if (currentVolume < 0.0) currentVolume = 0.0;
      await player.setVolume(currentVolume);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _performFadeIn(int seconds) async {
    int steps = seconds * 10;
    double stepSize = 1.0 / steps;
    double currentVolume = 0.0;
    await player.setVolume(currentVolume);

    for (int i = 0; i < steps; i++) {
      if (_isFadingOutForCrossfade) break;
      currentVolume += stepSize;
      if (currentVolume > 1.0) currentVolume = 1.0;
      await player.setVolume(currentVolume);
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await player.setVolume(1.0); // Ensure it reaches max
  }

  Future<void> _playFromQueueIndex(int index) async {
    if (index < 0 || index >= currentQueue.length) return;

    final children = <AudioSource>[];
    for (var track in currentQueue) {
      children.add(FluxStreamAudioSource(track, this, tag: _createMediaItem(track)));
    }

    _queueSource = ConcatenatingAudioSource(children: children);

    currentTrack = currentQueue[index];
    _addToRecentlyPlayed(currentTrack!);
    _updatePalette(currentTrack!['album_image_url']);
    notifyListeners();

    try {
      await player.stop();
      await player.setAudioSource(_queueSource!, initialIndex: index);
      player.play();
    } catch (e) {
      debugPrint("FLUX ENGINE ERROR: $e");
    }

    _preloadNextTracks(index);
  }

  Future<void> _preloadNextTracks(int currentIndex) async {
    if (kIsWeb) return;
    
    // Pre-cache the next 2 tracks
    for (int i = 1; i <= 2; i++) {
      int nextIndex = currentIndex + i;
      if (nextIndex < currentQueue.length) {
        final track = currentQueue[nextIndex];
        
        if (await isTrackDownloaded(track)) continue;

        final videoId = await _resolveVideoId(track);
        if (videoId == null) continue;

        if (_activeDownloads.contains(videoId) || _trackStatuses[videoId] == "DOWNLOADED") continue;

        debugPrint("FLUX CACHE: Pre-caching next track: ${track['track_name']}");
        _activeDownloads.add(videoId);
        
        try {
          await _executeDownload(track, videoId);
          _trackStatuses[videoId] = "DOWNLOADED";
          debugPrint("FLUX CACHE: Pre-cached successfully: ${track['track_name']}");
        } catch (e) {
          debugPrint("FLUX CACHE: Pre-cache failed for ${track['track_name']}: $e");
        } finally {
          _activeDownloads.remove(videoId);
        }
      }
    }
  }

  // --- QUEUE MANAGEMENT ---
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= currentQueue.length) return;
    if (newIndex < 0 || newIndex > currentQueue.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Move in local list
    final track = currentQueue.removeAt(oldIndex);
    currentQueue.insert(newIndex, track);

    // Move in just_audio source
    if (_queueSource != null) {
      try {
        await _queueSource!.move(oldIndex, newIndex);
      } catch (e) {
        debugPrint("FLUX: Error moving track in queue source: $e");
      }
    }

    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= currentQueue.length) return;

    // Remove from local list
    currentQueue.removeAt(index);

    // Remove from just_audio source
    if (_queueSource != null) {
      try {
        await _queueSource!.removeAt(index);
      } catch (e) {
        debugPrint("FLUX: Error removing track from queue source: $e");
      }
    }

    notifyListeners();
  }

  Future<void> addToQueue(Map<String, String> track) async {
    currentQueue.add(Map<String, String>.from(track));

    if (_queueSource != null) {
      try {
        _queueSource!.add(FluxStreamAudioSource(track, this, tag: _createMediaItem(track)));
      } catch (e) {
        debugPrint("FLUX: Error adding track to queue source: $e");
      }
    }

    notifyListeners();
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
    int index = currentQueue.indexWhere((t) =>
        t['track_name'] == track['track_name'] &&
        t['artist'] == track['artist']);
    
    if (index == -1) {
      currentQueue.add(track);
      index = currentQueue.length - 1;
    }
    
    await _playFromQueueIndex(index);
  }

  void toggleCollaborativePlaylist(String name) async {
    if (_collaborativePlaylists.contains(name)) {
      _collaborativePlaylists.remove(name);
    } else {
      _collaborativePlaylists.add(name);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('flux_collaborative_playlists', _collaborativePlaylists);
    notifyListeners();
  }

  void playPlaylist(List<Map<String, String>> tracks, {bool shuffle = false}) {
    if (tracks.isEmpty) return;

    _originalQueue = List.from(tracks);
    currentQueue = List.from(tracks);
    _isShuffled = shuffle;
    if (shuffle) currentQueue.shuffle();

    _playFromQueueIndex(0);
  }

  // --- QUEUE CONTROLS ---
  
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  PlaybackRepeatMode get repeatMode => _repeatMode;

  bool _isShuffled = false;
  bool get isShuffled => _isShuffled;
  List<Map<String, String>> _originalQueue = [];

  void toggleRepeatMode() {
    if (_repeatMode == PlaybackRepeatMode.off) {
      _repeatMode = PlaybackRepeatMode.all;
      player.setLoopMode(LoopMode.off); // We handle 'all' manually
    } else if (_repeatMode == PlaybackRepeatMode.all) {
      _repeatMode = PlaybackRepeatMode.one;
      player.setLoopMode(LoopMode.one); // just_audio loops the current source
    } else {
      _repeatMode = PlaybackRepeatMode.off;
      player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      _originalQueue = List.from(currentQueue);
      if (currentTrack != null) {
        currentQueue.removeWhere((t) => t['track_name'] == currentTrack!['track_name'] && t['artist'] == currentTrack!['artist']);
        currentQueue.shuffle();
        currentQueue.insert(0, currentTrack!);
      } else {
        currentQueue.shuffle();
      }
    } else {
      currentQueue = List.from(_originalQueue);
    }
    notifyListeners();
  }


  bool isFavorite(Map<String, String> track) {
    if (!playlists.containsKey("Favoritas")) return false;
    return playlists["Favoritas"]!.any((t) => t['track_name'] == track['track_name'] && t['artist'] == track['artist']);
  }

  void toggleFavorite(Map<String, String> track) {
    if (!playlists.containsKey("Favoritas")) {
      createPlaylist("Favoritas");
    }
    if (isFavorite(track)) {
      removeFromPlaylist("Favoritas", track);
    } else {
      addTrackToPlaylist("Favoritas", track);
    }
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> skipPrevious() async {
    if (player.position.inSeconds > 3) {
      player.seek(Duration.zero);
      return;
    }
    if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      player.seek(Duration.zero);
    }
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      final currentVol = player.volume;
      const int steps = 10;
      for (int i = 1; i <= steps; i++) {
        await Future.delayed(const Duration(milliseconds: 30));
        await player.setVolume(currentVol * (1 - (i / steps)));
      }
      await player.pause();
      await player.setVolume(currentVol);
    } else {
      player.play();
    }
  }


  @override
  void dispose() {
    _nowPlayingHeartbeat?.cancel();
    _sleepTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  MediaItem _createMediaItem(Map<String, String> track) {
    return MediaItem(
      id: track['video_id'] ?? track['track_name'] ?? 'unknown',
      title: track['track_name'] ?? 'Unknown Track',
      artist: track['artist'] ?? 'Unknown Artist',
      artUri: (track['album_image_url'] != null && track['album_image_url']!.isNotEmpty) 
          ? Uri.parse(track['album_image_url']!) 
          : null,
    );
  }
}

class FluxStreamAudioSource extends StreamAudioSource {
  final Map<String, String> track;
  final FluxProvider provider;

  FluxStreamAudioSource(this.track, this.provider, {super.tag});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (!kIsWeb) {
      final localPath = await provider.getDownloadedAudioPath(track);
      if (await File(localPath).exists()) {
        final file = File(localPath);
        final length = await file.length();
        final effectiveStart = start ?? 0;
        final effectiveEnd = end ?? (length - 1);
        final stream = file.openRead(effectiveStart, effectiveEnd + 1);
        return StreamAudioResponse(
          sourceLength: length,
          contentLength: effectiveEnd - effectiveStart + 1,
          offset: effectiveStart,
          stream: stream,
          contentType: 'audio/mpeg',
        );
      }
    }

    final videoId = await provider._resolveVideoId(track);
    if (videoId == null) throw Exception("Could not resolve video_id");
    final streamUrl = await provider._fetchStreamUrl(videoId);
    if (streamUrl == null) throw Exception("Could not fetch stream_url");

    final request = http.Request('GET', Uri.parse(streamUrl));
    if (start != null || end != null) {
      request.headers['Range'] = 'bytes=${start ?? 0}-${end ?? ''}';
    }
    request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';
    request.headers['ngrok-skip-browser-warning'] = 'true';

    final response = await http.Client().send(request);
    return StreamAudioResponse(
      sourceLength: response.contentLength,
      contentLength: response.contentLength,
      offset: start ?? 0,
      stream: response.stream,
      contentType: response.headers['content-type'] ?? 'audio/mpeg',
    );
  }
}
