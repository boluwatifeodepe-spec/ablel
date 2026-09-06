import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/download_record.dart';
import '../../data/repositories/history_repository.dart';

// Repository provider
final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

class HistoryState {
  final List<DownloadRecord> allRecords;
  final List<DownloadRecord> recentRecords;
  final List<DownloadRecord> filteredRecords;
  final String selectedFilter; // 'All', 'TikTok', 'Instagram', 'YouTube', etc.
  final String searchQuery;
  final bool isLoading;

  const HistoryState({
    this.allRecords = const [],
    this.recentRecords = const [],
    this.filteredRecords = const [],
    this.selectedFilter = 'All',
    this.searchQuery = '',
    this.isLoading = false,
  });

  HistoryState copyWith({
    List<DownloadRecord>? allRecords,
    List<DownloadRecord>? recentRecords,
    List<DownloadRecord>? filteredRecords,
    String? selectedFilter,
    String? searchQuery,
    bool? isLoading,
  }) {
    return HistoryState(
      allRecords: allRecords ?? this.allRecords,
      recentRecords: recentRecords ?? this.recentRecords,
      filteredRecords: filteredRecords ?? this.filteredRecords,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final HistoryRepository _repository;

  HistoryNotifier(this._repository) : super(const HistoryState()) {
    loadHistory();
  }

  void loadHistory() {
    try {
      final all = _repository.getAllRecords();
      final recent = _repository.getRecentRecords(5);
      final filtered = _repository.searchRecords(
        platform: state.selectedFilter,
        query: state.searchQuery,
      );

      state = state.copyWith(
        allRecords: all,
        recentRecords: recent,
        filteredRecords: filtered,
        isLoading: false,
      );
    } catch (_) {
      // Box may not be initialized yet
    }
  }

  void setFilter(String platform) {
    state = state.copyWith(selectedFilter: platform);
    final filtered = _repository.searchRecords(
      platform: platform,
      query: state.searchQuery,
    );
    state = state.copyWith(filteredRecords: filtered);
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    final filtered = _repository.searchRecords(
      platform: state.selectedFilter,
      query: query,
    );
    state = state.copyWith(filteredRecords: filtered);
  }

  Future<void> deleteRecord(String id) async {
    await _repository.deleteRecord(id);
    loadHistory();
  }

  Future<void> clearAll() async {
    await _repository.clearAllHistory();
    loadHistory();
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final repo = ref.watch(historyRepositoryProvider);
  return HistoryNotifier(repo);
});
