import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/firebase_firestore_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';

const mockExamAttemptCountField = 'mockExamAttemptCount';

abstract interface class MockExamAttemptService {
  Future<bool> tryStart({required bool isPro});
}

class FirestoreMockExamAttemptService implements MockExamAttemptService {
  FirestoreMockExamAttemptService(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  @override
  Future<bool> tryStart({required bool isPro}) async {
    if (isPro) return true;
    final user = _firestore.collection('users').doc(_uid);
    final today = user
        .collection(studyCalendarCollection)
        .doc(studyDateKey(DateTime.now()));
    return _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(user);
      if (userSnapshot.data()?['plan'] == 'pro') return true;
      final daySnapshot = await transaction.get(today);
      final attempts =
          (daySnapshot.data()?[mockExamAttemptCountField] as num?)?.toInt() ?? 0;
      if (attempts >= 1) return false;
      transaction.set(today, {
        'date': studyDateKey(DateTime.now()),
        mockExamAttemptCountField: FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    });
  }
}

final mockExamAttemptServiceProvider = Provider<MockExamAttemptService>((ref) {
  ref.watch(authStateProvider);
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return _SignedOutMockExamAttemptService();
  return FirestoreMockExamAttemptService(
    ref.watch(firebaseFirestoreProvider),
    user.uid,
  );
});

class _SignedOutMockExamAttemptService implements MockExamAttemptService {
  @override
  Future<bool> tryStart({required bool isPro}) async => false;
}
