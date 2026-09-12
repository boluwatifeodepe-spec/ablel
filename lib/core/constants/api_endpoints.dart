import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  // Default live backend URL (can also be customized anytime in App Settings)
  static const String _defaultProductionUrl = 'https://ablel.onrender.com';
  
  // Custom baseUrl override (can be changed in settings)
  static String? customBaseUrl;

  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    
    // Default fallback to live backend
    return _defaultProductionUrl;
  }

  static String get extract => '$baseUrl/api/extract';
  static String get platforms => '$baseUrl/api/platforms';
  static String get health => '$baseUrl/health';
  static String get proxy => '$baseUrl/api/proxy';
}
