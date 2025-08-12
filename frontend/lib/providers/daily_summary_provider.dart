// lib/providers/daily_summary_provider.dart

import 'package:flutter/material.dart';
import '../api/api_exception.dart';
import '../models/daily_summary.dart';
import '../api/api_service.dart'; // We will add a method to this service next

class DailySummaryProvider with ChangeNotifier {
  DailySummary? _summary;
  bool _isLoading = false;
  String? _error;

  // Getters
  DailySummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final ApiService _apiService = ApiService();

  Future<void> fetchLatestSummary() async {
    _isLoading = true;
    _error = null;
    // We notify listeners here so the UI can immediately show a spinner inside the card.
    notifyListeners();

    try {
      // This part remains the same: first trigger generation, then fetch the result.
      await _apiService.generateDailySummary();
      final fetchedSummary = await _apiService.fetchDailySummary();
      _summary = fetchedSummary;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      // If ANY error occurs in the try block (from generate or fetch), we catch it here.
      print("DailySummaryProvider caught an error: $e");
      // We set our internal error state. The UI can decide what to show the user.
      _error = "An unexpected error occurred while getting the daily summary.";
      _summary = null; // Clear any old summary data
    } finally {
      // The 'finally' block ALWAYS runs, whether there was an error or not.
      // This is the perfect place to set isLoading to false.
      _isLoading = false;
      // Notify listeners one last time to update the UI with either the new data or the error state.
      notifyListeners();
    }
  }
}