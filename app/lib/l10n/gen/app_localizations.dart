import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'DeepOS'**
  String get appTitle;

  /// No description provided for @commonMonthDay.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日'**
  String commonMonthDay(String month, int day);

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get commonCopy;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get commonRefresh;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @commonAllow.
  ///
  /// In zh, this message translates to:
  /// **'允许'**
  String get commonAllow;

  /// No description provided for @commonDeny.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get commonDeny;

  /// No description provided for @commonAllowSession.
  ///
  /// In zh, this message translates to:
  /// **'本会话均允许'**
  String get commonAllowSession;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get commonLoading;

  /// No description provided for @commonEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get commonEmpty;

  /// No description provided for @onboardingTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 DeepOS'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'免 PRoot 原生 Claude Code 端侧开发工作站'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingStepToolkit.
  ///
  /// In zh, this message translates to:
  /// **'1. 安装原生开发工具包'**
  String get onboardingStepToolkit;

  /// No description provided for @onboardingStepToolkitDesc.
  ///
  /// In zh, this message translates to:
  /// **'从 Termux 官方仓库按模块拉取（含 bash / git / node / python / clang），按 10 字符包名 app.deepos 等长改写，零 PRoot 损耗。'**
  String get onboardingStepToolkitDesc;

  /// No description provided for @onboardingStepClaude.
  ///
  /// In zh, this message translates to:
  /// **'2. 获取官方原版 Claude Code'**
  String get onboardingStepClaude;

  /// No description provided for @onboardingStepClaudeDesc.
  ///
  /// In zh, this message translates to:
  /// **'从 Anthropic 官方渠道在线下载并校验 SHA-256，原版二进制直接经 glibc 加载器运行。'**
  String get onboardingStepClaudeDesc;

  /// No description provided for @onboardingStepAuth.
  ///
  /// In zh, this message translates to:
  /// **'3. 连接模型接口'**
  String get onboardingStepAuth;

  /// No description provided for @onboardingStepAuthDesc.
  ///
  /// In zh, this message translates to:
  /// **'可登录 Claude 账户，或配置 Anthropic / DeepSeek / GLM / Kimi 等兼容 API Key。'**
  String get onboardingStepAuthDesc;

  /// No description provided for @onboardingInstallToolkit.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装工具包'**
  String get onboardingInstallToolkit;

  /// No description provided for @onboardingInstallClaude.
  ///
  /// In zh, this message translates to:
  /// **'下载官方 Claude Code'**
  String get onboardingInstallClaude;

  /// No description provided for @onboardingStartGateway.
  ///
  /// In zh, this message translates to:
  /// **'启动本地网关'**
  String get onboardingStartGateway;

  /// No description provided for @onboardingSkipToWorkspace.
  ///
  /// In zh, this message translates to:
  /// **'进入工作台'**
  String get onboardingSkipToWorkspace;

  /// No description provided for @onboardingOfflineArchive.
  ///
  /// In zh, this message translates to:
  /// **'选择本地离线工具包…'**
  String get onboardingOfflineArchive;

  /// No description provided for @navSessions.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get navSessions;

  /// No description provided for @navNewChat.
  ///
  /// In zh, this message translates to:
  /// **'新对话'**
  String get navNewChat;

  /// No description provided for @navTerminal.
  ///
  /// In zh, this message translates to:
  /// **'终端'**
  String get navTerminal;

  /// No description provided for @navFiles.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get navFiles;

  /// No description provided for @navExtensions.
  ///
  /// In zh, this message translates to:
  /// **'扩展'**
  String get navExtensions;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @navTrash.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get navTrash;

  /// No description provided for @chatComposerHint.
  ///
  /// In zh, this message translates to:
  /// **'给 Claude 发消息，或输入 /goal、/compact…'**
  String get chatComposerHint;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'原生 Claude Code 已就绪'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'直接读写本机项目、执行终端命令、拆分子代理与回退代码。'**
  String get chatEmptySubtitle;

  /// No description provided for @chatSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get chatSend;

  /// No description provided for @chatStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get chatStop;

  /// No description provided for @chatQueuePromote.
  ///
  /// In zh, this message translates to:
  /// **'⚡ 插话'**
  String get chatQueuePromote;

  /// No description provided for @chatQueueCount.
  ///
  /// In zh, this message translates to:
  /// **'排队中 {count} 条'**
  String chatQueueCount(int count);

  /// No description provided for @chatActionResend.
  ///
  /// In zh, this message translates to:
  /// **'重发'**
  String get chatActionResend;

  /// No description provided for @chatActionRewind.
  ///
  /// In zh, this message translates to:
  /// **'回退到此处'**
  String get chatActionRewind;

  /// No description provided for @chatActionFork.
  ///
  /// In zh, this message translates to:
  /// **'从此处分叉'**
  String get chatActionFork;

  /// No description provided for @chatActionShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get chatActionShare;

  /// No description provided for @chatRewindTitle.
  ///
  /// In zh, this message translates to:
  /// **'代码与对话回退'**
  String get chatRewindTitle;

  /// No description provided for @chatRewindFilesOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅还原代码改动'**
  String get chatRewindFilesOnly;

  /// No description provided for @chatRewindFilesAndChat.
  ///
  /// In zh, this message translates to:
  /// **'同时还原代码与对话'**
  String get chatRewindFilesAndChat;

  /// No description provided for @chatRewindNoFiles.
  ///
  /// In zh, this message translates to:
  /// **'此消息之后没有可还原的文件改动。'**
  String get chatRewindNoFiles;

  /// No description provided for @chatToolStepsDone.
  ///
  /// In zh, this message translates to:
  /// **'{count} 步工具调用 · 已完成'**
  String chatToolStepsDone(int count);

  /// No description provided for @chatToolStepsRunning.
  ///
  /// In zh, this message translates to:
  /// **'{count} 步工具调用 · 执行中'**
  String chatToolStepsRunning(int count);

  /// No description provided for @chatSubagentTag.
  ///
  /// In zh, this message translates to:
  /// **'子代理'**
  String get chatSubagentTag;

  /// No description provided for @chatThinkingLabel.
  ///
  /// In zh, this message translates to:
  /// **'思考过程'**
  String get chatThinkingLabel;

  /// No description provided for @chatPermissionRequired.
  ///
  /// In zh, this message translates to:
  /// **'敏感操作确认'**
  String get chatPermissionRequired;

  /// No description provided for @chatCompactedDivider.
  ///
  /// In zh, this message translates to:
  /// **'上下文已压缩'**
  String get chatCompactedDivider;

  /// No description provided for @quickPanelTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前对话控制'**
  String get quickPanelTitle;

  /// No description provided for @quickPanelProvider.
  ///
  /// In zh, this message translates to:
  /// **'接口厂商'**
  String get quickPanelProvider;

  /// No description provided for @quickPanelModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get quickPanelModel;

  /// No description provided for @quickPanelEffort.
  ///
  /// In zh, this message translates to:
  /// **'思考强度'**
  String get quickPanelEffort;

  /// No description provided for @quickPanelContext.
  ///
  /// In zh, this message translates to:
  /// **'上下文占用'**
  String get quickPanelContext;

  /// No description provided for @quickPanelFollowGlobal.
  ///
  /// In zh, this message translates to:
  /// **'跟随全局默认'**
  String get quickPanelFollowGlobal;

  /// No description provided for @quickPanelResetSessionModel.
  ///
  /// In zh, this message translates to:
  /// **'恢复跟随全局'**
  String get quickPanelResetSessionModel;

  /// No description provided for @quickPanelSafeMode.
  ///
  /// In zh, this message translates to:
  /// **'安全模式（不加载自定义钩子与插件）'**
  String get quickPanelSafeMode;

  /// No description provided for @terminalTitle.
  ///
  /// In zh, this message translates to:
  /// **'原生终端'**
  String get terminalTitle;

  /// No description provided for @terminalNew.
  ///
  /// In zh, this message translates to:
  /// **'新建终端'**
  String get terminalNew;

  /// No description provided for @terminalUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'终端未就绪：请先确保本地网关运行中。'**
  String get terminalUnavailable;

  /// No description provided for @filesTitle.
  ///
  /// In zh, this message translates to:
  /// **'工作区与文件'**
  String get filesTitle;

  /// No description provided for @filesGitStatus.
  ///
  /// In zh, this message translates to:
  /// **'Git 变更'**
  String get filesGitStatus;

  /// No description provided for @filesSaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get filesSaveSuccess;

  /// No description provided for @extensionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'扩展与工具链'**
  String get extensionsTitle;

  /// No description provided for @extensionsModules.
  ///
  /// In zh, this message translates to:
  /// **'工具包模块'**
  String get extensionsModules;

  /// No description provided for @extensionsMcp.
  ///
  /// In zh, this message translates to:
  /// **'MCP 服务器'**
  String get extensionsMcp;

  /// No description provided for @extensionsSkills.
  ///
  /// In zh, this message translates to:
  /// **'技能 (Skills)'**
  String get extensionsSkills;

  /// No description provided for @extensionsPlugins.
  ///
  /// In zh, this message translates to:
  /// **'Claude 插件'**
  String get extensionsPlugins;

  /// No description provided for @extensionsImportSkillZip.
  ///
  /// In zh, this message translates to:
  /// **'导入 .zip 技能'**
  String get extensionsImportSkillZip;

  /// No description provided for @extensionsInstalled.
  ///
  /// In zh, this message translates to:
  /// **'已安装'**
  String get extensionsInstalled;

  /// No description provided for @extensionsInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get extensionsInstall;

  /// No description provided for @extensionsRemove.
  ///
  /// In zh, this message translates to:
  /// **'卸载'**
  String get extensionsRemove;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsProviders.
  ///
  /// In zh, this message translates to:
  /// **'模型接口与密钥'**
  String get settingsProviders;

  /// No description provided for @settingsClaudeLogin.
  ///
  /// In zh, this message translates to:
  /// **'Claude 官方账户登录'**
  String get settingsClaudeLogin;

  /// No description provided for @settingsApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get settingsApiKey;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观与语言'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingsThemeMode;

  /// No description provided for @settingsGlassBlur.
  ///
  /// In zh, this message translates to:
  /// **'毛玻璃模糊效果'**
  String get settingsGlassBlur;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get settingsLanguage;

  /// No description provided for @settingsShizuku.
  ///
  /// In zh, this message translates to:
  /// **'Shizuku 特权命令行 (priv / cc-mem)'**
  String get settingsShizuku;

  /// No description provided for @settingsShizukuDesc.
  ///
  /// In zh, this message translates to:
  /// **'可选：允许终端与 Claude 经授权调用 priv 执行 logcat/pm 调试命令，以及开启重编译前内存管家。不包含任何无障碍读屏或屏幕点按功能。'**
  String get settingsShizukuDesc;

  /// No description provided for @settingsShizukuRequest.
  ///
  /// In zh, this message translates to:
  /// **'申请 Shizuku 授权'**
  String get settingsShizukuRequest;

  /// No description provided for @settingsShizukuOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开 Shizuku 管理器'**
  String get settingsShizukuOpen;

  /// No description provided for @settingsShizukuAudit.
  ///
  /// In zh, this message translates to:
  /// **'特权命令审计日志'**
  String get settingsShizukuAudit;

  /// No description provided for @settingsGatewayStatus.
  ///
  /// In zh, this message translates to:
  /// **'网关与运行时诊断'**
  String get settingsGatewayStatus;

  /// No description provided for @settingsGatewayRestart.
  ///
  /// In zh, this message translates to:
  /// **'重启本地网关'**
  String get settingsGatewayRestart;

  /// No description provided for @settingsGatewayStop.
  ///
  /// In zh, this message translates to:
  /// **'停止网关'**
  String get settingsGatewayStop;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'zh':
      return L10nZh();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
