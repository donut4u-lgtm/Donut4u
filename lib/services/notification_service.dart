import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId} – ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  /// Call once at app startup (after Firebase.initializeApp).
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Request permission (iOS + Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('User declined push permission');
        return;
      }

      // 2. Android local notifications channel
      const androidChannel = AndroidNotificationChannel(
        'donut4u_channel',
        'donut4u Notifications',
        description: 'New posts, comments, and viral updates',
        importance: Importance.high,
      );

      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      // 3. Background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Foreground messages → show local notification
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      // 5. When user taps a notification and app opens from background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

      // Check if app was opened from a terminated state via notification
      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        _handleMessageOpened(initial);
      }

      // 6. Get & store FCM token
      _fcmToken = await _fcm.getToken();
      debugPrint('FCM Token: $_fcmToken');
      await _saveToken(_fcmToken);

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await _saveToken(token);
        debugPrint('FCM Token refreshed: $token');
      });

      // Optional: subscribe to topics
      await _fcm.subscribeToTopic('all_users');
      await _fcm.subscribeToTopic('viral');
      await _fcm.subscribeToTopic('bago');

      _initialized = true;
      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('NotificationService init error (Firebase may not be configured): $e');
    }
  }

  Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title ?? 'donut4u',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'donut4u_channel',
          'donut4u Notifications',
          channelDescription: 'New posts, comments, and viral updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  void _handleMessageOpened(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    debugPrint('Notification tapped → data: $data');
  }

  /// Call this after a user logs in to associate the token with their account.
  Future<void> saveTokenForUser(String userId) async {
    if (_fcmToken == null) return;
    debugPrint('Would save FCM token for user $userId: $_fcmToken');
  }

  /// Unsubscribe from topics (e.g. on sign out)
  Future<void> unsubscribeAll() async {
    try {
      await _fcm.unsubscribeFromTopic('all_users');
      await _fcm.unsubscribeFromTopic('viral');
      await _fcm.unsubscribeFromTopic('bago');
    } catch (_) {}
  }
}
