import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FluxProvider extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  String _baseUrl = "";
  String get baseUrl => _baseUrl;
  
  Map<String, String>? currentTrack;
  List<Map<String, String>> currentQueue = []; 
  Map<String, List<Map<String, String>>> playlists = {"Favoritas": []};

  FluxProvider() {
    _loadFromPrefs();
    _loadBaseUrl();
  }

  // --- PERSISTENCE ---
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_data', json.encode(playlists));
  }

  // --- IMPORT PLAYLIST ---
  Future<void> importPlaylistFromJson(String playlistName, List<dynamic> jsonList) async {
    // Cria a playlist se não existir
    if (!playlists.containsKey(playlistName)) {
      playlists[playlistName] = [];
    }

    // Injeta as músicas
    for (var item in jsonList) {
      playlists[playlistName]!.add({
        "track_name": item["track_name"]?.toString() ?? "Unknown",
        "artist": item["artist"]?.toString() ?? "Unknown",
        "album_image_url": item["album_image_url"]?.toString() ?? "",
        "video_id": item["video_id"]?.toString() ?? "", 
      });
    }
    
    // Salva e atualiza a UI
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
    _baseUrl = url;
    await prefs.setString('server_url', url);
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
            (value as List).map((item) => Map<String, String>.from(item)).toList(),
          );
        });
        notifyListeners();
      } catch (e) {
        debugPrint("Erro ao carregar dados: $e");
      }
    }
  }

// --- FILE SYSTEM PATHS ---
  Future<String> getDownloadedAudioPath(Map<String, String> track) async {
    Directory? directory;
    
    // Use external storage for Android (Android/data/...), fallback to documents for iOS
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory(); 
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    
    // Just in case getExternalStorageDirectory returns null on a weird device
    directory ??= await getApplicationDocumentsDirectory();

    final safeTrackName = track['track_name']!.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final safeArtist = track['artist']!.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    
    return '${directory.path}/$safeTrackName - $safeArtist.mp3';
  }

  // --- PLAYLIST MANAGEMENT ---
  void createPlaylist(String name) {
    if (name.isNotEmpty && !playlists.containsKey(name)) {
      playlists[name] = [];
      saveToPrefs();
      notifyListeners();
    }
  }

  // --- TRACK MANAGEMENT ---
  void addTrackToPlaylist(String playlistName, Map<String, String> track) {
    if (playlists.containsKey(playlistName)) {
      // Check if it already exists to prevent duplicates
      bool exists = playlists[playlistName]!.any((m) => m["track_name"] == track["track_name"] && m["artist"] == track["artist"]);
      if (!exists) {
        // Use Map.from to create a copy of the track object
        playlists[playlistName]!.add(Map<String, String>.from(track));
        saveToPrefs();
        notifyListeners();
      }
    }
  }

  void removeFromPlaylist(String playlistName, Map<String, String> track) {
    if (playlists.containsKey(playlistName)) {
      playlists[playlistName]!.removeWhere((m) => m["track_name"] == track["track_name"] && m["artist"] == track["artist"]);
      saveToPrefs();
      notifyListeners();
    }
  }


  // --- DOWNLOAD LOGIC ---
  Future<bool> downloadTrack(Map<String, String> track) async {
    try {
      String? videoId = track['video_id'];
      
      // If it's a Spotify import without an ID, search YouTube first
      if (videoId == null || videoId.isEmpty) {
        final yt = YoutubeExplode();
        final search = await yt.search.search("${track['track_name']} ${track['artist']} audio");
        if (search.isNotEmpty) {
          videoId = search.first.id.value;
          track['video_id'] = videoId; // Update the ID in memory
        }
        yt.close();
      }

      if (videoId == null) return false;

      final savePath = await getDownloadedAudioPath(track);
      final file = File(savePath);

      // Create the folder structure if it doesn't exist
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      // If already downloaded, return success immediately
      if (await file.exists()) return true;

      // Hit your new download server on port 9001
      final url = "http://10.0.28.126:9001/get_audio?id=$videoId";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Save the raw MP3 bytes to your Android/data/... folder
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("FLUX Download Error: $e");
      return false;
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

      bool exists = playlists[playlistName]!.any((m) => m["video_id"] == video.id.value);
      
      if (!exists) {
        playlists[playlistName]!.add(musicData);
        saveToPrefs();
        notifyListeners();
      }
    }
  }

  // --- THE CORE PLAYBACK ENGINE ---

  // 1. Unified Playback Logic (Search -> Server -> Player)
  Future<void> _playFromQueueIndex(int index) async {
    if (index < 0 || index >= currentQueue.length) return;
    
    final track = currentQueue[index];
    currentTrack = track;
    notifyListeners(); 

    try {
      // Step A: Check Local File First
      final localPath = await getDownloadedAudioPath(track);
      if (await File(localPath).exists()) {
        debugPrint("FLUX: Local file found. Playing offline.");
        playTrack(track); 
        return;
      }

      // Step B: Resolve YouTube ID if missing (Spotify imports)
      String? videoId = track['video_id'];
      if (videoId == null || videoId.isEmpty) {
        debugPrint("FLUX: Missing ID. Searching YouTube...");
        final yt = YoutubeExplode();
        final search = await yt.search.search("${track['track_name']} ${track['artist']} audio");
        if (search.isNotEmpty) {
          videoId = search.first.id.value;
        }
        yt.close();
      }

      // Step C: Fetch Stream URL from Server and Play
      if (videoId != null) {
        final response = await http.get(Uri.parse("http://10.0.28.126:9000/get_audio?id=$videoId"));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          playTrack(track, data['url']); 
        } else {
          debugPrint("FLUX: Server error ${response.statusCode}");
        }
      }
    } catch (e) {
      debugPrint("FLUX ENGINE ERROR: $e");
    }
  }

  // 2. Interaction with the just_audio Player
  void playTrack(Map<String, String> track, [String? serverStreamUrl]) async {
    currentTrack = track;
    notifyListeners();

    try {
      await player.stop();
      
      final localPath = await getDownloadedAudioPath(track);
      final file = File(localPath);

      AudioSource source;
      if (await file.exists()) {
        source = AudioSource.uri(Uri.file(localPath));
      } else if (serverStreamUrl != null) {
        source = AudioSource.uri(Uri.parse(serverStreamUrl));
      } else {
        debugPrint("FLUX: No source found for track.");
        return;
      }

      await player.setAudioSource(source);
      player.play();

      // Listen for song completion to trigger the next one
      player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          skipNext(); 
        }
      });

    } catch (e) {
      debugPrint("Error during playback: $e");
    }
  }

  // 3. Queue Controls
  void playPlaylist(List<Map<String, String>> tracks, {bool shuffle = false}) {
    if (tracks.isEmpty) return;

    currentQueue = List.from(tracks);
    if (shuffle) {
      currentQueue.shuffle();
    }

    _playFromQueueIndex(0);
  }

  // --- PLAYLIST ACTIONS ---
  
  void deletePlaylist(String playlistName) {
    if (playlists.containsKey(playlistName)) {
      playlists.remove(playlistName);
      saveToPrefs();
      notifyListeners();
    }
  }

// --- NOTIFICATION SETUP ---
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    
    // Uses your app's default launcher icon for the notification
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    // THE FIX IS HERE: Add "settings:" before initSettings
    await _notificationsPlugin.initialize(settings: initSettings);
    
    _notificationsInitialized = true;
  }

Future<void> _updateDownloadNotification(String playlistName, int current, int total) async {
    await _initNotifications();
    
    final int percentage = ((current / total) * 100).toInt();
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Mostra o progresso de download das playlists',
      importance: Importance.low, 
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: total,
      progress: current,
    );
    
    // THE FIX IS HERE: Added named parameters (id:, title:, body:, notificationDetails:)
    await _notificationsPlugin.show(
      id: 888, 
      title: 'Baixando: $playlistName',
      body: '$current de $total concluídas ($percentage%)',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _showCompletionNotification(String playlistName) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Mostra o progresso de download das playlists',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    
    // THE FIX IS HERE TOO: Added named parameters
    await _notificationsPlugin.show(
      id: 888, 
      title: 'Download Concluído!',
      body: 'Todas as músicas de "$playlistName" foram salvas.',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  // --- UPDATED CONCURRENT DOWNLOAD LOGIC ---
  Future<void> downloadEntirePlaylist(String playlistName) async {
    if (!playlists.containsKey(playlistName)) return;
    
    final tracks = List<Map<String, String>>.from(playlists[playlistName]!);
    final int total = tracks.length;
    int completed = 0;

    // Show initial notification
    await _updateDownloadNotification(playlistName, completed, total);

    // Process in batches of 5
    const int batchSize = 5;
    
    for (int i = 0; i < total; i += batchSize) {
      // Get the next 5 songs (or fewer if we're at the end of the list)
      final end = (i + batchSize < total) ? i + batchSize : total;
      final batch = tracks.sublist(i, end);
      
      // Future.wait runs all 5 downloads at the exact same time
      await Future.wait(batch.map((track) async {
        await downloadTrack(track);
        completed++;
        // Update the progress bar in the notification
        await _updateDownloadNotification(playlistName, completed, total);
      }));
    }
    
    // Change notification to "Finished" state
    await _showCompletionNotification(playlistName);
  }

  void skipNext() {
    if (currentTrack == null || currentQueue.isEmpty) return;
    int currentIndex = currentQueue.indexOf(currentTrack!);
    if (currentIndex != -1 && currentIndex < currentQueue.length - 1) {
      _playFromQueueIndex(currentIndex + 1);
    }
  }

  void skipPrevious() {
    if (currentTrack == null || currentQueue.isEmpty) return;
    int currentIndex = currentQueue.indexOf(currentTrack!);
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