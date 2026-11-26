/// Structured exceptions thrown by `package:cc_gateway_client`.
library;

sealed class CcGatewayException implements Exception {
  const CcGatewayException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// HTTP-level failure returned by the local gateway (`status >= 400`).
final class CcHttpException extends CcGatewayException {
  const CcHttpException({
    required this.statusCode,
    required this.path,
    required String message,
    this.errorCode,
    this.body,
  }) : super(message);

  final int statusCode;
  final String path;
  final String? errorCode;
  final Map<String, Object?>? body;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403 || statusCode == 421;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() =>
      'CcHttpException($statusCode ${errorCode ?? ''} on $path): $message';
}

/// Socket/connection failure talking to the local loopback gateway.
final class CcTransportException extends CcGatewayException {
  const CcTransportException(super.message, [this.cause]);

  final Object? cause;
}

/// Gateway identity proof (`/__proof`) failed verification.
final class CcProofException extends CcGatewayException {
  const CcProofException(super.message);
}
