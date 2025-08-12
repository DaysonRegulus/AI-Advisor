// lib/providers/user_profile_provider.dart

import 'package:flutter/material.dart';
import '../api/api_exception.dart' ;
import '../models/user_profile.dart';
import '../api/api_service.dart';

// This class 'mixes in' ChangeNotifier, which gives it the ability
// to notify its listeners (our UI widgets) of any changes.
class UserProfileProvider with ChangeNotifier {
  String? _error;
  String? get error => _error;
  UserProfile? _userProfile;
  final ApiService _apiService = ApiService();
  // Add a new state variable to track if the initial fetch is done.
  bool _isInitialFetchDone = false;

  // 'getters' to allow UI to safely access the state
  UserProfile? get userProfile => _userProfile; 
  // Change the definition of isLoading to be more specific
  bool get isLoading => !_isInitialFetchDone;

  // We will trigger the fetch from the UI for more control.
  UserProfileProvider();

  // --- Methods to interact with the state ---

  Future<void> fetchUserProfile() async {
    _error = null;
    // If we've already fetched, don't show a full-screen loader again.
    // This method can now be used for silent refreshes.
    if (!_isInitialFetchDone) {
      notifyListeners(); // Tell the UI we are now loading
    }

    // In a real app, we'd fetch from an endpoint. For now, we simulate.
    try {
      _userProfile = await _apiService.fetchUserProfile();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = "An unexpected error occurred.";
    }

    _isInitialFetchDone = true;
    notifyListeners(); // Tell the UI we are done loading and provide the data
  }

  Future<void> awardXpForEvent(String eventName, int amount) async {
    print("Provider is awarding $amount XP for $eventName");
    // Call the API to do the actual work
    final updatedProfile = await _apiService.awardXp(eventName, amount);
    
    if (updatedProfile != null) {
      _userProfile = updatedProfile;
      // If the user leveled up, you could trigger a special animation or dialog here!
      if (updatedProfile.leveledUp) {
        print("LEVEL UP DETECTED IN PROVIDER!");
        // (Future enhancement: show a cool animation)
      }
      notifyListeners(); // This is the magic! It tells listening widgets to rebuild.
    }
  }
}