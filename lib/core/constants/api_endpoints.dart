import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  // Override this when backend is deployed to Railway
  static const String _defaultProductionUrl = 'https://able-backend-production.up.railway.app';
  
  // Custom baseUrl override (can be changed in settings)
  static String? customBaseUrl;

  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    
    // In production builds, use Railway URL
    if (kReleaseMode) {
      return _defaultProductionUrl;
    }

    // In local development / debug builds:
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000'; // Android emulator localhost alias
    } else {
      return 'http://localhost:3000'; // iOS simulator / macOS
    }
  }

  static String get extract => '$baseUrl/api/extract';
  static String get platforms => '$baseUrl/api/platforms';
  static String get health => '$baseUrl/health';
  static String get proxy => '$baseUrl/api/proxy';
}
