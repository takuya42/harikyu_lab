import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/constants/question_sheet_constants.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String categoryCsvUrl(String category) {
  final gid = questionSheetGids[category];
  if (gid == null || gid.isEmpty) {
    throw StateError('カテゴリ「$category」の gid が設定されていません。');
  }
  return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/'
      'export?format=csv&gid=$gid';
}

const mockExamGoogleSheetsCsvUrl = String.fromEnvironment(
  'MOCK_EXAM_SHEET_CSV_URL',
  defaultValue:
      'https://docs.google.com/spreadsheets/d/e/2PACX-1vToUSFPQQ_mswZBqNCIQd7TunBKimDs2IQx2SU8t0pfB3CnJzSkeYvRKM5P9t87TOpvhCUu1h-oYnEE/pub?output=csv',
);

abstract interface class QuestionRepository {
  /// Emits the local cache first, then the latest spreadsheet contents.
  Stream<List<Question>> watchQuestions();

  /// Downloads the latest questions and replaces the local cache.
  Future<List<Question>> refresh();
}

class GoogleSheetsQuestionRepository implements QuestionRepository {
  GoogleSheetsQuestionRepository({
    required http.Client client,
    required SharedPreferences preferences,
    required String sheetUrl,
    this.gid,
    String cacheKey = 'questions_cache_v1',
  })  : _client = client,
        _preferences = preferences,
        _sheetUrl = sheetUrl,
        _cacheKey = cacheKey;

  final http.Client _client;
  final SharedPreferences _preferences;
  final String _sheetUrl;
  final String? gid;
  final String _cacheKey;

  @override
  Stream<List<Question>> watchQuestions() async* {
    final cached = _readCache();
    if (cached != null) {
      yield cached;
      try {
        final latest = await refresh();
        if (!_sameQuestions(cached, latest)) yield latest;
      } on Object {
        // The already emitted cache remains visible when background sync fails.
      }
      return;
    }
    yield await refresh();
  }

  bool _sameQuestions(List<Question> first, List<Question> second) =>
      jsonEncode(first.map((item) => item.toJson()).toList()) ==
      jsonEncode(second.map((item) => item.toJson()).toList());

  List<Question>? _readCache() {
    final value = _preferences.getString(_cacheKey);
    if (value == null) return null;
    try {
      final rows = jsonDecode(value) as List<dynamic>;
      return List.unmodifiable(rows.map(
        (row) => Question.fromJson(Map<String, dynamic>.from(row as Map)),
      ));
    } on Object {
      _preferences.remove(_cacheKey);
      return null;
    }
  }

  @override
  Future<List<Question>> refresh() async {
    if (_sheetUrl.isEmpty) {
      throw StateError('CSV URL が設定されていません。');
    }
    final url = _sheetUrl;
    if (gid != null) debugPrint('CSV gid: $gid');
    debugPrint('CSV URL: $url');
    late final http.Response response;
    try {
      response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
    } on Object catch (error) {
      debugPrint(
        '[QuestionRepository] fetch failed statusCode=unavailable '
        'url=$_sheetUrl error=$error',
      );
      rethrow;
    }
    if (response.statusCode != 200) {
      debugPrint(
        '[QuestionRepository] fetch failed statusCode=${response.statusCode} '
        'url=$_sheetUrl',
      );
      throw http.ClientException(
        '問題データの取得に失敗しました (${response.statusCode})',
        Uri.parse(_sheetUrl),
      );
    }
    final csv = utf8.decode(response.bodyBytes);
    final table = _csvRows(csv);
    for (var index = 0; index < table.length && index < 5; index++) {
      debugPrint('CSV row ${index + 1}: ${table[index]}');
    }
    debugPrint('CSV total rows: ${table.length}');
    final questions = _parseCsv(table);
    debugPrint('CSV fetched count: ${questions.length}');
    debugPrint(
      '[QuestionRepository] spreadsheet question count=${questions.length}',
    );
    debugPrint(
      '[QuestionRepository] first 5 categories='
      '${questions.take(5).map((question) => question.category).toList()}',
    );
    if (questions.isEmpty) throw const FormatException('問題データが空です。');
    await _preferences.setString(
      _cacheKey,
      jsonEncode(questions.map((question) => question.toJson()).toList()),
    );
    return List.unmodifiable(questions);
  }

  List<Question> _parseCsv(List<List<String>> table) {
    if (table.isEmpty) return const [];
    final headers = table.first.map((value) => value.trim()).toList();
    if (headers.isNotEmpty) headers[0] = headers[0].replaceFirst('\ufeff', '');
    final questions = <Question>[];
    for (var index = 1; index < table.length; index++) {
      final row = table[index];
      if (!row.any((cell) => cell.trim().isNotEmpty)) continue;
      final values = <String, String>{};
      for (var column = 0; column < headers.length; column++) {
        values[headers[column]] =
            column < row.length ? row[column].trim() : '';
      }
      final rowNumber = index + 1;
      questions.add(Question.fromSheetRow(
        values,
        fallbackId: 'row_$rowNumber',
        rowNumber: rowNumber,
      ));
    }
    return questions;
  }

  List<List<String>> _csvRows(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (character == '"') {
        if (quoted && index + 1 < source.length && source[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((character == '\n' || character == '\r') && !quoted) {
        if (character == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else {
        field.write(character);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final questionRepositoryProvider = FutureProvider<QuestionRepository>(
  (ref) async => GoogleSheetsQuestionRepository(
    client: ref.watch(httpClientProvider),
    preferences: await ref.watch(sharedPreferencesProvider.future),
    sheetUrl: categoryCsvUrl('医療概論'),
    gid: questionSheetGids['医療概論'],
  ),
);

final questionsProvider = StreamProvider<List<Question>>((ref) async* {
  final repository = await ref.watch(questionRepositoryProvider.future);
  yield* repository.watchQuestions();
});

final mockExamQuestionRepositoryProvider = FutureProvider<QuestionRepository>(
  (ref) async => GoogleSheetsQuestionRepository(
    client: ref.watch(httpClientProvider),
    preferences: await ref.watch(sharedPreferencesProvider.future),
    sheetUrl: mockExamGoogleSheetsCsvUrl,
    cacheKey: 'mock_exam_questions_cache_v1',
  ),
);

final mockExamQuestionsProvider = StreamProvider<List<Question>>((ref) async* {
  final repository = await ref.watch(mockExamQuestionRepositoryProvider.future);
  yield* repository.watchQuestions();
});

final subjectQuestionsProvider =
    Provider.family<AsyncValue<List<Question>>, String?>((ref, subject) {
  if (subject != null) return ref.watch(categoryQuestionsProvider(subject));
  return ref.watch(questionsProvider).whenData(
        (questions) => filterQuestionsByCategory(questions, subject),
      );
});

final categoryQuestionRepositoryProvider =
    FutureProvider.family<QuestionRepository, String>((ref, category) async {
  final gid = questionSheetGids[category];
  return GoogleSheetsQuestionRepository(
    client: ref.watch(httpClientProvider),
    preferences: await ref.watch(sharedPreferencesProvider.future),
    sheetUrl: categoryCsvUrl(category),
    gid: gid,
    cacheKey: 'questions_cache_category_$category',
  );
});

final categoryQuestionsProvider =
    StreamProvider.family<List<Question>, String>((ref, category) async* {
  final repository =
      await ref.watch(categoryQuestionRepositoryProvider(category).future);
  final questions = repository.watchQuestions();
  await for (final items in questions) {
    yield filterQuestionsByCategory(items, category);
  }
});

/// Loads every category so favorites created outside the quick-quiz category
/// can also be resolved to their complete question data.
final allQuestionsProvider = FutureProvider<List<Question>>((ref) async {
  final categoryQuestions = await Future.wait(
    questionSheetGids.keys.map(
      (category) => ref.watch(categoryQuestionsProvider(category).future),
    ),
  );
  final questionsById = <String, Question>{};
  for (final questions in categoryQuestions) {
    for (final question in questions) {
      questionsById[question.id] = question;
    }
  }
  return List.unmodifiable(questionsById.values);
});

/// Filters the category selected in the UI against the spreadsheet category.
///
/// Older sheets stored the same value in `subject`, so that column remains a
/// compatibility fallback while `category` is the canonical filter field.
List<Question> filterQuestionsByCategory(
  List<Question> questions,
  String? category,
) {
  debugPrint('[QuestionRepository] category filter="$category"');
  debugPrint(
    '[QuestionRepository] first 5 categories='
    '${questions.take(5).map((question) => question.category).toList()}',
  );
  if (category == null) {
    debugPrint(
      '[QuestionRepository] filtered question count=${questions.length}',
    );
    return questions;
  }

  final normalizedCategory = category.trim();
  final filtered = List<Question>.unmodifiable(
    questions.where(
      (question) => question.category.trim() == normalizedCategory ||
          question.subject.trim() == normalizedCategory,
    ),
  );
  debugPrint(
    '[QuestionRepository] filtered question count=${filtered.length} '
    'category="$category"',
  );
  return filtered;
}
