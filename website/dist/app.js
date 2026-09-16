(() => {
  'use strict';
  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => [...document.querySelectorAll(selector)];
  const { t, en } = window.DoraZoomI18n;
  const canvas = $('#drawing-canvas');
  const display = canvas.getContext('2d');
  const sceneCanvas = document.createElement('canvas');
  sceneCanvas.width = 1440; sceneCanvas.height = 900;
  const ctx = sceneCanvas.getContext('2d');
  const W = 720, H = 450;
  let viewport = { x: 0, y: 0, width: W, height: H };
  const font = '"DM Sans", -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif';
  let tool = 'ellipse', color = '#f04438', drawing = null, pointerId = null;
  let marks = [{ type: 'ellipse', color: '#f04438', points: [{ x: 283, y: 299 }, { x: 458, y: 352 }] }];
  let revision = 0, exportRevision = -1, exportBlob = null, exportUrl = null;
  let toastTimer;
  const toast = (message) => {
    $('#toast').textContent = message;
    $('#toast').classList.add('visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => $('#toast').classList.remove('visible'), 3500);
  };
  function roundRect(x, y, w, h, radius, fill, stroke) {
    ctx.beginPath(); ctx.roundRect(x, y, w, h, radius);
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
  }
  function text(value, x, y, size, fill, weight = 400, align = 'left') {
    ctx.font = `${weight} ${size}px ${font}`; ctx.fillStyle = fill; ctx.textAlign = align; ctx.fillText(value, x, y);
  }
  function base() {
    ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#fafbfc'; ctx.fillRect(0, 0, W, 38);
    ctx.strokeStyle = '#edeef2'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(0, 38); ctx.lineTo(W, 38); ctx.stroke();
    ['#dce0e6', '#dce0e6', '#dce0e6'].forEach((c, i) => { ctx.beginPath(); ctx.fillStyle = c; ctx.arc(17 + i * 12, 19, 3, 0, Math.PI * 2); ctx.fill(); });
    roundRect(226, 8, 268, 22, 5, '#f0f2f5');
    text('acme.design / pricing', 360, 23, 10, '#a4a9b2', 400, 'center');
    text('acme', 43, 77, 19, '#252b37', 750);
    text(t('产品'), 504, 75, 10, '#a0a6b1'); text(t('价格'), 550, 75, 10, '#505967'); text(t('关于'), 596, 75, 10, '#a0a6b1');
    text(t('好点子，值得一个好开始。'), 360, 130, 26, '#242b39', 600, 'center');
    text(t('选一个计划，让你的下一个想法发生。'), 360, 158, 11, '#a2a8b4', 400, 'center');
    const cards = [
      { x: 52, name: 'Starter', price: '0', subtitle: t('给刚刚萌芽的想法'), button: t('免费开始'), features: [t('1 个创作空间'), t('基础组件库')] },
      { x: 276, name: 'Pro', price: '29', subtitle: t('给想再向前一步的你'), button: t('开始试用'), features: [t('无限创作空间'), t('完整组件与导出')], pro: true },
      { x: 500, name: 'Team', price: '99', subtitle: t('给一起创造的团队'), button: t('联系团队'), features: [t('团队共享空间'), t('协作与成员管理')] }
    ];
    cards.forEach((c) => {
      roundRect(c.x, 194, 168, 199, 10, c.pro ? '#f7f8fc' : '#fff', c.pro ? '#d6dce8' : '#e8ebf0');
      if (c.pro) { roundRect(c.x + 103, 204, 54, 19, 5, '#e8edf7'); text(t('人气之选'), c.x + 130, 217, 8, '#7a89ab', 500, 'center'); }
      text(c.name, c.x + 16, 222, 12, '#596271', 600);
      text(c.subtitle, c.x + 16, 244, 9, '#a8adb7');
      text('¥', c.x + 16, 282, 15, '#303847', 500);
      text(c.price, c.x + 30, 282, 30, '#303847', 600);
      text(t('/ 月'), c.x + (c.price.length === 1 ? 55 : 71), 281, 9, '#a4aab4');
      roundRect(c.x + 16, 309, 136, 33, 6, c.pro ? '#293345' : '#f4f5f8', c.pro ? undefined : '#e7eaf0');
      text(c.button, c.x + 84, 330, 11, c.pro ? '#fff' : '#7d8592', 500, 'center');
      c.features.forEach((f, i) => { text('✓', c.x + 17, 363 + i * 16, 10, '#b0b6c0'); text(f, c.x + 34, 363 + i * 16, 9, '#a0a7b2'); });
    });
    text(t('网页示例 · 在这里标注你的修改想法'), 360, 427, 9, '#c0c4cc', 400, 'center');
  }
  function drawMark(mark) {
    const first = mark.points[0], last = mark.points[mark.points.length - 1];
    ctx.strokeStyle = mark.color; ctx.fillStyle = mark.color; ctx.lineWidth = 2.7; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.beginPath();
    if (mark.type === 'ellipse') {
      ctx.ellipse((first.x + last.x) / 2, (first.y + last.y) / 2, Math.max(Math.abs(last.x - first.x) / 2, 1), Math.max(Math.abs(last.y - first.y) / 2, 1), -.035, 0, 2 * Math.PI); ctx.stroke();
    } else if (mark.type === 'arrow') {
      ctx.moveTo(first.x, first.y); ctx.lineTo(last.x, last.y); ctx.stroke();
      const angle = Math.atan2(last.y - first.y, last.x - first.x), head = 13;
      ctx.beginPath(); ctx.moveTo(last.x - head * Math.cos(angle - .45), last.y - head * Math.sin(angle - .45)); ctx.lineTo(last.x, last.y); ctx.lineTo(last.x - head * Math.cos(angle + .45), last.y - head * Math.sin(angle + .45)); ctx.stroke();
    } else {
      ctx.moveTo(first.x, first.y); mark.points.slice(1).forEach((point) => ctx.lineTo(point.x, point.y)); ctx.stroke();
    }
  }
  function render() {
    ctx.setTransform(2, 0, 0, 2, 0, 0); base(); marks.forEach(drawMark); if (drawing) drawMark(drawing);
    display.clearRect(0, 0, canvas.width, canvas.height);
    display.drawImage(sceneCanvas, viewport.x * 2, viewport.y * 2, viewport.width * 2, viewport.height * 2, 0, 0, canvas.width, canvas.height);
    $('#annotation-count').textContent = en ? `${marks.length} annotation${marks.length === 1 ? '' : 's'}` : `${marks.length} 处标注`;
    $('#undo').disabled = !marks.length; $('#clear').disabled = !marks.length;
    canvas.setAttribute('aria-label', en ? `Drawing playground, ${marks.length} annotation${marks.length === 1 ? '' : 's'}. Drag to draw or press Enter to mark the example button.` : `圈画体验区，已有 ${marks.length} 处标注。鼠标或手指拖动标注，按 Enter 标注示例按钮。`);
  }
  function invalidate() {
    revision++;
    if (exportBlob) $('#generate').innerHTML = t('更新标注截图 <span aria-hidden="true">↗</span>');
    render();
  }
  function point(event) {
    const box = canvas.getBoundingClientRect();
    return { x: viewport.x + Math.max(0, Math.min(viewport.width, (event.clientX - box.left) * viewport.width / box.width)), y: viewport.y + Math.max(0, Math.min(viewport.height, (event.clientY - box.top) * viewport.height / box.height)) };
  }
  // Keep marks in full-scene coordinates as the visible canvas switches to a close-up.
  const canvasResize = new ResizeObserver(([entry]) => {
    const compact = entry.contentRect.width < 480;
    const next = compact ? { x: 260, y: 184, width: 200, height: 220 } : { x: 0, y: 0, width: W, height: H };
    if (next.width === viewport.width) return;
    drawing = null;
    if (pointerId !== null && canvas.hasPointerCapture(pointerId)) canvas.releasePointerCapture(pointerId);
    pointerId = null; viewport = next;
    canvas.width = next.width * 2; canvas.height = next.height * 2;
    canvas.style.aspectRatio = `${next.width} / ${next.height}`;
    $('#canvas-view-note').hidden = !compact;
    $('.canvas-container').classList.toggle('compact', compact);
    render();
  });
  canvasResize.observe($('.canvas-container'));
  canvas.addEventListener('pointerdown', (event) => {
    if (pointerId !== null || event.button !== 0 || !event.isPrimary) return;
    event.preventDefault(); canvas.focus({ preventScroll: true }); pointerId = event.pointerId; canvas.setPointerCapture(pointerId);
    drawing = { type: tool, color, points: [point(event), point(event)] }; $('#canvas-hint').classList.add('used');
  });
  canvas.addEventListener('pointermove', (event) => {
    if (!drawing || event.pointerId !== pointerId) return;
    if (tool === 'pen') drawing.points.push(point(event)); else drawing.points[1] = point(event);
    render();
  });
  function finishDraw(event, cancel = false) {
    if (!drawing || event.pointerId !== pointerId) return;
    if (!cancel) {
      const a = drawing.points[0], b = drawing.points[drawing.points.length - 1];
      if (Math.hypot(b.x - a.x, b.y - a.y) > 3 || drawing.points.length > 3) { marks.push(drawing); if (marks.length > 150) marks.shift(); }
    }
    drawing = null; pointerId = null; invalidate();
  }
  canvas.addEventListener('pointerup', (event) => finishDraw(event));
  canvas.addEventListener('pointercancel', (event) => finishDraw(event, true));
  canvas.addEventListener('lostpointercapture', (event) => finishDraw(event, true));
  function setTool(next) {
    if (!['ellipse', 'pen', 'arrow'].includes(next)) throw new Error(t('不支持的圈画工具'));
    tool = next; $$('[data-tool]').forEach((button) => { const selected = button.dataset.tool === next; button.classList.toggle('active', selected); button.setAttribute('aria-pressed', String(selected)); });
    $('#canvas-instruction').textContent = { ellipse: t('拖动画一个圈'), pen: t('自由画出你的想法'), arrow: t('拖动指出方向') }[next];
  }
  $$('[data-tool]').forEach((button) => button.addEventListener('click', () => setTool(button.dataset.tool)));
  $$('[data-color]').forEach((button) => button.addEventListener('click', () => { color = button.dataset.color; $$('[data-color]').forEach((b) => { const selected = b === button; b.classList.toggle('active', selected); b.setAttribute('aria-pressed', String(selected)); }); }));
  function undo() { if (marks.length) { marks.pop(); invalidate(); } }
  function clearMarks() { marks = []; drawing = null; pointerId = null; invalidate(); }
  function addExample() { marks.push({ type: 'ellipse', color, points: [{ x: 283, y: 299 }, { x: 458, y: 352 }] }); invalidate(); $('#canvas-hint').classList.add('used'); }
  $('#undo').addEventListener('click', undo); $('#clear').addEventListener('click', clearMarks); $('#add-example').addEventListener('click', addExample);
  canvas.addEventListener('keydown', (event) => {
    if (['1', '2', '3'].includes(event.key)) { event.preventDefault(); setTool({ 1: 'ellipse', 2: 'pen', 3: 'arrow' }[event.key]); }
    if (event.key === 'Enter') { event.preventDefault(); addExample(); }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z') { event.preventDefault(); undo(); }
    if (event.key === 'Escape' && drawing) { drawing = null; pointerId = null; render(); }
  });
  async function makeExport() {
    if (exportRevision === revision && exportBlob) return exportBlob;
    render();
    const capturedRevision = revision;
    // Export the complete scene, including marks outside the mobile close-up.
    ctx.setTransform(2, 0, 0, 2, 0, 0); base(); marks.forEach(drawMark);
    const blob = await new Promise((resolve, reject) => sceneCanvas.toBlob((result) => result ? resolve(result) : reject(new Error(t('图片生成失败，请重试'))), 'image/png'));
    if (exportUrl) URL.revokeObjectURL(exportUrl);
    exportBlob = blob; exportUrl = URL.createObjectURL(blob); exportRevision = capturedRevision;
    $('#attachment-image').src = exportUrl; $('#attachment-image').hidden = false; $('#attachment').classList.add('ready'); $('#export-actions').hidden = false;
    $('#generate').innerHTML = t('重新生成截图 <span aria-hidden="true">↗</span>');
    return blob;
  }
  function saveBlob(blob) {
    const url = URL.createObjectURL(blob), link = document.createElement('a'); link.href = url; link.download = t('DoraZoom-我的标注.png'); document.body.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 10000);
  }
const saveSiteButton = $('#save-site');
if (saveSiteButton) saveSiteButton.addEventListener('click', () => {
    const file = new Blob(['[InternetShortcut]\r\nURL=https://dorazoom.iwalk.pro/\r\n'], { type: 'application/internet-shortcut' });
    const url = URL.createObjectURL(file), link = document.createElement('a');
    link.href = url; link.download = t('DoraZoom-官网.url'); document.body.append(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
    toast(t('官网快捷方式已保存，打开它即可查看下载状态。'));
});
  $('#generate').addEventListener('click', async () => { try { await makeExport(); toast(t('标注截图已生成，可以复制或保存了。')); } catch (error) { toast(error.message); } });
  $('#save-image').addEventListener('click', async () => { try { saveBlob(await makeExport()); toast(t('已开始保存标注图片。')); } catch (error) { toast(error.message); } });
  $('#copy-image').addEventListener('click', async () => {
    try {
      if (!navigator.clipboard?.write || !window.ClipboardItem) { saveBlob(await makeExport()); toast(t('当前浏览器不支持复制图片，已为你保存。')); return; }
      const imagePromise = makeExport();
      await navigator.clipboard.write([new ClipboardItem({ 'image/png': imagePromise })]);
      toast(t('标注图片已复制，去 AI 对话中粘贴吧。'));
    } catch { toast(t('暂时无法复制图片，请点击「保存图片」。')); }
  });
  $('#copy-prompt').addEventListener('click', async () => {
    const input = $('#prompt-text');
    if (!input.value.trim()) { toast(t('先写一句你的修改想法吧。')); input.focus(); return; }
    try { await navigator.clipboard.writeText(input.value); toast(t('补充文字已复制。')); }
    catch { input.focus(); input.select(); toast(t('请按 Command / Control + C 复制选中的文字。')); }
  });
  const dialog = $('#video-dialog'), video = $('#promo-video');
  let videoTrigger = null;
  function openVideo(start = 0, trigger = document.activeElement) {
    videoTrigger = trigger;
    if (!dialog.open) dialog.showModal();
    document.body.style.overflow = 'hidden';
    const seekAndPlay = () => { video.currentTime = start; video.play().catch(() => {}); };
    if (video.readyState >= 1) seekAndPlay();
    else { video.addEventListener('loadedmetadata', seekAndPlay, { once: true }); video.load(); }
  }
  function closeVideo() { video.pause(); dialog.close(); }
  $$('[data-video]').forEach((button) => button.addEventListener('click', () => openVideo(0, button)));
  $('#close-video').addEventListener('click', closeVideo);
  dialog.addEventListener('click', (event) => { if (event.target === dialog) { const r = dialog.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) closeVideo(); } });
  dialog.addEventListener('close', () => { video.pause(); document.body.style.overflow = ''; videoTrigger?.focus({ preventScroll: true }); });
  const scenes = {
    ai: { tag: 'VIBE CODING', title: t('你的想法，<br>不必翻译成长提示词。'), description: t('圈出想修改的组件，标好方向，截下画面。把「改这里」连同上下文，一起粘贴给 AI。'), points: [t('圈出具体元素，减少位置描述'), t('截图到剪贴板，接上现有工作流'), t('由你使用的 AI 工具完成后续修改')], image: 'assets/ai-result.png', alt: t('圈选按钮、粘贴到 AI 对话并展示页面结果的示意画面'), caption: t('圈出意图 → 截图传达 → AI 接着完成'), start: 12.5 },
    teach: { tag: 'PRESENT & EXPLAIN', title: t('你讲到哪里，<br>目光就跟到哪里。'), description: t('放大关键一步，圈出需要注意的细节。面对文档、公式和复杂界面，让大家始终看见同一个重点。'), points: [t('静态与实时缩放，聚焦细节'), t('圈画、高亮、文字，一起讲清楚'), t('白板与黑板，随时展开思路')], image: 'assets/teach.png', alt: t('放大数学推导步骤，并用红笔圈出重点的教学示意画面'), caption: t('放大细节 → 圈出重点 → 同步理解'), start: 2.5 },
    record: { tag: 'RECORD & SHARE', title: t('你不在场，<br>讲解也能继续。'), description: t('把操作过程和屏幕圈画一起录下来。发出一段有重点的演示，让反馈、交接和说明都更直观。'), points: [t('全屏、区域或窗口录制'), t('把圈画保留在讲解视频中'), t('录制后预览、裁剪与导出')], image: 'assets/record.png', alt: t('包含红色圈画标注的录制视频播放器示意画面'), caption: t('开始录制 → 边操作边标注 → 分享讲解'), start: 22.5 }
  };
  let currentScene = 'ai';
  function setScene(key) {
    if (!Object.hasOwn(scenes, key)) throw new Error(t('未知的使用场景'));
    currentScene = key; const scene = scenes[key];
    $$('[data-scene]').forEach((button) => { const selected = button.dataset.scene === key; button.classList.toggle('active', selected); button.setAttribute('aria-selected', String(selected)); button.tabIndex = selected ? 0 : -1; });
    $('#scene-panel').setAttribute('aria-labelledby', `tab-${key}`); $('#scene-tag').textContent = scene.tag; $('#scene-title').innerHTML = scene.title; $('#scene-description').textContent = scene.description;
    $('#scene-points').replaceChildren(...scene.points.map((value) => { const li = document.createElement('li'); li.textContent = value; return li; }));
    $('#scene-image').src = scene.image; $('#scene-image').alt = scene.alt; $('#scene-caption').textContent = scene.caption;
  }
  $$('[data-scene]').forEach((button, index, buttons) => {
    button.addEventListener('click', () => setScene(button.dataset.scene));
    button.addEventListener('keydown', (event) => { let next; if (event.key === 'ArrowRight') next = (index + 1) % buttons.length; if (event.key === 'ArrowLeft') next = (index + buttons.length - 1) % buttons.length; if (event.key === 'Home') next = 0; if (event.key === 'End') next = buttons.length - 1; if (next !== undefined) { event.preventDefault(); setScene(buttons[next].dataset.scene); buttons[next].focus(); } });
  });
  $('#scene-watch').addEventListener('click', () => openVideo(scenes[currentScene].start)); $('#scene-play').addEventListener('click', () => openVideo(scenes[currentScene].start));
  if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const observer = new IntersectionObserver((entries) => entries.forEach((entry) => { if (entry.isIntersecting) { entry.target.classList.remove('pending'); observer.unobserve(entry.target); } }), { threshold: .1 });
    $$('.reveal').forEach((element) => { element.classList.add('pending'); observer.observe(element); });
  }
  function registerTools() {
    if (!document.modelContext?.registerTool) return;
    const lifecycle = new AbortController();
    const tools = [{ name: 'get_annotation_state', title: t('读取圈画状态'), description: t('读取本地圈画体验的工具、标注数量和截图是否需要更新，不读取补充文字。'), inputSchema: { type: 'object', properties: {}, additionalProperties: false }, annotations: { readOnlyHint: true, untrustedContentHint: false }, execute(input) { if (!input || typeof input !== 'object' || Object.keys(input).length) throw new Error(t('请输入空对象')); return { tool, color, annotationCount: marks.length, screenshotReady: !!exportBlob, screenshotCurrent: exportRevision === revision }; } }, { name: 'select_product_scene', title: t('切换产品场景'), description: t('在官网中显示 AI 协作、教学讲解或录屏分享场景。不会生成或修改图片。'), inputSchema: { type: 'object', properties: { scene: { type: 'string', enum: ['ai', 'teach', 'record'] } }, required: ['scene'], additionalProperties: false }, annotations: { readOnlyHint: false, untrustedContentHint: false }, execute(input) { if (!input || typeof input !== 'object' || Object.keys(input).length !== 1 || !Object.hasOwn(scenes, input.scene)) throw new Error(t('请选择 ai、teach 或 record')); setScene(input.scene); return { scene: currentScene, title: $('#scene-title').textContent }; } }];
    for (const entry of tools) { try { Promise.resolve(document.modelContext.registerTool(entry, { signal: lifecycle.signal })).catch(() => {}); } catch {} }
    window.addEventListener('pagehide', () => lifecycle.abort(), { once: true });
  }
  render(); document.fonts.ready.then(render); registerTools();
})();
