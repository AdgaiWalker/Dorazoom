# 遥测 Schema（JSONL 事件流）

本地明文、零网络请求。默认路径 `~/Library/Application Support/InkLayer/telemetry.jsonl`，
可用环境变量 `INKLAYER_TELEMETRY_PATH` 覆盖（指向 iCloud Drive 目录即得多机同步）。

每行一个 JSON 对象：

| 字段 | 类型 | 说明 |
|---|---|---|
| `ts` | string | ISO8601 时间戳 |
| `event` | string | 事件名（见下表） |
| `props` | object? | 事件属性（可选） |

## 事件表

| event | props | 触发时机 |
|---|---|---|
| `app.launch` | — | 应用启动 |
| `layer.draw.on` | `mode`: `frozen` / `live-glass`；`afterEsc`?: 秒（≤10 才记录） | Ctrl+2 唤起圈画 |
| `layer.draw.off` | `trigger`: `hotkey.ctrl2` / `esc`；`strokes`: 本次笔画数 | 关闭圈画层 |
| `draw.stroke` | `points`: 点数；`width`: 笔宽 | 落笔完成一笔 |
| `draw.color` | `key`: r/g/b/o/y/p | 换色 |
| `draw.width` | `width`: 新笔宽 | Ctrl+滚轮 |
| `draw.undo` | — | Ctrl+Z 撤销一笔 |
| `freeze.capture_failed` | `error` | 已授权但截图失败 |
| `snip.start` | `mode`: `overlay-draw` / `frozen` / `live+grab`；`withStrokes`: 带入笔画数 | Ctrl+6 进入 Snip |
| `snip.done` | `w` / `h`: 选区尺寸（pt） | 合成成功入剪贴板 |
| `snip.cancel` | `reason`: `esc` / `tiny-selection` | 取消 Snip |
| `snip.denied` | — | 无录屏权限触发 Snip，弹权限引导 |
| `record.start` | `mic`: `on` / `off` | Ctrl+5 开始录制 |
| `record.stop` | `duration`: 秒；`bytes`: 文件大小 | 正常停止落盘 |
| `record.denied` | — | 无录屏权限触发录屏 |
| `record.mic_denied` | — | 麦克风被拒，录无声 |
| `record.error` | `error` / `duration` / `bytes` | 录制或落盘失败（文件已删） |
| `layer.type.on` / `layer.type.off` | off 含 `trigger` / `stamps` | Ctrl+3 打字层 |
| `type.field.open` | — | 浮出输入框 |
| `type.stamp` | `chars` | 回车烙字上屏 |
| `type.color` / `type.fontSize` / `type.undo` | 同名 | 打字层快捷操作 |
| `layer.whiteboard.on` / `layer.whiteboard.off` | off 含 `trigger` | Ctrl+4 白板层 |
| `layer.zoom.on` / `layer.zoom.off` | on 含 `scale`；off 含 `trigger` | Ctrl+1 缩放层 |
| `zoom.denied` | — | 无录屏权限触发缩放 |
| `clear.all` | `trigger` | Esc 全清 |
| `permission.screen.open_settings` | — | 用户点击"解锁冻结态"或 Snip 引导"去授权" |
| `hint.eval` | — | （保留位） |
| `overlay.assert` | `level` / `sharingType` / `visible` | 实验 0 自检（已退役） |

## 分析口径（对接 PRD §8 / §9）

- **活屏回魂代理指标**：`layer.draw.on` 且 `props.afterEsc` 存在（Esc 清场后 10 秒内重进圈画）的频次。
  频次达标 → 开发活屏态。
- **层类功能频率审判**：`layer.<name>.on` 合计，遥测满 14 天 <10 次 → 砍。
- **图层组合**：同一次会话中多个层同时处于 on 的记录（P3 起有意义）。
- **应急类（Snip/录屏）**：只记录触发与成功，不做频率审判。
