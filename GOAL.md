# Goal Document: InkLayer v1 —— Mac 屏幕板书层（实验 0 → P4 六件套）

> 锚定文档：PRD v1.5（`# PRD: Mac 屏幕板书层.md`，需求冻结）
> 日期：2026-07-23 · 状态：执行中

## Go / No-Go
- **Judgment**: Go
- **Reason**: 需求冻结、热键/技术栈/证伪标准齐备；工具链已核查（Xcode 26.6 / Swift 6.3.3 / macOS 27.0）。生死线（Screen Studio 可捕获 overlay）刻意保留为"机检 + 人检"双门，不伪造通过。

## Target Outcome
作者的 Mac 上常驻一个**零权限即装即用**的菜单栏板书层：
`Ctrl+1~6` 单手热键语法唤起缩放/圈画/打字/白板/录屏/Snip，
图层独立可叠加；Screen Studio 成片包含 overlay 全部内容；
事件流遥测自第一行代码起持续落盘 JSONL，构成行为数据资产。
Phase 0 一周硬时限：2026-07-30 前交付"能天天用的冻结态圈画"。

## Goal Definition
- **Type**: product / delivery
- **Boundary**: PRD §5 In Scope（六件套 + 地基），按 实验0→P0→P1→P2→P3→P4 执行
- **Non-goals**: PRD §5 砍单全表（多屏 / 设置 UI / 热键自定义 / 账号云端 / 视频编辑……）
- **Deferred work**: 活屏态（代理指标回魂）、黑板、发布清单（更名 / 公证 / Sparkle / 设置 UI）
- **Verification rule**: 每 Phase 的 Exit proof 全过 → PRD §7 五个验收框逐项勾
- **Evidence source**: 命令（`swift build`）、trace（telemetry.jsonl）、行为（用户操作）、用户信号（Screen Studio 成片）
- **Pass criteria**: PRD §7 全部勾中，且遥测覆盖全部热键事件
- **Confidence note**: "overlay 可捕获"无代理指标，唯一直接证据是 Screen Studio 成片——这是刻意保留的人工验收门
- **Judgment owner**: 构建/日志类 = 命令判定；体验与成片 = 用户本人

## Current State
- 工作区：仅 PRD v1.5，零代码；单屏
- 工具链：Xcode 26.6 · Swift 6.3.3 · git 2.50.1 · macOS 27.0（arm64）
- 约束：部署目标 macOS 14+；Carbon 热键免辅助功能权限；零第三方依赖起步（PRD 允许至多 1 个）
- 风险：PRD §9 六条 + 实验 0 验收半自动（需用户录 10 秒）+ macOS 15+ 录屏权限周期弹窗（ScreenCaptureKit 正路）

## Plan Rewrite Notes（PRD §10 Rollout → 本目标文档）

| Existing item | Decision | Reason |
|---|---|---|
| 实验 0 | keep + rewrite | 拆出"机检/人检"双 exit；补脚手架与自检 todos |
| P0 一周硬时限 | keep | 2026-07-23 起算 → 2026-07-30 截止 |
| P1→P4 顺序 | keep | 救场类（Snip/录屏）先于层类（打字/白板）：救场类不受频率审判，先做稳赚 |
| 发布清单 | remove | 属"发布"目标，非 v1 目标，移出防 cleanup drift |

## Drift Diagnosis
- **Goal drift**：无——所有阶段直指 Target Outcome
- **Phase drift**：PRD 阶段按依赖与风险排序（非按主题），维持
- **Validation drift**：风险点——"实现了 X"易冒充"完成了 X"；强制每个 todo 挂 proof
- **Compatibility drift**：绿地项目，无历史包袱
- **Cleanup drift**：发布清单移出本目标

## Priority Rationale
- 实验 0 最先：可捕获性是生死线，不通则全案终止，损失最小化
- P0 次之：圈画使用频率第一；一周硬时限抗"动机衰减"（自用工具头号死因）
- P1/P2 先于 P3/P4：应急类功能只做"救场"审判，先做无被砍风险；层类需遥测积累后再判生死

## Assumptions and Open Decisions

| Item | Status | Impact | Owner / Next step |
|---|---|---|---|
| 内部代号 InkLayer（非商标，发布前更名） | assumed | 工程/目标命名 | 发布清单 |
| Screen Studio 日常录制方式=全屏录制 | assumed（用户曾表示不确定） | 决定人检操作步骤 | 用户录制时确认 |
| 遥测默认 `~/Library/Application Support/InkLayer/telemetry.jsonl`，`INKLAYER_TELEMETRY_PATH` 可覆盖 | assumed | 数据资产落地位置 | P0 内做配置文件 |
| SPM 可执行目标（无 .app bundle） | assumed | 登录自启（SMAppService）需 bundle | 推迟到发布打包 |

## Phases

### 实验 0：生死线 —— overlay 可被 Screen Studio 捕获
- **Purpose**: 验证 PRD §6 第 1 条；不通不开发
- **Entry condition**: 工具链核查通过 ✅
- **Phase rules**:
  - 只建骨架：菜单栏图标 / overlay / `Ctrl+2` / 遥测首行；不实现任何真实功能
  - overlay 必须 `sharingType=.readWrite` + 屏幕级置顶（`.screenSaver`）
  - 零第三方依赖
- **Todos**:
  - [x] SPM 脚手架 + git init + .gitignore — `swift build` 通过 ✅
  - [x] 菜单栏常驻 + 无 Dock 图标（`.accessory`）— 进程存活、Dock 无图标 ✅
  - [x] 透明置顶 overlay + 测试字画 — `overlay.assert`: level=1000 / sharingType=2 / visible=true ✅
  - [x] Carbon 注册 `Ctrl+2` 切换 overlay 显隐 — 用户实测切换正常（遥测含 hotkey.ctrl2 记录）✅
  - [x] 遥测落盘 launch / overlay.show 事件 — `telemetry.jsonl` 首行可读 ✅
  - [x] **人检**：Screen Studio 录 10 秒 — 用户确认成片可见 overlay（2026-07-23）✅
- **Exit proof**: ✅ 机检 + 人检全过（2026-07-23）→ **实验 0 关门，生死线通过**
- **Stop condition**: 成片不见 overlay → 停止开发，转排查（sharingType / 窗口级别 / 录制方式），不得进入 P0

### Phase 0：冻结态圈画（硬时限 2026-07-30）
- **Purpose**: 交付"能天天用"的最小核心
- **Entry condition**: 实验 0 人检通过
- **Phase rules**:
  - 超时即砍直线/箭头/发现性提示条保交付（能天天用的丑工具 > 完美的半成品）
  - 未授权录屏权限 → 退化活屏玻璃（首启零弹窗）；授权后自动解锁冻结态
- **Todos**:
  - [x] SCScreenshotManager 冻结快照作 overlay 底图 — 用户实测画面冻结 ✅
  - [x] 矢量自由笔 + Core Graphics 渲染 — 用户实测平滑笔迹 ✅
  - [x] R/G/B/O/Y/P 六色 + `Ctrl+滚轮` 笔宽 — 遥测含 draw.color / draw.width 流水 ✅
  - [x] `Ctrl+Z` 撤销当前层最后一笔 — 用户实测 ✅
  - [x] `Esc` 清场 — 遥测 layer.draw.off trigger=esc ✅
  - [x] 模式可见性（菜单栏状态 + 角落常驻标记）+ 提示条 — 用户实测 ✅
  - [x] 遥测覆盖全部 P0 事件 + schema 文档化 — `docs/telemetry.md` ✅
  - [x] 迭代：画笔光标（ZoomIt 风十字+实心点，用户反馈驱动，两轮定稿）✅
- **Exit proof**: ✅ 用户验收"都顺"+"可以"（2026-07-23，提前 7 天收口）→ **P0 关门**
- **Stop condition**: 2026-07-30 未全勾 → 砍形状/提示条，强制收口

### Phase 1：Snip→剪贴板
- **Purpose**: 区域截图合成标注直达剪贴板
- **Entry condition**: P0 收口
- **Todos**:
  - [x] HotkeyManager 重构多热键分发（Ctrl+2/6）— build 通过 ✅
  - [x] 裸 Snip：Ctrl+6 拖选 → 剪贴板 + 白闪 + Esc 取消 — 用户粘贴验证 ✅
  - [x] 标注 Snip：圈画中 Ctrl+6 合成底图+笔画 — 用户粘贴验证 ✅（PRD 核心诉求）
  - [x] 权限引导：无权限 → snip.denied + 弹窗直达系统设置 — 代码路径就绪
  - [x] 菜单栏状态三态（待命/圈画/Snip）— 用户可见 ✅
- **Exit proof**: ✅ 用户验收"都没有问题"（2026-07-23）→ **P1 关门**
- **Stop condition**: 合成与冻结态坐标系冲突 → 先修坐标系（未触发：复用 CanvasView 离屏渲染，零坐标系风险）

### Phase 2：讲一段录屏
- **Todos**:
  - [x] Ctrl+5 即录/停 → H.264+AAC mp4（SCStream + 麦克风）
  - [x] 菜单栏红点 + 角落计时条可点停（体验红线）
  - [x] 输出目录 JSON 可配（默认 ~/Movies/InkLayer）
  - [x] 遥测 record.* 事件
- **Exit proof**: 代码交付；用户验收待确认（录屏）
- **Stop condition**: "忘了还在录"指示缺失 → 先补指示

### Phase 3：打字层
- **Todos**:
  - [x] Ctrl+3 点击处浮出 NSTextField → 回车烙字
  - [x] IME 安全（有标记文本时不抢回车）
  - [x] 六色 / Ctrl+滚轮字号 / Ctrl+Z 撤销
  - [x] 与圈画/白板可叠加
- **Exit proof**: 代码交付；用户验收待确认
- **Stop condition**: 浮出框别扭 → 后院重估

### Phase 4：白板层 + 轻量缩放
- **Todos**:
  - [x] Ctrl+4 白板（穿透、可叠加）
  - [x] Ctrl+1 两档缩放（2×，光标中心，拖移平移）
  - [x] LayerCoordinator 编排 + Esc 全清
  - [x] InkConstants / InkPalette 逻辑分离
- **Exit proof**: 六件套代码齐；用户人检待确认
- **Stop condition**: 缩放与圈画同开坐标错乱 → 互斥策略（当前各独立窗口，不互斥）

## Dry-Run Findings
- 人检依赖用户操作 Screen Studio：已列为显式 todo，验收前不得自封通过
- 执行中发现：终端无录屏权限 → `screencapture` 自检不可用；机检断言改走遥测落盘（`overlay.assert`：level=1000 / sharingType=2 / visible=true ✅）
- SPM 无 Info.plist：无 Dock 图标用 `setActivationPolicy(.accessory)` 解决；SMAppService 登录自启推迟到打包
- "逐层撤销"P0 仅一层，"当前层最后一笔"语义不变，P3 后自然完整
- P0 冻结态依赖录屏权限：权限引导放 P0，不污染实验 0 的"零弹窗"验证
- `Ctrl+数字` 被虚拟机/远程桌面吞：撞上再做备用键位（PRD §9），不预设

## Final Validation
1. `swift build` 通过（命令）
2. `telemetry.jsonl` 覆盖 launch / 层开关 / snip / record 事件（trace）
3. PRD §7 五个验收框全勾（用户验收）
4. 连续自用 14 天后出具首份遥测报告，执行 §8 砍/留纪律

## First Execution Step
工具链核查 ✅ → 落盘本目标文档 → SPM 脚手架 → 实验 0 五个机检 todo → 交用户做人检。
