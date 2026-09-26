// lib/features/authentication/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../../../api/api_service.dart';
import '../../../api/api_exception.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../locator.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = locator<ApiService>();
  final SecureStorageService _storageService = locator<SecureStorageService>();

  bool _isAuthenticated = false;
  bool _isLoading = true; 
  String? _error;

  // --- NEW: DECLARATIVE VIEW TOGGLE ---
  bool _showLogin = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showLogin => _showLogin; // Getter

  AuthProvider() {
    checkInitialAuthStatus();
  }

  /// Toggles between the Login and SignUp views.
  void toggleAuthView() {
    _showLogin = !_showLogin;
    _error = null; // Clear any errors on transition
    notifyListeners();
  }

  Future<void> checkInitialAuthStatus() async {
    final accessToken = await _storageService.getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      _isAuthenticated = true;
    } else {
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _error = null;

    try {
      final tokenResponse = await _apiService.login(email: email, password: password);
      await _storageService.saveTokens(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken,
      );
      _isAuthenticated = true;
      print('AuthProvider: Login successful. isAuthenticated is now $_isAuthenticated');
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
    }
    
    notifyListeners();
  }

  Future<void> signUp(String username, String email, String password) async {
    _error = null;

    try {
      await _apiService.signUp(username: username, email: email, password: password);
      // On successful signup, automatically switch back to the login view.
      _showLogin = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
    }

    notifyListeners();
  }

  Future<void> logout() async {
    await _storageService.deleteTokens();
    _isAuthenticated = false;
    notifyListeners();
  }
}