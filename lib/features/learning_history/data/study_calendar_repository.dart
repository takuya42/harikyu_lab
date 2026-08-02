import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:harikyu_lab/features/learning_history/domain/study_calendar_day.dart';
import 'package:harikyu_lab/features/settings/data/settings_service.dart';

const defaultDailyGoal = 10;
const dailyGoalOptions = [5, 10, 20, 30, 50, 100];

String studyDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

abstract interface class StudyCalendarRepository {
  Stream<List<StudyCalendarDay>> watch();
  Stream<int> watchDailyGoal();
  Future<void> recordStudy(LearningHistory history);
  Future<void> updateDailyGoal(int dailyGoal);
  Future<void> refresh();
}

class FirestoreStudyCalendarRepository implements StudyCalendarRepository {
  FirestoreStudyCalendarRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _user =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _days =>
      _user.collection('study_calendar');

  @override
  Stream<List<StudyCalendarDay>> watch() => _days.snapshots().map((snapshot) {
    debugPrint('Loaded ${snapshot.docs.length} study calendar documents');
    return snapshot.docs
        .map((document) => StudyCalendarDay.fromMap(document.id, document.data()))
        .toList(growable: false);
  });

  @override
  Stream<int> watchDailyGoal() => _user.snapshots().map(
    (snapshot) =>
        (snapshot.data()?['dailyGoal'] as num?)?.toInt() ?? defaultDailyGoal,
  );

  @override
  Future<void> recordStudy(LearningHistory history) async {
    final date = studyDateKey(history.completedAt);
    final answeredCount = history.answeredCount;
    final correctCount = history.correctCount;
    debugPrint(
      'recordStudy: uid=$_uid date=$date answered=$answeredCount correct=$correctCount',
    );

    final reference = _days.doc(date);
    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(_user);
      final dailyGoal =
          (userSnapshot.data()?['dailyGoal'] as num?)?.toInt() ??
          defaultDailyGoal;
      final daySnapshot = await transaction.get(reference);
      final currentAnswered =
          (daySnapshot.data()?['answeredCount'] as num?)?.toInt() ?? 0;
      final nextAnswered = currentAnswered + answeredCount;

      // A transaction is used because goalAchieved depends on the accumulated
      // answer count. All counters are still written atomically in one commit.
      transaction.set(reference, {
        'answeredCount': FieldValue.increment(answeredCount),
        'correctCount': FieldValue.increment(correctCount),
        'studySeconds': FieldValue.increment(history.duration.inSeconds),
        'examCount': FieldValue.increment(
          history.type == LearningType.mockExam ? 1 : 0,
        ),
        'goalAchieved': nextAnswered >= dailyGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    debugPrint('Firestore study_calendar updated');
  }

  @override
  Future<void> updateDailyGoal(int dailyGoal) async {
    final key = studyDateKey(DateTime.now());
    final reference = _days.doc(key);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      transaction.set(_user, {'dailyGoal': dailyGoal}, SetOptions(merge: true));
      if (!snapshot.exists) return;
      final answered =
          (snapshot.data()?['answeredCount'] as num?)?.toInt() ?? 0;
      transaction.update(reference, {
        'goalAchieved': answered >= dailyGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> refresh() async => _days.limit(1).get();
}

final studyCalendarRepositoryProvider =
    FutureProvider<StudyCalendarRepository>((ref) async {
      final auth = ref.watch(firebaseAuthProvider);
      final authUser = await ref.watch(authStateProvider.future);
      final user = authUser ?? (await auth.signInAnonymously()).user;
      if (user == null) throw StateError('ユーザーを作成できませんでした。');
      return FirestoreStudyCalendarRepository(
        ref.watch(firebaseFirestoreProvider),
        user.uid,
      );
    });

final studyCalendarProvider = StreamProvider<List<StudyCalendarDay>>((ref) async* {
  final repository = await ref.watch(studyCalendarRepositoryProvider.future);
  yield* repository.watch();
});

final dailyGoalProvider = StreamProvider<int>((ref) async* {
  final repository = await ref.watch(studyCalendarRepositoryProvider.future);
  yield* repository.watchDailyGoal();
});
