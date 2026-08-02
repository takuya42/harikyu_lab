import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LearningHistoryRepository {
  Stream<List<LearningHistory>> watch();
  Future<void> save(LearningHistory history);
  Future<void> refresh();
  void dispose();
}

/// Persists complete sessions per signed-in user. This repository keeps the
/// feature usable offline and can be replaced by a Firestore implementation
/// without affecting the presentation layer.
class LocalLearningHistoryRepository implements LearningHistoryRepository {
  LocalLearningHistoryRepository(this._preferences, {String? userId})
    : _key = 'learning_history_v1_${userId == null ? 'guest' : 'user_$userId'}' {
    _items = _read();
  }

  final SharedPreferences _preferences;
  final String _key;
  final _controller = StreamController<List<LearningHistory>>.broadcast();
  late List<LearningHistory> _items;

  List<LearningHistory> _read() {
    try {
      final value = _preferences.getString(_key);
      if (value == null) return const [];
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded
          .map((item) => LearningHistory.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    } on Object {
      return const [];
    }
  }

  @override
  Stream<List<LearningHistory>> watch() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<void> save(LearningHistory history) async {
    _items = [history, ..._items.where((item) => item.id != history.id)]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    await _preferences.setString(
      _key,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
    _controller.add(List.unmodifiable(_items));
  }

  @override
  Future<void> refresh() async {
    _items = _read();
    _controller.add(List.unmodifiable(_items));
  }

  @override
  void dispose() => _controller.close();
}

/// Stores completed learning sessions below `users/{uid}/studyDays`.
///
/// A session is intentionally kept as a separate document. This makes writes
/// idempotent and lets the calendar aggregate every kind of learning activity
/// without losing the detail needed by the day sheet.
class FirestoreLearningHistoryRepository implements LearningHistoryRepository {
  FirestoreLearningHistoryRepository(this._firestore, this._userId);

  final FirebaseFirestore _firestore;
  final String _userId;

  CollectionReference<Map<String, dynamic>> get _sessions => _firestore
      .collection('users')
      .doc(_userId)
      .collection('studyDays');

  @override
  Stream<List<LearningHistory>> watch() => _sessions
      .orderBy('completedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_fromDocument).toList());

  LearningHistory _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    final completedAt = data['completedAt'];
    data['id'] = document.id;
    data['completedAt'] = completedAt is Timestamp
        ? completedAt.toDate().toIso8601String()
        : completedAt;
    return LearningHistory.fromJson(data);
  }

  @override
  Future<void> save(LearningHistory history) async {
    final data = history.toJson()..remove('id');
    data['completedAt'] = Timestamp.fromDate(history.completedAt);
    data['studyDate'] =
        '${history.completedAt.year.toString().padLeft(4, '0')}-'
        '${history.completedAt.month.toString().padLeft(2, '0')}-'
        '${history.completedAt.day.toString().padLeft(2, '0')}';
    await _sessions.doc(history.id).set(data);
  }

  @override
  Future<void> refresh() async => _sessions.limit(1).get();

  @override
  void dispose() {}
}

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final learningHistoryRepositoryProvider = FutureProvider<LearningHistoryRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  final user = await ref.watch(authStateProvider.future);
  final LearningHistoryRepository repository = user == null
      ? LocalLearningHistoryRepository(preferences)
      : FirestoreLearningHistoryRepository(
          ref.watch(firebaseFirestoreProvider),
          user.uid,
        );
  ref.onDispose(repository.dispose);
  return repository;
});

final learningHistoryProvider = StreamProvider<List<LearningHistory>>((ref) async* {
  final repository = await ref.watch(learningHistoryRepositoryProvider.future);
  yield* repository.watch();
});
