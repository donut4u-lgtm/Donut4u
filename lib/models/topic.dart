class Topic {
  final String id;
  final String nameTagalog;   // column name shown to user
  final String nameEnglish;
  final String emoji;
  final String botName;

  const Topic({
    required this.id,
    required this.nameTagalog,
    required this.nameEnglish,
    required this.emoji,
    required this.botName,
  });
}

/// The official 10+ Tagalog columns for donut4u
const List<Topic> kTopics = [
  Topic(id: 'viral', nameTagalog: 'Viral', nameEnglish: 'Viral', emoji: '🔥', botName: 'ViralBot'),
  Topic(id: 'haha', nameTagalog: 'Haha', nameEnglish: 'Funny', emoji: '😂', botName: 'HahaBot'),
  Topic(id: 'bago', nameTagalog: 'Bago', nameEnglish: 'New', emoji: '✨', botName: 'BagoBot'),
  Topic(id: 'uso', nameTagalog: 'Uso', nameEnglish: 'Trending', emoji: '📈', botName: 'UsoBot'),
  Topic(id: 'balita', nameTagalog: 'Balita', nameEnglish: 'News', emoji: '📰', botName: 'BalitaBot'),
  Topic(id: 'chika', nameTagalog: 'Chika', nameEnglish: 'Gossip', emoji: '💬', botName: 'ChikaBot'),
  Topic(id: 'pagkain', nameTagalog: 'Pagkain', nameEnglish: 'Food', emoji: '🍜', botName: 'PagkainBot'),
  Topic(id: 'libangan', nameTagalog: 'Libangan', nameEnglish: 'Entertainment', emoji: '🎬', botName: 'LibanganBot'),
  Topic(id: 'sports', nameTagalog: 'Sports', nameEnglish: 'Sports', emoji: '⚽', botName: 'SportsBot'),
  Topic(id: 'tekno', nameTagalog: 'Tekno', nameEnglish: 'Tech', emoji: '📱', botName: 'TeknoBot'),
  Topic(id: 'pagibig', nameTagalog: 'Pag-ibig', nameEnglish: 'Love', emoji: '❤️', botName: 'PagibigBot'),
  Topic(id: 'lokal', nameTagalog: 'Lokal', nameEnglish: 'Local', emoji: '📍', botName: 'LokalBot'),
];
