import 'dart:async';
import 'dart:math';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gateway_state.dart';
import 'sessions_state.dart';

final class QueuedMessageItem {
  const QueuedMessageItem({
    required this.id,
    required this.text,
    this.held = false,
  });

  final String id;
  final String text;
  final bool held;
}

final class ChatState {
  const ChatState({
    required this.sessionKey,
    this.sessionId,
    this.title = '',
    this.cwd,
    this.durableEntries = const <CcChatEntry>[],
    this.liveEntries = const <CcChatEntry>[],
    this.queued = const <QueuedMessageItem>[],
    this.activeRunId,
    this.contextTokens,
    this.contextWindow,
    this.goalText,
    this.backgroundTasks = const <Map<String, Object?>>[],
    this.loading = false,
    this.sending = false,
    this.error,
  });

  /// Family key (`new` for a brand new draft chat, or the real `sessionId`).
  final String sessionKey;
  final String? sessionId;
  final String title;
  final String? cwd;
  final List<CcChatEntry> durableEntries;
  final List<CcChatEntry> liveEntries;
  final List<QueuedMessageItem> queued;
  final String? activeRunId;
  final int? contextTokens;
  final int? contextWindow;
  final String? goalText;
  final List<Map<String, Object?>> backgroundTasks;
  final bool loading;
  final bool sending;
  final String? error;

  bool get isStreaming => activeRunId != null || liveEntries.isNotEmpty;

  /// Combined immutable list passed to `ChatRowsCache` (historical entries keep
  /// identical object identity while only trailing `liveEntries` mutate).
  List<CcChatEntry> get entries =>
      liveEntries.isEmpty ? durableEntries : <CcChatEntry>[...durableEntries, ...liveEntries];

  ChatState copyWith({
    String? sessionId,
    String? title,
    String? cwd,
    List<CcChatEntry>? durableEntries,
    List<CcChatEntry>? liveEntries,
    List<QueuedMessageItem>? queued,
    String? activeRunId,
    bool clearActiveRun = false,
    int? contextTokens,
    int? contextWindow,
    String? goalText,
    bool clearGoal = false,
    List<Map<String, Object?>>? backgroundTasks,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      sessionKey: sessionKey,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      cwd: cwd ?? this.cwd,
      durableEntries: durableEntries ?? this.durableEntries,
      liveEntries: liveEntries ?? this.liveEntries,
      queued: queued ?? this.queued,
      activeRunId: clearActiveRun ? null : (activeRunId ?? this.activeRunId),
      contextTokens: contextTokens ?? this.contextTokens,
      contextWindow: contextWindow ?? this.contextWindow,
      goalText: clearGoal ? null : (goalText ?? this.goalText),
      backgroundTasks: backgroundTasks ?? this.backgroundTasks,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatController extends Notifier<ChatState> {
  ChatController(this._sessionKey);

  final String _sessionKey;
  StreamSubscription<CcBusEvent>? _busSub;
  CcLiveTurnAccumulator? _liveAcc;
  final Random _rng = Random.secure();

  @override
  ChatState build() {
    final initialSessionId = _sessionKey == 'new' ? null : _sessionKey;
    final client = ref.watch(gatewayClientProvider).value;
    ref.onDispose(() => unawaited(_busSub?.cancel()));

    if (client != null) {
      if (initialSessionId != null) {
        unawaited(_loadSession(initialSessionId));
      }
      _busSub = client.eventBus.events.listen(_handleBusEvent);
    }

    return ChatState(
      sessionKey: _sessionKey,
      sessionId: initialSessionId,
    );
  }

  Future<void> reload() async {
    final sid = state.sessionId;
    if (sid != null) await _loadSession(sid);
  }

  Future<void> _loadSession(String sid) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await client.getSessionPage(sid, limit: 80);
      state = state.copyWith(
        sessionId: page.id,
        title: page.title,
        cwd: page.cwd,
        durableEntries: page.entries,
        activeRunId: page.liveRunId,
        contextTokens: page.contextTokens,
        goalText: page.goal?['condition']?.toString(),
        backgroundTasks: page.tasks,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void _handleBusEvent(CcBusEvent ev) {
    final mySid = state.sessionId;
    final evSid = ev.sessionId;
    final evRunId = ev.runId;

    if (ev.type == 'state' || ev.type == 'hello') {
      _syncQueueSnapshot(ev.payload);
      return;
    }

    final matchesSession = mySid != null && evSid == mySid;
    final matchesRun = state.activeRunId != null && evRunId == state.activeRunId;
    if (!matchesSession && !matchesRun) return;

    if (ev.type == 'run_start' && evRunId != null) {
      _liveAcc = CcLiveTurnAccumulator(runId: evRunId);
      state = state.copyWith(
        sessionId: evSid ?? state.sessionId,
        activeRunId: evRunId,
        liveEntries: _liveAcc!.buildLiveEntries(),
      );
      return;
    }

    if (ev.type == 'run_end') {
      final sid = evSid ?? state.sessionId;
      _liveAcc = null;
      state = state.copyWith(
        clearActiveRun: true,
        liveEntries: const <CcChatEntry>[],
      );
      if (sid != null) {
        if (state.sessionId == null) {
          ref.read(sessionsProvider.notifier).selectSession(sid);
        }
        unawaited(_loadSession(sid));
      }
      return;
    }

    if (ev.type == 'goal') {
      final g = ev.payload['goal'];
      final cond = g is Map ? g['condition']?.toString() : null;
      state = cond == null || cond.isEmpty
          ? state.copyWith(clearGoal: true)
          : state.copyWith(goalText: cond);
      return;
    }

    if (ev.type == 'tasks') {
      final raw = ev.payload['tasks'];
      if (raw is List) {
        state = state.copyWith(
          backgroundTasks: raw.whereType<Map<String, Object?>>().toList(),
        );
      }
      return;
    }

    final runId = evRunId ?? state.activeRunId ?? 'live';
    final acc = (_liveAcc != null && _liveAcc!.runId == runId)
        ? _liveAcc!
        : (_liveAcc = CcLiveTurnAccumulator(runId: runId));
    acc.apply(ev);
    state = state.copyWith(
      sessionId: evSid ?? state.sessionId,
      activeRunId: runId,
      liveEntries: acc.buildLiveEntries(),
      contextTokens: acc.contextTokens ?? state.contextTokens,
      contextWindow: acc.contextWindow ?? state.contextWindow,
    );
  }

  void _syncQueueSnapshot(Map<String, Object?> payload) {
    final rawQueue = payload['queue'];
    if (rawQueue is! List) return;
    final mySid = state.sessionId;
    final items = <QueuedMessageItem>[];
    for (final raw in rawQueue) {
      if (raw is! Map) continue;
      final qSid = raw['sessionId']?.toString();
      if (mySid != null && qSid != null && qSid != mySid) continue;
      items.add(
        QueuedMessageItem(
          id: (raw['id'] ?? '').toString(),
          text: (raw['message'] ?? '').toString(),
          held: raw['held'] == true,
        ),
      );
    }
    state = state.copyWith(queued: items);
  }

  Future<void> sendMessage(
    String text, {
    String? pinProvider,
    String? pinModel,
    String? pinEffort,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) {
      state = state.copyWith(error: 'Gateway is not connected');
      return;
    }
    final idem = _randomIdemKey();
    final optimisticUser = CcUserEntry(
      key: 'opt_$idem',
      text: trimmed,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    state = state.copyWith(
      sending: true,
      clearError: true,
      durableEntries: <CcChatEntry>[...state.durableEntries, optimisticUser],
    );
    try {
      final res = await client.sendChat(
        message: trimmed,
        sessionId: state.sessionId,
        idempotencyKey: idem,
        pinProvider: pinProvider,
        pinModel: pinModel,
        pinEffort: pinEffort,
      );
      final runId = res['id']?.toString();
      if (runId != null && res['started'] == true) {
        _liveAcc = CcLiveTurnAccumulator(runId: runId);
        state = state.copyWith(
          sending: false,
          activeRunId: runId,
          liveEntries: _liveAcc!.buildLiveEntries(),
        );
      } else {
        state = state.copyWith(sending: false);
      }
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
    }
  }

  Future<void> stopRun() async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.abortRun(runId: state.activeRunId, sessionId: state.sessionId);
  }

  Future<void> promoteQueued(String queueId) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.promoteQueuedMessage(queueId);
  }

  Future<void> removeQueued(String queueId) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.removeQueuedMessage(queueId);
  }

  Future<void> answerPermission(
    String requestId, {
    required bool allow,
    bool allowForSession = false,
  }) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.answerPermission(
      requestId: requestId,
      allow: allow,
      allowForSession: allowForSession,
    );
  }

  Future<CcRewindPreview?> previewRewind(CcUserEntry entry) async {
    final client = ref.read(gatewayClientProvider).value;
    final sid = state.sessionId;
    if (client == null || sid == null) return null;
    return client.rewindSession(
      sid,
      userText: entry.text,
      uuid: entry.uuid,
      afterOffset: entry.offset,
      dryRun: true,
    );
  }

  Future<CcRewindPreview?> executeRewind(
    CcUserEntry entry, {
    required bool rewindConversation,
  }) async {
    final client = ref.read(gatewayClientProvider).value;
    final sid = state.sessionId;
    if (client == null || sid == null) return null;
    final res = await client.rewindSession(
      sid,
      userText: entry.text,
      uuid: entry.uuid,
      afterOffset: entry.offset,
      dryRun: false,
      rewindConversation: rewindConversation,
    );
    if (res.freshSession) {
      ref.read(sessionsProvider.notifier).selectSession(null);
    } else if (res.forkSessionId != null) {
      ref.read(sessionsProvider.notifier).selectSession(res.forkSessionId);
    } else {
      await _loadSession(sid);
    }
    return res;
  }

  Future<String?> forkFromEntry(CcChatEntry entry) async {
    final client = ref.read(gatewayClientProvider).value;
    final sid = state.sessionId;
    if (client == null || sid == null) return null;
    final uuid = switch (entry) {
      CcUserEntry(:final uuid) => uuid,
      CcAssistantEntry(:final uuid) => uuid,
      _ => null,
    };
    final newSid = await client.forkSession(sid, uuid: uuid, latest: uuid == null);
    if (newSid != null && newSid.isNotEmpty) {
      ref.read(sessionsProvider.notifier).selectSession(newSid);
      unawaited(ref.read(sessionsProvider.notifier).refresh(silent: true));
    }
    return newSid;
  }

  String _randomIdemKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      16,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
  }
}

final chatProvider =
    NotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  ChatController.new,
);
