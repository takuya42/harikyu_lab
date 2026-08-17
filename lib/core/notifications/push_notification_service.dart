import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:harikyu_lab/firebase_options.dart';

/// Handles push notifications without depending on the user's auth state.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const topic = 'harikyu_lab_all';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  Future<void> initialize() async {
    try {
      _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
        _subscribeTokenToTopic,
        onError: (Object error) {
          debugPrint('FCM token refresh failed: $error');
        },
      );

      _messageOpenedSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // A denied permission is not an error and does not gate token/topic setup.
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _waitForApnsTokenIfNeeded();
      final token = await _messaging.getToken();
      debugPrint('FCM TOKEN: $token');
      if (token != null) {
        await _subscribeTokenToTopic(token);
      }
    } catch (error, stackTrace) {
      // Push setup must never prevent guests (or signed-in users) from using the
      // app when permission is denied or notification services are unavailable.
      debugPrint('Push notification setup failed: $error\n$stackTrace');
    }
  }

  Future<void> _waitForApnsTokenIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    // FCM cannot issue an Apple-platform token until APNs registration finishes.
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await _messaging.getAPNSToken() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _subscribeTokenToTopic(String _) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (error) {
      debugPrint('FCM topic subscription failed: $error');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // App launch/resume is the intended behavior for now. Keeping the handler
    // centralised makes data-driven navigation straightforward to add later.
    debugPrint('Opened notification: ${message.messageId ?? '(no message id)'}');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
