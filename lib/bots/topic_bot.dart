import '../models/post.dart';
import '../models/topic.dart';
import '../services/content_service.dart';
import '../services/video_service.dart';

class TopicBot {
  final Topic topic;
  DateTime? lastGeneratedAt;

  TopicBot({required this.topic});

  /// Real, current articles + videos + stories for this topic.
  Future<List<Post>> generateFreshContent() async {
    final results = await Future.wait([
      ContentService().postsForTopic(topic),
      VideoService().postsForTopic(topic),
    ]);
    lastGeneratedAt = DateTime.now();
    return [...results[0], ...results[1]];
  }
}
