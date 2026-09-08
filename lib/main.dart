import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/history_repository.dart';
import 'presentation/navigation/main_scaffold.dart';
import 'presentation/providers/history_provider.dart';
import 'presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0E14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive for local download history
  await Hive.initFlutter();
  final historyRepo = HistoryRepository();
  await historyRepo.init();

  runApp(
    ProviderScope(
      overrides: [
        historyRepositoryProvider.overrideWithValue(historyRepo),
      ],
      child: const AbleApp(),
    ),
  );
}

class AbleApp extends ConsumerWidget {
  const AbleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Able',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}
