import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
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

    final keys = _preferences.getKeys().where(
      isLearningDataPreferenceKey,
    );
    await Future.wait(keys.map(_preferences.remove));
  }

  static bool isLearningDataPreferenceKey(String key) =>
      key == 'favorite_question_ids_v1' ||
      key.startsWith('study_statistics_') ||
      key.startsWith('learning_history_') ||
      key.startsWith('study_calendar_') ||
      key == 'daily_goal_v1';

  static const _learningCollections = [
    'favorites',
    'learningHistory',
    'statistics',
    'studyDays',
    'study_calendar',
  ];

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('ログインが必要です。');

    final userDocument = _firestore.collection('users').doc(user.uid);
    // Known per-user collections are removed before the parent document.
    for (final name in _learningCollections) {
      await _deleteCollection(userDocument.collection(name));
    }
    await userDocument.delete();
    await user.delete();
    await resetLearningData();
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

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  return SettingsService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    preferences: await ref.watch(sharedPreferencesProvider.future),
  );
});
