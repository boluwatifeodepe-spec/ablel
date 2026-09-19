import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../models/media_item.dart';
import 'client_extractor.dart';

class ApiService {
  final Dio _dio;
  Timer? _keepAliveTimer;

  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 60),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    // Immediate warmup and 10-minute keep-alive ping loop for Render server
    checkHealth();
    _startKeepAlivePing();
  }

  void _startKeepAlivePing() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      pingServer();
    });
  }

  /// Send keep-alive ping to Render backend endpoint every 10 minutes
  Future<bool> pingServer() async {
    try {
      final res = await _dio.get(
        '${ApiEndpoints.baseUrl}/ping',
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Extract media metadata and formats from a social link
  Future<MediaItem> extractMedia(String rawUrl) async {
    final cleanUrl = ClientExtractor.sanitizeUrl(rawUrl);
    final platform = ClientExtractor.detectPlatform(cleanUrl);

    // Requirement 5: Do NOT use RapidAPI/Backend for YouTube, use youtube_explode_dart directly in Flutter
    if (platform == 'youtube') {
      return await ClientExtractor.extract(cleanUrl);
    }

    // 1. Try remote extraction backend for Instagram, TikTok, Facebook, Twitter
    try {
      final response = await _dio.post(
        ApiEndpoints.extract,
        data: {'url': cleanUrl},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return MediaItem.fromJson(data, originalUrl: cleanUrl);
        }
      }
    } catch (_) {
      // Backend is offline or cold starting; fall through to client extractor
    }

    // 2. Direct on-device extraction fallback
    try {
      return await ClientExtractor.extract(cleanUrl);
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.health,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
