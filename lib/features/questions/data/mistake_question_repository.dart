import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class MistakeQuestionRepository {
  Stream<Set<String>> watchMistakeIds();
  Future<void> add(String questionId);
}

class SharedPreferencesMistakeQuestionRepository
    implements MistakeQuestionRepository {
  SharedPreferencesMistakeQuestionRepository(this._preferences);

  static const mistakesKey = 'mistake_question_ids_v1';
  final SharedPreferences _preferences;
  final _controller = StreamController<Set<String>>.broadcast();

  Set<String> get _ids =>
      Set.unmodifiable(_preferences.getStringList(mistakesKey) ?? const []);

  @override
  Stream<Set<String>> watchMistakeIds() async* {
    yield _ids;
    yield* _controller.stream;
  }

  @override
  Future<void> add(String questionId) async {
    final ids = Set<String>.of(_ids)..add(questionId);
    await _preferences.setStringList(mistakesKey, ids.toList()..sort());
    _controller.add(Set.unmodifiable(ids));
  }
}

final mistakeQuestionRepositoryProvider =
    FutureProvider<MistakeQuestionRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return SharedPreferencesMistakeQuestionRepository(preferences);
});

final mistakeQuestionIdsProvider = StreamProvider<Set<String>>((ref) async* {
  final repository = await ref.watch(mistakeQuestionRepositoryProvider.future);
  yield* repository.watchMistakeIds();
});
