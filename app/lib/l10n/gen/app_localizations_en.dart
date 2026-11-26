// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DeepOS';

  @override
  String commonMonthDay(String month, int day) {
    return '$month/$day';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonClose => 'Close';

  @override
  String get commonAllow => 'Allow';

  @override
  String get commonDeny => 'Deny';

  @override
  String get commonAllowSession => 'Allow for session';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonEmpty => 'Nothing here yet';

  @override
  String get onboardingTitle => 'Welcome to DeepOS';

  @override
  String get onboardingSubtitle => 'Native No-PRoot Claude Code Workstation on Android';

  @override
  String get onboardingStepToolkit => '1. Install Native Devkit';

  @override
  String get onboardingStepToolkitDesc =>
      'Modular Termux toolchain (bash, git, node, python, clang) byte-rewritten for 10-char package app.deepos with zero PRoot overhead.';

  @override
  String get onboardingStepClaude => '2. Download Official Claude Code';

  @override
  String get onboardingStepClaudeDesc =>
      'Fetches the unmodified official linux-arm64 Claude Code binary from Anthropic and verifies SHA-256 before launch via glibc loader.';

  @override
  String get onboardingStepAuth => '3. Connect Model Provider';

  @override
  String get onboardingStepAuthDesc =>
      'Sign in to Claude.ai or configure an Anthropic / DeepSeek / GLM / Kimi compatible API key.';

  @override
  String get onboardingInstallToolkit => 'Download & Install Toolkit';

  @override
  String get onboardingInstallClaude => 'Download Official Claude Code';

  @override
  String get onboardingStartGateway => 'Start Local Gateway';

  @override
  String get onboardingSkipToWorkspace => 'Enter Workspace';

  @override
  String get onboardingOfflineArchive => 'Pick local devkit archive…';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navNewChat => 'New Chat';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'Files';

  @override
  String get navExtensions => 'Extensions';

  @override
  String get navSettings => 'Settings';

  @override
  String get navTrash => 'Trash';

  @override
  String get chatComposerHint => 'Message Claude, or type /goal, /compact…';

  @override
  String get chatEmptyTitle => 'Native Claude Code Ready';

  @override
  String get chatEmptySubtitle =>
      'Read/edit local projects, run shell toolchains, inspect subagents, and rewind code cleanly.';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatQueuePromote => '⚡ Inject';

  @override
  String chatQueueCount(int count) {
    return '$count queued';
  }

  @override
  String get chatActionResend => 'Resend';

  @override
  String get chatActionRewind => 'Rewind to here';

  @override
  String get chatActionFork => 'Fork from here';

  @override
  String get chatActionShare => 'Share';

  @override
  String get chatRewindTitle => 'Rewind Code & Conversation';

  @override
  String get chatRewindFilesOnly => 'Undo code changes only';

  @override
  String get chatRewindFilesAndChat => 'Undo code and conversation';

  @override
  String get chatRewindNoFiles => 'No file checkpoints recorded after this turn.';

  @override
  String chatToolStepsDone(int count) {
    return '$count tool steps · done';
  }

  @override
  String chatToolStepsRunning(int count) {
    return '$count tool steps · running';
  }

  @override
  String get chatSubagentTag => 'Subagent';

  @override
  String get chatThinkingLabel => 'Reasoning';

  @override
  String get chatPermissionRequired => 'Action Approval Required';

  @override
  String get chatCompactedDivider => 'Context compacted';

  @override
  String get quickPanelTitle => 'Session Controls';

  @override
  String get quickPanelProvider => 'Provider';

  @override
  String get quickPanelModel => 'Model';

  @override
  String get quickPanelEffort => 'Reasoning Effort';

  @override
  String get quickPanelContext => 'Context Usage';

  @override
  String get quickPanelFollowGlobal => 'Follow global default';

  @override
  String get quickPanelResetSessionModel => 'Reset to global';

  @override
  String get quickPanelSafeMode => 'Safe mode (disable custom hooks & plugins)';

  @override
  String get terminalTitle => 'Native Terminal';

  @override
  String get terminalNew => 'New Terminal';

  @override
  String get terminalUnavailable => 'Terminal unavailable: start the local gateway first.';

  @override
  String get filesTitle => 'Workspace & Files';

  @override
  String get filesGitStatus => 'Git Changes';

  @override
  String get filesSaveSuccess => 'Saved';

  @override
  String get extensionsTitle => 'Extensions & Toolchain';

  @override
  String get extensionsModules => 'Toolkit Modules';

  @override
  String get extensionsMcp => 'MCP Servers';

  @override
  String get extensionsSkills => 'Skills';

  @override
  String get extensionsPlugins => 'Claude Plugins';

  @override
  String get extensionsImportSkillZip => 'Import .zip Skill';

  @override
  String get extensionsInstalled => 'Installed';

  @override
  String get extensionsInstall => 'Install';

  @override
  String get extensionsRemove => 'Remove';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsProviders => 'Providers & API Keys';

  @override
  String get settingsClaudeLogin => 'Sign in with Claude.ai';

  @override
  String get settingsApiKey => 'API Key';

  @override
  String get settingsAppearance => 'Appearance & Language';

  @override
  String get settingsThemeMode => 'Theme Mode';

  @override
  String get settingsGlassBlur => 'Glassmorphism Blur';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsShizuku => 'Shizuku CLI Helper (priv / cc-mem)';

  @override
  String get settingsShizukuDesc =>
      'Optional: lets terminal and Claude run authorized priv commands (logcat/pm) and cc-mem background cleanup before heavy builds. No accessibility screen control.';

  @override
  String get settingsShizukuRequest => 'Request Shizuku Permission';

  @override
  String get settingsShizukuOpen => 'Open Shizuku Manager';

  @override
  String get settingsShizukuAudit => 'Privileged Command Audit Log';

  @override
  String get settingsGatewayStatus => 'Gateway & Runtime Diagnostics';

  @override
  String get settingsGatewayRestart => 'Restart Local Gateway';

  @override
  String get settingsGatewayStop => 'Stop Gateway';
}
