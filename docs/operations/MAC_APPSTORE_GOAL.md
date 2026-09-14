# Goal Document: DoraZoom Mac App Store 首次内测发布

## Go / No-Go

- **Judgment**: Go after signing prerequisites
- **Reason**: 商店版 target、沙盒边界、App Store Connect record 和商店文案已准备；当前剩余阻塞是本机缺少 Installer 分发证书和 provisioning profile，无法生成可上传 Archive。

## Target Outcome

在 App Store Connect 创建 DoraZoom macOS App，并上传一个可进入 TestFlight 内测的 Mac App Store Archive；上传成功、处理完成且 TestFlight 可见后，才称为完成。

## Goal Definition

- **Type**: delivery
- **Boundary**: Mac App Store/TestFlight 首次上传；包含商店版 target、沙盒 entitlement、Mac App Distribution 签名、Archive、App Store Connect app record 和上传验证。
- **Non-goals**:
  - 不把当前 Developer ID 站外版伪装成商店版。
  - 不在商店版保留 `CGEventPost(Command+V)` 模拟粘贴能力。
  - 在账号侧确认前不提交 App Review 或公开发布。
- **Deferred work**:
  - 真实 Mac 上全部屏幕录制、Input Monitoring、麦克风、摄像头和升级/卸载验收。
  - 由最终签名商店版生成截图并完成审核说明。
- **Verification rule**: 以本地商店版 Archive 签名/entitlement 检查和 App Store Connect/TestFlight 处理状态为准。
- **Evidence source**: Xcode archive、`codesign`/`spctl` 输出、App Store Connect app record 和 TestFlight build 状态。
- **Pass criteria**: 商店版 Archive 使用 Mac App Distribution，包含 App Sandbox，Bundle ID 稳定且成功上传；App Store Connect 处理状态为可测试。
- **Confidence note**: 站外版的 Swift 测试和签名链路已通过，但商店版能力和沙盒兼容性尚未证明。
- **Judgment owner**: App Store Connect 处理结果 + 用户在 TestFlight 的真实安装验收。

## Current State

- SwiftPM macOS 项目，Bundle ID `com.duola.dorazoom`，最低 macOS 14，228 项测试已通过。
- 已有站外版 `Developer ID Application` 签名、公证 DMG/ZIP 和 `notarytool` 凭据。
- 已有 `AppStore/DoraZoomStore.xcodeproj`、商店版 entitlements 和 Archive scheme；Release build 4 已本地编译。
- 商店版构建产物未发现 `CGEventPost`、`CGEventTapCreate` 或 `PasteTapBridge` 字符串；签名验证仍待真实 Archive。
- App Store Connect 已确认 DoraZoom macOS record：Apple ID `6803335624`、Bundle ID `com.duola.dorazoom`、SKU `dorazoom-macos-2026`、版本 1.0 处于准备提交。
- 本机仅有 `3rd Party Mac Developer Application: cong ni (26GG8J688T)`，缺少对应 Installer 身份；本机也没有 provisioning profile 目录。

## Priority Rationale

- 先验证 Xcode/App Store Connect 的身份和 app record，避免在错误 Bundle ID 上改造代码。
- 再建立商店版壳和沙盒边界，最后才做 Archive 上传；这样每一阶段都有可回滚的证据。
- 站外版保持不变，商店版通过独立 target/能力开关隔离，避免污染已完成的内测包。

## Assumptions and Open Decisions

| Item | Status | Impact | Owner / Next step |
|------|--------|--------|-------------------|
| 商店版 Bundle ID 是否继续使用 `com.duola.dorazoom` | unresolved | 决定 App Store Connect app record 和签名身份 | 先查 App Store Connect；若已有 record，沿用；否则创建 |
| 商店版是否接受移除模拟粘贴和可能受沙盒限制的能力 | unresolved | 决定首个可上传能力范围 | 以最小可测 TestFlight 版本为准，记录降级能力 |
| Mac App Distribution 证书/Provisioning Profile | unresolved | 没有它无法 Archive 上传 | 在 Apple Developer/Xcode 中确认并生成 |
| 商店资料、隐私答案、截图 | deferred | 影响审核，不影响首次 TestFlight 上传 | 首次 TestFlight build 成功后补齐 |

## Phases

### Phase 1: 前置条件和 app record 审计

- **Purpose**: 确认账号、Bundle ID、SKU、平台和签名能力，避免错误创建或上传。
- **Entry condition**: 用户已授权发布到 App Store Connect。
- **Phase rules**:
  - 只读检查优先，不创建重复 app record。
  - 发现 Bundle ID 或团队权限冲突时暂停并报告。
- **Todos**:
  - [x] 检查 App Store Connect 是否已有 DoraZoom macOS app record。
    - **Surface**: App Store Connect UI
    - **Proof**: 记录 app ID、Bundle ID、平台和当前状态
    - **Depends on**: 已登录 App Store Connect
  - [ ] 检查 Apple Developer 的 Mac App Distribution 能力和 Bundle ID。
    - **Surface**: Developer portal/Xcode
    - **Proof**: 可选签名身份、Bundle ID 和 profile 明确
    - **Depends on**: 账号团队权限
- **Exit proof**: Bundle ID、app record 和签名路线已确定。
- **Stop condition**: 需要用户决定新 Bundle ID、产品名称或商店能力范围。

### Phase 2: 商店版 target 和能力隔离

- **Purpose**: 建立可被 App Store 审核的独立沙盒构建，不破坏站外版。
- **Entry condition**: Phase 1 已确定 Bundle ID 和首个 TestFlight 能力范围。
- **Phase rules**:
  - 站外版 target、Bundle ID、entitlement 和发布脚本保持不变。
  - 商店版禁止 `CGEventPost` 模拟粘贴；使用能力开关或替代提示。
  - 每次修改必须有测试或静态检查证据。
- **Todos**:
  - [x] 创建正式 Xcode macOS App target、scheme、Info.plist 和 AppIcon。
    - **Surface**: Xcode project/build files
    - **Proof**: `xcodebuild -list` 能看到 Archive scheme
    - **Depends on**: Phase 1
  - [x] 添加最小 App Sandbox entitlement 和商店版签名配置。
    - **Surface**: entitlements/build settings
    - **Proof**: `codesign -d --entitlements -` 仅包含已验证能力
    - **Depends on**: target 已存在
  - [x] 隔离或关闭商店版模拟粘贴实现。
    - **Surface**: Swift/C bridge/feature flag
    - **Proof**: 商店版产物不含 `CGEventPost` 路径；测试通过
    - **Depends on**: target 已存在
- **Exit proof**: 商店版可在本地编译，Bundle ID、版本、架构和 entitlement 符合目标。
- **Stop condition**: 沙盒导致核心功能不可用且没有用户认可的降级方案。

### Phase 3: Archive、上传和 TestFlight 验证

- **Purpose**: 把商店版变成 App Store Connect 可处理的 build，并确认内测入口可用。
- **Entry condition**: 商店版本地构建和静态签名检查通过。
- **Phase rules**:
  - 上传前必须保存 Archive 元数据和校验结果。
  - 只上传明确版本，不提交审核或公开发布。
- **Todos**:
  - [ ] 使用 Mac App Distribution 生成 Archive。
    - **Surface**: Xcode/xcodebuild archive
    - **Proof**: Archive 签名、Bundle ID、版本、架构和 entitlements 检查通过
    - **Depends on**: Phase 2
  - [ ] 上传 Archive 到 App Store Connect。
    - **Surface**: Xcode Organizer/Transporter/App Store Connect
    - **Proof**: build processing 状态成功
    - **Depends on**: Archive 通过
  - [ ] 将 build 加入 TestFlight 内测并记录安装入口。
    - **Surface**: App Store Connect/TestFlight
    - **Proof**: build 可见且至少一台真实 Mac 能安装
    - **Depends on**: build processing 成功
- **Exit proof**: TestFlight 中可见可安装的 DoraZoom macOS build。
- **Stop condition**: 上传被拒、处理失败、Bundle ID 冲突或沙盒能力不满足内测目标。

## Dry-Run Findings

- 商店版 Xcode project、Archive scheme 和最小沙盒 entitlement 已建立。
- Release build 4 可编译，Bundle ID、版本、最低系统版本和商店版权主体均符合目标。
- 商店版二进制静态检查未发现模拟粘贴路径。
- 本机缺少 `3rd Party Mac Developer Installer` 身份与 provisioning profile；因此签名 Archive、Transporter 上传和 TestFlight 仍未完成。

## Final Validation

- `xcodebuild -scheme <StoreScheme> -configuration Release archive ...`
- `codesign -d --entitlements - --xml <StoreApp>`
- `codesign --verify --deep --strict <StoreApp>`
- App Store Connect build processing = processed/successful
- TestFlight build visible and installable on a real Mac

## First Execution Step

补齐 Apple Developer 的 Mac App Distribution/Installer 证书与 App Store provisioning profile 后，串行执行签名 Archive；随后在 App Store Connect 临门操作前向用户确认上传、定价和提交审核。
