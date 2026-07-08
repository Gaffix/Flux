import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single podcast episode.
class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final String imageUrl;
  final String publishDate;
  final String duration;
  final String podcastName;

  PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.imageUrl,
    required this.publishDate,
    required this.duration,
    required this.podcastName,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'audioUrl': audioUrl,
    'imageUrl': imageUrl,
    'publishDate': publishDate,
    'duration': duration,
    'podcastName': podcastName,
  };

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) => PodcastEpisode(
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    audioUrl: json['audioUrl'] ?? '',
    imageUrl: json['imageUrl'] ?? '',
    publishDate: json['publishDate'] ?? '',
    duration: json['duration'] ?? '',
    podcastName: json['podcastName'] ?? '',
  );

  /// Convert to a track map compatible with FluxProvider
  Map<String, String> toTrackMap() => {
    'track_name': title,
    'artist': podcastName,
    'album_image_url': imageUrl,
    'video_id': '',
    'stream_url': audioUrl,
    'is_podcast': 'true',
  };
}

/// Represents a subscribed podcast feed.
class PodcastFeed {
  final String title;
  final String description;
  final String imageUrl;
  final String feedUrl;
  final List<PodcastEpisode> episodes;

  PodcastFeed({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.feedUrl,
    this.episodes = const [],
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'feedUrl': feedUrl,
    'episodes': episodes.map((e) => e.toJson()).toList(),
  };

  factory PodcastFeed.fromJson(Map<String, dynamic> json) => PodcastFeed(
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    imageUrl: json['imageUrl'] ?? '',
    feedUrl: json['feedUrl'] ?? '',
    episodes: (json['episodes'] as List?)
        ?.map((e) => PodcastEpisode.fromJson(e))
        .toList() ?? [],
  );
}

/// Service for managing podcast subscriptions and RSS feed parsing.
class PodcastService extends ChangeNotifier {
  List<PodcastFeed> _subscribedFeeds = [];
  Map<String, Duration> _episodePositions = {}; // Remember playback positions

  List<PodcastFeed> get subscribedFeeds => List.unmodifiable(_subscribedFeeds);

  // --- Playback settings ---
  double _playbackSpeed = 1.0;
  bool _skipSilence = false;

  double get playbackSpeed => _playbackSpeed;
  bool get skipSilence => _skipSilence;

  PodcastService() {
    _loadData();
  }

  /// Set playback speed (0.5x to 3.0x)
  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.5, 3.0);
    _saveData();
    notifyListeners();
  }

  void toggleSkipSilence() {
    _skipSilence = !_skipSilence;
    _saveData();
    notifyListeners();
  }

  /// Subscribe to a podcast RSS feed
  Future<PodcastFeed?> subscribeFeed(String feedUrl) async {
    try {
      // Check if already subscribed
      if (_subscribedFeeds.any((f) => f.feedUrl == feedUrl)) {
        return _subscribedFeeds.firstWhere((f) => f.feedUrl == feedUrl);
      }

      final feed = await _parseFeed(feedUrl);
      if (feed != null) {
        _subscribedFeeds.add(feed);
        _saveData();
        notifyListeners();
        return feed;
      }
    } catch (e) {
      debugPrint("FLUX PODCAST: Error subscribing to feed: $e");
    }
    return null;
  }

  /// Unsubscribe from a feed
  void unsubscribeFeed(String feedUrl) {
    _subscribedFeeds.removeWhere((f) => f.feedUrl == feedUrl);
    _saveData();
    notifyListeners();
  }

  /// Refresh all subscribed feeds
  Future<void> refreshAllFeeds() async {
    for (int i = 0; i < _subscribedFeeds.length; i++) {
      try {
        final updated = await _parseFeed(_subscribedFeeds[i].feedUrl);
        if (updated != null) {
          _subscribedFeeds[i] = updated;
        }
      } catch (e) {
        debugPrint("FLUX PODCAST: Error refreshing feed: $e");
      }
    }
    _saveData();
    notifyListeners();
  }

  /// Save and restore playback positions for episodes
  Duration getEpisodePosition(String episodeTitle) {
    return _episodePositions[episodeTitle] ?? Duration.zero;
  }

  void saveEpisodePosition(String episodeTitle, Duration position) {
    _episodePositions[episodeTitle] = position;
    _saveData();
  }

  /// Parse an RSS feed URL into a PodcastFeed
  Future<PodcastFeed?> _parseFeed(String feedUrl) async {
    try {
      final response = await http.get(Uri.parse(feedUrl));
      if (response.statusCode != 200) return null;

      final body = response.body;

      // Simple XML parsing for RSS feeds
      final title = _extractXmlTag(body, 'title') ?? 'Unknown Podcast';
      final description = _extractXmlTag(body, 'description') ?? '';
      final imageUrl = _extractItunesImage(body) ?? '';

      // Parse episodes
      final episodes = <PodcastEpisode>[];
      final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
      final matches = itemRegex.allMatches(body);

      for (final match in matches) {
        final itemContent = match.group(1) ?? '';
        final epTitle = _extractXmlTag(itemContent, 'title') ?? '';
        final epDescription = _extractXmlTag(itemContent, 'description') ?? '';
        final pubDate = _extractXmlTag(itemContent, 'pubDate') ?? '';
        final duration = _extractXmlTag(itemContent, 'itunes:duration') ?? '';
        final audioUrl = _extractEnclosureUrl(itemContent) ?? '';
        final epImage = _extractItunesImage(itemContent) ?? imageUrl;

        if (audioUrl.isNotEmpty) {
          episodes.add(PodcastEpisode(
            title: _cleanHtml(epTitle),
            description: _cleanHtml(epDescription),
            audioUrl: audioUrl,
            imageUrl: epImage,
            publishDate: pubDate,
            duration: duration,
            podcastName: _cleanHtml(title),
          ));
        }
      }

      return PodcastFeed(
        title: _cleanHtml(title),
        description: _cleanHtml(description),
        imageUrl: imageUrl,
        feedUrl: feedUrl,
        episodes: episodes,
      );
    } catch (e) {
      debugPrint("FLUX PODCAST: Error parsing feed $feedUrl: $e");
      return null;
    }
  }

  String? _extractXmlTag(String xml, String tag) {
    // Handle CDATA
    final cdataRegex = RegExp('<$tag[^>]*>\\s*<!\\[CDATA\\[(.*?)\\]\\]>\\s*</$tag>', dotAll: true);
    final cdataMatch = cdataRegex.firstMatch(xml);
    if (cdataMatch != null) return cdataMatch.group(1);

    final regex = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true);
    final match = regex.firstMatch(xml);
    return match?.group(1);
  }

  String? _extractEnclosureUrl(String xml) {
    final regex = RegExp(r'<enclosure[^>]+url="([^"]+)"', dotAll: true);
    final match = regex.firstMatch(xml);
    return match?.group(1);
  }

  String? _extractItunesImage(String xml) {
    final regex = RegExp(r'<itunes:image[^>]+href="([^"]+)"', dotAll: true);
    final match = regex.firstMatch(xml);
    return match?.group(1);
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  // --- Persistence ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'flux_podcast_feeds',
      json.encode(_subscribedFeeds.map((f) => f.toJson()).toList()),
    );
    await prefs.setDouble('flux_podcast_speed', _playbackSpeed);
    await prefs.setBool('flux_podcast_skip_silence', _skipSilence);

    final positionMap = _episodePositions.map(
      (k, v) => MapEntry(k, v.inMilliseconds),
    );
    await prefs.setString('flux_podcast_positions', json.encode(positionMap));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    _playbackSpeed = prefs.getDouble('flux_podcast_speed') ?? 1.0;
    _skipSilence = prefs.getBool('flux_podcast_skip_silence') ?? false;

    final feedsJson = prefs.getString('flux_podcast_feeds');
    if (feedsJson != null) {
      try {
        final decoded = json.decode(feedsJson) as List;
        _subscribedFeeds = decoded.map((e) => PodcastFeed.fromJson(e)).toList();
      } catch (_) {}
    }

    final positionsJson = prefs.getString('flux_podcast_positions');
    if (positionsJson != null) {
      try {
        final decoded = json.decode(positionsJson) as Map<String, dynamic>;
        _episodePositions = decoded.map(
          (k, v) => MapEntry(k, Duration(milliseconds: (v as num).toInt())),
        );
      } catch (_) {}
    }

    notifyListeners();
  }
}
