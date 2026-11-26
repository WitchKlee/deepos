import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/extensions_state.dart';

class ExtensionsPage extends ConsumerWidget {
  const ExtensionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final st = ref.watch(extensionsProvider);
    final ctrl = ref.read(extensionsProvider.notifier);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.extensionsTitle),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => unawaited(ctrl.refresh()),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: l10n.extensionsModules),
              Tab(text: l10n.extensionsMcp),
              Tab(text: l10n.extensionsSkills),
              Tab(text: l10n.extensionsPlugins),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            // 1. Modular Termux Devkit modules
            ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: st.modules.length,
              itemBuilder: (context, index) {
                final m = st.modules[index];
                final sizeMb = (m.downloadBytes / (1024 * 1024)).toStringAsFixed(0);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('${m.name} (${m.id})'),
                    subtitle: Text('${m.description} · $sizeMb MB'),
                    trailing: m.requiredModule
                        ? Chip(label: Text(l10n.extensionsInstalled))
                        : m.installed
                            ? OutlinedButton(
                                onPressed: () => unawaited(ctrl.removeModule(m.id)),
                                child: Text(l10n.extensionsRemove),
                              )
                            : FilledButton.tonal(
                                onPressed: m.installing
                                    ? null
                                    : () => unawaited(ctrl.installModule(m.id)),
                                child: Text(l10n.extensionsInstall),
                              ),
                  ),
                );
              },
            ),
            // 2. MCP Servers
            ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: st.mcpServers.length,
              itemBuilder: (context, index) {
                final s = st.mcpServers[index];
                final name = (s['name'] ?? s['id'] ?? '').toString();
                final enabled = s['disabled'] != true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SwitchListTile(
                    title: Text(name),
                    subtitle: Text((s['command'] ?? s['url'] ?? '').toString()),
                    value: enabled,
                    onChanged: (v) => unawaited(ctrl.toggleMcp(name, enabled: v)),
                  ),
                );
              },
            ),
            // 3. Skills (.zip import supported)
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(l10n.extensionsImportSkillZip),
                      onPressed: () async {
                        final res = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const <String>['zip'],
                        );
                        final path = res.firstOrNull?.path;
                        if (path != null) {
                          final bytes = await File(path).readAsBytes();
                          await ctrl.importSkillZip(bytes);
                        }
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: st.skills.length,
                    itemBuilder: (context, index) {
                      final sk = st.skills[index];
                      final dir = (sk['dir'] ?? sk['name'] ?? '').toString();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text((sk['name'] ?? dir).toString()),
                          subtitle: Text((sk['description'] ?? '').toString()),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => unawaited(ctrl.deleteSkill(dir)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // 4. Claude Plugins
            ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: st.plugins.length,
              itemBuilder: (context, index) {
                final pl = st.plugins[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text((pl['name'] ?? pl['id'] ?? '').toString()),
                    subtitle: Text((pl['description'] ?? '').toString()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
