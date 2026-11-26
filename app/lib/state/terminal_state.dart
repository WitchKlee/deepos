import 'dart:async';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import 'gateway_state.dart';

final class TerminalTabState {
  const TerminalTabState({
    this.sessions = const <CcTerminalSession>[],
    this.activeTermId,
    this.loading = false,
    this.error,
  });

  final List<CcTerminalSession> sessions;
  final String? activeTermId;
  final bool loading;
  final String? error;

  TerminalTabState copyWith({
    List<CcTerminalSession>? sessions,
    String? activeTermId,
    bool clearActive = false,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return TerminalTabState(
      sessions: sessions ?? this.sessions,
      activeTermId: clearActive ? null : (activeTermId ?? this.activeTermId),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TerminalController extends Notifier<TerminalTabState> {
  final Map<String, Terminal> _terminals = <String, Terminal>{};
  final Map<String, StreamSubscription<String>> _subs =
      <String, StreamSubscription<String>>{};

  @override
  TerminalTabState build() {
    final client = ref.watch(gatewayClientProvider).value;
    ref.onDispose(_disposeAll);
    if (client != null) {
      unawaited(refresh());
    }
    return const TerminalTabState();
  }

  Terminal terminalFor(String termId) {
    return _terminals.putIfAbsent(termId, () {
      final term = Terminal(maxLines: 5000);
      term.onOutput = (String data) {
        final client = ref.read(gatewayClientProvider).value;
        if (client != null) {
          unawaited(client.writeTerminalInput(termId, data).catchError((_) {}));
        }
      };
      term.onResize = (int w, int h, int pw, int ph) {
        final client = ref.read(gatewayClientProvider).value;
        if (client != null) {
          unawaited(
            client.resizeTerminal(termId, cols: w, rows: h).catchError((_) {}),
          );
        }
      };
      _attachStream(termId, term);
      return term;
    });
  }

  void _attachStream(String termId, Terminal term) {
    unawaited(_subs[termId]?.cancel());
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    _subs[termId] = client
        .streamTerminalOutput(
          termId,
          onExit: (code) {
            term.write('\r\n[Process exited with code ${code ?? 0}]\r\n');
            unawaited(refresh());
          },
        )
        .listen(
          term.write,
          onError: (_) {},
        );
  }

  Future<void> refresh() async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final list = await client.listTerminals();
      final nextActive = state.activeTermId != null &&
              list.any((t) => t.id == state.activeTermId)
          ? state.activeTermId
          : (list.isNotEmpty ? list.first.id : null);
      state = state.copyWith(
        sessions: list,
        activeTermId: nextActive,
        clearActive: nextActive == null,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> createTerminal({String? cwd}) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    try {
      final created = await client.createTerminal(cwd: cwd);
      await refresh();
      state = state.copyWith(activeTermId: created.id);
      terminalFor(created.id);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void selectTerminal(String id) {
    state = state.copyWith(activeTermId: id);
    terminalFor(id);
  }

  Future<void> killTerminal(String id) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.killTerminal(id);
    unawaited(_subs.remove(id)?.cancel());
    _terminals.remove(id);
    await refresh();
  }

  void sendQuickInput(String text) {
    final id = state.activeTermId;
    final client = ref.read(gatewayClientProvider).value;
    if (id == null || client == null) return;
    unawaited(client.writeTerminalInput(id, text).catchError((_) {}));
  }

  void _disposeAll() {
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _terminals.clear();
  }
}

final terminalProvider = NotifierProvider<TerminalController, TerminalTabState>(
  TerminalController.new,
);
