import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/post.dart';
import '../models/comment.dart';

/// Handles Firestore + Storage when Firebase is configured.
/// Falls back to in-memory lists when Firebase is not ready (still fully usable).
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  bool _ready = false;
  final List<Post> _localUserPosts = [];
  final Map<String, List<Comment>> _localComments = {};

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

  // ---------- POSTS ----------

  Future<void> saveUserPost(Post post) async {
    if (_ready) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(post.id).set(post.toMap());
        return;
      } catch (e) {
        debugPrint('Firestore save post error: $e');
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
            .get();
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
  /// Returns null if Firebase is not ready or upload fails.
  Future<String?> uploadMedia(File file, {required String folder}) async {
    if (!_ready) return null;
    try {
      final ext = file.path.split('.').last;
      final name = '${const Uuid().v4()}.$ext';
      final ref = FirebaseStorage.instance.ref().child('$folder/$name');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage upload error: $e');
      return null;
    }
  }

  // ---------- COMMENTS ----------

  Future<void> addComment(Comment comment) async {
    if (_ready) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(comment.postId)
            .collection('comments')
            .doc(comment.id)
            .set(comment.toMap());

        // increment count
        await FirebaseFirestore.instance.collection('posts').doc(comment.postId).update({
          'commentsCount': FieldValue.increment(1),
        });
        return;
      } catch (e) {
        debugPrint('Firestore add comment error: $e');
      }
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
            .get();
        return snap.docs.map((d) => Comment.fromMap(d.data())).toList();
      } catch (e) {
        debugPrint('Firestore fetch comments error: $e');
      }
    }
    return List.from(_localComments[postId] ?? []);
  }
}
