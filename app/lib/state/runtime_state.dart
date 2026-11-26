import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/runtime_channel.dart';

final runtimeChannelProvider = Provider<RuntimeChannel>((ref) => RuntimeChannel());

final class RuntimeState {
  const RuntimeState({
    this.snapshot = const RuntimeSnapshot(phase: RuntimePhase.notInstalled),
    this.safeMode = false,
    this.selectedModules = const <String>['base', 'cli'],
    this.gatewayLog = '',
  });

  final RuntimeSnapshot snapshot;
  final bool safeMode;
  final List<String> selectedModules;
  final String gatewayLog;

  RuntimeState copyWith({
    RuntimeSnapshot? snapshot,
    bool? safeMode,
    List<String>? selectedModules,
    String? gatewayLog,
  }) {
    return RuntimeState(
      snapshot: snapshot ?? this.snapshot,
      safeMode: safeMode ?? this.safeMode,
      selectedModules: selectedModules ?? this.selectedModules,
      gatewayLog: gatewayLog ?? this.gatewayLog,
    );
  }
}

class RuntimeController extends Notifier<RuntimeState> {
  StreamSubscription<RuntimeSnapshot>? _sub;

  @override
  RuntimeState build() {
    final channel = ref.read(runtimeChannelProvider);
    ref.onDispose(() => unawaited(_sub?.cancel()));
    _attach(channel);
    return const RuntimeState();
  }

  Future<void> _attach(RuntimeChannel channel) async {
    try {
      final initial = await channel.getStatus();
      state = state.copyWith(snapshot: initial);
      if (initial.devkitInstalled &&
          initial.claudeInstalled &&
          initial.phase == RuntimePhase.installed) {
        unawaited(channel.startGateway(safeMode: state.safeMode));
      }
      _sub = channel.statusStream().listen(
        (snap) => state = state.copyWith(snapshot: snap),
        onError: (_) {},
      );
    } on MissingPluginException {
      // Running in widget tests or non-Android host.
    }
  }

  void toggleModule(String id) {
    if (id == 'base') return;
    final next = List<String>.from(state.selectedModules);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedModules: next);
  }

  Future<void> installDevkit({String? localPath}) async {
    await ref.read(runtimeChannelProvider).installDevkit(
          localPath: localPath,
          modules: state.selectedModules,
        );
    await refreshStatus();
  }

  Future<void> installClaude({String channel = 'stable'}) async {
    await ref.read(runtimeChannelProvider).installClaude(channel: channel);
    await refreshStatus();
  }

  Future<void> startGateway({bool? safeMode}) async {
    final useSafe = safeMode ?? state.safeMode;
    state = state.copyWith(safeMode: useSafe);
    await ref.read(runtimeChannelProvider).startGateway(safeMode: useSafe);
  }

  Future<void> stopGateway() async {
    await ref.read(runtimeChannelProvider).stopGateway();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    try {
      final snap = await ref.read(runtimeChannelProvider).getStatus();
      state = state.copyWith(snapshot: snap);
    } on MissingPluginException {
      // Ignore in tests.
    }
  }

  Future<void> loadGatewayLog() async {
    try {
      final log = await ref.read(runtimeChannelProvider).readGatewayLog();
      state = state.copyWith(gatewayLog: log);
    } on MissingPluginException {
      // Ignore in tests.
    }
  }
}

final runtimeProvider = NotifierProvider<RuntimeController, RuntimeState>(
  RuntimeController.new,
);
