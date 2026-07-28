"use client";
/* eslint-disable @next/next/no-img-element -- tiny local icon; avoids an unnecessary image runtime in the interactive client surface */

import { useCallback, useEffect, useRef, useState } from "react";
import Magnet from "@/components/Magnet";
import SpotlightCard from "@/components/SpotlightCard";

type Mode = "zoom" | "draw" | "capture" | "record";

const modes: Array<{ id: Mode; label: string; key: string; result: string }> = [
  { id: "zoom", label: "放大", key: "⌃1", result: "细节进入视野" },
  { id: "draw", label: "圈画", key: "⌃2", result: "重点留在画面" },
  { id: "capture", label: "截图", key: "⌃6", result: "结果已到剪贴板" },
  { id: "record", label: "录制", key: "⌃5", result: "讲解完整留下" },
];

const flow = [
  {
    index: "01",
    title: "讲到哪里，放大哪里",
    body: "静态或实时缩放，光标和内容始终跟得上思路。听众不再猜“你说的是哪一块”。",
    shortcut: "Control + 1",
  },
  {
    index: "02",
    title: "顺手圈出关键关系",
    body: "画笔、箭头、高亮、文字和白板随时接上。不是切换工具，是继续讲解。",
    shortcut: "Control + 2",
  },
  {
    index: "03",
    title: "把结果直接带走",
    body: "截图进剪贴板，录制导出为常用格式。少一次保存和寻找，多一次自然衔接。",
    shortcut: "Control + 6",
  },
];

const localPoints = ["无需账号", "不依赖云服务", "截图可不落盘", "按需申请权限"];

function project(velocity: number, decelerationRate = 0.99) {
  return (velocity / 1000) * (decelerationRate / (1 - decelerationRate));
}

function rubberband(value: number, min: number, max: number, dimension: number) {
  if (value < min) {
    const over = value - min;
    return min + (over * dimension * 0.55) / (dimension + 0.55 * Math.abs(over));
  }
  if (value > max) {
    const over = value - max;
    return max + (over * dimension * 0.55) / (dimension + 0.55 * Math.abs(over));
  }
  return value;
}

export default function Home() {
  const [mode, setMode] = useState<Mode>("zoom");
  const [lens, setLens] = useState({ x: 395, y: 185 });
  const [dragging, setDragging] = useState(false);
  const stageRef = useRef<HTMLDivElement>(null);
  const animationRef = useRef<number | null>(null);
  const lensRef = useRef(lens);
  const gestureRef = useRef({
    pointerId: -1,
    startX: 0,
    startY: 0,
    lensX: 0,
    lensY: 0,
    lastX: 0,
    lastY: 0,
    lastTime: 0,
    velocityX: 0,
    velocityY: 0,
  });

  useEffect(() => {
    lensRef.current = lens;
  }, [lens]);

  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const elements = Array.from(document.querySelectorAll<HTMLElement>("[data-reveal]"));
    if (reduced) {
      elements.forEach((element) => element.classList.add("is-visible"));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            (entry.target as HTMLElement).classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.14 },
    );

    elements.forEach((element) => observer.observe(element));
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    return () => {
      if (animationRef.current !== null) cancelAnimationFrame(animationRef.current);
    };
  }, []);

  const setLensPosition = useCallback((x: number, y: number) => {
    const next = { x, y };
    lensRef.current = next;
    setLens(next);
  }, []);

  const animateLensTo = useCallback(
    (targetX: number, targetY: number, velocityX = 0, velocityY = 0) => {
      if (animationRef.current !== null) cancelAnimationFrame(animationRef.current);
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        setLensPosition(targetX, targetY);
        return;
      }

      let { x, y } = lensRef.current;
      let vx = velocityX;
      let vy = velocityY;
      let previous = performance.now();
      const stiffness = 310;
      const damping = 28;

      const tick = (time: number) => {
        const dt = Math.min((time - previous) / 1000, 0.032);
        previous = time;
        vx += ((targetX - x) * stiffness - vx * damping) * dt;
        vy += ((targetY - y) * stiffness - vy * damping) * dt;
        x += vx * dt;
        y += vy * dt;
        setLensPosition(x, y);

        if (Math.hypot(targetX - x, targetY - y) < 0.35 && Math.hypot(vx, vy) < 5) {
          setLensPosition(targetX, targetY);
          animationRef.current = null;
          return;
        }
        animationRef.current = requestAnimationFrame(tick);
      };

      animationRef.current = requestAnimationFrame(tick);
    },
    [setLensPosition],
  );

  const getBounds = useCallback(() => {
    const rect = stageRef.current?.getBoundingClientRect();
    return {
      width: rect?.width ?? 720,
      height: rect?.height ?? 460,
      maxX: Math.max(16, (rect?.width ?? 720) - 166),
      maxY: Math.max(70, (rect?.height ?? 460) - 166),
    };
  }, []);

  const onLensPointerDown = (event: React.PointerEvent<HTMLDivElement>) => {
    if (animationRef.current !== null) cancelAnimationFrame(animationRef.current);
    event.currentTarget.setPointerCapture(event.pointerId);
    const now = performance.now();
    gestureRef.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      lensX: lensRef.current.x,
      lensY: lensRef.current.y,
      lastX: event.clientX,
      lastY: event.clientY,
      lastTime: now,
      velocityX: 0,
      velocityY: 0,
    };
    setDragging(true);
  };

  const onLensPointerMove = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!dragging || gestureRef.current.pointerId !== event.pointerId) return;
    const gesture = gestureRef.current;
    const now = performance.now();
    const dt = Math.max(8, now - gesture.lastTime) / 1000;
    gesture.velocityX = (event.clientX - gesture.lastX) / dt;
    gesture.velocityY = (event.clientY - gesture.lastY) / dt;
    gesture.lastX = event.clientX;
    gesture.lastY = event.clientY;
    gesture.lastTime = now;

    const bounds = getBounds();
    const rawX = gesture.lensX + event.clientX - gesture.startX;
    const rawY = gesture.lensY + event.clientY - gesture.startY;
    setLensPosition(
      rubberband(rawX, 16, bounds.maxX, bounds.width),
      rubberband(rawY, 70, bounds.maxY, bounds.height),
    );
  };

  const releaseLens = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!dragging || gestureRef.current.pointerId !== event.pointerId) return;
    setDragging(false);
    const { maxX, maxY } = getBounds();
    const gesture = gestureRef.current;
    const projectedX = lensRef.current.x + project(gesture.velocityX);
    const projectedY = lensRef.current.y + project(gesture.velocityY);
    const snapPoints = [
      { x: 54, y: 112 },
      { x: maxX, y: 98 },
      { x: 116, y: maxY },
      { x: maxX - 34, y: maxY - 12 },
    ];
    const target = snapPoints.reduce((best, point) => {
      const bestDistance = Math.hypot(best.x - projectedX, best.y - projectedY);
      const distance = Math.hypot(point.x - projectedX, point.y - projectedY);
      return distance < bestDistance ? point : best;
    });
    animateLensTo(target.x, target.y, gesture.velocityX, gesture.velocityY);
  };

  const onLensKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    const step = event.shiftKey ? 28 : 10;
    const movement: Record<string, [number, number]> = {
      ArrowLeft: [-step, 0],
      ArrowRight: [step, 0],
      ArrowUp: [0, -step],
      ArrowDown: [0, step],
    };
    if (!movement[event.key]) return;
    event.preventDefault();
    const bounds = getBounds();
    const [dx, dy] = movement[event.key];
    animateLensTo(
      Math.min(bounds.maxX, Math.max(16, lensRef.current.x + dx)),
      Math.min(bounds.maxY, Math.max(70, lensRef.current.y + dy)),
    );
  };

  const activeMode = modes.find((item) => item.id === mode) ?? modes[0];

  return (
    <main>
      <header className="site-header" aria-label="主导航">
        <a className="brand" href="#top" aria-label="DoraZoom 首页">
          <img src="/dorazoom-icon.png" alt="" width="36" height="36" />
          <span>DoraZoom</span>
        </a>
        <nav className="desktop-nav" aria-label="页面导航">
          <a href="#why">为什么</a>
          <a href="#workflow">怎么用</a>
          <a href="#privacy">本地优先</a>
        </nav>
        <a className="nav-download pressable" href="/DoraZoom.zip" download>
          下载 Mac 版 <span aria-hidden="true">↓</span>
        </a>
      </header>

      <section className="hero" id="top">
        <div className="hero-aura" aria-hidden="true" />
        <div className="hero-copy" data-reveal>
          <div className="eyebrow"><span /> 为 Mac 上的讲解者而做</div>
          <h1>把注意力，<br />带到你正在讲的地方。</h1>
          <p className="hero-subtitle">
            一个快捷键，放大、圈画、截图或录制。<br className="desktop-break" />
            不打断表达，也不让重点从屏幕上溜走。
          </p>
          <div className="hero-actions">
            <Magnet wrapperClassName="magnet-wrap" padding={68} magnetStrength={9}>
              <a className="primary-button pressable" href="/DoraZoom.zip" download>
                <span>下载 macOS 版</span>
                <span className="button-arrow" aria-hidden="true">↘</span>
              </a>
            </Magnet>
            <a className="text-link" href="#demo">先体验一下 <span aria-hidden="true">→</span></a>
          </div>
          <p className="download-note">macOS 14+ · 无需账号 · 本地运行</p>
        </div>

        <div className="product-shell" id="demo" data-reveal>
          <div className="demo-toolbar" role="group" aria-label="体验不同功能">
            {modes.map((item) => (
              <button
                className={`mode-button ${mode === item.id ? "is-active" : ""}`}
                key={item.id}
                type="button"
                aria-pressed={mode === item.id}
                onClick={() => setMode(item.id)}
              >
                <span>{item.label}</span>
                <kbd>{item.key}</kbd>
              </button>
            ))}
          </div>

          <div className={`demo-stage mode-${mode}`} ref={stageRef}>
            <div className="mock-window">
              <div className="window-bar">
                <div className="traffic-lights" aria-hidden="true"><i /><i /><i /></div>
                <div className="window-title">产品复盘 · 7 月</div>
                <div className="window-actions" aria-hidden="true"><span>•••</span><span>分享</span></div>
              </div>
              <div className="workspace">
                <aside className="sidebar" aria-hidden="true">
                  <div className="side-title" />
                  <div className="side-row active" /><div className="side-row" /><div className="side-row short" />
                  <div className="side-caption" />
                  <div className="side-row" /><div className="side-row short" />
                </aside>
                <div className="canvas">
                  <div className="canvas-topline">本月，我们找对了增长杠杆</div>
                  <div className="metric-row">
                    <div className="metric"><span>活跃用户</span><strong>18.4k</strong><em>+24%</em></div>
                    <div className="metric"><span>完成率</span><strong>72%</strong><em>+11%</em></div>
                    <div className="metric"><span>平均时长</span><strong>8m</strong><em>−18%</em></div>
                  </div>
                  <div className="chart-card">
                    <div className="chart-heading"><span>留存趋势</span><small>最近 8 周</small></div>
                    <div className="chart" aria-label="上升的留存趋势图">
                      <i style={{ height: "26%" }} /><i style={{ height: "34%" }} /><i style={{ height: "31%" }} />
                      <i style={{ height: "46%" }} /><i style={{ height: "54%" }} /><i style={{ height: "61%" }} />
                      <i className="focus-bar" style={{ height: "78%" }} /><i style={{ height: "88%" }} />
                    </div>
                  </div>
                  <div className="insight-row"><span className="insight-dot" /> 新手引导缩短后，第二周留存提升最明显。</div>
                </div>
              </div>
            </div>

            <div className="draw-layer" aria-hidden="true">
              <i className="draw-underline" /><i className="draw-circle" /><i className="draw-arrow" />
              <span>关键变化</span>
            </div>

            <div className="capture-frame" aria-hidden="true">
              <i /><i /><i /><i />
              <span>860 × 420</span>
            </div>

            <div className="recording-ui" aria-hidden="true">
              <span className="record-dot" /><strong>00:18</strong>
              <div className="audio-wave"><i /><i /><i /><i /><i /></div>
            </div>

            <div
              className={`zoom-lens ${dragging ? "is-dragging" : ""}`}
              style={{ transform: `translate3d(${lens.x}px, ${lens.y}px, 0)` }}
              role="slider"
              tabIndex={mode === "zoom" ? 0 : -1}
              aria-label="拖动放大镜查看屏幕细节"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(Math.min(100, Math.max(0, (lens.x / 554) * 100)))}
              aria-valuetext="可移动的放大镜"
              onPointerDown={onLensPointerDown}
              onPointerMove={onLensPointerMove}
              onPointerUp={releaseLens}
              onPointerCancel={releaseLens}
              onKeyDown={onLensKeyDown}
            >
              <div className="lens-content">
                <span>完成率</span><strong>72%</strong><em>+11%</em>
              </div>
              <div className="lens-handle" aria-hidden="true" />
            </div>

            <div className="mode-result" aria-live="polite">
              <span className={`result-icon result-${mode}`} aria-hidden="true" />
              <strong>{activeMode.result}</strong>
              <span className="result-hint">{mode === "zoom" ? "拖动光圈试试" : "点击上方切换功能"}</span>
            </div>
          </div>
        </div>
      </section>

      <section className="audience-strip" aria-label="适用场景">
        <span>给每一个需要讲清楚的人</span>
        <div className="audience-list" aria-hidden="true">
          <b>产品演示</b><i>•</i><b>在线教学</b><i>•</i><b>代码讲解</b><i>•</i><b>教程录制</b>
        </div>
      </section>

      <section className="purpose-section" id="why">
        <div className="section-kicker" data-reveal>不是更多工具，是更少打断。</div>
        <div className="purpose-grid">
          <h2 data-reveal>你继续讲。<br /><span>DoraZoom 负责让人看见。</span></h2>
          <p data-reveal>
            屏幕讲解最怕注意力断线：找菜单、切应用、保存文件、再回到现场。
            DoraZoom 把高频动作压进熟悉的快捷键里，让表达保持连续。
          </p>
        </div>
        <div className="result-cards">
          <SpotlightCard className="result-card orange-card" spotlightColor="rgba(255, 255, 255, 0.34)" data-reveal>
            <div className="card-number">01</div>
            <div className="focus-demo" aria-hidden="true"><span>看这里</span><i /></div>
            <div><h3>听众看见重点</h3><p>放大与圈画发生在同一块屏幕上，不需要口头描述坐标。</p></div>
          </SpotlightCard>
          <SpotlightCard className="result-card ink-card" spotlightColor="rgba(255, 90, 24, 0.28)" data-reveal>
            <div className="card-number">02</div>
            <div className="clipboard-demo" aria-hidden="true"><div>⌘V</div><span>已复制</span></div>
            <div><h3>结果立刻流转</h3><p>截图直接进入剪贴板，下一秒就能粘贴给同事或 AI。</p></div>
          </SpotlightCard>
          <SpotlightCard className="result-card blue-card" spotlightColor="rgba(255, 255, 255, 0.3)" data-reveal>
            <div className="card-number">03</div>
            <div className="record-demo" aria-hidden="true"><span /><i /><i /><i /><i /><i /></div>
            <div><h3>讲解完整留下</h3><p>画面、声音、摄像头和标注一起录下，导出即可继续编辑。</p></div>
          </SpotlightCard>
        </div>
      </section>

      <section className="workflow-section" id="workflow">
        <div className="workflow-heading" data-reveal>
          <span className="section-label">一条不被打断的讲解流</span>
          <h2>按下快捷键，<br />然后继续你的思路。</h2>
        </div>
        <div className="flow-list">
          {flow.map((item) => (
            <article className="flow-item" key={item.index} data-reveal>
              <span className="flow-index">{item.index}</span>
              <div><h3>{item.title}</h3><p>{item.body}</p></div>
              <kbd>{item.shortcut}</kbd>
            </article>
          ))}
        </div>
        <div className="shortcut-ticker" aria-label="常用快捷键">
          <div>
            <span><kbd>⌃1</kbd> 静态缩放</span><span><kbd>⌃2</kbd> 原比例绘画</span>
            <span><kbd>⌃5</kbd> 全屏录制</span><span><kbd>⌃6</kbd> 截图复制</span>
            <span><kbd>⌃8</kbd> 长截图</span><span><kbd>W</kbd> 白板</span><span><kbd>K</kbd> 黑板</span>
          </div>
        </div>
      </section>

      <section className="privacy-section" id="privacy">
        <div className="privacy-visual" data-reveal aria-hidden="true">
          <div className="privacy-orbit orbit-one" /><div className="privacy-orbit orbit-two" />
          <div className="privacy-core"><img src="/dorazoom-icon.png" alt="" width="64" height="64" /><span>只在你的 Mac</span></div>
          <span className="privacy-chip chip-one">屏幕</span><span className="privacy-chip chip-two">声音</span>
          <span className="privacy-chip chip-three">剪贴板</span><span className="privacy-chip chip-four">录制</span>
        </div>
        <div className="privacy-copy" data-reveal>
          <span className="section-label">本地优先</span>
          <h2>你的屏幕，<br />不该绕远路。</h2>
          <p>DoraZoom 不需要账号，也不把讲解交给云端。权限只在相关功能真正需要时说明和申请。</p>
          <ul>
            {localPoints.map((point) => <li key={point}><span aria-hidden="true">✓</span>{point}</li>)}
          </ul>
        </div>
      </section>

      <section className="final-cta" data-reveal>
        <div className="cta-glow" aria-hidden="true" />
        <img src="/dorazoom-icon.png" alt="DoraZoom" width="92" height="92" />
        <h2>下一次讲解，<br />别让重点等你。</h2>
        <p>下载 DoraZoom，让每一次放大、圈画和截取都跟得上思路。</p>
        <Magnet wrapperClassName="magnet-wrap final-magnet" padding={80} magnetStrength={10}>
          <a className="cta-button pressable" href="/DoraZoom.zip" download>
            <span>下载 macOS 版</span><span aria-hidden="true">↓</span>
          </a>
        </Magnet>
        <small>适用于 macOS 14 及以上 · 个人测试版</small>
      </section>

      <footer>
        <a className="brand footer-brand" href="#top"><img src="/dorazoom-icon.png" alt="" width="32" height="32" />DoraZoom</a>
        <p>为讲清楚而做。</p>
        <span>© 2026 DoraZoom</span>
      </footer>
    </main>
  );
}
