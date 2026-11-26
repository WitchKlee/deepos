import 'dart:async';
import 'dart:typed_data';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gateway_state.dart';

final class ExtensionsState {
  const ExtensionsState({
    this.modules = const <CcDevkitModule>[],
    this.mcpServers = const <Map<String, Object?>>[],
    this.skills = const <Map<String, Object?>>[],
    this.plugins = const <Map<String, Object?>>[],
    this.loading = false,
    this.error,
  });

  final List<CcDevkitModule> modules;
  final List<Map<String, Object?>> mcpServers;
  final List<Map<String, Object?>> skills;
  final List<Map<String, Object?>> plugins;
  final bool loading;
  final String? error;

  ExtensionsState copyWith({
    List<CcDevkitModule>? modules,
    List<Map<String, Object?>>? mcpServers,
    List<Map<String, Object?>>? skills,
    List<Map<String, Object?>>? plugins,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ExtensionsState(
      modules: modules ?? this.modules,
      mcpServers: mcpServers ?? this.mcpServers,
      skills: skills ?? this.skills,
      plugins: plugins ?? this.plugins,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ExtensionsController extends Notifier<ExtensionsState> {
  @override
  ExtensionsState build() {
    final client = ref.watch(gatewayClientProvider).value;
    if (client != null) {
      unawaited(refresh());
    }
    return const ExtensionsState();
  }

  Future<void> refresh() async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        client.listDevkitModules().catchError((_) => const <CcDevkitModule>[]),
        client.listMcpServers().catchError((_) => const <String, Object?>{}),
        client.listSkills().catchError((_) => const <String, Object?>{}),
        client.listClaudePlugins().catchError((_) => const <String, Object?>{}),
      ]);
      state = state.copyWith(
        modules: results[0]! as List<CcDevkitModule>,
        mcpServers: _itemsOf(results[1]! as Map<String, Object?>),
        skills: _itemsOf(results[2]! as Map<String, Object?>),
        plugins: _itemsOf(results[3]! as Map<String, Object?>),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> installModule(String id) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.installDevkitModule(id);
    await refresh();
  }

  Future<void> removeModule(String id) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.removeDevkitModule(id);
    await refresh();
  }

  Future<void> toggleMcp(String name, {required bool enabled}) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.toggleMcpServer(name, enabled: enabled);
    await refresh();
  }

  Future<void> removeMcp(String name) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.removeMcpServer(name);
    await refresh();
  }

  Future<void> importSkillZip(Uint8List bytes) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.importSkillZip(bytes);
    await refresh();
  }

  Future<void> deleteSkill(String dir) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.deleteSkill(dir);
    await refresh();
  }

  static List<Map<String, Object?>> _itemsOf(Map<String, Object?> map) {
    final raw = map['items'] ?? map['skills'] ?? map['plugins'] ?? map['servers'];
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw.whereType<Map<String, Object?>>().toList();
  }
}

final extensionsProvider =
    NotifierProvider<ExtensionsController, ExtensionsState>(
  ExtensionsController.new,
);
