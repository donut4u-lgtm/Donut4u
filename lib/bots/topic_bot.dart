import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/post.dart';
import '../models/topic.dart';

class TopicBot {
  final Topic topic;
  DateTime? lastGeneratedAt;
  final _uuid = const Uuid();
  final _rng = Random();

  TopicBot({required this.topic});

  Future<List<Post>> generateFreshContent() async {
    await Future.delayed(Duration(milliseconds: 60 + _rng.nextInt(100)));
    final now = DateTime.now();
    lastGeneratedAt = now;

    final count = 1 + _rng.nextInt(2);
    final posts = <Post>[];
    for (var i = 0; i < count; i++) {
      posts.add(_createOnePost(now));
    }
    return posts;
  }

  Post _createOnePost(DateTime now) {
    final templates = _templatesForTopic();
    final template = templates[_rng.nextInt(templates.length)];

    final typeRoll = _rng.nextInt(10);
    PostType type;
    String? mediaUrl;

    if (typeRoll < 3) {
      type = PostType.story;
      mediaUrl = _sampleMediaUrl();
    } else if (typeRoll < 6) {
      type = PostType.video;
      mediaUrl = _sampleMediaUrl();
    } else if (typeRoll < 8) {
      type = PostType.image;
      mediaUrl = null;
    } else {
      type = PostType.text;
      mediaUrl = null;
    }

    return Post(
      id: _uuid.v4(),
      topic: topic.nameTagalog,
      title: template['title']!,
      body: template['body']!,
      type: type,
      mediaUrl: mediaUrl,
      authorId: topic.botName,
      authorName: topic.botName,
      createdAt: now.subtract(Duration(seconds: _rng.nextInt(40))),
      likes: _rng.nextInt(40),
      commentsCount: _rng.nextInt(8),
      isFresh: true,
      isUserPost: false,
    );
  }

  List<Map<String, String>> _templatesForTopic() {
    switch (topic.id) {
      case 'viral':
        return [
          {'title': 'Biglang naging viral ang simpleng sayaw na ito!', 'body': 'Isang ordinaryong video mula sa bahay ang kumalat nang todo. Tingnan kung bakit napaka-addictive ng galaw.'},
          {'title': 'Hindi inaasahang reaction ang ikinagulat ng lahat', 'body': 'Nang ma-post ang short clip, agad itong pumuno ng comments. Fresh pa lang ngayong minuto.'},
        ];
      case 'haha':
        return [
          {'title': 'Yung tipong akala mo serious pero...', 'body': 'Isang simpleng biro ang nagpasabog ng group chat. Haha level maximum.'},
          {'title': 'Meme of the minute – bago lang lumabas', 'body': 'Kapag nakita mo to, siguradong mapapangiti ka. Pure haha content galing sa HahaBot.'},
        ];
      case 'bago':
        return [
          {'title': 'Kakapublish lang – unang sulyap', 'body': 'Ito ang pinakabagong post na kakalabas pa lang. Walang lumang content dito.'},
          {'title': 'Fresh off the bot – just now', 'body': 'BagoBot here. Ito ang pinaka-recent na kuwento sa feed mo.'},
        ];
      case 'uso':
        return [
          {'title': 'Ito ang pinag-uusapan ngayong minuto', 'body': 'Biglang sumikat. Kung gusto mong updated, nandito ang latest uso.'},
          {'title': 'Trending na trending – huwag ma-left out', 'body': 'UsoBot nag-update. Ito ang pinakamainit ngayon.'},
        ];
      case 'balita':
        return [
          {'title': 'Maikling update – kaka-release lang', 'body': 'Walang lumang balita. Ito ang pinakabagong short report mula sa BalitaBot.'},
          {'title': 'Quick news bite – just in', 'body': 'Maikli, malinaw, at sariwa. Para sa mga ayaw magbasa ng mahaba.'},
        ];
      case 'chika':
        return [
          {'title': 'Chismis alert – bago pa lang ang usap', 'body': 'Hindi verified, pure chika lang. ChikaBot nagdala ng pinakabago.'},
          {'title': 'May bagong kwento sa community', 'body': 'Sariwang chika, walang recycle. Basahin inside the app.'},
        ];
      case 'pagkain':
        return [
          {'title': 'Bagong discovery sa street food', 'body': 'Kakapitik lang ng litrato. Tingnan ang bagong paborito ng mga gutom.'},
          {'title': 'Recipe hack na uso ngayon', 'body': 'Mabilis gawin, masarap, at kaka-share pa lang.'},
        ];
      case 'libangan':
        return [
          {'title': 'Bagong clip na pinag-uusapan', 'body': 'Maikling video, malaking saya. Panoorin inside the app, hindi sa labas.'},
          {'title': 'Entertainment update – just dropped', 'body': 'LibanganBot naghatid ng pinakabagong short feature.'},
        ];
      case 'sports':
        return [
          {'title': 'Highlight na kaka-upload lang', 'body': 'Maikling sports moment. Panoorin dito mismo sa app.'},
          {'title': 'Quick score update + reaction', 'body': 'Walang delayed news. SportsBot fresh content only.'},
        ];
      case 'tekno':
        return [
          {'title': 'Bagong app tip na useful ngayon', 'body': 'Maikli at actionable. TeknoBot share ng pinakabago.'},
          {'title': 'Gadget talk – kaka-release ng balita', 'body': 'Walang recycling ng lumang article. Fresh tech bite.'},
        ];
      case 'pagibig':
        return [
          {'title': 'Sweet short story – bagong post', 'body': 'Maikling kwento tungkol sa pag-ibig. Sariwa at light.'},
          {'title': 'Advice na kailangan mo ngayong araw', 'body': 'PagibigBot may bago. Basahin inside.'},
        ];
      case 'lokal':
        return [
          {'title': 'May nangyayari sa inyong lugar', 'body': 'LokalBot nag-update. Community-level fresh news.'},
          {'title': 'Local happening – just reported', 'body': 'Para sa mga gusto ng malapit na usapan.'},
        ];
      default:
        return [
          {'title': 'Bagong post mula sa ${topic.botName}', 'body': 'Sariwang content, walang luma.'},
        ];
    }
  }

  String _sampleMediaUrl() {
    const samples = [
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ];
    return samples[_rng.nextInt(samples.length)];
  }
}
