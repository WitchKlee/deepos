import 'dart:async';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gateway_state.dart';
import 'runtime_state.dart';

final class FilesState {
  const FilesState({
    this.currentDir = '',
    this.projects = const <CcProjectInfo>[],
    this.entries = const <CcFileNode>[],
    this.gitStatus = const <String, Object?>{},
    this.selectedFilePath,
    this.selectedFileContent,
    this.loading = false,
    this.error,
  });

  final String currentDir;
  final List<CcProjectInfo> projects;
  final List<CcFileNode> entries;
  final Map<String, Object?> gitStatus;
  final String? selectedFilePath;
  final String? selectedFileContent;
  final bool loading;
  final String? error;

  FilesState copyWith({
    String? currentDir,
    List<CcProjectInfo>? projects,
    List<CcFileNode>? entries,
    Map<String, Object?>? gitStatus,
    String? selectedFilePath,
    String? selectedFileContent,
    bool clearSelectedFile = false,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return FilesState(
      currentDir: currentDir ?? this.currentDir,
      projects: projects ?? this.projects,
      entries: entries ?? this.entries,
      gitStatus: gitStatus ?? this.gitStatus,
      selectedFilePath:
          clearSelectedFile ? null : (selectedFilePath ?? this.selectedFilePath),
      selectedFileContent: clearSelectedFile
          ? null
          : (selectedFileContent ?? this.selectedFileContent),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FilesController extends Notifier<FilesState> {
  @override
  FilesState build() {
    final client = ref.watch(gatewayClientProvider).value;
    final defaultDir = ref.read(runtimeProvider).snapshot.workspaceDir;
    if (client != null) {
      unawaited(openDirectory(defaultDir));
    }
    return FilesState(currentDir: defaultDir);
  }

  Future<void> openDirectory(String dir) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    state = state.copyWith(
      currentDir: dir,
      loading: true,
      clearError: true,
      clearSelectedFile: true,
    );
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        client.listDirectory(dir),
        client.listProjects().catchError((_) => const <CcProjectInfo>[]),
        client.getGitStatus(dir).catchError((_) => const <String, Object?>{}),
      ]);
      state = state.copyWith(
        entries: results[0]! as List<CcFileNode>,
        projects: results[1]! as List<CcProjectInfo>,
        gitStatus: results[2]! as Map<String, Object?>,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> openFile(String path) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final content = await client.readTextFile(path);
      state = state.copyWith(
        selectedFilePath: path,
        selectedFileContent: content,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> saveOpenFile(String content) async {
    final client = ref.read(gatewayClientProvider).value;
    final path = state.selectedFilePath;
    if (client == null || path == null) return;
    await client.saveTextFile(path, content);
    state = state.copyWith(selectedFileContent: content);
  }

  void closeFile() {
    state = state.copyWith(clearSelectedFile: true);
  }
}

final filesProvider = NotifierProvider<FilesController, FilesState>(
  FilesController.new,
);
