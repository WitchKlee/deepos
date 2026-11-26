/// Persistent `/api/events` SSE event bus and incremental live-turn folder.
library;

import 'dart:async';

import 'errors.dart';
import 'http_transport.dart';
import 'models.dart';

/// Decoded event published on `GET /api/events`.
final class CcBusEvent {
  const CcBusEvent({
    required this.type,
    required this.payload,
    this.eventId,
  });

  final String type;
  final Map<String, Object?> payload;
  final String? eventId;

  String? get sessionId => payload['sessionId']?.toString();
  String? get runId => payload['runId']?.toString();
}

enum CcBusConnectionState { disconnected, connecting, connected, reconnecting }

/// Auto-reconnecting SSE subscriber to `GET /api/events`, preserving
/// `Last-Event-ID` (`<BOOT>.<seq>`) across background freezes.
final class CcEventBus {
  CcEventBus(this._transport);

  final CcHttpTransport _transport;
  final StreamController<CcBusEvent> _eventsController =
      StreamController<CcBusEvent>.broadcast();
  final StreamController<CcBusConnectionState> _stateController =
      StreamController<CcBusConnectionState>.broadcast();

  CcBusConnectionState _state = CcBusConnectionState.disconnected;
  String? _lastEventId;
  bool _running = false;
  int _generation = 0;

  Stream<CcBusEvent> get events => _eventsController.stream;
  Stream<CcBusConnectionState> get stateChanges => _stateController.stream;
  CcBusConnectionState get state => _state;
  String? get lastEventId => _lastEventId;

  void start() {
    if (_running) return;
    _running = true;
    _runLoop(++_generation);
  }

  /// Forces an immediate reconnect (e.g. when returning to foreground).
  void kickReconnect() {
    if (!_running) {
      start();
      return;
    }
    _runLoop(++_generation);
  }

  void stop() {
    _running = false;
    _generation++;
    _setState(CcBusConnectionState.disconnected);
  }

  Future<void> dispose() async {
    stop();
    await _eventsController.close();
    await _stateController.close();
  }

  void _setState(CcBusConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  Future<void> _runLoop(int gen) async {
    var attempt = 0;
    while (_running && gen == _generation) {
      _setState(
        attempt == 0
            ? CcBusConnectionState.connecting
            : CcBusConnectionState.reconnecting,
      );
      try {
        final stream = _transport.openSse(
          '/api/events',
          lastEventId: _lastEventId,
        );
        await for (final frame in stream) {
          if (!_running || gen != _generation) return;
          if (_state != CcBusConnectionState.connected) {
            _setState(CcBusConnectionState.connected);
            attempt = 0;
          }
          if (frame.id != null && frame.id!.isNotEmpty) {
            _lastEventId = frame.id;
          }
          final map = frame.tryDecodeJson();
          if (map == null) continue;
          final type = (map['type'] ?? frame.event ?? 'message').toString();
          if (!_eventsController.isClosed) {
            _eventsController.add(
              CcBusEvent(type: type, payload: map, eventId: frame.id),
            );
          }
        }
      } on CcHttpException catch (e) {
        if (!_running || gen != _generation) return;
        if (e.isUnauthorized) {
          // Gateway may have restarted with a new BOOT id; re-prove before retrying.
          try {
            final refreshed = await CcHttpTransport.connectAndProve(
              token: _transport.signer.token,
              uiHost: _transport.signer.uiHost,
              port: _transport.signer.port,
            );
            _transport.signer = refreshed;
            _lastEventId = null;
          } catch (_) {}
        }
      } catch (_) {
        if (!_running || gen != _generation) return;
      }

      attempt++;
      final backoffMs = (attempt <= 1)
          ? 400
          : (attempt <= 4 ? attempt * 1000 : 5000);
      await Future<void>.delayed(Duration(milliseconds: backoffMs));
    }
  }
}

/// Parses durable session items from `GET /api/session/:id` and folds live
/// SSE stream deltas (`delta`, `thinking_delta`, `tool_use`, `tool_result`,
/// `sub_progress`, `sub_text`, `sub_done`, `discard_partial`) into stable-keyed
/// [CcChatEntry] items for 120Hz list diffing.
final class CcTranscriptParser {
  const CcTranscriptParser._();

  static List<CcChatEntry> parseDurableItems(List<Object?> rawItems) {
    final out = <CcChatEntry>[];
    final pendingTools = <CcToolCallStep>[];
    var groupSeq = 0;
    var msgSeq = 0;

    void flushToolGroup() {
      if (pendingTools.isEmpty) return;
      final firstId = pendingTools.first.id;
      out.add(
        CcToolGroupEntry(
          key: 'tg_${firstId.isNotEmpty ? firstId : groupSeq++}',
          steps: List<CcToolCallStep>.unmodifiable(pendingTools),
        ),
      );
      pendingTools.clear();
    }

    var pendingThinking = '';

    for (final raw in rawItems) {
      if (raw is! Map<String, Object?>) continue;
      if (raw['compact'] == true) {
        flushToolGroup();
        out.add(
          CcCompactDividerEntry(
            key: 'cmp_${raw['uuid'] ?? msgSeq++}',
            chapterNumber: raw['chapter'] is num ? (raw['chapter']! as num).toInt() : null,
            title: raw['chTitle']?.toString(),
            preTokens: raw['pre'] is num ? (raw['pre']! as num).toInt() : null,
            postTokens: raw['post'] is num ? (raw['post']! as num).toInt() : null,
          ),
        );
        continue;
      }

      final role = (raw['role'] ?? raw['type'] ?? '').toString();
      switch (role) {
        case 'user':
          flushToolGroup();
          pendingThinking = '';
          final uuid = raw['uuid']?.toString();
          final offs = raw['off'] is num ? (raw['off']! as num).toInt() : null;
          out.add(
            CcUserEntry(
              key: 'u_${uuid ?? offs ?? msgSeq++}',
              text: (raw['text'] ?? raw['content'] ?? '').toString(),
              uuid: uuid,
              offset: offs,
              timestamp: raw['ts'] is num ? (raw['ts']! as num).toInt() : null,
            ),
          );
        case 'thinking':
          final t = (raw['text'] ?? raw['thinking'] ?? '').toString();
          if (t.isNotEmpty) {
            pendingThinking = pendingThinking.isEmpty ? t : '$pendingThinking\n$t';
          }
        case 'assistant':
        case 'bot':
          flushToolGroup();
          final uuid = raw['uuid']?.toString();
          out.add(
            CcAssistantEntry(
              key: 'a_${uuid ?? msgSeq++}',
              text: (raw['text'] ?? raw['content'] ?? '').toString(),
              thinking: pendingThinking,
              uuid: uuid,
              interrupted: raw['incomplete'] == true,
            ),
          );
          pendingThinking = '';
        case 'tool_use':
          final id = (raw['id'] ?? 'tool_${msgSeq++}').toString();
          final name = (raw['name'] ?? 'Tool').toString();
          final input = raw['input'] is Map<String, Object?>
              ? raw['input']! as Map<String, Object?>
              : const <String, Object?>{};
          pendingTools.add(
            CcToolCallStep(
              id: id,
              name: name,
              input: input,
              isSubagent: raw['sub'] == true || name == 'Task' || name == 'Agent',
            ),
          );
        case 'tool_result':
          final id = (raw['id'] ?? raw['tool_use_id'] ?? '').toString();
          final ok = raw['ok'] != false && raw['is_error'] != true;
          final text = (raw['text'] ?? raw['content'] ?? '').toString();
          final idx = pendingTools.indexWhere((s) => s.id == id);
          if (idx >= 0) {
            pendingTools[idx] = pendingTools[idx].copyWith(
              status: ok ? CcToolStepStatus.succeeded : CcToolStepStatus.failed,
              output: text,
            );
          }
      }
    }

    flushToolGroup();
    if (pendingThinking.isNotEmpty) {
      out.add(
        CcAssistantEntry(
          key: 'a_think_${msgSeq++}',
          text: '',
          thinking: pendingThinking,
        ),
      );
    }
    return out;
  }
}

/// Mutable accumulator for the active streaming run of a single session.
/// Produces stable-keyed live entries (`live_<runId>_*`) so `ChatRowsCache`
/// never rebuilds historical message rows during token streaming.
final class CcLiveTurnAccumulator {
  CcLiveTurnAccumulator({required this.runId});

  final String runId;
  final StringBuffer _textBuf = StringBuffer();
  final StringBuffer _thinkingBuf = StringBuffer();
  final List<CcToolCallStep> _tools = <CcToolCallStep>[];
  final List<CcPermissionPromptEntry> _prompts = <CcPermissionPromptEntry>[];
  String? phase;
  int? contextTokens;
  int? contextWindow;
  bool compacting = false;
  int _segmentIndex = 0;
  final List<CcChatEntry> _committedSegments = <CcChatEntry>[];

  void apply(CcBusEvent ev) {
    final p = ev.payload;
    switch (ev.type) {
      case 'phase':
        phase = p['phase']?.toString();
      case 'compacting':
        compacting = true;
        phase = 'compacting';
      case 'compacted':
        compacting = false;
        if (p['post'] is num) contextTokens = (p['post']! as num).toInt();
      case 'context':
      case 'usage':
        if (p['tokens'] is num) contextTokens = (p['tokens']! as num).toInt();
        if (p['window'] is num) contextWindow = (p['window']! as num).toInt();
      case 'delta':
        final chunk = (p['text'] ?? '').toString();
        if (chunk.isNotEmpty) {
          _flushToolsIfNeeded();
          _textBuf.write(chunk);
        }
      case 'thinking_delta':
        final chunk = (p['text'] ?? '').toString();
        if (chunk.isNotEmpty) {
          _flushToolsIfNeeded();
          _thinkingBuf.write(chunk);
        }
      case 'discard_partial':
        final dropText = p['text'] is num ? (p['text']! as num).toInt() : 0;
        final dropThink = p['think'] is num ? (p['think']! as num).toInt() : 0;
        if (dropText > 0) _trimEnd(_textBuf, dropText);
        if (dropThink > 0) _trimEnd(_thinkingBuf, dropThink);
      case 'assistant_text':
        final full = (p['text'] ?? '').toString();
        if (_textBuf.isEmpty && full.isNotEmpty) {
          _flushToolsIfNeeded();
          _textBuf.write(full);
        }
      case 'thinking':
        final full = (p['text'] ?? '').toString();
        if (_thinkingBuf.isEmpty && full.isNotEmpty) {
          _flushToolsIfNeeded();
          _thinkingBuf.write(full);
        }
      case 'tool_use':
        if (p['parent'] != null) {
          // Subagent child tool call: increment tool count on parent step.
          final parentId = p['parent'].toString();
          final idx = _tools.indexWhere((t) => t.id == parentId);
          if (idx >= 0) {
            _tools[idx] = _tools[idx].copyWith(
              isSubagent: true,
              subagentTools: _tools[idx].subagentTools + 1,
              subagentProgressDesc: '${p['name'] ?? ''}',
            );
          }
          break;
        }
        _commitTextSegmentIfNotEmpty();
        final id = (p['id'] ?? 'tool_${_tools.length}').toString();
        final name = (p['name'] ?? 'Tool').toString();
        final input = p['input'] is Map<String, Object?>
            ? p['input']! as Map<String, Object?>
            : const <String, Object?>{};
        _tools.add(
          CcToolCallStep(
            id: id,
            name: name,
            input: input,
            isSubagent: name == 'Task' || name == 'Agent',
          ),
        );
      case 'tool_result':
        if (p['parent'] != null) break;
        final id = (p['id'] ?? '').toString();
        final ok = p['ok'] != false;
        final text = (p['text'] ?? '').toString();
        final idx = _tools.indexWhere((s) => s.id == id);
        if (idx >= 0) {
          _tools[idx] = _tools[idx].copyWith(
            status: ok ? CcToolStepStatus.succeeded : CcToolStepStatus.failed,
            output: text,
          );
        }
      case 'sub_progress':
        final parentId = (p['parent'] ?? '').toString();
        final idx = _tools.indexWhere((s) => s.id == parentId);
        if (idx >= 0) {
          _tools[idx] = _tools[idx].copyWith(
            isSubagent: true,
            subagentProgressDesc: p['desc']?.toString(),
            subagentTokens: p['tokens'] is num ? (p['tokens']! as num).toInt() : _tools[idx].subagentTokens,
            subagentTools: p['tools'] is num ? (p['tools']! as num).toInt() : _tools[idx].subagentTools,
          );
        }
      case 'sub_text':
        final parentId = (p['parent'] ?? '').toString();
        final idx = _tools.indexWhere((s) => s.id == parentId);
        if (idx >= 0) {
          _tools[idx] = _tools[idx].copyWith(
            isSubagent: true,
            subagentReport: p['text']?.toString(),
          );
        }
      case 'sub_done':
        final parentId = (p['parent'] ?? '').toString();
        final idx = _tools.indexWhere((s) => s.id == parentId);
        if (idx >= 0) {
          _tools[idx] = _tools[idx].copyWith(status: CcToolStepStatus.succeeded);
        }
      case 'perm_ask':
        final reqId = (p['id'] ?? p['reqId'] ?? '').toString();
        if (reqId.isNotEmpty) {
          _prompts.removeWhere((x) => x.requestId == reqId);
          _prompts.add(
            CcPermissionPromptEntry(
              key: 'perm_$reqId',
              requestId: reqId,
              toolName: (p['tool'] ?? p['name'] ?? 'Tool').toString(),
              summary: (p['summary'] ?? p['reason'] ?? p['cmd'] ?? '').toString(),
              details: p,
            ),
          );
        }
      case 'perm_done':
        final reqId = (p['id'] ?? p['reqId'] ?? '').toString();
        _prompts.removeWhere((x) => x.requestId == reqId);
    }
  }

  List<CcChatEntry> buildLiveEntries() {
    final result = <CcChatEntry>[..._committedSegments];
    if (_tools.isNotEmpty) {
      result.add(
        CcToolGroupEntry(
          key: 'live_${runId}_tg_$_segmentIndex',
          steps: List<CcToolCallStep>.unmodifiable(_tools),
        ),
      );
    }
    if (_textBuf.isNotEmpty || _thinkingBuf.isNotEmpty || (_tools.isEmpty && _committedSegments.isEmpty)) {
      result.add(
        CcAssistantEntry(
          key: 'live_${runId}_a_$_segmentIndex',
          text: _textBuf.toString(),
          thinking: _thinkingBuf.toString(),
          streaming: true,
          phase: phase,
          contextTokens: contextTokens,
          contextWindow: contextWindow,
        ),
      );
    }
    result.addAll(_prompts);
    return result;
  }

  void _commitTextSegmentIfNotEmpty() {
    if (_textBuf.isEmpty && _thinkingBuf.isEmpty) return;
    _committedSegments.add(
      CcAssistantEntry(
        key: 'live_${runId}_a_$_segmentIndex',
        text: _textBuf.toString(),
        thinking: _thinkingBuf.toString(),
        streaming: false,
      ),
    );
    _textBuf.clear();
    _thinkingBuf.clear();
    _segmentIndex++;
  }

  void _flushToolsIfNeeded() {
    if (_tools.isEmpty) return;
    _committedSegments.add(
      CcToolGroupEntry(
        key: 'live_${runId}_tg_$_segmentIndex',
        steps: List<CcToolCallStep>.unmodifiable(_tools),
      ),
    );
    _tools.clear();
    _segmentIndex++;
  }

  static void _trimEnd(StringBuffer buf, int count) {
    final current = buf.toString();
    buf.clear();
    if (count < current.length) {
      buf.write(current.substring(0, current.length - count));
    }
  }
}
