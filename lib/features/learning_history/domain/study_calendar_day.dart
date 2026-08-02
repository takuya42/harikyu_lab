class StudyCalendarDay {
  const StudyCalendarDay({
    required this.date,
    required this.answeredCount,
    required this.correctCount,
    required this.studySeconds,
    required this.examCount,
    required this.goalAchieved,
    required this.dailyGoal,
  });

  final DateTime date;
  final int answeredCount;
  final int correctCount;
  final int studySeconds;
  final int examCount;
  final bool goalAchieved;
  final int dailyGoal;

  factory StudyCalendarDay.fromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final parts = (data['date'] as String? ?? documentId).split('-');
    return StudyCalendarDay(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      answeredCount: (data['answeredCount'] as num?)?.toInt() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      studySeconds: (data['studySeconds'] as num?)?.toInt() ?? 0,
      examCount: (data['examCount'] as num?)?.toInt() ?? 0,
      goalAchieved: data['goalAchieved'] as bool? ?? false,
      dailyGoal: (data['dailyGoal'] as num?)?.toInt() ?? 10,
    );
  }
}
