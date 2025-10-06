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
  // This 'isLoading' is ONLY for the initial app startup check.
  bool _isLoading = true; 
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    checkInitialAuthStatus();
  }

  Future<void> checkInitialAuthStatus() async {
    final accessToken = await _storageService.getAccessToken();

    if (accessToken != null && accessToken.isNotEmpty) {
      _isAuthenticated = true;
    } else {
      _isAuthenticated = false;
    }

    _isLoading = false; // This is the ONLY place this should become false.
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    // THE FIX: Do NOT manage loading state here. Let the UI do it.
    _error = null;
    // We don't notify listeners here because the UI will show its own spinner.

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
    
    // Notify listeners at the very end to signal the process is complete.
    notifyListeners();
  }

  Future<void> signUp(String username, String email, String password) async {
    // THE FIX: Do NOT manage loading state here.
    _error = null;

    try {
      await _apiService.signUp(username: username, email: email, password: password);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
    }

    // We still notify here so the UI can check the error status.
    notifyListeners();
  }

  Future<void> logout() async {
    await _storageService.deleteTokens();
    _isAuthenticated = false;
    notifyListeners();
  }
}