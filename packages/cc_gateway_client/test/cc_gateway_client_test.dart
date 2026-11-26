import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  group('CcAuthSigner', () {
    test('signs sig2 headers matching gateway/gw/access.mjs format', () {
      const token =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const bootId = 'deadbeefcafebabe0123456789abcdef';
      const nonce = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ts = 1764000000000;
      final body = utf8.encode('{"message":"hello"}');

      final signer = CcAuthSigner(
        token: token,
        bootId: bootId,
        uiHost: '127.0.0.2',
        port: 8791,
      );

      final headers = signer.signHeaders(
        method: 'POST',
        pathAndQuery: '/api/chat',
        bodyBytes: body,
        nowEpochMs: ts,
        fixedNonce32: nonce,
      );

      final expectedBodySha = sha256.convert(body).toString();
      final expectedSig = Hmac(sha256, utf8.encode(token))
          .convert(
            utf8.encode(
              'sig2:$bootId:127.0.0.2:POST:$ts:$nonce:$expectedBodySha:/api/chat',
            ),
          )
          .toString();

      expect(headers['Host'], '127.0.0.2:8791');
      expect(headers['X-CC-Body'], expectedBodySha);
      expect(headers['X-CC-Sig'], '$ts.$nonce.$expectedSig');
    });

    test('verifies /__proof response with and without spawn secret', () {
      const token = 'abcdef0123456789abcdef0123456789';
      const spawnSecret =
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
      const nonce = '11223344556677889900aabbccddeeff';
      const boot = 'boot1234567890abcdef';

      final derivedKey = CcAuthSigner.deriveSpawnProofKey(
        token: token,
        spawnSecret: spawnSecret,
      );
      final mac = Hmac(sha256, utf8.encode(derivedKey))
          .convert(utf8.encode('proof:$nonce:$boot:127.0.0.2'))
          .toString();

      expect(
        CcAuthSigner.verifyProofResponse(
          responseText: '$boot $mac\n',
          nonce: nonce,
          token: token,
          spawnSecret: spawnSecret,
          uiHost: '127.0.0.2',
        ),
        boot,
      );

      expect(
        CcAuthSigner.verifyProofResponse(
          responseText: '$boot $mac',
          nonce: nonce,
          token: token,
          spawnSecret: 'wrong',
          uiHost: '127.0.0.2',
        ),
        isNull,
      );
    });
  });

  group('CcTranscriptParser & CcLiveTurnAccumulator', () {
    test('groups consecutive tool calls and folds live deltas with stable keys', () {
      final durable = CcTranscriptParser.parseDurableItems(<Object?>[
        <String, Object?>{'role': 'user', 'uuid': 'u1', 'text': 'fix build'},
        <String, Object?>{'role': 'tool_use', 'id': 't1', 'name': 'Read', 'input': <String, Object?>{'file_path': 'a.dart'}},
        <String, Object?>{'role': 'tool_result', 'id': 't1', 'ok': true, 'text': 'ok'},
        <String, Object?>{'role': 'tool_use', 'id': 't2', 'name': 'Edit', 'input': <String, Object?>{'file_path': 'a.dart'}},
        <String, Object?>{'role': 'tool_result', 'id': 't2', 'ok': false, 'text': 'err'},
        <String, Object?>{'role': 'thinking', 'text': 'let me check'},
        <String, Object?>{'role': 'assistant', 'uuid': 'a1', 'text': 'Done.'},
      ]);

      expect(durable.length, 3);
      expect(durable[0], isA<CcUserEntry>());
      expect(durable[1], isA<CcToolGroupEntry>());
      final group = durable[1] as CcToolGroupEntry;
      expect(group.steps.length, 2);
      expect(group.hasFailure, isTrue);
      expect(group.shouldAutoExpand, isTrue);
      final assistant = durable[2] as CcAssistantEntry;
      expect(assistant.thinking, 'let me check');
      expect(assistant.text, 'Done.');

      final live = CcLiveTurnAccumulator(runId: 'run1');
      live.apply(const CcBusEvent(type: 'delta', payload: <String, Object?>{'text': 'Hello '}));
      final snap1 = live.buildLiveEntries();
      live.apply(const CcBusEvent(type: 'delta', payload: <String, Object?>{'text': 'world'}));
      final snap2 = live.buildLiveEntries();
      expect(snap1.single.key, snap2.single.key);
      expect((snap2.single as CcAssistantEntry).text, 'Hello world');

      live.apply(const CcBusEvent(type: 'discard_partial', payload: <String, Object?>{'text': 5}));
      expect((live.buildLiveEntries().single as CcAssistantEntry).text, 'Hello ');
    });
  });

  group('CcGatewayClient loopback integration', () {
    late HttpServer server;
    const token =
        '1111111122222222333333334444444455555555666666667777777788888888';
    const bootId = 'abcdef0123456789abcdef0123456789';

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest req) async {
        final path = req.uri.path;
        if (path == '/__proof') {
          final n = req.uri.queryParameters['n'] ?? '';
          final mac = Hmac(sha256, utf8.encode(token))
              .convert(utf8.encode('proof:$n:$bootId:127.0.0.1'))
              .toString();
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.text
            ..write('$bootId $mac');
          await req.response.close();
          return;
        }
        // Verify X-CC-Sig on all /api/* requests.
        final sig = req.headers.value('x-cc-sig') ?? '';
        final bodySha = req.headers.value('x-cc-body') ?? '';
        final bodyBytes = await req.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        expect(sha256.convert(bodyBytes).toString(), bodySha);
        final parts = sig.split('.');
        expect(parts.length, 3);
        final expected = Hmac(sha256, utf8.encode(token))
            .convert(
              utf8.encode(
                'sig2:$bootId:127.0.0.1:${req.method}:${parts[0]}:${parts[1]}:$bodySha:${req.uri}',
              ),
            )
            .toString();
        expect(parts[2], expected);

        if (path == '/api/events') {
          req.response
            ..statusCode = 200
            ..headers.set('content-type', 'text/event-stream; charset=utf-8')
            ..bufferOutput = false;
          req.response.write('id: $bootId.1\ndata: {"type":"hello","runs":[]}\n\n');
          req.response.write('id: $bootId.2\ndata: {"type":"delta","text":"hi"}\n\n');
          await req.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await req.response.close();
          return;
        }

        if (path == '/api/sessions') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(<String, Object?>{
              'sessions': <Object?>[
                <String, Object?>{'id': 's1', 'title': 'First Chat', 'mtime': 1700000000000},
              ],
            }));
          await req.response.close();
          return;
        }

        req.response
          ..statusCode = 404
          ..write('{"error":"not found"}');
        await req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('connects via /__proof, signs /api/sessions, and receives SSE events', () async {
      final client = await CcGatewayClient.connect(
        token: token,
        uiHost: '127.0.0.1',
        port: server.port,
        startEventBus: false,
      );
      addTearDown(client.close);

      final sessions = await client.listSessions();
      expect(sessions.length, 1);
      expect(sessions.first.id, 's1');
      expect(sessions.first.title, 'First Chat');

      final got = <CcBusEvent>[];
      final sub = client.eventBus.events.listen(got.add);
      addTearDown(sub.cancel);
      client.eventBus.start();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(got.length, greaterThanOrEqualTo(2));
      expect(got[0].type, 'hello');
      expect(got[1].type, 'delta');
      expect(client.eventBus.lastEventId, '$bootId.2');
    });
  });
}
