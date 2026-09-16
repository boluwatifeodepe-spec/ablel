import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../models/media_item.dart';

import 'client_extractor.dart';

class ApiService {
  final Dio _dio;

  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 45),
                receiveTimeout: const Duration(seconds: 60),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    // Warm up Render backend immediately in the background on app init
    checkHealth();
  }

  /// Extract media metadata and formats from a social link
  Future<MediaItem> extractMedia(String rawUrl) async {
    final cleanUrl = ClientExtractor.sanitizeUrl(rawUrl);

    // 1. Try remote extraction backend if configured and healthy
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
      // Backend is unavailable, offline, or threw 503; fall through to client extractor
    }

    // 2. Direct on-device extraction fallback (guaranteed offline/standalone support)
    try {
      return await ClientExtractor.extract(cleanUrl);
    } catch (e) {
      throw Exception('Could not extract media. Please verify the link is valid and public.');
    }
  }

  /// Check backend health
  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.health,
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
