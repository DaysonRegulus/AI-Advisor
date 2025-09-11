// lib/models/chart_data_point.dart
class ChartDataPoint {
  final DateTime date;
  final double value;

  ChartDataPoint({required this.date, required this.value});

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      date: DateTime.parse(json['log_date']),
      value: (json['avg_weight'] as num).toDouble(),
    );
  }
}