import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_endpoints.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String appVersion;
  final String backendUrl;

  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.appVersion = 'v2.4.1',
    this.backendUrl = '',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? appVersion,
    String? backendUrl,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      appVersion: appVersion ?? this.appVersion,
      backendUrl: backendUrl ?? this.backendUrl,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(backendUrl: ApiEndpoints.baseUrl));

  void toggleTheme(bool isDark) {
    state = state.copyWith(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void updateBackendUrl(String url) {
    ApiEndpoints.customBaseUrl = url.trim();
    state = state.copyWith(backendUrl: ApiEndpoints.baseUrl);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
