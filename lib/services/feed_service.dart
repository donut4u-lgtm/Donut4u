import 'package:flutter/foundation.dart';
import '../bots/manager_bot.dart';
import '../models/post.dart';
import 'data_service.dart';

class FeedService extends ChangeNotifier {
  final ManagerBot _manager = ManagerBot();
  final DataService _data = DataService();
  List<Post> _posts = [];
  String? _currentTopicId;
  bool _isLoading = false;
  DateTime? _lastRefresh;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  DateTime? get lastRefresh => _lastRefresh;
  String? get currentTopicId => _currentTopicId;

  void initialize() {
    _manager.initialize();
    _data.initialize();
    _load();
    _startUiTicker();
  }

  void _startUiTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 60));
      await _load();
      return true;
    });
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();

    await _manager.forceRefresh();
    final botPosts = _manager.getFreshPosts(topicId: _currentTopicId);
    final userPosts = await _data.fetchRecentUserPosts(maxAgeMinutes: ManagerBot.maxAgeMinutes);

    final filteredUser = userPosts.where((p) {
      if (_currentTopicId == null) return true;
      return p.topic.toLowerCase() == _currentTopicId!.toLowerCase();
    }).toList();

    _posts = [...filteredUser, ...botPosts];
    _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _lastRefresh = DateTime.now();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setTopic(String? topicId) async {
    _currentTopicId = topicId;
    await _load();
  }

  Future<void> forceRefresh() async => _load();

  Future<void> addUserPost(Post post) async {
    await _data.saveUserPost(post);
    await _load();
  }

  Map<String, String> getBotStatus() => _manager.getBotStatus();
}
