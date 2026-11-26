import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

enum AppLanguagePref { system, zh, en }

final class AppAppearanceState {
  const AppAppearanceState({
    this.themeMode = ThemeMode.system,
    this.glassBlur = true,
    this.accentSeed = const Color(0xFF8E86A9),
    this.language = AppLanguagePref.system,
    this.onboardingDone = false,
  });

  final ThemeMode themeMode;
  final bool glassBlur;
  final Color accentSeed;
  final AppLanguagePref language;
  final bool onboardingDone;

  Locale? get preferredLocale => switch (language) {
    AppLanguagePref.system => null,
    AppLanguagePref.zh => AppLocale.zhCN,
    AppLanguagePref.en => AppLocale.en,
  };

  AppAppearanceState copyWith({
    ThemeMode? themeMode,
    bool? glassBlur,
    Color? accentSeed,
    AppLanguagePref? language,
    bool? onboardingDone,
  }) {
    return AppAppearanceState(
      themeMode: themeMode ?? this.themeMode,
      glassBlur: glassBlur ?? this.glassBlur,
      accentSeed: accentSeed ?? this.accentSeed,
      language: language ?? this.language,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }
}

class AppAppearanceController extends Notifier<AppAppearanceState> {
  static const _kTheme = 'deepos.themeMode';
  static const _kBlur = 'deepos.glassBlur';
  static const _kLang = 'deepos.language';
  static const _kOnboard = 'deepos.onboardingDone';

  @override
  AppAppearanceState build() {
    _hydrate();
    return const AppAppearanceState();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_kTheme);
      final mode = ThemeMode.values.where((m) => m.name == themeName).firstOrNull ??
          ThemeMode.system;
      final langName = prefs.getString(_kLang);
      final lang = AppLanguagePref.values.where((l) => l.name == langName).firstOrNull ??
          AppLanguagePref.system;
      final blur = prefs.getBool(_kBlur) ?? true;
      final done = prefs.getBool(_kOnboard) ?? false;
      state = state.copyWith(
        themeMode: mode,
        glassBlur: blur,
        language: lang,
        onboardingDone: done,
      );
      if (lang != AppLanguagePref.system) {
        AppLocale.use(lang == AppLanguagePref.en ? AppLocale.en : AppLocale.zhCN);
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode.name);
  }

  Future<void> setGlassBlur(bool enabled) async {
    state = state.copyWith(glassBlur: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBlur, enabled);
  }

  Future<void> setLanguage(AppLanguagePref lang) async {
    state = state.copyWith(language: lang);
    if (lang != AppLanguagePref.system) {
      AppLocale.use(lang == AppLanguagePref.en ? AppLocale.en : AppLocale.zhCN);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, lang.name);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingDone: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboard, true);
  }
}

final appAppearanceProvider =
    NotifierProvider<AppAppearanceController, AppAppearanceState>(
  AppAppearanceController.new,
);
