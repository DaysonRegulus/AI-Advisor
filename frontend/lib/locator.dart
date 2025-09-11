// lib/locator.dart
import 'package:get_it/get_it.dart';
import 'api/api_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register ApiService as a "singleton". This means a single instance
  // will be created and shared throughout the app's lifecycle.
  locator.registerLazySingleton(() => ApiService());
}