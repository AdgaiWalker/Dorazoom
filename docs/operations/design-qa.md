# DoraZoom 官网修复复测

日期：2026-09-14。实现：`website/dist`。本地预览：http://127.0.0.1:4277/ 。本次已修复网站层面的审查问题并完成浏览器回归；尚未部署。

## Findings / 修复结果

| 原问题 | 处理 | 复测证据 |
| --- | --- | --- |
| P1 获取应用路径无终点 | 首屏与页尾明确尚未开放下载，导航改为“下载状态”；新增“保存官网地址”，实际下载指向正式域名的快捷方式。真实安装包仍是发布依赖，不声称已经可以安装。 | mobile-390-hero.png、desktop-release.png、DoraZoom.url |
| P2 320px 工具栏溢出 | 窄画布下两排排列，所有按钮固定 44×44px，颜色点与点击区域分离。 | playground-320.png；320/360/390/768/1440px 的 layout-checks.json，所有按钮都在工具栏内，文档无横向溢出。 |
| P2 手机画布无法读清 | 容器小于 480px 时显示中间卡片局部，逻辑区域 200×220；320px 下按钮文字约 14.2px，390px 下约 18px。保持完整场景坐标，不清除标注。 | mobile-390-playground.png、playground-320.png；实际手机绘制并导出 mobile-export.png。 |
| P2 功能性灰字对比度低 | 使用统一支持文字 #626975 与深色背景支持文字 #b8bdc8。 | contrast.json；五项实测 5.07–8.55:1。 |
| P2 示例价格易混淆 | 在画布外加入可读的“虚构网页，仅用于圈画演示；以下价格不代表 DoraZoom 定价”。 | playground-1440.png、playground-320.png。 |
| P2 教程遗漏截图操作 | 第三步同时显示截图 ⌃6 与粘贴 ⌘V；正文注明 Control + 6 选区截图，再 Command + V 粘贴。 | desktop-workflow.png；快捷键与仓库 README 核对，ModeCoordinator.startSnip 验证区域截图流程。未启动真实 Mac 应用测试。 |

此前报告使用了旧域名 product.iwalk.pro。正式域名现为 https://dora.iwalk.pro/；Vercel 已绑定该域名，但当前 DNS 尚需设置 `A dora.iwalk.pro 76.76.21.21`，因此在 DNS 生效前不把 HTTPS 请求失败视为应用故障。

## 交互与回归

- 浏览器：ego-browser / Chromium；沿用前轮内置 Browser 失败后的工具路径。
- 桌面：1440×1000 CSS px；手机：320/360/390×844；平板：768×1000。deviceScaleFactor=1，保存截图像素尺寸等于视口，无密度归一化处理。
- state：中文、浅色、无需登录；初始圈选、手机指针箭头、生成后、保存、键盘标注、场景切换与视频弹窗。
- 通过：页面身份与非空内容；无框架错误覆盖层；语法、唯一 ID、片段链接和修改差异空白检查。
- 通过：320/360/390/768/1440px 页面无横向溢出且所有工具按钮均处于白色工具栏内。
- 通过：清空 → 手机画箭头 → 生成 → 保存实际 PNG，导出为 1440×900 完整画面，箭头落在正确卡片上。
- 通过：切回桌面后导出图片保持一致，SHA-256 为 `76e7135780562ef558d25c8dd6615b6e824d47470fc57d618fe2fec5bb101ede`；撤销后 Enter 示例恢复为一处标注。
- 通过：保存官网快捷方式，文件内容 `[InternetShortcut]` 与 `URL=https://dora.iwalk.pro/` 正确。未在各操作系统中双击打开此文件。
- 通过：场景方向键切换；视频打开与 Escape 关闭，焦点返回 scene-watch。
- 控制台：本轮运行观察区间内没有 Runtime exception 或 error 日志，见 browser-errors.json。
- 工具回归中，调整手机为桌面宽度后按钮临时处于固定导航下方，自动点击失败；观察位置后滚动回体验区，正常点击通过。未把这一工具定位失败记为应用运行异常。

## 对比度复测

| 表面 | 原值 | 修复后 |
| --- | --- | --- |
| 补充你的想法 | 3.24:1 | 5.53:1 |
| 拖动画一个圈 | 2.20:1 | 5.07:1 |
| 体验边界说明 | 3.57:1 | 5.53:1 |
| 未选场景标签 | 2.68:1 | 5.20:1 |
| 下载区说明 | 3.91:1 | 8.55:1 |

以上为正常大小文字与实际纯色背景计算。不是整站 WCAG 合规声明。

## 五项必查表面

- **字体 / 排版**：沿用 PingFang SC / DM Sans 字体栈。手机首屏文案缩短，画布改为局部视图；目标按钮在最窄已测视口中达到约 14.2px。未验证跨平台字体回退。
- **间距 / 布局**：沿用既有圆角、浅阴影与区块节奏；桌面保留双列，手机工具栏两排。完整画布与局部画布切换时标注与导出保持一致。
- **颜色 / token**：保留红色强调与黑白灰基调；五处报告中的功能性弱对比文字均超过 4.5:1。
- **图像 / 素材**：继续使用现有产品 PNG、视频和品牌资源，无新资产替换。手机放大的是既有示例的一部分，导出仍是完整场景，实际 PNG 已打开检查。
- **文案 / 内容**：补齐预发布状态、示例价格边界与截图快捷键。没有捏造发布包或开放下载日期。

## 实际浏览器截图

图片目录：`/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/`。

### 首屏与手机体验

![手机首屏](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/mobile-390-hero.png)

![390px 圈画](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/mobile-390-playground.png)

![320px 工具栏](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/playground-320.png)

### 桌面体验、教程与发布状态

![桌面圈画](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/playground-1440.png)

![教程](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/desktop-workflow.png)

![发布状态](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/desktop-release.png)

![场景标签](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/desktop-scenes.png)

### 手机实际导出的完整画面

![手机导出](/Users/happy/Desktop/zoomit/website/audit/2026-09-14-fix/mobile-export.png)

## Comparison history / 证据限制

1. 第一轮审查：无已批准的官网来源设计；完成实际页面 UX 审查，1 项 P1 与5 项 P2。原报告保存在 `website/audit/2026-09-14/original-report.md`，原始截图保留。
2. 第二轮修复：依据用户“修复”的明确指令，对以上问题作定点修改；布局、颜色、坐标与导出、发布状态、教程的复测证据见本报告。不是按旧截图逐像素还原。
3. source visual truth path：仍缺失。旧截图是缺陷证据，不是假定的已批准视觉目标。
4. implementation screenshot path：上方保存并检查的截图。source pixel dimensions：不适用；实现视口与像素尺寸见环境说明。
5. full-view comparison evidence：未进行独立设计目标与实现的保真度并排比较；没有来源，因此不能声称严格 design QA 通过。
6. focused region comparison evidence：对工具栏、画布、教程与说明文字作实际截图检查和尺寸 / 对比度测量，但没有独立来源可作局部保真度比较。
7. `desktop-hero.png` 是圈线动画未完成的中间帧，`mobile-workflow.png` 是视口变化期间的中间帧，两者不作为验收截图。上述正式使用的截图已逐一打开确认。

## Open Questions / Remaining work

- 真实 Mac 安装包仍未正式发布：网站已如实说明，正式下载按钮需在取得合法、确认的发布地址后接入。
- 本轮没有部署，不声称在线网站已更新。
- 尚无独立官网设计稿，因此保真度比较仍不具备条件；这不影响本次已授权的定点修复与功能验证。
- 未进行真实 iOS / Safari、屏幕阅读器、OS 剪贴板粘贴、官网快捷方式跨系统打开、完整网络故障与性能测试。

## Implementation Checklist

- [x] 下载状态提前说明，提供保存官网地址。
- [x] 手机工具栏容器内排列、44px 目标。
- [x] 手机局部放大、完整导出与跨宽度保留标注。
- [x] 功能性文字对比度提高并实测。
- [x] 价格示例边界及截图快捷键补齐。
- [ ] 有正式安装包后接入应用下载。
- [ ] 有已批准设计稿后完成保真度比较。

final result: blocked

严格 design QA 阻塞原因：source visual target 缺失；实际应用下载仍依赖正式发布。网站定点修复的浏览器回归已通过，本次修复工作完成。
