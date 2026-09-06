import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/constants/app_colors.dart';
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
                      record.title,
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
    if (record.thumbnail != null && record.thumbnail!.isNotEmpty) {
      if (record.thumbnail!.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: record.thumbnail!,
          fit: BoxFit.cover,
          placeholder: (c, u) => Container(color: AppColors.surface),
          errorWidget: (c, u, e) => _buildPlaceholder(),
        );
      } else if (File(record.thumbnail!).existsSync()) {
        return Image.file(File(record.thumbnail!), fit: BoxFit.cover);
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
