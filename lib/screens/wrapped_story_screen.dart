import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/wrapped_share_card.dart';

class WrappedStoryScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  final String title;
  final String subtitle;

  const WrappedStoryScreen({
    Key? key,
    required this.stats,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  State<WrappedStoryScreen> createState() => _WrappedStoryScreenState();
}

class _WrappedStoryScreenState extends State<WrappedStoryScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      
      if (pngBytes == null) return;
      
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/flux_wrapped_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(imagePath);
      await file.writeAsBytes(pngBytes);
      
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: 'Confira meu ${widget.title} no Flux Music!',
      );
    } catch (e) {
      debugPrint("Error sharing: $e");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topTracks = widget.stats['top_tracks'] as List<dynamic>? ?? [];
    final topArtists = widget.stats['top_artists'] as List<dynamic>? ?? [];
    final totalMinutes = widget.stats['total_minutes'] ?? 0;
    
    final topArtist = topArtists.isNotEmpty ? topArtists[0]['artist'] : "Desconhecido";
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapUp: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 3) {
              _previousPage();
            } else {
              _nextPage();
            }
          },
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                children: [
                  // PAGE 1: Intro
                  _buildPage(
                    color1: Colors.blue.shade900,
                    color2: Colors.purple.shade900,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          "Pronto para ver o seu\n${widget.title}?",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  // PAGE 2: Top Artist
                  _buildPage(
                    color1: Colors.green.shade900,
                    color2: Colors.teal.shade900,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Você passou muito tempo ouvindo...",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 24, color: Colors.white70),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              topArtist,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "e passou mais de $totalMinutes minutos curtindo música no Flux.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // PAGE 3: Top Tracks
                  _buildPage(
                    color1: Colors.orange.shade900,
                    color2: Colors.red.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Suas músicas favoritas foram:",
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 32),
                          for (int i = 0; i < topTracks.length && i < 5; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                children: [
                                  Text("${i+1}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white54)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(topTracks[i]['track_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                        Text(topTracks[i]['artist'], style: const TextStyle(fontSize: 16, color: Colors.white70)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                  // PAGE 4: Share Card
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RepaintBoundary(
                          key: _globalKey,
                          child: WrappedShareCard(
                            stats: widget.stats,
                            title: widget.title,
                            subtitle: widget.subtitle,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isSharing)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton.icon(
                            onPressed: _shareImage,
                            icon: const Icon(Icons.share),
                            label: const Text("Compartilhar Histórico"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                      ],
                    ),
                  )
                ],
              ),
              
              // Close button
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              
              // Progress bars
              Positioned(
                top: 10,
                left: 10,
                right: 50,
                child: Row(
                  children: List.generate(
                    _totalPages,
                    (index) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 4,
                        decoration: BoxDecoration(
                          color: index <= _currentPage ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage({required Color color1, required Color color2, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color1, color2],
        ),
      ),
      child: child,
    );
  }
}
