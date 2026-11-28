import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../models/topic.dart';
import 'content_service.dart';
import 'data_service.dart';

/// Keeps a separate list for every column, so switching columns is instant
/// and never shows the previous column's posts.
class FeedService extends ChangeNotifier {
  final DataService _data = DataService();
  final ContentService _content = ContentService();

  final Map<String, List<Post>> _byTopic = {};
  final Map<String, bool> _loadingTopic = {};
  final Map<String, int> _newCount = {};
  final List<Post> _userPosts = [];

  String _currentTopicId = kTopics.first.id;
  bool _disposed = false;
  bool _started = false;
  bool _busy = false;
  DateTime? _lastRefresh;
  Timer? _timer;
  int _round = 0;

  static const int maxPerTopic = 60;

  DateTime? get lastRefresh => _lastRefresh;
  String get currentTopicId => _currentTopicId;
  bool get isLoading => _loadingTopic[_currentTopicId] ?? false;
  int get lastNewCount => _newCount[_currentTopicId] ?? 0;

  List<Post> postsFor(String topicId) {
    final name = _nameOf(topicId);
    final mine = _userPosts
        .where((p) => p.topic.toLowerCase() == name.toLowerCase())
        .toList();
    return [...mine, ..._byTopic[topicId] ?? const <Post>[]];
  }

  bool isLoadingTopic(String topicId) => _loadingTopic[topicId] ?? false;

  String _nameOf(String id) {
    for (final t in kTopics) {
      if (t.id == id) return t.nameTagalog;
    }
    return id;
  }

  Topic _topicOf(String id) =>
      kTopics.firstWhere((t) => t.id == id, orElse: () => kTopics.first);

  void initialize() {
    if (_started) return;
    _started = true;
    _data.initialize();
    _loadUserPosts();
    _refreshAll();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _tick();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadUserPosts() async {
    try {
      final list = await _data.fetchRecentUserPosts(maxAgeMinutes: 1440);
      _userPosts
        ..clear()
        ..addAll(list);
      _userPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _notify();
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    if (_busy) return;
    _busy = true;
    try {
      await _refreshTopic(_currentTopicId);
      for (final t in kTopics) {
        if (_disposed) return;
        if (t.id == _currentTopicId) continue;
        await _refreshTopic(t.id);
      }
      _lastRefresh = DateTime.now();
      _notify();
    } finally {
      _busy = false;
    }
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await _refreshTopic(_currentTopicId);
      final others = kTopics.where((t) => t.id != _currentTopicId).toList();
      if (others.isNotEmpty) {
        final t = others[_round % others.length];
        _round++;
        await _refreshTopic(t.id);
      }
      _lastRefresh = DateTime.now();
      _notify();
    } finally {
      _busy = false;
    }
  }

  Future<void> _refreshTopic(String id) async {
    _loadingTopic[id] = true;
    _notify();
    try {
      final fresh = await _content.postsForTopic(_topicOf(id));
      final old = _byTopic[id] ?? <Post>[];
      final oldIds = old.map((p) => p.id).toSet();
      final added = fresh.where((p) => !oldIds.contains(p.id)).toList();
      final merged = <String, Post>{};
      for (final p in [...fresh, ...old]) {
        merged.putIfAbsent(p.id, () => p);
      }
      final list = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _byTopic[id] = list.take(maxPerTopic).toList();
      _newCount[id] = old.isEmpty ? 0 : added.length;
    } catch (e) {
      debugPrint('Refresh error ($id): $e');
    }
    _loadingTopic[id] = false;
    _notify();
  }

  void setTopic(String topicId) {
    _currentTopicId = topicId;
    _notify();
    if ((_byTopic[topicId] ?? const []).isEmpty && !_busy) {
      _refreshTopic(topicId);
    }
  }

  Future<void> forceRefresh() async {
    _content.invalidate();
    await _refreshTopic(_currentTopicId);
    _lastRefresh = DateTime.now();
    _notify();
  }

  Future<void> addUserPost(Post post) async {
    await _data.saveUserPost(post);
    _userPosts.insert(0, post);
    _notify();
  }
}
