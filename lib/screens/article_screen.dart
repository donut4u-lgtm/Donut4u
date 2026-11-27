import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/post.dart';

/// Shows an article inside the app (no Chrome, no leaving donut4u).
class ArticleScreen extends StatefulWidget {
  final Post post;
  const ArticleScreen({super.key, required this.post});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: (request) {
            final u = request.url;
            final isWeb = u.startsWith('http://') ||
                u.startsWith('https://') ||
                u.startsWith('about:');
            // Never jump to another app: everything stays in donut4u.
            return isWeb ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.post.sourceUrl ?? 'about:blank'));
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.topic,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (post.sourceName != null)
                Text(
                  post.sourceName!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Isara',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_progress < 100)
              LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
