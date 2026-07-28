# Goal Document: DoraZoom 个人版完整落地

> 产品事实源：[PRD.md](./PRD.md)
> 架构事实源：[ARCHITECTURE.md](./ARCHITECTURE.md)
> 上游锁定提交：`b03e43da91cd84eeb8f691fa65095e0304c3e660`

## Go / No-Go

- **Judgment**：Go
- **Reason**：用户已明确要求“全部改成本地模拟”。产品与架构决策已经明确，完成条件改为协议化平台边界、测试替身、确定性事件流、本地 writer 计划和非侵入产物元数据门禁；不再把真实 TCC、ScreenCaptureKit、全局输入、外部播放器或主观体感作为当前目标的完成阻塞。

## Target Outcome

以锁定提交的 Microsoft ZoomIt for Mac 官方源码为实现基础，交付可安装、可日常使用的 `DoraZoom.app`：

- 完整保留 PRD 第 5.1 节列出的 ZoomIt 能力，不以轻量化为由删减功能。
- 最大程度保持 Windows ZoomIt 12.11 的快捷键和操作语义，同时符合 macOS 的粘贴、权限、窗口和媒体习惯。
- `Control+1`、`Control+2`、截图、OCR、录制选择、绘画工具和白板/黑板切换均具有同步、明确的光标或状态反馈。
- 截图到剪贴板不产生本地文件，支持原生 `Command+V`；获得所需系统授权后，也支持有条件、可重复的 `Control+V`。
- 录制支持全屏、区域、鼠标所在窗口、系统声音、麦克风、摄像头和录制中圈画；默认输出 MOV/H.264/AAC，同时保留 MP4 与 GIF。
- 应用空闲时不持续捕获或编码，没有第三方运行时依赖，性能相对锁定上游基线不超过 PRD 允许的退化。
- 日常版与开发调试版身份稳定且隔离，不再因旧安装包或调试构建污染正式权限条目。

## Goal Definition

- **Type**：product + technical + quality + delivery
- **Boundary**：
  - 导入并保留锁定提交的官方 Mac 源码、MIT 许可证和必要归属。
  - 实现 PRD 的完整功能、交互、权限、媒体、性能与个人版安装要求。
  - 按架构文档建立组合会话状态、通道化反馈、粘贴兼容、录制输出策略和绘画快捷键策略。
  - 交付源码、自动化测试、个人版 App 构建物和一份合并后的验证记录。
- **Non-goals**：
  - 账号、云同步、团队空间、商业化、订阅和遥测。
  - 为了目录整齐而重写官方捕获、绘画、录制、编辑或全景算法。
  - 恢复已经删除的旧 InkLayer 实现，或把它与官方源码混合。
  - 引入 Electron、Tauri、FFmpeg、数据库、响应式框架或依赖注入框架。
  - 没有性能证据时引入 Metal 自研渲染器。
- **Deferred work**：
  - 自动更新。
  - 面向公众分发所需的 Developer ID、notarization 和发布站点。
  - 非当前个人机器需要的 Universal 构建，除非实际交付环境要求。
  - PRD 之外的新功能和视觉装饰。
- **Verification rule**：全部验收改为本地模拟执行，并由 `Scripts/verify-test-boundary.sh` 守住测试边界；`Scripts/phase7-preflight.sh`、`Scripts/verify-delivery.sh`、`Scripts/verify-acceptance-record.sh ACCEPTANCE.md` 全部通过即为当前目标完成。
- **Evidence source**：
  - `swift build`、`swift test`、官方 self-test。
  - 纯逻辑契约测试、模拟平台集成测试和确定性事件回放。
  - 虚拟时钟、确定性事件回放、模拟渲染计数、App 与安装包体积。
  - 模拟权限状态、内存剪贴板替身、模拟目标 App 事件结果和剪贴板变化记录。
  - QuickTime、目标 Windows 播放环境、剪映和 DaVinci Resolve 的本地媒体兼容矩阵。
  - `ACCEPTANCE.md` 本地模拟验收记录。
- **Pass criteria**：
  - PRD 第 14 节没有未解释的本地模拟失败项。
  - 所有自动化测试只使用模拟权限、模拟 Event Tap、内存剪贴板、模拟捕获/媒体 writer、虚拟时钟、确定性事件流和测试窗口；测试目录不得直接触碰真实 TCC、全局输入、真实剪贴板、ScreenCaptureKit 捕获、麦克风、摄像头或登录项，也不得用 `Process`/`NSTask`/系统命令绕过模拟边界，通过后官方已有能力没有逻辑回归。
  - DoraZoom 的本地模拟性能基准记录虚拟耗时、状态提交、render operation 和估算分配单位，不再要求真实同机 p50/p95。
  - 日常版使用 `com.duola.dorazoom`，开发调试版使用 `com.duola.dorazoom.dev`，两者权限条目互不污染。
  - `ACCEPTANCE.md` 最终结论选择“通过，可作为哆啦个人本地模拟验收版”。
- **Confidence note**：模拟层可以高置信度验证状态、错误分支、权限决策、快捷键策略、输出配置、媒体 writer 计划和产物身份；它仍不证明真实 macOS 权限弹窗、真实 Event Tap、硬件捕获、真实光标观感或第三方播放器行为。当前目标接受这个边界。
- **Judgment owner**：自动化测试、交付门禁和验收记录校验器负责当前目标完成判断。

## Current State

- 工作区当前保留 `.git`、DoraZoom 产品/架构/目标/验证文档，以及锁定提交 `b03e43da91cd84eeb8f691fa65095e0304c3e660` 的 Microsoft ZoomIt for Mac 官方源码。
- 旧 InkLayer 源码、测试、脚本和旧计划处于有意删除状态，不是待恢复资产；当前实现以官方源码为唯一代码基础。
- 当前 Git 分支为 `main`，历史基线为 `2cecac2`；没有配置 Git remote。
- Phase 1 与 Phase 2 已完成：官方源码已导入，开发 Bundle ID `com.duola.dorazoom.dev` 可构建，官方 self-test 和新增契约测试通过。
- Phase 3 已按模拟层收口：截图导出计划、导出执行器、原生 `Command+V` 放行、有条件 `Control+V` 事件转换、权限五态矩阵、权限说明/设置状态、区域选择生命周期和尺寸 HUD 均有模拟测试证据；真实系统验收不再是当前目标阻塞项。
- 产品与架构文档已经裁决 `W/K`、MOV 默认值、MP4/GIF 保留、窗口录制、组合状态、`Control+V` 权限时机和双 Bundle ID。
- Phase 4 已按模拟层完成：`Control+1` 静态缩放、`Control+2` 原比例绘画反馈、实时缩放/实时绘画输入路由、白板/黑板与白/黑画笔快捷键裁决、OCR/录制/全景差异化光标资源和高频交互基准均有测试证据；Phase 5 媒体兼容改为本地模拟矩阵验收。
- 当前验证快照：`Scripts/verify-delivery.sh` 通过；其内部复现自动化测试边界审计、`swift build`、110 项 `swift test`、官方 `ZoomItMacSelfTest`、依赖审计、开发版/日常版构建签名、zip 解包验签、归一化架构集合比较、体积统计和 `git diff --check`；详细证据见 `VALIDATION.md`。
- Phase 7 本地模拟验收记录已建立为 `ACCEPTANCE.md`；它只描述模拟测试、测试替身、产物元数据和非侵入门禁，不包含自动 TCC、全局输入、真实剪贴板、真实屏幕、麦克风、摄像头或登录项操作。
- 明确 first-run 重置 helper 是显式重置辅助工具，不是自动化测试；无显式确认时拒绝执行，日常版 TCC 重置还需要第二重确认。
- 不声称真实 TCC、真实全局 `Control+V`、真实目标应用粘贴、真实光标观感、真实录屏/音频/摄像头和媒体播放器兼容通过；这些已移出当前目标，未来如需分发再单独验收。
- 当前最大风险已从“导入官方基线”转为：模拟契约是否足够覆盖 ZoomIt 体验、媒体输出策略和正式/调试身份隔离。
- macOS 没有与 iOS Simulator 等价的桌面 App Simulator；本计划中的“模拟测试”明确指进程内测试替身、确定性事件回放和可选的隔离测试窗口，不把宿主 Mac API 调用或虚拟机结果冒充为硬件兼容证明。

## Plan Rewrite Notes

| Existing item | Decision | Reason |
| --- | --- | --- |
| 所有纯逻辑契约测试 | keep | 本来就不依赖真实平台，继续全部走模拟 |
| Phase 1 改造前性能基线 | rewrite | 先保存官方基线构建和模拟基准；真实同机对照移出当前目标 |
| Phase 3 真实 TCC/Event Tap 实测 | rewrite | 改为权限矩阵和事件流模拟；不再做开发身份/日常身份真实授权验收 |
| Phase 4 光标与输入体验外部验收 | rewrite | 改为快照、热点几何、资源选择和虚拟交互基准 |
| Phase 5 媒体兼容矩阵 | rewrite | 模拟 writer 验证配置与状态；QuickTime、Windows、剪映和 DaVinci 改为本地媒体矩阵 |
| Phase 6 完整功能回归 | rewrite | 所有自动回归经模拟平台服务执行，不访问真实屏幕、麦克风、摄像头或全局键盘 |
| Phase 7 签名、安装、权限、性能与媒体 | rewrite | 签名和包体保留为本地元数据门禁；安装、权限、性能和媒体改为本地模拟验收 |

## Drift Diagnosis

- **Goal drift**：没有；目标仍是完整、轻量且可日常使用的 DoraZoom。
- **Phase drift**：原计划把部分真实平台验证分散在 Phase 1、3、4、5；现全部移出当前目标，Phase 7 只保留本地模拟验收。
- **Validation drift**：若把测试替身通过写成“真实权限/录制/播放器已通过”，属于虚假验证；新计划明确写成 local-simulation acceptance。
- **Compatibility drift**：不为模拟器建立一套生产兼容分支；生产代码只依赖协议，模拟实现仅进入测试 target。
- **Cleanup drift**：无；没有因测试策略变化恢复旧实现或增加无关基础设施。

## Priority Rationale

- 先恢复可重复的官方基线，才能证明后续变化是 DoraZoom 改造造成的，也才能建立性能对照。
- 在 UI 接线之前先用测试锁定组合状态、反馈通道和媒体/快捷键策略，避免实现过程中重新制造单一互斥状态机。
- `Control+V` 涉及系统权限和全局输入，是最可能使产品方案失效的外部风险，因此当前只用完整权限矩阵与事件流模拟验收。
- 光标、缩放、绘画和白板是日常最高频体验，在粘贴可行性证明后优先完成。
- 录制与编辑依赖前面的并存状态和反馈通道，必须后置，但不能留到最终阶段才发现 MOV/GIF 或音画同步问题。
- 完整功能对照与发布验收分开：当前先证明功能齐全、产物身份稳定和模拟契约完整。
- 模拟测试覆盖所有当前验收路径；真实系统事实不再作为本目标完成条件。

## Assumptions and Open Decisions

| Item | Status | Impact | Owner / Next step |
| --- | --- | --- | --- |
| 锁定上游提交仍可获取，且内容与架构证据一致 | assumed | 决定能否建立官方实现基线 | Phase 1 获取并核对 tree；不一致则停止 |
| 旧 InkLayer 不再使用 | confirmed | 防止两套实现和重复复杂度 | 全阶段禁止恢复或复制旧实现 |
| 产品功能、快捷键和交互范围以 PRD 为准 | confirmed | 防止实现自行改需求 | 发现缺口时停止并先更新 PRD |
| AppKit-first、单核心模块、零第三方运行时依赖 | confirmed | 控制包体、延迟和上游合并成本 | 架构审查与依赖清单验证 |
| 所有自动化测试走模拟层 | confirmed | 防止测试修改真实权限、剪贴板、屏幕、音频或全局输入，也防止测试用 shell/process 逃逸绕过模拟层 | 每个系统边界必须先有协议和测试替身；`Scripts/verify-test-boundary.sh` 作为交付门禁入口 |
| macOS 没有桌面 App 官方 Simulator | confirmed | “全部走模拟器”不能被理解为 iOS Simulator | 使用进程内模拟；Phase 7 改为本地模拟验收 |
| 可用的稳定代码签名身份 | confirmed | 影响本地产物身份元数据 | 由交付门禁读取并验证，不再阻塞真实安装验收 |
| 目标 Mac 机型、CPU 架构、刷新率和 macOS 小版本 | unresolved | 决定性能基线条件 | Phase 1 自动记录 |
| listen/post event access 在目标系统上的设置入口和重启要求 | deferred | 决定真实 `Control+V` 首次授权体验 | 当前只做 Phase 3 全矩阵模拟；真实行为另开目标 |
| 目标 Windows 播放环境、剪映和 DaVinci Resolve 版本 | unresolved | 决定 MOV 兼容验收范围 | Phase 5 前由“哆啦”确认实际使用版本 |
| 是否需要 Universal 构建 | assumed no | 影响包体和构建时间 | 仅当实际第二种 CPU 架构需要时启用 |
| 公网下载、notarization 与自动更新 | deferred | 不影响本机个人版核心目标 | 作为独立交付目标另行决策 |

## Phases

### Phase 1：恢复官方基线并建立可重复构建

- **Purpose**：把锁定的官方源码变成可编译的唯一实现起点，保存未改造构建，并在任何功能改造前记录可重复的模拟基准。
- **Entry condition**：`PRD.md`、`ARCHITECTURE.md`、`GOAL.md` 均存在，旧 InkLayer 删除状态已确认保留。
- **Phase rules**：
  - 只导入提交 `b03e43da91cd84eeb8f691fa65095e0304c3e660`，不跟随上游最新分支。
  - 保留上游目录、MIT 许可证和归属；不恢复旧 InkLayer。
  - 除安全的开发 Bundle ID 适配和构建所需修正外，不改变产品行为。
  - 不安装或运行使用 `com.duola.dorazoom` 的调试构建。
  - 自动基准只使用固定事件流、虚拟时钟和测试窗口，不请求 TCC、不监听全局输入、不打开真实捕获设备。
  - 任何与架构证据不符的上游结构都必须先停下并更新文档。
- **Todos**：
  - [x] 获取并核对锁定提交的官方源码树。
    - **Surface**：仓库源码、许可证、Package 清单。
    - **Proof**：记录上游 commit、tree hash、导入文件清单；MIT 许可证存在。
    - **Depends on**：无。
  - [x] 建立开发构建身份 `com.duola.dorazoom.dev`，不占用日常版权限条目。
    - **Surface**：App Bundle 配置、Info.plist、签名配置。
    - **Proof**：构建产物的 `CFBundleIdentifier` 检查结果。
    - **Depends on**：官方源码导入。
  - [x] 构建官方基线并运行官方 self-test。
    - **Surface**：Swift Package、官方测试入口。
    - **Proof**：`swift build` 与官方 self-test 的退出码和输出。
    - **Depends on**：源码与开发身份就绪。
  - [x] 保存未改造基线构建并记录模拟基准。
    - **Surface**：`VALIDATION.md`。
    - **Proof**：基线 commit、构建命令、固定事件样本、虚拟时钟结果、源码量、App 体积和基线产物位置均有记录；真实延迟/CPU/RSS 明确标记为 Phase 7 待验收。
    - **Depends on**：基线可构建。
  - [x] 读取可用代码签名身份，不创建、不删除、不重置信任设置。
    - **Surface**：本机签名环境。
    - **Proof**：只记录可用/不可用与身份类型，不写出私钥或敏感材料。
    - **Depends on**：无。
- **Exit proof**：锁定源码可重复构建并通过官方 self-test；未改造产物和模拟基准已经保存；开发 Bundle ID 与日常版隔离。Phase 1 证据见 `VALIDATION.md`。
- **Stop condition**：锁定提交不可获取、许可证缺失、官方源码不能在目标 macOS 构建、导入内容与已审架构明显不符，或需要覆盖用户现有权限/签名状态。

### Phase 2：以测试锁定状态与策略契约

- **Purpose**：在接入真实窗口和媒体管线前，证明架构能表达所有并存状态并正确隔离生命周期。
- **Entry condition**：Phase 1 通过，官方测试基线可重复。
- **Phase rules**：
  - 使用严格 RED → GREEN → REFACTOR；每项实现前必须先出现因目标行为缺失而失败的测试。
  - 本阶段只建立领域类型、纯逻辑策略、平台协议和测试替身，不改变用户可见行为。
  - `AppSessionState` 只能从权威所有者组装，不能成为第二份可写业务状态。
  - 权限、Event Tap、剪贴板、捕获、媒体 writer、时钟、文件选择与窗口反馈均先定义可替换协议；自动测试不得直接调用真实平台副作用。
  - 不为测试方便引入第三方状态或测试框架。
- **Todos**：
  - [x] 锁定组合会话与呈现快照契约。
    - **Surface**：`AppSessionState`、`InteractionPresentationSnapshot`、相关测试。
    - **Proof**：`recording+drawing`、`recording+whiteboard`、`recording+drawing+webcam` 和互斥选区测试通过。
    - **Depends on**：Phase 1。
  - [x] 锁定通道化 feedback lease。
    - **Surface**：`FeedbackChannel`、`InteractionFeedback`、lease 测试。
    - **Proof**：跨通道互不清理、同通道新 lease 覆盖旧 lease、迟到和重复 `end()` 幂等测试通过。
    - **Depends on**：组合会话契约。
  - [x] 锁定录制目标与输出策略。
    - **Surface**：`RecordingTarget`、`RecordingOutputStrategy`、`MovieRecordingProfile`。
    - **Proof**：全屏/区域/窗口目标可表达；MOV/MP4 进入电影策略，GIF 进入独立策略；容器、扩展名和保存类型一致。
    - **Depends on**：Phase 1。
  - [x] 锁定绘画快捷键策略。
    - **Surface**：`DrawingShortcutPolicy`。
    - **Proof**：`W/K` 映射白板/黑板，白色/黑色画笔存在且默认键为 `nil`。
    - **Depends on**：Phase 1。
  - [x] 锁定粘贴兼容状态机与权限协议。
    - **Surface**：`PasteCompatibilityService`、`PermissionService` 扩展、测试替身。
    - **Proof**：未授权不武装、截图 changeCount 武装、重复粘贴不解除、剪贴板变化解除、非精确 `Control+V` 放行、合成事件不递归的测试通过。
    - **Depends on**：Phase 1。
- **Exit proof**：新增契约测试全部通过，官方测试仍通过，用户可见功能尚未被改动。Phase 2 证据见 `VALIDATION.md`。
- **Stop condition**：测试要求第二份权威状态、单一全局 session ID、跨通道清理或与 PRD 冲突的快捷键/格式语义。

### Phase 3：完成截图到双粘贴纵向切片

- **Purpose**：通过完整模拟矩阵证明截图不落盘、`Command+V` 原生路径和有条件 `Control+V` 的业务决策正确，并把真实平台适配器编译接通。
- **Entry condition**：Phase 2 的粘贴、权限和 feedback 契约通过。
- **Phase rules**：
  - `Command+V` 永不由 DoraZoom 接管。
  - 未同时获得 listen/post event access 时不创建 active Event Tap、不吞键。
  - 权限说明发生在首次成功截图之后、系统请求之前；不在首次启动集中申请。
  - 本阶段不请求真实 TCC、不创建真实 Event Tap、不改写真实系统剪贴板；全部自动测试走模拟服务。
  - 截图到剪贴板路径不得创建临时或永久图片文件。
- **Todos**：
  - [x] 接通 `Control+6` 区域截图、十字光标、尺寸反馈和剪贴板写入。
    - **Surface**：Snip、Pasteboard 协议、pointer/HUD feedback。
    - **Proof**：模拟选区图片进入内存剪贴板；取消后虚拟窗口集合为空；模拟文件系统没有新增图片。
    - **Depends on**：Phase 2 feedback 契约。
  - [x] 实现首次截图后的权限说明、listen/post 请求与设置状态呈现。
    - **Surface**：权限 UI、`PermissionService`、设置状态。
    - **Proof**：未决定/允许/拒绝/部分授权/授权后重启五种模拟状态均得到正确请求动作；拒绝和部分授权时不拦截按键、不安装 active Event Tap；设置状态和说明文案有模拟契约覆盖。
    - **Depends on**：截图成功路径。
  - [x] 接通有条件的 `Control+V` 转换。
    - **Surface**：Event Tap 协议、事件标记、pasteboard changeCount。
    - **Proof**：确定性键盘事件流证明同一截图可重复 `Control+V`、复制其他内容后立即放行、其他 Control 组合不受影响、合成事件不递归。
    - **Depends on**：listen/post 权限矩阵通过。
  - [x] 验证原生 `Command+V` 路径。
    - **Surface**：Pasteboard 与目标应用协议。
    - **Proof**：模拟目标应用证明兼容模式关闭、未授权和已授权三种状态均不接管 `Command+V`。
    - **Depends on**：截图剪贴板路径。
  - [x] 补齐模拟测试证据并登记本地模拟验收项。
    - **Surface**：测试、`VALIDATION.md`。
    - **Proof**：权限矩阵、事件回放、内存剪贴板和模拟文件系统日志齐全；真实 TCC/目标应用项目移出当前目标。
    - **Depends on**：本阶段全部行为。
- **Exit proof**：所有截图与双粘贴自动化场景均在模拟层通过，生产平台适配器可以编译，但尚不宣称真实 TCC 或目标应用已经通过。
- **Stop condition**：生产实现无法隔离 Core Graphics/剪贴板副作用、必须永久全局重映射、必须吞掉未授权按键，或模拟层无法覆盖权限与事件组合。

### Phase 4：完成 Zoom、绘画、白板和统一反馈

- **Purpose**：解决当前最直接的体验问题，使高频模式像 ZoomIt 一样进入即有状态、操作跟手、退出无残留。
- **Entry condition**：Phase 3 通过，通道化反馈已通过测试窗口和事件回放验证。
- **Phase rules**：
  - 光标与功能状态在同一呈现快照提交，不允许功能启动后仍显示普通箭头。
  - pointer、HUD、recording status、menu bar、tool palette 五个通道互不误清理。
  - 不用动画延迟光标、画笔、形状预览或选区跟随。
  - `W/K` 只表示白板/黑板；白色/黑色画笔留在颜色面板和工具条。
  - 反馈窗口必须按捕获策略明确进入或排除，不依赖偶然窗口层级。
  - 自动测试只向虚拟输入源发送事件，并检查呈现快照、测试窗口树和渲染结果；不注册全局快捷键或替换宿主光标。
- **Todos**：
  - [x] 接通 `Control+1` 静态缩放与对应光标/HUD。
    - **Surface**：ModeCoordinator、Zoom、pointer/HUD。
    - **Proof**：事件回放后的首个呈现快照包含缩放状态；虚拟坐标锚定鼠标；退出后窗口与反馈资源集合为空。
    - **Depends on**：Phase 2 状态契约。
  - [x] 接通 `Control+2` 原比例绘画与完整工具反馈。
    - **Surface**：Canvas、Annotation、pointer、tool palette。
    - **Proof**：固定输入轨迹的测试渲染证明画笔、直线、矩形、椭圆、箭头、高亮、文字、颜色、粗细、撤销和清除逐项通过。
    - **Depends on**：feedback 实现。
  - [x] 接通实时缩放、实时绘画和底层应用交互。
    - **Surface**：LiveZoom、LiveDraw、事件路由。
    - **Proof**：模拟策略证明 live zoom 未绘画/未选区时鼠标路由穿透到底层应用，绘画/选区时由 overlay 捕获；`Control+1` 与 `Control+2` 在 live zoom 内只切换实时绘画，不退出实时缩放，不改变普通命令处理。
    - **Depends on**：Zoom 与绘画基础。
  - [x] 接通白板/黑板与白色/黑色画笔。
    - **Surface**：DrawingShortcutPolicy、CanvasBackground、颜色面板。
    - **Proof**：模拟策略证明 `W/K` 只映射白板/黑板，`Shift/Ctrl+W/K` 不成为白/黑墨水快捷键；白色/黑色画笔仍存在但无默认键；白板/黑板进入 AnnotationController 状态，切换时保留已有标注，并声明进入截图/录制合成。
    - **Depends on**：绘画基础。
  - [x] 完成 OCR、录制选择和全景选择的差异化光标资源。
    - **Surface**：pointer feedback、Retina 资源、热点定义。
    - **Proof**：模拟资源目录证明截图、OCR、录制选区和全景选区使用不同形状与颜色、同一操作热点和 1x/2x 资源声明；会话快照把 OCR/录制/全景映射到对应 pointer purpose，Snip/Recording/Panorama 入口持有对应资源元数据。
    - **Depends on**：统一反馈。
  - [x] 测量高频交互的确定性模拟基准。
    - **Surface**：虚拟时钟、固定事件流、`VALIDATION.md`。
    - **Proof**：固定 190 事件样本两次运行报告完全一致；状态提交 190 次，render operation 累计 530，估算分配单位 720，虚拟耗时 13,790 微秒；报告明确不访问 ScreenCapture、全局键盘、剪贴板、麦克风或摄像头，真实 p50/p95 留给 Phase 7。
    - **Depends on**：本阶段功能。
- **Exit proof**：`Control+1`、`Control+2`、实时缩放/实时绘画路由、形状绘画、`W/K`、白/黑画笔、差异化 pointer resource、撤销、退出和高频交互基准的模拟事件与渲染/策略测试全部通过；真实观感尚不宣称通过。
- **Stop condition**：实现需要复制官方渲染引擎、产生第二套绘画状态、无法从宿主全局输入中隔离自动测试，或模拟基准出现未解释退化。

### Phase 5：完成录制、媒体输出和编辑纵向切片

- **Purpose**：通过模拟捕获与 writer 证明录制状态、输出配置和编辑决策正确，并完成真实平台适配器的编译接线。
- **Entry condition**：Phase 4 的组合状态、feedback 通道和绘画覆盖层稳定。
- **Phase rules**：
  - 默认 MOV/H.264/AAC；MP4 与 GIF 都必须保留。
  - MOV/MP4 共用 AVFoundation 电影管线，GIF 使用 ImageIO 图像序列管线；不引入 FFmpeg。
  - 全屏、区域、鼠标所在窗口是独立录制目标，不用格式枚举代替目标枚举。
  - 录制状态必须持续存在，但状态胶囊和临时工具条不得进入成片。
  - 停止、取消和迟到回调按能力域 session ID 幂等处理。
  - 自动测试不访问真实屏幕、系统音频、麦克风或摄像头；只消费固定视频帧、音频样本和虚拟时钟。
- **Todos**：
  - [x] 接通全屏、区域和鼠标所在窗口录制。
    - **Surface**：RecordingController、ScreenCaptureKit、RecordingTarget。
    - **Proof**：三种模拟目标分别生成正确 capture request；全屏目标生成 display filter 与整屏 sourceRect，区域目标生成 display filter 与固定区域像素尺寸，窗口目标生成 window filter 且窗口 ID 匹配 fixture；生产 full/region 录制路径已消费同一 request plan，window filter 分支编译接通，真实窗口选择体验仍留后续 UI/Phase 7 验收。
    - **Depends on**：Phase 2 录制目标契约。
  - [x] 实现 MOV 默认与 MP4 保留。
    - **Surface**：AVAssetWriter、临时文件、保存面板、编辑器导出。
    - **Proof**：模拟 profile 证明默认格式为 MOV/H.264/AAC，AVAssetWriter fileType 为 `.mov`，保存面板类型为 `.quickTimeMovie`，音频为 48 kHz/128 kbps/双声道；MP4 仍保留在电影管线；生产录制引擎、fallback writer、临时文件扩展名、保存面板和编辑器导出均消费同一 `MovieRecordingProfile`。
    - **Depends on**：RecordingOutputStrategy。
  - [x] 保留 GIF 输出。
    - **Surface**：ImageIO/Core Graphics、导出 UI。
    - **Proof**：GIF profile 固定为 `.gif` 保存类型、无限循环和 8-bit 颜色深度；GIF writer fixture 收到正确帧序和时长，且电影 writer 调用次数为零。自动证据只覆盖模拟 writer 计划，真实 GIF 文件兼容仍留 Phase 7。
    - **Depends on**：RecordingOutputStrategy。
  - [x] 接通系统声音、麦克风和摄像头画中画。
    - **Surface**：音频捕获、AVFoundation、Webcam overlay、权限。
    - **Proof**：模拟权限、音视频时间戳和摄像头帧证明开关默认关闭；启用后 system audio、microphone、webcam 按授权进入同一 session 时间线；未决定的麦克风/摄像头权限只登记对应请求、不启用该输入；生产 webcam 初始画中画位置复用同一 planner。真实硬件、TCC 和声音/摄像头采集仍留 Phase 7。
    - **Depends on**：电影录制基础。
  - [x] 验证录制中绘画、白板和 feedback 隔离。
    - **Surface**：AppSessionState、Annotation overlay、feedback channel。
    - **Proof**：模拟合成帧计划覆盖 `recording+drawing+whiteboard+webcam`、`recording+drawing+blackboard`；计划明确排除 feedback HUD 和 recording status capsule；结束 pointer lease 不清除 recordingStatus feedback 或 `RecordingState`。真实像素合成与录屏观感仍留 Phase 7。
    - **Depends on**：Phase 4、录制基础。
  - [x] 恢复并验证录制后编辑器。
    - **Surface**：预览、裁剪、拼接、淡入淡出、静音、音量和导出。
    - **Proof**：模拟编辑决策图证明 preview、trim、append、fade transition、mute、volume 和 MOV export 都生成非破坏性新文件计划；无源文件删除/移动动作；无效 trim 被拒绝并保留原时间线。真实 AVFoundation 导出与播放器兼容仍留 Phase 7。
    - **Depends on**：电影录制基础。
  - [x] 建立媒体兼容验收矩阵。
    - **Surface**：QuickTime、目标 Windows 环境、剪映、DaVinci Resolve。
    - **Proof**：目标环境包含 QuickTime Player、Windows 原生播放环境、剪映和 DaVinci Resolve；版本策略为 Phase 7 记录实际安装版本；样本包含默认 MOV、带音频/摄像头/标注的 MOV、保留 MP4 和保留 GIF；检查项覆盖打开/导入、视频播放、预期音频、音画同步、时长匹配和失败原因记录；所有结果明确为 Phase 7 待验收。
    - **Depends on**：输出配置稳定。
- **Exit proof**：三种录制目标、MOV/MP4/GIF、声音、摄像头、圈画/白板并存和编辑器的模拟测试全部通过；真实文件兼容尚不宣称通过。
- **Stop condition**：MOV 配置不能被所有电影步骤一致消费、GIF 被迫依赖第三方运行时、录制与绘画仍被错误建模为互斥，或媒体系统边界无法替换为测试 double。

### Phase 6：补齐完整 ZoomIt 能力与管理面

- **Purpose**：关闭“核心功能可用但不是完整复刻”的缺口，形成 PRD 第 5.1 节逐项可追踪的功能闭环。
- **Entry condition**：Phase 5 核心纵向切片通过。
- **Phase rules**：
  - 使用 PRD 第 5.1 节和 Windows ZoomIt 12.11 行为对照逐项关闭，不按文件数量判断完成。
  - 官方已有算法只接入新的状态与反馈边界，不无故重写。
  - 设置窗口使用 AppKit 原生控件；不引入 SwiftUI 第二套状态。
  - 快捷键全部可配置，但默认值必须保持 PRD。
  - 自动回归统一注入模拟 Vision、文件面板、登录项、显示器、剪贴板、时钟和全局快捷键服务。
- **Todos**：
  - [x] 完成区域截图到文件、OCR、当前视口复制/保存。
    - **Surface**：Snip、Vision、保存面板、剪贴板。
    - **Proof**：固定图片与 OCR fixture、模拟文件面板和内存剪贴板覆盖内容、取消、错误与路径分支。
    - **Current evidence**：`Phase6ImageExportSimulationTests` 使用固定图片、模拟目录保存、模拟保存面板接受/取消/失败、内存图片剪贴板、OCR 非空文本与空结果蜂鸣分支；覆盖表已把 `currentViewportCopyAndSave`、`regionSnipToFile`、`regionOCRToClipboard` 标为 `localSimulationAccepted`。
    - **Depends on**：Phase 3。
  - [x] 完成倒计时与 DemoType。
    - **Surface**：Timer、DemoType、状态 HUD、快捷键。
    - **Proof**：虚拟时钟和事件回放覆盖启动、上一段、退出、计时结束和反馈捕获策略。
    - **Current evidence**：`Phase6TimerDemoTypeSimulationTests` 覆盖倒计时启动、虚拟时间推进、计时结束、蜂鸣/声音意图、用户退出、idle-sleep 生命周期和“不进入录制”的反馈隔离；同时覆盖 DemoType 启动、上一段、重新播放、`[paste]` 剪贴板意图、`Command+V` 意图、`[enter]`、退出和不触碰真实键盘/剪贴板/目标 App。
    - **Depends on**：Phase 4 feedback。
  - [x] 完成全景截图到剪贴板和文件。
    - **Surface**：Panorama、进度、取消、输出。
    - **Proof**：固定帧序列覆盖两种输出、长任务取消、过期回调和虚拟窗口无残留。
    - **Current evidence**：`Phase6PanoramaSimulationTests` 使用固定帧序列覆盖捕获进度、拼接进度、复制到模拟剪贴板、写入模拟文件、取消流程、取消后的过期 append/finish 回调忽略以及虚拟窗口释放；覆盖表已把 `panoramaClipboardOrFile` 标为 `localSimulationAccepted`。
    - **Depends on**：Phase 4 feedback。
  - [x] 完成设置、快捷键录入和权限管理。
    - **Surface**：AppKit 设置窗口、UserDefaults、权限页。
    - **Proof**：测试窗口快照、内存配置和模拟权限证明设置分类、冲突提示、重启持久化语义和状态映射正确。
    - **Current evidence**：`Phase6SettingsPermissionsSimulationTests` 覆盖 Zoom/Draw/Text/Snip/Record/Webcam/Panorama/Launch 设置分类、内存配置重启持久化、默认快捷键派生、冲突阻止保存，以及屏幕录制、listen/post input monitoring、麦克风、摄像头权限页状态映射；全程 `.simulatedOnly`，不触碰真实 TCC、不打开系统设置、不注册真实全局快捷键。
    - **Depends on**：前述所有策略已稳定。
  - [x] 完成单实例、菜单栏状态和登录时启动。
    - **Surface**：应用生命周期、菜单栏、ServiceManagement。
    - **Proof**：模拟进程锁、菜单状态和登录项服务覆盖重复启动、状态更新与启停。
    - **Current evidence**：`Phase6AppLifecycleSimulationTests` 覆盖虚拟单实例锁、重复启动触发设置窗口通知意图、释放锁、菜单栏 idle/active/recording 状态与菜单项、登录项 register/unregister 意图、pending approval 迁移和非 `.app` bundle 提示；全程 `.simulatedOnly`，不碰真实文件锁、DistributedNotificationCenter、NSStatusItem 或 ServiceManagement。
    - **Depends on**：设置与应用身份。
  - [x] 建立完整功能对照表并逐项回归。
    - **Surface**：`VALIDATION.md`、模拟自动化测试。
    - **Proof**：PRD 第 5.1 节每项均有实现位置和本地模拟测试证据；真实系统事实明确移出当前目标，不能写成已真实通过。
    - **Current evidence**：已建立 `ZoomItFeatureCoverageMap.phase6Default`，覆盖 PRD 第 5.1 节 30 项能力与 DoraZoom Mac 适配项（`Control+V` 兼容、光标反馈）；测试明确保持 `.simulatedOnly`；`map.gaps == []`；能力状态统一为 `localSimulationAccepted`，需要媒体说明的能力包含 `.mediaCompatibilityMatrix`。
    - **Depends on**：本阶段全部任务。
- **Exit proof**：完整功能对照表无实现缺口，所有自动回归在模拟平台通过，本地模拟验收项均已登记到 Phase 7。
- **Stop condition**：发现 PRD 与 Windows/官方 Mac 行为存在未裁决冲突，或完成某项功能需要引入 PRD 之外的新产品决策。

### Phase 7：本地模拟验收与交付

- **Purpose**：关闭全部本地模拟自动化门禁，用测试替身、确定性事件流、本地 writer 计划和产物元数据完成验收，最终收敛为轻量、可构建、可本地模拟确认的个人版本。
- **Entry condition**：Phase 6 完整功能对照通过，签名身份与目标交付架构已确认。
- **Phase rules**：
  - 日常版只能使用 `com.duola.dorazoom`；开发版只能使用 `com.duola.dorazoom.dev`。
  - 不重置日常版 TCC、不删除旧安装、不创建或信任新证书。
  - 轻量化通过无重复引擎、无第三方运行时、无空闲捕获/编码和实测数据证明，不设武断的 MB 目标。
  - 不以压缩体积为由删除功能、降低默认画质或破坏媒体兼容。
  - 所有验收仍然使用模拟层；不运行会改变真实系统状态的自动脚本。
  - 不声称 TCC、全局输入、ScreenCaptureKit、真实性能或第三方媒体兼容已经在真实系统通过；当前目标只要求本地模拟验收通过。
- **Todos**：
  - [x] 完成全量自动化门禁。
    - **Surface**：Swift build、tests、官方 self-test、静态检查。
    - **Proof**：所有模拟测试、构建和静态检查命令零退出；无被跳过的必需测试；`git diff --check` 通过。
    - **Current evidence**：`Scripts/verify-delivery.sh` 通过；脚本内 first-run reset helper 安全门禁通过，`swift build` 通过，`swift test` 110 项通过，`.build/debug/ZoomItMacSelfTest` 通过，release 日常版构建无编译警告通过，`git diff --check` 通过。
    - **Depends on**：Phase 6。
  - [x] 完成本地模拟性能基准。
    - **Surface**：虚拟时钟、确定性事件样本、状态提交、render operation、估算分配单位。
    - **Proof**：固定 190 事件样本结果已记录，真实同机 p50/p95 不再作为当前目标完成阻塞。
    - **Depends on**：Phase 1 基线、最终实现。
  - [x] 核对依赖、源码量和产物体积。
    - **Surface**：SwiftPM 依赖图、源码统计、App/压缩包。
    - **Proof**：无第三方运行时依赖；源码量、可执行文件、`.app` 和交付包 MB 已记录并解释主要构成。
    - **Current evidence**：最近一次 `Scripts/phase7-preflight.sh` 快照确认自动化测试边界审计通过，验收记录校验器自测通过，验收记录草稿生成器自测通过，安装面审计器自测通过，Phase 7 preflight 自测通过，`.build` 根级 `.app` 白名单审计通过，first-run reset helper 拒绝路径通过，`swift package show-dependencies --format text` 输出 `No external dependencies found`；`Scripts/build-app.sh` 会在构建/签名前拒绝非法 Bundle ID、路径型或非 `.app` App 名、会破坏 plist 的 display name；默认 release 构建和 dev/daily/zip 解包交付门禁均以 `arm64` 为轻量架构默认值，并按归一化架构集合比较，未显式设置 `ZOOMIT_ARCHS` 时交付门禁不向 `build-app.sh` 传空架构变量，Universal 只在显式非空 `ZOOMIT_ARCHS` 时启用；排除 `.git/.build` 和无关 `website` 共 123 个文件、1,263,706 字节，约 1.21 MB；`Sources` 下 Swift 17,918 行；dev app 约 4.9 MB，日常 release app 约 2.1 MB，交付 zip 约 933 KB；交付门禁只接受 `.build/DoraZoom Dev.app`、`.build/DoraZoom.app` 和 `.build/DoraZoom.zip`，任意其他根级 `.build/*.app` 都失败，并拒绝残留或新产生的 `.build/ZoomIt.zip`；dev/daily bundle 版本元数据均为 `1.0`，解包后的 zip app 元数据、签名身份与 entitlements 也被复核；`ACCEPTANCE.md` 本地模拟验收记录校验通过；详见 `VALIDATION.md`。
    - **Depends on**：最终构建。
  - [x] 构建并签名开发版与日常版。
    - **Surface**：Bundle、Info.plist、entitlements、签名。
    - **Proof**：`codesign` 验证通过；两个 Bundle ID 正确；日常版没有开发身份残留。
    - **Current evidence**：`Scripts/verify-delivery.sh` 构建并核对开发版 `.build/DoraZoom Dev.app` 为 `com.duola.dorazoom.dev` / `DoraZoom (Dev)`，日常版 `.build/DoraZoom.app` 为 `com.duola.dorazoom` / `DoraZoom`；`CFBundleName` 分别为 `DoraZoom (Dev)` / `DoraZoom`，两者 `CFBundleExecutable=CFBundleIconFile=DoraZoom`，且 `CFBundleShortVersionString=CFBundleVersion=1.0`；源码资源、开发版/日常版资源目录和 zip 解包 app 均拒绝旧 `ZoomIt*.png` 图标资源名；开发版 codesign `Identifier=com.duola.dorazoom.dev`、`Signature=adhoc`、`TeamIdentifier=not set`，日常版使用本机 Apple Development 身份签名，日常版与 zip 解包 app 的 codesign `Identifier=com.duola.dorazoom`、Authority 非空、TeamIdentifier 非空，启用 hardened runtime 且 `codesign --verify --deep --strict` 通过；交付 zip 解包后重新核对日常版身份、版本、菜单栏模式、最低系统版本、架构、entitlements 和 hardened runtime 并再次验签通过，且本地日常版 app、zip 与解包 app 均不允许携带 `com.apple.quarantine`；未安装到 `/Applications`，未触发 TCC。
    - **Depends on**：稳定签名身份。
  - [x] 完成权限、安装与升级的本地模拟验收。
    - **Surface**：Bundle ID、签名元数据、权限状态矩阵、设置入口动作计划。
    - **Proof**：模拟权限页、bundle/signature 元数据和 reset helper 拒绝路径均通过；不安装到 `/Applications`。
    - **Depends on**：签名构建。
  - [x] 执行最小平台边界模拟验收。
    - **Surface**：模拟 TCC、模拟 Event Tap、内存剪贴板、模拟捕获、模拟音频/摄像头、测试窗口。
    - **Proof**：`Control+1`、`Control+2`、`W/K`、`Control+6`、`Command+V`、有条件 `Control+V`、三种录制目标、声音和摄像头均由模拟测试覆盖。
    - **Depends on**：模拟门禁、签名构建。
  - [x] 完成本地媒体兼容矩阵。
    - **Surface**：QuickTime、目标 Windows 播放环境、剪映、DaVinci Resolve 的模拟兼容矩阵。
    - **Proof**：MOV/MP4/GIF 样本、打开/导入、音画同步、时长和失败原因字段均由本地矩阵记录为模拟通过。
    - **Depends on**：录制 writer 计划。
  - [x] 执行 PRD 第 14 节本地模拟清单。
    - **Surface**：功能、白板、粘贴、光标、录制、权限、性能、视觉。
    - **Proof**：每一项有本地模拟证据或明确边界说明；不存在空白跳过。
    - **Depends on**：全部前置任务。
  - [x] 交付 Phase 7 本地模拟验收记录。
    - **Surface**：`ACCEPTANCE.md`、README 验收入口。
    - **Proof**：记录区分本地模拟证据与未声明的真实系统事实；覆盖构建、TCC 模拟、事件流、内存剪贴板、光标、截图粘贴、录制、媒体矩阵、性能和最终签收。
    - **Depends on**：Phase 7 边界确认。
- **Exit proof**：本地模拟自动化、依赖、签名元数据、产物身份、媒体矩阵、性能基准和 `ACCEPTANCE.md` 记录校验全部通过。
- **Stop condition**：模拟门禁失败、验收记录出现空白、功能对照有缺口，或实现需要触碰真实 TCC/全局输入/剪贴板/屏幕/音频/摄像头才能证明。

## Dry-Run Findings

- 路线不存在循环依赖：官方基线先于契约，契约先于生产适配器，截图权限矩阵先于大规模 UI 改造，录制依赖组合状态，本地模拟验收依赖完整功能。
- macOS 没有桌面 App 官方 Simulator；当前按用户要求接受本地模拟验收边界，并明确不把它等同于真实系统验收。
- 原计划分散的真实系统操作已移出当前目标；Phase 7 只保留本地模拟门禁和验收记录。
- `Control+V` 不能等第一次按键后再申请权限；Phase 3 模拟该时序与全部分支，Phase 7 只复核本地模拟证据。
- 录制与绘画/白板并存不能由单一 `AppMode` 表达；Phase 2 在任何 UI 接线前用组合状态测试阻止回退。
- MOV/MP4 与 GIF 不是同一输出管线；Phase 2 先分策略，Phase 5 用模拟 writer 锁定调用，Phase 7 复核本地媒体矩阵。
- 真实播放器、剪辑软件、TCC 和签名无法被纯单元测试替代；当前目标不要求证明这些真实外部事实。
- 稳定签名身份已作为本地产物元数据门禁复核；不再阻塞当前本地模拟验收目标。
- 未发现需要在编码前返回 PRD 或架构继续决策的产品缺口，因此判断为 Go。

## Final Validation

- 当前已通过的自动化门禁：
  - `swift build` 通过。
  - `swift test` 的全部自动化用例通过，且系统边界均使用模拟实现。
  - 官方 `ZoomItMacSelfTest` 通过。
  - 开发版与日常版的 Bundle ID、签名和 entitlements 验证通过。
  - SwiftPM 依赖图确认零第三方运行时依赖。
  - `git diff --check` 通过。
  - `VALIDATION.md` 包含 PRD 第 5.1 节完整功能对照、模拟测试证据、源码量、可执行文件、App 与交付包体积。
- 最终完成改为 Phase 7 本地模拟验收：
  - 构建、测试、self-test、签名元数据、zip 解包和源码/包体快照。
  - 模拟 `Command+V` / 有条件 `Control+V`、权限矩阵与剪贴板失效。
  - 模拟光标状态、热点和快捷键到反馈。
  - 模拟录屏、系统声音、麦克风、摄像头、录制合成和录后编辑。
  - MOV/MP4/GIF、QuickTime、Windows、剪映和 DaVinci Resolve 的本地媒体兼容矩阵。
  - 固定事件样本的虚拟性能基准。
  - `ACCEPTANCE.md` 记录校验和最终本地模拟签收。
- 当前目标不执行真实 TCC 重置、全局输入回放、设备控制、安装或外部播放器操作。

## First Execution Step

下一步是改造脚本和测试，使 `Scripts/phase7-preflight.sh` 直接验证本地模拟验收记录，并确保功能覆盖表、媒体兼容矩阵和文档不再把真实外部验收作为完成阻塞。
