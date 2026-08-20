# DoraZoom 双版本发布 TODO

## 发布判断

- **当前状态**：站外完整版 `0.1.0` 已完成 Developer ID 签名、公证、装订和交付校验；Mac App Store 版仍未开始。
- **商店版**：以 Mac App Store 为主要公开渠道，必须启用 App Sandbox，并移除模拟键盘粘贴能力。
- **完整版**：使用 Developer ID、公证和 DMG/ZIP 站外分发，保留完整的 Control+V 兼容能力。
- **共同规则**：两个版本共享业务核心和自动化测试，不在源码中复制两套实现；差异集中在 Xcode target、entitlements、能力开关和发布脚本。

## 发布矩阵

| 项目 | Mac App Store 版 | 站外完整版 |
| --- | --- | --- |
| 分发渠道 | App Store Connect / TestFlight | 私有下载或公开下载 |
| 构建入口 | 后续新增正式 Xcode App target | `Scripts/release-internal.sh` |
| 签名 | Mac App Distribution，由 Xcode Archive 管理 | Developer ID Application |
| 安全能力 | App Sandbox 必须开启 | Hardened Runtime；不强制沙盒 |
| Control+V 模拟粘贴 | 禁用 `CGEventPost(Command+V)`；只复制并提示手动粘贴 | 保留完整兼容模式 |
| 权限 | 屏幕录制、Input Monitoring、麦克风、摄像头逐项沙盒验证 | 按现有权限流程验收 |
| 产物 | Xcode Archive 上传，不提交仓库 | 公证后的 DMG/ZIP，不提交仓库 |
| 验收 | TestFlight + App Review 检查 | Gatekeeper + 真机安装检查 |

## 当前基线

- [x] 原生 SwiftPM macOS 应用，最低 macOS 14
- [x] Xcode 26.6 已安装
- [x] 现有 Swift 自动化测试为 219 项
- [x] `Scripts/release-internal.sh` 已准备为站外完整版发布入口
- [x] 网站发布二进制 `website/public/DoraZoom.zip` 已从仓库移除
- [ ] Mac App Store Xcode App target、App Sandbox entitlements 和 Archive scheme
- [x] Developer ID Application 发布凭据
- [ ] 两个版本的真实 macOS 权限与核心功能验收

## 阶段 1：清理并锁定仓库边界

- [x] 删除可重建缓存、重复素材、无引用网站资源和嵌套仓库
- [x] 将网站设计过程稿归档到仓库外，并生成 SHA-256 校验值
- [x] 保留新增 Swift 源码、测试、`website/lib/` 和正式场景资源
- [x] 忽略 `*.tsbuildinfo`，保持发布二进制不入库
- [ ] 提交前复核所有未跟踪源码和测试均属于当前产品迭代

## 阶段 2：建立共享核心与两个发布壳

- [ ] 保持 `ZoomItMacCore` 为两个版本的共享实现
- [ ] 新增正式 Xcode macOS App target、Archive scheme、AppIcon asset 和商店版 Info.plist
- [ ] 为商店版增加 `com.apple.security.app-sandbox` 及最小必需硬件、文件访问 entitlement
- [ ] 将模拟粘贴能力置于发布风味开关后；商店 target 编译时关闭，完整版开启
- [ ] 为两个发布壳建立独立的签名、Bundle ID、显示名称和权限回归测试，避免 TCC 身份互相覆盖
- [ ] 保留当前手工 `.app` 构建与公证脚本，仅服务站外完整版

## 阶段 3：Mac App Store 沙盒验证

- [ ] 在沙盒环境实测全局快捷键监听与 Input Monitoring 请求
- [ ] 实测静态缩放、实时缩放、圈画、截图、OCR、全景截图和剪贴板复制
- [ ] 实测全屏/区域录屏、暂停继续、麦克风、摄像头和文件导出
- [ ] 确认商店版不调用 `CGEventPost`，UI 明确提示用户手动粘贴
- [ ] 检查容器目录、用户选择文件访问和安全作用域书签行为
- [ ] 记录所有 sandbox violation；不能通过公开 entitlement 合法解决的能力从商店版移除

## 阶段 4：站外完整版验证

- [x] 安装 Developer ID Application 证书
- [x] 配置 `notarytool` 钥匙串 profile，不把凭据写入仓库
- [x] 执行 `Scripts/release-internal.sh` 生成并公证 DMG/ZIP
- [x] 验证签名、Hardened Runtime、staple、Gatekeeper 和 DMG 完整性
- [ ] 真机验证 Control+V 兼容模式及所有辅助功能权限

## 阶段 5：商店资料与交付

- [ ] 锁定首发版本号、Bundle ID、SKU、分类、年龄分级和隐私答案
- [ ] 准备 1024×1024 App Store 图标、16:10 截图、描述、关键词、支持和隐私政策链接
- [ ] 在 App Store Connect 创建 app record，并上传首个 Archive
- [ ] 通过 TestFlight 完成至少一轮外部环境验收
- [ ] 填写 Review Notes，解释屏幕录制、Input Monitoring、麦克风和摄像头用途
- [ ] 提交审核；将审核反馈和修复证据记录在本文件或 `ACCEPTANCE.md`

## 共同发布门禁

- Swift 全量测试通过
- 网站干净安装、lint、build 和测试通过
- 两个版本均不包含缓存、设计过程稿、旧命名或仓库内发布二进制
- 两个签名产物的 Bundle ID、版本、build number、entitlements 和架构符合各自矩阵
- 至少一台真实 Mac 完成首次启动、权限、核心功能、升级和卸载验证
- 未完成项目不得在 README 或官网中表述为已发布能力

## 当前下一步

在独立迭代中创建 Mac App Store Xcode target，并先做一次最小沙盒构建；以真实 sandbox violation 和功能验收结果决定商店版最终能力清单。
