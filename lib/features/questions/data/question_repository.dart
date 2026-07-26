import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _cacheKey = 'questions_csv_cache_v1';
const _requiredColumns = {
  'id',
  'subject',
  'category',
  'question',
  'choice1',
  'choice2',
  'choice3',
  'choice4',
  'answer',
  'explanation',
  'image',
};

class QuestionRepository {
  QuestionRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Question>> fetchQuestions() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final response = await _client.get(
        Uri.parse(AppConstants.questionsSheetCsvUrl),
      );
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}');
      }
      final questions = parseCsv(utf8.decode(response.bodyBytes));
      await preferences.setString(
        _cacheKey,
        jsonEncode(questions.map((question) => question.toJson()).toList()),
      );
      return questions;
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached == null) rethrow;
      return (jsonDecode(cached) as List)
          .map((item) => Question.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    }
  }

  List<Question> parseCsv(String source) {
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(source.replaceAll('\r\n', '\n'));
    if (rows.isEmpty) throw const FormatException('CSV is empty');
    final headers = rows.first
        .map(
          (cell) => cell
              .toString()
              .trim()
              .replaceFirst('\ufeff', ''),
        )
        .toList();
    if (!_requiredColumns.every(headers.contains)) {
      throw const FormatException('CSV does not contain all required columns');
    }
    return rows
        .skip(1)
        .where((row) => row.any((cell) => '$cell'.isNotEmpty))
        .map((row) {
          final values = <String, String>{};
          for (var index = 0; index < headers.length; index++) {
            values[headers[index]] =
                index < row.length ? row[index].toString() : '';
          }
          return Question.fromCsvRow(values);
        })
        .toList(growable: false);
  }
}

final questionRepositoryProvider = Provider<QuestionRepository>(
  (ref) => QuestionRepository(),
);

final questionsProvider = FutureProvider<List<Question>>(
  (ref) => ref.watch(questionRepositoryProvider).fetchQuestions(),
);
