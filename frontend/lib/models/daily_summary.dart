// lib/models/daily_summary.dart

class DailySummary {
  final String id;
  final String summaryText;
  final DateTime date;

  DailySummary({
    required this.id,
    required this.summaryText,
    required this.date,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      id: json['id'],
      summaryText: json['summary_text'],
      date: DateTime.parse(json['date']),
    );
  }
}