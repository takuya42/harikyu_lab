import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FavoriteQuestionRepository {
  Stream<Set<String>> watchFavoriteIds();
  Future<void> toggle(String questionId);
}

class SharedPreferencesFavoriteQuestionRepository
    implements FavoriteQuestionRepository {
  SharedPreferencesFavoriteQuestionRepository(this._preferences);

  static const favoritesKey = 'favorite_question_ids_v1';
  final SharedPreferences _preferences;
  final _controller = StreamController<Set<String>>.broadcast();

  Set<String> get _ids =>
      Set.unmodifiable(_preferences.getStringList(favoritesKey) ?? const []);

  @override
  Stream<Set<String>> watchFavoriteIds() async* {
    yield _ids;
    yield* _controller.stream;
  }

  @override
  Future<void> toggle(String questionId) async {
    final ids = Set<String>.of(_ids);
    ids.contains(questionId) ? ids.remove(questionId) : ids.add(questionId);
    await _preferences.setStringList(favoritesKey, ids.toList()..sort());
    _controller.add(Set.unmodifiable(ids));
  }
}

final favoriteQuestionRepositoryProvider =
    FutureProvider<FavoriteQuestionRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return SharedPreferencesFavoriteQuestionRepository(preferences);
});

final favoriteQuestionIdsProvider = StreamProvider<Set<String>>((ref) async* {
  final repository = await ref.watch(favoriteQuestionRepositoryProvider.future);
  yield* repository.watchFavoriteIds();
});
