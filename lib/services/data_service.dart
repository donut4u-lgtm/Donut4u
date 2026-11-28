import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/post.dart';
import '../models/comment.dart';

/// Handles Firestore + Storage when Firebase is configured.
/// If something fails, [lastError] says why (so the screen can show it).
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  bool _ready = false;
  final List<Post> _localUserPosts = [];
  final Map<String, List<Comment>> _localComments = {};

  /// Short reason of the last failure, or null when the last action worked.
  String? lastError;

  bool get isReady => _ready;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _ready = true;
      }
    } catch (_) {
      _ready = false;
    }
  }

  String _why(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
      return 'Not allowed by Firebase rules (permission denied).';
    }
    if (s.contains('unauthorized') || s.contains('object-not-found') ||
        s.contains('bucket-not-found') || s.contains('project-not-found')) {
      return 'Cloud storage is not available (Firebase Storage is off).';
    }
    if (s.contains('unavailable') || s.contains('network')) {
      return 'No internet.';
    }
    return s.length > 120 ? s.substring(0, 120) : s;
  }

  // ---------- POSTS ----------

  Future<void> saveUserPost(Post post) async {
    lastError = null;
    if (_ready) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .set(post.toMap())
            .timeout(const Duration(seconds: 15));
        return;
      } catch (e) {
        debugPrint('Firestore save post error: $e');
        lastError = _why(e);
      }
    }
    _localUserPosts.insert(0, post);
  }

  Future<List<Post>> fetchRecentUserPosts({int maxAgeMinutes = 120}) async {
    if (_ready) {
      try {
        final cutoff = DateTime.now().subtract(Duration(minutes: maxAgeMinutes));
        final snap = await FirebaseFirestore.instance
            .collection('posts')
            .where('createdAt', isGreaterThan: cutoff.toIso8601String())
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get()
            .timeout(const Duration(seconds: 15));
        return snap.docs.map((d) => Post.fromMap(d.data())).toList();
      } catch (e) {
        debugPrint('Firestore fetch posts error: $e');
      }
    }
    return _localUserPosts
        .where((p) => p.isStillFresh(maxAgeMinutes: maxAgeMinutes))
        .toList();
  }

  // ---------- MEDIA UPLOAD ----------

  /// Uploads a local file to Firebase Storage and returns the download URL.
  /// Returns null if it fails (see [lastError]).
  Future<String?> uploadMedia(File file, {required String folder}) async {
    lastError = null;
    if (!_ready) {
      lastError = 'Cloud is not connected.';
      return null;
    }
    try {
      final ext = file.path.split('.').last;
      final name = '${const Uuid().v4()}.$ext';
      final ref = FirebaseStorage.instance.ref().child('$folder/$name');
      await ref.putFile(file).timeout(const Duration(seconds: 60));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage upload error: $e');
      lastError = _why(e);
      return null;
    }
  }

  // ---------- COMMENTS ----------

  Future<void> addComment(Comment comment) async {
    lastError = null;
    if (_ready) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(comment.postId)
            .collection('comments')
            .doc(comment.id)
            .set(comment.toMap())
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Firestore add comment error: $e');
        lastError = _why(e);
        _localComments.putIfAbsent(comment.postId, () => []).add(comment);
        return;
      }
      // Counter is optional: crawled posts have no document, so ignore errors.
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(comment.postId)
            .update({'commentsCount': FieldValue.increment(1)});
      } catch (_) {}
      return;
    }
    _localComments.putIfAbsent(comment.postId, () => []).add(comment);
  }

  Future<List<Comment>> fetchComments(String postId) async {
    if (_ready) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .orderBy('createdAt', descending: false)
            .get()
            .timeout(const Duration(seconds: 15));
        final remote = snap.docs.map((d) => Comment.fromMap(d.data())).toList();
        return [...remote, ...(_localComments[postId] ?? [])];
      } catch (e) {
        debugPrint('Firestore fetch comments error: $e');
      }
    }
    return List.from(_localComments[postId] ?? []);
  }
}
