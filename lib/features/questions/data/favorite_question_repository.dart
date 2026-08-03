import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FavoriteQuestionRepository {
  Stream<Set<String>> watchFavoriteIds();
  Future<void> toggle(String questionId);
}

class SharedPreferencesFavoriteQuestionRepository
    implements FavoriteQuestionRepository {
  SharedPreferencesFavoriteQuestionRepository(
    this._preferences, {
    String? userId,
  }) : _favoritesKey = keyForUser(userId);

  static const favoritesKey = 'favorite_question_ids_v1';
  final SharedPreferences _preferences;
  final String _favoritesKey;
  final _controller = StreamController<Set<String>>.broadcast();

  static String keyForUser(String? userId) =>
      '${favoritesKey}_${userId == null ? 'guest' : 'user_$userId'}';

  Set<String> get _ids =>
      Set.unmodifiable(
        _preferences.getStringList(_favoritesKey) ??
            (_favoritesKey == keyForUser(null)
                ? _preferences.getStringList(favoritesKey)
                : null) ??
            const [],
      );

  @override
  Stream<Set<String>> watchFavoriteIds() async* {
    final initialIds = _ids;
    debugPrint('Favorite count: ${initialIds.length}');
    yield initialIds;
    await for (final ids in _controller.stream) {
      debugPrint('Favorite count: ${ids.length}');
      yield ids;
    }
  }

  @override
  Future<void> toggle(String questionId) async {
    final ids = Set<String>.of(_ids);
    ids.contains(questionId) ? ids.remove(questionId) : ids.add(questionId);
    await _preferences.setStringList(_favoritesKey, ids.toList()..sort());
    _controller.add(Set.unmodifiable(ids));
  }

  void dispose() => _controller.close();
}

final favoriteQuestionRepositoryProvider =
    FutureProvider<FavoriteQuestionRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  ref.watch(authStateProvider);
  final user = ref.watch(firebaseAuthProvider).currentUser;
  final repository = SharedPreferencesFavoriteQuestionRepository(
    preferences,
    userId: user?.uid,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final favoriteQuestionIdsProvider = StreamProvider<Set<String>>((ref) async* {
  final repository = await ref.watch(favoriteQuestionRepositoryProvider.future);
  yield* repository.watchFavoriteIds();
});
