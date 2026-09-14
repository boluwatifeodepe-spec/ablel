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
      try {
        baseDir = await getExternalStorageDirectory();
      } catch (_) {}
      baseDir ??= await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final ableDir = Directory(p.join(baseDir.path, 'Able'));
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
      // Inspect initial bytes to ensure we did not download an HTML webpage (e.g. 403/Expired page)
      if (finalSize > 0) {
        final sampleBytes = await file.openRead(0, finalSize < 8192 ? finalSize : 8192).transform(const SystemEncoding().decoder).join('').catchError((_) => '');
        final lowerSample = sampleBytes.toLowerCase();
        if (lowerSample.contains('<html') || lowerSample.contains('<!doctype') || lowerSample.contains('<head') || lowerSample.contains('<body')) {
          await file.delete().catchError((_) => file);
          throw Exception('The direct video stream URL could not be opened or is protected. Please try another link.');
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
                'Referer': item.thumbnail.contains('tiktok') ? 'https://www.tiktok.com/' : 'https://www.instagram.com/',
              },
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
          if (await thumbFile.exists() && await thumbFile.length() > 200) {
            localThumbnailPath = thumbFile.path;
          }
        } catch (_) {
          // Keep remote thumbnail URL if local caching fails
        }
      }

      // Export file to phone's public MediaStore / Gallery
      if (Platform.isAndroid) {
        try {
          await _galleryChannel.invokeMethod('saveToGallery', {
            'path': targetFilePath,
            'isVideo': !format.isAudio,
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
