import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:deepos_app/app.dart';
import 'package:deepos_app/ui/chat/chat_rows_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ChatRowsCache skips rebuilding historical rows when only live draft changes', () {
    final cache = ChatRowsCache();
    const u1 = CcUserEntry(key: 'u_1', text: 'Write a parser');
    const a1 = CcAssistantEntry(key: 'a_1', text: 'Here is the parser.');
    const draft1 = CcAssistantEntry(key: 'live_r1_a_0', text: 'Working', streaming: true);
    const draft2 = CcAssistantEntry(key: 'live_r1_a_0', text: 'Working on it...', streaming: true);

    Widget buildEntry(CcChatEntry e) => Text(e.key);

    final wU1First = cache.widgetFor(u1, buildEntry);
    final wA1First = cache.widgetFor(a1, buildEntry);
    final wD1 = cache.widgetFor(draft1, buildEntry);
    expect(cache.totalBuilds, 3);

    // Streaming delta updates draft1 -> draft2; historical entries keep object identity.
    final wU1Second = cache.widgetFor(u1, buildEntry);
    final wA1Second = cache.widgetFor(a1, buildEntry);
    final wD2 = cache.widgetFor(draft2, buildEntry);

    expect(identical(wU1First, wU1Second), isTrue);
    expect(identical(wA1First, wA1Second), isTrue);
    expect(identical(wD1, wD2), isFalse);
    expect(cache.totalBuilds, 4);
  });

  testWidgets('DeepOsApp renders onboarding wizard cleanly on first launch', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const ProviderScope(child: DeepOsApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('DeepOS'), findsWidgets);
  });
}
