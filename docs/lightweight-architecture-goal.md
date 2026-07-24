# Goal Document: InkLayer 轻量架构优化

## Go / No-Go
- **Judgment**: Go
- **Reason**: 当前代码可构建，产品边界已由 PRD 冻结；审查发现的改动可局限于内部状态、重复路径和测试护栏，不需要改变热键、窗口、媒体格式或用户流程。

## Target Outcome
在保持六件套行为、AppKit/ScreenCaptureKit 性能路径和零第三方依赖不变的前提下，让录屏生命周期只能处于一个合法状态，删除重复的跨层通知与文字渲染实现，并用自动化测试约束最容易回归的状态转换。

## Goal Definition
- **Type**: quality / technical
- **Boundary**: `RecordLayer` 生命周期、`LayerCoordinator` 输入归属通知、`TextStamp` 渲染复用、相关 SwiftPM 测试
- **Non-goals**:
  - 不引入统一 `Layer` 协议、共享巨型画布或依赖注入框架
  - 不重写 ScreenCaptureKit / AVFoundation 媒体管线
  - 不改变热键、UI 文案、遥测事件、文件格式和用户流程
  - 不实现 PRD 已明确砍掉的多显示器、设置 UI、自动更新
- **Deferred work**:
  - Telemetry 异步批量写入；没有实测卡顿证据前不以耐久性换吞吐
  - Actor 化录屏管线；等竞态证据或更严格 Swift 并发模式再做
  - 通用 Layer 协议；等层类型继续增长且出现真实扩展压力再证明
- **Verification rule**: 状态机测试先红后绿；全量 `swift test`、debug/release build 通过；无新增依赖和警告
- **Evidence source**: Swift Testing / XCTest 结果、SwiftPM 构建、源码搜索与 diff
- **Pass criteria**:
  - 录屏状态仅有 idle / starting / recording / stopping，非法转换被拒绝
  - `LayerCoordinator` 每次层状态回调只负责一次状态刷新
  - 屏幕与 Snip 预览共用同一文字烙印绘制实现
  - `swift test`、`swift build`、`swift build -c release` 全部通过
- **Confidence note**: 自动化测试可可靠证明纯状态转换与构建完整性；真实录屏、IME 和视觉一致性仍需用户人检，不能由单元测试冒充
- **Judgment owner**: 自动化项由测试/构建命令判定；真实媒体与视觉体验由用户验收

## Current State
- 19 个 Swift 源文件，约 2,026 行非空/非整行注释代码；debug 可执行文件约 1.01 MB
- `swift build` 通过；`swift test` 因仓库没有测试目标而失败
- `RecordLayer` 用 `isBooting` / `isRecording` / `isSealing` 三个布尔值表达互斥阶段，并在主线程、异步 Task 和录屏 I/O 队列间更新
- `LayerCoordinator` 的 `claimInput` / `releaseInput` 与各层回调都会通知状态变化，draw/type toggle 还会重复 claim
- `CanvasView` 与 `TypeCanvasView` 各自编码同一 `TextStamp` 绘制规则
- 旧 `方案.md` 的若干 P0 结论已被实现修复，不能继续当作当前代码事实

## Priority Rationale
- 先测试录屏状态转换：它是最小、纯粹、可自动验证的高风险切片
- 再替换布尔组合：让非法状态在类型层消失，不触碰媒体热路径
- 最后做重复路径收敛：均为行为保持型重构，可由测试和全量构建兜底

## Assumptions and Open Decisions

| Item | Status | Impact | Owner / Next step |
|---|---|---|---|
| 六件套仍是固定产品边界 | confirmed | 不为假想插件化引入协议层 | PRD §5 |
| 录屏生命周期四态足够 | assumed | 若未来增加暂停/恢复再扩展枚举 | 状态测试 + 现有调用链 |
| 状态栏重复刷新没有用户可见语义 | confirmed | 可安全删除重复通知 | `refreshStatus()` 仅重绘菜单栏 |
| 真实录屏与 IME 无法在当前单元测试稳定自动化 | confirmed | 保留人检门 | 用户验收 |

## Phases

### Phase 1: 冻结状态契约
- **Purpose**: 先定义录屏合法转换，避免重构时凭感觉改行为
- **Entry condition**: 当前 debug build 通过
- **Phase rules**:
  - 只新增测试目标和失败测试，不先写生产实现
  - 测试纯状态行为，不模拟 ScreenCaptureKit
- **Todos**:
  - [x] 添加录屏生命周期合法/非法转换测试
    - **Surface**: `Package.swift`, `Tests/InkLayerTests`
    - **Proof**: `swift test` 因目标类型尚不存在而正确失败
    - **Depends on**: none
- **Exit proof**: RED 失败指向缺失的生命周期实现，而不是环境或语法问题
- **Stop condition**: 测试必须启动真实录屏或依赖权限

### Phase 2: 最小状态实现
- **Purpose**: 用单一枚举替代三个可组合布尔值
- **Entry condition**: RED 已确认
- **Phase rules**:
  - 不改媒体编码、采样率、帧率和输出格式
  - 所有状态写入通过生命周期对象
- **Todos**:
  - [x] 实现四态生命周期并接入 `RecordLayer`
    - **Surface**: production Swift
    - **Proof**: 目标测试转绿
    - **Depends on**: Phase 1
- **Exit proof**: 生命周期测试通过，`RecordLayer` 不再声明三个状态布尔值
- **Stop condition**: 接入要求改变用户可见的 toggle 语义

### Phase 3: 去重而不加层
- **Purpose**: 删除已确认的重复工作和重复知识
- **Entry condition**: Phase 2 全绿
- **Phase rules**:
  - 不新增通用 Layer 协议或框架
  - 保持文字属性、绘制选项和坐标不变
- **Todos**:
  - [x] 收敛 Coordinator 重复 claim / status 通知
    - **Surface**: `LayerCoordinator.swift`
    - **Proof**: 搜索确认单一通知路径 + 全量测试/构建
    - **Depends on**: Phase 2
  - [x] 让两个画布共用 `TextStamp` 绘制实现
    - **Surface**: `TypeLayer.swift`, `CanvasView.swift`
    - **Proof**: 搜索确认单一绘制决策 + 全量测试/构建
    - **Depends on**: Phase 2
  - [x] 删除无效 monitor 状态和重复赋值
    - **Surface**: `TypeLayer.swift`
    - **Proof**: 编译与源码搜索
    - **Depends on**: Phase 2
- **Exit proof**: `swift test` 与 debug build 通过
- **Stop condition**: 任一去重需要改变窗口焦点、IME 或 Snip 合成语义

### Phase 4: 全量验证
- **Purpose**: 证明轻量化没有以构建或性能配置退步为代价
- **Entry condition**: 所有代码改动完成
- **Phase rules**:
  - 不把真实媒体人检伪装成自动通过
- **Todos**:
  - [x] 运行 debug/release build 与测试
    - **Surface**: 全项目
    - **Proof**: 命令退出码 0、无警告
    - **Depends on**: Phase 3
  - [x] 比较源码、依赖、产物尺寸与关键调用路径
    - **Surface**: 架构报告
    - **Proof**: 前后数据与 diff
    - **Depends on**: Phase 3
- **Exit proof**: 所有自动化门通过，剩余人检项明确列出
- **Stop condition**: release 构建或现有功能编译失败

## Dry-Run Findings
- 测试目标需要依赖可执行目标；SwiftPM 支持 `@testable import InkLayer`，无需拆库或新增运行时模块
- 若把全部层抽成协议，会增加适配器和 mock，却不能减少当前六个固定层的产品复杂度，故排除
- 若把录屏拆成 capture/writer/ticker 三个公开模块，会暴露更多生命周期排序知识，故本轮只收紧内部状态
- Telemetry 的同步 I/O 是潜在性能点，但没有 trace 证明且事件多在操作完成时产生；本轮选择保留耐久语义

## Final Validation
1. `swift test`
2. `swift build`
3. `swift build -c release`
4. 搜索确认无 `isBooting` / `isSealing` 状态布尔值、无重复 `TextStamp` 绘制代码、无无效 `keyMonitor`
5. 用户后续人检：开始/停止/连续两次录屏、圈画+打字焦点、Snip 中文烙字一致性

## First Execution Step
新增只描述录屏合法状态转换的测试并运行 RED；确认失败原因正确后才写生产实现。
