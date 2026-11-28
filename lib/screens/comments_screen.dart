import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class CommentsScreen extends StatefulWidget {
  final Post post;

  const CommentsScreen({super.key, required this.post});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _textCtrl = TextEditingController();
  final _data = DataService();
  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _data.fetchComments(widget.post.id);
    if (mounted) {
      setState(() {
        _comments = list;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first to comment.')),
      );
      return;
    }
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    final comment = Comment(
      id: const Uuid().v4(),
      postId: widget.post.id,
      userId: auth.userId ?? '',
      displayName: auth.displayName ?? 'User',
      text: text,
      createdAt: DateTime.now(),
    );
    await _data.addComment(comment);
    final error = _data.lastError;
    _textCtrl.clear();
    await _load();
    if (mounted) {
      setState(() => _sending = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment saved only on this phone. Reason: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.post.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.post.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet. Be the first!'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = _comments[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              child: Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?'),
                            ),
                            title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(c.text),
                            trailing: Text(
                              _timeAgo(c.createdAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}
