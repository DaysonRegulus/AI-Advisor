// lib/locator.dart
import 'package:get_it/get_it.dart';
import 'api/api_service.dart';
import 'core/services/secure_storage_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register ApiService as a "singleton". This means a single instance
  // will be created and shared throughout the app's lifecycle.
  locator.registerLazySingleton(() => ApiService());

  // Register our new SecureStorageService as a singleton as well.
  // This means a single instance will be created and shared.
  locator.registerLazySingleton(() => SecureStorageService());
}