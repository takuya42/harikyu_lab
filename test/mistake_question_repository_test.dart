import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/questions/data/mistake_question_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('間違えた問題を重複せずSharedPreferencesへ保存する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository =
        SharedPreferencesMistakeQuestionRepository(preferences);

    await repository.add('question-2');
    await repository.add('question-1');
    await repository.add('question-2');

    expect(
      preferences.getStringList(
        SharedPreferencesMistakeQuestionRepository.mistakesKey,
      ),
      ['question-1', 'question-2'],
    );
    expect(await repository.watchMistakeIds().first, {
      'question-1',
      'question-2',
    });
  });
}
