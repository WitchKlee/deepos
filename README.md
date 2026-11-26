# DeepOS

DeepOS 是一款基于 [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) 二次开发的 **Android 专属精简定制版** DeepSeek Harness (DSH) 客户端与端侧 Agent 操作系统。

## 核心能力（保留）

- **端侧 Linux 引擎（PRoot / Ubuntu 24.04）**：免 Root 在 Android 上直接运行 `dsh web`、bash、Node.js、Python 与终端会话。
- **远程主机与多端协同**：支持 SSH 主机与 DSH Remote（WebRTC / LAN / TURN / 中继）无缝切换。
- **手机操控（Android Accessibility / Shizuku / ADB）**：自动操作手机界面、本地 OCR、应用权限与操作审计。
- **语音对话与端上语音模型**：内置 Silero VAD v6.2 + smart-turn v3.2 与原生语音通话 / 朗读。
- **可扩展插件与主题系统**：支持 `dsh-go-plugin` 原生扩展位、本地自定义主题包与声明式 `ui.json`。
- **本地离线导出与分享码**：支持图片长图、离线 HTML / Markdown / `.dshgo` 回放文件及纯前端 fragment 分享码。

## 精简内容（相对上游 dsh-Go）

- 仅保留 **Android** 端（移除了 iOS、HarmonyOS/ArkTS、官网、Cloudflare Workers 后端与测试截图）。
- 移除了非核心娱乐与官方云耦合模块：酒馆（Tavern）、论坛与社区（Forum / Community）、伙伴小屋（Companion / Live2D）、桌宠与悬浮宠（Pets）、创意工坊（Workshop）、模式切换与 Bot 目录（Modes / Bots）、托管外链上传（Share Hosted）、匿名遥测统计（Usage Telemetry）及求 Star 弹窗。
- 完整替换了所有受版权保护的品牌标识、启动图标与鲸尾加载精灵图，采用独立设计的 DeepOS 几何向量图形。
- 独立包名 `io.github.witchklee.deepos`，更新源指向 `WitchKlee/deepos`。

## 开发与验证

```bash
# 1. Dart 核心包验证
(cd packages/dsh_client && dart pub get && dart analyze && dart test)
(cd packages/dsh_remote && dart pub get && dart analyze && dart test)

# 2. Flutter 应用静态分析
(cd app && flutter pub get && flutter analyze lib/)

# 3. 构建 Android 调试 APK（含 arm64 引擎需先运行 runtime/build-runtime.sh arm64-v8a）
(cd app && flutter build apk --debug --flavor arm64)
```

## 开源协议与致谢

本项目遵循 **GNU Affero General Public License v3.0 (AGPL-3.0)**，详见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

- 上游项目：[ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go)（AGPL-3.0）
- 远程协议上游：[liguobao/ds-harness-remote](https://github.com/liguobao/ds-harness-remote)
- 本应用并非 DeepSeek 官方产品。
