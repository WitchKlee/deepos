import 'dart:async';
import 'dart:io';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:test/test.dart';

void main() {
  test('real gateway/server.mjs /__proof + HMAC sig2 + SSE handshake', () async {
    final repoRoot = Directory.current.parent.parent.path;
    final serverScript = File('$repoRoot/gateway/server.mjs');
    if (!serverScript.existsSync()) {
      markTestSkipped('gateway/server.mjs not found at ${serverScript.path}');
      return;
    }

    final tmp = await Directory.systemTemp.createTemp('deepos_gw_interop_');
    final home = Directory('${tmp.path}/home')..createSync(recursive: true);
    final workspace = Directory('${tmp.path}/workspace')..createSync(recursive: true);
    final prefix = Directory('${tmp.path}/usr')..createSync(recursive: true);
    Directory('${prefix.path}/bin').createSync(recursive: true);

    // Pick a free ephemeral TCP port.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    final proc = await Process.start(
      'node',
      <String>[serverScript.path, '$port'],
      environment: <String, String>{
        'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin',
        'HOME': home.path,
        'CCAPP_HOME': home.path,
        'CCAPP_WORKSPACE': workspace.path,
        'CCAPP_PREFIX': prefix.path,
        'CCAPP_PORT': '$port',
        'CCAPP_UI_HOST': '127.0.0.1',
        'CCAPP_LOG': '${tmp.path}/gateway.log',
        'CCAPP_TMP': tmp.path,
      },
    );
    addTearDown(() async {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          proc.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    // Wait for token file & port readiness.
    final tokenFile = File('${home.path}/.gateway-token');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    String token = '';
    CcGatewayClient? client;
    Object? lastErr;
    while (DateTime.now().isBefore(deadline)) {
      if (tokenFile.existsSync()) {
        token = tokenFile.readAsStringSync().trim();
      }
      if (token.isNotEmpty) {
        try {
          client = await CcGatewayClient.connect(
            token: token,
            uiHost: '127.0.0.1',
            port: port,
            startEventBus: false,
          );
          break;
        } catch (e) {
          lastErr = e;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    expect(client, isNotNull, reason: 'Failed to connect to live gateway: $lastErr');
    addTearDown(() => client!.close());

    final status = await client!.getStatus();
    expect(status, isA<Map<String, Object?>>());

    final providers = await client.listProviders();
    expect(providers, isNotEmpty);

    final events = <CcBusEvent>[];
    final gotHello = Completer<CcBusEvent>();
    final sub = client.eventBus.events.listen((e) {
      events.add(e);
      if (e.type == 'hello' && !gotHello.isCompleted) {
        gotHello.complete(e);
      }
    });
    addTearDown(sub.cancel);
    client.eventBus.start();

    final hello = await gotHello.future.timeout(const Duration(seconds: 5));
    expect(hello.type, 'hello');
  });
}
