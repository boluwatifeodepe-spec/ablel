import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:able_app/core/theme/app_theme.dart';
import 'package:able_app/core/utils/platform_utils.dart';
import 'package:able_app/presentation/navigation/main_scaffold.dart';
import 'package:able_app/presentation/widgets/platform_chip.dart';
import 'package:able_app/presentation/widgets/gradient_button.dart';
import 'package:able_app/presentation/widgets/circular_progress_gauge.dart';

void main() {
  testWidgets('PlatformChip renders platform name and icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlatformChip(
            platform: SocialPlatform.tiktok,
          ),
        ),
      ),
    );

    expect(find.text('TikTok'), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('GradientButton renders text and responds to tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientButton(
            text: 'Paste & Analyze',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Paste & Analyze'), findsOneWidget);
    await tester.tap(find.text('Paste & Analyze'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('CircularProgressGauge renders percentage text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CircularProgressGauge(
            progress: 0.75,
            percentage: 75,
          ),
        ),
      ),
    );

    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('MainScaffold renders Home and Library navigation items', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MainScaffold(),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Able'), findsOneWidget);
    expect(find.text('Paste a link to download'), findsOneWidget);
  });
}
