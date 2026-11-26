# 品牌与第三方素材说明（DeepOS）

DeepOS 基于 [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go)（AGPL-3.0）二次开发。

## 品牌素材

DeepOS 已完整移除上游 `dsh-Go` 中不在 AGPL-3.0 授权范围内的品牌标识、桌宠/吉祥物（Deepy、小粉鱼、鲸娘）、求 Star 贴纸与鲸尾加载精灵图，并替换为独立绘制的 DeepOS 几何向量图形：

- `app/assets/brand/` 与生成的 `app/lib/ui/shell/brand_glyph.g.dart`
- `app/android/app/src/main/res/mipmap-*/ic_launcher*.png`、`drawable/ic_launcher_monochrome.xml`、`drawable/ic_stat_dsh.xml`
- `app/lib/ui/chat/widgets/whale_tail.dart`（纯向量几何脉动指示器，无外部图片素材）

## 端上语音模型

语音通话判停模型位于 `app/android/app/src/main/assets/speech/`，随 APK 打包，遵循各自开源协议（详见 `THIRD_PARTY_NOTICES.md`）：

- `silero_vad.onnx`（Silero VAD v6.2，MIT）
- `smart-turn-v3.2-cpu.onnx`（smart-turn v3.2 int8，BSD-2-Clause）
