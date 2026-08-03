import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LearningHistoryRepository {
  Stream<List<LearningHistory>> watch();
  Future<void> save(LearningHistory history);
  Future<void> refresh();
  void dispose();
}

/// Persists complete sessions per signed-in user. This repository keeps the
/// answer details on the device rather than sending them to Firestore.
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

final learningHistoryRepositoryProvider =
    FutureProvider<LearningHistoryRepository>((ref) async {
      final preferences = await ref.watch(sharedPreferencesProvider.future);
      final user = await ref.watch(authStateProvider.future);
      final LearningHistoryRepository repository =
          LocalLearningHistoryRepository(preferences, userId: user?.uid);
      ref.onDispose(repository.dispose);
      return repository;
    });

final learningHistoryProvider = StreamProvider<List<LearningHistory>>(
  (ref) async* {
    final repository = await ref.watch(
      learningHistoryRepositoryProvider.future,
    );
    yield* repository.watch();
  },
);
