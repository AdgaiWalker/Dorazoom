import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("https://dorazoom.example/", {
      headers: {
        accept: "text/html",
        host: "dorazoom.example",
        "x-forwarded-proto": "https",
      },
    }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("renders the DoraZoom product story without unsupported distribution claims", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>DoraZoom — 就在屏幕上，指给他看<\/title>/i);
  assert.match(html, /就在屏幕上，/);
  assert.match(html, /指给他看。/);
  assert.match(html, /不用切应用，也不用重复解释。/);
  assert.match(html, /放大、圈画、截图和录制，都留在当前画面。/);

  const scenarios = [
    ["同事", "看到要改的位置", "圈出图标，截图直接进入对话。"],
    ["学生", "对着原题看重点", "不切白板，重点还留在原题上。"],
    ["收件人", "找到你标的位置", "截下、标出、复制，对方不用猜。"],
    ["观众", "在录屏里看重点", "边讲边画，说明留在画面里。"],
  ];
  for (const [audience, result, savedStep] of scenarios) {
    assert.match(html, new RegExp(audience));
    assert.match(html, new RegExp(result));
    assert.match(html, new RegExp(savedStep));
    assert.ok(html.indexOf(result) < html.indexOf(savedStep));
  }

  for (const path of [
    "/scenes/codex-mark.png",
    "/scenes/codex-result.png",
  ]) {
    assert.match(html, new RegExp(`src="${path.replaceAll("/", "\\/")}"`));
  }
  for (const path of [
    "/scenes/codex-mark.png",
    "/scenes/codex-result.png",
    "/scenes/teaching.png",
    "/scenes/share.png",
    "/scenes/recording.jpg",
  ]) {
    assert.equal(existsSync(new URL(`../public${path}`, import.meta.url)), true);
  }

  for (const capability of [
    "放大当前画面，直接圈画。",
    "遮挡内容，添加编号。",
    "截图到剪贴板或文件。",
    "OCR 文字到剪贴板。",
    "录全屏或区域，可暂停继续。",
    "无需账号或云同步。当前未正式分发。",
  ]) {
    assert.match(html, new RegExp(capability));
  }

  assert.match(html, /四个结果，/);
  assert.match(html, /真实画面，不是功能示意图。/);
  assert.match(html, /href="#tutorial">教程<\/a>/);

  const tutorialFlow = [
    "第一次用，",
    "首次运行",
    "进入圈画",
    "指出重点",
    "框选并复制",
    "粘贴给对方",
    "换个任务，",
    "查看全部快捷键",
  ];
  for (const marker of tutorialFlow) {
    assert.match(html, new RegExp(marker));
  }
  for (let index = 1; index < tutorialFlow.length; index += 1) {
    assert.ok(html.indexOf(tutorialFlow[index - 1]) < html.indexOf(tutorialFlow[index]));
  }
  for (const tutorialFact of [
    "允许“屏幕录制”",
    "Control\\+2",
    "松手即复制到剪贴板",
    "Command\\+V",
    "Control\\+4",
    "aria-label=\"Control 加 Option 加 6\"",
    "预览、裁剪和导出",
    "实时圈画中第一次只退画笔",
  ]) {
    assert.match(html, new RegExp(tutorialFact));
  }
  assert.doesNotMatch(html, /Control\+Option\+5|录全屏、区域或窗口/);

  assert.match(html, /它替你省下/);
  assert.match(html, /先说结果，再看能力。/);

  assert.match(html, /href="https:\/\/github\.com\/AdgaiWalker\/zoomit"/);
  assert.match(html, /查看源码/);
  assert.match(html, /当前状态/);
  assert.doesNotMatch(
    html,
    /<a\b[^>]*(?:\bdownload\b|href="[^"]*(?:\/download\b|\.zip\b|\.dmg\b|\.pkg\b)[^"]*")/i,
  );
  assert.doesNotMatch(
    html,
    /立即下载|现可下载|下载(?:\s*DoraZoom|\s*macOS|\s*Mac)|下载安装|安装\s*Mac|现已(?:正式)?发布|已经(?:正式)?发布|正式发布(?:版|！|!|。|<)|支持\s*macOS|兼容(?:性|\s*macOS|\s*QuickTime)|macOS\s*\d+\+|个人测试版|\d+(?:\.\d+)?k\s*用户/i,
  );
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|react-loading-skeleton/i);
});

test("publishes a site-specific social preview", async () => {
  const response = await render();
  const html = await response.text();

  assert.match(html, /property="og:image"/);
  assert.match(html, /https:\/\/dorazoom\.example\/og\.png/);
  assert.match(html, /name="twitter:card" content="summary_large_image"/);
});

test("does not expose a dormant distribution archive", () => {
  assert.equal(existsSync(new URL("../public/DoraZoom.zip", import.meta.url)), false);
  assert.equal(existsSync(new URL("../dist/client/DoraZoom.zip", import.meta.url)), false);
});
