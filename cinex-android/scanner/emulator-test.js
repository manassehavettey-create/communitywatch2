// Step 4: drive the installed app's WebView on an emulator (Playwright _android),
// play a video on every server/player type found by the scan, and check:
//   - a <video> is actually advancing (currentTime > 0)
//   - no popup got through (the WebView has exactly one page; logcat BLOCKED_POPUP counted)
//   - no bounce-back (main frame still on an allowlisted domain)
// If a server fails and the app blocked one of its requests, that domain is added to
// manualAllow, pushed as an override config, the app restarted and the server retested.
const { _android } = require('playwright');
const { execSync } = require('child_process');
const fs = require('fs');
const { findServers, clickPlay, isPlaying, host } = require('./common');

const PKG = 'watch.cinex.app';
const CFG = process.argv[2] || 'domains.json';
const SCAN = process.argv[3] || 'scan-log.json';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const adb = (c) => execSync(`adb ${c}`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
const AD_RE = /(^|[.-])(ads?|adserv\w*|pop\w*|click\w*|track\w*|doubleclick|syndication|propeller\w*|exoclick|monetag|adsterra|push\w*|redirect\w*)([.-]|$)/i;

const cfg = JSON.parse(fs.readFileSync(CFG, 'utf8'));
const scan = fs.existsSync(SCAN) ? JSON.parse(fs.readFileSync(SCAN, 'utf8')) : { pages: [] };
const allowed = (h) => h && [...cfg.allow, ...(cfg.manualAllow || [])].some((d) => h === d || h.endsWith('.' + d));
const guardLog = () => adb('logcat -d -s CinexGuard:I').split('\n').filter((l) => l.includes('CinexGuard'));

async function launch(device) {
  adb(`shell am force-stop ${PKG}`);
  await sleep(2000);
  const next = device.waitForEvent('webview', { timeout: 90000 });
  adb(`shell am start -n ${PKG}/.MainActivity`);
  const wv = await next; // fresh WebView of the new process (never the stale one)
  const page = await wv.page();
  await page.waitForLoadState('domcontentloaded').catch(() => {});
  return page;
}

async function main() {
  const [device] = await _android.devices();
  console.log('device', device.model(), device.serial());
  let page = await launch(device);
  await sleep(8000);
  console.log('home loaded:', page.url());

  let urls = scan.pages.filter((p) => p.servers).map((p) => p.url);
  if (!urls.length) {
    urls = (await page.$$eval('a[href]', (as) => as.map((a) => a.href))).filter((u) => /\/(movie|tv|watch|series|episode)\b/i.test(u));
    urls = [...new Set(urls)].slice(0, 4);
  }
  urls = urls.slice(0, +process.env.MAX_PAGES || 4);

  const results = [];
  const seenPlayers = new Set();
  for (const url of urls) {
    if (page.isClosed()) { page = await launch(device); await sleep(4000); }
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
    await sleep(5000);
    await clickPlay(page); await sleep(2000);
    const servers = await findServers(page);
    console.log(`\n${url}: ${servers.length} servers`);
    for (const [j, s] of servers.entries()) {
      if (page.isClosed()) { page = await launch(device); await sleep(4000); }
      let r = await tryServer(page, url, s, j);
      if (!r.playing && r.candidates.length) {
        console.log(`   -> not playing; app blocked ${r.candidates.join(', ')}; adding to allowlist and retesting`);
        cfg.manualAllow = [...new Set([...(cfg.manualAllow || []), ...r.candidates])];
        fs.writeFileSync('override.json', JSON.stringify(cfg));
        adb(`shell mkdir -p /sdcard/Android/data/${PKG}/files`);
        adb(`push override.json /sdcard/Android/data/${PKG}/files/domains.json`);
        page = await launch(device); await sleep(4000);
        await page.goto(url, { waitUntil: 'domcontentloaded' }).catch(() => {}); await sleep(5000);
        r = await tryServer(page, url, s, j); r.retested = true;
      }
      results.push(r);
      if (r.playing) seenPlayers.add(r.playing);
      console.log('  ', JSON.stringify(r));
    }
  }

  const pass = results.filter((r) => r.playing && !r.bounced && r.pagesOpen === 1);
  console.log(`\n=== EMULATOR RESULT: ${pass.length}/${results.length} server options played with no popup/bounce ===`);
  console.log('player domains that played:', [...seenPlayers].join(', ') || 'none');
  console.log('popups blocked natively:', results.reduce((a, r) => a + r.popupsBlocked, 0), ' navigations cancelled:', results.reduce((a, r) => a + r.navBlocked, 0));
  console.log('manualAllow added during test:', (cfg.manualAllow || []).join(', ') || 'none');
  fs.writeFileSync('domains.json', JSON.stringify(cfg, null, 2) + '\n');
  fs.writeFileSync('emulator-results.json', JSON.stringify(results, null, 1));
  await device.screenshot({ path: 'emulator-final.png' }).catch(() => {});
  await device.close();
  if (!pass.length) process.exit(2);
}

async function tryServer(page, url, s, j) {
  adb('logcat -c');
  const r = { url, server: s.label, playing: false };
  try {
    if (host(page.url()) !== host(url)) { await page.goto(url, { waitUntil: 'domcontentloaded' }); await sleep(4000); }
    const el = page.locator(s.selector).nth(s.index);
    await el.scrollIntoViewIfNeeded({ timeout: 3000 }).catch(() => {});
    await el.click({ timeout: 5000 });
    await sleep(5000);
    await clickPlay(page);
    for (let t = 0; t < 6 && !r.playing; t++) { await sleep(4000); r.playing = await isPlaying(page); if (!r.playing && t === 2) await clickPlay(page); }
  } catch (e) { r.error = e.message.split('\n')[0]; }
  const logs = guardLog();
  r.mainUrl = page.url();
  r.bounced = !allowed(host(page.url()));
  r.pagesOpen = page.context().pages().length;
  r.popupsBlocked = logs.filter((l) => l.includes('BLOCKED_POPUP')).length;
  r.navBlocked = logs.filter((l) => l.includes('BLOCKED_NAV')).length;
  r.media = [...new Set(logs.filter((l) => l.includes(' MEDIA ')).map((l) => l.split(' MEDIA ')[1].trim()))];
  const frames = page.frames().map((f) => host(f.url())).filter(Boolean);
  r.candidates = [...new Set(logs.filter((l) => l.includes('BLOCKED_REQ')).map((l) => l.split('BLOCKED_REQ ')[1].trim()))]
    .filter((h) => !AD_RE.test(h) && (frames.includes(h) || !r.playing));
  if (r.candidates.length > 3) r.candidates = r.candidates.filter((h) => frames.includes(h));
  await page.screenshot({ path: `emu-${j}.png` }).catch(() => {});
  return r;
}

main().catch((e) => { console.error(e); process.exit(1); });
