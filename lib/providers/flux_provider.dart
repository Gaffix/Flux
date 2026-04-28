import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FluxProvider extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  String _baseUrl = "";
  String get baseUrl => _baseUrl;

  Map<String, List<Map<String, String>>> playlists = {"Favoritas": []};

  FluxProvider() {
    _loadFromPrefs();
    _loadBaseUrl();
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flux_data', json.encode(playlists));
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

  void addTrackToPlaylist(String playlistName, Map<String, String> track) {
    if (playlists.containsKey(playlistName)) {
      playlists[playlistName]!.add(Map<String, String>.from(track));
      saveToPrefs();
      notifyListeners();
    }
  }

  void playTrack(String streamUrl) async {
    try {
      await player.stop();
      await player.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
      player.play();
    } catch (e) {
      debugPrint("Erro ao tocar mÃºsica: $e");
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
