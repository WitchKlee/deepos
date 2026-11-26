# AGENTS.md — DeepOS

DeepOS 是基于 [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) 二次开发的 Android 专属精简定制版客户端（`applicationId = io.github.witchklee.deepos`）。

## 仓库布局

```
app/                         Flutter Android App（原生 UI、Riverpod 状态、手机操控、语音、主题、插件）
app/android/                 Android 宿主（Kotlin、PRoot 引擎管理、无障碍手机操控、端上语音）
packages/dsh_client/         纯 Dart 客户端：HTTP/SSE、mux、会话与权限 API
packages/dsh_remote/         远程传输：WebRTC / LAN / TURN / 中继
runtime/                     DSH 引擎运行时与补丁（保留上游补丁兼容性）
sdk/plugin-kit/              原生插件 SDK
tooling/                     APK 构建与版本号脚本
docs/                        架构与开发文档
```

## 常用验证命令

```bash
(cd app && flutter pub get && flutter analyze lib/)
(cd packages/dsh_client && dart pub get && dart analyze && dart test)
(cd packages/dsh_remote && dart pub get && dart analyze && dart test)
(cd app && flutter build apk --debug --flavor arm64)
node --test runtime/tests/*.test.mjs
```

## 关键约束

- **Android PRoot 约束**：`app/android/app/build.gradle.kts` 中的 `targetSdk = 28` 与 `useLegacyPackaging = true` 为 PRoot 执行 rootfs 内二进制所必需，请勿改动。
- **AGPL-3.0 与素材合规**：保留 `LICENSE`、`THIRD_PARTY_NOTICES.md` 及上游 `ccch1mneyyy/dsh-Go` 署名；不得引入上游 `ASSETS.md` 声明的非 AGPL 品牌或吉祥物素材。
- **界面文案**：修改 `app/lib/l10n/parts/*.arb` 后运行 `python3 app/tool/l10n_merge.py`，不要直接手改 `app/lib/l10n/gen/`。
- **不提交敏感信息**：签名密钥、API Key、Token 不入库、不回显。
