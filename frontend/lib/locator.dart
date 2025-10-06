// lib/locator.dart
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'api/api_service.dart';
import 'core/services/secure_storage_service.dart';
import 'api/api_interceptor.dart';
import 'core/services/navigation_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // --- Core Services ---
  // Register the GlobalKey for navigation
  locator.registerLazySingleton(() => NavigationService.navigatorKey);

  // Register SecureStorageService
  locator.registerLazySingleton(() => SecureStorageService());

  // --- API Layer ---
  // Register our custom ApiInterceptor. It's a type of http.Client.
  locator.registerLazySingleton<http.Client>(() => ApiInterceptor());

  // Register ApiService and pass the http.Client (our interceptor) to it.
  locator.registerLazySingleton(() => ApiService(locator<http.Client>()));
}