import assert from "node:assert/strict";
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

test("renders the DoraZoom product story and real download", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>DoraZoom — 把注意力带到你正在讲的地方<\/title>/i);
  assert.match(html, /把注意力/);
  assert.match(html, /带到你正在讲的地方/);
  assert.match(html, /href="\/DoraZoom\.zip"/);
  assert.match(html, /本地优先/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|react-loading-skeleton/i);
});

test("publishes a site-specific social preview", async () => {
  const response = await render();
  const html = await response.text();

  assert.match(html, /property="og:image"/);
  assert.match(html, /https:\/\/dorazoom\.example\/og\.png/);
  assert.match(html, /name="twitter:card" content="summary_large_image"/);
});
