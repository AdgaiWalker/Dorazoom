"use client";
/* eslint-disable @next/next/no-img-element -- documentary product images are local and intentionally unprocessed */

import { useCallback, useEffect, useRef, useState } from "react";
import { createFrameAnimator } from "../lib/oil-motion/interactive-motion";

type ScenarioId = "codex" | "teaching" | "share" | "recording";

type Scenario = {
  id: ScenarioId;
  audience: string;
  title: string;
  detail: string;
  image: string;
  alt: string;
  note?: string;
};

const githubUrl = "https://github.com/AdgaiWalker/zoomit";

const scenarios: Scenario[] = [
  {
    id: "codex",
    audience: "同事",
    title: "看到要改的位置",
    detail: "圈出图标，截图直接进入对话。",
    image: "/scenes/codex-mark.png",
    alt: "DoraZoom 官网中，GitHub 图标被红框圈出",
  },
  {
    id: "teaching",
    audience: "学生",
    title: "对着原题看重点",
    detail: "不切白板，重点还留在原题上。",
    image: "/scenes/teaching.png",
    alt: "数学原题中的函数图像被红框标出",
  },
  {
    id: "share",
    audience: "收件人",
    title: "找到你标的位置",
    detail: "截下、标出、复制，对方不用猜。",
    image: "/scenes/share.png",
    alt: "数据界面中的运行次数被红色箭头指出",
  },
  {
    id: "recording",
    audience: "观众",
    title: "在录屏里看重点",
    detail: "边讲边画，说明留在画面里。",
    image: "/scenes/recording.jpg",
    alt: "电脑上正在编辑一段带有屏幕标注的录屏",
    note: "录制工作现场；画面中的 Screen Studio 不代表产品集成。",
  },
];

const capabilities = [
  "放大当前画面，直接圈画。",
  "遮挡内容，添加编号。",
  "截图到剪贴板或文件。",
  "OCR 文字到剪贴板。",
  "录全屏或区域，可暂停继续。",
  "无需账号或云同步。当前未正式分发。",
];

type KeySet = {
  keys: string[];
  label: string;
  caption?: string;
};

const quickStartSteps = [
  {
    number: "01",
    keySet: { keys: ["⌃", "2"], label: "Control 加 2" },
    title: "进入圈画",
    detail: "按下 Control+2，当前画面立即成为画布。",
  },
  {
    number: "02",
    keySet: { keys: ["拖动鼠标"], label: "拖动鼠标" },
    title: "指出重点",
    detail: "直接画线；按住 Control 画矩形，按住 Control+Shift 画箭头。",
  },
  {
    number: "03",
    keySet: { keys: ["⌃", "6"], label: "Control 加 6" },
    title: "框选并复制",
    detail: "拖出范围，松手即复制到剪贴板；不需要先保存文件。",
  },
  {
    number: "04",
    keySet: { keys: ["⌘", "V"], label: "Command 加 V" },
    title: "粘贴给对方",
    detail: "先按 Esc 退出圈画，再到聊天、邮件或 AI 对话里按 Command+V 粘贴。",
  },
];

const taskShortcuts: Array<{
  title: string;
  detail: string;
  keySets: KeySet[];
}> = [
  {
    title: "放大当前画面",
    detail: "冻结并放大当前画面，单击后可继续圈画；按 Esc 退出。",
    keySets: [{ keys: ["⌃", "1"], label: "Control 加 1" }],
  },
  {
    title: "边操作边放大",
    detail: "移动鼠标平移，滚轮或触控板调倍率；再次按 Control+4 退出。",
    keySets: [{ keys: ["⌃", "4"], label: "Control 加 4" }],
  },
  {
    title: "识别屏幕文字",
    detail: "框住文字，松手后由 OCR 复制到剪贴板。",
    keySets: [{ keys: ["⌃", "⌥", "6"], label: "Control 加 Option 加 6" }],
  },
  {
    title: "录下讲解",
    detail: "开始前可选声音；菜单栏可暂停。再次按 Control+5 停止，然后预览、裁剪和导出。",
    keySets: [
      { keys: ["⌃", "5"], label: "Control 加 5", caption: "全屏" },
      { keys: ["⌃", "⇧", "5"], label: "Control 加 Shift 加 5", caption: "区域" },
    ],
  },
];

const shortcutGroups: Array<{
  title: string;
  rows: Array<{ keySet: KeySet; action: string }>;
}> = [
  {
    title: "进入模式",
    rows: [
      { keySet: { keys: ["⌃", "1"], label: "Control 加 1" }, action: "静态放大" },
      { keySet: { keys: ["⌃", "2"], label: "Control 加 2" }, action: "原比例圈画" },
      { keySet: { keys: ["⌃", "3"], label: "Control 加 3" }, action: "休息倒计时" },
      { keySet: { keys: ["⌃", "4"], label: "Control 加 4" }, action: "实时放大" },
      { keySet: { keys: ["⌃", "5"], label: "Control 加 5" }, action: "录制全屏" },
      { keySet: { keys: ["⌃", "⇧", "5"], label: "Control 加 Shift 加 5" }, action: "录制区域" },
      { keySet: { keys: ["⌃", "6"], label: "Control 加 6" }, action: "框选截图到剪贴板" },
      { keySet: { keys: ["⌃", "⇧", "6"], label: "Control 加 Shift 加 6" }, action: "框选截图保存为文件" },
      { keySet: { keys: ["⌃", "⌥", "6"], label: "Control 加 Option 加 6" }, action: "框选文字到剪贴板" },
      { keySet: { keys: ["⌃", "7"], label: "Control 加 7" }, action: "DemoType" },
      { keySet: { keys: ["⌃", "⇧", "7"], label: "Control 加 Shift 加 7" }, action: "DemoType 回到上一段" },
      { keySet: { keys: ["⌃", "8"], label: "Control 加 8" }, action: "滚动长截图到剪贴板" },
      { keySet: { keys: ["⌃", "⇧", "8"], label: "Control 加 Shift 加 8" }, action: "滚动长截图保存为文件" },
    ],
  },
  {
    title: "圈画时",
    rows: [
      { keySet: { keys: ["鼠标拖动"], label: "鼠标拖动" }, action: "自由画笔" },
      { keySet: { keys: ["⇧", "拖动"], label: "Shift 加拖动" }, action: "直线" },
      { keySet: { keys: ["⌃", "拖动"], label: "Control 加拖动" }, action: "矩形" },
      { keySet: { keys: ["⌃", "⇧", "拖动"], label: "Control 加 Shift 加拖动" }, action: "箭头" },
      { keySet: { keys: ["Tab", "拖动"], label: "Tab 加拖动" }, action: "椭圆" },
      { keySet: { keys: ["F", "/", "L", "/", "A", "/", "H"], label: "F、L、A 或 H" }, action: "画笔 / 直线 / 箭头 / 高亮" },
      { keySet: { keys: ["M", "/", "X", "/", "N"], label: "M、X 或 N" }, action: "模糊 / 实色遮挡 / 编号" },
      { keySet: { keys: ["T"], label: "T" }, action: "输入文字；Shift+T 右对齐" },
      { keySet: { keys: ["R", "G", "B", "Y", "O", "P"], label: "R、G、B、Y、O 或 P" }, action: "切换颜色；加 Shift 使用高亮墨水" },
      { keySet: { keys: ["[", "]"], label: "左方括号或右方括号" }, action: "减小 / 增大画笔粗细" },
      { keySet: { keys: ["W", "/", "K"], label: "W 或 K" }, action: "白板 / 黑板" },
      { keySet: { keys: ["⌘", "Z"], label: "Command 加 Z" }, action: "撤销上一步" },
      { keySet: { keys: ["E"], label: "E" }, action: "清除全部标注" },
    ],
  },
  {
    title: "输出与退出",
    rows: [
      { keySet: { keys: ["⌘", "C"], label: "Command 加 C" }, action: "复制当前视图" },
      { keySet: { keys: ["⌘", "S"], label: "Command 加 S" }, action: "保存当前视图" },
      { keySet: { keys: ["右键"], label: "鼠标右键" }, action: "退出圈画，回到当前缩放画面" },
      { keySet: { keys: ["Esc"], label: "Escape" }, action: "取消框选或退出当前状态；实时圈画中第一次只退画笔" },
    ],
  },
];

function KeyCombo({ keySet }: { keySet: KeySet }) {
  return (
    <span className="key-combo" aria-label={keySet.label}>
      {keySet.keys.map((key, index) => <kbd key={`${key}-${index}`}>{key}</kbd>)}
    </span>
  );
}

function ArrowDownIcon() {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true">
      <path d="M10 3v12M5.5 10.5 10 15l4.5-4.5" />
    </svg>
  );
}

function ArrowOutIcon() {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true">
      <path d="M7 5h8v8M15 5 5 15" />
    </svg>
  );
}

function CloseIcon() {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true">
      <path d="m5 5 10 10M15 5 5 15" />
    </svg>
  );
}

export default function Home() {
  const [activeScenario, setActiveScenario] = useState<ScenarioId>("codex");
  const [reducedMotion, setReducedMotion] = useState(false);
  const [pageVisible, setPageVisible] = useState(true);
  const [statusOpen, setStatusOpen] = useState(false);
  const lastManualSelectionRef = useRef(0);
  const statusTriggerRef = useRef<HTMLButtonElement>(null);
  const statusPanelRef = useRef<HTMLElement>(null);
  const statusCloseRef = useRef<HTMLButtonElement>(null);
  const proofMotionRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const queryRequestsReduced = new URLSearchParams(window.location.search).get("motion") === "reduce";
    const update = () => setReducedMotion(media.matches || queryRequestsReduced);
    update();
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  useEffect(() => {
    const onVisibilityChange = () => setPageVisible(!document.hidden);
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => document.removeEventListener("visibilitychange", onVisibilityChange);
  }, []);

  useEffect(() => {
    const root = proofMotionRef.current;
    const thumb = root?.querySelector<HTMLElement>(".transfer-thumb");
    const path = root?.querySelector<SVGPathElement>("path");
    if (!root || !thumb || !path) return;

    const showStaticLink = () => {
      thumb.style.opacity = "0";
      thumb.style.transform = "translateX(38px) scale(1)";
      path.style.opacity = "0.72";
      path.style.strokeDashoffset = "0";
    };

    if (reducedMotion || !pageVisible || statusOpen) {
      showStaticLink();
      return;
    }

    let animator: ReturnType<typeof createFrameAnimator> | null = null;
    const startCycle = () => {
      animator?.destroy();
      animator = createFrameAnimator({
        frameCount: 121,
        initialFrame: 0,
        smoothTime: 0.32,
        maxSpeed: 190,
        render: (frame) => {
          const progress = frame / 120;
          const fadeIn = Math.min(1, progress * 6);
          const fadeOut = 1 - Math.max(0, (progress - 0.78) / 0.22);
          const opacity = Math.max(0, fadeIn * fadeOut);
          thumb.style.opacity = opacity.toFixed(3);
          thumb.style.transform = `translateX(${(-18 + progress * 66).toFixed(2)}px) scale(${(0.92 + progress * 0.08).toFixed(3)})`;
          path.style.opacity = opacity.toFixed(3);
          path.style.strokeDashoffset = `${(50 * (1 - Math.min(1, progress * 1.8))).toFixed(2)}`;
        },
      });
      animator.setTarget(120);
    };

    startCycle();
    const timer = window.setInterval(startCycle, 4800);
    return () => {
      window.clearInterval(timer);
      animator?.destroy();
    };
  }, [pageVisible, reducedMotion, statusOpen]);

  useEffect(() => {
    if (reducedMotion || !pageVisible || statusOpen) return;
    const timer = window.setInterval(() => {
      if (Date.now() - lastManualSelectionRef.current < 7000) return;
      setActiveScenario((current) => {
        const index = scenarios.findIndex((scenario) => scenario.id === current);
        return scenarios[(index + 1) % scenarios.length].id;
      });
    }, 4200);
    return () => window.clearInterval(timer);
  }, [pageVisible, reducedMotion, statusOpen]);

  useEffect(() => {
    if (!statusOpen) return;
    const previousFocus = document.activeElement as HTMLElement | null;
    const fallbackFocus = statusTriggerRef.current;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const frame = window.requestAnimationFrame(() => statusCloseRef.current?.focus({ preventScroll: true }));

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setStatusOpen(false);
        return;
      }
      if (event.key !== "Tab") return;
      const panel = statusPanelRef.current;
      if (!panel) return;
      const focusable = Array.from(
        panel.querySelectorAll<HTMLElement>('a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'),
      );
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", onKeyDown);
    return () => {
      window.cancelAnimationFrame(frame);
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
      (previousFocus ?? fallbackFocus)?.focus({ preventScroll: true });
    };
  }, [statusOpen]);

  const selectScenario = useCallback((id: ScenarioId) => {
    lastManualSelectionRef.current = Date.now();
    setActiveScenario(id);
  }, []);

  const currentScenario = scenarios.find((scenario) => scenario.id === activeScenario) ?? scenarios[0];

  return (
    <main
      className="product-site"
      data-reduced={reducedMotion ? "true" : "false"}
      data-page-visible={pageVisible ? "true" : "false"}
    >
      <a className="skip-link" href="#results">跳到四个结果</a>

      <header className="site-header">
        <a className="site-brand" href="#top" aria-label="DoraZoom 首页">
          <img src="/dorazoom-icon.png" alt="" width="30" height="30" />
          <span>DoraZoom</span>
        </a>
        <nav aria-label="官网导航">
          <a href="#results">场景</a>
          <a href="#tutorial">教程</a>
          <a href="#capabilities">能力</a>
          <a href={githubUrl} target="_blank" rel="noreferrer">
            源码 <ArrowOutIcon />
          </a>
        </nav>
      </header>

      <section id="top" className="hero" aria-labelledby="hero-title">
        <div className="hero-main">
          <div className="hero-copy">
            <h1 id="hero-title">就在屏幕上，<br />指给他看。</h1>
            <p>不用切应用，也不用重复解释。放大、圈画、截图和录制，都留在当前画面。</p>
            <div className="hero-actions">
              <a className="primary-action" href="#results">
                看四个结果 <ArrowDownIcon />
              </a>
              <a className="secondary-action" href={githubUrl} target="_blank" rel="noreferrer">
                查看源码 <ArrowOutIcon />
              </a>
            </div>
          </div>

          <div className="hero-proof" aria-label="圈出位置后，截图直接进入 Codex 对话">
            <figure className="proof-step proof-source">
              <div className="proof-image-wrap">
                <img src="/scenes/codex-mark.png" alt="GitHub 图标在 DoraZoom 官网中被圈出" />
              </div>
              <figcaption>圈出位置</figcaption>
            </figure>
            <div ref={proofMotionRef} className="proof-transfer" aria-hidden="true">
              <span className="transfer-thumb"><img src="/scenes/codex-mark.png" alt="" /></span>
              <svg viewBox="0 0 48 20"><path d="M2 10h40M35 3l7 7-7 7" /></svg>
            </div>
            <figure className="proof-step proof-result">
              <div className="proof-image-wrap">
                <img src="/scenes/codex-result.png" alt="标注截图已经进入 Codex 对话" />
              </div>
              <figcaption>直接进入对话</figcaption>
            </figure>
          </div>
        </div>

        <div className="audience-strip" aria-label="适用对象">
          {scenarios.map((scenario) => (
            <div key={scenario.id}>
              <span>{scenario.audience}</span>
              <strong>{scenario.title}</strong>
            </div>
          ))}
        </div>
      </section>

      <section id="results" className="results" aria-labelledby="results-title">
        <div className="section-heading">
          <h2 id="results-title">四个结果，<br />一眼看完。</h2>
          <p>真实画面，不是功能示意图。</p>
        </div>

        <div className="results-layout">
          <figure key={currentScenario.id} className="result-media">
            <div className="result-image-wrap">
              <img src={currentScenario.image} alt={currentScenario.alt} />
            </div>
            {currentScenario.note && <figcaption>{currentScenario.note}</figcaption>}
          </figure>

          <div className="result-switcher" role="group" aria-label="选择真实场景">
            {scenarios.map((scenario) => (
              <button
                key={scenario.id}
                type="button"
                className={activeScenario === scenario.id ? "is-active" : ""}
                aria-pressed={activeScenario === scenario.id}
                onClick={() => selectScenario(scenario.id)}
              >
                <span>{scenario.audience}</span>
                <strong>{scenario.title}</strong>
                <em>{scenario.detail}</em>
              </button>
            ))}
          </div>
        </div>
        <p className="sr-only" aria-live="polite">
          {currentScenario.audience}：{currentScenario.title}。{currentScenario.detail}
        </p>
      </section>

      <section id="tutorial" className="tutorial" aria-labelledby="tutorial-title">
        <div className="tutorial-shell">
          <div className="tutorial-heading">
            <h2 id="tutorial-title">第一次用，<br />只记住四步。</h2>
            <p>快捷键唤起，直接在当前屏幕完成，不先打开编辑器。</p>
          </div>

          <aside className="tutorial-first-run" aria-label="首次运行说明">
            <span>首次运行</span>
            <p>打开后，DoraZoom 待在菜单栏。第一次触发放大、圈画或截图时，允许“屏幕录制”；授权后若仍无反应，从菜单栏打开“权限”并按提示重启，再按一次快捷键。</p>
          </aside>

          <ol className="tutorial-steps">
            {quickStartSteps.map((step) => (
              <li key={step.number}>
                <span className="tutorial-step-number">{step.number}</span>
                <KeyCombo keySet={step.keySet} />
                <h3>{step.title}</h3>
                <p>{step.detail}</p>
              </li>
            ))}
          </ol>

          <div className="tutorial-task-heading">
            <h3>换个任务，<br />只换第一个快捷键。</h3>
            <p>⌃ 是 Control。全局快捷键都可以在设置中修改。</p>
          </div>

          <div className="tutorial-tasks">
            {taskShortcuts.map((task) => (
              <article key={task.title}>
                <div className="task-keysets">
                  {task.keySets.map((keySet) => (
                    <span className="task-key-choice" key={keySet.label}>
                      <KeyCombo keySet={keySet} />
                      {keySet.caption && <small>{keySet.caption}</small>}
                    </span>
                  ))}
                </div>
                <h4>{task.title}</h4>
                <p>{task.detail}</p>
              </article>
            ))}
          </div>

          <details className="shortcut-index">
            <summary>
              <strong>查看全部快捷键</strong>
              <span>按任务查找</span>
            </summary>
            <div className="shortcut-groups">
              {shortcutGroups.map((group) => (
                <section key={group.title} aria-labelledby={`shortcut-${group.title}`}>
                  <h3 id={`shortcut-${group.title}`}>{group.title}</h3>
                  <div>
                    {group.rows.map((row) => (
                      <p key={`${group.title}-${row.keySet.label}`}>
                        <KeyCombo keySet={row.keySet} />
                        <span>{row.action}</span>
                      </p>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          </details>
        </div>
      </section>

      <section id="capabilities" className="capabilities" aria-labelledby="capabilities-title">
        <div className="capabilities-heading">
          <h2 id="capabilities-title">它替你省下<br />这些动作。</h2>
          <p>先说结果，再看能力。</p>
        </div>
        <div className="capability-list">
          {capabilities.map((capability) => <p key={capability}>{capability}</p>)}
        </div>
      </section>

      <footer className="site-footer">
        <a className="footer-brand" href="#top">
          <img src="/dorazoom-icon.png" alt="" width="36" height="36" />
          <span>DoraZoom</span>
        </a>
        <div className="footer-actions">
          <a href={githubUrl} target="_blank" rel="noreferrer">
            查看源码 <ArrowOutIcon />
          </a>
          <button ref={statusTriggerRef} type="button" onClick={() => setStatusOpen(true)}>
            当前状态
          </button>
        </div>
      </footer>

      {statusOpen && (
        <div className="status-scrim" role="presentation" onPointerDown={() => setStatusOpen(false)}>
          <section
            ref={statusPanelRef}
            className="status-panel"
            role="dialog"
            aria-modal="true"
            aria-labelledby="status-title"
            onPointerDown={(event) => event.stopPropagation()}
          >
            <header>
              <h2 id="status-title">当前状态</h2>
              <button ref={statusCloseRef} type="button" onClick={() => setStatusOpen(false)} aria-label="关闭当前状态面板">
                <CloseIcon />
              </button>
            </header>
            <ol>
              <li>自动化证据来自进程内模拟层、测试替身与确定性事件回放。</li>
              <li>真实权限、真实剪贴板、真实播放器与真实硬件手感尚未完整验证。</li>
              <li>目前没有 Developer ID 正式分发、公证或公开发布证据。</li>
            </ol>
            <a href={githubUrl} target="_blank" rel="noreferrer">
              在 GitHub 查看源码 <ArrowOutIcon />
            </a>
          </section>
        </div>
      )}
    </main>
  );
}
