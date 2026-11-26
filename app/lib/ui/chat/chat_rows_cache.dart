import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter/widgets.dart';

/// 120Hz identity-preserving row cache for streaming Claude Code conversations.
///
/// Performance contract:
/// When only the trailing live draft changes (e.g. token deltas arrive at
/// 30–60 chunks/sec), every historical row whose [CcChatEntry] object identity
/// is unchanged reuses its cached [Widget] instance without rebuilding.
final class ChatRowsCache {
  final Map<String, ({CcChatEntry entry, Widget widget})> _cache =
      <String, ({CcChatEntry entry, Widget widget})>{};

  int _buildCount = 0;

  /// Exposed for performance unit tests (`test/chat/chat_rows_cache_test.dart`).
  int get totalBuilds => _buildCount;

  Widget widgetFor(
    CcChatEntry entry,
    Widget Function(CcChatEntry entry) builder,
  ) {
    final hit = _cache[entry.key];
    if (hit != null && identical(hit.entry, entry)) {
      return hit.widget;
    }
    _buildCount++;
    final built = KeyedSubtree(
      key: ValueKey<String>(entry.key),
      child: builder(entry),
    );
    _cache[entry.key] = (entry: entry, widget: built);
    return built;
  }

  /// Drops entries no longer present in [activeEntries] to bound memory.
  void retainOnly(List<CcChatEntry> activeEntries) {
    if (_cache.length <= activeEntries.length + 16) return;
    final activeKeys = <String>{for (final e in activeEntries) e.key};
    _cache.removeWhere((k, _) => !activeKeys.contains(k));
  }

  void clear() {
    _cache.clear();
  }
}
