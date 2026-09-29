// Step 1: crawl cinex.watch, click every server/player option and play,
// log every request (domain + type) and every popup / redirect chain.
// Usage: node scan.js [baseUrl] [outFile]
const { chromium } = require('playwright');
const fs = require('fs');
const { findServers, clickPlay, isPlaying } = require('./common');

const BASE = process.argv[2] || 'https://cinex.watch';
const OUT = process.argv[3] || 'scan-log.json';
const MAX_VIDEO_PAGES = +process.env.MAX_VIDEO_PAGES || 4;
const MEDIA_RE = /\.(m3u8|mpd|mp4|m4s|m4v|webm|ts)(\?|#|$)/i;
const MEDIA_CT = /(mpegurl|dash\+xml|video\/|audio\/|mp2t)/i;
const VIDEO_LINK_RE = /\/(movie|movies|tv|show|shows|series|watch|episode|film|anime)\b/i;

const log = { base: BASE, startedAt: new Date().toISOString(), pages: [], requests: [], popups: [], redirects: [], errors: [] };
const host = (u) => { try { return new URL(u).hostname.toLowerCase(); } catch { return null; } };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let current = 'init';

function classify(req) {
  const rt = req.resourceType();
  const url = req.url();
  const frame = safe(() => req.frame());
  if (rt === 'document') return frame && frame.parentFrame() ? 'iframe' : 'document';
  if (rt === 'media' || MEDIA_RE.test(url)) return 'media';
  if (rt === 'xhr' || rt === 'fetch') return 'xhr';
  return rt; // script, image, stylesheet, font, websocket, other...
}
function safe(fn) { try { return fn(); } catch { return null; } }

function attach(page, origin) {
  page.on('request', (req) => {
    const url = req.url();
    if (!/^https?:/.test(url)) return;
    const frame = safe(() => req.frame());
    log.requests.push({
      step: current, origin, url: url.slice(0, 400), domain: host(url), type: classify(req),
      frameDomain: frame ? host(frame.url()) : null,
      mainFrame: frame ? !frame.parentFrame() : null,
    });
  });
  page.on('response', async (res) => {
    const ct = res.headers()['content-type'] || '';
    if (MEDIA_CT.test(ct)) log.requests.push({ step: current, origin, url: res.url().slice(0, 400), domain: host(res.url()), type: 'media', contentType: ct });
  });
  page.on('framenavigated', (f) => {
    if (f === page.mainFrame() && origin === 'main') {
      const h = host(f.url());
      if (h && !h.endsWith(host(BASE).replace(/^www\./, ''))) log.redirects.push({ step: current, to: f.url(), domain: h });
    }
  });
}

async function main() {
  const browser = await chromium.launch({ headless: process.env.HEADLESS === '1', args: ['--autoplay-policy=no-user-gesture-required', '--disable-blink-features=AutomationControlled'] });
  const ctx = await browser.newContext({
    viewport: { width: 1366, height: 800 },
  });
  await ctx.addInitScript(() => Object.defineProperty(navigator, 'webdriver', { get: () => undefined }));
  const page = await ctx.newPage();
  attach(page, 'main');

  // Record every popup / new tab and its full redirect chain, then close it.
  // Context-level listeners so the popup's very first navigation is never missed.
  const recs = new Map();
  const recFor = (p) => {
    if (!recs.has(p)) {
      const rec = { step: current, opener: page.url(), chain: [], domains: [] };
      recs.set(p, rec); log.popups.push(rec); attach(p, 'popup');
      setTimeout(() => { push(rec, p.url()); p.close().catch(() => {}); }, 6000);
    }
    return recs.get(p);
  };
  const push = (rec, u) => { if (u && u !== 'about:blank' && rec.chain.at(-1) !== u) { rec.chain.push(u.slice(0, 400)); const h = host(u); if (h && !rec.domains.includes(h)) rec.domains.push(h); } };
  ctx.on('request', (r) => {
    const f = safe(() => r.frame()); const p = f && safe(() => f.page());
    if (!p || p === page || !r.isNavigationRequest() || f !== p.mainFrame()) return;
    const rec = recFor(p); const hops = []; let rr = r; while (rr) { hops.unshift(rr.url()); rr = rr.redirectedFrom(); }
    hops.forEach((u) => push(rec, u));
    log.requests.push({ step: current, origin: 'popup', url: r.url().slice(0, 400), domain: host(r.url()), type: 'document' });
  });
  ctx.on('page', (p) => { if (p !== page) { const rec = recFor(p); push(rec, p.url()); p.on('framenavigated', (f) => { if (f === p.mainFrame()) push(rec, f.url()); }); } });

  // Homepage
  current = 'home';
  await page.goto(BASE, { waitUntil: 'domcontentloaded', timeout: 60000 }).catch((e) => log.errors.push('home: ' + e.message));
  await waitContent(page);
  console.log('DIAG home', JSON.stringify(await diag(page)).slice(0, 3000));
  await page.mouse.wheel(0, 3000); await sleep(2000);
  const links = await page.$$eval('a[href]', (as) => as.map((a) => a.href)).catch(() => []);
  const home = host(BASE).replace(/^www\./, '');
  const videoLinks = [...new Set(links.filter((u) => host(u) && host(u).endsWith(home) && /^\/(movie|tv|watch|series|episode|anime)\/[\w-]+\/?$/i.test(new URL(u).pathname)).map((u) => { const x = new URL(u); return x.origin + x.pathname; }))];
  // Prefer a mix of movie and tv pages
  const pick = [];
  for (const re of [/movie|film/i, /tv|show|series|episode/i, /./]) for (const u of videoLinks) if (pick.length < MAX_VIDEO_PAGES && re.test(u) && !pick.includes(u) && pick.filter((x) => re.test(x)).length < Math.ceil(MAX_VIDEO_PAGES / 2)) pick.push(u);
  log.pages.push({ url: page.url(), title: await page.title().catch(() => ''), linksFound: links.length, videoLinks: videoLinks.length, picked: pick });
  console.log(`home: ${links.length} links, ${videoLinks.length} video links; scanning`, pick);
  if (!pick.length) { fs.writeFileSync('home.html', await page.content().catch(() => '')); await page.screenshot({ path: 'home.png' }).catch(() => {}); }

  for (const [i, url] of pick.entries()) {
    current = `video${i}`;
    const info = { url, servers: [] };
    log.pages.push(info);
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await waitContent(page);
      // Some sites need a "Watch now"/play click before servers render.
      await clickPlay(page);
      await sleep(3000);
      await page.screenshot({ path: `video${i}.png` }).catch(() => {});
      if (i < 2 || process.env.DIAG) console.log('DIAG', url, JSON.stringify(await diag(page)));
      const servers = await findServers(page);
      info.serverCount = servers.length;
      console.log(`${url}: ${servers.length} server options`);
      for (const [j, s] of servers.entries()) {
        current = `video${i}-server${j}`;
        const rec = { label: s.label };
        info.servers.push(rec);
        try {
          if (page.url() !== url && host(page.url()) !== host(url)) { await page.goto(url, { waitUntil: 'domcontentloaded' }); await sleep(4000); }
          const el = page.locator(s.selector).nth(s.index);
          await el.scrollIntoViewIfNeeded({ timeout: 3000 }).catch(() => {});
          await el.click({ timeout: 5000 });
          await sleep(5000);
          await clickPlay(page);
          await sleep(12000);
          rec.iframes = page.frames().filter((f) => f.parentFrame()).map((f) => host(f.url())).filter(Boolean);
          rec.playing = await isPlaying(page);
          rec.mainUrl = page.url();
          await page.screenshot({ path: `video${i}-server${j}.png` }).catch(() => {});
        } catch (e) { rec.error = e.message.split('\n')[0]; }
        console.log('  ', JSON.stringify(rec));
      }
    } catch (e) { log.errors.push(`${url}: ${e.message.split('\n')[0]}`); }
  }
  log.finishedAt = new Date().toISOString();
  fs.writeFileSync(OUT, JSON.stringify(log, null, 1));
  console.log(`requests=${log.requests.length} popups=${log.popups.length} redirects=${log.redirects.length}`);
  await browser.close();
}

// Wait (up to 30s) until the page has real content: gets past Cloudflare checks and SPA hydration.
async function waitContent(page) {
  for (let t = 0; t < 15; t++) {
    await sleep(2000);
    const n = await page.evaluate(() => document.querySelectorAll('a[href],button').length).catch(() => 0);
    const title = await page.title().catch(() => '');
    if (n > 5 && !/just a moment|attention required|checking/i.test(title)) { await sleep(2000); return true; }
  }
  return false;
}

// Dump what is clickable on a page so selectors can be tuned from the CI log.
async function diag(page) {
  return page.evaluate(() => {
    const vis = (el) => { const r = el.getBoundingClientRect(); return r.width > 2 && r.height > 2; };
    const d = (el) => `${el.tagName.toLowerCase()}.${(el.className && el.className.baseVal === undefined ? el.className : '').toString().slice(0, 60)}|${(el.innerText || el.getAttribute('aria-label') || '').trim().replace(/\s+/g, ' ').slice(0, 40)}|${el.getAttribute('href') || ''}`;
    return {
      url: location.href,
      buttons: [...document.querySelectorAll('button,[role=button],[onclick],select,option,li[data-id],[data-server],[data-id]')].filter(vis).slice(0, 60).map(d),
      links: [...new Set([...document.querySelectorAll('a[href]')].map((a) => a.getAttribute('href')))].filter((h) => !/^(https?:)?\/\/(?!cinex)/.test(h)).slice(0, 60),
      iframes: [...document.querySelectorAll('iframe')].map((f) => f.src.slice(0, 150)),
      videos: document.querySelectorAll('video').length,
      title: document.title, text: document.body ? document.body.innerText.replace(/\s+/g, ' ').slice(0, 600) : '',
    };
  }).catch((e) => ({ error: e.message }));
}

main().catch((e) => { console.error(e); log.errors.push(String(e)); fs.writeFileSync(OUT, JSON.stringify(log, null, 1)); process.exit(1); });
