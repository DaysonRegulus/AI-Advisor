// lib/models/water_log.dart

class WaterLog {
  final String id;
  final int amountMl;
  final DateTime createdAt;

  WaterLog({
    required this.id,
    required this.amountMl,
    required this.createdAt,
  });

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: json['id'],
      amountMl: json['amount_ml'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}