import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _csv = '''id,subject,category,question,choice1,choice2,choice3,choice4,answer,explanation,image
q001,解剖学,基礎,"カンマ,を含む問題",選択1,選択2,選択3,選択4,2,"複数行の
解説",https://example.com/image.png''';

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
    expect(questions.single.subject, '解剖学');
    expect(questions.single.category, '基礎');
    expect(questions.single.explanation, '複数行の\n解説');
    expect(questions.single.imageUrl, 'https://example.com/image.png');
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

  test('キャッシュを先に返してから更新された問題を返す', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final initialRepository = GoogleSheetsQuestionRepository(
      client: MockClient((_) async => http.Response(_csv, 200)),
      preferences: preferences,
      sheetUrl: 'https://example.com/questions.csv',
    );
    await initialRepository.refresh();
    final updatedCsv = _csv.replaceFirst('カンマ,を含む問題', '更新された問題');
    final repository = GoogleSheetsQuestionRepository(
      client: MockClient((_) async => http.Response(updatedCsv, 200)),
      preferences: preferences,
      sheetUrl: 'https://example.com/questions.csv',
    );

    final emissions = await repository.watchQuestions().toList();

    expect(emissions, hasLength(2));
    expect(emissions.first.single.text, 'カンマ,を含む問題');
    expect(emissions.last.single.text, '更新された問題');
  });
}
