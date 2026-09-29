// Helpers shared by scan.js (desktop Chromium) and emulator-test.js (the app's WebView).
const SERVER_TEXT_RE = /(server|player|source|mirror|embed|stream|vid|upcloud|megacloud|vidsrc|\bhd\b|\b[0-9]{1,2}\b)/i;
const host = (u) => { try { return new URL(u).hostname.toLowerCase(); } catch { return null; } };

// Server/player choices: buttons/links/li inside anything named server/player/source,
// or elements with data-* attributes that carry an embed/server id.
async function findServers(page) {
  return page.evaluate((reSrc) => {
    const re = new RegExp(reSrc, 'i');
    const PROVIDER = /(vid|embed|src|stream|cine|play|server|source|mirror|upcloud|mega|\b\d{1,2}\b)/i;
    const vis = (el) => { const r = el.getBoundingClientRect(); return r.width > 4 && r.height > 4; };
    const label = (el) => (el.innerText || el.getAttribute('title') || el.getAttribute('aria-label') || '').trim().replace(/\s+/g, ' ').slice(0, 40);
    const out = []; const seen = new Set();
    const add = (el) => {
      const l = label(el); if (!l || seen.has(l) || el.closest('nav,header,footer')) return;
      seen.add(l); out.push({ selector: `${el.tagName.toLowerCase()}:text-is(${JSON.stringify(l)})`, index: 0, label: l });
    };
    // 1) Groups of >=3 sibling buttons whose labels look like provider / server names.
    const groups = new Map();
    document.querySelectorAll('button,[role=button],li[data-id],a[data-id]').forEach((el) => {
      if (!vis(el)) return; const p = el.parentElement; if (!groups.has(p)) groups.set(p, []); groups.get(p).push(el);
    });
    for (const els of groups.values()) {
      if (els.length >= 3 && els.filter((e) => PROVIDER.test(label(e))).length >= Math.ceil(els.length / 2)) els.forEach(add);
    }
    // 2) Anything inside a container named server/source/player/provider.
    const sel = ['[class*="server" i]', '[id*="server" i]', '[class*="source" i]', '[class*="provider" i]', '[data-server]', '[data-embed]', '[data-link]'];
    for (const s of sel) document.querySelectorAll(`${s} button, ${s} li, ${s} a, button${s}`).forEach((el) => { if (vis(el) && re.test(label(el) + ' ' + el.className)) add(el); });
    return out.slice(0, 15);
  }, SERVER_TEXT_RE.source).catch(() => []);
}

async function clickPlay(page) {
  const sels = ['[class*="play" i]:not(video)', '[aria-label*="play" i]', 'button:has-text("Watch")', 'a:has-text("Watch now")', '.jw-icon-display', '.vjs-big-play-button', '.plyr__control--overlaid'];
  for (const f of page.frames()) {
    for (const s of sels) {
      const el = f.locator(s).first();
      if (await el.isVisible({ timeout: 300 }).catch(() => false)) { await el.click({ timeout: 2000 }).catch(() => {}); break; }
    }
    await f.evaluate(() => document.querySelectorAll('video').forEach((v) => { v.muted = true; v.play().catch(() => {}); })).catch(() => {});
  }
  // Also click the centre of the largest iframe (player overlays usually need it).
  const box = await page.evaluate(() => { let b = null, a = 0; document.querySelectorAll('iframe').forEach((f) => { const r = f.getBoundingClientRect(); if (r.width * r.height > a) { a = r.width * r.height; b = { x: r.x + r.width / 2, y: r.y + r.height / 2 }; } }); return b; }).catch(() => null);
  if (box) await page.mouse.click(box.x, box.y).catch(() => {});
}

async function isPlaying(page) {
  for (const f of page.frames()) {
    const ok = await f.evaluate(() => [...document.querySelectorAll('video')].some((v) => v.currentTime > 0 && v.readyState >= 2)).catch(() => false);
    if (ok) return host(f.url());
  }
  return false;
}

module.exports = { findServers, clickPlay, isPlaying, host, SERVER_TEXT_RE };
