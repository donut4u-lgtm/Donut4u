import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';

/// Works in two modes:
/// 1. Firebase mode (when Firebase is configured) – real accounts, syncs across devices
/// 2. Local mode (fallback) – display-name only, stored on device
class AuthService extends ChangeNotifier {
  String? _userId;
  String? _displayName;
  bool _isLoggedIn = false;
  bool _firebaseReady = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get displayName => _displayName;
  bool get isFirebaseMode => _firebaseReady;

  Future<void> initialize() async {
    try {
      // Will only succeed if google-services.json / Firebase options are present
      if (Firebase.apps.isNotEmpty) {
        _firebaseReady = true;
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null) {
            _userId = user.uid;
            _displayName = user.displayName ?? user.email ?? 'User';
            _isLoggedIn = true;
          } else {
            _userId = null;
            _displayName = null;
            _isLoggedIn = false;
          }
          notifyListeners();
        });
      }
    } catch (_) {
      _firebaseReady = false;
    }
    if (!_firebaseReady) {
      await loadLocalSession();
    }
  }

  Future<void> loadLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _displayName = prefs.getString('displayName');
    _isLoggedIn = _userId != null;
    notifyListeners();
  }

  /// Simple display-name sign-in (local or sets Firebase displayName)
  Future<bool> signInWithDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    if (_firebaseReady) {
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        await cred.user?.updateDisplayName(trimmed);
        _userId = cred.user?.uid;
        _displayName = trimmed;
        _isLoggedIn = true;
        notifyListeners();
        await NotificationService().saveTokenForUser(_userId ?? '');
        return true;
      } catch (e) {
        debugPrint('Firebase sign-in failed: $e');
        // fall through to local
      }
    }

    // Local fallback
    final prefs = await SharedPreferences.getInstance();
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('userId', id);
    await prefs.setString('displayName', trimmed);
    _userId = id;
    _displayName = trimmed;
    _isLoggedIn = true;
    notifyListeners();
    await NotificationService().saveTokenForUser(_userId ?? '');
    return true;
  }

  Future<void> signOut() async {
    if (_firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('displayName');
    _userId = null;
    _displayName = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  bool requireLogin() => _isLoggedIn;
}
