import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_mode.dart';

@immutable
class ThemeSettingsState {
  const ThemeSettingsState({
    this.preset = AppThemePreset.cosmicGlass,
    this.reducedBlur = false,
    this.fontScale = 1.0,
    this.hapticsEnabled = true,
  });

  final AppThemePreset preset;
  final bool reducedBlur;
  final double fontScale;
  final bool hapticsEnabled;

  ThemeSettingsState copyWith({
    AppThemePreset? preset,
    bool? reducedBlur,
    double? fontScale,
    bool? hapticsEnabled,
  }) {
    return ThemeSettingsState(
      preset: preset ?? this.preset,
      reducedBlur: reducedBlur ?? this.reducedBlur,
      fontScale: fontScale ?? this.fontScale,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

class ThemeSettingsNotifier extends Notifier<ThemeSettingsState> {
  static const _kThemeKey = 'orbi_theme_preset';
  static const _kReducedBlurKey = 'orbi_reduced_blur';
  static const _kFontScaleKey = 'orbi_font_scale';
  static const _kHapticsKey = 'orbi_haptics_enabled';

  @override
  ThemeSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ThemeSettingsState(
      preset: AppThemePreset.fromId(prefs.getString(_kThemeKey)),
      reducedBlur: prefs.getBool(_kReducedBlurKey) ?? false,
      fontScale: (prefs.getDouble(_kFontScaleKey) ?? 1.0).clamp(0.85, 1.3),
      hapticsEnabled: prefs.getBool(_kHapticsKey) ?? true,
    );
  }

  Future<void> setPreset(AppThemePreset preset) async {
    state = state.copyWith(preset: preset);
    await ref.read(sharedPreferencesProvider).setString(_kThemeKey, preset.id);
  }

  Future<void> setReducedBlur(bool value) async {
    state = state.copyWith(reducedBlur: value);
    await ref.read(sharedPreferencesProvider).setBool(_kReducedBlurKey, value);
  }

  Future<void> setFontScale(double value) async {
    final clamped = value.clamp(0.85, 1.3).toDouble();
    state = state.copyWith(fontScale: clamped);
    await ref.read(sharedPreferencesProvider).setDouble(_kFontScaleKey, clamped);
  }

  Future<void> setHapticsEnabled(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kHapticsKey, value);
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettingsState>(
  ThemeSettingsNotifier.new,
);
