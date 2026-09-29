// Step 2: turn scan-log.json into allow/block lists.
// allow = own domain + every domain serving an iframe player or a video stream.
// block = domains seen only in popups, off-site redirects or ad scripts.
const fs = require('fs');
const log = JSON.parse(fs.readFileSync(process.argv[2] || 'scan-log.json', 'utf8'));
const OUT = process.argv[3] || 'domains.json';
const prev = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, 'utf8')) : {};

// Collapse to registrable domain (good enough; handles common 2-level TLDs).
const TWO = /\.(co|com|net|org|gov|edu|ac)\.[a-z]{2}$/;
const root = (h) => { if (!h) return null; if (/^[0-9.]+$/.test(h)) return h; const p = h.split('.'); return p.slice(TWO.test(h) ? -3 : -2).join('.'); };
const AD_RE = /(^|[.-])(ads?|adserv\w*|adsystem|advert\w*|pop\w*|clk|click\w*|track\w*|analytics|doubleclick|googlesyndication|taboola|outbrain|mgid|propeller\w*|exoclick|juicyads|hilltop\w*|monetag|adsterra|onclick\w*|push\w*|notif\w*|syndication|banner\w*|redirect\w*|smartlink)([.-]|$)/i;

// Ad networks that rotate throw-away domains (Adsterra, Monetag, PropellerAds, ...).
const AD_NET = /(revenue|cpm|profit|monet|adcash|popcash|clickadu|galaksion|hilltop|aclib|a-ads|adskeeper|realsrv|bidgear|pemsrv|tsyndicate|intellipopup|popunder|onclicka)/i;
const RANDOM_DOMAIN = /^(?=[a-z0-9-]*\d)[a-z0-9-]{10,}\.(cfd|sbs|xyz|top|click|shop|online|site|store|lol|quest|icu|buzz|rest|bond|autos|beauty|hair|skin|mom|boats)$/i;
const isAd = (d) => AD_RE.test(d) || AD_NET.test(d) || RANDOM_DOMAIN.test(d);
const own = root(new URL(log.base).hostname);
const allow = new Set([own]);
const why = {};
const note = (d, r) => { (why[d] ||= new Set()).add(r); };

const mainD = new Set(); // every domain the site itself (not a popup) loaded
const iframeD = new Set(), mediaD = new Set(), scriptD = new Set(), popupD = new Set(), redirD = new Set(), otherD = new Set();
for (const r of log.requests) {
  const d = root(r.domain); if (!d) continue;
  if (r.origin === 'popup') { popupD.add(d); continue; }
  mainD.add(d);
  if (r.type === 'iframe') iframeD.add(d);
  else if (r.type === 'media') mediaD.add(d);
  else if (r.type === 'script') scriptD.add(d);
  else otherD.add(d);
}
for (const p of log.popups) for (const h of p.domains) popupD.add(root(h));
for (const r of log.redirects) redirD.add(root(r.domain));

// Iframes that carry an ad (their domain also opened popups and never served media or
// showed up as a player on a server click) are not players.
const playerIframes = new Set(log.pages.flatMap((p) => (p.servers || []).flatMap((s) => (s.iframes || []).map(root))));
for (const d of iframeD) {
  const adLike = isAd(d) || (popupD.has(d) && !mediaD.has(d) && !playerIframes.has(d));
  if (!adLike) { allow.add(d); note(d, 'iframe player'); }
}
for (const d of mediaD) { allow.add(d); note(d, 'video stream'); }
for (const d of prev.allow || []) if (!allow.has(d)) { allow.add(d); note(d, 'kept from previous config'); }
for (const d of prev.manualAllow || []) { allow.add(d); note(d, 'manual/retest'); }

const block = new Set();
// Popup / redirect domains are blocked only if the site's own pages never needed them
// (so shared CDNs a popup happened to load, like gstatic or jsdelivr, stay usable).
for (const d of [...popupD, ...redirD]) if (!allow.has(d) && (!mainD.has(d) || redirD.has(d))) { block.add(d); note(d, redirD.has(d) ? 'redirect' : 'popup'); }
for (const d of scriptD) if (!allow.has(d) && isAd(d)) { block.add(d); note(d, 'ad script'); }
for (const d of otherD) if (!allow.has(d) && isAd(d)) { block.add(d); note(d, 'ad/tracker'); }
for (const d of prev.block || []) if (!allow.has(d) && !mainD.has(d)) block.add(d);

const neutral = [...new Set([...scriptD, ...otherD])].filter((d) => !allow.has(d) && !block.has(d)).sort();
const cfg = {
  generatedAt: new Date().toISOString(),
  source: log.base,
  ownDomain: own,
  allow: [...allow].sort(),
  block: [...block].sort(),
  manualAllow: prev.manualAllow || [],
  neutral, // third-party resources that are neither players nor ads: loaded, never navigated to
  reasons: Object.fromEntries(Object.entries(why).map(([k, v]) => [k, [...v].join(', ')])),
};
fs.writeFileSync(OUT, JSON.stringify(cfg, null, 2) + '\n');

console.log(`\n=== ALLOWLIST (${cfg.allow.length}) ===`);
for (const d of cfg.allow) console.log(`  + ${d.padEnd(32)} ${cfg.reasons[d] || 'own domain'}`);
console.log(`\n=== BLOCKLIST (${cfg.block.length}) ===`);
for (const d of cfg.block) console.log(`  - ${d.padEnd(32)} ${cfg.reasons[d] || 'previous config'}`);
console.log(`\n=== NEUTRAL (${neutral.length}) === ${neutral.join(', ')}`);
console.log(`\npopups recorded: ${log.popups.length}`);
for (const p of log.popups) console.log(`  [${p.step}] ${p.chain.join(' -> ')}`);
console.log(`off-site main-frame redirects: ${log.redirects.length}`);
for (const r of log.redirects) console.log(`  [${r.step}] ${r.to}`);
console.log('\nper-server results:');
for (const p of log.pages) for (const s of p.servers || []) console.log(`  ${p.url} | ${s.label} | iframes=${(s.iframes || []).join(',')} playing=${s.playing} ${s.error || ''}`);
