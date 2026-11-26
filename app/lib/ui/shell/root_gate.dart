import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_settings_state.dart';
import '../../state/runtime_state.dart';
import '../onboarding/onboarding_page.dart';
import 'home_shell.dart';

/// Root landing gate: shows [OnboardingPage] until toolkit + Claude Code are
/// installed (or user explicitly enters workspace), then mounts [HomeShell].
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(
      appAppearanceProvider.select((a) => a.onboardingDone),
    );
    final ready = ref.watch(
      runtimeProvider.select(
        (r) => r.snapshot.devkitInstalled && r.snapshot.claudeInstalled,
      ),
    );
    if (!onboardingDone && !ready) {
      return const OnboardingPage();
    }
    return const HomeShell();
  }
}
