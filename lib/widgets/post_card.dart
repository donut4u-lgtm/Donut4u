import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../screens/article_screen.dart';
import '../screens/comments_screen.dart';

// Photos posted by users are saved inside the post (data:image/...;base64,...).
// Decode each one only once.
final Map<String, Uint8List> _photoCache = {};

Uint8List? _photoBytes(String url) {
  final cached = _photoCache[url];
  if (cached != null) return cached;
  try {
    final bytes = base64Decode(url.substring(url.indexOf(',') + 1));
    if (_photoCache.length > 40) _photoCache.clear();
    _photoCache[url] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTapStoryOrVideo;

  const PostCard({
    super.key,
    required this.post,
    this.onTapStoryOrVideo,
  });

  void _openArticle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMedia = post.type == PostType.story || post.type == PostType.video;
    final hasImage = post.type == PostType.image &&
        post.mediaUrl != null &&
        (post.mediaUrl!.startsWith('http') || post.mediaUrl!.startsWith('data:image'));
    final hasSource = post.sourceUrl != null && post.sourceUrl!.isNotEmpty;

    VoidCallback? onTap;
    if (isMedia) {
      onTap = onTapStoryOrVideo;
    } else if (hasSource) {
      onTap = () => _openArticle(context);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _colorForTopic(post.topic),
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '${post.topic} • ${_timeAgo(post.createdAt)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (isMedia)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: post.type == PostType.story ? Colors.purple.shade100 : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        post.type == PostType.story ? 'STORY' : 'VIDEO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: post.type == PostType.story ? Colors.purple.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(post.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(post.body, style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.35)),
              if (hasImage) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: post.mediaUrl!.startsWith('data:image')
                      ? _memoryPhoto(post.mediaUrl!)
                      : CachedNetworkImage(
                          imageUrl: post.mediaUrl!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (context, url, error) => const SizedBox.shrink(),
                        ),
                ),
              ],
              if (isMedia) ...[
                const SizedBox(height: 12),
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        post.type == PostType.story ? Icons.auto_stories : Icons.play_circle_fill,
                        size: 56,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      Positioned(
                        bottom: 8,
                        child: Text(
                          'Panoorin DITO sa app',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _action(Icons.favorite_border, '${post.likes}'),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CommentsScreen(post: post)),
                      );
                    },
                    child: _action(Icons.chat_bubble_outline, '${post.commentsCount}'),
                  ),
                  const Spacer(),
                  if (post.isUserPost)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('USER', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    )
                  else if (post.sourceName != null)
                    Flexible(
                      child: Text(
                        post.sourceName!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              if (hasSource && !isMedia) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openArticle(context),
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text('Basahin'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _memoryPhoto(String url) {
    final bytes = _photoBytes(url);
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(
      bytes,
      width: double.infinity,
      height: 180,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }

  Widget _action(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }

  Color _colorForTopic(String topic) {
    const colors = {
      'Viral': Colors.red,
      'Haha': Colors.orange,
      'Bago': Colors.teal,
      'Uso': Colors.indigo,
      'Balita': Colors.blueGrey,
      'Chika': Colors.purple,
      'Pagkain': Colors.deepOrange,
      'Libangan': Colors.pink,
      'Sports': Colors.green,
      'Tekno': Colors.cyan,
      'Pag-ibig': Colors.redAccent,
      'Lokal': Colors.brown,
    };
    return colors[topic] ?? Colors.grey;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}
