// lib/models/food_log.dart
class FoodLog {
  final String id;
  final String foodName;
  final String mealType;
  final double calories;
  final DateTime createdAt;
  // Add other fields as needed later
  
  FoodLog({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.calories,
    required this.createdAt,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'],
      foodName: json['food_name'],
      mealType: json['meal_type'],
      calories: (json['calories'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}