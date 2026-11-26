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

  Future<void> _pickMedia(ImageSource source, {required bool isVideo}) async {
    try {
      final XFile? file = isVideo
          ? await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2))
          : await _picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);

      if (file != null) {
        setState(() {
          _pickedFile = File(file.path);
          _type = isVideo ? PostType.video : PostType.image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hindi makuha ang media: $e')),
        );
      }
    }
  }

  void _showPickerOptions(bool isVideo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(isVideo ? 'Pumili ng Video mula sa Gallery' : 'Pumili ng Larawan mula sa Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(ImageSource.gallery, isVideo: isVideo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(isVideo ? 'Mag-record / Kumuha ng Video' : 'Kumuha ng Larawan'),
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(ImageSource.camera, isVideo: isVideo);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mag-sign in muna para makapag-post')),
      );
      return;
    }

    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lagyan ng title at body')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? mediaUrl;
    if (_pickedFile != null) {
      final data = DataService();
      mediaUrl = await data.uploadMedia(
        _pickedFile!,
        folder: _type == PostType.video || _type == PostType.story ? 'videos' : 'images',
      );
    }

    final post = Post(
      id: const Uuid().v4(),
      topic: _selectedTopic,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
      mediaUrl: mediaUrl,
      localMediaPath: _pickedFile?.path,
      authorId: auth.userId ?? 'unknown',
      authorName: auth.displayName ?? 'User',
      createdAt: DateTime.now(),
      likes: 0,
      commentsCount: 0,
      isFresh: true,
      isUserPost: true,
    );

    await context.read<FeedService>().addUserPost(post);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Na-post na! Makikita sa feed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gumawa ng Post'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('I-post'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedTopic,
            decoration: const InputDecoration(labelText: 'Column / Topic', border: OutlineInputBorder()),
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
              labelText: 'Sulat / Caption',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            maxLength: 500,
          ),
          const SizedBox(height: 16),
          const Text('Uri ng post', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<PostType>(
            segments: const [
              ButtonSegment(value: PostType.text, label: Text('Text'), icon: Icon(Icons.text_fields)),
              ButtonSegment(value: PostType.image, label: Text('Image'), icon: Icon(Icons.image)),
              ButtonSegment(value: PostType.video, label: Text('Video'), icon: Icon(Icons.videocam)),
              ButtonSegment(value: PostType.story, label: Text('Story'), icon: Icon(Icons.auto_stories)),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() {
                _type = s.first;
                if (_type == PostType.text) _pickedFile = null;
              });
            },
          ),
          const SizedBox(height: 20),
          if (_type == PostType.image || _type == PostType.video || _type == PostType.story) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: Text(_type == PostType.image ? 'Pumili ng Larawan' : 'Pumili ng Video'),
                    onPressed: () => _showPickerOptions(_type != PostType.image),
                  ),
                ),
              ],
            ),
            if (_pickedFile != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _type == PostType.image
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_pickedFile!, fit: BoxFit.cover),
                      )
                    : const Center(child: Icon(Icons.videocam, size: 48)),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _pickedFile = null),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Alisin ang media'),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Text(
            DataService().isReady
                ? 'Firebase ready – media will be uploaded to Storage.'
                : 'Firebase not configured yet – post will still work locally. Add google-services.json later for cloud sync & media upload.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
