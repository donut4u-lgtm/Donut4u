import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../models/topic.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../services/data_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _selectedTopic = kTopics.first.nameTagalog;
  PostType _type = PostType.text;
  File? _pickedFile;
  bool _isSubmitting = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      // Small photo: it is saved inside the post (free, no extra storage).
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 55,
      );
      if (file != null) {
        setState(() {
          _pickedFile = File(file.path);
          _type = PostType.image;
        });
      }
    } catch (e) {
      _say('Cannot get the photo: $e');
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose a photo from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    if (!auth.requireLogin()) {
      _say('Please sign in first to post.');
      return;
    }

    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      _say('Please write a title and a caption.');
      return;
    }

    setState(() => _isSubmitting = true);

    String? mediaUrl;
    if (_pickedFile != null) {
      try {
        final bytes = await _pickedFile!.readAsBytes();
        if (bytes.length > 700 * 1024) {
          _say('The photo is too big. Please choose a smaller one.');
          setState(() => _isSubmitting = false);
          return;
        }
        mediaUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (e) {
        _say('Cannot read the photo: $e');
        setState(() => _isSubmitting = false);
        return;
      }
    }

    final post = Post(
      id: const Uuid().v4(),
      topic: _selectedTopic,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: mediaUrl != null ? PostType.image : PostType.text,
      mediaUrl: mediaUrl,
      authorId: auth.userId ?? 'unknown',
      authorName: auth.displayName ?? 'User',
      createdAt: DateTime.now(),
      likes: 0,
      commentsCount: 0,
      isFresh: true,
      isUserPost: true,
    );

    await context.read<FeedService>().addUserPost(post);
    final error = DataService().lastError;

    if (mounted) {
      Navigator.pop(context);
      _say(error == null
          ? 'Posted! Everyone can see it.'
          : 'Saved only on this phone. Reason: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a post'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedTopic,
            decoration: const InputDecoration(labelText: 'Column', border: OutlineInputBorder()),
            items: kTopics
                .map((t) => DropdownMenuItem(value: t.nameTagalog, child: Text('${t.emoji} ${t.nameTagalog}')))
                .toList(),
            onChanged: (v) => setState(() => _selectedTopic = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Caption',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            maxLength: 500,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: Text(_pickedFile == null ? 'Add a photo' : 'Change the photo'),
            onPressed: _showPickerOptions,
          ),
          if (_pickedFile != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_pickedFile!, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _pickedFile = null;
                _type = PostType.text;
              }),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Remove the photo'),
            ),
          ],
        ],
      ),
    );
  }
}
