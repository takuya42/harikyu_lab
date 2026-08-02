import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/data/learning_history_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:harikyu_lab/features/learning_history/domain/study_calendar_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dailyGoalPreferenceKey = 'daily_goal_v1';
const defaultDailyGoal = 10;
const dailyGoalOptions = [5, 10, 20, 30, 50, 100];

String studyDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

abstract interface class StudyCalendarRepository {
  Stream<List<StudyCalendarDay>> watch();
  Future<void> addSession(LearningHistory history);
  Future<void> updateTodayGoal(int dailyGoal);
  Future<void> refresh();
  void dispose();
}

class FirestoreStudyCalendarRepository implements StudyCalendarRepository {
  FirestoreStudyCalendarRepository(this._firestore, this._uid, this._preferences);

  final FirebaseFirestore _firestore;
  final String _uid;
  final SharedPreferences _preferences;

  CollectionReference<Map<String, dynamic>> get _days => _firestore
      .collection('users')
      .doc(_uid)
      .collection('study_calendar');

  @override
  Stream<List<StudyCalendarDay>> watch() => _days.snapshots().map(
    (snapshot) => snapshot.docs
        .map((document) => StudyCalendarDay.fromMap(document.id, document.data()))
        .toList(),
  );

  @override
  Future<void> addSession(LearningHistory history) async {
    final key = studyDateKey(history.completedAt);
    final reference = _days.doc(key);
    final goal = _preferences.getInt(dailyGoalPreferenceKey) ?? defaultDailyGoal;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = snapshot.data();
      final answered = (current?['answeredCount'] as num?)?.toInt() ?? 0;
      final nextAnswered = answered + history.answeredCount;
      transaction.set(reference, {
        'date': key,
        'answeredCount': nextAnswered,
        'correctCount': ((current?['correctCount'] as num?)?.toInt() ?? 0) +
            history.correctCount,
        'studySeconds': ((current?['studySeconds'] as num?)?.toInt() ?? 0) +
            history.duration.inSeconds,
        'examCount': ((current?['examCount'] as num?)?.toInt() ?? 0) +
            (history.type == LearningType.mockExam ? 1 : 0),
        'goalAchieved': nextAnswered >= goal,
        'dailyGoal': goal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> updateTodayGoal(int dailyGoal) async {
    final key = studyDateKey(DateTime.now());
    final reference = _days.doc(key);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final answered = (snapshot.data()?['answeredCount'] as num?)?.toInt() ?? 0;
      transaction.update(reference, {
        'dailyGoal': dailyGoal,
        'goalAchieved': answered >= dailyGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> refresh() async => _days.limit(1).get();

  @override
  void dispose() {}
}

class LocalStudyCalendarRepository implements StudyCalendarRepository {
  LocalStudyCalendarRepository(this._preferences) {
    _items = _read();
  }

  final SharedPreferences _preferences;
  final _controller = StreamController<List<StudyCalendarDay>>.broadcast();
  static const _key = 'study_calendar_v1_guest';
  late Map<String, StudyCalendarDay> _items;

  Map<String, StudyCalendarDay> _read() {
    final value = _preferences.getString(_key);
    if (value == null) return {};
    try {
      final data = Map<String, dynamic>.from(jsonDecode(value) as Map);
      return data.map(
        (key, value) => MapEntry(
          key,
          StudyCalendarDay.fromMap(key, Map<String, dynamic>.from(value as Map)),
        ),
      );
    } on Object {
      return {};
    }
  }

  Future<void> _persist() async {
    await _preferences.setString(
      _key,
      jsonEncode({
        for (final entry in _items.entries)
          entry.key: {
            'date': entry.key,
            'answeredCount': entry.value.answeredCount,
            'correctCount': entry.value.correctCount,
            'studySeconds': entry.value.studySeconds,
            'examCount': entry.value.examCount,
            'goalAchieved': entry.value.goalAchieved,
            'dailyGoal': entry.value.dailyGoal,
          },
      }),
    );
    _controller.add(List.unmodifiable(_items.values));
  }

  @override
  Stream<List<StudyCalendarDay>> watch() async* {
    yield List.unmodifiable(_items.values);
    yield* _controller.stream;
  }

  @override
  Future<void> addSession(LearningHistory history) async {
    final key = studyDateKey(history.completedAt);
    final old = _items[key];
    final goal = _preferences.getInt(dailyGoalPreferenceKey) ?? defaultDailyGoal;
    final answered = (old?.answeredCount ?? 0) + history.answeredCount;
    _items[key] = StudyCalendarDay(
      date: history.completedAt,
      answeredCount: answered,
      correctCount: (old?.correctCount ?? 0) + history.correctCount,
      studySeconds: (old?.studySeconds ?? 0) + history.duration.inSeconds,
      examCount: (old?.examCount ?? 0) +
          (history.type == LearningType.mockExam ? 1 : 0),
      goalAchieved: answered >= goal,
      dailyGoal: goal,
    );
    await _persist();
  }

  @override
  Future<void> updateTodayGoal(int dailyGoal) async {
    final key = studyDateKey(DateTime.now());
    final old = _items[key];
    if (old == null) return;
    _items[key] = StudyCalendarDay(
      date: old.date,
      answeredCount: old.answeredCount,
      correctCount: old.correctCount,
      studySeconds: old.studySeconds,
      examCount: old.examCount,
      goalAchieved: old.answeredCount >= dailyGoal,
      dailyGoal: dailyGoal,
    );
    await _persist();
  }

  @override
  Future<void> refresh() async {
    _items = _read();
    _controller.add(List.unmodifiable(_items.values));
  }

  @override
  void dispose() => _controller.close();
}

final studyCalendarRepositoryProvider = FutureProvider<StudyCalendarRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  final user = await ref.watch(authStateProvider.future);
  final repository = user == null
      ? LocalStudyCalendarRepository(preferences)
      : FirestoreStudyCalendarRepository(
          ref.watch(firebaseFirestoreProvider),
          user.uid,
          preferences,
        );
  ref.onDispose(repository.dispose);
  return repository;
});

final studyCalendarProvider = StreamProvider<List<StudyCalendarDay>>((ref) async* {
  final repository = await ref.watch(studyCalendarRepositoryProvider.future);
  yield* repository.watch();
});

class DailyGoalNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    return preferences.getInt(dailyGoalPreferenceKey) ?? defaultDailyGoal;
  }

  Future<void> setGoal(int value) async {
    if (!dailyGoalOptions.contains(value)) return;
    final previous = state.asData?.value ?? defaultDailyGoal;
    state = AsyncData(value);
    try {
      final preferences = await ref.read(sharedPreferencesProvider.future);
      await preferences.setInt(dailyGoalPreferenceKey, value);
      await (await ref.read(studyCalendarRepositoryProvider.future))
          .updateTodayGoal(value);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final dailyGoalProvider = AsyncNotifierProvider<DailyGoalNotifier, int>(
  DailyGoalNotifier.new,
);
