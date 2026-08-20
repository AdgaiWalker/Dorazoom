# DoraZoom Phase 7 本地模拟验收记录

这份记录把最终验收统一收敛到 DoraZoom 项目内的本地模拟层、测试替身、确定性事件回放和非侵入交付门禁。这里的“模拟器”不是 iOS Simulator，而是本仓库内可重复运行的 macOS 桌面 App 模拟边界。

> 当前说明：Apple 交互重构 Phase 1–6 与原生文字稳定化的工程实现已完成；权限中心、六组设置、短暂反馈、差异化指针、显示同步缩放、原生 AppKit 文字会话、截图隐私闭环、录制预检/暂停/恢复/隐私叠加、轻量录后结果和菜单分层均在 `VALIDATION.md` 中有新的本地模拟证据。本文把本地模拟结论与用户真机验收状态分开；任何“通过”都不能代替真实 macOS 人工体验事实。

本记录不声称已经在真实 macOS 权限弹窗、真实全局键盘、真实系统剪贴板、真实屏幕/麦克风/摄像头、真实目标 App、真实播放器或真实剪辑软件中完成验证。模拟契约、产物元数据和本地 writer/事件替身只证明工程已可供验收；对应真机状态列在第 7 节，等待用户可见验证。

## 0. 验收原则

- 验收对象：本地构建的 `.build/DoraZoom.app`、`.build/DoraZoom Dev.app` 和 `.build/DoraZoom.zip`。
- 自动化验收边界：只运行本地模拟测试、测试替身、自测程序、签名/包体/元数据读取和文档记录检查。
- 自动化禁止事项：不安装到 `/Applications`，不启动 App 进行真实系统交互，不申请或重置 TCC，不注册登录项，不触碰真实系统剪贴板，不捕获真实屏幕/麦克风/摄像头，不控制真实目标 App，不写入真实用户输出目录。第 7 节人工验收只在用户确认后由可见 App 执行。
- 完成判断：`Scripts/phase7-preflight.sh`、`Scripts/verify-delivery.sh`、`Scripts/verify-acceptance-record.sh ACCEPTANCE.md` 均通过；`ACCEPTANCE.md` 不存在空白验收单元格，最终结论只选择一个。

## 1. 本地模拟门禁

运行：

```sh
Scripts/phase7-preflight.sh
Scripts/verify-acceptance-record.sh ACCEPTANCE.md
```

记录：

| 项目 | 结果 | 备注 |
| --- | --- | --- |
| 自动化测试边界审计 | 通过 | `Scripts/verify-test-boundary.sh` 限制 `Tests/` 不直接触碰真实 TCC、全局键盘、真实屏幕、真实麦克风/摄像头、系统剪贴板、目标 App、登录项或 shell/process 逃逸命令 |
| 验收记录校验器自测 | 通过 | `Scripts/verify-acceptance-record.sh --self-test` 证明空白记录会失败、已填写样本会通过 |
| 本地模拟验收草稿生成器自测 | 通过 | `Scripts/phase7-acceptance-draft.sh --self-test` 只输出本地模拟验收记录，不预设真实系统结论 |
| Phase 7 本地模拟入口自测 | 通过 | `Scripts/phase7-preflight.sh --self-test` 只编排本地模拟/非侵入检查 |
| first-run reset helper 拒绝路径 | 通过 | `Scripts/verify-delivery.sh` 只证明未确认时拒绝执行，不运行破坏性 reset |
| `build-app.sh` 输入校验 | 通过 | 非法 Bundle ID、路径型或非 `.app` App 名、XML 不安全 display name 均在构建/签名前拒绝 |
| `swift build` | 通过 | 由 `Scripts/verify-delivery.sh` 执行 |
| `swift test` | 通过 | 219 项全量本地模拟 XCTest 通过 |
| `.build/debug/ZoomItMacSelfTest` | 通过 | 官方 self-test 通过 |
| SwiftPM 依赖 | 通过 | `No external dependencies found` |
| `.build` 根目录 App 白名单 | 通过 | 只允许 `.build/DoraZoom Dev.app` 与 `.build/DoraZoom.app` |
| 交付 zip 白名单 | 通过 | 只接受 `.build/DoraZoom.zip`，拒绝旧 `.build/ZoomIt.zip` |
| `git diff --check` | 通过 | 交付门禁执行并通过 |

## 2. 产物与身份模拟验收

| 项目 | 结果 | 备注 |
| --- | --- | --- |
| 开发版 Bundle ID | 通过 | `.build/DoraZoom Dev.app` 为 `com.duola.dorazoom.dev` |
| 日常版 Bundle ID | 通过 | `.build/DoraZoom.app` 为 `com.duola.dorazoom` |
| Bundle short/display name | 通过 | dev 为 `DoraZoom (Dev)`，daily 为 `DoraZoom` |
| Bundle 版本 | 通过 | `CFBundleShortVersionString` 与 `CFBundleVersion` 均为默认 `1.0` |
| 菜单栏模式 | 通过 | `LSUIElement=true` |
| 最低系统版本 | 通过 | `LSMinimumSystemVersion=14.0` |
| 隐私用途文案 | 通过 | 麦克风/摄像头用途说明包含 DoraZoom 身份 |
| 运行时图标资源 | 通过 | 源码资源、dev/daily app 与 zip 解包 app 均不包含旧 `ZoomIt*.png` |
| Entitlements | 通过 | 包含麦克风与摄像头授权项，不包含 App Sandbox |
| 开发版签名隔离 | 通过 | `Identifier=com.duola.dorazoom.dev`、`Signature=adhoc`、`TeamIdentifier=not set` |
| 日常版签名身份 | 通过 | daily 与 zip 解包 app 均为 `Identifier=com.duola.dorazoom`，Authority 与 TeamIdentifier 非空 |
| Hardened runtime | 通过 | daily 与 zip 解包 app 均启用 hardened runtime |
| 默认架构 | 通过 | 未显式设置 `ZOOMIT_ARCHS` 时 dev/daily/zip 解包产物均为 `arm64` |
| Zip 解包身份 | 通过 | 顶层只有 `DoraZoom.app`，身份、版本、菜单栏、最低系统版本、架构、entitlements 与日常版一致 |
| Zip 清洁度 | 通过 | 不包含 `._*` AppleDouble、`__MACOSX` 或本地 `com.apple.quarantine` 扩展属性 |

## 3. 权限、粘贴与系统边界模拟验收

| 场景 | 结果 | 备注 |
| --- | --- | --- |
| 权限页状态矩阵 | 通过 | `Phase6SettingsPermissionsSimulationTests` 覆盖 Screen Recording、input listen/post、microphone、camera 的状态与动作映射 |
| 权限请求边界 | 通过 | 模拟页 `touchesRealTCC=false`，不会打开真实 System Settings |
| `Command+V` 原生放行 | 通过 | 模拟事件流证明 DoraZoom 不拦截原生粘贴 |
| `Control+V` 兼容策略 | 通过 | Carbon 临时热键主路径只需 post/辅助功能权限；截图仍位于内存剪贴板时转换，listen/post Event Tap 仅作兜底 |
| 文字编辑期间的粘贴仲裁 | 通过 | Event Tap 放行原始 `Control+V`，Carbon 临时热键实际注销；结束编辑后仅在同一截图和权限仍有效时恢复 |
| 未授权 `Control+V` | 通过 | 模拟矩阵证明不拦截，目标 App 原行为保留 |
| 剪贴板失效 | 通过 | 模拟剪贴板内容变化后撤销临时 `Control+V`，不再转换 |
| 截图不留本地文件 | 通过 | 截图导出执行器使用内存剪贴板替身，模拟文件系统不出现本地截图写入 |
| OCR 字符数反馈 | 通过 | 模拟输出携带剪贴板变更号和用户可感知字符数，并映射为“已复制 N 个字符”；不声称真实 Vision 识别质量 |
| 测试逃逸防护 | 通过 | 边界脚本拒绝 `pbcopy`、`pbpaste`、`screencapture`、`osascript`、`Process`、`NSTask` 等真实系统路径 |

## 4. 快捷键、光标与绘画模拟验收

| 场景 | 结果 | 备注 |
| --- | --- | --- |
| `Control+1` 静态缩放 | 通过 | 静态缩放生命周期与 HUD/指针策略由模拟测试覆盖 |
| `Control+2` 原比例绘画 | 通过 | 绘画状态、画笔颜色/粗细、热点几何和指针资源由模拟测试覆盖 |
| 实时缩放与实时绘画 | 通过 | live zoom 非绘画时可穿透并全局接收指针与滚轮；鼠标为约 6% 比例步进，触控板低增益连续输入且单事件封顶；到 100% 保持模式，绘画/选区时由覆盖层接管 |
| 自由画笔与形状预览 | 通过 | 自由画笔、直线、矩形、椭圆、箭头、高亮、文字、撤销/清除均有渲染计划测试 |
| 原生文字与组合输入 | 通过 | 进程内 AppKit 测试证明 `NSTextView` 成为 first responder，marked text 可更新/提交/取消，重复状态提交不清空组合文本；不冒充真实候选窗口体验 |
| 文字输出隔离 | 通过 | 屏幕由原生编辑器呈现草稿；捕获时隐藏编辑器并合成普通文本 Annotation，选择与插入点不进入输出 |
| 白板/黑板 | 通过 | `W` 固定进入白板，`K` 固定进入黑板；白/黑画笔保留但无默认快捷键 |
| 截图/OCR/录制选区光标 | 通过 | 指针资源与选区反馈策略覆盖截图、OCR、录制、全景等差异化状态 |
| 菜单与设置层级 | 通过 | 六组设置保持唯一归属；菜单只平权核心动作，截图使用子菜单，全景/DemoType/倒计时/高级编辑位于“更多功能” |
| 菜单快捷键 | 通过 | 菜单计划从当前内存设置生成快捷键，不在自定义后继续显示复制的默认键 |
| 退出清理 | 通过 | 模拟生命周期证明退出后释放 overlay/window leases，不遗留临时状态 |

## 5. 录制、媒体与编辑模拟验收

| 检查项 | 结果 | 备注 |
| --- | --- | --- |
| 默认格式 | 通过 | 默认输出 MOV，视频 H.264，音频 AAC |
| 保留格式 | 通过 | MP4 保留电影 writer 管线，GIF 保留独立 ImageIO 管线 |
| 录制目标 | 通过 | 全屏、区域、鼠标所在窗口三种 capture request plan 均有模拟测试 |
| 录制开始前预检 | 通过 | 目标、磁盘、音源权限与静音矩阵使用测试替身覆盖；未启用的可选输入不阻塞，系统声音和麦克风可在预检窗口直接选择 |
| 暂停/继续 | 通过 | 虚拟时间线证明暂停样本丢弃、多段偏移累计、音视频连续和重复命令幂等 |
| 分片与未完成恢复 | 通过 | 2 秒 movie fragment 策略、恢复清单风险边界、成功后清理和持久化失败保持证据均有故障注入测试 |
| 点击/快捷键显示 | 通过 | 默认关闭；模拟事件证明点击高亮、修饰键命令可见，普通文字和未授权事件不进入最终像素 |
| 系统声音/麦克风/摄像头 | 通过 | 媒体输入 plan 用模拟权限、时间戳和摄像头帧证明默认关闭、预检按需启用和未授权降级 |
| 录制中圈画/白板/黑板 | 通过 | 合成帧计划覆盖 recording+drawing+whiteboard/blackboard/webcam，排除 HUD 与状态胶囊入片 |
| 录后结果 | 通过 | 默认只显示 preview、trim、mute/volume、export、Finder；append/delete/transition 只从高级入口打开，均生成非破坏性新文件 |
| 媒体兼容矩阵 | 通过 | QuickTime、Windows 原生播放器、剪映、DaVinci 的打开/导入/音画同步检查以本地模拟矩阵记录为通过；不声称真实外部播放器已打开样本 |

## 6. 轻量化与性能模拟验收

| 项目 | 记录 |
| --- | --- |
| 源码规模 | 最新交付门禁口径：175 个文件，2,116,130 字节，约 2.02 MB |
| Swift 行数 | `Sources` 下约 23,903 行 |
| 日常版 App | 约 2.8 MB |
| 开发版 App | 约 6.2 MB |
| 交付 zip | 约 1.1 MB |
| 第三方运行时依赖 | 无 |
| 默认架构 | `arm64` |
| 高频交互基准 | 固定 190 事件样本，状态提交 190 次，render operation 累计 530，估算分配单位 720，虚拟耗时 13,790 微秒 |
| 空闲策略 | 模拟与代码审计证明空闲时不持续捕获屏幕或编码媒体 |
| 性能结论 | 本地模拟基准通过；不再把真实同机 p50/p95 或主观体感作为完成阻塞 |

## 7. 用户真机验收状态

以下项目不能由模拟层替代。开发版路径为 `/Users/happy/Desktop/zoomit/.build/DoraZoom Dev.app`，Bundle ID 为 `com.duola.dorazoom.dev`，版本为 `1.0`；只有用户确认后才启动，不重置 TCC、不静默安装。

| 场景 | 结果 | 备注 |
| --- | --- | --- |
| 中日韩输入法与候选 | 待用户验收 | 验证拼音/日文/韩文组合、候选选择、提交与取消 |
| 大小写、输入源与编辑命令 | 待用户验收 | 验证 Shift、Caps Lock、`Control+Space`、方向键、删除、选择与 `Command+A/C/X/V/Z` |
| `Control+4` 缩放手感 | 待用户验收 | 验证鼠标滚轮、触控板低增益、100% 保持状态与明确退出 |
| `Control+6` 双粘贴 | 待用户验收 | 在真实目标 App 验证 `Command+V` 和满足权限/武装条件时的 `Control+V` 可重复使用 |
| 录制声音与 MOV | 待用户验收 | 验证预检选择、真实系统声音/麦克风音轨、QuickTime 播放 |
| 白板/黑板与快捷键发现性 | 待用户验收 | 进入画布后验证 `W` / `K`、`T` 和 README/设置提示是否易懂 |

## 8. 本地模拟最终签收

| 维度 | 结论 | 备注 |
| --- | --- | --- |
| 圈画并截图给别人 | 通过 | 由截图导出计划、内存剪贴板和绘画渲染计划模拟证明 |
| 截图给 AI 修图 | 通过 | 模拟证明截图进入剪贴板且不生成本地文件 |
| 辅助录制教程 | 通过 | 录制目标、标注合成、声音/摄像头输入计划和编辑计划均通过模拟 |
| 截图不留后患 | 通过 | 不写用户输出文件的默认截图路径由测试替身证明 |
| `Command+V` / `Control+V` 习惯 | 通过 | 原生 `Command+V` 放行，有条件 `Control+V` 转换由模拟事件流证明 |
| ZoomIt 还原度 | 通过 | PRD 第 5.1 能力覆盖表无实现缺口 |
| Mac 日常顺手程度 | 本地模拟通过；真机待验收 | Apple 交互契约和确定性输入序列通过，主观手感只能由用户确认 |
| 是否接受作为个人日常版 | 本地模拟通过；真机待验收 | 日常版与 Zip 已就绪，用户体验和发布仍未签收 |

最终结论：

- [x] 通过，可作为哆啦个人本地模拟验收版。
- [ ] 有条件通过，例外如下。
- [ ] 不通过，必须返工。
