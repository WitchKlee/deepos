/// Domain models for the Claude Code native gateway (`gateway/gw/*.mjs`).
library;

/// Summary of a conversation session from `GET /api/sessions`.
final class CcSessionSummary {
  const CcSessionSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.createdAt,
    this.cwd,
    this.projectId,
    this.pinnedAt = 0,
    this.misc = false,
    this.live = false,
    this.preview,
    this.model,
    this.provider,
  });

  factory CcSessionSummary.fromJson(Map<String, Object?> j) {
    return CcSessionSummary(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? j['name'] ?? '').toString(),
      updatedAt: _int(j['mtime'] ?? j['updatedAt'] ?? j['updated'] ?? 0),
      createdAt: j['created'] != null ? _int(j['created']) : null,
      cwd: _strOrNull(j['cwd']),
      projectId: _strOrNull(j['projectId'] ?? j['project']),
      pinnedAt: _int(j['pinned'] ?? 0),
      misc: j['misc'] == true,
      live: j['live'] == true || j['running'] == true,
      preview: _strOrNull(j['preview'] ?? j['firstPrompt'] ?? j['summary']),
      model: _strOrNull(j['model']),
      provider: _strOrNull(j['provider']),
    );
  }

  final String id;
  final String title;
  final int updatedAt;
  final int? createdAt;
  final String? cwd;
  final String? projectId;
  final int pinnedAt;
  final bool misc;
  final bool live;
  final String? preview;
  final String? model;
  final String? provider;

  bool get isPinned => pinnedAt > 0;
}

/// Per-session or pending new-session model/provider/effort selection.
final class CcSessionModelSelection {
  const CcSessionModelSelection({
    required this.provider,
    required this.model,
    required this.effort,
    this.effortRun = '',
    this.own = false,
    this.ownProvider = false,
    this.defaultModel,
  });

  factory CcSessionModelSelection.fromJson(Map<String, Object?> j) {
    return CcSessionModelSelection(
      provider: (j['provider'] ?? 'anthropic').toString(),
      model: (j['model'] ?? '').toString(),
      effort: (j['effort'] ?? '').toString(),
      effortRun: (j['effortRun'] ?? j['effort'] ?? '').toString(),
      own: j['own'] == true,
      ownProvider: j['ownProvider'] == true,
      defaultModel: _strOrNull(j['defaultModel']),
    );
  }

  final String provider;
  final String model;
  final String effort;
  final String effortRun;
  final bool own;
  final bool ownProvider;
  final String? defaultModel;

  String get displayModel =>
      model.isNotEmpty ? model : (defaultModel ?? provider);
}

/// Provider entry from `GET /api/providers`.
final class CcProviderInfo {
  const CcProviderInfo({
    required this.id,
    required this.label,
    required this.baseUrl,
    this.hasKey = false,
    this.login = false,
    this.loggedIn = false,
    this.builtin = false,
    this.local = false,
    this.defaultModel,
    this.models = const <String>[],
  });

  factory CcProviderInfo.fromJson(Map<String, Object?> j) {
    final rawModels = j['models'];
    return CcProviderInfo(
      id: (j['id'] ?? '').toString(),
      label: (j['label'] ?? j['name'] ?? j['id'] ?? '').toString(),
      baseUrl: (j['baseUrl'] ?? j['upstream'] ?? '').toString(),
      hasKey: j['hasKey'] == true || j['configured'] == true,
      login: j['login'] == true,
      loggedIn: j['loggedIn'] == true,
      builtin: j['builtin'] == true,
      local: j['local'] == true,
      defaultModel: _strOrNull(j['defaultModel']),
      models: rawModels is List
          ? rawModels.map((e) => e is Map ? (e['id'] ?? '').toString() : e.toString()).where((s) => s.isNotEmpty).toList()
          : const <String>[],
    );
  }

  final String id;
  final String label;
  final String baseUrl;
  final bool hasKey;
  final bool login;
  final bool loggedIn;
  final bool builtin;
  final bool local;
  final String? defaultModel;
  final List<String> models;
}

/// Model descriptor from `GET /api/models`.
final class CcModelInfo {
  const CcModelInfo({
    required this.id,
    required this.label,
    this.contextWindow = 0,
    this.effortLevels = const <String>[],
    this.supportsThinking = false,
  });

  factory CcModelInfo.fromJson(Map<String, Object?> j) {
    final efforts = j['effortLevels'] ?? j['efforts'];
    return CcModelInfo(
      id: (j['id'] ?? '').toString(),
      label: (j['label'] ?? j['name'] ?? j['id'] ?? '').toString(),
      contextWindow: _int(j['context_window'] ?? j['contextWindow'] ?? 0),
      effortLevels: efforts is List
          ? efforts.map((e) => e.toString()).toList()
          : const <String>[],
      supportsThinking: j['thinking'] == true || (efforts is List && efforts.isNotEmpty),
    );
  }

  final String id;
  final String label;
  final int contextWindow;
  final List<String> effortLevels;
  final bool supportsThinking;
}

/// Renderable chat transcript / live stream item.
sealed class CcChatEntry {
  const CcChatEntry({required this.key});

  /// Stable identity key for `ChatRowsCache` 120Hz diffing.
  final String key;
}

final class CcUserEntry extends CcChatEntry {
  const CcUserEntry({
    required super.key,
    required this.text,
    this.uuid,
    this.offset,
    this.timestamp,
    this.attachments = const <String>[],
    this.queued = false,
    this.queueId,
  });

  final String text;
  final String? uuid;
  final int? offset;
  final int? timestamp;
  final List<String> attachments;
  final bool queued;
  final String? queueId;
}

final class CcAssistantEntry extends CcChatEntry {
  const CcAssistantEntry({
    required super.key,
    required this.text,
    this.thinking = '',
    this.uuid,
    this.streaming = false,
    this.phase,
    this.interrupted = false,
    this.contextTokens,
    this.contextWindow,
  });

  final String text;
  final String thinking;
  final String? uuid;
  final bool streaming;
  final String? phase;
  final bool interrupted;
  final int? contextTokens;
  final int? contextWindow;

  CcAssistantEntry copyWith({
    String? text,
    String? thinking,
    String? uuid,
    bool? streaming,
    String? phase,
    bool? interrupted,
    int? contextTokens,
    int? contextWindow,
  }) {
    return CcAssistantEntry(
      key: key,
      text: text ?? this.text,
      thinking: thinking ?? this.thinking,
      uuid: uuid ?? this.uuid,
      streaming: streaming ?? this.streaming,
      phase: phase ?? this.phase,
      interrupted: interrupted ?? this.interrupted,
      contextTokens: contextTokens ?? this.contextTokens,
      contextWindow: contextWindow ?? this.contextWindow,
    );
  }
}

enum CcToolStepStatus { running, awaitingPermission, succeeded, failed }

final class CcToolCallStep {
  const CcToolCallStep({
    required this.id,
    required this.name,
    required this.input,
    this.status = CcToolStepStatus.running,
    this.output = '',
    this.isSubagent = false,
    this.subagentProgressDesc,
    this.subagentTokens = 0,
    this.subagentTools = 0,
    this.subagentReport,
  });

  final String id;
  final String name;
  final Map<String, Object?> input;
  final CcToolStepStatus status;
  final String output;
  final bool isSubagent;
  final String? subagentProgressDesc;
  final int subagentTokens;
  final int subagentTools;
  final String? subagentReport;

  CcToolCallStep copyWith({
    Map<String, Object?>? input,
    CcToolStepStatus? status,
    String? output,
    bool? isSubagent,
    String? subagentProgressDesc,
    int? subagentTokens,
    int? subagentTools,
    String? subagentReport,
  }) {
    return CcToolCallStep(
      id: id,
      name: name,
      input: input ?? this.input,
      status: status ?? this.status,
      output: output ?? this.output,
      isSubagent: isSubagent ?? this.isSubagent,
      subagentProgressDesc: subagentProgressDesc ?? this.subagentProgressDesc,
      subagentTokens: subagentTokens ?? this.subagentTokens,
      subagentTools: subagentTools ?? this.subagentTools,
      subagentReport: subagentReport ?? this.subagentReport,
    );
  }
}

/// Collapsible group of consecutive tool steps ("3 steps · done"), matching
/// `cccodroid`'s mobile-friendly step folding.
final class CcToolGroupEntry extends CcChatEntry {
  const CcToolGroupEntry({
    required super.key,
    required this.steps,
  });

  final List<CcToolCallStep> steps;

  bool get hasFailure => steps.any((s) => s.status == CcToolStepStatus.failed);
  bool get hasRunning => steps.any(
    (s) => s.status == CcToolStepStatus.running || s.status == CcToolStepStatus.awaitingPermission,
  );
  bool get shouldAutoExpand =>
      steps.any((s) => s.status == CcToolStepStatus.awaitingPermission || s.status == CcToolStepStatus.failed);
}

/// Sensitive tool / `PreToolUse` guard confirmation card (`POST /api/perm/answer`).
final class CcPermissionPromptEntry extends CcChatEntry {
  const CcPermissionPromptEntry({
    required super.key,
    required this.requestId,
    required this.toolName,
    required this.summary,
    this.details = const <String, Object?>{},
    this.resolved = false,
    this.allowed = false,
  });

  final String requestId;
  final String toolName;
  final String summary;
  final Map<String, Object?> details;
  final bool resolved;
  final bool allowed;
}

/// Compaction chapter divider (`compact_boundary`).
final class CcCompactDividerEntry extends CcChatEntry {
  const CcCompactDividerEntry({
    required super.key,
    this.chapterNumber,
    this.title,
    this.preTokens,
    this.postTokens,
  });

  final int? chapterNumber;
  final String? title;
  final int? preTokens;
  final int? postTokens;
}

/// Rewind dry-run or execution result from `POST /api/session/:id/rewind`.
final class CcRewindPreview {
  const CcRewindPreview({
    required this.canRewind,
    this.files = const <String>[],
    this.insertions = 0,
    this.deletions = 0,
    this.reason,
    this.forkSessionId,
    this.freshSession = false,
  });

  factory CcRewindPreview.fromJson(Map<String, Object?> j) {
    final fx = j['files'] is Map<String, Object?>
        ? j['files']! as Map<String, Object?>
        : j;
    final rawFiles = fx['files'];
    final fork = j['fork'] is Map<String, Object?>
        ? j['fork']! as Map<String, Object?>
        : null;
    return CcRewindPreview(
      canRewind: fx['canRewind'] == true,
      files: rawFiles is List ? rawFiles.map((e) => e.toString()).toList() : const <String>[],
      insertions: _int(fx['insertions'] ?? 0),
      deletions: _int(fx['deletions'] ?? 0),
      reason: _strOrNull(fx['reason']),
      forkSessionId: fork != null ? _strOrNull(fork['id'] ?? fork['sessionId']) : null,
      freshSession: fork != null && fork['fresh'] == true,
    );
  }

  final bool canRewind;
  final List<String> files;
  final int insertions;
  final int deletions;
  final String? reason;
  final String? forkSessionId;
  final bool freshSession;
}

/// Paginated session page from `GET /api/session/:id`.
final class CcSessionPage {
  const CcSessionPage({
    required this.id,
    required this.title,
    required this.entries,
    this.cwd,
    this.cursor,
    this.nextOffset,
    this.totalSize = 0,
    this.contextTokens,
    this.liveRunId,
    this.goal,
    this.tasks = const <Map<String, Object?>>[],
  });

  final String id;
  final String title;
  final List<CcChatEntry> entries;
  final String? cwd;
  final int? cursor;
  final int? nextOffset;
  final int totalSize;
  final int? contextTokens;
  final String? liveRunId;
  final Map<String, Object?>? goal;
  final List<Map<String, Object?>> tasks;
}

/// Terminal session descriptor from `/api/term/*`.
final class CcTerminalSession {
  const CcTerminalSession({
    required this.id,
    required this.title,
    required this.cols,
    required this.rows,
    required this.alive,
    this.createdAt = 0,
    this.exitCode,
  });

  factory CcTerminalSession.fromJson(Map<String, Object?> j) {
    return CcTerminalSession(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? 'bash').toString(),
      cols: _int(j['cols'] ?? 80),
      rows: _int(j['rows'] ?? 24),
      alive: j['alive'] != false,
      createdAt: _int(j['created'] ?? 0),
      exitCode: j['code'] is num ? (j['code']! as num).toInt() : null,
    );
  }

  final String id;
  final String title;
  final int cols;
  final int rows;
  final bool alive;
  final int createdAt;
  final int? exitCode;
}

/// Workspace project entry from `/api/projects`.
final class CcProjectInfo {
  const CcProjectInfo({
    required this.id,
    required this.name,
    required this.path,
    this.provider,
    this.model,
    this.effort,
  });

  factory CcProjectInfo.fromJson(Map<String, Object?> j) {
    return CcProjectInfo(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? '').toString(),
      path: (j['path'] ?? '').toString(),
      provider: _strOrNull(j['provider']),
      model: _strOrNull(j['model']),
      effort: _strOrNull(j['effort']),
    );
  }

  final String id;
  final String name;
  final String path;
  final String? provider;
  final String? model;
  final String? effort;
}

/// File / directory item from `GET /api/files`.
final class CcFileNode {
  const CcFileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.mtime = 0,
  });

  factory CcFileNode.fromJson(Map<String, Object?> j, {String parentDir = ''}) {
    final name = (j['name'] ?? '').toString();
    final rawPath = _strOrNull(j['path']);
    final fullPath = rawPath ??
        (parentDir.isEmpty
            ? name
            : '${parentDir.endsWith('/') ? parentDir.substring(0, parentDir.length - 1) : parentDir}/$name');
    return CcFileNode(
      name: name,
      path: fullPath,
      isDirectory: j['dir'] == true || j['isDirectory'] == true || j['type'] == 'dir',
      size: _int(j['size'] ?? 0),
      mtime: _int(j['mtime'] ?? 0),
    );
  }

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int mtime;
}

/// Modular Termux devkit module from `GET /api/devkit/modules`.
final class CcDevkitModule {
  const CcDevkitModule({
    required this.id,
    required this.name,
    required this.description,
    required this.installed,
    this.requiredModule = false,
    this.installing = false,
    this.downloadBytes = 0,
    this.installedBytes = 0,
  });

  factory CcDevkitModule.fromJson(Map<String, Object?> j) {
    return CcDevkitModule(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? j['id'] ?? '').toString(),
      description: (j['desc'] ?? j['description'] ?? '').toString(),
      installed: j['installed'] == true,
      requiredModule: j['required'] == true,
      installing: j['installing'] == true || j['busy'] == true,
      downloadBytes: _int(j['bytes'] ?? j['gzBytes'] ?? j['size'] ?? 0),
      installedBytes: _int(j['installedBytes'] ?? j['unpackBytes'] ?? 0),
    );
  }

  final String id;
  final String name;
  final String description;
  final bool installed;
  final bool requiredModule;
  final bool installing;
  final int downloadBytes;
  final int installedBytes;
}

/// Shizuku `priv` & `cc-mem` status from `/api/priv/status` and `/api/mem/status`.
final class CcPrivStatus {
  const CcPrivStatus({
    required this.shizukuInstalled,
    required this.shizukuRunning,
    required this.permissionGranted,
    this.uid,
    this.memGuardEnabled = false,
    this.keepAliveEnabled = false,
  });

  factory CcPrivStatus.fromJson(Map<String, Object?> j) {
    return CcPrivStatus(
      shizukuInstalled: j['installed'] == true || j['shizukuInstalled'] == true,
      shizukuRunning: j['running'] == true || j['binderAlive'] == true || j['alive'] == true,
      permissionGranted: j['granted'] == true || j['authorized'] == true || j['ok'] == true,
      uid: j['uid'] is num ? (j['uid']! as num).toInt() : null,
      memGuardEnabled: j['memGuard'] == true,
      keepAliveEnabled: j['keepalive'] == true,
    );
  }

  final bool shizukuInstalled;
  final bool shizukuRunning;
  final bool permissionGranted;
  final int? uid;
  final bool memGuardEnabled;
  final bool keepAliveEnabled;
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String? _strOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}
