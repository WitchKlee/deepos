import 'dart:async';

import 'package:flutter/services.dart';

enum RuntimePhase {
  notInstalled,
  installingDevkit,
  needClaude,
  installingClaude,
  installed,
  starting,
  running,
  stopped,
  error;

  static RuntimePhase parse(Object? raw) => switch (raw?.toString()) {
    'not_installed' => notInstalled,
    'installing_devkit' => installingDevkit,
    'need_claude' => needClaude,
    'installing_claude' => installingClaude,
    'installed' => installed,
    'starting' => starting,
    'running' => running,
    'stopped' => stopped,
    _ => error,
  };

  bool get isBusy =>
      this == installingDevkit || this == installingClaude || this == starting;
}

/// Snapshot emitted by Kotlin `RuntimePlugin` (`deepos/runtime/events`).
final class RuntimeSnapshot {
  const RuntimeSnapshot({
    required this.phase,
    this.packageId = 'app.deepos',
    this.targetSdk = 28,
    this.deviceSdk = 34,
    this.execMode = 'direct',
    this.devkitInstalled = false,
    this.claudeInstalled = false,
    this.uiHost = '127.0.0.2',
    this.port = 8791,
    this.bootId,
    this.token,
    this.spawnSecret,
    this.homeDir = '/data/data/app.deepos/files/home',
    this.workspaceDir = '/data/data/app.deepos/files/home/workspace',
    this.error,
    this.progress,
    this.detail,
  });

  factory RuntimeSnapshot.fromMap(Map<Object?, Object?> map) {
    return RuntimeSnapshot(
      phase: RuntimePhase.parse(map['phase']),
      packageId: (map['packageId'] ?? 'app.deepos').toString(),
      targetSdk: (map['targetSdk'] as num?)?.toInt() ?? 28,
      deviceSdk: (map['deviceSdk'] as num?)?.toInt() ?? 34,
      execMode: (map['execMode'] ?? 'direct').toString(),
      devkitInstalled: map['devkitInstalled'] == true,
      claudeInstalled: map['claudeInstalled'] == true,
      uiHost: (map['uiHost'] ?? '127.0.0.2').toString(),
      port: (map['port'] as num?)?.toInt() ?? 8791,
      bootId: map['bootId']?.toString(),
      token: map['token']?.toString(),
      spawnSecret: map['spawnSecret']?.toString(),
      homeDir: (map['homeDir'] ?? '/data/data/app.deepos/files/home').toString(),
      workspaceDir:
          (map['workspaceDir'] ?? '/data/data/app.deepos/files/home/workspace')
              .toString(),
      error: map['error']?.toString(),
      progress: (map['progress'] as num?)?.toDouble(),
      detail: map['detail']?.toString(),
    );
  }

  final RuntimePhase phase;
  final String packageId;
  final int targetSdk;
  final int deviceSdk;
  final String execMode;
  final bool devkitInstalled;
  final bool claudeInstalled;
  final String uiHost;
  final int port;
  final String? bootId;
  final String? token;
  final String? spawnSecret;
  final String homeDir;
  final String workspaceDir;
  final String? error;
  final double? progress;
  final String? detail;

  bool get canConnectGateway =>
      phase == RuntimePhase.running &&
      token != null &&
      token!.isNotEmpty;
}

/// Platform channel bridge to Android `app.deepos.runtime.RuntimePlugin`.
class RuntimeChannel {
  static const MethodChannel _method = MethodChannel('deepos/runtime');
  static const EventChannel _events = EventChannel('deepos/runtime/events');

  Stream<RuntimeSnapshot> statusStream() {
    return _events.receiveBroadcastStream().map((dynamic raw) {
      if (raw is Map<Object?, Object?>) {
        return RuntimeSnapshot.fromMap(raw);
      }
      return const RuntimeSnapshot(phase: RuntimePhase.error);
    });
  }

  Future<RuntimeSnapshot> getStatus() async {
    final raw = await _method.invokeMethod<Map<Object?, Object?>>('getStatus');
    if (raw == null) {
      return const RuntimeSnapshot(phase: RuntimePhase.notInstalled);
    }
    return RuntimeSnapshot.fromMap(raw);
  }

  Future<void> installDevkit({
    String? localPath,
    List<String> modules = const <String>['base', 'cli'],
  }) async {
    await _method.invokeMethod<Object?>('installDevkit', <String, Object?>{
      'localPath': ?localPath,
      'modules': modules,
    });
  }

  Future<void> installClaude({String channel = 'stable'}) async {
    await _method.invokeMethod<Object?>('installClaude', <String, Object?>{
      'channel': channel,
    });
  }

  Future<void> startGateway({bool safeMode = false}) async {
    await _method.invokeMethod<Object?>('startGateway', <String, Object?>{
      'safeMode': safeMode,
    });
  }

  Future<void> stopGateway() async {
    await _method.invokeMethod<Object?>('stopGateway');
  }

  Future<String> readGatewayLog() async {
    return (await _method.invokeMethod<String>('readGatewayLog')) ?? '';
  }
}
