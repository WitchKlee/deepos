# DeepOS v2 架构与代码地图

> Android 专属免 PRoot 原生 Claude Code 端侧开发工作站（`applicationId = app.deepos`）。

## 1. 系统全貌

```text
┌─────────────────── Android App 进程（app.deepos · Flutter 3 + Kotlin）───────────────────┐
│ Dart: ui/（120Hz ChatRowsCache / xterm / Files / Extensions / GlassTheme）                │
│        └─ Riverpod 3: state/ ── CcGatewayClient (packages/cc_gateway_client) ──┐         │
│        └─ MethodChannel/EventChannel (deepos/runtime, deepos/priv) ──> Kotlin  │ HTTP+SSE│
│             runtime/: Env / Installer / GatewayService (WakeLock + SPAWN_KEY)  │ X-CC-Sig│
│             priv/:    可选 Shizuku CLI 桥（priv / cc-mem，绝无无障碍控屏）       │         │
└──────────────────────────────────────────────┬─────────────────────────────────┼─────────┘
                                               │ stdin SPAWN_KEY                 │ 127.0.0.2:8791
┌──────────────────────────────────────────────▼─────────────────────────────────▼─────────┐
│ 免 PRoot 原生用户态（/data/data/app.deepos/files/）                                        │
│   gateway/server.mjs（Node + HTTP/SSE 32MB 环形缓冲 + PreToolUse 守卫 + 会话/回退/分叉）     │
│     ├─ CMake 原生垫片（libccenosys / libccexecshim / libccptyhost / libccnodump）          │
│     ├─ libldlinux.so（glibc 动态加载器，已按 10 字符等长改写为 app.deepos）                  │
│     ├─ 官方原版 linux-arm64 Claude Code 二进制（首次启动在线下载并校验，不进 APK）           │
│     └─ 模块化 Termux Devkit（bash / git / node / python / clang，零 PRoot 原生执行）        │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

## 2. 目录结构

| 路径 | 职责 |
|---|---|
| `app/lib/state/` | Riverpod 3 状态层（严禁 import `ui/`，由 `app/test/arch/import_direction_test.dart` 强制守卫） |
| `app/lib/runtime/`、`app/lib/priv/` | Flutter 平台通道桥（`deepos/runtime`、`deepos/priv`） |
| `app/lib/ui/` | 120Hz 原生 UI（`ChatRowsCache`、`HomeShell`、`OnboardingPage`、`TerminalPage`、`FilesPage`、`ExtensionsPage`、`SettingsPage`） |
| `app/android/app/src/main/cpp/` | CMake 编译的 7 个免 PRoot 原生垫片与 PTY 宿主 |
| `app/android/app/src/main/kotlin/app/deepos/` | `MainActivity`（120Hz 帧率投票）、`GatewayService`、`Installer`、`Env`、可选 Shizuku `PrivPlugin` |
| `packages/cc_gateway_client/` | 纯 Dart 客户端：`/__proof` 身份验签、`X-CC-Sig` 按次 HMAC 签名、`/api/events` SSE 断流续传与强类型 API |
| `gateway/` | 移植并裁剪自 `cccodroid`（Apache-2.0）的本地 Claude Code 网关（已移除 WebView 前端与无障碍控屏） |
| `devkit/`、`claude-code/` | 模块化 Termux 工具包构建器（10 字符等长前缀改写）与官方 Claude Code 验签清单 |

## 3. 双风味构建（`sdk28` / `sdk36`）

- **`sdk28`**：常规兼容包（`targetSdk = 28`），允许直接执行应用私有目录内二进制。
- **`sdk36`**：适配拦截旧 `targetSdk` 的新款 Android 15/16/17 机型（`targetSdk = 36`），自动启用 `libldlinux.so` + `/system/bin/linker64` + `libccexecshim.so` 经加载器执行模式。
