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
class ApiInterceptor extends http.BaseClient {
  final http.Client _inner = http.Client();
  final SecureStorageService _storageService = locator<SecureStorageService>();

  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // THE FIX: Check if this is a public authentication request.
    // We do not want to attach auth headers or handle 401s for signup, login, or refresh.
    final bool isAuthRoute = request.url.path.contains('/auth/login') ||
                             request.url.path.contains('/auth/signup') ||
                             request.url.path.contains('/auth/refresh-token');

    if (!isAuthRoute) {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken != null) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    
    request.headers['Content-Type'] = 'application/json';

    // Send the request.
    final response = await _inner.send(request);

    // THE FIX: Only trigger the refresh logic if we get a 401 AND this is NOT a public auth route.
    if (response.statusCode == 401 && !isAuthRoute) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        _refreshCompleter = Completer<void>();
        
        try {
          await _refreshToken();
          _refreshCompleter!.complete();
        } catch (e) {
          _refreshCompleter!.completeError(e);
          await locator<AuthProvider>().logout();
          throw ApiException('Your session has expired. Please log in again.');
        } finally {
          _isRefreshing = false;
        }
      }
      
      await _refreshCompleter!.future;

      final newAccessToken = await _storageService.getAccessToken();
      if (newAccessToken != null) {
        final newRequest = _copyRequest(request);
        newRequest.headers['Authorization'] = 'Bearer $newAccessToken';
        return _inner.send(newRequest);
      }
    }
    
    return response;
  }

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
      await _storageService.saveTokens(
        accessToken: responseBody['access_token'],
        refreshToken: responseBody['refresh_token'],
      );
      print("Token successfully refreshed.");
    } else {
      print("Failed to refresh token. Status: ${response.statusCode}");
      throw ApiException('Failed to refresh session.');
    }
  }

  http.BaseRequest _copyRequest(http.BaseRequest original) {
    if (original is http.Request) {
      final newRequest = http.Request(original.method, original.url)
        ..headers.addAll(original.headers)
        ..bodyBytes = original.bodyBytes;
      return newRequest;
    } else {
      throw UnimplementedError('Request type ${original.runtimeType} is not supported for retrying.');
    }
  }
}