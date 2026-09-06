import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../models/media_item.dart';

class ApiService {
  final Dio _dio;

  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Extract media metadata and formats from a social link
  Future<MediaItem> extractMedia(String url) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.extract,
        data: {'url': url.trim()},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return MediaItem.fromJson(data, originalUrl: url);
        } else {
          throw Exception(data['error'] ?? 'Extraction failed.');
        }
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final errorMsg = e.response?.data['error'];
        if (errorMsg != null) throw Exception(errorMsg);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Connection timed out. Please check your internet or backend server.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Could not connect to extraction backend (${ApiEndpoints.baseUrl}).');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to extract media: $e');
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
