import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('[NotificationService] Background message handled: ${message.messageId}');
  } catch (e) {
    debugPrint('[NotificationService] Background handler initialization failed: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'music_app_announcements',
    'Music App Announcements',
    description: 'Notifications for new releases, playlists, and updates.',
    importance: Importance.high,
    playSound: true,
  );

  bool _initialized = false;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initializes Firebase and sets up Cloud Messaging & local notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('[NotificationService] Initializing Firebase...');
      await Firebase.initializeApp();
      debugPrint('[NotificationService] Firebase App initialized.');

      // Setup background messaging handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions
      await _requestPermissions();

      // Configure Android notification channel
      if (!kIsWeb && Platform.isAndroid) {
        await _setupAndroidChannel();
      }

      // Configure Foreground notification presentation options (iOS & Android)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for incoming foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification opened app events
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);

      // Check if opened from a terminated state
      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpenedApp(initialMessage);
      }

      // Retrieve device FCM Token
      _fcmToken = await _fcm.getToken();
      debugPrint('[NotificationService] FCM Token: $_fcmToken');

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[NotificationService] FCM Token refreshed: $newToken');
      });

      _initialized = true;
      debugPrint('[NotificationService] Notification Service successfully initialized.');
    } catch (e, stack) {
      debugPrint('[NotificationService] Initialization warning/error: $e\n$stack');
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[NotificationService] User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupAndroidChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
    }

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[NotificationService] Local notification payload tapped: ${response.payload}');
      },
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[NotificationService] Foreground message received: ${message.notification?.title}');
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && !kIsWeb) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleNotificationOpenedApp(RemoteMessage message) {
    debugPrint('[NotificationService] App opened via notification: ${message.data}');
  }
}
