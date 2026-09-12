import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/download_record.dart';
import '../providers/download_provider.dart';
import '../providers/extract_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class DownloadCompleteScreen extends ConsumerWidget {
  final DownloadRecord record;

  const DownloadCompleteScreen({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Glowing Success Checkmark Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple.withOpacity(0.2),
                  border: Border.all(color: AppColors.primaryPurple, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title & Subtitle
              const Text(
                'Download Complete',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your file has been saved locally.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Saved File Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Preview
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildThumbnail(),
                          ),
                        ),
                        // Quality + duration badge
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${record.quality} • ${record.duration}',
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
                    const SizedBox(height: 14),

                    // File name / title
                    Text(
                      Formatters.decodeHtmlEntities(record.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Format info
                    Text(
                      '${Formatters.formatBytes(record.fileSize)} • ${record.format.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Primary Action: Open File
              GradientButton(
                onPressed: () {
                  if (File(record.filePath).existsSync()) {
                    OpenFilex.open(record.filePath);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('File not found at path.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                text: 'Open File',
              ),
              const SizedBox(height: 12),

              // Secondary Action: Share
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (File(record.filePath).existsSync()) {
                        Share.shareXFiles([XFile(record.filePath)], text: record.title);
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_outlined, color: AppColors.textPrimary, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Share',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // "Download another ->"
              TextButton(
                onPressed: () {
                  ref.read(extractProvider.notifier).reset();
                  ref.read(downloadProvider.notifier).reset();
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text(
                  'Download another →',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (record.thumbnail != null && record.thumbnail!.isNotEmpty) {
      if (File(record.thumbnail!).existsSync()) {
        return Image.file(
          File(record.thumbnail!),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildPlaceholder(),
        );
      } else if (record.thumbnail!.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: record.thumbnail!,
          fit: BoxFit.cover,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
          },
          placeholder: (c, u) => Container(color: AppColors.surfaceLight),
          errorWidget: (c, u, e) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(
          record.isAudio ? Icons.music_note_rounded : Icons.play_arrow_rounded,
          color: AppColors.textMuted,
          size: 40,
        ),
      ),
    );
  }
}
