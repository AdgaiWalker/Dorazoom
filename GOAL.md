# Goal Document: DoraZoom Apple 交互与安全补齐

> 产品事实源：[PRD.md](./PRD.md)
> 架构事实源：[ARCHITECTURE.md](./ARCHITECTURE.md)
> 实现基线：Microsoft ZoomIt for Mac `b03e43da91cd84eeb8f691fa65095e0304c3e660`
> 当前提交基线：`1bfda9d`；本轮稳定化改动位于未提交混合工作区，发布前必须按明确范围审查

## Go / No-Go

- **Judgment**：Go
- **Reason**：最新 PRD 的已知缺陷行为已经实现，原生文字、粘贴仲裁、缩放、录音计划和快捷键指南均有本地模拟证据；完整交付门禁已通过。当前可以进入用户可见真机验收，但不能沿用旧 Phase 7 的“真实体验全部完成”结论。

## Target Outcome

在不重写官方捕获、绘制和媒体引擎的前提下，把当前 DoraZoom 基线升级为符合最新 PRD 的 Mac 个人版：

- 快捷键和即时操作保留 ZoomIt 肌肉记忆，设置、权限、菜单、窗口和反馈符合 macOS 习惯。
- 权限通过非模态统一中心呈现；从系统设置返回只刷新状态，必要重启具有明确动作，不再反复弹窗或突然退出。
- 设置固定为六组；打开设置不暂停全部热键，只有录入新快捷键时临时暂停。
- 光标承担长期模式反馈，模式和工具变化只显示短暂状态胶囊；缩放改为显示同步且可中断。
- 文字标注由 AppKit 原生文本系统处理中日韩组合输入、候选、大小写、输入源和编辑命令；文字编辑期间释放 `Control+V` 兼容热键。
- 截图补齐模糊/遮挡、上一次区域、窗口截图、编号标记和多显示器正确性；默认剪贴板路径不产生本地文件。
- 录制补齐开始前预检、暂停/继续、分段安全写入、未完成结果恢复、可选点击/快捷键显示和轻量录后结果页。
- DemoType、倒计时、全景、摄像头细项、MP4/GIF 和复杂编辑继续可用，但进入高级入口，不与核心动作界面平权。
- 现有 `Command+V`、有条件 `Control+V`、MOV/H.264/AAC、白板/黑板、单实例、签名身份和零第三方运行时依赖不得回归。

完成后应生成可构建、可签名的开发版和日常版，并先以本地模拟验收记录证明工程就绪。真实 macOS 权限、输入法、缩放手感、目标 App 粘贴、声音和播放器必须由用户在可见流程中人工验收；未得到结果前不写成通过，也不提交或发布。

## Goal Definition

- **Type**：product + technical + quality + delivery
- **Boundary**：
  - 重构权限、设置、菜单栏、模式反馈和缩放动效的 AppKit 外壳。
  - 增加 PRD 第 5.1 节列出的截图安全/效率能力和录制安全/恢复能力。
  - 更新领域状态、平台协议、测试替身、功能覆盖表、验证记录和验收记录。
  - 保留并复用官方捕获、标注、ScreenCaptureKit、AVFoundation、Vision、全景和高级编辑实现。
  - 保持 `arm64` 默认交付、SwiftPM、单进程、单核心模块、零第三方运行时依赖。
- **Non-goals**：
  - 账号、云同步、团队空间、订阅、遥测和第三方 AI API。
  - 截图历史库、永久素材库、自动后台归档。
  - OBS 式场景、直播、多轨专业时间线和 Screen Studio 式自动电影缩放。
  - 恢复旧 `Sources/InkLayer/**`，或建立官方实现之外的第二套捕获/绘制/录制引擎。
  - 为旧内部类型、旧设置标签或旧窗口控制器建立兼容别名；不存在外部公开契约时直接迁移调用方。
  - 自动触碰真实 TCC、全局键盘、真实剪贴板、屏幕、麦克风、摄像头、登录项、目标 App 或真实用户输出目录。
- **Deferred work**：
  - Developer ID、notarization、公网下载站和自动更新。
  - Universal 构建，除非后续确认存在 Intel 交付目标。
  - 截图置顶、延时截图、颜色拾取、像素测量和高级 OCR。
  - 自动摄像头背景虚化、噪声消除和电影级鼠标平滑。
- **Verification rule**：
  - 每个实现 todo 使用 `hai-tdd` 执行 RED → GREEN → REFACTOR，并将证据写入 `VALIDATION.md`。
  - 所有自动化测试只使用进程内模拟层、测试替身、虚拟时钟和确定性事件回放，由 `Scripts/verify-test-boundary.sh` 守门。
  - 工程完成要求 `Scripts/verify-delivery.sh`、全量测试、自测、功能覆盖、文档一致性和交付产物门禁全部通过。
  - 当前产品完成以 `Scripts/phase7-preflight.sh` 和已填写的本地模拟 `ACCEPTANCE.md` 为准；Codex 不启动 App、请求权限或操作真实目标应用。
- **Evidence source**：
  - Swift XCTest 的纯逻辑、模拟集成、虚拟时钟和故障恢复测试。
  - `ZoomItFeatureCoverageMap` 的实现引用、模拟测试引用和缺口集合。
  - `swift build`、`swift test`、`ZoomItMacSelfTest`、`Scripts/verify-delivery.sh`。
  - App/zip 身份、签名、entitlements、架构、依赖和体积元数据。
  - 更新后的 `VALIDATION.md` 和本地模拟 `ACCEPTANCE.md`。
- **Pass criteria**：
  - 最新 PRD 第 14 节每个自动化可验证项均有测试证据，没有空白、跳过或把真实系统事实写成模拟通过。
  - 功能覆盖表包含最新新增能力，最终 `gaps == []`；默认核心与高级兼容能力的层级有测试或菜单/设置计划证据。
  - 权限中心不存在返回应用后自动重弹、递归权限 `NSAlert` 或多权限按钮堆叠；可选麦克风/摄像头未请求时不显示为错误。
  - 设置固定六组，普通打开/关闭不停止全局热键；快捷键录入完成、冲突、取消和关闭均恢复热键。
  - 原生文字会话覆盖 marked text、候选提交/取消、大小写、输入源切换、选择与编辑命令；旧 `event.characters` 正文追加路径已删除。
  - 模式首帧反馈、短暂 HUD、60/120 Hz 缩放序列、减少动态/透明度/增强对比度替代计划全部通过模拟测试。
  - 区域、上一次区域和窗口截图均能进入内存剪贴板替身；模糊/遮挡/编号进入合成；默认路径无模拟文件写入。
  - 录制预检、暂停/继续、时间线连续性、分段写入、恢复、点击/快捷键隐私过滤和轻量结果页均有确定性测试。
  - 原有 `Command+V`、条件式 `Control+V`、MOV/MP4/GIF、三种录制目标、白板/黑板和高级功能测试无回归。
  - 自动化测试边界、零第三方依赖、dev/daily 身份隔离、`arm64` 默认和交付 zip 门禁保持通过。
  - `ACCEPTANCE.md` 的本地模拟单元格无空白、最终结论唯一，且没有把真实系统事实冒充为通过。
- **Confidence note**：模拟层能够高置信度证明状态机、权限决策、渲染计划、事件路由、媒体时间线、恢复策略和交付身份；它不能证明真实 TCC、输入法候选、光标观感、硬件声音、目标 App 粘贴或第三方播放器表现。
- **Judgment owner**：自动化门禁、功能覆盖表和本地模拟记录宣布“可供验收”；用户的可见真机结果宣布体验是否通过；发布另需当前明确授权。

## Current State

- 当前分支为 `main`，remote 为 `origin -> https://github.com/AdgaiWalker/zoomit.git`。
- 当前提交基线为 `1bfda9d`；工作区已有产品、代码、测试、文档和网站等混合改动，尚未暂存或提交，禁止用宽泛暂存覆盖用户工作。
- 旧 Phase 1–7 已建立官方源码、组合状态、反馈通道、截图/粘贴、MOV/MP4/GIF、全景、DemoType、倒计时、设置和交付基线；这些只作为历史证据保留。
- 当前全量回归为 219 项本地模拟 XCTest，0 失败、0 跳过；官方 self-test、测试边界门禁、build 和 diff 检查通过，零第三方 SwiftPM 运行时依赖。
- `Scripts/verify-test-boundary.sh` 当前通过，测试目录未直接触碰真实 TCC、全局键盘、真实屏幕/音频/摄像头、系统剪贴板、目标 App 或登录项。
- Phase 1 已完成：`ZoomItFeatureCoverageMap.current` 已纳入最新 PRD，并区分已完成证据、计划实现/测试引用和用户人工验收要求。
- Phase 2 权限中心与六组设置纵向切片已完成；旧递归权限弹窗、返回后自动重现、十标签/floating 设置结构和“打开设置即停用热键”均已删除。
- 设置窗口现使用通用/快捷键/截图与圈画/录制/权限/高级六组 `NSSplitViewController` 导航、普通窗口层级和 frame 持久化；只有 `HotkeyCaptureSession` 活跃时暂停全局热键。
- Phase 3 即时反馈与显示同步动效已完成：模式/工具/完成/警告/错误改为可捕获排除的短暂状态胶囊，旧永久绘画 HUD 已删除。
- 模式指针现按放大镜、画笔圆环、高亮笔尖、形状十字和文本光标区分，并对减少动态效果、减少透明度和增强对比度生成替代呈现计划。
- 固定 30 fps 缩放 Timer 已替换为显示同步时钟和可中断的临界阻尼运动；PiP 已接入 1:1 拖动、边界渐进阻力、速度投射和无弹跳角落吸附。
- Phase 4 截图沟通与隐私闭环已完成：模糊笔、实色遮挡、自动编号、上一次区域、鼠标所在窗口和多显示器坐标均已接入生产路径与本地模拟。
- Phase 5 已完成：录制预检、暂停/继续、分段安全写入、未完成结果恢复、点击/快捷键隐私显示和轻量录后结果页均已接入生产路径与确定性模拟。
- 原生文字稳定化已完成：`CanvasTextEditingSession` 以 `NSTextView` 接管组合输入与原生编辑，画布提交普通文本 Annotation；文字编辑期间 Carbon/Event Tap 两条 `Control+V` 兼容路径均让位，结束后按剪贴板与权限状态恢复。
- OCR 生产复制管线现会回传剪贴板变更号和用户可感知字符数，协调器据此显示“已复制 N 个字符”，并复用有条件 `Control+V` 链路。
- Phase 6 的菜单/设置层级已收敛：菜单使用中文核心动作、截图子菜单和“更多功能”高级入口，快捷键来自当前设置，权限只有在存在可操作缺失时标记。
- 最新 `ZoomItFeatureCoverageMap.current` 的 `gaps == []`；`Scripts/verify-delivery.sh` 已通过并生成 dev/daily/zip 三个 arm64 产物。
- `VALIDATION.md` 已追加当前迭代 TDD 证据，`ACCEPTANCE.md` 已同步本地模拟工程验收；两者均明确不冒充真实 macOS 人工体验。
- `Scripts/phase7-preflight.sh` 已通过，工程已达到本地模拟“可供验收”；用户真机验收与发布授权尚未完成。

## Plan Rewrite Notes

| Existing item | Decision | Reason |
| --- | --- | --- |
| 旧 Phase 1–7 详细 todo | remove from active route | 已完成且篇幅过大，继续留在活跃计划会掩盖新缺口；历史由 Git、`VALIDATION.md` 和 `ACCEPTANCE.md` 保存 |
| 官方源码、双 Bundle ID、模拟测试边界 | keep | 是新迭代的稳定底座和安全约束 |
| “完整复刻、功能平权”目标 | remove | 已被最新 PRD 的核心体验兼容和高级入口分层取代 |
| 旧 `phase6Default.gaps == []` | rewrite first | 与最新 PRD 冲突，会让后续执行产生虚假完成状态 |
| 权限、设置、反馈、截图、录制五项顺序 | expand into phases | 原计划只有一段顺序，没有 action + surface + proof，无法直接执行 |
| 真实系统自动验收 | keep excluded | 用户要求自动化全部走模拟层；真实验收只能由用户主动、可见地进行 |
| 重型录制编辑器作为默认路径 | move to advanced | 日常路径改为预览、裁剪、音量和导出，保留高级编辑实现 |
| 旧 Phase 7 “通过” | retain as baseline only | 它证明旧实现和交付身份，不证明新增产品要求 |
| Phase 3 四项 Apple 呈现 todo | mark complete | 短暂反馈、指针双编码、显示同步缩放和 PiP 直接操纵已有生产接线与确定性模拟测试，不再作为未开始项 |

## Drift Diagnosis

- **Goal drift**：旧 GOAL 同时描述已完成历史和未开始新迭代，且仍以“完整能力覆盖”为成功语言，无法准确表达当前目标。
- **Phase drift**：新需求只被追加成五行“Current Iteration”，没有阶段入口、依赖、证明或停止条件；旧七阶段反而占据主体。
- **Validation drift**：覆盖表与旧验收仍显示无缺口，而 PRD 已明确新增能力；若不先修复，会出现测试全绿但目标未完成。
- **Compatibility drift**：旧 Windows 设置结构和权限弹窗被当成上游兼容内容保留，但它们不是外部契约；新计划直接替换，不建立双 UI 或兼容别名。
- **Cleanup drift**：禁止在本迭代顺手重排整个源码、恢复 InkLayer、拆多 Package 或重写官方引擎；只处理证明目标所需的结构。

## Priority Rationale

- 先让覆盖表承认缺口，才能防止后续任何阶段被旧“全部通过”结论提前关闭。
- 权限和设置是用户已经真实遇到的高频阻力，并且是独立于捕获/媒体算法的外壳，风险低、反馈快，应最先形成用户可见改进。
- 光标、HUD 和显示同步动效是截图与录制共用的呈现基础，必须先于新增截图和录制能力稳定。
- 截图闭环比录制更短，能先验证隐私工具、选区复用、多显示器和剪贴板组合；其标注合成还能被后续录制复用。
- 录制暂停、分段写入和恢复是本轮最复杂的状态/媒体风险，放在前置状态、反馈和合成稳定之后，但不能推迟到最终整合才验证。
- 最后统一收口菜单层级、覆盖表、文档和交付产物，避免每个阶段重复调整默认界面。

## Assumptions and Open Decisions

| Item | Status | Impact | Owner / Next step |
| --- | --- | --- | --- |
| PRD 和架构已足以启动 | confirmed | 不需要再次讨论总体产品方向 | 发现新的用户行为决策时停止实现并先更新 PRD |
| 自动化测试全部走进程内模拟层 | confirmed | 禁止测试触发真实平台副作用 | 每阶段运行 `Scripts/verify-test-boundary.sh` |
| 现有官方捕获/绘制/媒体引擎继续复用 | confirmed | 控制风险和上游合并成本 | 只有测试证明现有实现无法满足目标时才局部修改 |
| 不存在需要兼容的外部公开 Swift API | assumed | 内部类型可以直接重命名和迁移 | Phase 1 搜索 Package public surface；若发现外部契约则重新裁决 |
| “上一次区域”只在当前进程和当前显示拓扑有效 | assumed | 避免跨启动或显示器变化复用错误坐标 | Phase 4 测试显示器变化后自动失效；如需持久化另开决策 |
| 新能力暂不新增全局默认快捷键 | assumed | 避免与 ZoomIt 数字键和 Mac 系统快捷键冲突 | 先从菜单、模式内工具和可配置快捷键访问；默认键需更新 PRD 后再加 |
| 模糊和实色遮挡属于标注合成，不建立原图历史 | confirmed | 保护隐私并保持“用完即走” | Phase 4 只在当前会话内保留撤销所需数据 |
| 快捷键显示默认过滤普通文字 | confirmed | 防止密码和聊天正文泄露 | Phase 5 仅允许修饰键组合和明确白名单按键 |
| 高级功能保留但不默认展示 | confirmed | 避免功能删除，同时降低界面密度 | Phase 6 验证菜单和设置层级 |
| 当前最终验收全部走本地模拟 | confirmed | 不安装、启动或触碰真实平台副作用 | 运行 Phase 7 preflight 和验收记录校验；真实设备另开目标 |

## Phases

### Phase 1：重置覆盖事实与迭代门禁

- **Purpose**：让代码、测试和验证记录诚实表达最新 PRD 的新增缺口，建立后续阶段唯一的完成计数器。
- **Entry condition**：最新 `PRD.md` 和 `ARCHITECTURE.md` 已写入，当前基线测试可运行。
- **Phase rules**：
  - 使用 `hai-tdd`；第一个 RED 必须因为旧覆盖表遗漏最新能力而失败。
  - 本阶段可以修改覆盖枚举、状态命名、测试和验证文档，不改变用户可见 AppKit 行为。
  - `phase6Default` 等历史命名属于内部实现，可直接重命名，不建立兼容别名。
  - 旧能力的实现/测试引用必须保留；新增能力必须显式标为 gap，不能伪造实现证据。
- **Todos**：
  - [x] 重建最新 PRD 功能覆盖清单和层级。
    - **Surface**：`ZoomItFeatureCoverageMap.swift`、覆盖测试。
    - **Proof**：RED 测试证明旧 map 漏掉新增能力；GREEN 后 required capabilities 包含权限中心、六组设置、短暂反馈、显示同步缩放、截图四项和录制安全项。
    - **Depends on**：无。
  - [x] 将阶段绑定状态名改为通用状态。
    - **Surface**：覆盖状态枚举、调用方和测试。
    - **Proof**：不再出现 `phase6ImplementationGap` / `phase6Default` 等把新迭代误写成旧阶段的生产符号；全量编译通过。
    - **Depends on**：覆盖清单。
  - [x] 建立“基线已实现 / 当前待实现 / 仅人工验收”三类证据规则。
    - **Surface**：覆盖模型、`VALIDATION.md`、测试。
    - **Proof**：测试拒绝 required capability 没有状态、没有实现引用却被标为完成、或把人工验收引用冒充模拟通过。
    - **Depends on**：覆盖状态通用化。
- **Exit proof**：全量测试通过；覆盖表准确列出当前新增 gaps；`VALIDATION.md` 记录本阶段 RED/GREEN/REFACTOR；测试边界门禁通过。
- **Stop condition**：发现最新 PRD 能力无法映射为可独立验收项，或必须重新决定产品范围。

### Phase 2：权限中心与六组设置

- **Purpose**：先消除用户已经遇到的重复权限提示、授权后突然退出、Windows 十标签设置和设置期间热键失效。
- **Entry condition**：Phase 1 覆盖表明确列出权限与设置 gaps。
- **Phase rules**：
  - 先实现纯逻辑 plan/model，再接 AppKit；测试不得打开真实系统设置或申请 TCC。
  - 删除递归权限 `NSAlert` 和返回后自动重现路径，不保留双 UI。
  - 打开设置不得停止全局热键；只有 `HotkeyCaptureSession` 活跃时暂停。
  - 设置保存继续使用现有 `UserDefaults`，不迁移数据库或增加配置版本兼容层。
- **Todos**：
  - [x] 实现 `PermissionCenterModel` 状态与动作矩阵。
    - **Surface**：权限领域类型、模拟权限服务、测试。
    - **Proof**：覆盖未请求/允许/拒绝/需要设置/需要重启、可选麦克风/摄像头，以及返回应用只刷新状态。
    - **Depends on**：Phase 1。
  - [x] 用非模态权限中心替换当前权限弹窗。
    - **Surface**：`AppController`、新权限中心 AppKit 控制器、设置入口。
    - **Proof**：模拟窗口生命周期中不存在递归展示；每行只有一个当前动作；relaunch 产生明确意图而非无说明 terminate。
    - **Depends on**：权限 model。
  - [x] 重构设置为六组原生导航。
    - **Surface**：`SettingsWindowController`、设置分类计划、测试窗口。
    - **Proof**：固定为通用/快捷键/截图与圈画/录制/权限/高级；DemoType、倒计时、全景、摄像头细项和格式设置只在高级组。
    - **Depends on**：Phase 1。
  - [x] 实现短生命周期快捷键录入会话。
    - **Surface**：`HotkeyCaptureSession`、HotkeyService 接线、设置 UI。
    - **Proof**：普通打开/关闭设置不触发 stop/start；录入成功、冲突、`Escape`、关闭窗口均只恢复一次。
    - **Depends on**：六组设置。
  - [x] 移除 Windows 专用布局行为。
    - **Surface**：复选框、floating window、窗口 frame 持久化、本地化标签。
    - **Proof**：测试窗口使用原生控件方向和普通层级，重开时恢复 frame；代码搜索不再以 Windows Options 布局作为设置实现约束。
    - **Depends on**：设置导航。
- **Exit proof**：权限与设置新增 gaps 关闭；相关模拟测试、全量测试、边界门禁和 `git diff --check` 通过；验证记录包含完整 TDD 证据。
- **Stop condition**：某权限状态需要新的产品文案/请求时机裁决，或 macOS API 无法在不自动弹窗的情况下表达已确认流程。

### Phase 3：即时反馈与显示同步动效

- **Purpose**：让模式进入即有状态、绘画/选区直接跟手、缩放可中断，并建立截图和录制共用的呈现基础。
- **Entry condition**：Phase 2 的设置和权限窗口生命周期稳定。
- **Phase rules**：
  - 光标提交不等待捕获、HUD 或动画；pointer、HUD、recording status、menu bar、palette 通道继续隔离。
  - 选区、画笔和形状预览不使用 spring；只有缩放和 PiP 归位使用可中断动效。
  - 测试使用虚拟 60 Hz/120 Hz 时钟，不访问真实显示器刷新回调。
  - 临时反馈显式排除在截图/录制结果之外。
- **Todos**：
  - [x] 建立 `FeedbackPresentationAdapter` 和短暂 HUD 计划。
    - **Surface**：InteractionFeedback、HUD/Palette 呈现、虚拟时钟测试。
    - **Proof**：模式进入、工具变化、完成、警告、错误具有独立时长；旧 lease 不能清除新反馈；默认无永久工具条。
    - **Depends on**：Phase 1 覆盖规则。
  - [x] 接通光标首帧与无障碍环境计划。
    - **Surface**：pointer resource、presentation snapshot、reduce motion/transparency/contrast 输入。
    - **Proof**：所有模式首帧非普通箭头；形状与颜色双编码；三个系统环境分别生成替代呈现计划。
    - **Depends on**：反馈适配器。
  - [x] 以显示同步时钟替换固定 30 fps 缩放 Timer。
    - **Surface**：OverlayWindowController、ZoomViewportController、生产/模拟 motion clock。
    - **Proof**：60/120 Hz 事件序列得到一致目标；中途反向从当前呈现值和速度继续；减少动态时直接提交或短淡化。
    - **Depends on**：虚拟时钟协议。
  - [x] 完成 PiP 直接操纵与吸附计划。
    - **Surface**：WebcamOverlayController、拖动/速度/边界策略测试。
    - **Proof**：保持抓取偏移和 1:1 跟随；释放后按投射位置吸附；边界使用渐进阻力；动画可中断且无默认弹跳。
    - **Depends on**：显示同步动效。
- **Exit proof**：反馈/动效 gaps 关闭；60/120 Hz、中途反向、减少动态效果和 PiP 边界/吸附确定性模拟通过；全量 147 项 XCTest 通过；源码搜索不再存在固定 30 fps 缩放 Timer 或永久绘画 HUD。
- **Stop condition**：显示同步实现要求引入第二套渲染引擎，或动画改变 ZoomIt 的核心定位和控制语义。

### Phase 4：截图沟通与隐私闭环

- **Purpose**：把“选择—保护隐私—说明重点—复制—粘贴”做成完整、无落盘、可重复的 Mac 截图闭环。
- **Entry condition**：Phase 3 的光标、HUD、选区和显示器反馈稳定。
- **Phase rules**：
  - 默认输出只写剪贴板替身；保存文件仍是高级/修饰键路径。
  - 上一次区域只在当前进程且显示拓扑未变化时有效。
  - 模糊/遮挡/编号属于可撤销标注，不建立原图历史或永久素材库。
  - `Command+V` 永远放行；现有条件式 `Control+V` 语义不得改变。
- **Todos**：
  - [x] 实现模糊笔和实色遮挡合成。
    - **Surface**：AnnotationTool、render plan、截图导出和录制合成共享路径。
    - **Proof**：固定图片 fixture 证明遮挡区域进入最终像素；撤销恢复前态；输出不包含未遮挡像素的可恢复旁路。
    - **Depends on**：Phase 3 feedback。
  - [x] 实现自动递增编号标记。
    - **Surface**：annotation model/controller/render plan。
    - **Proof**：连续编号、拖动、撤销回退、清除与截图合成测试通过。
    - **Depends on**：标注管线。
  - [x] 实现“上一次区域”截图。
    - **Surface**：SnipController、region memory、display topology policy。
    - **Proof**：同拓扑复用并直接复制；取消/显示器变化/无历史时安全降级；不写本地文件。
    - **Depends on**：选区生命周期。
  - [x] 实现窗口截图到剪贴板。
    - **Surface**：窗口目标选择、capture request plan、snip export plan。
    - **Proof**：模拟窗口列表选择正确 window ID；阴影策略可配置；取消和窗口消失不留临时状态。
    - **Depends on**：现有窗口录制目标能力。
  - [x] 完成多显示器截图正确性。
    - **Surface**：DisplayManager、坐标转换、pointer/HUD placement、capture exclusion。
    - **Proof**：不同原点、缩放因子和主副屏 fixture 下选区、热点、HUD、像素尺寸和输出目标一致。
    - **Depends on**：前三项截图能力。
- **Exit proof**：截图 5 项新增 gaps 全部关闭；隐私像素、编号、拓扑失效、窗口消失和跨屏坐标 fixture 通过；171 项全量 XCTest、build、self-test、测试边界和 diff 门禁通过；默认截图路径模拟文件写入数为零。
- **Stop condition**：隐私工具无法保证输出像素不可恢复，或窗口/多显示器坐标语义需要新的产品裁决。

### Phase 5：录制安全、暂停与恢复

- **Purpose**：优先消除“录完没声音、无法暂停、崩溃全丢”的不可逆风险，再收敛日常录后路径。
- **Entry condition**：Phase 4 的标注合成可以稳定进入录制帧计划。
- **Phase rules**：
  - 默认仍为 MOV/H.264/AAC，MP4/GIF 保留；不引入 FFmpeg。
  - 录制状态必须显式表达 preparing/recording/paused/finalizing/recoverableFailure。
  - 自动测试只使用模拟音频电平、磁盘、writer、时钟、文件系统和故障注入。
  - 恢复清单只服务未完成录制，不演变为媒体历史库。
  - 普通文字按键不得进入快捷键显示层。
- **Todos**：
  - [x] 实现录制开始前预检。
    - **Surface**：RecordingPreflightPlan、音源权限/电平、磁盘协议、UI plan。
    - **Proof**：无音源、静音、权限缺失、空间不足、目标消失和正常开始矩阵通过；可选输入不阻塞未启用场景。
    - **Depends on**：Phase 2 权限中心。
  - [x] 实现暂停/继续和连续时间线。
    - **Surface**：RecordingState、RecordingController、writer 时间戳策略。
    - **Proof**：多次暂停/继续后输出时长等于有效片段总和；音视频和标注时间线连续；重复命令幂等。
    - **Depends on**：预检与现有 writer profile。
  - [x] 实现分段安全写入和未完成结果恢复。
    - **Surface**：segment writer、recovery manifest、模拟文件系统、启动恢复计划。
    - **Proof**：在开始、片段中、暂停、finalize 各故障点注入失败后，能恢复可用片段或给出明确不可恢复原因；正常完成后清理 manifest。
    - **Depends on**：暂停/继续。
  - [x] 实现鼠标点击和快捷键显示的隐私策略。
    - **Surface**：recording overlay event model、过滤策略、合成计划。
    - **Proof**：点击位置、高亮时长、修饰键组合可见；普通文字、密码式连续输入和未授权事件不进入输出。
    - **Depends on**：Phase 3 feedback。
  - [x] 建立轻量录后结果页。
    - **Surface**：VideoClipEditorController 或独立 result controller、导出计划。
    - **Proof**：默认只显示预览、裁剪、音量、导出、访达入口；复杂拼接/淡入淡出仅从高级入口打开，全部非破坏性。
    - **Depends on**：安全 writer。
- **Exit proof**：录制新增 gaps 已关闭；故障注入、媒体时间线、MOV/MP4/GIF、摄像头、声音、标注合成和高级编辑测试通过；当前 219 项全量模拟 XCTest、测试边界、build、self-test 和 diff 检查通过。
- **Stop condition**：现有 AVFoundation 管线无法实现可靠暂停/恢复且需要改变默认格式，或恢复策略会产生不可控的永久文件积累。

### Phase 6：默认界面分层与工程交付

- **Purpose**：把各纵向切片整合为一致的菜单栏产品，关闭覆盖表和全部模拟门禁，生成可进行本地模拟验收的 App。
- **Entry condition**：Phase 2–5 的新增能力与回归测试分别通过。
- **Phase rules**：
  - 菜单栏默认只显示圈画、缩放、截图和录制；高级功能统一下沉。
  - 不为减小体积删除核心或高级兼容能力，不降低默认媒体质量。
  - 更新文档必须区分模拟证据和真实人工事实。
  - 不安装、不启动、不请求权限；只构建并交付明确路径。
- **Todos**：
  - [x] 收敛菜单栏、设置和状态层级。
    - **Surface**：AppDelegate menu plan、SettingsNavigationModel、menu lifecycle tests。
    - **Proof**：默认动作顺序与 PRD 一致；更多功能包含 DemoType/倒计时/全景；权限无问题时保持安静、缺失时显示状态。
    - **Depends on**：Phase 2–5。
  - [x] 关闭最新功能覆盖表全部 gaps。
    - **Surface**：ZoomItFeatureCoverageMap、实现/测试引用。
    - **Proof**：每项 required capability 有实现与模拟测试引用；人工项单独标记；最终 `gaps == []`。
    - **Depends on**：全部实现。
  - [x] 运行全量模拟、边界和交付门禁。
    - **Surface**：Scripts、SwiftPM、self-test、bundle/zip。
    - **Proof**：`Scripts/verify-test-boundary.sh`、`swift test`、self-test、`Scripts/verify-delivery.sh`、`git diff --check` 全部通过。
    - **Depends on**：覆盖表关闭。
  - [x] 更新验证与验收记录。
    - **Surface**：`VALIDATION.md`、`ACCEPTANCE.md`、README。
    - **Proof**：每阶段 TDD 证据齐全；旧基线说明保留；新模拟验收无空白，不声称真实平台通过。
    - **Depends on**：全量门禁。
  - [x] 生成开发版、日常版和交付 zip。
    - **Surface**：`.build/DoraZoom Dev.app`、`.build/DoraZoom.app`、`.build/DoraZoom.zip`。
    - **Proof**：bundle identity、签名、entitlements、架构、版本、图标、zip 清洁度和 allowlist 通过。
    - **Depends on**：交付门禁。
- **Exit proof**：自动化工程门禁全部通过，最新覆盖表无 gap，文档证据完整；开发版 6.2 MB、日常版 2.8 MB、交付 zip 1.1 MB 均为 arm64，可进入用户可见的真机验收。
- **Stop condition**：任何测试需要突破模拟边界、交付身份不稳定、功能覆盖存在未解释缺口，或新增改动使包体/性能出现无法解释的明显回退。

### Phase 7：本地模拟最终验收

- **Purpose**：使用同一条非侵入入口复跑模拟、替身、事件回放、产物元数据和验收记录校验，关闭当前目标而不触碰宿主 Mac 的真实交互面。
- **Entry condition**：Phase 6 工程完成，三个交付产物已生成。
- **Phase rules**：
  - 只运行 `Scripts/phase7-preflight.sh` 和 `Scripts/verify-acceptance-record.sh ACCEPTANCE.md`。
  - 不安装、不启动、不请求/重置 TCC、不监听或发送真实全局键盘、不读写系统剪贴板、不捕获真实屏幕/音频/摄像头、不注册登录项、不控制目标 App。
  - 验收记录必须说明模拟证据边界；外部播放器、真实权限和主观体验不能写成真实通过。
- **Todos**：
  - [x] 运行 Phase 7 本地模拟入口。
    - **Surface**：`Scripts/phase7-preflight.sh`。
    - **Proof**：完整交付门禁与验收校验返回 PASS。
    - **Depends on**：Phase 6。
  - [x] 校验验收记录完整且结论唯一。
    - **Surface**：`ACCEPTANCE.md`、`Scripts/verify-acceptance-record.sh`。
    - **Proof**：不存在空白验收单元格，最终只选择“通过”。
    - **Depends on**：本地模拟入口。
  - [x] 完成本地模拟工程收口。
    - **Surface**：`GOAL.md`、`VALIDATION.md`。
    - **Proof**：记录最终命令、产物和明确限制；不遗留实现 gap 或模拟门禁失败。
    - **Depends on**：前两项。
- **Exit proof**：Phase 7 preflight、验收记录校验和 diff 检查全部通过；本地模拟最终结论为通过，真实体验结论仍待用户给出。
- **Stop condition**：任何测试试图突破模拟边界、验收记录不完整、交付门禁失败或覆盖表重新出现 gap。

## Dry-Run Findings

- 路线无循环依赖：覆盖事实先于实现；权限/设置先于依赖它们的录制预检；反馈/动效先于截图和录制呈现；截图标注合成先于录制复用；交付先于本地模拟最终验收。
- 第一风险不是编码难度，而是旧覆盖表继续报告“无缺口”；Phase 1 先恢复诚实缺口，Phase 2–5 逐项关闭后，当前覆盖表已由实现和模拟测试引用证明 `gaps == []`。
- 权限中心和设置可以在不触碰真实 TCC 的情况下通过状态矩阵与测试窗口完成工程验证，不需要等待人工环境。
- “上一次区域”的跨启动持久化、所有新增能力的默认全局快捷键都不是当前必要条件；计划采用会话级区域和无新增默认热键，避免阻塞。
- 模糊/遮挡必须在导出像素层验证，不能只检查 annotation model；否则隐私目标没有被真正证明。
- 录制恢复是最大技术风险，计划在 Phase 5 使用多故障点注入提前证明，不留到最终播放器验收。
- 工程实现与最终模拟收口明确分开：Phase 6 关闭实现/交付，Phase 7 复跑统一入口并校验本地模拟验收记录。
- Phase 4 已证明标注、隐私合成、内存剪贴板输出与多显示器坐标；Phase 5 可直接复用这些合成计划，不建立第二套录制标注引擎。
- 未发现需要先返回 PRD 或架构补充的阻塞决策，执行判断为 Go。

## Final Validation

工程门禁：

```sh
Scripts/verify-test-boundary.sh
swift build
swift test
.build/debug/ZoomItMacSelfTest
Scripts/verify-delivery.sh
Scripts/verify-acceptance-record.sh ACCEPTANCE.md
git diff --check
```

最终检查：

- 最新 `ZoomItFeatureCoverageMap` 的 required capabilities 全部有实现和模拟测试证据，`gaps == []`。
- `VALIDATION.md` 包含每阶段 RED、GREEN、REFACTOR 与验证命令。
- `ACCEPTANCE.md` 分别记录本地模拟结论和真实系统人工验收状态，未验事实保持“待用户验收”。
- dev/daily/zip 产物身份、签名、架构、版本、entitlements 和清洁度通过。
- `Scripts/phase7-preflight.sh` 与验收记录校验通过，最终模拟结论唯一选择“通过”。

## First Execution Step

下一步是用户可见的真机验收。启动前先明确开发版路径 `/Users/happy/Desktop/zoomit/.build/DoraZoom Dev.app`、Bundle ID `com.duola.dorazoom.dev` 和版本 `1.0`；未经用户确认不自动启动、不安装、不重置 TCC。用户结果写回 `ACCEPTANCE.md`，失败项立即回到 TDD；全部通过后仍需单独的发布授权。
