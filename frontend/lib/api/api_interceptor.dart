// lib/api/api_interceptor.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/services/secure_storage_service.dart';
import '../features/authentication/providers/auth_provider.dart';
import '../locator.dart';
import '../config.dart';
import 'api_exception.dart';

/// A custom HTTP client that automatically handles token refreshing.
/// It wraps the base http.Client and intercepts requests and responses.
class ApiInterceptor extends http.BaseClient {
  final http.Client _inner = http.Client();
  final SecureStorageService _storageService = locator<SecureStorageService>();

  // A mechanism to prevent multiple simultaneous token refresh attempts.
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Before sending any request, get the current access token.
    final accessToken = await _storageService.getAccessToken();

    // If a token exists, add the 'Authorization' header to the request.
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    request.headers['Content-Type'] = 'application/json';

    // Send the request and get the response.
    final response = await _inner.send(request);

    // Check if the response status code is 401 (Unauthorized).
    if (response.statusCode == 401) {
      // If the token is expired, we need to refresh it.
      // We use a Completer and a boolean flag to handle race conditions,
      // ensuring that we only attempt to refresh the token once, even if
      // multiple API calls fail simultaneously.
      if (!_isRefreshing) {
        _isRefreshing = true;
        _refreshCompleter = Completer<void>();
        
        try {
          await _refreshToken();
          _refreshCompleter!.complete();
        } catch (e) {
          _refreshCompleter!.completeError(e);
          // If refresh fails, log the user out.
          await locator<AuthProvider>().logout();
          throw ApiException('Your session has expired. Please log in again.');
        } finally {
          _isRefreshing = false;
        }
      }
      
      // Wait for the refresh process to complete.
      await _refreshCompleter!.future;

      // After a successful refresh, retry the original request with the new token.
      final newAccessToken = await _storageService.getAccessToken();
      if (newAccessToken != null) {
        // Create a new request by copying the original one.
        final newRequest = _copyRequest(request);
        newRequest.headers['Authorization'] = 'Bearer $newAccessToken';
        
        // Resend the request.
        return _inner.send(newRequest);
      }
    }
    
    // If the response is not 401, return it as is.
    return response;
  }

  /// Handles the logic for refreshing the authentication token.
  Future<void> _refreshToken() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null) {
      throw ApiException('No refresh token available.');
    }

    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/refresh-token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      // Save the new tokens. It's crucial to save the new refresh token
      // as it may have been rotated by the backend.
      await _storageService.saveTokens(
        accessToken: responseBody['access_token'],
        refreshToken: responseBody['refresh_token'],
      );
      print("Token successfully refreshed.");
    } else {
      // If the refresh token itself is invalid, the user must log in again.
      print("Failed to refresh token. Status: ${response.statusCode}");
      throw ApiException('Failed to refresh session.');
    }
  }

  /// Helper method to clone a request for retrying.
  http.BaseRequest _copyRequest(http.BaseRequest original) {
    if (original is http.Request) {
      final newRequest = http.Request(original.method, original.url)
        ..headers.addAll(original.headers)
        ..bodyBytes = original.bodyBytes;
      return newRequest;
    } else {
      // This is a simplified example. A full implementation would need to
      // handle different request types like MultipartRequest.
      throw UnimplementedError('Request type ${original.runtimeType} is not supported for retrying.');
    }
  }
}