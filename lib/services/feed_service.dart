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
  DateTime? _lastRefresh;
  Timer? _uiTimer;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  DateTime? get lastRefresh => _lastRefresh;
  String? get currentTopicId => _currentTopicId;

  void initialize() {
    _manager.initialize();
    _data.initialize();
    _load(refresh: false);
    // The ManagerBot already creates new posts every 60 seconds by itself.
    // This timer only re-reads the list so the screen stays up to date.
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _load(refresh: false);
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
    _posts = all;
    _lastRefresh = DateTime.now();

    _isLoading = false;
    _notify();
  }

  Future<void> setTopic(String? topicId) async {
    _currentTopicId = topicId;
    await _load(refresh: false);
  }

  /// Called by the refresh button and pull-to-refresh.
  Future<void> forceRefresh() async => _load(refresh: true);

  Future<void> addUserPost(Post post) async {
    await _data.saveUserPost(post);
    await _load(refresh: false);
  }

  Map<String, String> getBotStatus() => _manager.getBotStatus();
}
