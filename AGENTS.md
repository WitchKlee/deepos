# AGENTS.md — DeepOS

DeepOS 是基于 [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go)（AGPL-3.0）与 [greyoak111/cccodroid](https://github.com/greyoak111/cccodroid)（Apache-2.0）融合重构的 **Android 原生免 PRoot Claude Code 端侧工作站**（`applicationId = app.deepos`）。

## 仓库布局

```
app/                         Flutter Android App（120Hz 原生 UI、Riverpod 3 状态、xterm 终端、文件/扩展、毛玻璃主题）
app/android/                 Android 宿主（Kotlin GatewayService/Installer、可选 Shizuku CLI priv 桥、CMake 原生垫片）
packages/cc_gateway_client/  纯 Dart 网关客户端（/__proof 验签、X-CC-Sig 按次 HMAC 签名、/api/events SSE 环形续传）
gateway/                     免 PRoot 本地 Claude Code HTTP + SSE 网关（移植自 cccodroid，移除 WebView 前端与无障碍控屏）
devkit/                      模块化 Termux 工具包构建器（10 字符包名 app.deepos 等长字节前缀改写）
claude-code/                 官方原版 Claude Code 清单与签名校验文件（不随仓/APK 分发专有二进制）
third_party/                 随 APK 分发的 LGPL/MIT 许可与源码归档说明（glibc loader、7-Zip、Shizuku-API）
tooling/                     网关测试与构建脚本
```

## 常用验证命令

```bash
node tooling/test-gateway.mjs a0610-b2-sessionops ccmem.test a0610-b2-state-shapes a0610-b2-transcript-search a0610-b3-records-atomic
(cd packages/cc_gateway_client && dart pub get && dart analyze && dart test)
python3 app/tool/l10n_merge.py && git diff --exit-code -- app/lib/l10n
(cd app && flutter pub get && flutter analyze lib/ && flutter test)
(cd app && flutter build apk --debug --flavor sdk28)
(cd app && flutter build apk --debug --flavor sdk36)
```

## 关键约束

- **10 字符包名与免 PRoot 双风味**：`app/android/app/build.gradle.kts` 的 `applicationId = "app.deepos"`（与 `com.termux` 同为 10 字符）用于 Termux 工具包等长字节替换；`useLegacyPackaging = true` 为 `libldlinux.so` 与原生垫片可执行所必需，请勿改动。
- **不含无障碍控屏**：保留可选 Shizuku 终端 `priv` / `cc-mem` 辅助，禁止重新引入 `AccessibilityService` 屏幕操控。
- **AGPL-3.0 / Apache-2.0 / 专有合规**：保留 `LICENSE`、`THIRD_PARTY_NOTICES.md` 中 `ccch1mneyyy/dsh-Go` 与 `greyoak111/cccodroid` 署名；严禁将 Anthropic 官方 Claude Code 闭源二进制打包进仓库或 APK 资产。
- **界面文案**：修改 `app/lib/l10n/parts/*.arb` 后运行 `python3 app/tool/l10n_merge.py`，不要直接手改 `app/lib/l10n/gen/`。
- **不提交敏感信息**：签名密钥、API Key、Token 不入库、不回显。
