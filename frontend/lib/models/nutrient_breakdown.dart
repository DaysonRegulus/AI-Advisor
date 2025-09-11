// lib/models/nutrient_breakdown.dart
class NutrientBreakdown {
  final double totalCalories;
  final Map<String, double> macros;
  final Map<String, double> micros;

  NutrientBreakdown({
    required this.totalCalories,
    required this.macros,
    required this.micros,
  });

  factory NutrientBreakdown.fromJson(Map<String, dynamic> json) {
    return NutrientBreakdown(
      totalCalories: (json['total_calories'] as num).toDouble(),
      // Safely cast the maps
      macros: (json['macros'] as Map).map((key, value) => MapEntry(key, (value as num).toDouble())),
      micros: (json['micros'] as Map).map((key, value) => MapEntry(key, (value as num).toDouble())),
    );
  }
}