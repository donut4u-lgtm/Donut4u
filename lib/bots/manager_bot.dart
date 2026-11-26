import 'dart:async';
import '../models/post.dart';
import '../models/topic.dart';
import 'topic_bot.dart';

class ManagerBot {
  static final ManagerBot _instance = ManagerBot._internal();
  factory ManagerBot() => _instance;
  ManagerBot._internal();

  final Map<String, TopicBot> _topicBots = {};
  final List<Post> _allFreshPosts = [];
  Timer? _refreshTimer;

  static const int maxAgeMinutes = 120;

  bool get isRunning => _refreshTimer != null && _refreshTimer!.isActive;

  void initialize() {
    for (final topic in kTopics) {
      _topicBots[topic.id] = TopicBot(topic: topic);
    }
    startAutoRefresh();
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshAll();
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshAll() async {
    final List<Post> newPosts = [];
    for (final bot in _topicBots.values) {
      final posts = await bot.generateFreshContent();
      newPosts.addAll(posts);
    }

    final nowFresh = newPosts.where((p) => p.isStillFresh(maxAgeMinutes: maxAgeMinutes)).toList();
    _allFreshPosts.removeWhere((p) => !p.isStillFresh(maxAgeMinutes: maxAgeMinutes));

    final existingIds = _allFreshPosts.map((p) => p.id).toSet();
    for (final p in nowFresh) {
      if (!existingIds.contains(p.id)) {
        _allFreshPosts.add(p);
      }
    }
    _allFreshPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Post> getFreshPosts({String? topicId}) {
    _allFreshPosts.removeWhere((p) => !p.isStillFresh(maxAgeMinutes: maxAgeMinutes));
    if (topicId == null) return List.unmodifiable(_allFreshPosts);
    return List.unmodifiable(
      _allFreshPosts.where((p) => p.topic.toLowerCase() == topicId.toLowerCase()).toList(),
    );
  }

  Future<void> forceRefresh() async => _refreshAll();

  TopicBot? getBot(String topicId) => _topicBots[topicId];

  Map<String, String> getBotStatus() {
    final status = <String, String>{};
    for (final entry in _topicBots.entries) {
      status[entry.key] = entry.value.lastGeneratedAt != null
          ? 'Active – last: ${entry.value.lastGeneratedAt}'
          : 'Idle';
    }
    return status;
  }
}
