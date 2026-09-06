import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // GENERAL SECTION
            const Text(
              'GENERAL',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.accentCyan),
                    title: const Text('Dark Mode', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('System default', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    value: settings.themeMode == ThemeMode.dark,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).toggleTheme(val);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                    title: const Text('App Version', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    trailing: Text(settings.appVersion, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.star_outline_rounded, color: AppColors.textSecondary),
                    title: const Text('Rate the App', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thank you for supporting Able!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // DATA & SUPPORT SECTION
            const Text(
              'DATA & SUPPORT',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                    title: const Text('Clear Download History', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => _confirmClearHistory(context, ref),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined, color: AppColors.accentCyan),
                    title: const Text('Backend Server URL', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(ApiEndpoints.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
                    onTap: () => _editBackendUrlDialog(context, ref),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary),
                    title: const Text('Report a Problem', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contact support at support@ableapp.com')),
                      );
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.article_outlined, color: AppColors.textSecondary),
                    title: const Text('About Able', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Clear Download History?'),
        content: const Text(
          'This will remove all entries from your local download library. Your saved media files on disk will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(historyProvider.notifier).clearAll();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download history cleared.')),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editBackendUrlDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ApiEndpoints.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Configure Backend URL'),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'https://...',
            labelText: 'API Base URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            onPressed: () {
              ref.read(settingsProvider.notifier).updateBackendUrl(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.accentCyan),
            SizedBox(width: 8),
            Text('About Able'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Able is a fast, clean media download utility for saving public content for personal and offline use.\n\n'
            'Notice: Able respects copyright and intellectual property rights. Users are reminded to use downloaded media for personal offline backup only and not to redistribute commercial content without authorization.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryPurple)),
          ),
        ],
      ),
    );
  }
}
