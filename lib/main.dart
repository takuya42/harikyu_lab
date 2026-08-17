import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/app/app.dart';
import 'package:harikyu_lab/core/notifications/push_notification_service.dart';
import 'package:harikyu_lab/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: HarikyuLabApp(),
    ),
  );

  // Notification setup is deliberately independent of Firebase Auth. It is
  // also non-blocking so a permission denial or APNs failure cannot prevent
  // the app from starting normally.
  unawaited(PushNotificationService.instance.initialize());
}
