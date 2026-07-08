import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import '../services/podcast_service.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _feedUrlController = TextEditingController();
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _feedUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addFeed() async {
    final url = _feedUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    final podcastService = Provider.of<PodcastService>(context, listen: false);
    final feed = await podcastService.subscribeFeed(url);
    setState(() => _isLoading = false);

    if (feed == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load podcast feed')),
      );
    } else {
      _feedUrlController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluxApp.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.podcasts_rounded, color: FluxApp.accentColor, size: 22),
            const SizedBox(width: 8),
            const Text(
              'PODCASTS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FluxApp.accentColor,
          labelColor: FluxApp.accentColor,
          unselectedLabelColor: FluxApp.secondaryTextColor,
          tabs: const [
            Tab(text: 'My Podcasts'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyPodcasts(),
          _buildDiscover(),
        ],
      ),
    );
  }

  Widget _buildMyPodcasts() {
    return Consumer<PodcastService>(
      builder: (context, podcastService, _) {
        final feeds = podcastService.subscribedFeeds;

        if (feeds.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.podcasts_rounded, size: 64, color: FluxApp.secondaryTextColor.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No podcasts yet',
                  style: GoogleFonts.inter(color: FluxApp.secondaryTextColor, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add an RSS feed URL to get started',
                  style: GoogleFonts.inter(color: FluxApp.secondaryTextColor.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: FluxApp.accentColor,
          onRefresh: () => podcastService.refreshAllFeeds(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: feeds.length,
            itemBuilder: (context, index) {
              final feed = feeds[index];
              return _PodcastFeedCard(
                feed: feed,
                onTap: () => _showEpisodes(feed),
                onUnsubscribe: () => podcastService.unsubscribeFeed(feed.feedUrl),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDiscover() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RSS URL input
          Container(
            decoration: BoxDecoration(
              color: FluxApp.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TextField(
              controller: _feedUrlController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Paste podcast RSS feed URL...',
                hintStyle: TextStyle(color: FluxApp.secondaryTextColor.withOpacity(0.5)),
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                border: InputBorder.none,
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: FluxApp.accentColor, strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: FluxApp.accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        ),
                        onPressed: _addFeed,
                      ),
              ),
              onSubmitted: (_) => _addFeed(),
            ),
          ),
          const SizedBox(height: 32),

          // Popular podcast suggestions
          Text(
            'POPULAR FEEDS',
            style: TextStyle(
              color: FluxApp.secondaryTextColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildPopularFeeds(),
        ],
      ),
    );
  }

  List<Widget> _buildPopularFeeds() {
    final suggestions = [
      {'name': 'Lex Fridman Podcast', 'url': 'https://lexfridman.com/feed/podcast/'},
      {'name': 'Joe Rogan Experience', 'url': 'http://joeroganexp.joerogan.libsynpro.com/rss'},
      {'name': 'TED Talks Daily', 'url': 'https://feeds.feedburner.com/TEDTalks_audio'},
      {'name': 'Huberman Lab', 'url': 'https://feeds.megaphone.fm/hubermanlab'},
    ];

    return suggestions.map((s) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: FluxApp.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.podcasts_rounded, color: FluxApp.accentColor, size: 22),
        ),
        title: Text(s['name']!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded, color: FluxApp.accentColor),
          onPressed: () {
            _feedUrlController.text = s['url']!;
            _addFeed();
          },
        ),
      );
    }).toList();
  }

  void _showEpisodes(PodcastFeed feed) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FluxApp.backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: FluxApp.secondaryTextColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 60, height: 60,
                          child: feed.imageUrl.isNotEmpty
                              ? Image.network(feed.imageUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _podcastPlaceholder())
                              : _podcastPlaceholder(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feed.title,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${feed.episodes.length} episodes',
                              style: TextStyle(color: FluxApp.secondaryTextColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withOpacity(0.06)),
                // Episodes list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: feed.episodes.length,
                    itemBuilder: (context, index) {
                      final ep = feed.episodes[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48, height: 48,
                            child: ep.imageUrl.isNotEmpty
                                ? Image.network(ep.imageUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _podcastPlaceholder())
                                : _podcastPlaceholder(),
                          ),
                        ),
                        title: Text(
                          ep.title,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            if (ep.duration.isNotEmpty) ...[
                              const Icon(Icons.access_time_rounded, size: 12, color: FluxApp.secondaryTextColor),
                              const SizedBox(width: 4),
                              Text(ep.duration, style: const TextStyle(fontSize: 12, color: FluxApp.secondaryTextColor)),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                ep.publishDate,
                                style: const TextStyle(fontSize: 11, color: FluxApp.secondaryTextColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          final provider = Provider.of<FluxProvider>(context, listen: false);
                          provider.playPlaylist([ep.toTrackMap()]);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _podcastPlaceholder() {
    return Container(
      color: FluxApp.cardColor,
      child: const Icon(Icons.podcasts_rounded, color: FluxApp.accentColor),
    );
  }
}

class _PodcastFeedCard extends StatelessWidget {
  final PodcastFeed feed;
  final VoidCallback onTap;
  final VoidCallback onUnsubscribe;

  const _PodcastFeedCard({
    required this.feed,
    required this.onTap,
    required this.onUnsubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: FluxApp.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64, height: 64,
                  child: feed.imageUrl.isNotEmpty
                      ? Image.network(feed.imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: FluxApp.accentColor.withOpacity(0.2),
                            child: const Icon(Icons.podcasts, color: FluxApp.accentColor),
                          ))
                      : Container(
                          color: FluxApp.accentColor.withOpacity(0.2),
                          child: const Icon(Icons.podcasts, color: FluxApp.accentColor),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feed.title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${feed.episodes.length} episodes',
                      style: const TextStyle(color: FluxApp.secondaryTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: onUnsubscribe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
