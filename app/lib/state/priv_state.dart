import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../priv/priv_channel.dart';

final privChannelProvider = Provider<PrivChannel>((ref) => PrivChannel());

final class PrivState {
  const PrivState({
    this.status = const NativePrivSnapshot(),
    this.auditLog = const <String>[],
    this.loading = false,
  });

  final NativePrivSnapshot status;
  final List<String> auditLog;
  final bool loading;

  PrivState copyWith({
    NativePrivSnapshot? status,
    List<String>? auditLog,
    bool? loading,
  }) {
    return PrivState(
      status: status ?? this.status,
      auditLog: auditLog ?? this.auditLog,
      loading: loading ?? this.loading,
    );
  }
}

class PrivController extends Notifier<PrivState> {
  @override
  PrivState build() {
    unawaited(refresh());
    return const PrivState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    final ch = ref.read(privChannelProvider);
    final s = await ch.getStatus();
    final log = await ch.readAuditLog();
    state = state.copyWith(status: s, auditLog: log, loading: false);
  }

  Future<void> requestPermission() async {
    await ref.read(privChannelProvider).requestPermission();
    await refresh();
  }

  Future<void> openShizukuManager() async {
    await ref.read(privChannelProvider).openShizukuManager();
  }
}

final privProvider = NotifierProvider<PrivController, PrivState>(
  PrivController.new,
);
