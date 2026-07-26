import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/questions/data/favorite_question_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('お気に入りIDをトグルしてSharedPreferencesへ永続化する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository =
        SharedPreferencesFavoriteQuestionRepository(preferences);

    expect(await repository.watchFavoriteIds().first, isEmpty);

    await repository.toggle('q001');
    expect(await repository.watchFavoriteIds().first, {'q001'});
    expect(
      preferences.getStringList(
        SharedPreferencesFavoriteQuestionRepository.favoritesKey,
      ),
      ['q001'],
    );

    await repository.toggle('q001');
    expect(await repository.watchFavoriteIds().first, isEmpty);
  });
}
