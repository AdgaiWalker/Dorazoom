# DoraZoom 1.0.0 低摩擦体验技术方案

> 保留现有 Swift/AppKit 与截图、标注、录屏核心，集中重构启动入口、权限流程、文件访问和设置。
> 不重写整个应用，不拆中英文包。
> 本文档是第一版方案的**核对修订版**：代码落点已逐条对照工作区核实，三处与代码现状冲突的表述已按 2026-09-15 的确认结果改写。

## 一、代码现状与问题

核对源码后，主要问题有明确落点：

| 现状 | 落点 | 影响 | 改造方向 |
|---|---|---|---|
| 重复启动通知直接打开设置，缺少明确的重新打开入口 | `App/SingleInstance.swift:6,27`、`App/AppDelegate.swift:161-166` | 用户点击应用后不知道如何开始 | 统一打开操作面板 |
| 全仓没有 `applicationShouldHandleReopen` | `App/AppDelegate.swift` | 应用已运行时再次双击，无任何可见响应 | 补齐重新打开处理 |
| 屏幕权限用布尔值和"本次已提示"判断 | `Permissions/PermissionService.swift:4-6,110-123,176-177` | 无法清楚区分等待、拒绝、取消和需要重启 | 权限状态机 |
| 保存文件夹只记录路径 | `Settings/SettingsStore.swift:110`（`snipSaveDirectory: String`） | 沙盒重启后访问可能失败 | 持久化文件夹授权 |
| 商店 entitlement 不含用户选择文件读写与 app-scoped bookmark | `Scripts/ZoomItStore.entitlements` | 沙盒下写入用户选择目录会被拒绝 | 补齐两项 entitlement |
| 设置集中在大型窗口控制器中 | `Settings/SettingsWindowController.swift`（1893 行） | 布局和交互难以一致维护 | 拆分页面与公共控件 |
| 本地化已有统一入口，但仍有硬编码英文 | `Core/AppLocalization.swift` | 出现中英混杂 | 完整语言策略和资源检查 |
| 首次缺少登录启动偏好时默认开启 | 已修复：`AppSettings.defaults()` 为 `false`，`AppDelegate:31-37` 仅在系统已注册时迁移为 `true` | — | 保持现有行为（无需再改） |
| 应用无 Dock 图标，启动后不显示任何窗口 | `ZoomItMacApp/main.swift`（`.accessory`）、`AppDelegate.applicationDidFinishLaunching` | 首次启动对用户是"无反馈" | 操作面板 |

方案与工作区已有部分修复重叠，但**不能据此认为已安装版本也已修好**。

## 二、整体结构

所有入口走同一条执行链，避免菜单、快捷键和面板各自处理权限：

```text
操作面板 / 菜单栏 / 快捷键
            ↓
      AppController（扩展，不新增层）
            ↓
   PermissionGate（权限流程状态机）
            ↓
      ModeCoordinator（复用现有功能）
            ↓
    结果预览 → 复制 / 保存 / 继续标注
                         ↓
                  FileAccessService（新增）
```

**修订点 1（分层）**：原方案的 `ActionCoordinator` 与现有 `AppController` 处于同一层。`AppController`（108 行）已经是"菜单/快捷键 → `ModeCoordinator`"的命令路由层，再插入一层会造成四层叠加且两处都能触发动作。确认结果为**由 `AppController` 承担该职责**：不新增第四层，权限门控与文件授权编排直接加在 `AppController` 上。

`AppDelegate` 继续负责组装和生命周期，不承载更多业务判断。

## 三、六项改造

### 1. 统一启动入口

新增 `LauncherWindowController`，用原生 AppKit 提供放大、标注、截图识字、录屏四个入口；启动行为收敛到 `AppController` 的重新打开处理。

启动规则：

- 用户主动启动：显示操作面板。
- 应用已运行后再次打开：激活同一个面板。
- 用户已开启登录启动：后台进入菜单栏，不抢焦点。
- 关闭面板：应用继续运行。
- 正在录制时重新打开：展示录制状态，不重复开始录制。

在 `AppDelegate` 补齐 `applicationShouldHandleReopen`，并把 `SingleInstance` 的通知从"打开设置"调整为"显示统一入口"。

**注意**：应用以 `.accessory` 激活策略运行，没有 Dock 图标，重新打开时不会自动抢焦点，需要显式 `activate`；验收项"双击应用、菜单栏操作、快捷键执行结果一致"要在这个前提下解释。

### 2. 权限改为可恢复流程

整合现有 `PermissionService`、权限中心与重启协调器，集中管理：

```swift
enum PermissionGateState {
    case available            // 已授权，可直接执行
    case needsUserAction      // 从未询问过，需要发起系统授权
    case denied               // 系统明确报告已拒绝
    case requesting           // 正在请求中
    case waitingForSettings   // 已引导到系统设置，等待用户返回
    case requiresRestart      // 已授权但需要重启应用才生效
    case unavailable          // 该能力在当前构建中不可用
}
```

**修订点 2（状态机补 `denied`）**：原方案给的是 6 态、没有"已拒绝"。屏幕录制权限确实无法区分——`CGPreflightScreenCaptureAccess()` 只返回布尔值，不能据 `false` 认定用户拒绝；但麦克风与摄像头走 `AVCaptureDevice.authorizationStatus(for:)`，系统**能**明确报告 `.denied`。而验收项里有"拒绝权限后其他功能仍可用"和"拒绝、恢复、保存失败都有明确出口"，没有 `denied` 就无法表达。因此状态机按权限种类分别求值：屏幕录制只能落到 `needsUserAction` / `waitingForSettings` / `requiresRestart`，媒体权限才可能落到 `denied`。

具体规则：

- 启动只检查，不主动索要权限。
- 点击功能后，仅请求该功能实际需要的权限。
- 同一时间只允许一个授权流程，连续点击不重复弹窗。
- 取消后结束本次操作；再次主动点击时仍能继续。
- 从系统设置返回时重新检查，不循环打开系统设置。
- 普通截图可以在权限生效后恢复选择区域；录屏需要再次点击确认，不自动开始录制。
- 需要重启时明确提示，存在录制或未保存结果时先保护数据。

商店版保留截图后的 Ctrl+V 兼容，因此权限中心真实读取输入发布权限；DemoType 和快捷键兜底仍不进入商店包。麦克风、摄像头跟随功能开关请求。

### 3. 正确记住文件夹授权

新增 `FileAccessService`，替换仅保存 `snipSaveDirectory` 字符串的实现（落点：`SettingsStore.swift:110,488-489,551`、`ImageExporter.swift:38,67-97`、`SnipController.swift:487`、`ZoomCanvasView.swift:874,1010`）。

流程：

1. 用户通过系统文件夹选择器选择保存位置。
2. 保存 security-scoped bookmark。
3. 导出前解析 bookmark，获取作用域访问。
4. 写入结束后释放访问；录制导出期间保持访问有效。
5. bookmark 过期时尝试更新；无法恢复时，请用户重新选择该位置。

商店 entitlement 增加 `com.apple.security.files.user-selected.read-write` 与 `com.apple.security.files.bookmarks.app-scope`，限制在用户授权范围内。这是 Apple 提供的沙盒持久文件访问机制。[Apple 文件访问说明](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

迁移旧设置时保留路径作为选择提示，**不把旧路径当作有效授权**。保存失败保留结果，提供"重新选择位置"和"另存为"，不能静默丢失。现有 `ImageExporter.writeToDirectory` 在失败时只弹 `NSAlert(error:)`（`ImageExporter.swift:72-76,81-86`），不满足"不能静默丢失"，需要改成带出口的失败反馈。

### 4. 单包中英文

沿用 `AppLocalization` 和现有翻译资源，新增持久化选项：

```swift
enum AppLanguage: String, Codable {
    case system
    case simplifiedChinese
    case english
}
```

语言优先级为：应用内选择 → 系统语言偏好 → 英文兜底。

**修订点 3（语言范围）**：原方案"单包中英文"容易被读成只保留中英两种语言，但仓库现状是 10 种——`AppLocalization.supportedLocaleIdentifiers`、`Resources/*.lproj`（10 个）、`Localizable.xcstrings`、`Info.plist` 的 `CFBundleLocalizations`、以及 `docs/app-store/metadata/` 的 10 份商店文案。确认为：

- **手动切换**只提供"跟随系统 / 简体中文 / English"三项，即上面这个枚举。
- **跟随系统**时走 `resolvedLocaleIdentifier`，继续覆盖现有全部 10 种语言。
- 已上架的 10 种商店语言资料保持不变，不向下收窄。

其余规则：

- 默认跟随系统；不根据 IP 或销售地区判断。
- 切换时刷新菜单、面板和设置，不影响录制与截图状态。
- 系统授权窗口遵循 macOS 自身语言机制。
- 所有可见文案进入本地化资源，包括隐私、条款、支持和错误提示。
- 删除"覆盖英文资源为中文"的打包方式。
- 测试使用可注入语言配置，避免只在英文测试环境下验证。

### 5. 设置组件化

保留原生 AppKit，拆为四个页面控制器：

- 通用
- 快捷键
- 截图与录制
- 隐私与权限

共用表单行、分组标题、说明文字和状态行组件。统一采用 Auto Layout、顶部对齐、可换行说明和内容滚动。

快捷键录制只暂停必要的快捷键监听，完成或取消后立即恢复；冲突显示在对应行，提供恢复默认。原有设置键尽量沿用，新增字段提供兼容默认值，不整体重置用户配置。

### 6. 稳定构建与安装

统一以商店工程生成正式候选版本：

- 品牌名与用户可见版本保持 `DoraZoom 1.0.0`。
- 构建号仍保留在内部发布信息中，与产品版本分开管理；不能从包里删除。[Apple 版本字段说明](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)
- 每次构建记录源码提交、构建号、签名和产物校验值。
- 开发测试产物与正式应用隔离，不反复覆盖用户安装。
- 正式候选通过 TestFlight 验收，再用于商店提交。
- 不通过临时重签、修改已签名资源或清空系统授权来掩盖问题。

**待办**：工作区未提交的 `CURRENT_PROJECT_VERSION` 与 `ZOOMIT_BUILD_NUMBER` 已从 `4` 改成 `4.0.1`，这是把构建号写成了版本号形态，与本节"构建号与产品版本分开管理"相反，需在建立基线时判定。

稳定签名和安装来源能减少身份混乱，但不能承诺 macOS 永远不再要求授权。

## 四、实施顺序

| 阶段 | 工作 | 完成条件 |
|---|---|---|
| P0：可靠性 | 构建身份、权限状态机、文件授权 | 可稳定启动；拒绝、恢复、保存失败都有明确出口 |
| P1：首次使用 | 操作面板、统一动作入口、截图结果反馈 | 不进设置、不用快捷键即可截图并复制或保存 |
| P2：一致性 | 设置拆分、中英文、偏好迁移 | 中英文完整可用，旧设置保留 |
| P3：发布验收 | 真机沙盒、升级、TestFlight | 同一候选构建通过完整验收 |

已有未提交修改先逐项审查并建立基线；后续按阶段独立提交，便于定位问题和回退。

## 五、发布前验收

自动化覆盖权限状态转移、重复请求合并、取消重试、语言选择、旧设置迁移、文件授权过期和导出失败。

当前测试空白（已核实）：`Tests/` 与 `Sources/` 中搜不到 `reopen` / `launcher` / `bookmark` 相关实现，重新打开入口、操作面板、文件授权三项自动化均为零。

真机必须验证：

- 全新安装后，未使用功能前不出现权限请求。
- 双击应用、菜单栏操作、快捷键执行结果一致。
- 拒绝权限后其他功能仍可用。
- 授权生效后不再由应用重复索要；系统要求的提示单独记录。
- 重启应用后仍能保存到已授权文件夹。
- 切换语言不终止录制、不清空未保存内容。
- 默认窗口下中英文均无裁切、重叠和大块异常留白。
- 升级保留设置，正式沙盒包完成截图、OCR、录屏和导出验收。

**下一步先实施 P0，把启动、权限和文件保存三个基础流程稳定下来，再接入新的操作面板。**

## 六、基线记录（2026-09-15）

- 源码提交：`df0f2ae`（`main`），工作区含 9 个未提交文件、342 行改动。
- 编译：`swift build --disable-sandbox` 通过。注意本机 `swift build` 不加该参数会因 SPM manifest 的 `sandbox-exec` 被拒绝而报 `Invalid manifest`，属环境限制，非代码问题。
- 测试：`swift test --disable-sandbox` 通过，228 项、0 失败（改动前基线）。
- 未提交改动方向与 P0 一致的部分：`PermissionService` 不再在授权失败时打开系统设置；`PermissionCenterSystemAdapter` 真实读取 `canPost`，商店版保留截图后的 Ctrl+V 兼容；`SettingsWindowController` 换成翻转 clip view + `NSGridView` 做顶部对齐。

## 七、P0 实施记录（2026-09-15）

已完成并通过测试，265 项、0 失败（新增 37 项）。

**权限状态机**

- 新增 `Permissions/PermissionGate.swift`：`PermissionKind`、`PermissionSystemReport`、`PermissionGateState`（7 态，含 `denied`）、纯函数 `PermissionGate.state(for:)`、`PermissionFlowArbiter`。
- 屏幕录制与媒体权限分开求值：`PermissionSystemReport.screenCapture(isGranted:)` 只产出 `granted` / `inconclusive`，媒体权限才可能产出 `denied`。
- 「已授权」优先级高于「待重启」：preflight 只有在权限真正生效时才返回 `true`，所以 `granted` 一律落到 `available`，不被重启标记压住。
- 删除 `ScreenRecordingPermissionSession` 与 `ScreenRecordingPermissionAction`，`ScreenRecordingPrompt.ensureGranted` 改为走状态机；8 个调用点（`ModeCoordinator` ×3、`SnipController` ×3、`RecordingController`、`PanoramaController`）由 `permissionSession:` 改为共享的 `permissionArbiter:`，属性统一改名 `screenRecordingPermissionArbiter`。
- 取消仍可重试：取消只 `endFlow()`，下次点击继续弹出说明；已提示过则不再重复弹窗。

**文件授权**

- 新增 `Settings/FileAccessService.swift`：security-scoped bookmark 的保存、解析、过期刷新、失败即丢弃；`withAuthorizedFolder` 用 `defer` 保证写入结束（含抛错）后释放作用域访问。
- bookmark 存在独立于 `AppSettings` 的键（`snipSaveDirectoryBookmark`）中，因为它是授权凭证而非用户可编辑设置。旧 `snipSaveDirectory` 字符串只作为显示提示，不当作有效授权 —— 这正是迁移规则要求的。
- `Scripts/ZoomItStore.entitlements` 增加 `com.apple.security.files.user-selected.read-write` 与 `com.apple.security.files.bookmarks.app-scope`（`plutil -lint` 通过）。站外版不沙盒，未改动。
- `SettingsWindowController.applyChosenSaveDirectory(_:)` 在选择文件夹后记录 bookmark；记录失败时明确告知用户重启后可能失效，不静默吞掉。
- `ImageExporter.writeToDirectory` 改为在已记录授权时通过 `withAuthorizedFolder` 写入，返回 `SaveOutcome`；失败时把图像复制到剪贴板并弹出带「重新选择位置 / 另存为 / 取消」的出口，不再是 `NSAlert(error:)` 一闪而过。
- `FileAccessService` 由 `AppDelegate` 创建后注入 `AppController` → `SettingsWindowController`，两者共用同一实例。

**重新打开入口**

- 新增 `App/AppReopenPolicy.swift`：纯函数 `AppReopenPolicy.intent(isUserInitiated:isRecording:)`，登录启动不抢焦点、录制中显示状态而不重复开始。
- `AppDelegate` 补齐 `applicationShouldHandleReopen`；它与跨实例通知共用 `presentReopenIntent(isUserInitiated:)`，双击、菜单、快捷键不会各走一套。
- `SingleInstance.showSettingsNotification` 改名 `showPrimaryEntryNotification`，语义改为「显示统一入口」。**线上值故意保持 `com.duola.dorazoom.showSettings`**：那是旧版本正在监听的名称，改名会让升级期间的双击静默失效。操作面板落地时（P1）再评估是否换名。
- 面板尚未实现，当前复用状态栏菜单作为主入口（它已含录制状态行）；P1 接入 `LauncherWindowController` 时只需替换这一个分支。

### P0 尚未完成

- 操作面板本身（`LauncherWindowController`）属 P1，未开始。
- 权限状态机尚未接到 `PermissionCenterWindowController` 的展示层，设置里的权限页仍读旧的布尔状态。
- 录屏导出期间的授权保持（「录制导出期间保持访问有效」）未实现，当前只在单次写入范围内持有访问。
- 真机沙盒验收未做：需要在全新安装、升级、拒绝后恢复三种场景下实测。
- 第二轮复核新增的 P0 范围缺口见第八节（3）（4）（5）：文字演示在商店版的权限处理、摄像头/麦克风的流程仲裁、录屏保存失败出口。

## 八、第二轮复核：扩展到全仓（2026-09-15）

上一轮只看过 P0 直接相关的文件。这一轮把「构建身份 / 权限 / 文件访问 / 本地化」四个维度在全仓重扫，**共 9 项，2 项已修，7 项待定**。

### 已修

**（1）上一轮自己引入的本地化回归：11 个键不在字符串目录里**

`save_failure.*`（9 个）与 `settings.snip.folder_grant_failed.*`（2 个）只以 `defaultValue` 写在代码里。字符串目录由 `.l10n/keysets/*.json` + `.l10n/translations/*.json` 生成，**不扫源码**，所以这 11 个键在任何语言下都会回落成英文 —— 正是第四节要消灭的中英混杂。

- 已写入 2 个键表与 9 个 `translations/*.json`，`build-localization-catalog.py` 重新生成：**313 → 324 键**，生成器的占位符 / 换行结构 / 受保护术语校验全部通过。
- 顺带修一处文案：`settings.snip.folder_grant_failed.message` 原来引用了「Ask each time」这个并不存在的 macOS 标签，改为描述应用内那个开关本身。
- 复核：源码引用但目录缺失的键 **0 个**；`swift test` 265 项 0 失败。

**（2）商店产物的隐私提示无法本地化（打包缺陷）**

实测已构建的商店归档 `.build/DoraZoom-1.0.0-4.0.1-universal.xcarchive`：

```text
DoraZoom.app/Contents/Resources/
├── DoraZoom.icns
├── DoraZoomColorIcon.png
└── ZoomItMac_ZoomItMacCore.bundle   ← 10 个 lproj 全在嵌套 bundle 里
```

系统只在 **app 自身的** `Contents/Resources/<lang>.lproj/InfoPlist.strings` 里解析 `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`，不会进嵌套 bundle。因此商店包里 `CFBundleLocalizations` 声明了 10 种语言、界面也按语言显示，**但摄像头 / 麦克风授权弹窗永远是英文**。

开发通道没有这个问题：`build-app.sh` 把 SwiftPM bundle 的资源扁平化到 app 根（脚本内注释解释了原因），`build-app-store.sh` 走 `xcodebuild archive`，没有对应步骤。

- 已给商店工程增加 `Copy privacy strings` 脚本阶段（与既有 `Generate app icon` 同一模式，在任何签名之前写入 `Contents/Resources/<lang>.lproj/InfoPlist.strings`），并把 10 种语言登记进 `knownRegions`（原为 `en` / `Base`）。
- 验证：本机无可用签名身份，无法做完整归档，故以 `CODE_SIGNING_ALLOWED=NO` 执行 Release 构建 —— **BUILD SUCCEEDED**，产物 app 根出现 10 个 `.lproj`，`zh-Hans.lproj/InfoPlist.strings` 内容正确。
- 仍需在 TestFlight 真机确认授权弹窗语言（本机无法触发沙盒 TCC）。

### 待决策

**（3）文字演示（DemoType）在商店版里是开着的，且没有任何权限处理 —— 已决策并实施，见第九节**

`App/DemoTypeController.swift`（588 行）：`StatusMenuPlan` 的「更多功能」里 `.demoType` 无条件编译，`ModeCoordinator` 直接 `demoTypeController.startOrStop()`。它做两件需要 TCC 权限的事 —— `CGEvent.tapCreate(options: .defaultTap)`（监听键盘）与 `CGEvent.post(tap: .cghidEventTap)`（注入按键）。文件内既无 `AXIsProcessTrusted`、无 `CGRequestPostEventAccess`，也无 `#if DORAZOOM_APP_STORE`。

第二节只列了两条「需要额外权限的兜底路径」（模拟粘贴、快捷键兜底），两者均已在商店版编译掉。**文字演示是第三条，漏了。**

**（4）摄像头 / 麦克风完全绕过新状态机**

`PermissionFlowArbiter` 目前只守住屏幕录制。`WebcamOverlayController` 直接按 `cameraStatus() == .notDetermined` 请求，`RecordingPreflightCoordinator` 另有一套 `RecordingPreflightPermission` 映射。于是「同一时间只允许一个授权流程」管不住这两条。

**（5）录屏保存失败仍只用 `NSAlert(error:)`**

`RecordingController` 3 处（`savePanel` 移动失败、编辑器导出失败、`presentError`）、`RecordingRecoveryCoordinator` 1 处、`DemoTypeController` 1 处。图像路径上一轮已改为「重新选择位置 / 另存为 / 取消」，录屏路径尚未对齐第三节的「保存失败保留结果并提供出口」。

**（6）`verify-localization.sh` 在干净仓库上跑不起来**

脚本依赖 `.agents/skills/app-i18n-l10n/scripts/`，而 `.agents/` 在 `.gitignore` 中。实测 `build-localization-catalog.py` 可运行，紧接着 `audit_catalog.py: No such file or directory` 即中断。该闸门只在本机存在那份 skill 时有效。

**（7）开发通道的构建号被强制等于版本号**

`build-app.sh`：`BUILD_NUMBER="${ZOOMIT_BUILD_NUMBER:-$VERSION}"`，默认直接拿 `1.0.0` 当构建号；`verify-delivery.sh` 进一步断言 `CFBundleVersion == CFBundleShortVersionString`。与第六节「构建号与产品版本分开管理」相反，后果是同一版本的两个开发构建无法区分。

关于上一轮遗留的疑问：`4` → `4.0.1` **属本次未提交改动**（`Scripts/build-app-store.sh:11` 与 `project.pbxproj` 两处），旧值为 `4`，且 `4.0.1` 已用于一次真实归档（产物目录名含 `4.0.1`，构建于今日 10:11）。不似误改，更像为绕开 App Store Connect 的构建号占用。**该项未改动。**

**（8）三份 Info.plist 各自独立**

`AppStore/Info.plist`（商店）、`build-app.sh` 内联 heredoc（开发 .app）、`ZoomItInfo.plist`（经 `Package.swift:49` 以 `-Xlinker` 链入裸可执行文件）。今日三者的 10 语言列表与两条隐私描述一致，但 `LocalizationTests` 只覆盖根 plist 与源码 lproj，**未覆盖 `AppStore/Info.plist`，也未覆盖 `build-app.sh` 生成的那份**。上面第（2）条能溜过去，部分原因正是测试把「仓库里的文件」当成了「发布产物」。

**（9）`LaunchAtLogin` 的单向覆盖**

`applySavedPreference` 每次启动都按偏好调用 `setEnabled`。用户在系统设置里将登录项改为「需批准」时状态为 `.requiresApproval`，若此时偏好为关，代码会直接 `unregister()`（因为 `status != .notRegistered`），**静默逆转用户在系统设置里的选择**。

## 九、DemoType 从商店版编译排除（2026-09-15，已决策并实施）

**决策：**DoraZoom 1.0.0 商店版将 DemoType 编译排除，**不为它新增 `input-monitoring` 或任何输入注入 entitlement**。首发优先保证截图、标注、放大、录屏的可靠性，减少额外权限依赖；DemoType 后续作为独立功能评估恢复。

理由是第八节（3）指出的第三条需权限路径：`DemoTypeController` 同时使用 `CGEvent.tapCreate`（监听键盘）与 `CGEvent.post`（注入按键），而商店版既无相应 entitlement，代码里也不请求任何授权。两条既有的兜底路径（模拟粘贴、快捷键兜底）早已在商店版编译掉，文字演示是漏掉的那条——不处理就是「点了没反应」的静默失败。

> **⚠️ 优先读第十节。** 实施本节时发现 `DORAZOOM_APP_STORE` 这个编译条件**从未真正作用到 SwiftPM 包目标**，也就是说上面「早已在商店版编译掉」的说法在当时并不成立：模拟粘贴、快捷键兜底、文字演示全都打在商店包里。第十节是这一节的修复，也是本节结论能成立的前提。**在第十节修复之前，第三节与第九节的编译期承诺均为空头支票。**

### 9.1 排除范围（使用现有 `DORAZOOM_APP_STORE` 条件）

| 层面 | 处理 | 文件 |
|---|---|---|
| 专属实现 | 整个 `DemoTypeController`（脚本读取、按键注入、用户按键监听 tap）编译排除 | `App/DemoTypeController.swift` |
| 构建能力标记 | 新增 `DemoTypeBuildAvailability.isIncludedInBuild`，供纯模型读取，避免每处各写 `#if` | `App/DemoTypeBuildAvailability.swift` |
| 命令路由 | `demoTypeController` 属性与 `.startDemoType`/`.resetDemoType` 分支排除；商店版保留显式 no-op 以保证共享命令枚举仍穷尽 | `Core/ModeCoordinator.swift` |
| 动作入口 | `AppController.startDemoType()` 与 `AppDelegate.actionSelector` 的映射排除（商店版返回 `nil`） | `App/AppController.swift`、`App/AppDelegate.swift` |
| 快捷键注册 | `demoTypeHotKeyRef`/`demoTypeResetHotKeyRef`、Carbon id 14/15 映射、注册与注销块全部排除 | `Hotkeys/HotkeyService.swift` |
| 菜单 | 「更多功能」不再产出 `.demoType` 条目 | `App/StatusMenuPlan.swift` |
| 设置导航 | 高级分区的 `.demoType` 目标不产出 | `Settings/SettingsNavigationModel.swift` |
| 设置界面 | DemoType 标签页（含帮助文案、文件选择、速度滑块、驱动开关）、快捷键配置行、录制目标分支、显示串、冲突检测全部排除 | `Settings/SettingsWindowController.swift` |
| 快捷键模型 | `hotkeyPlan` 不再产出 DemoType 绑定 | `Settings/SettingsManagementSimulation.swift` |
| 自检 | 依赖 `DemoTypeController` 的 4 项自检排除（其余保留，见 9.3） | `SelfTest/SelfTestRunner.swift` |

**每项排除的共享代码保留**：`AppCommand.startDemoType/.resetDemoType`、`StatusMenuItemID.demoType`、`SettingsDestination.demoType`、`SettingsHotkeyCommand.demoType/.demoTypePreviousSegment`、`AppSettings.demoType*` 字段与 `demoType*` UserDefaults 键、`InteractionState.demoType`、`Localizable.xcstrings` 中 16 个 DemoType 键、`Phase6InteractionReplaySimulation` 的纯模型。理由：两种构建共用一套命令与设置面，删枚举会波及非商店版与测试，收益为零。

### 9.2 顺带修掉的一处真实缺陷

商店版的 `SystemHotkeyFallbackEventTap` 是刻意的 no-op 桩，但 `HotkeyService.startFallbackEventTapIfNeeded` 仍会因 Carbon 注册失败把 `requiresInputListeningFallback` 置真——于是权限中心会为**商店版根本不具备的兜底能力**索要输入监控。现已改为：商店版该标志恒为 `false`，失败日志也不再声称「回退到事件监听」。这正是「权限中心按当前构建实际具备的能力生成权限需求」要求的那类修正。

同时把「哪些能力会产生权限需求」从 `AppDelegate` 的内联闭包提成可测试的纯函数 `PermissionCapabilityDemandModel.demands(settings:hotkeyFallbackNeeded:)`。逐项核对结果，输入监听的**真实**消费者只有三个，均与 DemoType 无关：

1. 录屏点击／快捷键叠加层 —— `RecordingInputOverlayController` 第 17–18 行读 `recordMouseClicks`/`recordShortcutKeys`，由 `RecordingController:781` 驱动，且已用 `CGPreflightListenEventAccess()` 自行降级。
2. 快捷键事件监听兜底 —— 仅非商店版存在。
3. （无第三条）

**未删除任何其他功能需要的输入权限**：录屏叠加层的需求原样保留，并有测试守住。

### 9.3 用户偏好保留

`demoType*` 的 UserDefaults 读写路径完全未动。商店版仍会 `load`/`save` 这些键，因此升级到商店版不清空旧偏好，后续恢复功能时值还在。守护测试：`AppleDemoTypeBuildExclusionTests.testDemoTypePreferencesSurviveAPersistenceRoundTrip` 与 `testStoreShapedPlansDoNotRewriteStoredPreferences`；自检 `testDemoTypeSettingsRoundTrip` 也刻意保留在商店版内，用它来证明偏好确实保留。

### 9.4 验证

- 非商店版：`swift build --disable-sandbox` 通过；`swift test --disable-sandbox` **279 项 0 失败**（原 265 + 新增 14）。
- 商店变体（`DORAZOOM_APP_STORE=1 swift build --disable-sandbox --scratch-path <独立目录>`，全量重编）：通过。
- 真实商店目标：`DORAZOOM_APP_STORE=1 xcodebuild -scheme DoraZoomStore -configuration Release CODE_SIGNING_ALLOWED=NO` 通过，并由 `Scripts/verify-store-build.sh` 校验通过。
- **二进制取证**（`nm` 计数，商店列取修复后的真实商店产物，详见第十节）：

| 符号 | 非商店版 | 商店版 |
|---|---:|---:|
| `DemoTypeController` | 350 | **0** |
| `AppController.startDemoType` 符号 | 存在 | **不存在** |
| `SettingsWindowController.toggleDemoTypeHotKeyRecording` 符号 | 存在 | **不存在** |
| `demoTypeHotKey*` 符号（共享设置字段） | 21 | 10（保留，见 9.3） |

**注**：上表商店列只有在第十节的编译条件修复之后才成立。在此之前，同一命令产出的真实商店包里 `DemoTypeController` 是 **203** 个符号。

新增 `Tests/ZoomItMacCoreTests/AppleDemoTypeBuildExclusionTests.swift`（14 项）把两种构建形态都钉住：菜单、设置导航、快捷键计划在 `demoTypeAvailable: false` 下均不产出 DemoType，且在 `true` 下仍产出；另外覆盖「DemoType 永不贡献输入监听需求」与「录屏叠加层仍要输入监听」两个方向。

### 9.5 商店文案与截图

- 10 个 locale 的 `docs/app-store/metadata/*.md` 三处 DemoType 宣传已移除：核心工具条目、此版本新增内容、发布检查清单。关键词字段与六条截图文案本就不含 DemoType，无需改动。
- `docs/app-store/README.md` 的提交闸门第 2 条已注明 DemoType 已解决；第 5 条与新增段落记录了**两张截图已过期**。

**尚未完成（需要你决定或授权）：**

1. **两张截图必须重拍。**`docs/app-store/screenshots/zh-Hans/02-shortcuts.png` 仍有「DemoType: ⌃7」整行，`06-advanced.png` 整段都是 DemoType（帮助文案、快捷键、输入文件、打字速度、驱动开关）。原始截图出自签名商店构建，README 自身要求最终以签名 Archive/TestFlight 构建重拍，因此我**没有**用未签名构建生成替代图。
2. **`docs/app-store/metadata/*.md` 的 §4 字符数表已过期。**实测与记录值：英文描述 1303 vs 记 1241、简中描述 513 vs 记 451、繁中描述 523 vs 记 462——偏差约 62 字符，属本次改动之前就存在的陈旧数据（描述文案后来加过段落）。字段均在限内（4000），不阻断提交，但贴进 App Store Connect 前应统一口径重算。我未擅自改这些数字，因为无法确定原口径。
3. **官网隐私页提到 DemoType。**`website/dist/privacy/index.html` 的「本地文件与保留」段落枚举了「截图、视频、GIF、DemoType 文件和自定义资源」。该页由 App Store 列表引用，且页面已有「商店版不会模拟 Command+V」这类分构建说明的先例。属法务文案，未改动，等你定是否同步措辞。

## 十、商店构建的 `DORAZOOM_APP_STORE` 从未生效（2026-09-15 发现并修复）

第九节的验收要求是「商店构建没有 DemoType 入口、专属监听注册或因此产生的授权提示」。为此我没有只看 SPM，而是构建了**真实商店目标**并检查产物符号——结果与所有既有文档的假设相反。

### 10.1 发现

`xcodebuild -project AppStore/DoraZoomStore.xcodeproj -scheme DoraZoomStore -configuration Release CODE_SIGNING_ALLOWED=NO` 的产物：

| 符号 | 真实商店产物 | 预期 |
|---|---:|---|
| `DemoTypeController` | **203** | 0 |
| `SystemPasteCompatibilityEventTap`（截图后的 Ctrl+V 兼容） | **19** | **存在** |
| `ControlVPasteHotkeyService`（全局事件监听） | **37** | 0 |

### 10.2 根因

`SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DORAZOOM_APP_STORE"` 只写在 `AppStore/DoraZoomStore.xcodeproj/project.pbxproj` 里 **DoraZoomStore 这一个 Xcode target** 的 Debug/Release 配置上。而所有依赖该条件的代码都在 SwiftPM 包 `ZoomItMacCore` 内，**Xcode 不会把宿主 app target 的编译条件转发给包目标**。我实测了另一种可能：把设置提到**项目级**（PBXProject 的 Debug/Release 配置），产物符号数不变，同样无效。

于是 `Sources` 下全部 `#if DORAZOOM_APP_STORE` / `#if !DORAZOOM_APP_STORE` 分支在**两种构建里都走「非商店」那一条**。推论：

- 第八节（3）「文字演示在商店版是开着的」是**准确的**，而且它当时确实带着事件监听与按键注入进包。
- 第三节关于“商店版不因模拟粘贴要求额外权限”的结论已因产品需求调整：商店版现在保留截图后的 Ctrl+V 兼容，因此权限中心必须真实反映输入发布权限；DemoType 和快捷键兜底仍不进入商店包。
- `HotkeyFallbackEventTap.swift` 里那个「商店版 no-op 桩」也从未被使用过；商店版用的是真正的监听实现。
- 第八节（2）关于「商店包隐私弹窗无法本地化」的修复**不受影响**，仍然有效——那是 Xcode 的 shell script 构建阶段，不经由 SwiftPM。

### 10.3 修复

编译条件改由包清单自己定义：

- `Package.swift` 读环境变量 `DORAZOOM_APP_STORE`。置位时给 `ZoomItMacCore` 加 `.define("DORAZOOM_APP_STORE")`；`PasteTapBridge`（Ctrl+V 兼容的 C 原语）保留在两种分发包中。
- `Scripts/build-app-store.sh` 导出该变量，并改用专用 derived data 目录（`ZOOMIT_STORE_DERIVED_DATA`）。
- 新增 `Scripts/verify-store-build.sh`：断言产物中**不存在** `DemoTypeController`、`AppController.startDemoType`，同时断言 `SystemPasteCompatibilityEventTap`、`ControlVPasteHotkeyService`、`AppDelegate`、`ModeCoordinator` 等核心符号**存在**（避免把空产物判为通过）。`build-app-store.sh` 在归档后、`exportArchive` 前调用它，**不通过就不导出**。

### 10.4 验证

真实商店目标（`DORAZOOM_APP_STORE=1`，CODE_SIGNING_ALLOWED=NO）：

| 指标 | 修复前 | 修复后 |
|---|---:|---:|
| `DemoTypeController` 符号 | 203 | **0** |
| `SystemPasteCompatibilityEventTap` 符号 | 19 | **存在** |
| `ControlVPasteHotkeyService` 符号 | 37 | **存在** |
| 可执行文件大小 | 5,124,200 B | **4,754,392 B** |

校验闸门双向验证：对修复后的产物通过；对修复前的产物失败，并打印「条件未生效」这一最可能原因。默认构建（不带变量）仍编译全部功能，`swift test` 279 项 0 失败。

### 10.5 已知限制（重要）

**Xcode 会复用已构建的包产物，且不因环境变量变化而重新评估包清单。** 实测同一 derived data 目录下：先带变量构建（商店风味），再不带变量重跑，产物**仍是商店风味**，没有恢复完整功能。也就是说这个开关对缓存是「粘性」的。

因此：

- 商店归档**必须**走 `Scripts/build-app-store.sh`（专用目录 + 导出变量 + 校验闸门），不要用 Xcode GUI 直接 archive。
- **GUI 构建该 scheme 不会定义 `DORAZOOM_APP_STORE`，产物是完整功能版，不能用于提交。**
- 校验闸门的价值正在于它不依赖对 Xcode 缓存行为的判断——无论原因是变量没导出还是缓存复用，它都会拦住。

### 10.6 仍未做的终态重构

`AppStore` 工程目前只编译一个 Swift 文件（`../Sources/ZoomItMacApp/main.swift`），其余全部来自 SwiftPM 包，这正是编译条件无法与 target 绑定的根源。README 提交闸门第 1 条要求的「自带源码、带沙盒与签名的真实 Xcode app target」才是终态：届时条件直接写在 target 上，不再依赖环境变量。**本次修复是让现有结构在发布路径上可靠，不是该重构的替代。**
