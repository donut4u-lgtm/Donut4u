import '../models/post.dart';
import '../models/topic.dart';
import '../services/content_service.dart';

class TopicBot {
  final Topic topic;
  DateTime? lastGeneratedAt;

  TopicBot({required this.topic});

  /// Real, current articles for this topic.
  Future<List<Post>> generateFreshContent() async {
    final posts = await ContentService().postsForTopic(topic);
    lastGeneratedAt = DateTime.now();
    return posts;
  }
}
