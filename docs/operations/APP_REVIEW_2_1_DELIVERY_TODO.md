# DoraZoom App Review 2.1 — 重新审核交付清单

**App**：DoraZoom：屏幕标注 · macOS 1.0.0（build 6）  
**提交 ID**：`9bcfe909-f166-46d4-807e-68f72bc47dd1`  
**当前状态**：被拒绝 — Guideline 2.1，需要补充信息  
**原因**：Apple 认为该开发者账号的审核历史较少，因此需要更多材料来确认产品。未报告崩溃或具体功能缺陷。

## 完成原则

本次只需要补充证据和说明。不要重新上传构建版本、删除现有 build，也不要点击“更新审核／重新提交”。只有在真机录制中发现实际缺陷时，才需要重新构建。

## 交付清单

### A. 真机演示视频 — 负责人：工作室

- [ ] 使用运行最新可用 macOS 的实体 Mac 录制；不得使用虚拟机。
- [ ] 在“应用程序”文件夹或 Dock 中启动 DoraZoom 前开始录制。
- [ ] 在视频中确认展示的是 DoraZoom 1.0.0（build 6）。
- [ ] 展示应用首次使用时的权限页面和已授予的“屏幕录制”权限；仅在演示全局快捷键时展示“辅助功能”权限。
- [ ] 演示典型主流程：打开 DoraZoom → 缩放或标注屏幕内容 → 区域截图 → 在本地文本应用或浏览器输入框中使用 `Command+V` 粘贴结果。
- [ ] 演示 OCR 识别可见文字，并展示识别结果。
- [ ] 演示屏幕录制：开始、暂停、继续、结束，以及保存或显示录制文件。
- [ ] 明确或直观展示麦克风和摄像头是可选功能；只有主动启用录制音频或画中画时才使用。
- [ ] 不得暴露密码、私信、私人文件、客户资料或无关应用内容。
- [ ] 从头到尾检查视频：所有展示功能正常，无崩溃、卡死或无法解释的重复权限循环。
- [ ] 导出一个文字清楚、可供审核的 MP4 或 MOV 文件；可不配音。

**推荐录制顺序**：3–5 分钟，一镜到底。先在“应用程序”中启动 DoraZoom，展示权限状态；然后在无敏感信息的示例页面标注，使用 `Control+6` 截图、使用 `Command+V` 粘贴，执行 OCR，最后演示录制／暂停／继续／结束并显示保存结果。

### B. 审核文字材料 — 负责人：Codex

- [ ] 准备覆盖 Apple 要求全部六项内容的英文审核回复。
- [ ] 将同一份信息加入“App 审核信息 → 备注”。
- [ ] 明确说明：没有登录、账号创建、用户生成内容、外部支付或 App 内购买。
- [ ] 明确说明：DoraZoom 是一次性买断的 Mac App Store 应用；购买后可使用全部功能，应用内无额外付费功能。
- [ ] 明确说明：截图、OCR 与录屏处理均在本机完成。
- [ ] 明确说明：不使用账号系统、广告、分析 SDK、云端 AI、数据提供商、身份验证服务或支付处理商等外部服务。
- [ ] 确认所有地区功能一致；界面语言根据 macOS 语言偏好显示。
- [ ] 确认应用不属于受监管行业，且不提供受保护的第三方内容。
- [ ] 通过 App Store Connect 提供的附件入口，将真机视频附在审核信息或审核回复中。

### C. App Store Connect 操作步骤 — 负责人：Codex，关键提交前由账号持有人确认

- [ ] 确认仍是 **1.0.0（6）**，且拒绝原因仅为 `2.1.0 Performance: App Completeness`／需要补充信息。
- [ ] 将审核通过的视频上传为 App 审核附件。
- [ ] 保存更新后的“App 审核信息 → 备注”。
- [ ] 在现有 Apple 消息线程中粘贴审核回复。
- [ ] 在发送前核对回复文字、附件文件名和备注字段。
- [ ] 发送回复前，向账号持有人取得即时确认。
- [ ] 点击“更新审核／重新提交”前，向账号持有人取得即时确认。
- [ ] 后续监控 App Store Connect 和 Apple 邮件中的状态变化。

## 提交给 Apple 的英文回复草稿

仅在视频已上传、文件名已确认后使用以下内容。

> Hello App Review team,
>
> Thank you for the opportunity to provide additional information about DoraZoom. We have attached a screen recording captured on a physical Mac running the latest available macOS. The recording begins with launching DoraZoom and demonstrates the typical user flow: permissions, screen zooming and annotation, region capture and paste, OCR, and screen recording with pause/resume and saving.
>
> 1. **Purpose and target audience:** DoraZoom is a native macOS visual-communication utility for creators, educators, presenters, designers, developers, and teams. It helps users direct attention to on-screen content through zooming, annotation, screenshots, OCR, and screen recording.
>
> 2. **Setup and access:** No account, registration, login, sample file, or demo credential is required. Users launch DoraZoom on macOS 14 or later and grant Screen Recording permission when using capture-related features. Accessibility permission is requested only when the user chooses features that require global shortcuts or on-screen interaction. Microphone and camera are optional and are used only when the user enables audio recording or camera picture-in-picture.
>
> 3. **External services:** DoraZoom does not use external services to deliver its core functionality. It has no account system, advertising, analytics SDK, cloud AI inference, authentication service, data provider, or external payment processor. Capture, OCR, and recording processing are performed locally on the Mac.
>
> 4. **Business model:** DoraZoom is a one-time paid Mac App Store app. It has no in-app purchases, subscriptions, locked paid features, or external purchase flow. All app functionality is available after purchase.
>
> 5. **Regional availability:** DoraZoom has the same functionality in all regions. The interface follows the user's macOS language preferences, including Simplified Chinese and English where available.
>
> 6. **Regulatory and third-party content:** DoraZoom is not a regulated-industry service and does not include protected third-party content or require credentials to provide such content.
>
> Please let us know if any additional information is needed. Thank you for your review.

## 本地留存证据

- [ ] 原始视频文件和最终审核上传副本。
- [ ] 已填写“备注”字段的截图。
- [ ] 发送前，已附加视频和已起草回复的截图。
- [ ] Apple 回复时间、审核员反馈和任何新的补充要求。

## 当前阻塞项

- [ ] 尚未选定并附加真机演示视频。
- [ ] 面向 Apple 的回复和更新后的审核备注尚未保存或发送。
