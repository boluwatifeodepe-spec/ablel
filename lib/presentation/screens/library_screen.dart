import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/history_provider.dart';
import '../widgets/library_item_card.dart';
import 'settings_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterTabs = const [
    'All',
    'TikTok',
    'Instagram',
    'YouTube',
    'Twitter',
    'Facebook',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final records = historyState.filteredRecords;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.vibrantPurpleGradient.createShader(bounds),
                    child: const Text(
                      'Able',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(historyProvider.notifier).search(val);
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Library...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(historyProvider.notifier).search('');
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // Filter Tabs
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: _filterTabs.length,
                itemBuilder: (context, index) {
                  final tab = _filterTabs[index];
                  final isSelected = historyState.selectedFilter.toLowerCase() == tab.toLowerCase();

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        tab,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryPurple : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(historyProvider.notifier).setFilter(tab);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Media Grid or Empty State
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 64,
                            color: AppColors.textMuted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            historyState.searchQuery.isNotEmpty
                                ? 'No downloads matching "${historyState.searchQuery}"'
                                : 'No downloads in ${historyState.selectedFilter}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Downloaded media will appear here.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return LibraryItemCard(
                          record: record,
                          onDelete: () {
                            ref.read(historyProvider.notifier).deleteRecord(record.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
