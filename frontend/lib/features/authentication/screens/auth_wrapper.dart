// lib/features/authentication/screens/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../screens/main_scaffold.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'splash_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // State 1: Running initial auth token check
        if (authProvider.isLoading) {
          return const SplashScreen();
        }

        // State 2: Authenticated, show main app
        if (authProvider.isAuthenticated) {
          return const MainScaffold();
        }

        // State 3: Unauthenticated, show login or signup based on internal state
        return authProvider.showLogin ? const LoginScreen() : const SignUpScreen();
      },
    );
  }
}