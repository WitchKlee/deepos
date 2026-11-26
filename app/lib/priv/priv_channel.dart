import 'package:flutter/services.dart';

/// Native Shizuku status snapshot from `app.deepos.priv.PrivPlugin`.
final class NativePrivSnapshot {
  const NativePrivSnapshot({
    this.installed = false,
    this.running = false,
    this.granted = false,
    this.uid,
  });

  factory NativePrivSnapshot.fromMap(Map<Object?, Object?> map) {
    return NativePrivSnapshot(
      installed: map['installed'] == true,
      running: map['running'] == true,
      granted: map['granted'] == true,
      uid: (map['uid'] as num?)?.toInt(),
    );
  }

  final bool installed;
  final bool running;
  final bool granted;
  final int? uid;
}

/// Platform channel bridge to optional CLI-only Shizuku `PrivPlugin`.
class PrivChannel {
  static const MethodChannel _method = MethodChannel('deepos/priv');

  Future<NativePrivSnapshot> getStatus() async {
    try {
      final raw = await _method.invokeMethod<Map<Object?, Object?>>('getStatus');
      if (raw == null) return const NativePrivSnapshot();
      return NativePrivSnapshot.fromMap(raw);
    } on MissingPluginException {
      return const NativePrivSnapshot();
    }
  }

  Future<bool> requestPermission() async {
    try {
      return (await _method.invokeMethod<bool>('requestPermission')) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> openShizukuManager() async {
    try {
      return (await _method.invokeMethod<bool>('openShizukuManager')) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<List<String>> readAuditLog() async {
    try {
      final raw = await _method.invokeMethod<List<Object?>>('readAuditLog');
      return raw?.map((e) => e.toString()).toList() ?? const <String>[];
    } on MissingPluginException {
      return const <String>[];
    }
  }
}
