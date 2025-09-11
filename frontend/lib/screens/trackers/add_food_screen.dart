// lib/screens/trackers/add_food_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_service.dart';
import '../../providers/food_timeline_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../locator.dart';

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({Key? key}) : super(key: key);

  @override
  _AddFoodScreenState createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isDetailed = false;
  String _selectedMealType = 'Breakfast';

  // --- A map for easier controller management ---
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'calories': TextEditingController(),
    'protein': TextEditingController(),
    'carbs': TextEditingController(),
    'fat': TextEditingController(),
    'fiber': TextEditingController(),
    'sugar': TextEditingController(),
    'sodium': TextEditingController(),
    'potassium': TextEditingController(),
    'saturated_fat': TextEditingController(),
    'cholesterol': TextEditingController(),
    'calcium': TextEditingController(),
  };

  bool _isSaving = false;

  @override
  void dispose() {
    // It's crucial to dispose controllers to prevent memory leaks
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // Helper to safely parse text to double, returning 0 if invalid
  double _parse_double(String key) {
    return double.tryParse(_controllers[key]!.text) ?? 0.0;
  }

  Future<void> _saveFood() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isSaving = true; });

    final apiService = locator<ApiService>();

    try {
      final newLog = await apiService.logFood(
        foodName: _controllers['name']!.text,
        mealType: _selectedMealType,
        calories: _parse_double('calories'),
        macros: {
          "protein": _parse_double('protein'),
          "carbs": _parse_double('carbs'),
          "fat": _parse_double('fat'),
        },
        micros: _isDetailed ? {
          "fiber": _parse_double('fiber'),
          "sugar": _parse_double('sugar'),
          "sodium": _parse_double('sodium'),
          "potassium": _parse_double('potassium'),
          "saturated_fat": _parse_double('saturated_fat'),
          "cholesterol": _parse_double('cholesterol'),
          "calcium": _parse_double('calcium'),
        } : null, // Send NULL if not in detailed mode
      );

      if (newLog != null && mounted) {
        // Optimistically update all relevant providers
        context.read<FoodTimelineProvider>().addFoodLog(newLog);
        context.read<DashboardProvider>().fetchDashboardData();
        context.read<UserProfileProvider>().fetchUserProfile();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food logged successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  // Helper to create a TextFormField for a nutrient
  Widget _buildNumericField(String key, String label, {bool isRequired = false}) {
    return TextFormField(
      controller: _controllers[key],
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Food"),
        actions: [
          if (_isSaving) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else IconButton(icon: const Icon(Icons.check), onPressed: _saveFood)
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _controllers['name'],
              decoration: const InputDecoration(labelText: 'Food Name*'),
              validator: (value) => (value == null || value.isEmpty) ? 'Food name is required' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedMealType,
              items: ['Breakfast', 'Lunch', 'Dinner', 'Snacks'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (newValue) => setState(() => _selectedMealType = newValue!),
              decoration: const InputDecoration(labelText: 'Meal Type*'),
            ),
            _buildNumericField('calories', 'Calories (kcal)*', isRequired: true),
            const SizedBox(height: 16),
            const Text("Macros", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildNumericField('protein', 'Protein (g)'),
            _buildNumericField('carbs', 'Carbohydrates (g)'),
            _buildNumericField('fat', 'Fat (g)'),

            SwitchListTile(
              title: const Text("Add Detailed Nutrients"),
              value: _isDetailed,
              onChanged: (value) => setState(() => _isDetailed = value),
              activeColor: Colors.green,
            ),

            if (_isDetailed) ...[
              const Divider(height: 20),
              const Text("Micro-nutrients", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              _buildNumericField('fiber', 'Dietary Fiber (g)'),
              _buildNumericField('sugar', 'Sugar (g)'),
              _buildNumericField('sodium', 'Sodium (mg)'),
              _buildNumericField('potassium', 'Potassium (mg)'),
              _buildNumericField('saturated_fat', 'Saturated Fat (g)'),
              _buildNumericField('cholesterol', 'Cholesterol (mg)'),
              _buildNumericField('calcium', 'Calcium (mg)'),
            ]
          ],
        ),
      ),
    );
  }
}