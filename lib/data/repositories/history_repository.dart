import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/download_record.dart';

class HistoryRepository {
  static const String boxName = 'download_history_box';
  Box<DownloadRecord>? _box;

  /// Initialize Hive box and register custom adapter
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DownloadRecordAdapter());
    }
    _box = await Hive.openBox<DownloadRecord>(boxName);
  }

  Box<DownloadRecord> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('HistoryRepository is not initialized. Call init() first.');
    }
    return _box!;
  }

  /// Get all download records sorted by newest first
  List<DownloadRecord> getAllRecords() {
    final list = box.values.toList();
    list.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return list;
  }

  /// Get recent download records (limit to 5 for Home carousel)
  List<DownloadRecord> getRecentRecords([int limit = 5]) {
    final list = getAllRecords();
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  /// Filter records by platform and query
  List<DownloadRecord> searchRecords({String? platform, String? query}) {
    var results = getAllRecords();

    if (platform != null && platform.isNotEmpty && platform.toLowerCase() != 'all') {
      results = results
          .where((r) => r.platform.toLowerCase() == platform.toLowerCase())
          .toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      results = results
          .where((r) => r.title.toLowerCase().contains(q) || r.format.toLowerCase().contains(q))
          .toList();
    }

    return results;
  }

  /// Add a new download record
  Future<void> addRecord(DownloadRecord record) async {
    await box.put(record.id, record);
  }

  /// Delete a record and optionally its file from disk
  Future<void> deleteRecord(String id, {bool deleteFile = true}) async {
    final record = box.get(id);
    if (record != null && deleteFile) {
      try {
        final file = File(record.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting local file: $e');
      }
    }
    await box.delete(id);
  }

  /// Clear all download history
  Future<void> clearAllHistory({bool deleteFiles = false}) async {
    if (deleteFiles) {
      for (final record in box.values) {
        try {
          final file = File(record.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    await box.clear();
  }

  /// Check if file exists on disk
  bool fileExists(String filePath) {
    try {
      return File(filePath).existsSync();
    } catch (_) {
      return false;
    }
  }
}
