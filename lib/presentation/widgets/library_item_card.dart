import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/download_record.dart';

class LibraryItemCard extends StatelessWidget {
  final DownloadRecord record;
  final VoidCallback? onDelete;
  static const MethodChannel _galleryChannel = MethodChannel('com.able.app/gallery');

  const LibraryItemCard({
    super.key,
    required this.record,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
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
          onLongPress: () => _showOptionsBottomSheet(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Preview
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: _buildThumbnail(),
                    ),
                  ),
                  // Platform pill in top left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: record.socialPlatform.brandColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(record.socialPlatform.iconData, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            record.quality,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Duration badge in bottom right
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
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
                ],
              ),
              // Meta info
              Padding(
                padding: const EdgeInsets.all(12),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          Formatters.formatBytes(record.fileSize),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        const SizedBox(width: 6),
                        Text(
                          Formatters.formatRelativeDate(record.downloadedAt),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
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
          placeholder: (c, u) => Container(color: AppColors.surfaceLight),
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
          size: 36,
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded, color: AppColors.accentCyan),
                  title: const Text('Open File', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    OpenFilex.open(record.filePath);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.accentCyan),
                  title: const Text('Open in Gallery', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await _galleryChannel.invokeMethod('openInGallery', {
                        'path': record.filePath,
                        'isVideo': !record.isAudio,
                      });
                    } catch (_) {
                      OpenFilex.open(record.filePath);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: AppColors.primaryPurple),
                  title: const Text('Share File', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Share.shareXFiles([XFile(record.filePath)], text: record.title);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Delete from Library', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
