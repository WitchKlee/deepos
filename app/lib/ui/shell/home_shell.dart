import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/chat_state.dart';
import '../../state/providers_state.dart';
import '../../state/runtime_state.dart';
import '../../state/sessions_state.dart';
import '../chat/chat_screen.dart';
import '../extensions/extensions_page.dart';
import '../files/files_page.dart';
import '../settings/settings_page.dart';
import '../terminal/terminal_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    if (isWide) {
      return Scaffold(
        key: _scaffoldKey,
        endDrawer: const Drawer(child: _QuickPanelDrawer()),
        body: Row(
          children: <Widget>[
            const SizedBox(width: 296, child: _SessionsDrawer(embedded: true)),
            const VerticalDivider(width: 1),
            Expanded(
              child: ChatScreen(
                onOpenDrawer: () {},
                onOpenQuickPanel: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const Drawer(child: _SessionsDrawer(embedded: false)),
      endDrawer: const Drawer(child: _QuickPanelDrawer()),
      body: ChatScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        onOpenQuickPanel: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
    );
  }
}

class _SessionsDrawer extends ConsumerWidget {
  const _SessionsDrawer({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final st = ref.watch(sessionsProvider);
    final ctrl = ref.read(sessionsProvider.notifier);

    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ctrl.selectSession(null);
                      if (!embedded) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.navNewChat),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => unawaited(ctrl.refresh()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                hintText: l10n.navSessions,
                isDense: true,
              ),
              onSubmitted: (q) => unawaited(ctrl.setSearchQuery(q)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: st.sessions.length,
              itemBuilder: (context, index) {
                final s = st.sessions[index];
                final selected = s.id == st.activeSessionId;
                return ListTile(
                  dense: true,
                  selected: selected,
                  leading: Icon(
                    s.isPinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline_rounded,
                    size: 18,
                  ),
                  title: Text(
                    s.title.isEmpty ? s.id.substring(0, s.id.length.clamp(0, 8)) : s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: s.preview != null
                      ? Text(
                          s.preview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (act) {
                      if (act == 'pin') unawaited(ctrl.togglePin(s));
                      if (act == 'trash') unawaited(ctrl.trashSession(s.id));
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(s.isPinned ? 'Unpin' : 'Pin'),
                      ),
                      PopupMenuItem(
                        value: 'trash',
                        child: Text(l10n.commonDelete),
                      ),
                    ],
                  ),
                  onTap: () {
                    ctrl.selectSession(s.id);
                    if (!embedded) Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 4,
              children: <Widget>[
                _NavIconButton(
                  icon: Icons.terminal_rounded,
                  label: l10n.navTerminal,
                  onTap: () => _pushPage(context, const TerminalPage()),
                ),
                _NavIconButton(
                  icon: Icons.folder_outlined,
                  label: l10n.navFiles,
                  onTap: () => _pushPage(context, const FilesPage()),
                ),
                _NavIconButton(
                  icon: Icons.extension_outlined,
                  label: l10n.navExtensions,
                  onTap: () => _pushPage(context, const ExtensionsPage()),
                ),
                _NavIconButton(
                  icon: Icons.settings_outlined,
                  label: l10n.navSettings,
                  onTap: () => _pushPage(context, const SettingsPage()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pushPage(BuildContext context, Widget page) {
    if (!embedded) Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _QuickPanelDrawer extends ConsumerWidget {
  const _QuickPanelDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final providers = ref.watch(providersProvider);
    final sel = providers.activeSelection;
    final activeSid = ref.watch(sessionsProvider.select((s) => s.activeSessionId));
    final sessionKey = activeSid ?? 'new';
    final (ctxTokens, ctxWindow) = ref.watch(
      chatProvider(sessionKey).select((s) => (s.contextTokens, s.contextWindow)),
    );
    final safeMode = ref.watch(runtimeProvider.select((r) => r.safeMode));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            l10n.quickPanelTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Text(l10n.quickPanelProvider, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: providers.providers.any((p) => p.id == sel?.provider)
                ? sel?.provider
                : null,
            items: <DropdownMenuItem<String>>[
              for (final p in providers.providers)
                DropdownMenuItem(value: p.id, child: Text(p.label)),
            ],
            onChanged: (v) {
              if (v != null) {
                unawaited(
                  ref.read(providersProvider.notifier).selectSessionModel(provider: v),
                );
              }
            },
          ),
          const SizedBox(height: 14),
          Text(l10n.quickPanelModel, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: providers.models.any((m) => m.id == sel?.model)
                ? sel?.model
                : null,
            items: <DropdownMenuItem<String>>[
              for (final m in providers.models)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(m.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                unawaited(
                  ref.read(providersProvider.notifier).selectSessionModel(model: v),
                );
              }
            },
          ),
          const SizedBox(height: 14),
          Text(l10n.quickPanelEffort, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment(value: 'low', label: Text('Low')),
              ButtonSegment(value: 'medium', label: Text('Med')),
              ButtonSegment(value: 'high', label: Text('High')),
            ],
            selected: <String>{
              if (<String>{'low', 'medium', 'high'}.contains(sel?.effort))
                sel!.effort
              else
                'medium',
            },
            onSelectionChanged: (s) => unawaited(
              ref.read(providersProvider.notifier).selectSessionModel(effort: s.first),
            ),
          ),
          if (sel?.own == true && activeSid != null) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => unawaited(
                ref.read(providersProvider.notifier).selectSessionModel(reset: true),
              ),
              child: Text(l10n.quickPanelResetSessionModel),
            ),
          ],
          if (ctxTokens != null && ctxTokens > 0) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              '${l10n.quickPanelContext}: ${(ctxTokens / 1000).toStringAsFixed(1)}k'
              '${ctxWindow != null && ctxWindow > 0 ? ' / ${(ctxWindow / 1000).toStringAsFixed(0)}k' : ''}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (ctxWindow != null && ctxWindow > 0)
                  ? (ctxTokens / ctxWindow).clamp(0.0, 1.0)
                  : null,
            ),
          ],
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.quickPanelSafeMode),
            value: safeMode,
            onChanged: (v) => unawaited(
              ref.read(runtimeProvider.notifier).startGateway(safeMode: v),
            ),
          ),
        ],
      ),
    );
  }
}
