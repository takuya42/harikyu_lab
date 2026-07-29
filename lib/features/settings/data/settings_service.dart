import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  Future<void> openContactEmail() async {
    final package = await PackageInfo.fromPlatform();
    final device = await _deviceDescription();
    final body = '''


---
アプリバージョン: ${package.version} (${package.buildNumber})
OS: ${defaultTargetPlatform.name}
端末: $device
''';
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {
        'subject': 'はりきゅうラボ お問い合わせ',
        'body': body,
      },
    );
    if (!await launchUrl(uri)) throw StateError('メールアプリを起動できませんでした。');
  }

  Future<String> _deviceDescription() async {
    final info = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final value = await info.androidInfo;
      return '${value.manufacturer} ${value.model} (Android ${value.version.release})';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final value = await info.iosInfo;
      return '${value.name} ${value.utsname.machine} (${value.systemVersion})';
    }
    return defaultTargetPlatform.name;
  }

  Future<void> resetLearningData() async {
    final keys = _preferences.getKeys().where(
      (key) =>
          key == 'favorite_question_ids_v1' ||
          key == 'mistake_question_ids_v1' ||
          key.startsWith('study_statistics_') ||
          key.startsWith('learning_history_'),
    );
    await Future.wait(keys.map(_preferences.remove));
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('ログインが必要です。');

    final userDocument = _firestore.collection('users').doc(user.uid);
    // Known per-user collections are removed before the parent document.
    for (final name in const [
      'favorites',
      'learningHistory',
      'mistakes',
      'statistics',
    ]) {
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
