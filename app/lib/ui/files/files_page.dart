import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/files_state.dart';

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  final TextEditingController _editor = TextEditingController();
  String? _loadedFile;

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final st = ref.watch(filesProvider);
    final ctrl = ref.read(filesProvider.notifier);

    if (st.selectedFilePath != null && st.selectedFilePath != _loadedFile) {
      _loadedFile = st.selectedFilePath;
      _editor.text = st.selectedFileContent ?? '';
    } else if (st.selectedFilePath == null) {
      _loadedFile = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          st.selectedFilePath != null
              ? st.selectedFilePath!.split('/').last
              : l10n.filesTitle,
        ),
        leading: st.selectedFilePath != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: ctrl.closeFile,
              )
            : null,
        actions: <Widget>[
          if (st.selectedFilePath != null)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: l10n.commonSave,
              onPressed: () async {
                await ctrl.saveOpenFile(_editor.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.filesSaveSuccess)),
                  );
                }
              },
            )
          else ...<Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_upward_rounded),
              onPressed: () {
                final parts = st.currentDir.split('/');
                if (parts.length > 2) {
                  parts.removeLast();
                  unawaited(ctrl.openDirectory(parts.join('/')));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => unawaited(ctrl.openDirectory(st.currentDir)),
            ),
          ],
        ],
      ),
      body: st.selectedFilePath != null
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _editor,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                ),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    st.currentDir,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                  ),
                ),
                if (st.gitStatus['branch'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Chip(
                      avatar: const Icon(Icons.account_tree_outlined, size: 16),
                      label: Text(
                        '${l10n.filesGitStatus}: ${st.gitStatus['branch']}',
                      ),
                    ),
                  ),
                if (st.loading) const LinearProgressIndicator(),
                Expanded(
                  child: st.entries.isEmpty
                      ? Center(child: Text(l10n.commonEmpty))
                      : ListView.builder(
                          itemCount: st.entries.length,
                          itemBuilder: (context, index) {
                            final item = st.entries[index];
                            return ListTile(
                              leading: Icon(
                                item.isDirectory
                                    ? Icons.folder_rounded
                                    : Icons.description_outlined,
                              ),
                              title: Text(item.name),
                              subtitle: item.isDirectory
                                  ? null
                                  : Text('${item.size} B'),
                              onTap: () => item.isDirectory
                                  ? unawaited(ctrl.openDirectory(item.path))
                                  : unawaited(ctrl.openFile(item.path)),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
