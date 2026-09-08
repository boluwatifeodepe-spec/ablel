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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);
    final textMuted = AppColors.getTextMuted(isDark);
    final border = AppColors.getBorder(isDark);

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
            Text(
              'GENERAL',
              style: TextStyle(
                color: textMuted,
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
                    title: Text('Dark Mode', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      settings.themeMode == ThemeMode.dark ? 'Enabled (Cyberpunk Dark)' : 'Disabled (Clean Light)',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                    value: settings.themeMode == ThemeMode.dark,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).toggleTheme(val);
                    },
                  ),
                  Divider(color: border, height: 1),
                  ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: textSecondary),
                    title: Text('App Version', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    trailing: Text(settings.appVersion, style: TextStyle(color: textMuted, fontSize: 13)),
                  ),
                  Divider(color: border, height: 1),
                  ListTile(
                    leading: Icon(Icons.star_outline_rounded, color: textSecondary),
                    title: Text('Rate the App', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right_rounded, color: textMuted),
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
            Text(
              'DATA & SUPPORT',
              style: TextStyle(
                color: textMuted,
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
                    title: Text('Clear Download History', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right_rounded, color: textMuted),
                    onTap: () => _confirmClearHistory(context, ref, isDark),
                  ),
                  Divider(color: border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined, color: AppColors.accentCyan),
                    title: Text('Backend Server URL', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      ApiEndpoints.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                    trailing: Icon(Icons.edit_outlined, color: textMuted, size: 18),
                    onTap: () => _editBackendUrlDialog(context, ref, isDark),
                  ),
                  Divider(color: border, height: 1),
                  ListTile(
                    leading: Icon(Icons.help_outline_rounded, color: textSecondary),
                    title: Text('Report a Problem', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right_rounded, color: textMuted),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contact support at support@ableapp.com')),
                      );
                    },
                  ),
                  Divider(color: border, height: 1),
                  ListTile(
                    leading: Icon(Icons.article_outlined, color: textSecondary),
                    title: Text('About Able', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right_rounded, color: textMuted),
                    onTap: () => _showAboutDialog(context, isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurfaceElevated(isDark),
        title: Text('Clear Download History?', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        content: Text(
          'This will remove all entries from your local download library. Your saved media files on disk will be preserved.',
          style: TextStyle(color: AppColors.getTextSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.getTextMuted(isDark))),
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

  void _editBackendUrlDialog(BuildContext context, WidgetRef ref, bool isDark) {
    final controller = TextEditingController(text: ApiEndpoints.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurfaceElevated(isDark),
        title: Text('Configure Backend URL', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'https://...',
            labelText: 'API Base URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.getTextMuted(isDark))),
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

  void _showAboutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getSurfaceElevated(isDark),
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.accentCyan),
            const SizedBox(width: 8),
            Text('About Able', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'Able is a fast, clean media download utility for saving public content for personal and offline use.\n\n'
            'Notice: Able respects copyright and intellectual property rights. Users are reminded to use downloaded media for personal offline backup only and not to redistribute commercial content without authorization.',
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.accentCyan)),
          ),
        ],
      ),
    );
  }
}
