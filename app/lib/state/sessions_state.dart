import 'dart:async';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gateway_state.dart';

final class SessionsState {
  const SessionsState({
    this.sessions = const <CcSessionSummary>[],
    this.trash = const <CcSessionSummary>[],
    this.activeSessionId,
    this.searchQuery = '',
    this.loading = false,
    this.error,
  });

  final List<CcSessionSummary> sessions;
  final List<CcSessionSummary> trash;
  final String? activeSessionId;
  final String searchQuery;
  final bool loading;
  final String? error;

  SessionsState copyWith({
    List<CcSessionSummary>? sessions,
    List<CcSessionSummary>? trash,
    String? activeSessionId,
    bool clearActiveSession = false,
    String? searchQuery,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return SessionsState(
      sessions: sessions ?? this.sessions,
      trash: trash ?? this.trash,
      activeSessionId: clearActiveSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
      searchQuery: searchQuery ?? this.searchQuery,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SessionsController extends Notifier<SessionsState> {
  StreamSubscription<CcBusEvent>? _busSub;

  @override
  SessionsState build() {
    final client = ref.watch(gatewayClientProvider).value;
    ref.onDispose(() => unawaited(_busSub?.cancel()));
    if (client != null) {
      unawaited(refresh());
      _busSub = client.eventBus.events.listen((ev) {
        if (ev.type == 'run_end' ||
            ev.type == 'state' ||
            ev.type == 'session_gone' ||
            ev.type == 'hello') {
          unawaited(refresh(silent: true));
        }
      });
    }
    return const SessionsState();
  }

  Future<void> refresh({bool silent = false}) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final list = state.searchQuery.trim().isEmpty
          ? await client.listSessions()
          : await client.searchSessions(state.searchQuery.trim());
      state = state.copyWith(sessions: list, loading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadTrash() async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    try {
      final items = await client.listTrash();
      state = state.copyWith(trash: items);
    } catch (_) {}
  }

  void selectSession(String? sessionId) {
    state = sessionId == null
        ? state.copyWith(clearActiveSession: true)
        : state.copyWith(activeSessionId: sessionId);
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await refresh();
  }

  Future<void> renameSession(String id, String title) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.renameSession(id, title);
    await refresh(silent: true);
  }

  Future<void> togglePin(CcSessionSummary session) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.pinSession(session.id, pinned: !session.isPinned);
    await refresh(silent: true);
  }

  Future<void> trashSession(String id) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.trashSession(id);
    if (state.activeSessionId == id) {
      state = state.copyWith(clearActiveSession: true);
    }
    await refresh(silent: true);
    await loadTrash();
  }

  Future<void> restoreSession(String id) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.restoreFromTrash(id);
    await refresh(silent: true);
    await loadTrash();
  }
}

final sessionsProvider = NotifierProvider<SessionsController, SessionsState>(
  SessionsController.new,
);
