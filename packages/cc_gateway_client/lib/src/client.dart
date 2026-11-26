/// High-level pure Dart API client for the local Claude Code native gateway.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'auth_signer.dart';
import 'event_bus.dart';
import 'http_transport.dart';
import 'models.dart';

/// Unified client wrapping all native gateway routes (`/api/*`).
final class CcGatewayClient {
  CcGatewayClient({
    required CcHttpTransport transport,
  }) : _transport = transport,
       eventBus = CcEventBus(transport);

  final CcHttpTransport _transport;
  final CcEventBus eventBus;

  CcAuthSigner get signer => _transport.signer;

  set languageCode(String code) {
    _transport.languageCode = code;
  }

  /// Connects to the local gateway, verifies `/__proof`, and starts the SSE bus.
  static Future<CcGatewayClient> connect({
    required String token,
    String? spawnSecret,
    String uiHost = '127.0.0.2',
    int port = 8791,
    String languageCode = 'zh',
    bool startEventBus = true,
  }) async {
    final signer = await CcHttpTransport.connectAndProve(
      token: token,
      spawnSecret: spawnSecret,
      uiHost: uiHost,
      port: port,
    );
    final transport = CcHttpTransport(
      signer: signer,
      languageCode: languageCode,
    );
    final client = CcGatewayClient(transport: transport);
    if (startEventBus) client.eventBus.start();
    return client;
  }

  Future<void> close() async {
    await eventBus.dispose();
    _transport.close();
  }

  // ── Status & Capabilities ──────────────────────────────────────────────

  Future<Map<String, Object?>> getStatus() => _transport.getJson('/api/status');

  Future<Map<String, Object?>> getStateSnapshot() => _transport.getJson('/api/state');

  Future<Map<String, Object?>> getCapabilities() =>
      _transport.getJson('/api/capabilities');

  Future<Map<String, Object?>> setSafeMode({required bool enabled}) =>
      _transport.postJson('/api/safe-mode', body: <String, Object?>{'on': enabled});

  // ── Chat, Queue, Permissions & Abort ───────────────────────────────────

  /// Enqueues or starts a turn (`POST /api/chat`).
  Future<Map<String, Object?>> sendChat({
    required String message,
    String? sessionId,
    String? projectId,
    String? idempotencyKey,
    List<String>? attachments,
    String? pinProvider,
    String? pinModel,
    String? pinEffort,
  }) {
    final body = <String, Object?>{
      'message': message,
      if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'idem': idempotencyKey,
      if (attachments != null && attachments.isNotEmpty) 'files': attachments,
      if (sessionId == null && (pinProvider != null || pinModel != null || pinEffort != null))
        'pin': <String, Object?>{
          'provider': ?pinProvider,
          'model': ?pinModel,
          'effort': ?pinEffort,
        },
    };
    return _transport.postJson('/api/chat', body: body);
  }

  /// Stops an active run (`POST /api/abort`). Queued messages are held rather
  /// than auto-sent, matching `cccodroid` user-intent safety rules.
  Future<Map<String, Object?>> abortRun({
    String? runId,
    String? sessionId,
  }) =>
      _transport.postJson(
        '/api/abort',
        body: <String, Object?>{
          'id': ?runId,
          'sessionId': ?sessionId,
        },
      );

  /// ⚡ Promotes a queued item (`POST /api/queue/promote`), injecting it into
  /// the live turn without aborting when compatible.
  Future<Map<String, Object?>> promoteQueuedMessage(String queueId) =>
      _transport.postJson('/api/queue/promote', body: <String, Object?>{'id': queueId});

  Future<Map<String, Object?>> removeQueuedMessage(String queueId) =>
      _transport.postJson('/api/queue/remove', body: <String, Object?>{'id': queueId});

  Future<Map<String, Object?>> editQueuedMessage(String queueId, String text) =>
      _transport.postJson(
        '/api/queue/edit',
        body: <String, Object?>{'id': queueId, 'text': text},
      );

  Future<Map<String, Object?>> clearQueue({List<String>? ids}) =>
      _transport.postJson(
        '/api/queue/clear',
        body: <String, Object?>{'ids': ?ids},
      );

  /// Responds to a sensitive-operation `PreToolUse` prompt (`POST /api/perm/answer`).
  Future<Map<String, Object?>> answerPermission({
    required String requestId,
    required bool allow,
    bool allowForSession = false,
  }) =>
      _transport.postJson(
        '/api/perm/answer',
        body: <String, Object?>{
          'id': requestId,
          'allow': allow,
          if (allowForSession) 'session': true,
        },
      );

  Future<Map<String, Object?>> setPermissionMode(String mode) =>
      _transport.postJson('/api/perm/mode', body: <String, Object?>{'mode': mode});

  Future<Map<String, Object?>> stopBackgroundTask({
    required String taskId,
    String? sessionId,
  }) =>
      _transport.postJson(
        '/api/task/stop',
        body: <String, Object?>{
          'id': taskId,
          'sessionId': ?sessionId,
        },
      );

  // ── Sessions, Transcript, Rewind, Fork & Trash ─────────────────────────

  Future<List<CcSessionSummary>> listSessions({
    String? projectId,
    int limit = 200,
    bool includeMisc = false,
  }) async {
    final res = await _transport.getJson(
      '/api/sessions',
      query: <String, String?>{
        'limit': '$limit',
        'project': ?projectId,
        if (includeMisc) 'misc': '1',
      },
    );
    final raw = res['sessions'] ?? res['items'];
    if (raw is! List) return const <CcSessionSummary>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcSessionSummary.fromJson)
        .toList();
  }

  Future<List<CcSessionSummary>> searchSessions(String query) async {
    final res = await _transport.getJson(
      '/api/sessions/search',
      query: <String, String?>{'q': query},
    );
    final raw = res['results'] ?? res['sessions'] ?? res['items'];
    if (raw is! List) return const <CcSessionSummary>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcSessionSummary.fromJson)
        .toList();
  }

  Future<CcSessionPage> getSessionPage(
    String sessionId, {
    int limit = 50,
    int? beforeOffset,
    int? afterOffset,
  }) async {
    final encoded = Uri.encodeComponent(sessionId);
    final res = await _transport.getJson(
      '/api/session/$encoded',
      query: <String, String?>{
        'limit': '$limit',
        if (beforeOffset != null) 'before': '$beforeOffset',
        if (afterOffset != null) 'after': '$afterOffset',
      },
    );
    final rawItems = res['items'] is List ? res['items']! as List<Object?> : const <Object?>[];
    final rawTasks = res['tasks'] is List
        ? (res['tasks']! as List<Object?>).whereType<Map<String, Object?>>().toList()
        : const <Map<String, Object?>>[];
    return CcSessionPage(
      id: (res['id'] ?? sessionId).toString(),
      title: (res['title'] ?? '').toString(),
      cwd: res['cwd']?.toString(),
      entries: CcTranscriptParser.parseDurableItems(rawItems),
      cursor: res['cursor'] is num ? (res['cursor']! as num).toInt() : null,
      nextOffset: res['next'] is num ? (res['next']! as num).toInt() : null,
      totalSize: res['size'] is num ? (res['size']! as num).toInt() : 0,
      contextTokens: res['contextTokens'] is num
          ? (res['contextTokens']! as num).toInt()
          : null,
      liveRunId: res['liveRunId']?.toString(),
      goal: res['goal'] is Map<String, Object?>
          ? res['goal']! as Map<String, Object?>
          : null,
      tasks: rawTasks,
    );
  }

  Future<void> renameSession(String sessionId, String title) async {
    final encoded = Uri.encodeComponent(sessionId);
    await _transport.postJson(
      '/api/session/$encoded/rename',
      body: <String, Object?>{'title': title},
    );
  }

  Future<void> pinSession(String sessionId, {required bool pinned}) async {
    final encoded = Uri.encodeComponent(sessionId);
    await _transport.postJson(
      '/api/session/$encoded/pin',
      body: <String, Object?>{'pin': pinned},
    );
  }

  Future<void> trashSession(String sessionId) async {
    final encoded = Uri.encodeComponent(sessionId);
    await _transport.deleteJson('/api/session/$encoded');
  }

  Future<List<CcSessionSummary>> listTrash() async {
    final res = await _transport.getJson('/api/trash');
    final raw = res['items'] ?? res['trash'];
    if (raw is! List) return const <CcSessionSummary>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcSessionSummary.fromJson)
        .toList();
  }

  Future<void> restoreFromTrash(String sessionId) async {
    await _transport.postJson(
      '/api/trash/restore',
      body: <String, Object?>{'id': sessionId},
    );
  }

  Future<CcRewindPreview> rewindSession(
    String sessionId, {
    required String userText,
    String? uuid,
    int? afterOffset,
    bool dryRun = true,
    bool rewindConversation = false,
  }) async {
    final encoded = Uri.encodeComponent(sessionId);
    final res = await _transport.postJson(
      '/api/session/$encoded/rewind',
      body: <String, Object?>{
        'userText': userText,
        'uuid': ?uuid,
        'after': ?afterOffset,
        'dryRun': dryRun,
        'conversation': rewindConversation,
      },
    );
    return CcRewindPreview.fromJson(res);
  }

  Future<String?> forkSession(
    String sessionId, {
    String userText = '',
    String? uuid,
    int? afterOffset,
    bool latest = false,
  }) async {
    final encoded = Uri.encodeComponent(sessionId);
    final res = await _transport.postJson(
      '/api/session/$encoded/fork',
      body: <String, Object?>{
        'userText': userText,
        'uuid': ?uuid,
        'after': ?afterOffset,
        if (latest) 'latest': true,
      },
    );
    return res['id']?.toString() ?? res['sessionId']?.toString();
  }

  Future<List<CcChatEntry>> getSubagentSteps(
    String sessionId, {
    required String toolUseId,
  }) async {
    final encoded = Uri.encodeComponent(sessionId);
    final res = await _transport.getJson(
      '/api/session/$encoded/agent',
      query: <String, String?>{'tool': toolUseId},
    );
    final raw = res['items'];
    if (raw is! List) return const <CcChatEntry>[];
    return CcTranscriptParser.parseDurableItems(raw);
  }

  // ── Providers, Models, Per-Session Model & Claude OAuth Login ──────────

  Future<List<CcProviderInfo>> listProviders() async {
    final res = await _transport.getJson('/api/providers');
    final raw = res['providers'] ?? res['items'];
    if (raw is! List) return const <CcProviderInfo>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcProviderInfo.fromJson)
        .toList();
  }

  Future<Map<String, Object?>> saveApiKey({
    required String providerId,
    required String apiKey,
  }) =>
      _transport.postJson(
        '/api/key',
        body: <String, Object?>{'provider': providerId, 'key': apiKey},
      );

  Future<Map<String, Object?>> saveCustomProvider(Map<String, Object?> provider) =>
      _transport.postJson('/api/providers/save', body: provider);

  Future<Map<String, Object?>> deleteCustomProvider(String providerId) =>
      _transport.postJson('/api/providers/delete', body: <String, Object?>{'id': providerId});

  Future<List<CcModelInfo>> listModels({String? providerId, bool refresh = false}) async {
    final res = await _transport.getJson(
      '/api/models',
      query: <String, String?>{
        'provider': ?providerId,
        if (refresh) 'refresh': '1',
      },
    );
    final raw = res['models'] ?? res['items'];
    if (raw is! List) return const <CcModelInfo>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcModelInfo.fromJson)
        .toList();
  }

  Future<CcSessionModelSelection> getSessionModel({
    String? sessionId,
    String? projectId,
  }) async {
    final res = await _transport.getJson(
      '/api/session-model',
      query: <String, String?>{
        'id': ?sessionId,
        'project': ?projectId,
      },
    );
    return CcSessionModelSelection.fromJson(res);
  }

  Future<CcSessionModelSelection> setSessionModel({
    required String sessionId,
    String? provider,
    String? model,
    String? effort,
    bool reset = false,
  }) async {
    final res = await _transport.postJson(
      '/api/session-model',
      body: <String, Object?>{
        'id': sessionId,
        if (reset) 'reset': true,
        'provider': ?provider,
        'model': ?model,
        'effort': ?effort,
      },
    );
    return CcSessionModelSelection.fromJson(res);
  }

  Future<Map<String, Object?>> getSettings() => _transport.getJson('/api/settings');

  Future<Map<String, Object?>> updateSettings(Map<String, Object?> patch) =>
      _transport.postJson('/api/settings', body: patch);

  Future<Map<String, Object?>> startClaudeLogin() =>
      _transport.postJson('/api/login/start');

  Future<Map<String, Object?>> getClaudeLoginStatus() =>
      _transport.getJson('/api/login/status');

  Future<Map<String, Object?>> logoutClaude() =>
      _transport.postJson('/api/login/logout');

  Future<Map<String, Object?>> getBillingAndQuota({String? providerId}) =>
      _transport.getJson(
        '/api/billing',
        query: <String, String?>{'provider': ?providerId},
      );

  // ── In-App Native PTY Terminal (`/api/term/*`) ─────────────────────────

  Future<List<CcTerminalSession>> listTerminals() async {
    final res = await _transport.getJson('/api/term/list');
    final raw = res['terms'];
    if (raw is! List) return const <CcTerminalSession>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcTerminalSession.fromJson)
        .toList();
  }

  Future<CcTerminalSession> createTerminal({
    int cols = 80,
    int rows = 24,
    String? cwd,
    String? title,
  }) async {
    final res = await _transport.postJson(
      '/api/term/new',
      body: <String, Object?>{
        'cols': cols,
        'rows': rows,
        'cwd': ?cwd,
        'title': ?title,
      },
    );
    return CcTerminalSession.fromJson(res);
  }

  /// Streams terminal output over SSE, automatically deduplicating replay chunks
  /// using `total` character offsets on reconnect.
  Stream<String> streamTerminalOutput(
    String termId, {
    void Function(int? exitCode)? onExit,
  }) async* {
    var seenTotal = 0;
    await for (final frame in _transport.openSse('/api/term/$termId/stream')) {
      final json = frame.tryDecodeJson();
      final kind = frame.event ?? json?['type']?.toString() ?? 'data';
      if (kind == 'replay' && json != null) {
        final data = (json['data'] ?? '').toString();
        final total = json['total'] is num ? (json['total']! as num).toInt() : data.length;
        if (seenTotal == 0) {
          seenTotal = total;
          if (data.isNotEmpty) yield data;
        } else if (total > seenTotal) {
          final deltaLen = total - seenTotal;
          seenTotal = total;
          if (deltaLen >= data.length) {
            yield data;
          } else {
            yield data.substring(data.length - deltaLen);
          }
        }
      } else if (kind == 'exit') {
        final code = json?['code'] is num ? (json!['code']! as num).toInt() : null;
        onExit?.call(code);
        return;
      } else {
        final chunk = json != null ? (json['data'] ?? '').toString() : frame.data;
        if (chunk.isNotEmpty) {
          seenTotal += chunk.length;
          yield chunk;
        }
      }
    }
  }

  Future<void> writeTerminalInput(String termId, String input) async {
    await _transport.requestBytes(
      method: 'POST',
      path: '/api/term/$termId/in',
      bodyBytes: utf8.encode(input),
      contentType: 'text/plain; charset=utf-8',
    );
  }

  Future<void> resizeTerminal(String termId, {required int cols, required int rows}) async {
    await _transport.postJson(
      '/api/term/$termId/resize',
      body: <String, Object?>{'cols': cols, 'rows': rows},
    );
  }

  Future<void> killTerminal(String termId) async {
    await _transport.postJson('/api/term/$termId/kill');
  }

  // ── Projects, Files & Git ──────────────────────────────────────────────

  Future<List<CcProjectInfo>> listProjects() async {
    final res = await _transport.getJson('/api/projects');
    final raw = res['projects'] ?? res['items'];
    if (raw is! List) return const <CcProjectInfo>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcProjectInfo.fromJson)
        .toList();
  }

  Future<CcProjectInfo> addProject({required String path, String? name}) async {
    final res = await _transport.postJson(
      '/api/projects',
      body: <String, Object?>{
        'path': path,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    final p = res['project'] is Map<String, Object?>
        ? res['project']! as Map<String, Object?>
        : res;
    return CcProjectInfo.fromJson(p);
  }

  Future<List<CcFileNode>> listDirectory(String dirPath) async {
    final res = await _transport.getJson(
      '/api/files',
      query: <String, String?>{'dir': dirPath},
    );
    final raw = res['items'] ?? res['files'];
    if (raw is! List) return const <CcFileNode>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map((e) => CcFileNode.fromJson(e, parentDir: dirPath))
        .toList();
  }

  Future<String> readTextFile(String filePath) async {
    final res = await _transport.getJson(
      '/api/file',
      query: <String, String?>{'path': filePath},
    );
    if (res.containsKey('content')) return (res['content'] ?? '').toString();
    if (res.containsKey('text')) return (res['text'] ?? '').toString();
    return jsonEncode(res);
  }

  Future<void> saveTextFile(String filePath, String content) async {
    await _transport.postJson(
      '/api/file/save',
      body: <String, Object?>{'path': filePath, 'content': content},
    );
  }

  Future<void> createDirectory(String dirPath) async {
    await _transport.postJson(
      '/api/file/mkdir',
      body: <String, Object?>{'path': dirPath},
    );
  }

  Future<void> deleteFileOrDir(String targetPath) async {
    await _transport.postJson(
      '/api/file/delete',
      body: <String, Object?>{'path': targetPath},
    );
  }

  Future<Map<String, Object?>> uploadAttachment({
    required String filename,
    required Uint8List bytes,
  }) async {
    final res = await _transport.requestBytes(
      method: 'POST',
      path: '/api/upload',
      query: <String, String?>{'name': filename},
      bodyBytes: bytes,
      contentType: 'application/octet-stream',
    );
    return jsonDecode(utf8.decode(res)) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> getGitStatus(String repoDir) =>
      _transport.getJson('/api/git/status', query: <String, String?>{'dir': repoDir});

  Future<Map<String, Object?>> getGitDiff(String repoDir, {String? file}) =>
      _transport.getJson(
        '/api/git/diff',
        query: <String, String?>{'dir': repoDir, 'file': ?file},
      );

  // ── Extensions, Modular Devkit, Components & Shizuku `priv` ────────────

  Future<List<CcDevkitModule>> listDevkitModules() async {
    final res = await _transport.getJson('/api/devkit/modules');
    final raw = res['modules'] ?? res['items'];
    if (raw is! List) return const <CcDevkitModule>[];
    return raw
        .whereType<Map<String, Object?>>()
        .map(CcDevkitModule.fromJson)
        .toList();
  }

  Future<Map<String, Object?>> installDevkitModule(String moduleId) =>
      _transport.postJson(
        '/api/devkit/modules/install',
        body: <String, Object?>{'id': moduleId},
        timeout: const Duration(minutes: 10),
      );

  Future<Map<String, Object?>> removeDevkitModule(String moduleId) =>
      _transport.postJson(
        '/api/devkit/modules/remove',
        body: <String, Object?>{'id': moduleId},
      );

  Future<Map<String, Object?>> listComponents() => _transport.getJson('/api/components');

  Future<Map<String, Object?>> listMcpServers() => _transport.getJson('/api/ext/mcp');

  Future<Map<String, Object?>> addMcpServer(Map<String, Object?> spec) =>
      _transport.postJson('/api/ext/mcp/add', body: spec);

  Future<Map<String, Object?>> removeMcpServer(String name) =>
      _transport.postJson('/api/ext/mcp/remove', body: <String, Object?>{'name': name});

  Future<Map<String, Object?>> toggleMcpServer(String name, {required bool enabled}) =>
      _transport.postJson(
        enabled ? '/api/ext/mcp/enable' : '/api/ext/mcp/disable',
        body: <String, Object?>{'name': name},
      );

  Future<Map<String, Object?>> listSkills() => _transport.getJson('/api/ext/skills');

  Future<Map<String, Object?>> importSkillZip(Uint8List zipBytes) async {
    final res = await _transport.requestBytes(
      method: 'POST',
      path: '/api/ext/skills/import',
      bodyBytes: zipBytes,
      contentType: 'application/zip',
    );
    return jsonDecode(utf8.decode(res)) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> deleteSkill(String dir) =>
      _transport.postJson('/api/ext/skills/delete', body: <String, Object?>{'dir': dir});

  Future<Map<String, Object?>> listClaudePlugins() =>
      _transport.getJson('/api/ext/plugins');

  Future<Map<String, Object?>> installClaudePlugin(String spec) =>
      _transport.postJson('/api/ext/plugins/install', body: <String, Object?>{'name': spec});

  Future<CcPrivStatus> getPrivStatus() async {
    final res = await _transport.getJson('/api/priv/status');
    return CcPrivStatus.fromJson(res);
  }

  Future<Map<String, Object?>> requestPrivPermission() =>
      _transport.postJson('/api/priv/request');

  Future<Map<String, Object?>> getPrivAuditLog() =>
      _transport.getJson('/api/priv/audit');

  Future<Map<String, Object?>> getMemManagerStatus() =>
      _transport.getJson('/api/mem/status');
}
