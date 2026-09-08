import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
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
                receiveTimeout: const Duration(seconds: 120),
              ),
            );

  /// Get or create local Able download directory
  Future<Directory> getDownloadDirectory() async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      // Prefer public Download folder on Android if accessible
      baseDir = Directory('/storage/emulated/0/Download/Able');
      try {
        if (!await baseDir.exists()) {
          await baseDir.create(recursive: true);
        }
        return baseDir;
      } catch (_) {
        // Fallback to external files or app documents
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

  /// Download media format to disk with live progress and save to Phone Gallery
  Future<DownloadRecord> downloadMedia({
    required MediaItem item,
    required MediaFormat format,
    required OnDownloadProgress onProgress,
  }) async {
    _currentCancelToken = CancelToken();

    // Prepare target directory & filename
    final directory = await getDownloadDirectory();
    final sanitizedTitle = item.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim()
        .take(40);
    final filename = '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.${format.ext}';
    final targetFilePath = p.join(directory.path, filename);

    // Track download progress
    int lastReceived = 0;
    int knownTotal = format.filesize ?? 0;

    try {
      await _dio.download(
        format.url,
        targetFilePath,
        cancelToken: _currentCancelToken,
        onReceiveProgress: (received, total) {
          lastReceived = received;
          final effectiveTotal = total > 0 ? total : (knownTotal > 0 ? knownTotal : received);
          final progress = effectiveTotal > 0 ? (received / effectiveTotal).clamp(0.0, 1.0) : 0.0;
          onProgress(received, effectiveTotal, progress);
        },
      );

      final file = File(targetFilePath);
      final finalSize = await file.length();

      // Trigger native Gallery & MediaStore indexing so it appears in Phone Gallery app
      if (Platform.isAndroid) {
        try {
          await _galleryChannel.invokeMethod('saveToGallery', {
            'path': targetFilePath,
            'isVideo': format.isVideo,
          });
        } catch (_) {
          try {
            await _galleryChannel.invokeMethod('scanFile', {'path': targetFilePath});
          } catch (_) {}
        }
      }

      return DownloadRecord(
        id: const Uuid().v4(),
        title: item.title,
        filePath: targetFilePath,
        thumbnail: item.thumbnail,
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
        // Clean up partial file if cancelled
        final partialFile = File(targetFilePath);
        if (await partialFile.exists()) {
          await partialFile.delete();
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
