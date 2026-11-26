import 'dart:async';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'runtime_state.dart';

/// Connects a singleton [CcGatewayClient] as soon as `RuntimePhase.running`
/// publishes a verified loopback endpoint and token.
class GatewayConnectionController extends AsyncNotifier<CcGatewayClient?> {
  @override
  Future<CcGatewayClient?> build() async {
    final endpoint = ref.watch(
      runtimeProvider.select((s) {
        final snap = s.snapshot;
        if (!snap.canConnectGateway) return null;
        return (snap.uiHost, snap.port, snap.token!, snap.spawnSecret);
      }),
    );

    if (endpoint == null) return null;
    final (uiHost, port, token, spawnSecret) = endpoint;

    final client = await CcGatewayClient.connect(
      token: token,
      spawnSecret: spawnSecret,
      uiHost: uiHost,
      port: port,
      languageCode: AppLocale.isEnglish ? 'en' : 'zh',
      startEventBus: true,
    );
    ref.onDispose(() => unawaited(client.close()));
    return client;
  }

  void kickReconnect() {
    state.value?.eventBus.kickReconnect();
  }
}

final gatewayClientProvider =
    AsyncNotifierProvider<GatewayConnectionController, CcGatewayClient?>(
  GatewayConnectionController.new,
);

/// Broadcast stream of decoded gateway SSE events (`/api/events`).
final gatewayEventsProvider = StreamProvider<CcBusEvent>((ref) {
  final client = ref.watch(gatewayClientProvider).value;
  if (client == null) return const Stream<CcBusEvent>.empty();
  return client.eventBus.events;
});
