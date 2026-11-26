import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/l10n.dart';
import 'state/app_settings_state.dart';
import 'state/gateway_state.dart';
import 'ui/shell/root_gate.dart';
import 'ui/theme/deepos_theme.dart';

class DeepOsApp extends ConsumerStatefulWidget {
  const DeepOsApp({super.key, this.home});

  final Widget? home;

  @override
  ConsumerState<DeepOsApp> createState() => _DeepOsAppState();
}

class _DeepOsAppState extends ConsumerState<DeepOsApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately re-establish SSE bus when returning from OEM background freeze.
      ref.read(gatewayClientProvider.notifier).kickReconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appear = ref.watch(appAppearanceProvider);
    final light = DeepOsTheme.build(
      brightness: Brightness.light,
      seed: appear.accentSeed,
    );
    final dark = DeepOsTheme.build(
      brightness: Brightness.dark,
      seed: appear.accentSeed,
    );

    return MaterialApp(
      title: 'DeepOS',
      debugShowCheckedModeBanner: false,
      themeMode: appear.themeMode,
      theme: light,
      darkTheme: dark,
      locale: appear.preferredLocale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, _) {
        final resolved = AppLocale.resolve(appear.preferredLocale, locales);
        AppLocale.use(resolved);
        return resolved;
      },
      home: widget.home ?? const RootGate(),
    );
  }
}
