import 'dart:async';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../state/app_settings_state.dart';
import '../../state/chat_state.dart';
import '../../state/gateway_state.dart';
import '../../state/providers_state.dart';
import '../../state/sessions_state.dart';
import '../theme/deepos_theme.dart';
import 'chat_rows_cache.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.onOpenDrawer,
    required this.onOpenQuickPanel,
  });

  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenQuickPanel;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeSessionId = ref.watch(
      sessionsProvider.select((s) => s.activeSessionId),
    );
    final sessionKey = activeSessionId ?? 'new';
    final blur = ref.watch(appAppearanceProvider.select((a) => a.glassBlur));

    // Performance contract: ChatScreen watches only a lightweight select tuple;
    // the full message list is watched exclusively inside _ChatMessageList.
    final (title, isStreaming, queuedCount, goalText, errorText) = ref.watch(
      chatProvider(sessionKey).select(
        (s) => (s.title, s.isStreaming, s.queued.length, s.goalText, s.error),
      ),
    );
    final activeModelLabel = ref.watch(
      providersProvider.select(
        (p) => p.activeSelection?.displayModel ?? 'Claude Code',
      ),
    );
    final connected = ref.watch(
      gatewayClientProvider.select((g) => g.value != null),
    );

    return Column(
      children: <Widget>[
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: GlassSurface(
              blur: blur,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: widget.onOpenDrawer,
                    tooltip: l10n.navSessions,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title.isEmpty ? l10n.navNewChat : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: connected ? Colors.greenAccent.shade400 : Colors.amber,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                activeModelLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: widget.onOpenQuickPanel,
                    tooltip: l10n.quickPanelTitle,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (goalText != null && goalText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.flag_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '/goal $goalText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (errorText != null && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: _ChatMessageList(
            sessionKey: sessionKey,
            scrollController: _scroll,
            onResend: (text) => _send(sessionKey, overrideText: text),
          ),
        ),
        if (queuedCount > 0) _QueueBar(sessionKey: sessionKey),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: GlassSurface(
              blur: blur,
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: l10n.chatComposerHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isStreaming)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.stop_rounded),
                      tooltip: l10n.chatStop,
                      onPressed: () =>
                          ref.read(chatProvider(sessionKey).notifier).stopRun(),
                    ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    icon: const Icon(Icons.arrow_upward_rounded),
                    tooltip: l10n.chatSend,
                    onPressed: () => _send(sessionKey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send(String sessionKey, {String? overrideText}) async {
    final text = overrideText ?? _composer.text;
    if (text.trim().isEmpty) return;
    if (overrideText == null) _composer.clear();
    await ref.read(chatProvider(sessionKey).notifier).sendMessage(text);
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }
}

class _QueueBar extends ConsumerWidget {
  const _QueueBar({required this.sessionKey});

  final String sessionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queued = ref.watch(chatProvider(sessionKey).select((s) => s.queued));
    if (queued.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.chatQueueCount(queued.length),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              for (final item in queued.take(3))
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(chatProvider(sessionKey).notifier)
                          .promoteQueued(item.id),
                      child: Text(l10n.chatQueuePromote),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => ref
                          .read(chatProvider(sessionKey).notifier)
                          .removeQueued(item.id),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessageList extends ConsumerStatefulWidget {
  const _ChatMessageList({
    required this.sessionKey,
    required this.scrollController,
    required this.onResend,
  });

  final String sessionKey;
  final ScrollController scrollController;
  final void Function(String text) onResend;

  @override
  ConsumerState<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<_ChatMessageList> {
  final ChatRowsCache _rowsCache = ChatRowsCache();

  @override
  void didUpdateWidget(covariant _ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionKey != widget.sessionKey) {
      _rowsCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(chatProvider(widget.sessionKey));
    final entries = state.entries;
    _rowsCache.retainOnly(entries);

    if (state.loading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.terminal_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.chatEmptyTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.chatEmptySubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _rowsCache.widgetFor(entry, (e) => _buildRow(context, e));
      },
    );
  }

  Widget _buildRow(BuildContext context, CcChatEntry entry) {
    return switch (entry) {
      CcUserEntry() => _UserBubble(
          entry: entry,
          onResend: () => widget.onResend(entry.text),
          onRewind: () => _openRewindSheet(context, entry),
        ),
      CcAssistantEntry() => _AssistantBubble(
          entry: entry,
          onFork: () => ref
              .read(chatProvider(widget.sessionKey).notifier)
              .forkFromEntry(entry),
        ),
      CcToolGroupEntry() => _ToolGroupCard(entry: entry),
      CcPermissionPromptEntry() => _PermissionCard(
          entry: entry,
          onAnswer: (allow, allowSession) => ref
              .read(chatProvider(widget.sessionKey).notifier)
              .answerPermission(
                entry.requestId,
                allow: allow,
                allowForSession: allowSession,
              ),
        ),
      CcCompactDividerEntry() => _CompactDivider(entry: entry),
    };
  }

  Future<void> _openRewindSheet(BuildContext context, CcUserEntry entry) async {
    final l10n = context.l10n;
    final preview = await ref
        .read(chatProvider(widget.sessionKey).notifier)
        .previewRewind(entry);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.chatRewindTitle,
                style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              if (preview == null || !preview.canRewind || preview.files.isEmpty)
                Text(preview?.reason ?? l10n.chatRewindNoFiles)
              else ...<Widget>[
                Text(
                  '+${preview.insertions} / -${preview.deletions} (${preview.files.length} files)',
                  style: Theme.of(sheetCtx).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final f in preview.files)
                        Text(
                          f,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: preview?.canRewind == true
                          ? () {
                              Navigator.pop(sheetCtx);
                              unawaited(
                                ref
                                    .read(chatProvider(widget.sessionKey).notifier)
                                    .executeRewind(entry, rewindConversation: false),
                              );
                            }
                          : null,
                      child: Text(l10n.chatRewindFilesOnly),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        unawaited(
                          ref
                              .read(chatProvider(widget.sessionKey).notifier)
                              .executeRewind(entry, rewindConversation: true),
                        );
                      },
                      child: Text(l10n.chatRewindFilesAndChat),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.entry,
    required this.onResend,
    required this.onRewind,
  });

  final CcUserEntry entry;
  final VoidCallback onResend;
  final VoidCallback onRewind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: SelectableText(
                entry.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  tooltip: l10n.commonCopy,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: entry.text)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  tooltip: l10n.chatActionResend,
                  visualDensity: VisualDensity.compact,
                  onPressed: onResend,
                ),
                IconButton(
                  icon: const Icon(Icons.history_rounded, size: 15),
                  tooltip: l10n.chatActionRewind,
                  visualDensity: VisualDensity.compact,
                  onPressed: onRewind,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.entry,
    required this.onFork,
  });

  final CcAssistantEntry entry;
  final VoidCallback onFork;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (entry.thinking.isNotEmpty)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              dense: true,
              title: Text(
                l10n.chatThinkingLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              children: <Widget>[
                SelectableText(
                  entry.thinking,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          if (entry.text.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: GptMarkdown(
                  entry.text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else if (entry.streaming)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.phase ?? l10n.commonLoading,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (!entry.streaming && entry.text.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  tooltip: l10n.commonCopy,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: entry.text)),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 15),
                  tooltip: l10n.chatActionShare,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: entry.text),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call_split_rounded, size: 15),
                  tooltip: l10n.chatActionFork,
                  visualDensity: VisualDensity.compact,
                  onPressed: onFork,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ToolGroupCard extends StatelessWidget {
  const _ToolGroupCard({required this.entry});

  final CcToolGroupEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = entry.hasRunning
        ? l10n.chatToolStepsRunning(entry.steps.length)
        : l10n.chatToolStepsDone(entry.steps.length);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: entry.shouldAutoExpand,
        dense: true,
        leading: Icon(
          entry.hasFailure
              ? Icons.warning_amber_rounded
              : (entry.hasRunning ? Icons.bolt_rounded : Icons.check_circle_outline_rounded),
          size: 18,
          color: entry.hasFailure ? scheme.error : scheme.primary,
        ),
        title: Text(label, style: Theme.of(context).textTheme.labelLarge),
        children: <Widget>[
          for (final step in entry.steps)
            ListTile(
              dense: true,
              title: Row(
                children: <Widget>[
                  Text(
                    step.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (step.isSubagent) ...<Widget>[
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(l10n.chatSubagentTag),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (step.subagentProgressDesc != null)
                    Text(
                      '${step.subagentProgressDesc} (${step.subagentTools} tools)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (step.output.isNotEmpty)
                    Text(
                      step.output,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              trailing: Icon(
                switch (step.status) {
                  CcToolStepStatus.succeeded => Icons.check_rounded,
                  CcToolStepStatus.failed => Icons.close_rounded,
                  CcToolStepStatus.running => Icons.hourglass_top_rounded,
                  CcToolStepStatus.awaitingPermission => Icons.shield_outlined,
                },
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.entry,
    required this.onAnswer,
  });

  final CcPermissionPromptEntry entry;
  final void Function(bool allow, bool allowSession) onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: scheme.secondaryContainer.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${l10n.chatPermissionRequired}: ${entry.toolName}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            if (entry.summary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              SelectableText(
                entry.summary,
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => onAnswer(false, false),
                  child: Text(l10n.commonDeny),
                ),
                FilledButton.tonal(
                  onPressed: () => onAnswer(true, false),
                  child: Text(l10n.commonAllow),
                ),
                FilledButton(
                  onPressed: () => onAnswer(true, true),
                  child: Text(l10n.commonAllowSession),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactDivider extends StatelessWidget {
  const _CompactDivider({required this.entry});

  final CcCompactDividerEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              entry.title?.isNotEmpty == true
                  ? '${l10n.chatCompactedDivider} · ${entry.title}'
                  : l10n.chatCompactedDivider,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
