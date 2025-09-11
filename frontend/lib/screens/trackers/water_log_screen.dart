// lib/screens/trackers/water_log_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_service.dart';
import '../../locator.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';

class WaterLogScreen extends StatefulWidget {
  const WaterLogScreen({Key? key}) : super(key: key);

  @override
  _WaterLogScreenState createState() => _WaterLogScreenState();
}

class _WaterLogScreenState extends State<WaterLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveWater() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isSaving = true; });

    final amount = int.tryParse(_amountController.text);
    if (amount == null) {
      setState(() { _isSaving = false; });
      return;
    }

    final apiService = locator<ApiService>();
    final dashboardProvider = context.read<DashboardProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();

    try {
      // Note: logWater does not return the created object, but we don't need it for this screen.
      await apiService.logWater(amount);
      
      if (mounted) {
        // Optimistically update the dashboard and award XP
        dashboardProvider.addWater(amount);
        userProfileProvider.awardXpForEvent('water_log', 5);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Water intake logged! +5 XP'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Water Intake"),
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _saveWater)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount (ml)",
                  border: OutlineInputBorder(),
                  suffixText: "ml",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Historical chart for water intake can be added here later
            ],
          ),
        ),
      ),
    );
  }
}