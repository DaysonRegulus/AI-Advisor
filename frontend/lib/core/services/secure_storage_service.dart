// lib/core/services/secure_storage_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// A service class to encapsulate all interactions with flutter_secure_storage.
// This makes the rest of our app unaware of the implementation details of
// how we are storing tokens.
class SecureStorageService {
  // Create a private instance of the storage.
  final _secureStorage = const FlutterSecureStorage();

  // Define the keys we will use to store our data.
  // Using private constants is a good practice to avoid typos.
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  /// Saves both the access and refresh tokens to secure storage.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // The `write` method is asynchronous and returns a Future.
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Retrieves the stored access token.
  /// Returns null if the token is not found.
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// Retrieves the stored refresh token.
  /// Returns null if the token is not found.
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  /// Deletes all stored tokens.
  /// This is used during the logout process.
  Future<void> deleteTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}