(() => {
  'use strict';
  // Translate text only: retain the original DOM, illustrations, and interactions.
  const translations = {
    'DoraZoom — 有些想法，圈一下就懂。': 'DoraZoom — A little mark. A clearer idea.',
    'DoraZoom 1.0.0：在 Mac 屏幕上圈画、标注、截图、OCR 和录制。Mac App Store 版本正在审核。': 'Draw, annotate, capture, extract text, and record on your Mac. Coming to the Mac App Store.',
    'DoraZoom 1.0.0 正在等待 Mac App Store 审核。圈出重点，画出方向。': 'Coming to the Mac App Store. Circle the point. Show the way.',
    '跳到交互体验':'Skip to the playground', 'DoraZoom 首页':'DoraZoom home', '主导航':'Main navigation',
    '亲手试试':'Try it', '使用场景':'Use cases', '如何使用':'How it works', '下载状态':'Get the app',
    '给想法，一个更直观的表达方式':'A clearer way to share an idea',
    '有些想法，':'Some ideas.', '圈一下':'One circle. ', '就懂。':'Got it.',
    '把想改的地方指给 AI，':'Show AI what to change. ', '把重点讲给别人。':'Show others what matters.',
    '在屏幕上圈画、标注，':'Draw and annotate on screen. ', '让沟通更直观。':'Make yourself clear.',
    '动手圈一下':'Try drawing', '看看它怎么用':'Watch the demo', '33 秒':'33 sec',
    '适用于 macOS 14 及以上 · DoraZoom 1.0.0':'For macOS 14+ · DoraZoom 1.0.0',
    'Mac App Store 版本正在等待 Apple 审核。':'Coming to the Mac App Store.', '查看版本状态':'Check availability',
    '少说几句，亲手画一下':'Less explaining. Try a mark.', '浏览器交互体验':'Browser playground',
    '你的页面，你来指方向。':'Your page. Your direction.', '拖动画一个圈':'Drag to draw a circle',
    '虚构网页，仅用于圈画演示；以下价格不代表 DoraZoom 定价。':'Example page for drawing. Prices below are not DoraZoom prices.',
    '已放大中间卡片 · 导出包含完整画面与所有标注':'Center card enlarged · Exports include the whole scene and all marks',
    '圈画体验区。可用鼠标或手指拖动标注，也可按 Enter 标注示例按钮。':'Drawing playground. Drag to annotate or press Enter to mark the example button.',
    '你的浏览器不支持画布，可观看下方产品演示。':'Your browser does not support canvas. Watch the walkthrough below.',
    '试着圈出你想改的地方':'Circle what you want to change', '圈画工具':'Drawing tools',
    '画圈':'Circle', '自由画笔':'Freehand pen', '画箭头':'Arrow', '画圈 (1)':'Circle (1)', '画笔 (2)':'Pen (2)', '箭头 (3)':'Arrow (3)',
    '画笔颜色':'Pen color', '红色':'Red', '蓝色':'Blue', '金色':'Gold', '标注历史':'Annotation history',
    '撤销上一步':'Undo last mark', '撤销':'Undo', '清空标注':'Clear annotations', '清空':'Clear',
    '圈画':'Circle', '画笔':'Pen', '箭头':'Arrow', '帮我圈一下':'Add a circle', '1 处标注':'1 annotation',
    '“这里”，':'“Right here.”', '现在说清楚了。':'Now it’s clear.', '一个圈，一句补充。':'A circle. A little context.', '把上下文一起交给 AI。':'Pass the whole idea to AI.',
    '补充你的想法':'Add your idea', '比如：把圈出的按钮做大一点。':'For example: make the circled button bigger.',
    '把圈出的按钮做大一点，其他保持不变。':'Make the circled button bigger. Keep everything else the same.',
    '圈好后，生成你的标注图':'Ready? Create your annotated image.', '你刚刚生成的标注截图':'Your generated annotated screenshot',
    '生成标注截图':'Create screenshot', '复制图片':'Copy image', '保存图片':'Save image', '复制文字':'Copy text',
    '这是圈画体验。生成后，粘贴到你使用的 AI 工具中继续。':'A drawing playground. Paste the result into your own AI tool to continue.',
    '从「左边那个按钮」到「就是这里」。':'From “that button on the left” to “right here.”', '屏幕上的想法，都有了落点。':'Give your ideas a place on screen.',
    '你已经知道想说什么。':'You know what you mean.', '现在，让对方也看见。':'Now let them see it.',
    '想让 AI 改这里，':'One small change for AI.', '却写了半屏描述。':'Half a screen to explain it.',
    '发出了一张截图，':'You sent a screenshot.', '对方还是没找到重点。':'They still missed the point.',
    '讲解已经到下一步，':'You’re on the next step.', '大家还在找上一步。':'They’re still looking for the last one.',
    '一个小动作。':'One small gesture.', '接住每一种表达。':'So many ways to share.',
    '和 AI 协作，向团队反馈，给别人讲解。':'Create with AI. Give feedback. Explain an idea.', '重点在哪里，就画在哪里。':'Wherever the point is, mark it.',
    '与 AI 一起创造':'Create with AI', '让讲解跟得上':'Guide attention', '把过程讲清楚':'Show the process',
    '你的想法，':'Your idea.', '不必翻译成长提示词。':'No lengthy prompt needed.',
    '你的想法，<br>不必翻译成长提示词。':'Your idea.<br>No lengthy prompt needed.',
    '圈出想修改的组件，标好方向，截下画面。把「改这里」连同上下文，一起粘贴给 AI。':'Circle a component, mark the direction, and capture it. Paste “change this” into AI, with the context attached.',
    '圈出具体元素，减少位置描述':'Circle the element, skip the directions', '截图到剪贴板，接上现有工作流':'Capture to your clipboard and keep moving', '由你使用的 AI 工具完成后续修改':'Your own AI tool handles the changes',
    '观看这段演示':'Watch this scene', '播放当前场景演示':'Play this scene',
    '圈选按钮、粘贴到 AI 对话并展示页面结果的示意画面':'Illustration of marking a button, sharing it with AI, and seeing the result',
    '圈出意图 → 截图传达 → AI 接着完成':'Mark the idea → Capture it → Let AI continue',
    '你讲到哪里，<br>目光就跟到哪里。':'Keep every eye<br>on your point.',
    '放大关键一步，圈出需要注意的细节。面对文档、公式和复杂界面，让大家始终看见同一个重点。':'Zoom into a key step and circle the details. Keep everyone focused on the same part of a document, formula, or complex interface.',
    '静态与实时缩放，聚焦细节':'Static and live zoom for closer details', '圈画、高亮、文字，一起讲清楚':'Draw, highlight, and add text', '白板与黑板，随时展开思路':'Whiteboard and blackboard for fresh ideas',
    '放大数学推导步骤，并用红笔圈出重点的教学示意画面':'Illustrative lesson with a zoomed-in formula and red annotations',
    '放大细节 → 圈出重点 → 同步理解':'Zoom in → Mark the point → Follow together',
    '你不在场，<br>讲解也能继续。':'Let the explanation<br>travel without you.',
    '把操作过程和屏幕圈画一起录下来。发出一段有重点的演示，让反馈、交接和说明都更直观。':'Record your steps and screen annotations together. Share a focused walkthrough for clearer feedback, handoffs, and instructions.',
    '全屏、区域或窗口录制':'Record a screen, region, or window', '把圈画保留在讲解视频中':'Keep annotations in the recording', '录制后预览、裁剪与导出':'Preview, trim, and export',
    '包含红色圈画标注的录制视频播放器示意画面':'Illustrative recording preview with red annotations',
    '开始录制 → 边操作边标注 → 分享讲解':'Record → Annotate as you go → Share',
    '跟上思路。':'Stay in your flow.', '只要三个动作。':'Just three steps.', '在 Mac 上，随手唤起 DoraZoom。':'Bring up DoraZoom on your Mac.', '你熟悉的工作方式，多了一支顺手的笔。':'Your familiar workflow, with a handy pen.',
    '唤起':'Start', '念头来了，就开始。':'An idea? Start right away.', '按下 Control + 2，进入屏幕圈画。':'Press Control + 2 to draw on screen.', '不用先打开另一个编辑窗口。':'No separate editor to open.',
    '就是这里':'Right here', '把重点，直接指出来。':'Point it out.', '用圈、箭头和文字标明意图。':'Use circles, arrows, and text.', '需要讲细节时，还可以放大画面。':'Zoom in when the details matter.',
    '截图':'Capture', '粘贴':'Paste', '传达':'Share', '带着上下文，交出去。':'Send the context too.',
    '按 Control + 6，选取区域并截图。':'Press Control + 6 to capture a region.', '再按 Command + V，粘贴给同事或 AI。':'Then Command + V to paste to your team or AI.',
    '顺手，还不止圈画':'More than a handy pen', '屏幕缩放':'Screen zoom', '文字标注':'Text annotations', '白板 / 黑板':'Whiteboard / Blackboard', 'OCR 取字':'OCR', '屏幕录制':'Screen recording', '滚动长截图':'Scrolling capture',
    'Mac App Store，':'Mac App Store.', '即将上线。':'Coming soon.', '一次买断，无需订阅。':'Buy once. No subscription.', '继续体验圈画':'Keep drawing', 'macOS 14 及以上':'macOS 14+',
    '你可能还想知道。':'A few more things.',
    'DoraZoom 会直接帮我修改代码吗？':'Does DoraZoom edit my code?',
    'DoraZoom 负责屏幕圈画、标注和截图，帮你把需求表达清楚。将标注图粘贴到支持图片输入的 AI 工具后，由该工具继续完成代码或页面修改。':'DoraZoom helps you express an idea with screen annotations and screenshots. Paste the image into an AI tool that accepts images; that tool handles code or page changes.',
    '可以在哪些地方使用？':'Where can I use it?',
    'DoraZoom 是 macOS 屏幕工具，可用于网页、应用界面、文档和演示内容。截图可以粘贴到支持图片的聊天、协作和 AI 工具中；具体接收方式取决于目标应用。':'Use DoraZoom on your Mac with websites, apps, documents, and presentations. Paste screenshots into chat, collaboration, or AI tools that accept images. Support depends on the destination app.',
    '网页上的圈画会上传吗？':'Are my drawings uploaded?',
    '这个网页体验在你的浏览器内处理标注和生成图片，不会上传圈画内容或补充文字。复制或保存后，由你决定把它们交给谁。':'This playground processes annotations and creates images in your browser. Your drawings and text are not uploaded. You choose where to share them after copying or saving.',
    '现在可以下载 Mac 应用吗？':'Can I download the Mac app now?',
    'Mac App Store 即将上线，开放下载后将在此提供官方入口。':'Coming to the Mac App Store. The official download link will appear here at launch.',
    '让想法被看见。':'Make your idea visible.', '隐私政策':'Privacy (中文)', '使用条款':'Terms (中文)', '技术支持':'Support (中文)', '源码':'Source', '回到顶部 ↑':'Back to top ↑',
    'DoraZoom · 看见同一个重点':'DoraZoom · See the same point', '关闭视频':'Close video', '你的浏览器不支持播放，请':'Video playback is unavailable. Please ', '下载视频':'download the video', '观看。':' to watch.',
    '产品流程示意 · AI 生成结果由外部 AI 工具完成':'Illustrative walkthrough (Chinese) · AI results are produced by external tools',
    '产品':'Product', '价格':'Pricing', '关于':'About', '好点子，值得一个好开始。':'Great ideas start here.', '选一个计划，让你的下一个想法发生。':'Choose a plan for your next idea.',
    '给刚刚萌芽的想法':'For a fresh idea', '免费开始':'Get started', '1 个创作空间':'1 workspace', '基础组件库':'Basic components',
    '给想再向前一步的你':'For your next step', '开始试用':'Start trial', '无限创作空间':'Unlimited spaces', '完整组件与导出':'Components & exports',
    '给一起创造的团队':'For creative teams', '联系团队':'Contact us', '团队共享空间':'Shared workspaces', '协作与成员管理':'Team management',
    '人气之选':'Popular', '/ 月':'/ mo', '网页示例 · 在这里标注你的修改想法':'Example page · Mark your ideas here',
    '更新标注截图 <span aria-hidden="true">↗</span>':'Update screenshot <span aria-hidden="true">↗</span>',
    '重新生成截图 <span aria-hidden="true">↗</span>':'Refresh screenshot <span aria-hidden="true">↗</span>',
    '不支持的圈画工具':'Unsupported drawing tool', '自由画出你的想法':'Draw your idea freely', '拖动指出方向':'Drag to point the way', '图片生成失败，请重试':'Could not create the image. Try again.',
    'DoraZoom-我的标注.png':'DoraZoom-annotations.png', 'DoraZoom-官网.url':'DoraZoom-website.url', '官网快捷方式已保存，打开它即可查看下载状态。':'Website shortcut saved. Open it to check availability.',
    '标注截图已生成，可以复制或保存了。':'Screenshot ready. Copy or save it.', '已开始保存标注图片。':'Saving your annotated image.',
    '当前浏览器不支持复制图片，已为你保存。':'Image copying is unavailable. Saving it instead.', '标注图片已复制，去 AI 对话中粘贴吧。':'Image copied. Paste it into your AI chat.',
    '暂时无法复制图片，请点击「保存图片」。':'Could not copy the image. Choose Save image.', '先写一句你的修改想法吧。':'Add your idea first.', '补充文字已复制。':'Text copied.', '请按 Command / Control + C 复制选中的文字。':'Press Command / Control + C to copy the selected text.',
    '未知的使用场景':'Unknown scene', '读取圈画状态':'Read drawing state', '读取本地圈画体验的工具、标注数量和截图是否需要更新，不读取补充文字。':'Read the selected tool, mark count, and export freshness without reading entered text.', '请输入空对象':'Provide an empty object',
    '切换产品场景':'Select product scene', '在官网中显示 AI 协作、教学讲解或录屏分享场景。不会生成或修改图片。':'Show the AI, teaching, or recording scene. Does not generate or alter images.', '请选择 ai、teach 或 record':'Choose ai, teach, or record',
  };
  let saved; try { saved = localStorage.getItem('dorazoom-language'); } catch {}
  const requested = new URL(location.href).searchParams.get('lang');
  const language = [requested, saved].find(v => v === 'en' || v === 'zh') || ((navigator.languages?.[0] || navigator.language || 'en').toLowerCase().startsWith('zh') ? 'zh' : 'en');
  const en = language === 'en';
  const t = value => en && Object.hasOwn(translations, value) ? translations[value] : value;
  window.DoraZoomI18n = { en, t };
  document.documentElement.lang = en ? 'en' : 'zh-CN';
  if (requested === 'en' || requested === 'zh') { try { localStorage.setItem('dorazoom-language', requested); } catch {} }
  document.querySelectorAll('[data-language]').forEach(link => {
    if (link.dataset.language === language) link.setAttribute('aria-current','true'); else link.removeAttribute('aria-current');
    const target = new URL(location.href); target.searchParams.set('lang',link.dataset.language); link.href = target.href;
    link.addEventListener('click',()=>{ const next = new URL(link.href); next.hash=location.hash; link.href=next.href; try { localStorage.setItem('dorazoom-language',link.dataset.language); } catch {} });
  });
  if (!en) return;
  const nodes = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT);
  while (nodes.nextNode()) {
    const node = nodes.currentNode;
    if (node.parentElement.closest('script,style,[data-language]')) continue;
    const key = node.nodeValue.trim();
    if (Object.hasOwn(translations,key)) node.nodeValue = node.nodeValue.replace(key,t(key));
  }
  document.querySelectorAll('[aria-label],[title],[alt],[placeholder],meta[content]').forEach(el => {
    for (const attr of ['aria-label','title','alt','placeholder','content']) {
      if (el.hasAttribute(attr)) el.setAttribute(attr,t(el.getAttribute(attr)));
    }
  });
})();
