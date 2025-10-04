// lib/features/authentication/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../../../api/api_service.dart';
import '../../../api/api_exception.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../locator.dart';

class AuthProvider with ChangeNotifier {
  // Dependencies from our service locator
  final ApiService _apiService = locator<ApiService>();
  final SecureStorageService _storageService = locator<SecureStorageService>();

  // Private state variables
  bool _isAuthenticated = false;
  bool _isLoading = true; // Start in loading state for initial check
  String? _error;

  // Public getters to allow the UI to read the state
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Constructor: Immediately check for a stored token when the app starts.
  AuthProvider() {
    checkInitialAuthStatus();
  }

  /// Checks secure storage for a token on app startup.
  Future<void> checkInitialAuthStatus() async {
    final accessToken = await _storageService.getAccessToken();

    // If a token exists, we consider the user authenticated.
    // A more robust implementation might also validate the token with the backend here.
    if (accessToken != null && accessToken.isNotEmpty) {
      _isAuthenticated = true;
      // Set the token in the ApiService for future requests
      _apiService.setAuthToken(accessToken);
    } else {
      _isAuthenticated = false;
      _apiService.setAuthToken(null);
    }

    _isLoading = false; // Finished the initial check
    notifyListeners(); // Notify UI to update
  }

  /// Handles user login.
  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call the API service to get the tokens
      final tokenResponse = await _apiService.login(email: email, password: password);

      // Save the tokens securely
      await _storageService.saveTokens(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken,
      );

      // Set the token in the ApiService
      _apiService.setAuthToken(tokenResponse.accessToken);

      // Update the state to authenticated
      _isAuthenticated = true;

      print('AuthProvider: Login successful. isAuthenticated is now $_isAuthenticated');
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handles new user registration.
  Future<void> signUp(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call the API service to create the new user
      await _apiService.signUp(username: username, email: email, password: password);
      // After signup, the user still needs to log in, so we don't change _isAuthenticated.
      // The error state will be null if successful.
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handles user logout.
  Future<void> logout() async {
    // Delete tokens from secure storage
    await _storageService.deleteTokens();

    // Clear the token from the ApiService
    _apiService.setAuthToken(null);

    // Update the state to unauthenticated
    _isAuthenticated = false;
    notifyListeners();
  }
}