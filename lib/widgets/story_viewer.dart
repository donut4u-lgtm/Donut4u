import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/post.dart';

/// Improved full-screen viewer:
/// - Progress bars at the top
/// - Auto-advance for stories
/// - Swipe left/right between multiple items
/// - Plays completely inside the app
class StoryViewer extends StatefulWidget {
  final Post post;
  final List<Post>? playlist;

  const StoryViewer({super.key, required this.post, this.playlist});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late List<Post> _items;
  late int _index;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  AnimationController? _progressController;
  bool _initialized = false;
  String? _error;
  bool _isStory = false;

  @override
  void initState() {
    super.initState();
    _items = widget.playlist?.isNotEmpty == true ? widget.playlist! : [widget.post];
    _index = _items.indexWhere((p) => p.id == widget.post.id);
    if (_index < 0) _index = 0;
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    setState(() {
      _initialized = false;
      _error = null;
    });
    _disposePlayers();

    final current = _items[_index];
    _isStory = current.type == PostType.story;
    final url = current.mediaUrl;

    if (url == null || url.isEmpty) {
      _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _next();
        });
      _progressController!.forward();
      setState(() => _initialized = true);
      return;
    }

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      final duration = _videoController!.value.duration;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        showControls: !_isStory,
        aspectRatio: _videoController!.value.aspectRatio,
      );

      if (_isStory) {
        _progressController = AnimationController(vsync: this, duration: duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _next();
          });
        _progressController!.forward();
      }

      setState(() => _initialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _next() {
    if (_index < _items.length - 1) {
      setState(() => _index++);
      _loadCurrent();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _loadCurrent();
    }
  }

  void _disposePlayers() {
    _progressController?.dispose();
    _progressController = null;
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposePlayers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final w = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < w * 0.3) {
            _prev();
          } else {
            _next();
          }
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -200) _next();
            if (details.primaryVelocity! > 200) _prev();
          }
        },
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.white70))
                  : !_initialized
                      ? const CircularProgressIndicator(color: Colors.white)
                      : _chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                current.body,
                                style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.4),
                                textAlign: TextAlign.center,
                              ),
                            ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: List.generate(_items.length, (i) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 3,
                            child: i == _index && _progressController != null
                                ? AnimatedBuilder(
                                    animation: _progressController!,
                                    builder: (_, __) => LinearProgressIndicator(
                                      value: _progressController!.value,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : LinearProgressIndicator(
                                    value: i < _index ? 1.0 : 0.0,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white24,
                          child: Text(
                            current.authorName.isNotEmpty ? current.authorName[0] : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.authorName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${current.topic} • IN-APP',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      current.body,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
