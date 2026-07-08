import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../providers/flux_provider.dart';
import '../services/ai_playlist_service.dart';

class AIPlaylistScreen extends StatefulWidget {
  const AIPlaylistScreen({super.key});

  @override
  State<AIPlaylistScreen> createState() => _AIPlaylistScreenState();
}

class _AIPlaylistScreenState extends State<AIPlaylistScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  final AIPlaylistService _aiService = AIPlaylistService();
  List<Map<String, String>> _generatedTracks = [];
  bool _isGenerating = false;
  String? _currentPrompt;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const List<_PromptSuggestion> _suggestions = [
    _PromptSuggestion('☕', 'Studying in a rainy coffee shop'),
    _PromptSuggestion('🏋️', 'High energy gym workout'),
    _PromptSuggestion('🌙', 'Late night chill vibes'),
    _PromptSuggestion('🎉', 'Party dance hits'),
    _PromptSuggestion('🚗', 'Road trip adventure'),
    _PromptSuggestion('💔', 'Sad songs for a rainy day'),
    _PromptSuggestion('🌅', 'Morning feel good playlist'),
    _PromptSuggestion('🎵', 'Lo-fi beats to relax'),
    _PromptSuggestion('🌊', 'Beach sunset acoustic'),
    _PromptSuggestion('🔥', 'Brazilian funk and reggaeton'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _aiService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generatePlaylist(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
      _currentPrompt = prompt.trim();
      _generatedTracks = [];
    });
    _pulseController.repeat(reverse: true);

    try {
      final tracks = await _aiService.generateFromPrompt(prompt.trim());
      if (mounted) {
        setState(() {
          _generatedTracks = tracks;
          _isGenerating = false;
        });
        _pulseController.stop();
        _pulseController.reset();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _pulseController.stop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating playlist: $e')),
        );
      }
    }
  }

  void _saveAsPlaylist() {
    if (_generatedTracks.isEmpty || _currentPrompt == null) return;

    final provider = Provider.of<FluxProvider>(context, listen: false);
    final playlistName = '🤖 $_currentPrompt';

    provider.createPlaylist(playlistName);
    for (final track in _generatedTracks) {
      provider.addTrackToPlaylist(playlistName, track);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playlist "$playlistName" saved with ${_generatedTracks.length} tracks!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: FluxApp.accentColor,
      ),
    );
  }

  void _playAll() {
    if (_generatedTracks.isEmpty) return;
    final provider = Provider.of<FluxProvider>(context, listen: false);
    provider.playPlaylist(_generatedTracks, shuffle: false);
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
            Icon(Icons.auto_awesome_rounded, color: FluxApp.accentColor, size: 22),
            const SizedBox(width: 8),
            const Text(
              'AI PLAYLISTS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- Prompt Input ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FluxApp.accentColor.withOpacity(0.1),
                    FluxApp.cardColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FluxApp.accentColor.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _promptController,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Describe your perfect playlist...',
                  hintStyle: TextStyle(
                    color: FluxApp.secondaryTextColor.withOpacity(0.6),
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  border: InputBorder.none,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: _isGenerating
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: FluxApp.accentColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: FluxApp.accentColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            ),
                      onPressed: _isGenerating ? null : () => _generatePlaylist(_promptController.text),
                    ),
                  ),
                ),
                onSubmitted: _isGenerating ? null : _generatePlaylist,
              ),
            ),
          ),

          // --- Suggestions ---
          if (_generatedTracks.isEmpty && !_isGenerating)
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        '${s.emoji} ${s.text}',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      backgroundColor: FluxApp.cardColor,
                      side: BorderSide(color: Colors.white.withOpacity(0.08)),
                      onPressed: () {
                        _promptController.text = s.text;
                        _generatePlaylist(s.text);
                      },
                    ),
                  );
                },
              ),
            ),

          // --- Loading State ---
          if (_isGenerating)
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnim.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: FluxApp.accentColor, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Generating your playlist...',
                            style: GoogleFonts.inter(
                              color: FluxApp.secondaryTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '"${_currentPrompt ?? ""}"',
                            style: GoogleFonts.inter(
                              color: FluxApp.accentColor,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // --- Results ---
          if (_generatedTracks.isNotEmpty && !_isGenerating) ...[
            // Actions bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_generatedTracks.length} tracks generated',
                      style: GoogleFonts.inter(
                        color: FluxApp.secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _MiniActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play All',
                    filled: true,
                    onTap: _playAll,
                  ),
                  const SizedBox(width: 8),
                  _MiniActionButton(
                    icon: Icons.playlist_add_rounded,
                    label: 'Save',
                    filled: false,
                    onTap: _saveAsPlaylist,
                  ),
                ],
              ),
            ),
            // Track list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: _generatedTracks.length,
                itemBuilder: (context, index) {
                  final track = _generatedTracks[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: (track['album_image_url'] ?? '').isNotEmpty
                            ? Image.network(
                                track['album_image_url']!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: FluxApp.cardColor,
                                  child: const Icon(Icons.music_note, color: FluxApp.accentColor),
                                ),
                              )
                            : Container(
                                color: FluxApp.cardColor,
                                child: const Icon(Icons.music_note, color: FluxApp.accentColor),
                              ),
                      ),
                    ),
                    title: Text(
                      track['track_name'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track['artist'] ?? '',
                      style: const TextStyle(color: FluxApp.secondaryTextColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      final provider = Provider.of<FluxProvider>(context, listen: false);
                      provider.playPlaylist(_generatedTracks, shuffle: false);
                    },
                  );
                },
              ),
            ),
          ],

          // --- Empty state ---
          if (_generatedTracks.isEmpty && !_isGenerating)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 64, color: FluxApp.secondaryTextColor.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'Describe a vibe, mood, or scenario',
                      style: GoogleFonts.inter(
                        color: FluxApp.secondaryTextColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'and Flux AI will create your perfect playlist',
                      style: GoogleFonts.inter(
                        color: FluxApp.secondaryTextColor.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromptSuggestion {
  final String emoji;
  final String text;
  const _PromptSuggestion(this.emoji, this.text);
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? FluxApp.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(color: FluxApp.accentColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : FluxApp.accentColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : FluxApp.accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
