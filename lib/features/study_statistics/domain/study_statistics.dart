class StudyStatistics {
  const StudyStatistics({
    this.todayStudyMinutes = 0,
    this.streakDays = 0,
    this.totalAnswered = 0,
    this.correctAnswered = 0,
  });

  final int todayStudyMinutes;
  final int streakDays;
  final int totalAnswered;
  final int correctAnswered;

  int get accuracy => totalAnswered == 0
      ? 0
      : (correctAnswered * 100 / totalAnswered).round();

  StudyStatistics copyWith({
    int? todayStudyMinutes,
    int? streakDays,
    int? totalAnswered,
    int? correctAnswered,
  }) => StudyStatistics(
    todayStudyMinutes: todayStudyMinutes ?? this.todayStudyMinutes,
    streakDays: streakDays ?? this.streakDays,
    totalAnswered: totalAnswered ?? this.totalAnswered,
    correctAnswered: correctAnswered ?? this.correctAnswered,
  );
}
