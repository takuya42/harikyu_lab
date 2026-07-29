class StudyStatistics {
  const StudyStatistics({
    this.streakDays = 0,
    this.totalAnswered = 0,
    this.correctAnswered = 0,
  });

  final int streakDays;
  final int totalAnswered;
  final int correctAnswered;

  int get accuracy => totalAnswered == 0
      ? 0
      : (correctAnswered * 100 / totalAnswered).round();

  StudyStatistics copyWith({
    int? streakDays,
    int? totalAnswered,
    int? correctAnswered,
  }) => StudyStatistics(
    streakDays: streakDays ?? this.streakDays,
    totalAnswered: totalAnswered ?? this.totalAnswered,
    correctAnswered: correctAnswered ?? this.correctAnswered,
  );
}
