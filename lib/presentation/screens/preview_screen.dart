import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../providers/download_provider.dart';
import '../providers/extract_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'downloading_screen.dart';
import 'settings_screen.dart';

class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extractState = ref.watch(extractProvider);

    if (extractState is! ExtractSuccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const Center(
          child: Text('No media preview available.'),
        ),
      );
    }

    final item = extractState.item;
    final selectedFormat = extractState.selectedFormat;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Media Preview Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Thumbnail with Badges
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: item.thumbnail.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: item.thumbnail,
                                    fit: BoxFit.cover,
                                    httpHeaders: const {
                                      'User-Agent':
                                          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
                                    },
                                    placeholder: (c, u) => Container(
                                      color: AppColors.surfaceElevated,
                                      child: const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (c, u, e) => Container(
                                      color: AppColors.surfaceElevated,
                                      child: Icon(item.platform.iconData, size: 48, color: AppColors.textMuted),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.surfaceElevated,
                                    child: Icon(item.platform.iconData, size: 48, color: AppColors.textMuted),
                                  ),
                          ),
                        ),
                        // Platform Badge in Top Left
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.platform.brandColor.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(item.platform.iconData, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  item.platform.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Duration Badge in Bottom Right
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Media Title
                    Text(
                      Formatters.decodeHtmlEntities(item.title),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Author info
                    Row(
                      children: [
                        if (item.author.avatar.isNotEmpty) ...[
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: NetworkImage(item.author.avatar),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          Formatters.decodeHtmlEntities(item.author.name),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.author.username,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quality / Format Selector Pills
                    Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: item.formats.map((format) {
                            final isSelected = selectedFormat.id == format.id;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: ChoiceChip(
                                label: Text(
                                  format.label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primaryPurple.withOpacity(0.35),
                                backgroundColor: AppColors.surfaceElevated,
                                side: BorderSide(
                                  color: isSelected ? AppColors.primaryPurple : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    ref.read(extractProvider.notifier).selectFormat(format);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Primary Action: Download Video (No Watermark)
              GradientButton(
                onPressed: () {
                  ref.read(downloadProvider.notifier).startDownload(
                    item: item,
                    format: selectedFormat,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const DownloadingScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                text: selectedFormat.isAudio
                    ? 'Download Audio Only'
                    : 'Download Video (No Watermark)',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
