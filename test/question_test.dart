import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';

void main() {
  test('CSVをQuestionへ変換し、空のimageをnullにする', () {
    const csv = 'id,subject,category,question,choice1,choice2,choice3,choice4,answer,explanation,image\n'
        'q1,解剖学,骨格,問い,A,B,C,D,2,解説,\n';

    final questions = QuestionRepository().parseCsv(csv);

    expect(questions, hasLength(1));
    expect(questions.single.id, 'q1');
    expect(questions.single.choices, ['A', 'B', 'C', 'D']);
    expect(questions.single.correctChoiceIndex, 1);
    expect(questions.single.image, isNull);
  });

  test('必須列が不足したCSVは拒否する', () {
    expect(
      () => QuestionRepository().parseCsv('id,question\n1,問い'),
      throwsFormatException,
    );
  });
}
