// Helpers shared by scan.js (desktop Chromium) and emulator-test.js (the app's WebView).
const SERVER_TEXT_RE = /(server|player|source|mirror|embed|stream|vid|upcloud|megacloud|vidsrc|\bhd\b|\b[0-9]{1,2}\b)/i;
const host = (u) => { try { return new URL(u).hostname.toLowerCase(); } catch { return null; } };

// Server/player choices: buttons/links/li inside anything named server/player/source,
// or elements with data-* attributes that carry an embed/server id.
async function findServers(page) {
  return page.evaluate((reSrc) => {
    const re = new RegExp(reSrc, 'i');
    const sel = [
      '[class*="server" i] a', '[class*="server" i] button', '[class*="server" i] li', '[id*="server" i] a', '[id*="server" i] button', '[id*="server" i] li',
      '[class*="source" i] button', '[class*="source" i] li', '[class*="player" i] button', '[class*="provider" i] button', '[class*="provider" i] li',
      '[data-server]', '[data-id][data-type]', '[data-embed]', '[data-src*="embed"]', '[data-link]', 'select[class*="server" i] option', 'select[id*="server" i] option',
    ];
    const out = []; const seen = new Set();
    for (const s of sel) {
      document.querySelectorAll(s).forEach((el, index) => {
        if (seen.has(el)) return;
        const r = el.getBoundingClientRect();
        const text = (el.innerText || el.getAttribute('title') || el.dataset.server || '').trim().slice(0, 40);
        if ((r.width < 5 || r.height < 5) && el.tagName !== 'OPTION') return;
        if (!text && !el.dataset.server && !el.dataset.id) return;
        if (el.closest('nav,header,footer')) return;
        if (!re.test(text + ' ' + el.className + ' ' + s)) return;
        seen.add(el); out.push({ selector: s, index, label: text });
      });
    }
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
