/// Per-request HMAC-SHA256 signer and `/__proof` verifier matching
/// `gateway/gw/access.mjs` (`sigOk` and `proof`).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cryptographic signer for the local gateway.
///
/// * Every `/api/*` request is signed with `TOKEN` using the `sig2:` domain:
///   `sig2:<BOOT>:<uiHost>:<METHOD>:<ts>:<nonce32>:<bodySha256>:<pathAndQuery>`
/// * Gateway liveness / anti-spoofing `/__proof?n=<nonce>` is verified with
///   `KEY` (either `HMAC_SHA256(TOKEN, "spawn:<spawnKey>")` hex when spawned
///   with a stdin secret, or `TOKEN` in dev/test mode).
final class CcAuthSigner {
  CcAuthSigner({
    required this.token,
    required this.bootId,
    this.uiHost = '127.0.0.2',
    this.port = 8791,
    Random? random,
  }) : _tokenBytes = utf8.encode(token),
       _random = random ?? Random.secure();

  /// The 256-bit hex gateway token from `home/.gateway-token`.
  final String token;

  /// The gateway process boot identifier returned by `/__proof`.
  final String bootId;

  /// Loopback interface (`127.0.0.2` by default, or `127.0.0.1` fallback).
  final String uiHost;

  /// Gateway TCP port (`8791` by default).
  final int port;

  final List<int> _tokenBytes;
  final Random _random;

  static final String emptyBodySha256 = sha256.convert(const <int>[]).toString();

  String get hostHeader => '$uiHost:$port';

  Uri get baseUri => Uri.http(hostHeader);

  /// Derives the proof key `KEY` used by `gateway/gw/access.mjs` when
  /// `CCAPP_SPAWN_KEY=stdin` was supplied.
  static String deriveSpawnProofKey({
    required String token,
    required String? spawnSecret,
  }) {
    if (spawnSecret == null || spawnSecret.isEmpty) return token;
    final mac = Hmac(sha256, utf8.encode(token));
    return mac.convert(utf8.encode('spawn:$spawnSecret')).toString();
  }

  /// Verifies the plain-text response `<BOOT> <hmac>` from `GET /__proof?n=<nonce>`.
  /// Returns the verified `bootId`, or `null` if invalid.
  static String? verifyProofResponse({
    required String responseText,
    required String nonce,
    required String token,
    String? spawnSecret,
    String uiHost = '127.0.0.2',
  }) {
    final trimmed = responseText.trim();
    final parts = trimmed.split(' ');
    if (parts.length != 2) return null;
    final boot = parts[0];
    final gotMac = parts[1];
    if (boot.isEmpty || gotMac.length != 64) return null;

    final proofKey = deriveSpawnProofKey(token: token, spawnSecret: spawnSecret);
    final expected = Hmac(sha256, utf8.encode(proofKey))
        .convert(utf8.encode('proof:$nonce:$boot:$uiHost'))
        .toString();
    return constantTimeEquals(gotMac, expected) ? boot : null;
  }

  /// Generates a 32-hex-character random nonce (16 random bytes).
  String generateNonce32() {
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return _toHex(bytes);
  }

  /// Signs an HTTP request for `gateway/gw/access.mjs` `sigOk()`.
  ///
  /// [pathAndQuery] MUST match the exact wire request target starting with `/`
  /// (e.g. `/api/sessions?limit=50`).
  Map<String, String> signHeaders({
    required String method,
    required String pathAndQuery,
    List<int>? bodyBytes,
    int? nowEpochMs,
    String? fixedNonce32,
  }) {
    final ts = (nowEpochMs ?? DateTime.now().millisecondsSinceEpoch).toString();
    final nonce = fixedNonce32 ?? generateNonce32();
    final bodySha = (bodyBytes == null || bodyBytes.isEmpty)
        ? emptyBodySha256
        : sha256.convert(bodyBytes).toString();
    final upperMethod = method.toUpperCase();
    final canonical =
        'sig2:$bootId:$uiHost:$upperMethod:$ts:$nonce:$bodySha:$pathAndQuery';
    final sig = Hmac(sha256, _tokenBytes).convert(utf8.encode(canonical)).toString();
    return <String, String>{
      'Host': hostHeader,
      'X-CC-Body': bodySha,
      'X-CC-Sig': '$ts.$nonce.$sig',
    };
  }

  static bool constantTimeEquals(String a, String b) {
    final ab = utf8.encode(a);
    final bb = utf8.encode(b);
    if (ab.length != bb.length) return false;
    var diff = 0;
    for (var i = 0; i < ab.length; i++) {
      diff |= ab[i] ^ bb[i];
    }
    return diff == 0;
  }

  static String _toHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
