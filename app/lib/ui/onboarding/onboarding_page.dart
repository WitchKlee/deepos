import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../runtime/runtime_channel.dart';
import '../../state/app_settings_state.dart';
import '../../state/runtime_state.dart';
import '../theme/deepos_theme.dart';

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  static const _optionalModules = <(String id, String label)>[
    ('cli', 'CLI (git-lfs, tmux, rg, fd, jq)'),
    ('build', 'C/C++ (clang, cmake, ninja)'),
    ('node', 'Node.js Ecosystem (pnpm, yarn, bun)'),
    ('python-tools', 'Python Tools (uv, ruff)'),
    ('go', 'Go Toolchain'),
    ('rust', 'Rust Toolchain'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rt = ref.watch(runtimeProvider);
    final snap = rt.snapshot;
    final blur = ref.watch(appAppearanceProvider.select((a) => a.glassBlur));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SizedBox(height: 12),
            Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.onboardingTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.onboardingSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Package: ${snap.packageId} · targetSdk ${snap.targetSdk} (${snap.execMode})',
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
            if (snap.progress != null && snap.phase.isBusy) ...<Widget>[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: snap.progress!.clamp(0.0, 1.0)),
              const SizedBox(height: 6),
              Text(
                snap.detail ?? l10n.commonLoading,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (snap.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    snap.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            GlassSurface(
              blur: blur,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        snap.devkitInstalled
                            ? Icons.check_circle_rounded
                            : Icons.download_for_offline_rounded,
                        color: snap.devkitInstalled
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.onboardingStepToolkit,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.onboardingStepToolkitDesc,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      const FilterChip(
                        label: Text('base (required)'),
                        selected: true,
                        onSelected: null,
                      ),
                      for (final (id, label) in _optionalModules)
                        FilterChip(
                          label: Text(label),
                          selected: rt.selectedModules.contains(id),
                          onSelected: (_) =>
                              ref.read(runtimeProvider.notifier).toggleModule(id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: snap.phase.isBusy
                            ? null
                            : () => unawaited(
                                  ref.read(runtimeProvider.notifier).installDevkit(),
                                ),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l10n.onboardingInstallToolkit),
                      ),
                      OutlinedButton.icon(
                        onPressed: snap.phase.isBusy
                            ? null
                            : () async {
                                final picked = await FilePicker.pickFiles(
                                  type: FileType.any,
                                );
                                final path = picked.firstOrNull?.path;
                                if (path != null) {
                                  await ref
                                      .read(runtimeProvider.notifier)
                                      .installDevkit(localPath: path);
                                }
                              },
                        icon: const Icon(Icons.folder_zip_outlined),
                        label: Text(l10n.onboardingOfflineArchive),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassSurface(
              blur: blur,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        snap.claudeInstalled
                            ? Icons.check_circle_rounded
                            : Icons.verified_outlined,
                        color: snap.claudeInstalled
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.onboardingStepClaude,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.onboardingStepClaudeDesc,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: snap.phase.isBusy
                        ? null
                        : () => unawaited(
                              ref.read(runtimeProvider.notifier).installClaude(),
                            ),
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: Text(l10n.onboardingInstallClaude),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassSurface(
              blur: blur,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.onboardingStepAuth,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.onboardingStepAuthDesc,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: snap.devkitInstalled && snap.phase != RuntimePhase.running
                            ? () => unawaited(
                                  ref.read(runtimeProvider.notifier).startGateway(),
                                )
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l10n.onboardingStartGateway),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => ref
                              .read(appAppearanceProvider.notifier)
                              .completeOnboarding(),
                          child: Text(l10n.onboardingSkipToWorkspace),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
