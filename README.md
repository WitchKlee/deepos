# DeepOS

DeepOS 是一款 **Android 原生免 PRoot Claude Code 端侧开发工作站**（`applicationId = app.deepos`），将 **Flutter 3 原生 120Hz 高刷毛玻璃界面** 与 **[`cccodroid`](https://github.com/greyoak111/cccodroid) 免 PRoot 原生底座** 深度融合。

## 核心能力

- **免 PRoot 原生执行（Zero-PRoot）**：采用 10 字符包名 `app.deepos` 与 Termux 工具包逐字节等长前缀改写，经 `libldlinux.so`（glibc 动态加载器）+ `seccomp-enosys`（Android 14+ 系统调用回退）+ `exec-shim` 直接运行 Anthropic 官方原版 `linux-arm64` Claude Code 二进制，同时提供 `sdk28` 与 `sdk36` 双构建风味。
- **120Hz 原生 Flutter 界面壳**：内置 `ChatRowsCache` 行级恒等缓存、毛玻璃主题与平板自适应分栏，支持工具调用折叠卡、Subagent 子代理进度、代码与对话文件级 **Rewind 回退**、会话 **Fork 分叉**、`/goal` 自动循环及排队消息 **⚡ 不打断插话**。
- **多接口与单会话独立模型**：支持 Claude.ai 官方账号 OAuth 登录，以及 DeepSeek、智谱 GLM、Kimi、通义千问、MiniMax 等 Anthropic 兼容接口，每个对话可独立切换厂商、模型与思考强度。
- **原生终端、工作区与模块化扩展**：内置 `xterm` 终端（`libccptyhost.so` PTY）、工作区文件浏览与 Git 状态视图，以及模块化工具包、MCP 服务器、Skills（`.zip` 导入）与 Claude 插件管理。
- **可选 Shizuku 命令行辅助（无屏幕操控）**：完全移除 `AccessibilityService` 屏幕读取与点按，仅保留可选的 Shizuku 终端 `priv` 调试命令与 `cc-mem` 重编译前后台内存管家。

## 开发与验证

```bash
# 1. 本地网关后端回归测试
node tooling/test-gateway.mjs a0610-b2-sessionops ccmem.test a0610-b2-state-shapes

# 2. 纯 Dart 网关客户端分析与测试（含真实网关 HMAC + SSE 互操作测试）
(cd packages/cc_gateway_client && dart pub get && dart analyze && dart test)

# 3. 国际化合并与 Flutter 静态分析 / 单测
python3 app/tool/l10n_merge.py
(cd app && flutter pub get && flutter analyze lib/ && flutter test)

# 4. 构建双风味 Android APK
(cd app && flutter build apk --debug --flavor sdk28)
(cd app && flutter build apk --debug --flavor sdk36)
```

## 开源协议与合规声明

- 本项目整体以 **GNU Affero General Public License v3.0 (AGPL-3.0)** 发布，详见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 界面架构与工程体系派生自 [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go)（AGPL-3.0）。
- 免 PRoot 原生加载层、模块化工具包构建器与本地 Claude Code 网关移植自 [greyoak111/cccodroid](https://github.com/greyoak111/cccodroid)（Apache-2.0）。
- **Claude Code** 为 Anthropic 专有软件，**不随本仓库或 APK 分发**，仅在首次启动时由用户设备从 Anthropic 官方渠道下载并校验后原样运行。
