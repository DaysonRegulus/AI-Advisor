// lib/screens/trackers/weight_log_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../api/api_service.dart';
import '../../locator.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/weight_log_provider.dart';
import '../../models/chart_data_point.dart';

class WeightLogScreen extends StatelessWidget {
  const WeightLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We wrap the screen in our new provider
    return ChangeNotifierProvider(
      create: (context) => WeightLogProvider(locator<ApiService>()),
      child: const _WeightLogScreenContent(),
    );
  }
}

class _WeightLogScreenContent extends StatefulWidget {
  const _WeightLogScreenContent({Key? key}) : super(key: key);

  @override
  _WeightLogScreenContentState createState() => _WeightLogScreenContentState();
}

class _WeightLogScreenContentState extends State<_WeightLogScreenContent> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _weightController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch initial 7-day chart data when the screen loads
      context.read<WeightLogProvider>().fetchChartData();
    });
  }

  Future<void> _saveWeight() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; });

    final weight = double.tryParse(_weightController.text);
    if (weight == null) {
      setState(() { _isSaving = false; });
      return;
    }
    
    final weightProvider = context.read<WeightLogProvider>();
    try {
      final newLog = await locator<ApiService>().logWeight(weight);
      if (newLog != null && mounted) {
        context.read<DashboardProvider>().logNewWeight(newLog);
        await context.read<UserProfileProvider>().fetchUserProfile();
        
        // After saving, refresh the chart data
        await weightProvider.fetchChartData(period: weightProvider.selectedPeriod);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight logged!'), backgroundColor: Colors.green));
        _weightController.clear(); // Clear input after successful save
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Log Weight")),
      body: ListView( // Use ListView to accommodate the form and the chart
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Input Form Section ---
          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Current Weight (kg)", border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null || double.parse(v) <= 0) ? 'Enter a valid weight' : null,
                  ),
                ),
                const SizedBox(width: 16),
                _isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _saveWeight,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                        child: const Text("Save"),
                      ),
              ],
            ),
          ),
          const Divider(height: 48),

          // --- Chart Section ---
          const Text("Weight History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Consumer<WeightLogProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  // Toggle Buttons for 7D/30D
                  ToggleButtons(
                    isSelected: [
                      provider.selectedPeriod == ChartPeriod.sevenDays,
                      provider.selectedPeriod == ChartPeriod.thirtyDays,
                    ],
                    onPressed: (index) {
                      final period = index == 0 ? ChartPeriod.sevenDays : ChartPeriod.thirtyDays;
                      provider.fetchChartData(period: period);
                    },
                    children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("7 Days")), Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("30 Days"))],
                  ),
                  const SizedBox(height: 24),
                  // The Chart
                  provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.chartData.isEmpty
                          ? const Center(child: Text("Not enough data to display a chart."))
                          : SizedBox(height: 200, child: _WeightChart(data: provider.chartData)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- A dedicated widget for the FL Chart ---
class _WeightChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  const _WeightChart({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Find min and max values for the y-axis
    final minY = data.map((d) => d.value).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = data.map((d) => d.value).reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: _bottomTitles),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.map((point) => FlSpot(point.date.millisecondsSinceEpoch.toDouble(), point.value)).toList(),
            isCurved: true,
            color: Colors.green,
            barWidth: 4,
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }

  SideTitles get _bottomTitles => SideTitles(
    showTitles: true,
    getTitlesWidget: (value, meta) {
      final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      return Text(DateFormat('d MMM').format(date)); // Format as "15 Jul"
    },
  );
}