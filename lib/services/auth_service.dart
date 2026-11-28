import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';

/// Email login. The user stays logged in until they press Sign out.
class AuthService extends ChangeNotifier {
  String? _userId;
  String? _displayName;
  String? _email;
  bool _isLoggedIn = false;
  bool _firebaseReady = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get displayName => _displayName;
  String? get email => _email;
  bool get isFirebaseMode => _firebaseReady;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseReady = true;
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) _apply(current);
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null) {
            _apply(user);
          } else if (_isLoggedIn && _userId != null && !_userId!.startsWith('local_')) {
            _clear();
          }
          notifyListeners();
        });
      }
    } catch (_) {
      _firebaseReady = false;
    }
    await _loadLocalSession();
  }

  void _apply(User user) {
    _userId = user.uid;
    _email = user.email;
    _displayName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName
        : _nameFromEmail(user.email ?? 'User');
    _isLoggedIn = true;
  }

  void _clear() {
    _userId = null;
    _email = null;
    _displayName = null;
    _isLoggedIn = false;
  }

  String _nameFromEmail(String email) =>
      email.contains('@') ? email.split('@').first : email;

  Future<void> _loadLocalSession() async {
    if (_isLoggedIn) return;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('userId');
    if (id != null) {
      _userId = id;
      _email = prefs.getString('email');
      _displayName = prefs.getString('displayName');
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  /// Returns null when OK, otherwise a short error message.
  Future<String?> signInWithEmail(String email, String password) async {
    final e = email.trim();
    if (!e.contains('@') || !e.contains('.')) return 'Wrong email.';
    if (password.length < 6) return 'Password: at least 6 characters.';
    if (_firebaseReady) {
      try {
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: e, password: password);
        if (cred.user != null) _apply(cred.user!);
        notifyListeners();
        await NotificationService().saveTokenForUser(_userId ?? '');
        return null;
      } on FirebaseAuthException catch (ex) {
        return _msg(ex);
      } catch (_) {
        return 'Cannot connect. Try again.';
      }
    }
    return _localLogin(e);
  }

  Future<String?> registerWithEmail(String email, String password) async {
    final e = email.trim();
    if (!e.contains('@') || !e.contains('.')) return 'Wrong email.';
    if (password.length < 6) return 'Password: at least 6 characters.';
    if (_firebaseReady) {
      try {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: e, password: password);
        await cred.user?.updateDisplayName(_nameFromEmail(e));
        if (cred.user != null) _apply(cred.user!);
        notifyListeners();
        await NotificationService().saveTokenForUser(_userId ?? '');
        return null;
      } on FirebaseAuthException catch (ex) {
        return _msg(ex);
      } catch (_) {
        return 'Cannot connect. Try again.';
      }
    }
    return _localLogin(e);
  }

  Future<String?> _localLogin(String e) async {
    final prefs = await SharedPreferences.getInstance();
    final id = 'local_${e.hashCode}';
    await prefs.setString('userId', id);
    await prefs.setString('email', e);
    await prefs.setString('displayName', _nameFromEmail(e));
    _userId = id;
    _email = e;
    _displayName = _nameFromEmail(e);
    _isLoggedIn = true;
    notifyListeners();
    return null;
  }

  String _msg(FirebaseAuthException ex) {
    switch (ex.code) {
      case 'email-already-in-use':
        return 'This email already has an account. Please sign in.';
      case 'invalid-email':
        return 'Wrong email.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'operation-not-allowed':
        return 'Email login is not turned on in Firebase yet.';
      case 'network-request-failed':
        return 'No internet.';
      default:
        return 'Failed (${ex.code}).';
    }
  }

  Future<void> signOut() async {
    if (_firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('displayName');
    _clear();
    notifyListeners();
  }

  bool requireLogin() => _isLoggedIn;
}
