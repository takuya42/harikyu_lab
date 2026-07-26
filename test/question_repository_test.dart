import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _csv = '''id,question,choice1,choice2,choice3,choice4,correctAnswer,explanation,category
q001,"カンマ,を含む問題",選択1,選択2,選択3,選択4,2,解説,基礎''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('スプレッドシートのCSVをQuestionへ変換してキャッシュする', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = GoogleSheetsQuestionRepository(
      client: MockClient((_) async => http.Response(_csv, 200)),
      preferences: preferences,
      sheetUrl: 'https://example.com/questions.csv',
    );

    final questions = await repository.watchQuestions().first;

    expect(questions.single.id, 'q001');
    expect(questions.single.text, 'カンマ,を含む問題');
    expect(questions.single.correctAnswerIndex, 1);
    expect(preferences.getString('questions_cache_v1'), isNotNull);
  });

  test('通信エラー時は保存済みキャッシュを返す', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final successfulRepository = GoogleSheetsQuestionRepository(
      client: MockClient((_) async => http.Response(_csv, 200)),
      preferences: preferences,
      sheetUrl: 'https://example.com/questions.csv',
    );
    await successfulRepository.watchQuestions().first;
    final offlineRepository = GoogleSheetsQuestionRepository(
      client: MockClient((_) async => http.Response('', 503)),
      preferences: preferences,
      sheetUrl: 'https://example.com/questions.csv',
    );

    final questions = await offlineRepository.watchQuestions().toList();

    expect(questions, hasLength(1));
    expect(questions.single.single.id, 'q001');
  });
}
