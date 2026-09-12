import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/formatters.dart';
import '../models/download_record.dart';
import '../models/media_format.dart';
import '../models/media_item.dart';

typedef OnDownloadProgress = void Function(int receivedBytes, int totalBytes, double percent);

class DownloadService {
  final Dio _dio;
  CancelToken? _currentCancelToken;
  static const MethodChannel _galleryChannel = MethodChannel('com.able.app/gallery');

  DownloadService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 180),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
                  'Accept': '*/*',
                  'Accept-Encoding': 'gzip, deflate, br',
                },
                followRedirects: true,
                maxRedirects: 8,
              ),
            );

  /// Get or create local Able download directory
  Future<Directory> getDownloadDirectory() async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      // Use public Download folder on Android so files are directly visible in Files / Gallery
      baseDir = Directory('/storage/emulated/0/Download/Able');
      try {
        if (!await baseDir.exists()) {
          await baseDir.create(recursive: true);
        }
        return baseDir;
      } catch (_) {
        baseDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final ableDir = Directory(p.join(baseDir?.path ?? '', 'Able'));
    if (!await ableDir.exists()) {
      await ableDir.create(recursive: true);
    }
    return ableDir;
  }

  /// Request necessary storage permissions
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) return true;

        final photosStatus = await Permission.photos.request();
        final videosStatus = await Permission.videos.request();
        final audioStatus = await Permission.audio.request();
        return photosStatus.isGranted || videosStatus.isGranted || audioStatus.isGranted;
      } catch (_) {}
    }
    return true;
  }

  /// Download media format to disk with live progress and save thumbnail locally for offline cover display
  Future<DownloadRecord> downloadMedia({
    required MediaItem item,
    required MediaFormat format,
    required OnDownloadProgress onProgress,
  }) async {
    _currentCancelToken = CancelToken();

    // Prepare target directory & filename
    final directory = await getDownloadDirectory();
    final cleanTitle = Formatters.decodeHtmlEntities(item.title)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim()
        .take(40);
    final recordId = const Uuid().v4();
    final filename = '${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.${format.ext}';
    final targetFilePath = p.join(directory.path, filename);

    // Track download progress
    int lastReceived = 0;
    int knownTotal = format.filesize ?? 0;

    try {
      await _dio.download(
        format.url,
        targetFilePath,
        cancelToken: _currentCancelToken,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
            'Accept': '*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          lastReceived = received;
          final effectiveTotal = total > 0 ? total : (knownTotal > 0 ? knownTotal : received);
          final progress = effectiveTotal > 0 ? (received / effectiveTotal).clamp(0.0, 1.0) : 0.0;
          onProgress(received, effectiveTotal, progress);
        },
      );

      final file = File(targetFilePath);
      if (!await file.exists()) {
        throw Exception('Download failed: file was not saved.');
      }

      final finalSize = await file.length();
      if (finalSize < 1024) {
        // Check if it's an HTML error page
        final content = await file.readAsString().catchError((_) => '');
        if (content.toLowerCase().contains('<html') || content.toLowerCase().contains('<!doctype')) {
          await file.delete().catchError((_) => file);
          throw Exception('Download stream expired or protected. Please try another format or copy a fresh link.');
        }
      }

      // Download and cache thumbnail locally so video cover ALWAYS renders in Library & Recent Downloads
      String localThumbnailPath = item.thumbnail;
      if (item.thumbnail.isNotEmpty && item.thumbnail.startsWith('http')) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final thumbsDir = Directory(p.join(appDocDir.path, 'thumbs'));
          if (!await thumbsDir.exists()) {
            await thumbsDir.create(recursive: true);
          }
          final thumbFile = File(p.join(thumbsDir.path, '${recordId}_thumb.jpg'));
          await _dio.download(
            item.thumbnail,
            thumbFile.path,
            options: Options(
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
              },
              receiveTimeout: const Duration(seconds: 6),
            ),
          );
          if (await thumbFile.exists() && await thumbFile.length() > 200) {
            localThumbnailPath = thumbFile.path;
          }
        } catch (_) {
          // Keep remote thumbnail URL if local caching fails
        }
      }

      // Notify MediaStore to index this single file (prevents duplicate gallery items)
      if (Platform.isAndroid) {
        try {
          await _galleryChannel.invokeMethod('scanFile', {
            'path': targetFilePath,
            'isVideo': format.isVideo,
          });
        } catch (_) {}
      }

      return DownloadRecord(
        id: recordId,
        title: Formatters.decodeHtmlEntities(item.title),
        filePath: targetFilePath,
        thumbnail: localThumbnailPath,
        platform: item.platform.name,
        fileSize: finalSize > 0 ? finalSize : lastReceived,
        duration: item.duration,
        format: format.ext,
        quality: format.label,
        downloadedAt: DateTime.now(),
        originalUrl: item.originalUrl,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        final partialFile = File(targetFilePath);
        if (await partialFile.exists()) {
          await partialFile.delete().catchError((_) => partialFile);
        }
        throw Exception('Download was cancelled.');
      }
      throw Exception('Failed to download file: ${e.toString()}');
    } finally {
      _currentCancelToken = null;
    }
  }

  /// Cancel any currently running download
  void cancelDownload() {
    _currentCancelToken?.cancel('Cancelled by user');
  }
}

extension StringTake on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
