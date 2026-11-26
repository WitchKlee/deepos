import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-UI libraries never import from lib/ui/ (strict unidirectional dependency)', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final violations = <String>[];
    final importPattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll('\\', '/');
      if (rel.startsWith('lib/ui/') ||
          rel == 'lib/main.dart' ||
          rel == 'lib/app.dart' ||
          rel.startsWith('lib/l10n/gen/')) {
        continue;
      }
      final content = entity.readAsStringSync();
      for (final match in importPattern.allMatches(content)) {
        final target = match.group(1) ?? '';
        if (target.contains('/ui/') || target.startsWith('ui/')) {
          violations.add('$rel -> $target');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Non-UI files must not import UI widgets:\n${violations.join('\n')}',
    );
  });
}
