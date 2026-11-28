import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/topic.dart';
import '../models/post.dart';
import '../services/feed_service.dart';
import '../services/auth_service.dart';
import '../widgets/post_card.dart';
import '../widgets/story_viewer.dart';
import 'create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kTopics.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final i = _tabController.index;
    final id = kTopics[i].id;
    final feed = context.read<FeedService>();
    if (feed.currentTopicId != id) feed.setTopic(id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _showLoginDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isNew = false;
    bool busy = false;
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isNew ? 'Create account' : 'Sign in'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 6),
                TextButton(
                  onPressed: busy ? null : () => setS(() { isNew = !isNew; error = null; }),
                  child: Text(isNew
                      ? 'Already have an account? Sign in'
                      : 'No account yet? Create one'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setS(() { busy = true; error = null; });
                      final auth = context.read<AuthService>();
                      final err = isNew
                          ? await auth.registerWithEmail(emailCtrl.text, passCtrl.text)
                          : await auth.signInWithEmail(emailCtrl.text, passCtrl.text);
                      if (err == null) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        setS(() { busy = false; error = err; });
                      }
                    },
              child: Text(busy ? '...' : (isNew ? 'Create' : 'Sign in')),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _onCreatePost() async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      final ok = await _showLoginDialog();
      if (!ok || !mounted) return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final feed = context.watch<FeedService>();
    final newBadge = feed.lastNewCount > 0 ? ' • +${feed.lastNewCount} new' : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'donut4u',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: auth.isLoggedIn ? 'Sign out' : 'Sign in',
            icon: Icon(auth.isLoggedIn ? Icons.logout : Icons.person_outline),
            onPressed: () async {
              if (auth.isLoggedIn) {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: Text(auth.email ?? auth.displayName ?? ''),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('No')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign out')),
                    ],
                  ),
                );
                if (sure == true) await auth.signOut();
              } else {
                _showLoginDialog();
              }
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: feed.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: feed.isLoading ? null : () => feed.forceRefresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: kTopics.map((t) => Tab(text: '${t.emoji} ${t.nameTagalog}')).toList(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    feed.lastRefresh == null
                        ? 'Starting...'
                        : 'Live • Updates every 1 min$newBadge • Last: ${_formatTime(feed.lastRefresh!)}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: kTopics.map((t) => _TopicPage(topicId: t.id)).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreatePost,
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/// One column. Keeps its own scroll position and its own posts.
class _TopicPage extends StatefulWidget {
  final String topicId;
  const _TopicPage({required this.topicId});

  @override
  State<_TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<_TopicPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = context.watch<FeedService>();
    final posts = feed.postsFor(widget.topicId);

    if (posts.isEmpty) {
      if (feed.isLoadingTopic(widget.topicId)) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Nothing here yet.'),
            TextButton(
              onPressed: () => feed.forceRefresh(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => feed.forceRefresh(),
      child: ListView.builder(
        key: PageStorageKey('feed_${widget.topicId}'),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return PostCard(
            key: ValueKey(post.id),
            post: post,
            onTapStoryOrVideo: () {
              if (post.type == PostType.story || post.type == PostType.video) {
                final media = posts
                    .where((p) => p.type == PostType.story || p.type == PostType.video)
                    .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewer(post: post, playlist: media),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
