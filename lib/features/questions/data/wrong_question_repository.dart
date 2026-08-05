import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/firebase_firestore_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';

const wrongQuestionsCollection = 'wrongQuestions';

class WrongQuestionEntry {
  const WrongQuestionEntry({
    required this.questionId,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String questionId;
  final String categoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WrongQuestionEntry.fromMap(Map<String, dynamic> data) =>
      WrongQuestionEntry(
        questionId: data['questionId'] as String? ?? '',
        categoryId: data['categoryId'] as String? ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
}

abstract interface class WrongQuestionRepository {
  Stream<List<WrongQuestionEntry>> watchWrongQuestions();
  Future<void> markWrong({required String questionId, required String categoryId});
  Future<void> markCorrect(String questionId);
}

class FirestoreWrongQuestionRepository implements WrongQuestionRepository {
  FirestoreWrongQuestionRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _wrongQuestions => _firestore
      .collection('users')
      .doc(_uid)
      .collection(wrongQuestionsCollection);

  @override
  Stream<List<WrongQuestionEntry>> watchWrongQuestions() => _wrongQuestions
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((document) => WrongQuestionEntry.fromMap(document.data()))
            .where((entry) => entry.questionId.isNotEmpty)
            .toList(growable: false),
      );

  @override
  Future<void> markWrong({
    required String questionId,
    required String categoryId,
  }) async {
    final reference = _wrongQuestions.doc(questionId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      transaction.set(reference, {
        'questionId': questionId,
        'categoryId': categoryId,
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> markCorrect(String questionId) =>
      _wrongQuestions.doc(questionId).delete();
}

final wrongQuestionRepositoryProvider = Provider<WrongQuestionRepository>((ref) {
  ref.watch(authStateProvider);
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw const WrongQuestionAuthenticationException();
  return FirestoreWrongQuestionRepository(
    ref.watch(firebaseFirestoreProvider),
    user.uid,
  );
});

class WrongQuestionAuthenticationException implements Exception {
  const WrongQuestionAuthenticationException();

  @override
  String toString() => 'ログインしてください';
}

final wrongQuestionEntriesProvider = StreamProvider<List<WrongQuestionEntry>>(
  (ref) => ref.watch(wrongQuestionRepositoryProvider).watchWrongQuestions(),
);
