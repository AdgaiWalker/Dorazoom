import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), 'dist');
const esc = (s) => s.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;');
const copy = {
  zh: {
    lang:'zh-CN', title:'DoraZoom — 在 Mac 上放大、圈画，让讲解更清楚。',
    description:'DoraZoom 是 Mac 屏幕讲解工具。放大重点、圈画标注、截图、OCR 与录屏。本机处理，无需账号，一次性买断。',
    nav:['使用场景','如何使用','获取 DoraZoom'], skip:'跳到正文',
    eyebrow:'有些想法，圈一下就懂。', headline:'放大重点。<br>圈出想法。<br><em>让讲解更清楚。</em>',
    intro:'在 Mac 屏幕上直接放大、圈画和截图。<br>教学、演示、远程沟通，让大家看见同一个重点。',
    watch:'观看演示', try:'亲手圈一下', available:'Mac App Store 即将上线', requirements:'macOS 14+ · 一次性买断 · 无需账号',
    caption:'产品流程示意 · 展示教学、圈画和录屏场景，非最终商店版实录。',
    demoTitle:'DoraZoom · 产品流程演示', close:'关闭演示', mediaNote:'现有演示含中文画面。AI 生成与修改由外部工具完成。',
    benefits:['圈画与缩放','截图与 OCR','录制与导出','本机处理'],
    sceneTitle:'少一点解释，<br>多一点理解。', sceneIntro:'从课堂到会议，从问题反馈到操作教程。',
    scenes:[['01 / 教学与演示','细节，看得见。','放大屏幕上的文字和图表，用圈、箭头和画笔引导视线。'],['02 / 团队与产品反馈','说的就是这里。','截图前先标好位置。把带着上下文的图片粘贴给同事，或交给你使用的 AI 工具。'],['03 / 录制操作教程','过程，留得住。','录下屏幕操作，需要时暂停、继续。可选麦克风和摄像头，文件保存在本机。']],
    workflowTitle:'跟上思路，<br>只要三个动作。', workflowIntro:'以下是默认快捷键，你可以在应用设置中调整。',
    steps:[['⌃ 2','唤起圈画','按 Control + 2，开始标注屏幕。'],['○ ↗','指出重点','用圈、箭头和文字，让对方看清你指的地方。'],['⌃ 6 → ⌘ V','截图与粘贴','按 Control + 6 选区截图，再按 Command + V 粘贴到支持图片的应用。']],
    playgroundTitle:'试着圈一下。', playgroundIntro:'这是浏览器中的交互示例。所有标注留在本机；示例画面不是 DoraZoom 应用界面。',
    tools:['画圈','画笔','箭头','撤销','清空','保存 PNG'], colors:['红色','蓝色'], keyboard:'拖动画一个圈；键盘按 Enter 添加示例标注。',
    purchaseTitle:'让下一次讲解，<br>更轻松一点。', purchaseIntro:'一次购买，无需订阅。Mac App Store 即将上线；开放购买后，这里会提供官方入口。',
    priceNote:'价格和销售地区以 App Store 上架时显示为准。', support:'联系支持',
    faqTitle:'开始之前，你可能想知道。',
    faq:[['为什么需要屏幕录制权限？','macOS 通过这项权限保护屏幕内容。缩放、截图、OCR 和录屏需要读取画面；使用相关功能时，按应用提示授权即可。麦克风和摄像头是可选项。'],['截图和 OCR 内容会上传吗？','DoraZoom 在本机处理截图、OCR 和录屏。应用不会把这些内容上传给我们，保存或分享由你决定。'],['支持中文和英文吗？','应用包含简体中文、英文等语言资源，按照 macOS 的语言偏好显示。界面语言与输入文字的语言是两回事；你可以使用系统输入法输入文字。'],['截图怎么粘贴？','默认按 Control + 6 选区截图，再按 Command + V 粘贴。目标应用需要支持粘贴图片；纯文本输入框通常不能接收图片。'],['现在可以安装吗？','Mac App Store 版本正在审核，尚未开放购买。上架后本页会提供安装入口；当前可以观看演示、体验圈画或在 GitHub 查看源码。']],
    footer:['隐私政策','使用条款','技术支持'], studio:'未然界域科技工作室', github:'GitHub / 源码', home:'返回首页',
  },
  en: {
    lang:'en', title:'DoraZoom — Zoom, annotate, and explain on your Mac.',
    description:'Zoom in, draw on your Mac screen, capture screenshots, extract text with OCR, and record. Local processing, no account, and a one-time purchase.',
    nav:['Use cases','How it works','Get DoraZoom'], skip:'Skip to content',
    eyebrow:'A little mark. A clearer idea.', headline:'Zoom in.<br>Mark it up.<br><em>Make it clear.</em>',
    intro:'Zoom, draw, and capture right on your Mac screen.<br>For lessons, presentations, and feedback that gets the point across.',
    watch:'Watch the demo', try:'Try drawing', available:'Coming to the Mac App Store', requirements:'macOS 14+ · One-time purchase · No account',
    caption:'Illustrative product walkthrough featuring teaching, annotation, and recording. Not a recording of the final store build.',
    demoTitle:'DoraZoom · Product walkthrough', close:'Close demo', mediaNote:'This walkthrough includes Chinese on-screen text. AI generation and editing are performed by external tools.',
    benefits:['Draw & zoom','Capture & OCR','Record & export','Processed locally'],
    sceneTitle:'Less explaining.<br>More understanding.', sceneIntro:'From a classroom to a meeting. From feedback to a how-to.',
    scenes:[['01 / TEACHING & PRESENTATIONS','Bring the details closer.','Zoom into text and charts. Use circles, arrows, and freehand drawing to guide everyone’s attention.'],['02 / TEAM & PRODUCT FEEDBACK','Show exactly where.','Mark the spot before taking a screenshot. Paste the context into your team chat or the AI tool you already use.'],['03 / HOW-TO RECORDINGS','Keep the whole process.','Record your screen, with pause and resume when needed. Add an optional microphone or camera feed and save locally.']],
    workflowTitle:'Stay in your flow.<br>Just three steps.', workflowIntro:'These are the default shortcuts. You can customize them in the app.',
    steps:[['⌃ 2','Start drawing','Press Control + 2 to annotate your screen.'],['○ ↗','Point it out','Use circles, arrows, and text to show exactly what you mean.'],['⌃ 6 → ⌘ V','Capture and paste','Press Control + 6 to capture a region, then Command + V to paste into an app that accepts images.']],
    playgroundTitle:'Give it a little circle.', playgroundIntro:'An interactive browser example. Annotations stay on your device. This example is not the DoraZoom app interface.',
    tools:['Circle','Pen','Arrow','Undo','Clear','Save PNG'], colors:['Red','Blue'], keyboard:'Drag to draw a circle, or press Enter on the canvas to add an example mark.',
    purchaseTitle:'Make your next<br>explanation easier.', purchaseIntro:'Buy once. No subscription. Coming to the Mac App Store, with an official purchase link here when it launches.',
    priceNote:'Final pricing and regional availability will be shown in the App Store.', support:'Contact support',
    faqTitle:'A few things before you start.',
    faq:[['Why does it need Screen Recording permission?','macOS uses this permission to protect screen content. Zoom, screenshots, OCR, and recording need access to that content. Follow the app’s prompt when using these features. Microphone and camera access are optional.'],['Are my screenshots or OCR results uploaded?','DoraZoom processes screenshots, OCR, and recordings locally. The app does not upload this content to us. You choose what to save or share.'],['Does it support English and Chinese?','The app includes English, Simplified Chinese, and other localizations, selected using your macOS language preferences. The interface language is separate from the language you type; use your system input method to enter text.'],['How do I paste a screenshot?','Press Control + 6 to capture a region, then Command + V to paste. The destination app must support image pasting; plain-text fields usually do not.'],['Can I install it now?','The Mac App Store version is under review and is not yet available to buy. We will add the installation link here at launch. For now, watch the walkthrough, try drawing, or browse the source on GitHub.']],
    footer:['Privacy','Terms','Support'], studio:'未然界域科技工作室', github:'GitHub / Source', home:'Back to home',
  },
};

function head(c, base, page = '') {
  const suffix = page ? `${page}/` : '';
  return `<!doctype html><html lang="${c.lang}"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${esc(c.title)}</title><meta name="description" content="${esc(c.description)}"><meta name="theme-color" content="#f7f8fa"><meta property="og:title" content="${esc(c.title)}"><meta property="og:description" content="${esc(c.description)}"><meta property="og:image" content="https://dorazoom.iwalk.pro/assets/dorazoom-icon.png"><link rel="canonical" href="https://dorazoom.iwalk.pro/${c.lang === 'en' ? 'en/' : ''}${suffix}"><link rel="alternate" hreflang="en" href="https://dorazoom.iwalk.pro/en/${suffix}"><link rel="alternate" hreflang="zh-Hans" href="https://dorazoom.iwalk.pro/${suffix}"><link rel="alternate" hreflang="x-default" href="https://dorazoom.iwalk.pro/${suffix}"><link rel="icon" href="${base}assets/dorazoom-icon.png"><link rel="stylesheet" href="${base}site.css"><script src="${base}language.js"></script><script src="${base}site.js" defer></script></head>`;
}

function languages(en, page = '') {
  const zh = en ? (page ? `../../${page}/index.html` : '../index.html') : (page ? 'index.html' : 'index.html');
  const eng = en ? 'index.html' : (page ? `../en/${page}/index.html` : 'en/index.html');
  return `<nav class="languages" aria-label="Language"><a data-language="zh" lang="zh-CN" href="${zh}" ${!en ? 'aria-current="true"' : ''}>中文</a><span aria-hidden="true">/</span><a data-language="en" lang="en" href="${eng}" ${en ? 'aria-current="true"' : ''}>EN</a></nav>`;
}

function home(c, en) {
  const base = en ? '../' : '';
  return `${head(c, base)}<body><a class="skip" href="#main">${c.skip}</a>
  <header class="header"><div class="shell nav"><a class="brand" href="index.html"><img src="${base}assets/dorazoom-icon.png" width="36" height="36" alt="">DoraZoom <small>for Mac</small></a><nav class="main-nav"><a href="#scenes">${c.nav[0]}</a><a href="#workflow">${c.nav[1]}</a></nav>${languages(en)}<a class="nav-cta" href="#get-started">${c.nav[2]} ↗</a></div></header>
  <main id="main"><section class="hero shell"><div class="hero-copy"><p class="eyebrow"><span>✳</span> ${c.eyebrow}</p><h1>${c.headline}</h1><p class="intro">${c.intro}</p><div class="actions"><button class="button dark" data-video>▶ ${c.watch}</button><a class="text-link" href="#playground">${c.try} ↗</a></div><p class="availability"><span></span>${c.available}</p><p class="fine">${c.requirements}</p></div>
  <figure class="hero-media"><div class="media-top"><span class="dots">● ● ●</span><span>DoraZoom / WALKTHROUGH</span></div><button class="poster" data-video aria-label="${c.watch}"><img src="${base}assets/teach.png" width="1920" height="1080" alt="${en ? 'Illustration of a screen presentation with annotations' : '屏幕讲解与标注的流程示意'}"><span class="play">▶</span></button><figcaption>${c.caption}</figcaption></figure></section>
  <div class="benefits shell">${c.benefits.map((b,i)=>`<span><i>0${i+1}</i>${b}</span>`).join('')}</div>
  <section class="section shell" id="scenes"><div class="section-heading"><div><p class="eyebrow">MADE FOR YOUR EVERYDAY</p><h2>${c.sceneTitle}</h2></div><p>${c.sceneIntro}</p></div><div class="scenes">${c.scenes.map((s,i)=>`<article><span class="index">${s[0]}</span><h3>${s[1]}</h3><p>${s[2]}</p><span class="scene-symbol" aria-hidden="true">${['⌕','↗','⏺'][i]}</span></article>`).join('')}</div></section>
  <section class="workflow" id="workflow"><div class="shell section"><div class="section-heading"><div><p class="eyebrow">STAY IN YOUR FLOW</p><h2>${c.workflowTitle}</h2></div><p>${c.workflowIntro}</p></div><div class="steps">${c.steps.map((s,i)=>`<article><div class="keys">${s[0]}</div><h3><span>0${i+1}</span>${s[1]}</h3><p>${s[2]}</p></article>`).join('')}</div></div></section>
  <section class="section shell" id="playground"><div class="section-heading"><div><p class="eyebrow">TRY IT YOURSELF</p><h2>${c.playgroundTitle}</h2></div><p>${c.playgroundIntro}</p></div><div class="playground"><div class="canvas-head"><span>DoraZoom Playground</span><span id="mark-count" role="status"></span></div><canvas id="drawing-canvas" width="1200" height="600" tabindex="0" aria-label="${c.keyboard}"></canvas><div class="toolbar" aria-label="${en ? 'Drawing tools' : '圈画工具'}">${c.tools.slice(0,3).map((t,i)=>`<button data-tool="${['circle','pen','arrow'][i]}" aria-pressed="${i===0}">${['○','✎','↗'][i]} ${t}</button>`).join('')}<span class="colors">${c.colors.map((t,i)=>`<button class="color ${i?'blue':'red'}" data-color="${i?'#345acf':'#e95142'}" aria-label="${t}" aria-pressed="${!i}"></button>`).join('')}</span><button id="undo">${c.tools[3]}</button><button id="clear">${c.tools[4]}</button><button id="save">${c.tools[5]} ↓</button></div></div><p class="fine">${c.keyboard}</p></section>
  <section class="purchase" id="get-started"><div class="shell"><img src="${base}assets/dorazoom-icon.png" alt="" width="76" height="76"><p class="eyebrow">DORAZOOM FOR MAC</p><h2>${c.purchaseTitle}</h2><p>${c.purchaseIntro}</p><div class="actions"><button class="button light" data-video>▶ ${c.watch}</button><a class="text-link" href="support/index.html">${c.support} ↗</a></div><p class="fine">${c.priceNote}</p></div></section>
  <section class="section shell faq"><h2>${c.faqTitle}</h2><div>${c.faq.map(([q,a])=>`<details><summary>${q}</summary><p>${a}</p></details>`).join('')}</div></section></main>
  <footer class="shell footer"><a class="brand" href="index.html">DoraZoom</a><p>© 2026 ${c.studio}</p><nav>${c.footer.map((t,i)=>`<a href="${['privacy','terms','support'][i]}/index.html">${t}</a>`).join('')}<a href="https://github.com/AdgaiWalker/Dorazoom/releases/tag/v1.0.0">${c.github}</a></nav></footer>
  <dialog id="video-dialog" aria-labelledby="video-title"><div class="dialog-head"><span id="video-title">${c.demoTitle}</span><button id="close-video" aria-label="${c.close}">✕</button></div><video controls playsinline preload="none" poster="${base}assets/teach.png"><source src="${base}assets/dorazoom-promo.mp4" type="video/mp4"></video><p>${c.caption} ${c.mediaNote}</p></dialog><div id="toast" role="status" aria-live="polite"></div></body></html>`;
}

for (const [lang,c] of Object.entries(copy)) {
  const out = lang === 'en' ? join(root,'en') : root;
  mkdirSync(out,{recursive:true});
  writeFileSync(join(out,'index.html'),home(c,lang === 'en'));
}

// English translations of the existing published legal and support content.
const documents = {
  privacy: ['Privacy policy', `<p>This policy explains how 未然界域科技工作室 (“we”) handles information in the DoraZoom macOS app, a local tool for screen zoom, annotation, screenshots, OCR, and recording.</p>
<h2>Information we process</h2><p>DoraZoom requires no account and contains no advertising, cross-app tracking, cloud inference, or third-party analytics SDK. The app does not upload screen content, screenshots, OCR text, microphone audio, camera images, or recordings to us. Content is processed locally in response to your actions. You decide whether to copy, save, or share it.</p>
<h2>System permissions</h2><ul><li>Screen Recording: used for screenshots, OCR, live zoom, scrolling capture, and screen recording.</li><li>Microphone: used only when you enable microphone recording.</li><li>Camera: used only when you enable camera picture-in-picture.</li><li>Accessibility or Input Monitoring: used for global shortcuts and input compatibility. Screenshot paste compatibility may convert Control + V to Command + V when enabled.</li></ul><p>You can revoke permissions in macOS System Settings. Related features may stop or offer reduced functionality, without affecting features that do not need that permission.</p>
<h2>Local files and retention</h2><p>Exported screenshots, videos, GIFs, DemoType files in editions that support them, and custom resources are saved to the locations you choose. Settings and unfinished recording recovery information may be stored in your Mac user directory. We cannot access this local content; you can delete it using DoraZoom or Finder.</p>
<h2>Website and support</h2><p>Our hosting provider may process basic technical logs to provide HTTPS, caching, and security. We do not use these logs to build advertising profiles. When you email support, we use the information you provide to address your issue, reply, and maintain support records. We do not sell your information. The website stores your language choice locally in your browser.</p>
<h2>Children’s privacy</h2><p>DoraZoom is not a service designed for children. We do not knowingly collect children’s personal information.</p>
<h2>Policy updates</h2><p>If our information handling changes, we will update this page and its effective date. Significant changes will be announced in the app or on the website.</p>
<h2>Contact</h2><p>To learn about, delete, or correct information provided through support, email <a href="mailto:praxiswalker@Outlook.com">praxiswalker@Outlook.com</a>. Operator: 未然界域科技工作室.</p>`],
  terms: ['Terms of use', `<p>Thank you for using DoraZoom. By using or downloading it, you agree to these terms. DoraZoom is provided by 未然界域科技工作室 for macOS 14 and later.</p>
<h2>License</h2><p>Subject to these terms, we grant you a personal, non-exclusive, non-transferable license to use DoraZoom obtained from the Mac App Store on a Mac you own or control. App Store purchases, refunds, Family Sharing, and downloads are governed by Apple’s applicable terms.</p>
<h2>Your content and permissions</h2><p>You are responsible for content you capture, record, annotate, and export, and for having the necessary rights and permissions. You control screen, microphone, camera, and Accessibility permissions. Do not record other people or protected content without permission.</p>
<h2>Restrictions</h2><p>You may not reverse engineer, crack, bypass authorization mechanisms, rent, or resell DoraZoom, or use it for unlawful activities or to infringe privacy or intellectual property rights.</p>
<h2>Third-party software</h2><p>DoraZoom includes third-party open-source components under their respective licenses. Applicable copyright and license notices accompany the software or project materials and do not change the DoraZoom license in these terms.</p>
<h2>Updates and availability</h2><p>We may release fixes and updates, or adjust or discontinue features for security, legal, or platform reasons. We will make reasonable efforts to maintain availability but do not guarantee identical functionality on every Mac, external display, or destination app.</p>
<h2>Disclaimer and limitation of liability</h2><p>DoraZoom is provided “as is.” To the maximum extent permitted by applicable law, 未然界域科技工作室 is not liable for indirect, incidental, or consequential losses arising from use of, or inability to use, the software.</p>
<h2>Contact</h2><p>For questions, email <a href="mailto:praxiswalker@Outlook.com">praxiswalker@Outlook.com</a>. Operator: 未然界域科技工作室.</p>`],
  support: ['Support', `<h2>Need a hand?</h2><p>Email <a href="mailto:praxiswalker@Outlook.com">praxiswalker@Outlook.com</a> with your macOS version, DoraZoom version, the feature involved, and steps to reproduce the issue. Do not include passwords, API keys, or screenshots containing private information.</p>
<h2>Getting started</h2><p>The Mac App Store version is under review. An installation link will appear on the homepage at launch.</p><ol><li>Once available, install DoraZoom from the Mac App Store and open it.</li><li>Use the DoraZoom menu bar icon to access features and settings.</li><li>Start the feature you need and follow its permission prompt. Enable microphone or camera only if you want them.</li><li>If a shortcut still does not work after authorization, quit DoraZoom completely and reopen it.</li></ol>
<h2>Screenshot and paste</h2><p>By default, press Control + 6 to select and capture a region. Press Command + V in an app that accepts images. A plain-text field cannot usually accept a screenshot.</p>
<h2>Language</h2><p>The app follows your macOS language preferences and includes English and Simplified Chinese. Where available, choose a per-app language in System Settings → General → Language &amp; Region, then reopen DoraZoom.</p>
<h2>Common questions</h2><p><strong>Are screenshots and OCR uploaded?</strong><br>No. Processing is local; you control export and sharing.</p><p><strong>Why is Screen Recording permission needed?</strong><br>macOS requires permission for the app to read screen content. DoraZoom uses it when you start a feature such as zoom, capture, OCR, or recording.</p><p><strong>Why are microphone and camera off by default?</strong><br>They are optional recording inputs and are used only when you enable them.</p><p><strong>How can I delete support information?</strong><br>Email us. We will verify your request and handle support records that can be deleted.</p>
<h2>Feedback</h2><p>DoraZoom is maintained by 未然界域科技工作室. Specific feedback about shortcuts, displays, captures, recording, and localization is welcome.</p>`],
};
for (const [page,[title,body]] of Object.entries(documents)) {
  const c={...copy.en,title:`DoraZoom — ${title}`,description:`DoraZoom ${title.toLowerCase()}.`};
  const out=join(root,'en',page);mkdirSync(out,{recursive:true});
  writeFileSync(join(out,'index.html'),`${head(c,'../../',page)}<body><main class="legal shell"><header class="legal-nav"><a class="brand" href="../index.html">DoraZoom</a>${languages(true,page)}</header><p class="eyebrow">未然界域科技工作室 · macOS 14+</p><h1>${title}</h1>${page==='support'?'':'<p class="fine">Effective: September 15, 2026</p>'}<nav class="legal-links"><a href="../index.html">Home</a>${copy.en.footer.map((t,i)=>`<a href="../${['privacy','terms','support'][i]}/index.html">${t}</a>`).join('')}</nav><article>${body}</article></main></body></html>`);
  // Preserve Chinese legal text, only add the shared language selector and scripts.
  const file=join(root,page,'index.html');let zh=readFileSync(file,'utf8');
  if(!zh.includes('language.js')) zh=zh.replace('</head>','<link rel="stylesheet" href="../site.css"><script src="../language.js"></script><script src="../site.js" defer></script></head>').replace('<body>','<body>').replace('<main class="wrap">',`<main class="wrap"><div class="legal-nav">${languages(false,page)}</div>`);
  writeFileSync(file,zh);
}
