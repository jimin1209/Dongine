import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dongine/core/constants/firestore_paths.dart';
import 'package:dongine/firebase_options.dart';

typedef NotificationRouteHandler = Future<void> Function(String route);
typedef ForegroundNotificationHandler =
    void Function(String title, String body);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestoreInstance = firestore,
       _messagingInstance = messaging;

  FirebaseFirestore? _firestoreInstance;
  FirebaseMessaging? _messagingInstance;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  bool _isConfigured = false;
  String? _activeUid;

  Future<void> configure({
    required NotificationRouteHandler onOpenRoute,
    required ForegroundNotificationHandler onForegroundNotification,
  }) async {
    if (_isConfigured) return;
    _isConfigured = true;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM authorization status: ${settings.authorizationStatus}');

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      final uid = _activeUid;
      if (uid == null) return;

      unawaited(_saveToken(uid, token));
    });

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) {
      final notification = message.notification;
      final title = notification?.title ?? '새 알림';
      final body =
          notification?.body ?? _buildForegroundMessageBody(message.data);

      if (title.isEmpty && body.isEmpty) return;
      onForegroundNotification(title, body);
    });

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final route = extractRoute(message.data);
      if (route == null) return;
      unawaited(onOpenRoute(route));
    });

    final initialMessage = await _messaging.getInitialMessage();
    final initialRoute = extractRoute(initialMessage?.data ?? const {});
    if (initialRoute != null) {
      await onOpenRoute(initialRoute);
    }
  }

  Future<void> registerCurrentDevice(String uid) async {
    _activeUid = uid;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _saveToken(uid, token);
  }

  Future<void> unregisterCurrentDevice(String uid) async {
    final token = await _messaging.getToken();
    if (_activeUid == uid) {
      _activeUid = null;
    }

    if (token == null || token.isEmpty) return;

    await _firestore.doc(FirestorePaths.user(uid)).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  void setActiveUser(String? uid) {
    _activeUid = uid;
  }

  static String? extractRoute(Map<String, dynamic> data) {
    final route = data['route'];
    if (route is! String || route.isEmpty) return null;
    if (!route.startsWith('/')) return null;
    return route;
  }

  Future<void> _saveToken(String uid, String token) async {
    await _firestore.doc(FirestorePaths.user(uid)).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastSeen': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static String buildForegroundMessageBody(Map<String, dynamic> data) {
    final type = data['type'];
    if (type is String && type.isNotEmpty) {
      return '$type 알림이 도착했습니다.';
    }

    return '새 알림이 도착했습니다.';
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
  }
}
