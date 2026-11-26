// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'DeepOS';

  @override
  String commonMonthDay(String month, int day) {
    return '$month月$day日';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonCopy => '复制';

  @override
  String get commonRetry => '重试';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonClose => '关闭';

  @override
  String get commonAllow => '允许';

  @override
  String get commonDeny => '拒绝';

  @override
  String get commonAllowSession => '本会话均允许';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonEmpty => '暂无内容';

  @override
  String get onboardingTitle => '欢迎使用 DeepOS';

  @override
  String get onboardingSubtitle => '免 PRoot 原生 Claude Code 端侧开发工作站';

  @override
  String get onboardingStepToolkit => '1. 安装原生开发工具包';

  @override
  String get onboardingStepToolkitDesc =>
      '从 Termux 官方仓库按模块拉取（含 bash / git / node / python / clang），按 10 字符包名 app.deepos 等长改写，零 PRoot 损耗。';

  @override
  String get onboardingStepClaude => '2. 获取官方原版 Claude Code';

  @override
  String get onboardingStepClaudeDesc => '从 Anthropic 官方渠道在线下载并校验 SHA-256，原版二进制直接经 glibc 加载器运行。';

  @override
  String get onboardingStepAuth => '3. 连接模型接口';

  @override
  String get onboardingStepAuthDesc => '可登录 Claude 账户，或配置 Anthropic / DeepSeek / GLM / Kimi 等兼容 API Key。';

  @override
  String get onboardingInstallToolkit => '下载并安装工具包';

  @override
  String get onboardingInstallClaude => '下载官方 Claude Code';

  @override
  String get onboardingStartGateway => '启动本地网关';

  @override
  String get onboardingSkipToWorkspace => '进入工作台';

  @override
  String get onboardingOfflineArchive => '选择本地离线工具包…';

  @override
  String get navSessions => '会话';

  @override
  String get navNewChat => '新对话';

  @override
  String get navTerminal => '终端';

  @override
  String get navFiles => '文件';

  @override
  String get navExtensions => '扩展';

  @override
  String get navSettings => '设置';

  @override
  String get navTrash => '回收站';

  @override
  String get chatComposerHint => '给 Claude 发消息，或输入 /goal、/compact…';

  @override
  String get chatEmptyTitle => '原生 Claude Code 已就绪';

  @override
  String get chatEmptySubtitle => '直接读写本机项目、执行终端命令、拆分子代理与回退代码。';

  @override
  String get chatSend => '发送';

  @override
  String get chatStop => '停止';

  @override
  String get chatQueuePromote => '⚡ 插话';

  @override
  String chatQueueCount(int count) {
    return '排队中 $count 条';
  }

  @override
  String get chatActionResend => '重发';

  @override
  String get chatActionRewind => '回退到此处';

  @override
  String get chatActionFork => '从此处分叉';

  @override
  String get chatActionShare => '分享';

  @override
  String get chatRewindTitle => '代码与对话回退';

  @override
  String get chatRewindFilesOnly => '仅还原代码改动';

  @override
  String get chatRewindFilesAndChat => '同时还原代码与对话';

  @override
  String get chatRewindNoFiles => '此消息之后没有可还原的文件改动。';

  @override
  String chatToolStepsDone(int count) {
    return '$count 步工具调用 · 已完成';
  }

  @override
  String chatToolStepsRunning(int count) {
    return '$count 步工具调用 · 执行中';
  }

  @override
  String get chatSubagentTag => '子代理';

  @override
  String get chatThinkingLabel => '思考过程';

  @override
  String get chatPermissionRequired => '敏感操作确认';

  @override
  String get chatCompactedDivider => '上下文已压缩';

  @override
  String get quickPanelTitle => '当前对话控制';

  @override
  String get quickPanelProvider => '接口厂商';

  @override
  String get quickPanelModel => '模型';

  @override
  String get quickPanelEffort => '思考强度';

  @override
  String get quickPanelContext => '上下文占用';

  @override
  String get quickPanelFollowGlobal => '跟随全局默认';

  @override
  String get quickPanelResetSessionModel => '恢复跟随全局';

  @override
  String get quickPanelSafeMode => '安全模式（不加载自定义钩子与插件）';

  @override
  String get terminalTitle => '原生终端';

  @override
  String get terminalNew => '新建终端';

  @override
  String get terminalUnavailable => '终端未就绪：请先确保本地网关运行中。';

  @override
  String get filesTitle => '工作区与文件';

  @override
  String get filesGitStatus => 'Git 变更';

  @override
  String get filesSaveSuccess => '已保存';

  @override
  String get extensionsTitle => '扩展与工具链';

  @override
  String get extensionsModules => '工具包模块';

  @override
  String get extensionsMcp => 'MCP 服务器';

  @override
  String get extensionsSkills => '技能 (Skills)';

  @override
  String get extensionsPlugins => 'Claude 插件';

  @override
  String get extensionsImportSkillZip => '导入 .zip 技能';

  @override
  String get extensionsInstalled => '已安装';

  @override
  String get extensionsInstall => '安装';

  @override
  String get extensionsRemove => '卸载';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsProviders => '模型接口与密钥';

  @override
  String get settingsClaudeLogin => 'Claude 官方账户登录';

  @override
  String get settingsApiKey => 'API Key';

  @override
  String get settingsAppearance => '外观与语言';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsGlassBlur => '毛玻璃模糊效果';

  @override
  String get settingsLanguage => '界面语言';

  @override
  String get settingsShizuku => 'Shizuku 特权命令行 (priv / cc-mem)';

  @override
  String get settingsShizukuDesc => '可选：允许终端与 Claude 经授权调用 priv 执行 logcat/pm 调试命令，以及开启重编译前内存管家。不包含任何无障碍读屏或屏幕点按功能。';

  @override
  String get settingsShizukuRequest => '申请 Shizuku 授权';

  @override
  String get settingsShizukuOpen => '打开 Shizuku 管理器';

  @override
  String get settingsShizukuAudit => '特权命令审计日志';

  @override
  String get settingsGatewayStatus => '网关与运行时诊断';

  @override
  String get settingsGatewayRestart => '重启本地网关';

  @override
  String get settingsGatewayStop => '停止网关';
}
