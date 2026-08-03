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
        SharedPreferencesFavoriteQuestionRepository.keyForUser(null),
      ),
      ['q001'],
    );

    await repository.toggle('q001');
    expect(await repository.watchFavoriteIds().first, isEmpty);
  });

  test('お気に入りIDをユーザーごとに分離して再起動後も復元する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstUser = SharedPreferencesFavoriteQuestionRepository(
      preferences,
      userId: 'user-a',
    );
    final secondUser = SharedPreferencesFavoriteQuestionRepository(
      preferences,
      userId: 'user-b',
    );

    await firstUser.toggle('q001');
    await secondUser.toggle('q002');

    final restartedFirstUser = SharedPreferencesFavoriteQuestionRepository(
      preferences,
      userId: 'user-a',
    );
    expect(await restartedFirstUser.watchFavoriteIds().first, {'q001'});
    expect(await secondUser.watchFavoriteIds().first, {'q002'});
  });
}
