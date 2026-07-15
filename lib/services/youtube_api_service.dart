import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeApiService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<Map<String, String>>> fetchTrending() async {
    try {
      final searchResults = await _yt.search.search('Top Hits Music 2024 audio',
          filter: TypeFilters.video);
      return searchResults.whereType<Video>().map<Map<String, String>>((video) => <String, String>{
        "track_name": video.title,
        "artist": video.author,
        "album_image_url": video.thumbnails.lowResUrl,
        "video_id": video.id.value,
      }).toList();
    } catch (e) {
      print("Erro ao buscar trending: $e");
    }
    return [];
  }

  Future<List<Map<String, String>>> fetchByGenre(String genre) async {
    try {
      final searchResults = await _yt.search.search('$genre hits 2024 audio',
          filter: TypeFilters.video);
      return searchResults.whereType<Video>().map<Map<String, String>>((video) => <String, String>{
        "track_name": video.title,
        "artist": video.author,
        "album_image_url": video.thumbnails.lowResUrl,
        "video_id": video.id.value,
      }).toList();
    } catch (e) {
      print("Erro ao buscar gênero $genre: $e");
    }
    return [];
  }

  void dispose() {
    _yt.close();
  }
}
