# DoraZoom 真实 3D 落地页执行计划

> 当前基线：真实三维世界，2026-09-05。本地概念场景图已移除，不作运行时或回退背景。
> 本轮范围：眼前谷地 → 蓝图峡谷空间小样；并非四区域终稿。
> 需求：[PRD](/Users/happy/Desktop/zoomit/docs/website-3d-experience/PRD.md)
> 旧混合方案：[v0.2 归档](/Users/happy/Desktop/zoomit/docs/website-3d-experience/plan-v0.2-hybrid-archive.md)，不再作为执行依据。

## 已实现

- [x] 真实连续地形、河面、植被和有厚度的玻璃片进入同一个 Three.js 场景。
- [x] 复用 /Users/happy/Desktop/image3d 的原始纸飞机工厂，不修改其模型文件。
- [x] 镜头与飞机独立路径、世界坐标姿态、确定性尾迹；不依赖图片切换。
- [x] 滚动推进与倒放、探索空间/转动视角、进度滑块、回放入口。
- [x] 去掉运行页的大卡片堆叠，用留白和少量叙事文字让三维世界成为主体。
- [x] 手机几何/DPR降级、系统减少动态效果静态观景、WebGL不可用提示。
- [x] 玻璃片通过 img2threejs 条件准入、独立规格、严格验证并生成 blockout；未冒充最终资产。

## 本轮验证

- [x] TypeScript 与生产构建通过。
- [x] 浏览器首屏、峡谷、自由视角、反向复现、回放、手机与 reduced-motion 回归通过（2026-09-05；桌面 1440×900、手机 390×844、静态观景 1280×800；本轮控制台错误为 0）。
- [ ] 玻璃片的完整多视角建模门禁通过（当前仍是 blockout）。
- [ ] 确认两区域的空间尺度与飞机镜头关系后，进入美术精修。

验证补充：48.004% 进度前进/倒放的飞机、相机坐标完全一致；60% 自由观景只改变相机、不移动飞机。手机柔光伪元素溢出已修复，控制栏完整位于可视区。101 个路径样本的镜头和飞机中心均高于地形；翼展近似采样发现真实玻璃射线遮挡，但尚不是完整机体碰撞或透明层叠像素验收。当前桌面主渲染计数约 63 万三角形、81–105 draw calls（含透明材质重复绘制），尚需性能优化。

## 后续顺序

1. 精修谷地与峡谷：打破重复排布，提高岩层/植被形态与光照层次；玻璃单体逐关验收。
2. 扩展真实 3D 意图温室、梦想花园；不以旧场景图替代。
3. 增加圈选→局部改变→飞机携带痕迹的真实交互。当前尚未实现。
4. 加入真实产品截图/录屏证据，验证下载入口和文案，不虚构 AI 集成。
5. 分块地形、远近精度、透明材质成本优化；实机性能测试后再部署。

## 技能边界

- img2threejs：独立物体的参考分析、规格、分阶段程序化建模、多角度验收。现有 image3d 是资产项目，不是新的生成图片背景流程。
- scroll-world：借用连续镜头、滚动节奏与可逆性规则；它原生的视频链不是本项目的运行架构，不调用视频生成。
- Three.js 环境开发：地形、水体、布局、实例化、雾与真实遮挡。
- imagegen：只有需要新的临时美术探索或独立物体参考视图时再使用；产物不得作为运行时场景背景。本轮没有重新生图。

## 调整入口

- 路径、缩放、FOV、指针影响：[worldConfig.ts](/Users/happy/Desktop/zoomit/docs/website-3d-experience/prototype/src/world/worldConfig.ts)
- 地形、河道、实例布局：[createWorld.ts](/Users/happy/Desktop/zoomit/docs/website-3d-experience/prototype/src/world/createWorld.ts)
- 模型规格：[object-sculpt-spec.json](/Users/happy/Desktop/zoomit/docs/website-3d-experience/world-3d/glass-outcrop/object-sculpt-spec.json)

旧 App.tsx、JourneyCanvas.tsx、flightConfig.ts、styles.css 保留但不再被运行入口引用；另有 archive/hybrid-v02 备份。
