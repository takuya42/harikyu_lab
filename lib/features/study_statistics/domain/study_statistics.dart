class StudyStatistics {
  const StudyStatistics({
    this.totalAnswered = 0,
    this.correctAnswered = 0,
  });

  final int totalAnswered;
  final int correctAnswered;

  int get accuracy => totalAnswered == 0
      ? 0
      : (correctAnswered * 100 / totalAnswered).round();

  StudyStatistics copyWith({
    int? totalAnswered,
    int? correctAnswered,
  }) => StudyStatistics(
    totalAnswered: totalAnswered ?? this.totalAnswered,
    correctAnswered: correctAnswered ?? this.correctAnswered,
  );
}
