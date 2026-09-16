(() => {
  const english = document.documentElement.lang === 'en';
  let saved;
  try { saved = localStorage.getItem('dorazoom-language'); } catch {}
  const requested = new URL(location.href).searchParams.get('lang');
  if (requested === 'zh' || requested === 'en') {
    saved = requested;
    try { localStorage.setItem('dorazoom-language', requested); } catch {}
  }
  // Explicit English URLs remain shareable. Only the default Chinese entry negotiates.
  const preference = saved || ((navigator.languages || [navigator.language]).find(Boolean)?.toLowerCase().startsWith('zh') ? 'zh' : 'en');
  if (!english && preference === 'en') {
    const current = new URL(location.href);
    const match = current.pathname.match(/\/(privacy|terms|support)(?:\/index\.html|\/)?$/);
    const base = match ? new URL('../', current.href.endsWith('/') || current.pathname.endsWith('.html') ? current : `${current.href}/`) : new URL('./', current);
    // Resolve relative to the site root for both hosted pages and local file previews.
    if (match && current.pathname.endsWith('.html')) base.pathname = base.pathname.replace(/(?:privacy|terms|support)\/$/, '');
    const target = new URL(`en/${match ? `${match[1]}/` : ''}index.html`, base);
    target.hash = current.hash;
    location.replace(target.href);
  }
})();
