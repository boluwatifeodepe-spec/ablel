import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/download_record.dart';
import '../../data/models/media_format.dart';
import '../../data/models/media_item.dart';
import '../../data/services/download_service.dart';
import 'history_provider.dart';

// Service provider
final downloadServiceProvider = Provider<DownloadService>((ref) => DownloadService());

enum DownloadStatus { idle, downloading, completed, error, cancelled }

class DownloadProgressState {
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final DownloadRecord? record;
  final String? errorMessage;
  final MediaItem? currentItem;
  final MediaFormat? currentFormat;

  const DownloadProgressState({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.record,
    this.errorMessage,
    this.currentItem,
    this.currentFormat,
  });

  int get percentage => (progress * 100).toInt().clamp(0, 100);

  DownloadProgressState copyWith({
    DownloadStatus? status,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    DownloadRecord? record,
    String? errorMessage,
    MediaItem? currentItem,
    MediaFormat? currentFormat,
  }) {
    return DownloadProgressState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      record: record ?? this.record,
      errorMessage: errorMessage ?? this.errorMessage,
      currentItem: currentItem ?? this.currentItem,
      currentFormat: currentFormat ?? this.currentFormat,
    );
  }
}

class DownloadNotifier extends StateNotifier<DownloadProgressState> {
  final DownloadService _downloadService;
  final Ref _ref;

  DownloadNotifier(this._downloadService, this._ref)
      : super(const DownloadProgressState());

  Future<void> startDownload({
    required MediaItem item,
    required MediaFormat format,
  }) async {
    state = DownloadProgressState(
      status: DownloadStatus.downloading,
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: format.filesize ?? 0,
      currentItem: item,
      currentFormat: format,
    );

    try {
      final hasPermission = await _downloadService.requestPermissions();
      if (!hasPermission) {
        state = state.copyWith(
          status: DownloadStatus.error,
          errorMessage: 'Storage permission is required to save downloads.',
        );
        return;
      }

      final record = await _downloadService.downloadMedia(
        item: item,
        format: format,
        onProgress: (received, total, progress) {
          state = state.copyWith(
            receivedBytes: received,
            totalBytes: total,
            progress: progress,
          );
        },
      );

      // Add to local Hive download history
      await _ref.read(historyRepositoryProvider).addRecord(record);
      _ref.read(historyProvider.notifier).loadHistory();

      state = state.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        record: record,
      );
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        state = state.copyWith(status: DownloadStatus.cancelled);
      } else {
        state = state.copyWith(
          status: DownloadStatus.error,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void cancelDownload() {
    _downloadService.cancelDownload();
    state = state.copyWith(status: DownloadStatus.cancelled);
  }

  void reset() {
    state = const DownloadProgressState();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadProgressState>((ref) {
  final downloadService = ref.watch(downloadServiceProvider);
  return DownloadNotifier(downloadService, ref);
});
