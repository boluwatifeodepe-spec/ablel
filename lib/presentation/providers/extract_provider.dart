import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/media_format.dart';
import '../../data/models/media_item.dart';
import '../../data/services/api_service.dart';

// Service provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Extraction state
sealed class ExtractState {
  const ExtractState();
}

class ExtractInitial extends ExtractState {
  const ExtractInitial();
}

class ExtractLoading extends ExtractState {
  final String url;
  const ExtractLoading(this.url);
}

class ExtractSuccess extends ExtractState {
  final MediaItem item;
  final MediaFormat selectedFormat;
  const ExtractSuccess({required this.item, required this.selectedFormat});

  ExtractSuccess copyWith({MediaItem? item, MediaFormat? selectedFormat}) {
    return ExtractSuccess(
      item: item ?? this.item,
      selectedFormat: selectedFormat ?? this.selectedFormat,
    );
  }
}

class ExtractError extends ExtractState {
  final String message;
  const ExtractError(this.message);
}

// Extract State Notifier
class ExtractNotifier extends StateNotifier<ExtractState> {
  final ApiService _apiService;

  ExtractNotifier(this._apiService) : super(const ExtractInitial());

  Future<void> extract(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      state = const ExtractError('Please enter or paste a valid link.');
      return;
    }

    state = ExtractLoading(cleanUrl);

    try {
      final mediaItem = await _apiService.extractMedia(cleanUrl);
      final defaultFormat = mediaItem.hdFormat ?? mediaItem.defaultVideoFormat ?? mediaItem.formats.first;

      state = ExtractSuccess(
        item: mediaItem,
        selectedFormat: defaultFormat,
      );
    } catch (e) {
      state = ExtractError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void selectFormat(MediaFormat format) {
    if (state is ExtractSuccess) {
      final current = state as ExtractSuccess;
      state = current.copyWith(selectedFormat: format);
    }
  }

  void reset() {
    state = const ExtractInitial();
  }
}

final extractProvider = StateNotifierProvider<ExtractNotifier, ExtractState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ExtractNotifier(apiService);
});
