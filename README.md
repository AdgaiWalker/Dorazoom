# DoraZoom

DoraZoom 是哆啦个人版的 macOS 屏幕讲解工具，目标是尽量还原 Windows ZoomIt 的高频体验：快速缩放、圈画、白板/黑板、截图到剪贴板、OCR、录屏、摄像头画中画和滚动长截图。

本项目基于 Microsoft Sysinternals ZoomIt for Mac 官方源码改造，锁定上游提交为 `b03e43da91cd84eeb8f691fa65095e0304c3e660`。上游 MIT 许可证与归属保留在仓库中；DoraZoom 的产品裁决以 [PRD.md](/Users/happy/Desktop/zoomit/PRD.md) 为准。

## 当前交付状态

- Phase 1–6 的自动化证明已完成。
- 自动化测试全部走模拟层/测试替身：不碰真实 TCC、全局键盘、真实屏幕、麦克风、摄像头、真实剪贴板、真实目标 App 或真实用户输出文件；这里的“模拟器”指 DoraZoom 进程内模拟边界，不是 iOS Simulator。
- 非侵入交付门禁已收敛到 `Scripts/verify-delivery.sh`。
- Phase 7 已改为本地模拟验收：完成条件是模拟测试、测试替身、确定性事件回放、产物元数据和验收记录校验全部通过；记录见 [ACCEPTANCE.md](/Users/happy/Desktop/zoomit/ACCEPTANCE.md)。

## 产品身份

| 用途 | App | Bundle ID | Display Name | 说明 |
| --- | --- | --- | --- | --- |
| 日常版 | `.build/DoraZoom.app` | `com.duola.dorazoom` | `DoraZoom` | 用于本地模拟验收和日常使用 |
| 开发版 | `.build/DoraZoom Dev.app` | `com.duola.dorazoom.dev` | `DoraZoom (Dev)` | 用于隔离调试，不占用日常版权限条目 |

不要把 ad-hoc 或调试构建伪装成日常版 Bundle ID。macOS 权限记录与 Bundle ID、签名要求相关，混用会让系统设置里看似已授权、实际不可用。

## 功能范围

- `Control+1`：静态缩放。
- `Control+2`：原比例绘画。
- `Control+3`：休息计时器。
- `Control+4`：实时缩放。
- `Control+5`：录制全屏。
- `Control+Shift+5`：录制区域。
- `Control+6`：截图到剪贴板。
- `Control+Shift+6`：截图保存到文件。
- `Control+Option+6`：OCR 到剪贴板。
- `Control+8`：滚动长截图到剪贴板。
- `Control+Shift+8`：滚动长截图保存到文件。
- 绘画工具：自由画笔、直线、矩形、椭圆、箭头、高亮、撤销、擦除、文字。
- 白板/黑板：`W` 进入白板，`K` 进入黑板；白色/黑色画笔保留但无默认快捷键。
- 粘贴：`Command+V` 永远原生；获得“辅助功能/发送按键”权限后，`Control+V` 只在 DoraZoom 截图仍在剪贴板时临时转换为粘贴。
- 录制：默认 MOV/H.264/AAC；MP4 保留；GIF 保留独立 ImageIO 管线。

## 构建与验证

常规开发验证：

```sh
swift build
swift test
.build/debug/ZoomItMacSelfTest
```

交付前非侵入门禁：

```sh
Scripts/verify-delivery.sh
```

该脚本会构建、测试、运行官方 self-test、审计 SwiftPM 依赖、校验 `.build` 根目录 App 白名单、构建开发版与日常版、验签、打 zip、拒绝旧 `ZoomIt.zip` 残留、解包后再次验签、输出源码量和包体快照，并运行 `git diff --check`。

脚本不会安装 App 到 `/Applications`，不会请求系统权限，不会启动全局快捷键监听，不会重置 TCC。

本地模拟验收推荐只记这个入口：

```sh
Scripts/phase7-preflight.sh
```

它会先跑完整交付门禁，再验证本地模拟验收记录；它不会安装、启动或申请权限。

如需查看本地模拟验收记录草稿，可以运行：

```sh
Scripts/phase7-acceptance-draft.sh
```

它只把本地模拟验收记录打印到终端，不会修改 `ACCEPTANCE.md`，也不会声称真实系统权限、真实剪贴板或真实播放器已经通过。

验收记录可运行：

```sh
Scripts/verify-acceptance-record.sh ACCEPTANCE.md
```

该脚本只检查验收记录是否还有空白结果，不会启动 App 或触碰真实系统权限。

如需排查旧安装包，可单独运行：

```sh
Scripts/audit-install-surface.sh
```

该脚本只读 `/Applications` 下的明确候选 App 身份，用来发现旧 `ZoomIt.app`、旧 `DoraZoom (Dev).app` 或错误 Bundle ID；它不会删除、覆盖、启动或申请权限。

## 运行与本地模拟验收

当前完成条件全部走本地模拟：

1. 运行 `Scripts/phase7-preflight.sh`，确认交付门禁和本地模拟验收记录通过。
2. 运行 `Scripts/verify-acceptance-record.sh ACCEPTANCE.md`，确认记录没有空白验收单元格。
3. 不把模拟验收写成真实系统权限、真实全局输入或真实外部播放器验收。

如果以后要面向他人分发或真实日常试用，再单独建立真实设备验收目标。

## 重要文档

- [PRD.md](/Users/happy/Desktop/zoomit/PRD.md)：产品需求与验收标准。
- [ARCHITECTURE.md](/Users/happy/Desktop/zoomit/ARCHITECTURE.md)：技术架构与边界。
- [GOAL.md](/Users/happy/Desktop/zoomit/GOAL.md)：阶段目标、边界和剩余工作。
- [VALIDATION.md](/Users/happy/Desktop/zoomit/VALIDATION.md)：自动化与交付门禁证据。
- [ACCEPTANCE.md](/Users/happy/Desktop/zoomit/ACCEPTANCE.md)：Phase 7 本地模拟验收记录。
