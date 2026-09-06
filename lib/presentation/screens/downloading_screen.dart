import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../providers/download_provider.dart';
import '../widgets/circular_progress_gauge.dart';
import 'download_complete_screen.dart';

class DownloadingScreen extends ConsumerWidget {
  const DownloadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);

    // If download completes, transition to complete screen
    ref.listen(downloadProvider, (prev, next) {
      if (next.status == DownloadStatus.completed && next.record != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => DownloadCompleteScreen(record: next.record!),
          ),
        );
      } else if (next.status == DownloadStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Download failed.'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      } else if (next.status == DownloadStatus.cancelled) {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Title
              const Column(
                children: [
                  SizedBox(height: 30),
                  Text(
                    'Downloading',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Fetching high-quality media...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Glowing Circular Gauge Center
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressGauge(
                    progress: downloadState.progress,
                    percentage: downloadState.percentage,
                    size: 220,
                  ),
                  const SizedBox(height: 32),
                  // Progress bytes indicator (e.g. 18.2 MB / 18.2 MB)
                  Text(
                    '${Formatters.formatBytes(downloadState.receivedBytes)} / ${Formatters.formatBytes(downloadState.totalBytes)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),

              // Bottom Cancel Action
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(downloadProvider.notifier).cancelDownload();
                  },
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
