enum PostType { text, story, video, image }

class Post {
  final String id;
  final String topic;
  final String title;
  final String body;
  final PostType type;
  final String? mediaUrl;       // download URL (Firebase Storage or sample)
  final String? localMediaPath; // temporary local path before upload
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final int likes;
  final int commentsCount;
  final bool isFresh;
  final bool isUserPost;

  Post({
    required this.id,
    required this.topic,
    required this.title,
    required this.body,
    required this.type,
    this.mediaUrl,
    this.localMediaPath,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.likes = 0,
    this.commentsCount = 0,
    this.isFresh = true,
    this.isUserPost = false,
  });

  bool isStillFresh({int maxAgeMinutes = 120}) {
    final age = DateTime.now().difference(createdAt).inMinutes;
    return age <= maxAgeMinutes;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic': topic,
      'title': title,
      'body': body,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'commentsCount': commentsCount,
      'isFresh': isFresh,
      'isUserPost': isUserPost,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      topic: map['topic'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: PostType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PostType.text,
      ),
      mediaUrl: map['mediaUrl'],
      authorId: map['authorId'] ?? 'unknown',
      authorName: map['authorName'] ?? 'donut4u',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      likes: map['likes'] ?? 0,
      commentsCount: map['commentsCount'] ?? map['comments'] ?? 0,
      isFresh: map['isFresh'] ?? true,
      isUserPost: map['isUserPost'] ?? false,
    );
  }

  Post copyWith({
    int? likes,
    int? commentsCount,
    String? mediaUrl,
  }) {
    return Post(
      id: id,
      topic: topic,
      title: title,
      body: body,
      type: type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      localMediaPath: localMediaPath,
      authorId: authorId,
      authorName: authorName,
      createdAt: createdAt,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      isFresh: isFresh,
      isUserPost: isUserPost,
    );
  }
}
