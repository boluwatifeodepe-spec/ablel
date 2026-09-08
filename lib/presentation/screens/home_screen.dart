import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/services/client_extractor.dart';
import '../providers/extract_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/platform_chip.dart';
import '../widgets/recent_download_card.dart';
import 'preview_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handlePasteAndAnalyze() async {
    String text = _urlController.text.trim();

    // If input is empty, try to grab from clipboard
    if (text.isEmpty) {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.trim().isNotEmpty) {
        text = clipboardData.text!.trim();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please paste a link to analyze.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Sanitize input to get pure URL
    final sanitized = ClientExtractor.sanitizeUrl(text);
    if (sanitized.isNotEmpty) {
      text = sanitized;
      _urlController.text = text;
    }

    // Trigger extraction
    await ref.read(extractProvider.notifier).extract(text);

    final extractState = ref.read(extractProvider);
    if (!mounted) return;

    if (extractState is ExtractSuccess) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PreviewScreen(),
        ),
      );
    } else if (extractState is ExtractError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(extractState.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final extractState = ref.watch(extractProvider);
    final historyState = ref.watch(historyProvider);
    final isLoading = extractState is ExtractLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Lightning Bolt | Able Logo | Settings
              Row(
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
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Headline & Subtitle
              Center(
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFBAE6FD), Color(0xFFE0E7FF)],
                      ).createShader(bounds),
                      child: const Text(
                        'Paste a link to download',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Fast, high-quality media extraction',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Paste Input Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Paste a link here...',
                        prefixIcon: const Icon(Icons.link_rounded, color: AppColors.textMuted),
                        suffixIcon: _urlController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                                onPressed: () {
                                  setState(() => _urlController.clear());
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => setState(() {}),
                      onSubmitted: (_) => _handlePasteAndAnalyze(),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      onPressed: isLoading ? null : _handlePasteAndAnalyze,
                      isLoading: isLoading,
                      icon: const Icon(Icons.content_paste_rounded, color: Colors.white, size: 18),
                      text: 'Paste & Analyze',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Supported Platforms
              const Text(
                'Supported Platforms',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    PlatformChip(
                      platform: SocialPlatform.tiktok,
                      onTap: () => _fillSampleUrl('https://www.tiktok.com/@user/video/123'),
                    ),
                    const SizedBox(width: 8),
                    PlatformChip(
                      platform: SocialPlatform.instagram,
                      onTap: () => _fillSampleUrl('https://www.instagram.com/reel/C3abc/'),
                    ),
                    const SizedBox(width: 8),
                    PlatformChip(
                      platform: SocialPlatform.youtube,
                      onTap: () => _fillSampleUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
                    ),
                    const SizedBox(width: 8),
                    PlatformChip(
                      platform: SocialPlatform.twitter,
                      onTap: () => _fillSampleUrl('https://x.com/user/status/12345'),
                    ),
                    const SizedBox(width: 8),
                    PlatformChip(
                      platform: SocialPlatform.facebook,
                      onTap: () => _fillSampleUrl('https://www.facebook.com/reel/123'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Recent Downloads
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Downloads',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (historyState.recentRecords.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        // Switch to Library tab if tapped
                      },
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (historyState.recentRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_download_outlined, size: 40, color: AppColors.textMuted.withOpacity(0.6)),
                      const SizedBox(height: 8),
                      const Text(
                        'No downloads yet',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Paste a link above to start downloading',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: historyState.recentRecords.length,
                    itemBuilder: (context, index) {
                      final record = historyState.recentRecords[index];
                      return RecentDownloadCard(record: record);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _fillSampleUrl(String sample) {
    setState(() {
      _urlController.text = sample;
    });
  }
}
