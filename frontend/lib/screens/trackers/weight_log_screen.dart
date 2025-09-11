// lib/screens/trackers/weight_log_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_service.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../locator.dart';

class WeightLogScreen extends StatefulWidget {
  const WeightLogScreen({Key? key}) : super(key: key);

  @override
  _WeightLogScreenState createState() => _WeightLogScreenState();
}

class _WeightLogScreenState extends State<WeightLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _weightController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveWeight() async {
    print("--- Save Weight Initiated ---");
    // 1. Validate the form input
    if (!_formKey.currentState!.validate()) {
      print("Validation failed. Aborting.");
      return;
    }

    setState(() { _isSaving = true; });
    print("State set to 'isSaving = true'.");

    final weight = double.tryParse(_weightController.text);
    if (weight == null) {
      // This should ideally not happen due to the validator, but it's a good safety check
      print("Could not parse weight string to double. Aborting.");
      setState(() { _isSaving = false; });
      return;
    }
    print("Successfully parsed weight: $weight");

    final apiService = locator<ApiService>();
    final dashboardProvider = context.read<DashboardProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();

    try {
      // 2. Call the API to save the weight
      print("Calling apiService.logWeight...");
      final newLog = await apiService.logWeight(weight);
      print("apiService.logWeight call completed.");

      if (newLog != null && mounted) {
        // 3. Optimistically update the dashboard state
        print("Log successful. Updating providers and UI.");
        dashboardProvider.logNewWeight(newLog);
        
        // 4. Check for XP award
        // The backend handles the logic, but we need to update the UI
        // A more advanced system would have the backend response tell us if XP was awarded.
        // For now, we assume the backend is correct and re-fetch the user profile.
        print("Fetching updated user profile for XP...");
        await userProfileProvider.fetchUserProfile();
        print("User profile fetch complete.");
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight logged successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
        print("Navigation complete.");

      } else {
        // This 'else' block will catch cases where the API returns a non-201 status but doesn't throw an exception.
        print("API call returned null or widget is unmounted. Failed to save log.");
        throw Exception("Failed to save log. API returned an unexpected response.");
      }
    } catch (e) {
      print("--- ERROR CAUGHT ---");
      print("Error object type: ${e.runtimeType}");
      print("Error message: ${e.toString()}");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      print("--- Finally Block Reached ---");
      if(mounted) {
        print("Widget is mounted. Setting 'isSaving = false'.");
        setState(() { _isSaving = false; });
      } else {
        print("Widget is unmounted. Not setting state.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Weight"),
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _saveWeight)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _weightController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Current Weight (kg)",
                  border: OutlineInputBorder(),
                  suffixText: "kg",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your weight';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // We can add a historical chart here later
            ],
          ),
        ),
      ),
    );
  }
}