// lib/providers/refresh_provider.dart
import 'package:flutter/material.dart';

class RefreshProvider with ChangeNotifier {
  Future<void> Function()? refreshAllData;

  void setRefreshFunction(Future<void> Function() func) {
    refreshAllData = func;
  }
}