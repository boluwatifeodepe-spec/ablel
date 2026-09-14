import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/download_record.dart';

class RecentDownloadCard extends StatelessWidget {
  final DownloadRecord record;
  final VoidCallback? onTap;

  const RecentDownloadCard({
    super.key,
    required this.record,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ??
              () {
                if (File(record.filePath).existsSync()) {
                  OpenFilex.open(record.filePath);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File not found on device.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with duration overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: _buildThumbnail(),
                    ),
                  ),
                  // Duration badge in bottom right
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Platform badge in top left
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: record.socialPlatform.brandColor.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        record.socialPlatform.iconData,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              // Title & platform name
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.decodeHtmlEntities(record.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          record.socialPlatform.displayName,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          record.quality,
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumb = record.thumbnail;
    if (thumb != null && thumb.isNotEmpty) {
      if (thumb.startsWith('http://') || thumb.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: thumb,
          fit: BoxFit.cover,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
            'Referer': 'https://www.tiktok.com/',
          },
          placeholder: (c, u) => Container(color: AppColors.surface),
          errorWidget: (c, u, e) => _buildPlaceholder(),
        );
      }
      try {
        final file = File(thumb);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildPlaceholder(),
          );
        }
      } catch (_) {}
    }

    if (record.originalUrl != null && record.originalUrl!.isNotEmpty) {
      final ytIdMatch = RegExp(
              r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|shorts\/|live\/|watch\?.+&v=))([\w-]{11})')
          .firstMatch(record.originalUrl!);
      if (ytIdMatch != null) {
        return CachedNetworkImage(
          imageUrl: 'https://i.ytimg.com/vi/${ytIdMatch.group(1)}/hqdefault.jpg',
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(color: AppColors.surface),
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
          size: 32,
        ),
      ),
    );
  }
}
