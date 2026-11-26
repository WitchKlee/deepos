import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../state/app_settings_state.dart';
import '../../state/priv_state.dart';
import '../../state/providers_state.dart';
import '../../state/runtime_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appear = ref.watch(appAppearanceProvider);
    final providers = ref.watch(providersProvider);
    final priv = ref.watch(privProvider);
    final rt = ref.watch(runtimeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          // 1. Model Providers & Claude.ai OAuth
          _SectionTitle(l10n.settingsProviders),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: Text(l10n.settingsClaudeLogin),
                  subtitle: Text(
                    providers.loginStatus['loggedIn'] == true
                        ? (providers.loginStatus['email'] ?? 'Signed in').toString()
                        : 'OAuth via browser',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      final url = await ref
                          .read(providersProvider.notifier)
                          .startClaudeOAuth();
                      if (url != null && url.isNotEmpty) {
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Text(l10n.commonConfirm),
                  ),
                ),
                const Divider(height: 1),
                for (final p in providers.providers)
                  ListTile(
                    title: Text(p.label),
                    subtitle: Text(
                      p.hasKey ? '${p.id} · API Key saved' : '${p.id} · ${p.baseUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (providers.globalProviderId == p.id)
                          const Icon(Icons.check_circle_rounded, color: Colors.green),
                        IconButton(
                          icon: const Icon(Icons.key_rounded),
                          onPressed: () => _editApiKeyDialog(context, ref, p.id, p.label),
                        ),
                      ],
                    ),
                    onTap: () => unawaited(
                      ref.read(providersProvider.notifier).selectGlobalProvider(p.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Appearance & Language
          _SectionTitle(l10n.settingsAppearance),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  title: Text(l10n.settingsThemeMode),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: <ThemeMode>{appear.themeMode},
                    onSelectionChanged: (s) => unawaited(
                      ref.read(appAppearanceProvider.notifier).setThemeMode(s.first),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.settingsGlassBlur),
                  value: appear.glassBlur,
                  onChanged: (v) => unawaited(
                    ref.read(appAppearanceProvider.notifier).setGlassBlur(v),
                  ),
                ),
                ListTile(
                  title: Text(l10n.settingsLanguage),
                  trailing: DropdownButton<AppLanguagePref>(
                    value: appear.language,
                    underline: const SizedBox.shrink(),
                    items: const <DropdownMenuItem<AppLanguagePref>>[
                      DropdownMenuItem(value: AppLanguagePref.system, child: Text('System')),
                      DropdownMenuItem(value: AppLanguagePref.zh, child: Text('简体中文')),
                      DropdownMenuItem(value: AppLanguagePref.en, child: Text('English')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        unawaited(
                          ref.read(appAppearanceProvider.notifier).setLanguage(v),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Optional Shizuku CLI `priv` & `cc-mem` helper (NO AccessibilityService)
          _SectionTitle(l10n.settingsShizuku),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.settingsShizukuDesc,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Shizuku: installed=${priv.status.installed}, running=${priv.status.running}, granted=${priv.status.granted}',
                    style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: () => unawaited(
                          ref.read(privProvider.notifier).requestPermission(),
                        ),
                        child: Text(l10n.settingsShizukuRequest),
                      ),
                      OutlinedButton(
                        onPressed: () => unawaited(
                          ref.read(privProvider.notifier).openShizukuManager(),
                        ),
                        child: Text(l10n.settingsShizukuOpen),
                      ),
                    ],
                  ),
                  if (priv.auditLog.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      l10n.settingsShizukuAudit,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    for (final line in priv.auditLog.take(8))
                      Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Gateway & Runtime Diagnostics
          _SectionTitle(l10n.settingsGatewayStatus),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${rt.snapshot.packageId} · ${rt.snapshot.phase.name} · '
                    'http://${rt.snapshot.uiHost}:${rt.snapshot.port} '
                    '(sdk${rt.snapshot.targetSdk}/${rt.snapshot.execMode})',
                    style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: () => unawaited(
                          ref.read(runtimeProvider.notifier).startGateway(),
                        ),
                        child: Text(l10n.settingsGatewayRestart),
                      ),
                      OutlinedButton(
                        onPressed: () => unawaited(
                          ref.read(runtimeProvider.notifier).stopGateway(),
                        ),
                        child: Text(l10n.settingsGatewayStop),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
    String providerId,
    String label,
  ) async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text('$label · ${l10n.settingsApiKey}'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'sk-...'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (saved == true && ctrl.text.trim().isNotEmpty) {
      await ref
          .read(providersProvider.notifier)
          .saveApiKey(providerId, ctrl.text.trim());
    }
    ctrl.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
