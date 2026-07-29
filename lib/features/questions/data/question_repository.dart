import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const googleSheetsCsvUrl = String.fromEnvironment(
  'QUESTIONS_SHEET_CSV_URL',
  defaultValue:
      'https://docs.google.com/spreadsheets/d/e/2PACX-1vTSyFXi-NgrS9YokHo5i183yOzt-c-7L00tR4qN4plO-ezWOcn_dpgrxgFXGXhGjILIMuJ0h0qViTCB/pub?output=csv',
);

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
    String cacheKey = 'questions_cache_v1',
  })  : _client = client,
        _preferences = preferences,
        _sheetUrl = sheetUrl,
        _cacheKey = cacheKey;

  final http.Client _client;
  final SharedPreferences _preferences;
  final String _sheetUrl;
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
      throw StateError('QUESTIONS_SHEET_CSV_URL が設定されていません。');
    }
    final response = await _client
        .get(Uri.parse(_sheetUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('問題データの取得に失敗しました (${response.statusCode})');
    }
    final questions = _parseCsv(utf8.decode(response.bodyBytes));
    if (questions.isEmpty) throw const FormatException('問題データが空です。');
    await _preferences.setString(
      _cacheKey,
      jsonEncode(questions.map((question) => question.toJson()).toList()),
    );
    return List.unmodifiable(questions);
  }

  List<Question> _parseCsv(String source) {
    final table = _csvRows(source);
    if (table.isEmpty) return const [];
    final headers = table.first.map((value) => value.trim()).toList();
    if (headers.isNotEmpty) headers[0] = headers[0].replaceFirst('\ufeff', '');
    return table
        .skip(1)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .map((row) {
      final values = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        values[headers[index]] = index < row.length ? row[index].trim() : '';
      }
      return Question.fromSheetRow(values);
    }).toList();
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

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

final questionRepositoryProvider = FutureProvider<QuestionRepository>(
  (ref) async => GoogleSheetsQuestionRepository(
    client: ref.watch(httpClientProvider),
    preferences: await ref.watch(sharedPreferencesProvider.future),
    sheetUrl: googleSheetsCsvUrl,
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
  return ref.watch(questionsProvider).whenData(
        (questions) => subject == null
            ? questions
            : List.unmodifiable(
                questions.where((question) => question.subject == subject),
              ),
      );
});
