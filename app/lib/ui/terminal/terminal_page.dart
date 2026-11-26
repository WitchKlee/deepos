import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../l10n/l10n.dart';
import '../../state/gateway_state.dart';
import '../../state/terminal_state.dart';

class TerminalPage extends ConsumerWidget {
  const TerminalPage({super.key});

  static const _shortcuts = <(String label, String seq)>[
    ('ESC', '\x1b'),
    ('TAB', '\t'),
    ('CTRL-C', '\x03'),
    ('CTRL-D', '\x04'),
    ('↑', '\x1b[A'),
    ('↓', '\x1b[B'),
    ('/', '/'),
    ('priv ', 'priv '),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final connected = ref.watch(gatewayClientProvider).value != null;
    final st = ref.watch(terminalProvider);
    final ctrl = ref.read(terminalProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.terminalTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.terminalNew,
            onPressed: connected ? () => unawaited(ctrl.createTerminal()) : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.commonRefresh,
            onPressed: connected ? () => unawaited(ctrl.refresh()) : null,
          ),
        ],
      ),
      body: !connected
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.terminalUnavailable),
              ),
            )
          : Column(
              children: <Widget>[
                if (st.sessions.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: <Widget>[
                        for (final s in st.sessions)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InputChip(
                              selected: s.id == st.activeTermId,
                              label: Text(s.title),
                              onSelected: (_) => ctrl.selectTerminal(s.id),
                              onDeleted: () => unawaited(ctrl.killTerminal(s.id)),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: st.activeTermId == null
                      ? Center(
                          child: FilledButton.icon(
                            onPressed: () => unawaited(ctrl.createTerminal()),
                            icon: const Icon(Icons.terminal_rounded),
                            label: Text(l10n.terminalNew),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF0B0B10),
                          padding: const EdgeInsets.all(6),
                          child: TerminalView(
                            ctrl.terminalFor(st.activeTermId!),
                            autofocus: true,
                            textStyle: const TerminalStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      children: <Widget>[
                        for (final (label, seq) in _shortcuts)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                minimumSize: const Size(0, 32),
                              ),
                              onPressed: st.activeTermId == null
                                  ? null
                                  : () => ctrl.sendQuickInput(seq),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
