# Goal Document: 异步层 Esc 取消闭环

## Go / No-Go
- **Judgment**: Go
- **Reason**: 代码证据已证明 Coordinator 漏掉 loading 状态，而 Draw/Zoom 自身已有取消能力；可通过纯状态测试先约束、再以小范围重构修复。

## Target Outcome
用户在圈画、缩放或 Snip 截图尚未返回时按 Esc，pending 激活立即失效；任何迟到的截图结果都不能在清场后重新显示 overlay。三个异步入口共用一份经过测试的激活语义，不增加运行时依赖，也不改截图、绘制或媒体热路径。

## Goal Definition
- **Type**: quality / technical
- **Boundary**: Draw/Zoom/Snip 的 idle/loading/active 生命周期与 `LayerCoordinator.clearAll`
- **Non-goals**:
  - 不重写 `FreezeCapture`
  - 不引入通用 Layer 协议、Actor 或依赖注入框架
  - 不修改录屏、Snip、IME、视觉样式和产品热键
- **Deferred work**:
  - RecordLayer `@unchecked Sendable` 的并发取证
  - `lastVideoPTS` 跨录制会话重置的独立验证
- **Verification rule**: 新测试必须先因缺少共享激活状态而失败，再转绿；完整测试、warnings-as-errors debug/release build 和静态路径检查通过
- **Evidence source**: XCTest、SwiftPM 构建、源码调用链、PRD/方案不变量
- **Pass criteria**:
  - idle → loading → active → idle 合法
  - loading → Esc/cancel → idle 后，旧 token 无法激活
  - Draw/Zoom/Snip 的 loading/active 均被 Coordinator 计入 clearAll
  - Snip loading 时重复触发不再启动第二次 capture
  - Draw/Zoom 不再各自维护 `isActive + isLoading + activateToken`
- **Confidence note**: 纯状态测试能证明迟到 token 被拒绝；真实权限对话框与 overlay 视觉仍需人检
- **Judgment owner**: 状态与构建由测试命令判定；真实 UI 由用户验收

## Current State
- 基线 `swift test -Xswiftc -warnings-as-errors`：2 tests，0 failures
- `DrawLayer.escape()` 在 `isActive || isLoading` 时可取消，但 Coordinator 仅在 `draw.isActive` 时调用
- `ZoomLayer.escape()` 同样支持 loading 取消，但 Coordinator 仅在 `zoom.isActive` 时调用
- `startSnip()` 在 capture 完成前仍是 inactive，Esc 无法取消且重复热键会并发 capture
- 两层各自重复维护三个状态字段及 token 失效逻辑
- PRD 要求 Esc 关闭所有层；`方案.md` 的 I2/I6 要求“Esc 永远清场、异步启动可取消”

## Plan Rewrite Notes

| Existing item | Decision | Reason |
|---|---|---|
| 上轮“录屏是最痛中心” | keep as completed | 录屏四态已落地并有测试 |
| 上轮“只剩人检” | rewrite | 对抗复查发现自动化可证明的 loading 取消漏洞 |
| Actor 化录屏 | defer | 没有新竞态证据，不抢占确定性漏洞 |
| 通用 Layer 协议 | remove | 不能解决 loading token 竞态，反而扩大改动面 |
| Snip pending capture | add to current scope | 红队证明它破坏同一个 Esc/I6 不变量 |

## Drift Diagnosis
- **Goal drift**: 若转去拆 RecordLayer，会偏离已复现的 Esc 取消问题
- **Phase drift**: 先写共享抽象再找用途会倒置证据；必须先 RED
- **Validation drift**: “有 token”不等于“Coordinator 会调用取消”；需同时验证状态与调用条件
- **Compatibility drift**: 无公共 API；内部调用可直接迁移
- **Cleanup drift**: 不顺手处理 Snip、Telemetry 或多显示器

## Priority Rationale
- Esc 后 overlay 回弹直接破坏核心不变量，比样式和文件长度问题优先
- Draw/Zoom/Snip 编码同一套 pending-token 决定，合并能减少变化放大；但只合并状态，不合并功能层

## Assumptions and Open Decisions

| Item | Status | Impact | Owner / Next step |
|---|---|---|---|
| Draw 的 nil 截图仍进入 live-glass active | confirmed | 状态机必须允许 nil 结果激活 | `DrawLayer.show` |
| Zoom 的 nil 截图回 idle 并提示权限 | confirmed | 需要按 token 失败转换 | `ZoomLayer.activate` |
| Esc 可在 loading 时产生一次 off 遥测 | assumed | 不影响用户行为；遥测语义后续可细分 | 本轮不扩 schema |

## Phases

### Phase 1: RED — 冻结异步取消语义
- **Purpose**: 让测试先证明“取消后旧结果不得激活”
- **Entry condition**: 现有测试全绿
- **Phase rules**:
  - 只新增测试，不修改生产代码
  - 不 mock AppKit 或 ScreenCaptureKit
- **Todos**:
  - [x] 添加 idle/loading/active 与迟到 token 测试
    - **Surface**: `Tests/InkLayerTests`
    - **Proof**: 测试因 `ActivationLifecycle` 不存在而失败
    - **Depends on**: none
- **Exit proof**: RED 失败只指向缺失的生产状态模型
- **Stop condition**: 测试需要真实屏幕权限

### Phase 2: GREEN — 最小状态模型
- **Purpose**: 用单一状态源表达两个层共享的激活语义
- **Entry condition**: RED 原因正确
- **Phase rules**:
  - 只实现测试要求的状态与 token 守卫
  - 不接入 AppKit 层
- **Todos**:
  - [x] 实现 `ActivationLifecycle`
    - **Surface**: production Swift
    - **Proof**: 目标测试转绿
    - **Depends on**: Phase 1
- **Exit proof**: 新测试全绿
- **Stop condition**: 状态模型需要了解窗口或截图类型

### Phase 3: REFACTOR — 接入 Draw/Zoom/Snip/Coordinator
- **Purpose**: 删除重复状态字段并闭合 Esc 调用链
- **Entry condition**: Phase 2 绿
- **Phase rules**:
  - 保持 Draw 的 live-glass 与 Zoom 的 denied 语义
  - 不改变截图调用次数和渲染热路径
- **Todos**:
  - [x] Draw/Zoom 改用共享生命周期
    - **Surface**: `DrawLayer.swift`, `ZoomLayer.swift`
    - **Proof**: 搜索确认重复三字段消失
    - **Depends on**: Phase 2
  - [x] clearAll 覆盖 loading 与 active
    - **Surface**: `LayerCoordinator.swift`
    - **Proof**: 静态调用检查 + 全量测试
    - **Depends on**: shared lifecycle
  - [x] Snip capture 使用同一 token 守卫
    - **Surface**: `LayerCoordinator.swift`
    - **Proof**: 重复 start 被拒绝、Esc 使迟到结果失效的静态调用链 + 全量测试
    - **Depends on**: shared lifecycle
- **Exit proof**: 测试、debug/release 构建通过
- **Stop condition**: 必须改变用户可见 toggle 行为

### Phase 4: 对抗复验与报告
- **Purpose**: 攻击新边界，记录保留/砍除项和残余风险
- **Entry condition**: Phase 3 全绿
- **Phase rules**:
  - 不把未跑的真实 UI 剧本写成通过
- **Todos**:
  - [x] 更新对抗审理报告与 TDD 证据
    - **Surface**: docs
    - **Proof**: 文件行号、RED/GREEN 命令、Razor Map
    - **Depends on**: Phase 3
- **Exit proof**: 报告明确红队攻击、蓝队防御、残余风险和人检步骤
- **Stop condition**: 证据与结论不一致

## Dry-Run Findings
- 只给两个 Layer 添加 `isActiveOrLoading` 可最小修 bug，但无法用纯测试约束迟到 token，也保留两套相同状态决定。
- 把截图统一搬到 Coordinator 会让它同时拥有业务编排和捕获生命周期，边界更浅，排除。
- 共用小型值状态机只吸收相同知识，不要求 Draw/Zoom 实现通用协议，符合轻量化。
- clearAll 必须先把 loading 计入 `any`，否则即使取消成功也不会留下 `clear.all` 行为证据。

## Final Validation
1. `swift test -Xswiftc -warnings-as-errors`
2. `swift build -c release -Xswiftc -warnings-as-errors`
3. 搜索确认 Draw/Zoom 不再各自声明 `isLoading` / `activateToken`
4. 搜索确认 clearAll 覆盖 Draw/Zoom/Snip pending 状态
5. 用户人检：Ctrl+1/2/6 后立刻 Esc，等待截图超时窗口后 overlay 不回弹

## First Execution Step
新增 `ActivationLifecycleTests`，先观察缺失类型导致的 RED。
