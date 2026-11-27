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
    _tabController = TabController(length: kTopics.length + 1, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final feed = context.read<FeedService>();
    if (_tabController.index == 0) {
      feed.setTopic(null);
    } else {
      final topic = kTopics[_tabController.index - 1];
      feed.setTopic(topic.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showLoginDialog() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mag-sign in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kailangan lang mag-sign in kung gusto mong mag-comment, mag-post, o mag-upload. '
              'Pwede mong i-browse ang lahat nang walang account.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Pangalan / Display name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Magpatuloy'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      final ok = await context.read<AuthService>().signInWithDisplayName(nameCtrl.text);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${nameCtrl.text.trim()}!')),
        );
      }
    }
  }

  void _onCreatePost() {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      _showLoginDialog().then((_) {
        if (!mounted) return;
        if (context.read<AuthService>().isLoggedIn) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
        }
      });
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedService>();
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'donut4u',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        centerTitle: true,
        actions: [
          if (auth.isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  auth.displayName ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          IconButton(
            tooltip: auth.isLoggedIn ? 'Sign out' : 'Sign in',
            icon: Icon(auth.isLoggedIn ? Icons.logout : Icons.person_outline),
            onPressed: () async {
              if (auth.isLoggedIn) {
                await auth.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out. Pwede pa ring mag-browse.')),
                  );
                }
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
          tabs: [
            const Tab(text: 'Lahat'),
            ...kTopics.map((t) => Tab(text: '${t.emoji} ${t.nameTagalog}')),
          ],
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
                        ? 'Nagsisimula pa lang...'
                        : 'Latest only • Auto-refresh every 1 min • Last: ${_formatTime(feed.lastRefresh!)}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeed(feed),
                ...kTopics.map((_) => _buildFeed(feed)),
              ],
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

  Widget _buildFeed(FeedService feed) {
    if (feed.isLoading && feed.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feed.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Walang fresh content pa.'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => feed.forceRefresh(),
              child: const Text('I-refresh ngayon'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => feed.forceRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: feed.posts.length,
        itemBuilder: (context, index) {
          final post = feed.posts[index];
          return PostCard(
            post: post,
            onTapStoryOrVideo: () {
              if (post.type == PostType.story || post.type == PostType.video) {
                final mediaPosts = feed.posts
                    .where((p) => p.type == PostType.story || p.type == PostType.video)
                    .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewer(post: post, playlist: mediaPosts),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
