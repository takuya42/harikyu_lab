import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/firebase_firestore_provider.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsService {
  SettingsService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required SharedPreferences preferences,
  }) : _auth = auth,
       _firestore = firestore,
       _preferences = preferences;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SharedPreferences _preferences;

  Future<void> openExternalUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      throw StateError('URLを開けませんでした。');
    }
  }

  Future<void> resetLearningData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDocument = _firestore.collection('users').doc(user.uid);
      for (final collection in _learningCollections) {
        await _deleteCollection(userDocument.collection(collection));
      }
    }

    await resetLocalLearningData();
  }

  Future<void> resetLocalLearningData() async {
    final keys = _preferences.getKeys().where(
      isLearningDataPreferenceKey,
    );
    await Future.wait(keys.map(_preferences.remove));
  }

  static bool isLearningDataPreferenceKey(String key) =>
      key.startsWith('favorite_question_ids_v1') ||
      key.startsWith('study_statistics_') ||
      key.startsWith('learning_history_') ||
      key.startsWith('study_calendar_') ||
      key == 'daily_goal_v1';

  // Detailed answer history stays on-device. Firestore contains only the
  // calendar aggregate used by the learning screens.
  static const _learningCollections = ['study_calendar'];

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('ログインが必要です。');

    await _deleteAccountWithCloudFunction(user);
    await resetLocalLearningData();
  }

  Future<void> _deleteAccountWithCloudFunction(User user) async {
    final projectId = Firebase.app().options.projectId;
    if (projectId == null || projectId.isEmpty) {
      throw StateError('FirebaseプロジェクトIDを取得できませんでした。');
    }

    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('認証情報を取得できませんでした。');
    }

    final response = await http.post(
      Uri.https(
        'us-central1-$projectId.cloudfunctions.net',
        'deleteCurrentUserAccount',
      ),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': <String, Object?>{}}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final message = _callableErrorMessage(response.body);
    throw StateError(message ?? '退会処理に失敗しました。時間をおいてもう一度お試しください。');
  }

  String? _callableErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final snapshot = await ref.limit(100).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  return SettingsService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    preferences: await ref.watch(sharedPreferencesProvider.future),
  );
});
