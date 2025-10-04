// lib/features/authentication/screens/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../screens/main_scaffold.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to authentication state changes.
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        print('AuthWrapper rebuilding. isAuthenticated: ${authProvider.isAuthenticated}, isLoading: ${authProvider.isLoading}');
        // If we are still running the initial check, show the splash screen.
        if (authProvider.isLoading) {
          return const SplashScreen();
        }

        // If the user is authenticated, show the main app.
        if (authProvider.isAuthenticated) {
          return const MainScaffold();
        }

        // Otherwise, the user is not authenticated, show the login screen.
        return const LoginScreen();
      },
    );
  }
}