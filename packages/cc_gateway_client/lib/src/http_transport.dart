/// Low-level signed HTTP + Server-Sent Events (SSE) transport for the local
/// Claude Code gateway.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'auth_signer.dart';
import 'errors.dart';

/// A single Server-Sent Event frame emitted by `/api/events` or
/// `/api/term/:id/stream`.
final class CcSseFrame {
  const CcSseFrame({
    this.id,
    this.event,
    required this.data,
  });

  final String? id;
  final String? event;
  final String data;

  Map<String, Object?>? tryDecodeJson() {
    if (data.isEmpty) return null;
    try {
      final decoded = jsonDecode(data);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

/// Signed HTTP/SSE transport over `dart:io` [HttpClient] (supports `127.0.0.2`
/// loopback binding and unbuffered SSE streaming).
final class CcHttpTransport {
  CcHttpTransport({
    required this.signer,
    this.languageCode = 'zh',
    HttpClient? httpClient,
  }) : _client = httpClient ?? _createDefaultHttpClient(),
       _ownsClient = httpClient == null;

  CcAuthSigner signer;
  String languageCode;
  final HttpClient _client;
  final bool _ownsClient;
  bool _closed = false;

  static HttpClient _createDefaultHttpClient() {
    final c = HttpClient();
    c.idleTimeout = const Duration(seconds: 30);
    c.connectionTimeout = const Duration(seconds: 10);
    c.autoUncompress = true;
    return c;
  }

  /// Performs `/__proof?n=<nonce>` handshake against `[uiHost]:[port]` and
  /// returns a verified [CcAuthSigner] bound to the live `BOOT` id.
  static Future<CcAuthSigner> connectAndProve({
    required String token,
    String? spawnSecret,
    String uiHost = '127.0.0.2',
    int port = 8791,
    HttpClient? httpClient,
  }) async {
    final tempSigner = CcAuthSigner(
      token: token,
      bootId: 'probe',
      uiHost: uiHost,
      port: port,
    );
    final nonce = '${tempSigner.generateNonce32()}${tempSigner.generateNonce32()}';
    final client = httpClient ?? _createDefaultHttpClient();
    final owns = httpClient == null;
    try {
      final uri = Uri.http('$uiHost:$port', '/__proof', <String, String>{'n': nonce});
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.hostHeader, '$uiHost:$port');
      final res = await req.close().timeout(const Duration(seconds: 5));
      final body = await utf8.decodeStream(res).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        throw CcProofException('Gateway /__proof returned HTTP ${res.statusCode}: $body');
      }
      final verifiedBoot = CcAuthSigner.verifyProofResponse(
        responseText: body,
        nonce: nonce,
        token: token,
        spawnSecret: spawnSecret,
        uiHost: uiHost,
      );
      if (verifiedBoot == null) {
        throw const CcProofException('Gateway /__proof HMAC verification failed');
      }
      return CcAuthSigner(
        token: token,
        bootId: verifiedBoot,
        uiHost: uiHost,
        port: port,
      );
    } on CcGatewayException {
      rethrow;
    } catch (e) {
      throw CcTransportException('Failed to reach gateway at $uiHost:$port', e);
    } finally {
      if (owns) client.close(force: false);
    }
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String?>? query,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await requestBytes(
      method: 'GET',
      path: path,
      query: query,
      timeout: timeout,
    );
    return _decodeJsonMap(res, path);
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?>? body,
    Map<String, String?>? query,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final encoded = body == null ? utf8.encode('{}') : utf8.encode(jsonEncode(body));
    final res = await requestBytes(
      method: 'POST',
      path: path,
      query: query,
      bodyBytes: encoded,
      contentType: 'application/json; charset=utf-8',
      timeout: timeout,
    );
    return _decodeJsonMap(res, path);
  }

  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String?>? query,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await requestBytes(
      method: 'DELETE',
      path: path,
      query: query,
      timeout: timeout,
    );
    return _decodeJsonMap(res, path);
  }

  Future<Uint8List> requestBytes({
    required String method,
    required String path,
    Map<String, String?>? query,
    List<int>? bodyBytes,
    String? contentType,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_closed) throw const CcTransportException('Transport is closed');
    final target = _buildPathAndQuery(path, query);
    final uri = Uri.parse('http://${signer.hostHeader}$target');
    final payload = bodyBytes ?? const <int>[];
    final sigHeaders = signer.signHeaders(
      method: method,
      pathAndQuery: target,
      bodyBytes: payload,
    );

    try {
      final req = await _client.openUrl(method.toUpperCase(), uri).timeout(timeout);
      sigHeaders.forEach(req.headers.set);
      req.headers.set('X-CC-Lang', languageCode);
      if (contentType != null) {
        req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      if (extraHeaders != null) {
        extraHeaders.forEach(req.headers.set);
      }
      if (payload.isNotEmpty) {
        req.contentLength = payload.length;
        req.add(payload);
      }
      final res = await req.close().timeout(timeout);
      final bytes = await _collectBytes(res).timeout(timeout);
      if (res.statusCode >= 400) {
        throw _buildHttpException(res.statusCode, target, bytes);
      }
      return bytes;
    } on CcGatewayException {
      rethrow;
    } catch (e) {
      throw CcTransportException('HTTP $method $target failed', e);
    }
  }

  /// Opens a signed Server-Sent Events stream (`GET /api/events` or
  /// `GET /api/term/:id/stream`).
  Stream<CcSseFrame> openSse(
    String path, {
    Map<String, String?>? query,
    String? lastEventId,
  }) async* {
    if (_closed) throw const CcTransportException('Transport is closed');
    final target = _buildPathAndQuery(path, query);
    final uri = Uri.parse('http://${signer.hostHeader}$target');
    final sigHeaders = signer.signHeaders(
      method: 'GET',
      pathAndQuery: target,
    );

    final HttpClientRequest req;
    final HttpClientResponse res;
    try {
      req = await _client.getUrl(uri).timeout(const Duration(seconds: 10));
      sigHeaders.forEach(req.headers.set);
      req.headers.set('Accept', 'text/event-stream');
      req.headers.set('Cache-Control', 'no-cache');
      req.headers.set('X-CC-Lang', languageCode);
      if (lastEventId != null && lastEventId.isNotEmpty) {
        req.headers.set('Last-Event-ID', lastEventId);
      }
      res = await req.close().timeout(const Duration(seconds: 15));
    } catch (e) {
      throw CcTransportException('SSE connect $target failed', e);
    }

    if (res.statusCode >= 400) {
      final bytes = await _collectBytes(res);
      throw _buildHttpException(res.statusCode, target, bytes);
    }

    String? currentId;
    String? currentEvent;
    final dataLines = <String>[];

    await for (final line in res.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty || currentId != null || currentEvent != null) {
          yield CcSseFrame(
            id: currentId,
            event: currentEvent,
            data: dataLines.join('\n'),
          );
          currentId = null;
          currentEvent = null;
          dataLines.clear();
        }
        continue;
      }
      if (line.startsWith(':')) {
        // Heartbeat comment (`: hb` / `: k`), ignore.
        continue;
      }
      final colon = line.indexOf(':');
      final String field;
      String value;
      if (colon < 0) {
        field = line;
        value = '';
      } else {
        field = line.substring(0, colon);
        value = line.substring(colon + 1);
        if (value.startsWith(' ')) value = value.substring(1);
      }
      switch (field) {
        case 'id':
          currentId = value;
        case 'event':
          currentEvent = value;
        case 'data':
          dataLines.add(value);
      }
    }
  }

  void close({bool force = false}) {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) {
      _client.close(force: force);
    }
  }

  static String _buildPathAndQuery(String path, Map<String, String?>? query) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    if (query == null || query.isEmpty) return normalizedPath;
    final filtered = <String, String>{};
    query.forEach((k, v) {
      if (v != null) filtered[k] = v;
    });
    if (filtered.isEmpty) return normalizedPath;
    final qs = Uri(queryParameters: filtered).query;
    return qs.isEmpty ? normalizedPath : '$normalizedPath?$qs';
  }

  static Future<Uint8List> _collectBytes(HttpClientResponse res) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static Map<String, Object?> _decodeJsonMap(Uint8List bytes, String path) {
    if (bytes.isEmpty) return const <String, Object?>{};
    final text = utf8.decode(bytes);
    final decoded = jsonDecode(text);
    if (decoded is Map<String, Object?>) return decoded;
    return <String, Object?>{'items': decoded};
  }

  static CcHttpException _buildHttpException(
    int statusCode,
    String path,
    Uint8List bytes,
  ) {
    Map<String, Object?>? map;
    String? errorCode;
    String message = 'HTTP $statusCode';
    if (bytes.isNotEmpty) {
      final text = utf8.decode(bytes, allowMalformed: true);
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, Object?>) {
          map = decoded;
          errorCode = decoded['error']?.toString();
          message = (decoded['message'] ?? decoded['error'] ?? text).toString();
        } else {
          message = text;
        }
      } catch (_) {
        message = text;
      }
    }
    return CcHttpException(
      statusCode: statusCode,
      path: path,
      message: message,
      errorCode: errorCode,
      body: map,
    );
  }
}
