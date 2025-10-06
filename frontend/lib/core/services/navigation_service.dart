// lib/core/services/navigation_service.dart

import 'package:flutter/material.dart';

// This GlobalKey allows us to access the Navigator's state from anywhere
// in the app, which is crucial for our API interceptor to handle logouts.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}