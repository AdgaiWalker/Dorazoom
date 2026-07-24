# InkLayer v1 — 交接文档

> 日期：2026-07-24
> 作者：pair programming session（InkLayer dev）
> 用途：给接手者 / 另一 AI 的工作指南
> 原则：中文表述、少兼容、逻辑分离、不写死

---

## 一、项目是什么

**InkLayer** 是一个 Mac 菜单栏常驻板书层（无 Dock 图标，`setActivationPolicy(.accessory)`）。  
单手 `Ctrl+数字` 热键唤起六件套图层，支持冻结态圈画、打字、白板、轻量缩放、一键录屏、区域截图到剪贴板。

**PRD 锚点**：`# PRD: Mac 屏幕板书层.md`（需求冻结 v1.5）  
**GOAL 文档**：`GOAL.md`（进度追踪，部分条目落后于实际代码）  
**对抗审理报告**：`方案.md`（红蓝对抗 + P0 修法，P0 已落地）

---

## 二、当前进度（截至 2026-07-24）

### ✅ 已完成
| 模块 | 状态 | 备注 |
|---|---|---|
| 实验 0 生死线（Screen Studio 可捕获 overlay） | ✅ 机检+人检双过 | Screen Studio 录 10 秒，成片可见 overlay |
| P0 圈画（冻结态 + 自由笔 + 六色 + 撤销 + Esc） | ✅ | ZoomIt 风光标两轮迭代 |
| P1 Snip（拖选→剪贴板 + 白闪） | ✅ | 矢量合成路径（排除自家 overlay） |
| P2 录屏（SCStream + 麦克风 → MP4） | 代码齐 | **待你实测：Ctrl+5 录 ≥5 秒，QuickTime 能播？** |
| P3 打字（浮出输入框 + 回车烙字 + IME） | ✅ | 单行防竖排错位 |
| P4 白板 + 轻量缩放（Ctrl+1/4） | ✅ | 缩放以进入时光标为中心 |
| `InputOwner` 焦点路由 + Esc 全清 | ✅ | 多窗口同开时快捷键不再假死 |
| `ImageDraw` 统一绘制 + Retina 离屏位图 | ✅ | C1/C3 坐标系修复 |
| `.app` 打包脚本 `scripts/package-app.sh` | ✅ | 日常使用此包 |
| 屏幕录制权限 | ✅ | 你已授权，系统设置里可见 "InkLayer" |

### ⚠️ 待你人工验证（请补填）
| # | 操作 | 预期 | 你的结果 |
|---|---|---|---|
| 1 | `open InkLayer.app` → 启动正常 | 菜单栏出现「墨」 | ? |
| 2 | `Ctrl+5` 录 ≥5 秒 → QuickTime 打开 | 画面+声音都有，时长合理 | ? |
| 3 | 白板 + 圈画 + 打字 → `Esc` | 三层全清 | ? |
| 4 | 画笔 + 烙一字 → `Ctrl+6` 粘贴 | 含笔画和字 | ? |
| 5 | `Ctrl+1` 放大 → 滚轮调倍率 → 再按退出 | 中心不动，手感顺 | ? |

> **若某条不过，交接文档里会标为「阻塞」，别写成已完成。**

### 📦 产物位置
```
InkLayer.app                    ← 日常双击这个
.build/debug/InkLayer           ← 开发调试（不要日常用）
Sources/InkLayer/*.swift         ← 源码（22 个文件）
Resources/Info.plist             ← .app 元数据
scripts/package-app.sh          ← 重打包命令
docs/telemetry.md               ← 遥测 schema
方案.md                           ← 红蓝对抗 + P0 修法（已落地）
GOAL.md                          ← 进度表（部分过时，以本文档为准）
```

---

## 三、怎么构建与启动

### 日常开发（改完代码后）
```bash
cd /Users/happy/Desktop/zoomit
swift build                       # 编译
bash scripts/package-app.sh      # 打 .app（自动调用 swift build）
open InkLayer.app                # 启动
```

### 快速调试（不改代码只想试效果）
```bash
cd /Users/happy/Desktop/zoomit
.build/debug/InkLayer            # 直接跑，但屏幕录制权限列表可能看不到它
```

> **重要**：日常必须用 `InkLayer.app`，否则「解锁冻结态」弹窗找不到程序名。

### 退出
菜单栏点「墨」→「退出 InkLayer」。

---

## 四、架构地图（逻辑分离版）

```
AppDelegate (入口 + 菜单栏)
└── LayerCoordinator (编排器：热键分发 / Esc 全清 / 焦点归属)
    ├── HotkeyManager (Carbon 全局热键 + 防抖)
    │
    ├── DrawLayer (Ctrl+2 · 圈画)
    │     └── CanvasView (渲染 + 鼠标键盘输入)
    │
    ├── TypeLayer (Ctrl+3 · 打字)
    │     └── TypeCanvasView (烙字渲染)
    │
    ├── WhiteboardLayer (Ctrl+4 · 白板)
    │     └── WhiteboardView
    │
    ├── ZoomLayer (Ctrl+1 · 缩放)
    │     └── ZoomView
    │
    ├── SnipLayer (Ctrl+6 · 截图)
    │     └── SnipContainerView (预览 + 暗化选区)
    │
    └── RecordLayer (Ctrl+5 · 录屏)
          └── SCStreamOutput + AVCaptureAudioDataOutputSampleBufferDelegate
```

### 关键设计决策

| 决策 | 原因 |
|---|---|
| `InputOwner` 枚举 | 解决多窗口同开时快捷键「假死」（F4 根因） |
| `ImageDraw` 工具类 | 消除 CG 顶左 vs AppKit 底左翻转（C1） |
| Snip 排除自家 overlay | 避免抓到底图自身导致标注丢失（L5） |
| 麦克风采样率跟设备走 | 避免硬编码 44.1kHz 导致不可播（R2） |
| 裸 Swift 二进制 → .app | 让系统设置「屏幕录制」列表稳定显示（H6） |

---

## 五、已知问题与方案 P1 债

以下来自 `方案.md` 红蓝对抗，**P0 已修，剩余 P1/P2**：

### P1（高频体验）
| ID | 问题 | 现状 | 建议 |
|---|---|---|---|
| H6 | 热键注册失败无 UI 提示 | 只打遥测 | 加 toast 或菜单栏小黄点 |
| M2 | 菜单不显示「谁持有焦点」 | ~~已加~~ `statusPresentation()` 现在返回 focusHint | **已实现**，待你感受 |
| L2 | Zoom 与其它层 z 序不稳定 | 同 level 后 orderFront 盖住先开的 | 给每层固定 level（Zoom = screenSaver+1） |
| Z3 | Zoom grab 无超时 | 卡权限时一直 loading | 加 deadline task |

### P2（边界 / 砍单项）
- 贴边长句输入溢出（C6）：框宽固定 800+，极端情况仍可能出屏
- 多显示器：一律 `NSScreen.main`，外接屏当主屏时不准（PRD 砍单）
- Telemetry 同步写盘微卡：高频笔画时偶发 UI 顿一下（P3）

---

## 六、约束与禁止事项

### 必须遵守
- **中文表述**：UI、注释、文档全部中文
- **少兼容**：macOS 14+，不做旧版兼容
- **逻辑分离**：常量抽 `InkConstants`，调色板抽 `InkPalette`，层业务独立
- **不写死**：输出目录走 JSON 配置，热键可通过外部 JSON 改（发布前再做 UI）

### 禁止
- ❌ 重做 P0 已修项（isBooting 半死锁、图像翻转、Snip 合成、音频采样率）
- ❌ 加新 Phase（活屏态、黑板、设置 UI、视频编辑……PRD 砍单表）
- ❌ 改 Carbon 热键协议（已是免辅助功能权限最优解）
- ❌ 删除遥测（它是证伪判决的数据资产）

---

## 七、下一步唯一目标（本次交接聚焦）

**选 B：清 P1 体验债**（不影响主线，让常用操作更顺手）

具体任务（按优先级）：
1. **H6**：热键注册失败 → 菜单栏小黄点提示
2. **L2**：Zoom layer level 抬高，避免盖住底下圈画/打字
3. **Z3**：Zoom grab 超时保护（30s）
4. **M2**：菜单栏显示「焦点:圈/字/放」（已在代码但未充分测试）

> 若你想换方向（A 自用收口 / C 发布向），告诉我，我立刻改写本节。

---

## 八、Git 基线说明

- **当前状态**：无任何 commit，全是 untracked（`git status -sb` 可见）
- **建议首次提交内容**：
  - `.gitignore`（已有，含 `.build/`, `telemetry.jsonl`, `Movies/`）
  - `Package.swift`
  - `Sources/InkLayer/`
  - `Resources/Info.plist`
  - `scripts/package-app.sh`
  - `docs/telemetry.md`
  - `方案.md`
  - `GOAL.md`（可选，部分过时）
  - `HANDOFF.md`（本文件）
- **绝对不要提交**：`.build/`, `InkLayer.app`, `*.DS_Store`, `~/Movies/InkLayer/`

---

## 九、一句话总结

> **v1 主线已通，权限已授，等待你实测录屏/Esc/Snip/缩放四项；P1 体验债留着等清。**

---

*本文档由 pair programming session 生成，未经修改，保留原文风格。*