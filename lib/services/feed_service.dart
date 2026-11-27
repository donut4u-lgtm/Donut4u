import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bots/manager_bot.dart';
import '../models/post.dart';
import '../models/topic.dart';
import 'data_service.dart';

class FeedService extends ChangeNotifier {
  final ManagerBot _manager = ManagerBot();
  final DataService _data = DataService();
  List<Post> _posts = [];
  String? _currentTopicId;
  bool _isLoading = false;
  bool _disposed = false;
  bool _topicJustChanged = false;
  DateTime? _lastRefresh;
  Timer? _uiTimer;
  int _lastNewCount = 0;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  DateTime? get lastRefresh => _lastRefresh;
  String? get currentTopicId => _currentTopicId;

  /// How many posts appeared in the most recent refresh.
  int get lastNewCount => _lastNewCount;

  void initialize() {
    _manager.initialize();
    _data.initialize();
    _load(refresh: true);
    // Every minute: download fresh content from the internet, then update the screen.
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_isLoading) _load(refresh: true);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _uiTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String? get _currentTopicName {
    if (_currentTopicId == null) return null;
    for (final t in kTopics) {
      if (t.id == _currentTopicId) return t.nameTagalog;
    }
    return null;
  }

  Future<void> _load({bool refresh = false}) async {
    _isLoading = true;
    _notify();

    if (refresh) {
      await _manager.forceRefresh();
    }

    final topicName = _currentTopicName;
    bool matches(Post p) =>
        topicName == null || p.topic.toLowerCase() == topicName.toLowerCase();

    final botPosts = _manager.getFreshPosts().where(matches).toList();
    final userPosts =
        await _data.fetchRecentUserPosts(maxAgeMinutes: ManagerBot.maxAgeMinutes);
    final filteredUser = userPosts.where(matches).toList();

    final all = [...filteredUser, ...botPosts];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Count what is new since the last time this list was shown.
    final firstLoad = _lastRefresh == null;
    if (firstLoad || _topicJustChanged) {
      _lastNewCount = 0;
    } else {
      final oldIds = _posts.map((p) => p.id).toSet();
      _lastNewCount = all.where((p) => !oldIds.contains(p.id)).length;
    }
    _topicJustChanged = false;

    _posts = all;
    _lastRefresh = DateTime.now();

    _isLoading = false;
    _notify();
  }

  Future<void> setTopic(String? topicId) async {
    _currentTopicId = topicId;
    _topicJustChanged = true;
    await _load(refresh: false);
  }

  /// Called by the refresh button and pull-to-refresh.
  Future<void> forceRefresh() async => _load(refresh: true);

  Future<void> addUserPost(Post post) async {
    await _data.saveUserPost(post);
    _topicJustChanged = true;
    await _load(refresh: false);
  }

  Map<String, String> getBotStatus() => _manager.getBotStatus();
}
