import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/post.dart';
import '../models/topic.dart';

class _Feed {
  final String name;
  final String url;
  const _Feed(this.name, this.url);
}

class _Trend {
  final String title;
  final String traffic;
  final String? picture;
  final String? newsTitle;
  final String? newsSource;
  final String? newsUrl;
  final DateTime date;

  const _Trend({
    required this.title,
    required this.traffic,
    required this.picture,
    required this.newsTitle,
    required this.newsSource,
    required this.newsUrl,
    required this.date,
  });
}

/// Loads real, current content for each topic from the internet:
/// Google News searches (any website), news feeds, Google Trends,
/// recipes and jokes. Every post keeps a link back to where it came from.
class ContentService {
  static final ContentService _instance = ContentService._internal();
  factory ContentService() => _instance;
  ContentService._internal();

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) donut4u/1.0',
    'Accept': '*/*',
  };

  // Google News search = "everything found on the internet", last 24 hours.
  static const String _gn = 'https://news.google.com/rss/search?q=';
  static const String _gnEnd = '+when:1d&hl=fil&gl=PH&ceid=PH:fil';

  static const Map<String, List<_Feed>> _feeds = {
    'viral': [
      _Feed('Google News', '${_gn}viral+Pilipinas$_gnEnd'),
      _Feed('Google News', '${_gn}viral+video+Pinoy$_gnEnd'),
    ],
    'haha': [
      _Feed('Google News', '${_gn}nakakatawa+viral+Pilipinas$_gnEnd'),
      _Feed('Google News', '${_gn}meme+Pinoy+trending$_gnEnd'),
    ],
    'uso': [
      _Feed('Google News', '${_gn}trending+Pilipinas+ngayon$_gnEnd'),
      _Feed('Google News', '${_gn}pinag-uusapan+social+media+Pilipinas$_gnEnd'),
    ],
    'balita': [
      _Feed('Inquirer', 'https://newsinfo.inquirer.net/feed'),
      _Feed('GMA News', 'https://data.gmanetwork.com/gno/rss/news/feed.xml'),
      _Feed('Philstar', 'https://www.philstar.com/rss/headlines'),
      _Feed('Google News', '${_gn}balita+Pilipinas$_gnEnd'),
    ],
    'sports': [
      _Feed('Inquirer Sports', 'https://sports.inquirer.net/feed'),
      _Feed('GMA Sports', 'https://data.gmanetwork.com/gno/rss/sports/feed.xml'),
      _Feed('Philstar Sports', 'https://www.philstar.com/rss/sports'),
      _Feed('Google News', '${_gn}PBA$_gnEnd'),
      _Feed('Google News', '${_gn}Gilas+Pilipinas$_gnEnd'),
      _Feed('Google News', '${_gn}Pinoy+boxing+volleyball$_gnEnd'),
    ],
    'libangan': [
      _Feed('Philstar Entertainment', 'https://www.philstar.com/rss/entertainment'),
      _Feed('Inquirer Entertainment', 'https://entertainment.inquirer.net/feed'),
      _Feed('Google News', '${_gn}teleserye+pelikula+Pilipinas$_gnEnd'),
      _Feed('Google News', '${_gn}OPM+concert+musika$_gnEnd'),
    ],
    'chika': [
      _Feed('GMA Showbiz', 'https://data.gmanetwork.com/gno/rss/showbiz/feed.xml'),
      _Feed('Google News', '${_gn}showbiz+chika+artista$_gnEnd'),
      _Feed('Google News', '${_gn}celebrity+Pinoy+usap-usapan$_gnEnd'),
    ],
    'tekno': [
      _Feed('GMA SciTech', 'https://data.gmanetwork.com/gno/rss/scitech/feed.xml'),
      _Feed('Inquirer Technology', 'https://technology.inquirer.net/feed'),
      _Feed('Google News', '${_gn}teknolohiya+gadget+Pilipinas$_gnEnd'),
      _Feed('Google News', '${_gn}smartphone+app+Philippines$_gnEnd'),
    ],
    'pagkain': [
      _Feed('Google News', '${_gn}pagkain+Pilipinas$_gnEnd'),
      _Feed('Google News', '${_gn}Filipino+food+recipe$_gnEnd'),
    ],
    'pagibig': [
      _Feed('Philstar Lifestyle', 'https://www.philstar.com/rss/lifestyle'),
      _Feed('GMA Lifestyle', 'https://data.gmanetwork.com/gno/rss/lifestyle/feed.xml'),
      _Feed('Google News', '${_gn}pag-ibig+relasyon+payo$_gnEnd'),
    ],
    'lokal': [
      _Feed('Philstar Nation', 'https://www.philstar.com/rss/nation'),
      _Feed('GMA Regions', 'https://data.gmanetwork.com/gno/rss/news/regions/feed.xml'),
      _Feed('Google News', '${_gn}lokal+balita+probinsya$_gnEnd'),
    ],
  };

  final Map<String, List<Post>> _cache = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<List<Post>>> _inFlight = {};

  List<_Trend> _trendCache = [];
  DateTime? _trendAt;

  /// Forget cached results so the next call downloads fresh content.
  void invalidate() {
    _fetchedAt.clear();
    _trendAt = null;
  }

  Duration _ttl(String topicId) {
    if (topicId == 'haha' || topicId == 'pagkain') {
      return const Duration(minutes: 30);
    }
    return const Duration(minutes: 10);
  }

  Future<List<Post>> postsForTopic(Topic topic) {
    final id = topic.id;
    final last = _fetchedAt[id];
    if (last != null && DateTime.now().difference(last) < _ttl(id)) {
      return Future.value(_cache[id] ?? <Post>[]);
    }
    final running = _inFlight[id];
    if (running != null) return running;

    final future = _load(topic).whenComplete(() {
      _inFlight.remove(id);
    });
    _inFlight[id] = future;
    return future;
  }

  Future<List<Post>> _load(Topic topic) async {
    try {
      final posts = await _fetchTopic(topic.id, topic.nameTagalog);
      if (posts.isNotEmpty) {
        _cache[topic.id] = posts;
        _fetchedAt[topic.id] = DateTime.now();
      }
    } catch (e) {
      debugPrint('Content load error (${topic.id}): $e');
    }
    return _cache[topic.id] ?? <Post>[];
  }

  Future<List<Post>> _fetchTopic(String id, String name) async {
    switch (id) {
      case 'viral':
        {
          final r = await Future.wait([
            _trendsFor(id, name, 0, 5),
            _fromFeeds('viral', id, name),
          ]);
          return _merge(r, 20);
        }
      case 'uso':
        {
          final r = await Future.wait([
            _trendsFor(id, name, 5, 15),
            _fromFeeds('uso', id, name),
          ]);
          return _merge(r, 20);
        }
      case 'haha':
        {
          final r = await Future.wait([
            _safe(_jokes(id, name)),
            _fromFeeds('haha', id, name),
          ]);
          return _merge(r, 20);
        }
      case 'pagkain':
        {
          final r = await Future.wait([
            _safe(_meals(id, name)),
            _fromFeeds('pagkain', id, name),
          ]);
          return _merge(r, 20);
        }
      case 'bago':
        {
          final parts = await Future.wait([
            _fromFeeds('balita', id, name),
            _fromFeeds('libangan', id, name),
            _fromFeeds('tekno', id, name),
            _fromFeeds('sports', id, name),
          ]);
          return _merge(parts, 12);
        }
      default:
        return _fromFeeds(id, id, name);
    }
  }

  Future<List<Post>> _safe(Future<List<Post>> f) async {
    try {
      return await f;
    } catch (e) {
      debugPrint('Source error: $e');
      return <Post>[];
    }
  }

  /// Combine lists, remove duplicates, newest first.
  List<Post> _merge(List<List<Post>> lists, int max) {
    final seen = <String>{};
    final all = <Post>[];
    for (final l in lists) {
      for (final p in l) {
        if (seen.add(p.id)) all.add(p);
      }
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(max).toList();
  }

  // ---------------------------------------------------------------- RSS

  Future<List<Post>> _fromFeeds(String feedKey, String topicId, String topicName) async {
    final feeds = _feeds[feedKey] ?? const <_Feed>[];
    final lists = await Future.wait(feeds.map((f) => _rss(f, topicId, topicName)));
    return _merge(lists, 20);
  }

  Future<List<Post>> _rss(_Feed feed, String topicId, String topicName) async {
    try {
      final res = await http
          .get(Uri.parse(feed.url), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return <Post>[];

      final isGoogleNews = feed.url.contains('news.google.com');
      final doc = XmlDocument.parse(utf8.decode(res.bodyBytes, allowMalformed: true));
      final out = <Post>[];

      for (final item in doc.findAllElements('item')) {
        var title = _clean(_childText(item, 'title'));
        final link = _childText(item, 'link');
        if (title.isEmpty || link.isEmpty) continue;

        var sourceName = feed.name;
        String? image;
        String body;

        if (isGoogleNews) {
          // Google News titles look like "Headline - Source name".
          final src = _clean(_childText(item, 'source'));
          if (src.isNotEmpty) {
            sourceName = src;
            final tail = ' - $src';
            if (title.endsWith(tail)) {
              title = title.substring(0, title.length - tail.length).trim();
            }
          }
          body = 'Mula sa $sourceName.';
        } else {
          final rawDesc = _childText(item, 'description');
          final rawFull = _childText(item, 'encoded');
          body = _shorten(_clean(rawDesc.isNotEmpty ? rawDesc : rawFull), 220);
          if (body.isEmpty || body == title) body = 'Mula sa ${feed.name}.';
          image = _imageFrom(item, '$rawDesc $rawFull');
        }

        out.add(Post(
          id: 'rss_${topicId}_${link.hashCode.toRadixString(16)}',
          topic: topicName,
          title: _shorten(title, 140),
          body: body,
          type: image == null ? PostType.text : PostType.image,
          mediaUrl: image,
          authorId: topicId,
          authorName: topicName,
          createdAt: _parseDate(_childText(item, 'pubDate')),
          likes: 0,
          commentsCount: 0,
          isFresh: true,
          isUserPost: false,
          sourceName: sourceName,
          sourceUrl: link,
        ));
        if (out.length >= 10) break;
      }
      return out;
    } catch (e) {
      debugPrint('Feed error (${feed.name}): $e');
      return <Post>[];
    }
  }

  // ------------------------------------------------------- Google Trends

  Future<List<Post>> _trendsFor(String topicId, String topicName, int start, int end) async {
    final all = await _trends();
    if (all.length <= start) return <Post>[];
    final stop = all.length < end ? all.length : end;
    return _trendPosts(topicId, topicName, all.sublist(start, stop));
  }

  Future<List<_Trend>> _trends() async {
    final at = _trendAt;
    if (at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 10) &&
        _trendCache.isNotEmpty) {
      return _trendCache;
    }
    try {
      final res = await http
          .get(Uri.parse('https://trends.google.com/trending/rss?geo=PH'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _trendCache;

      final doc = XmlDocument.parse(utf8.decode(res.bodyBytes, allowMalformed: true));
      final out = <_Trend>[];
      for (final item in doc.findAllElements('item')) {
        final title = _clean(_childText(item, 'title'));
        if (title.isEmpty) continue;
        final news = _child(item, 'news_item');
        out.add(_Trend(
          title: title,
          traffic: _childText(item, 'approx_traffic'),
          picture: _nz(_childText(item, 'picture')),
          newsTitle: news == null ? null : _nz(_clean(_childText(news, 'news_item_title'))),
          newsSource: news == null ? null : _nz(_clean(_childText(news, 'news_item_source'))),
          newsUrl: news == null ? null : _nz(_childText(news, 'news_item_url')),
          date: _parseDate(_childText(item, 'pubDate')),
        ));
      }
      if (out.isNotEmpty) {
        _trendCache = out;
        _trendAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('Trends error: $e');
    }
    return _trendCache;
  }

  List<Post> _trendPosts(String topicId, String topicName, List<_Trend> list) {
    return list.map((t) {
      final traffic = t.traffic.isEmpty ? '' : ' • ${t.traffic} searches';
      final body = StringBuffer('Pinag-uusapan ngayon sa Pilipinas$traffic.');
      if (t.newsTitle != null) {
        body.write('\n\n${_shorten(t.newsTitle!, 160)}');
      }
      final hasPic = t.picture != null && t.picture!.startsWith('http');
      return Post(
        id: 'trend_${topicId}_${t.title.hashCode.toRadixString(16)}',
        topic: topicName,
        title: t.title,
        body: body.toString(),
        type: hasPic ? PostType.image : PostType.text,
        mediaUrl: hasPic ? t.picture : null,
        authorId: topicId,
        authorName: topicName,
        createdAt: t.date,
        likes: 0,
        commentsCount: 0,
        isFresh: true,
        isUserPost: false,
        sourceName: t.newsSource ?? 'Google Trends',
        sourceUrl: t.newsUrl ?? 'https://trends.google.com/trending?geo=PH',
      );
    }).toList();
  }

  // ------------------------------------------------------------- Jokes

  Future<List<Post>> _jokes(String topicId, String topicName) async {
    final res = await http
        .get(
          Uri.parse(
            'https://v2.jokeapi.dev/joke/Any?safe-mode&type=single&amount=4'
            '&blacklistFlags=nsfw,religious,political,racist,sexist,explicit',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return <Post>[];

    final data = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    final List<dynamic> jokes;
    if (data is Map && data['jokes'] is List) {
      jokes = data['jokes'] as List<dynamic>;
    } else if (data is Map && data['joke'] != null) {
      jokes = [data];
    } else {
      jokes = [];
    }

    final out = <Post>[];
    for (final j in jokes) {
      if (j is! Map) continue;
      final text = (j['joke'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      out.add(Post(
        id: 'joke_${j['id']}_${text.hashCode.toRadixString(16)}',
        topic: topicName,
        title: 'Haha para sa araw mo 😂',
        body: text,
        type: PostType.text,
        authorId: topicId,
        authorName: topicName,
        createdAt: DateTime.now(),
        likes: 0,
        commentsCount: 0,
        isFresh: true,
        isUserPost: false,
        sourceName: 'JokeAPI',
      ));
    }
    return out;
  }

  // ------------------------------------------------------------- Meals

  Future<List<Post>> _meals(String topicId, String topicName) async {
    final responses = await Future.wait(List.generate(4, (_) {
      return http
          .get(Uri.parse('https://www.themealdb.com/api/json/v1/1/random.php'), headers: _headers)
          .timeout(const Duration(seconds: 15));
    }));

    final seen = <String>{};
    final out = <Post>[];
    for (final res in responses) {
      if (res.statusCode != 200) continue;
      final data = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
      if (data is! Map || data['meals'] is! List || (data['meals'] as List).isEmpty) continue;
      final m = (data['meals'] as List).first;
      if (m is! Map) continue;

      final mealId = (m['idMeal'] ?? '').toString();
      final name = (m['strMeal'] ?? '').toString().trim();
      if (mealId.isEmpty || name.isEmpty || !seen.add(mealId)) continue;

      final category = (m['strCategory'] ?? '').toString();
      final area = (m['strArea'] ?? '').toString();
      final how = _shorten(_clean((m['strInstructions'] ?? '').toString()), 180);
      final thumb = (m['strMealThumb'] ?? '').toString();
      final source = (m['strSource'] ?? '').toString();

      final tags = [category, area].where((s) => s.isNotEmpty).join(' • ');
      out.add(Post(
        id: 'meal_$mealId',
        topic: topicName,
        title: name,
        body: tags.isEmpty ? how : '$tags\n$how',
        type: thumb.startsWith('http') ? PostType.image : PostType.text,
        mediaUrl: thumb.startsWith('http') ? thumb : null,
        authorId: topicId,
        authorName: topicName,
        createdAt: DateTime.now(),
        likes: 0,
        commentsCount: 0,
        isFresh: true,
        isUserPost: false,
        sourceName: 'TheMealDB',
        sourceUrl: source.startsWith('http')
            ? source
            : 'https://www.themealdb.com/meal/$mealId',
      ));
    }
    return out;
  }

  // ----------------------------------------------------------- helpers

  XmlElement? _child(XmlElement parent, String local) {
    for (final c in parent.children) {
      if (c is XmlElement && c.name.local == local) return c;
    }
    return null;
  }

  String _childText(XmlElement parent, String local) {
    final c = _child(parent, local);
    return c == null ? '' : c.innerText.trim();
  }

  String? _nz(String s) => s.isEmpty ? null : s;

  bool _looksLikeImage(String url) {
    return RegExp(r'\.(jpe?g|png|webp|gif)(\?|$)', caseSensitive: false).hasMatch(url);
  }

  String? _imageFrom(XmlElement item, String rawHtml) {
    for (final c in item.children) {
      if (c is! XmlElement) continue;
      final n = c.name.local;
      if (n == 'enclosure' || n == 'content' || n == 'thumbnail') {
        final url = c.getAttribute('url');
        final type = c.getAttribute('type') ?? '';
        if (url != null &&
            url.startsWith('http') &&
            (type.startsWith('image') || _looksLikeImage(url))) {
          return url;
        }
      }
    }
    final m = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(rawHtml);
    final src = m?.group(1);
    if (src != null && src.startsWith('http')) return src;
    return null;
  }

  String _clean(String html) {
    var s = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8216;', '‘')
        .replaceAll('&#8220;', '“')
        .replaceAll('&#8221;', '”')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8230;', '…')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    s = s.replaceAll(RegExp(r'The post .*? appeared first on .*$'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String _shorten(String s, int max) {
    if (s.length <= max) return s;
    final cut = s.substring(0, max);
    final sp = cut.lastIndexOf(' ');
    return '${sp > 40 ? cut.substring(0, sp) : cut}…';
  }

  DateTime _parseDate(String? input) {
    final now = DateTime.now();
    if (input == null || input.trim().isEmpty) return now;
    final s = input.trim();

    final iso = DateTime.tryParse(s);
    if (iso != null) {
      final u = iso.toUtc();
      return u.isAfter(now) ? now : u;
    }

    final m = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|GMT|UTC|UT|Z)?',
    ).firstMatch(s);
    if (m == null) return now;

    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final month = months[m.group(2)!.toLowerCase()];
    if (month == null) return now;

    var dt = DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    );

    final tz = m.group(7);
    if (tz != null && (tz.startsWith('+') || tz.startsWith('-'))) {
      final sign = tz.startsWith('-') ? -1 : 1;
      final h = int.parse(tz.substring(1, 3));
      final mi = int.parse(tz.substring(3, 5));
      dt = dt.subtract(Duration(hours: sign * h, minutes: sign * mi));
    }
    return dt.isAfter(now) ? now : dt;
  }
}
