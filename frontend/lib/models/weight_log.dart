// lib/models/weight_log.dart

class WeightLog {
  final String id;
  final double weightKg;
  final DateTime createdAt;

  WeightLog({
    required this.id,
    required this.weightKg,
    required this.createdAt,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'],
      weightKg: (json['weight_kg'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}