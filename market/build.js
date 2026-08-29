const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const catalog = fs.readFileSync(path.join(DIR, 'catalog.js'), 'utf8');
const icons = fs.readFileSync(path.join(DIR, 'icons.js'), 'utf8');

/* ── 1. STOREFRONT ─────────────────────────────────────────── */
let tpl = fs.readFileSync(path.join(DIR, 'storefront.template.html'), 'utf8');
tpl = tpl.replace('/*{{CATALOG}}*/', catalog).replace('/*{{ICONS}}*/', icons);
fs.writeFileSync(path.join(DIR, 'dist', 'storefront.html'), tpl);
console.log('storefront.html written', tpl.length, 'bytes');

/* ── 2. PRICE INDEX (best price / where to go) ───────────────── */
const Y = require('./catalog.js');

function money(v) { return '€' + v.toFixed(2); }
function perMonth(p) {
  if (!p.months) return null;
  return p.price / p.months;
}
function esc(s) {
  return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

// group by shop, sort by price
const byShop = {};
Y.shops.forEach(s => byShop[s.id] = []);
Y.products.forEach(p => byShop[p.shop].push(p));
Y.shops.forEach(s => byShop[s.id].sort((a, b) => a.price - b.price));

// "best deal" per shop = lowest price product with a retail comparison (savings %), fallback lowest price
function bestOf(list) {
  const withRetail = list.filter(p => p.retail > 0);
  if (withRetail.length) {
    return withRetail.reduce((best, p) => {
      const save = 1 - p.price / p.retail;
      const bestSave = 1 - best.price / best.retail;
      return save > bestSave ? p : best;
    });
  }
  return list.reduce((best, p) => p.price < best.price ? p : best, list[0]);
}

const shopRows = Y.shops.map(s => {
  const items = byShop[s.id];
  const best = bestOf(items);
  const cheapest = items[0];
  const avg = items.reduce((a, p) => a + p.price, 0) / items.length;
  return { shop: s, items, best, cheapest, avg };
});

const vm = require('vm');
const iconsSandbox = { window: {} };
vm.createContext(iconsSandbox);
vm.runInContext(icons, iconsSandbox);
const iconsMap = iconsSandbox.window.YSLEM_ICONS;

function logo(b) { return iconsMap[b] || ''; }

const shopCardHTML = shopRows.map(({ shop, items, best, cheapest, avg }) => {
  const rows = items.map(p => {
    const pm = perMonth(p);
    return `<tr>
      <td class="pc-name"><span class="pc-logo" style="--br:${Y.brands[p.brand] || '#888'}">${logo(p.brand)}</span><span>${esc(p.name)}<span class="pc-dur">${esc(p.dur)}</span></span></td>
      <td class="pc-kind">${p.kind}</td>
      <td class="pc-price">${money(p.price)}</td>
      <td class="pc-pm">${pm ? money(pm) + '/mo' : '—'}</td>
      <td class="pc-retail">${p.retail ? `<s>${money(p.retail)}</s>` : '—'}</td>
    </tr>`;
  }).join('');
  return `<section class="shop-card" id="shop-${shop.id}">
    <header class="shop-head">
      <div class="shop-icon">${shop.id.slice(0, 2).toUpperCase()}</div>
      <div class="shop-meta">
        <h2>${shop.name}</h2>
        <p>${shop.blurb}</p>
      </div>
      <div class="shop-stat">
        <div class="shop-stat-n">${items.length}</div>
        <div class="shop-stat-l">products</div>
      </div>
    </header>
    <div class="best-strip">
      <div class="best-tag">Best value here</div>
      <div class="best-row">
        <span class="pc-logo lg" style="--br:${Y.brands[best.brand] || '#888'}">${logo(best.brand)}</span>
        <div class="best-info">
          <div class="best-name">${esc(best.name)}</div>
          <div class="best-sub">${best.kind} · ${esc(best.dur)}${best.retail ? ` · saves ${Math.round((1 - best.price / best.retail) * 100)}% vs retail` : ''}</div>
        </div>
        <div class="best-price">${money(best.price)}</div>
      </div>
    </div>
    <div class="table-wrap">
      <table class="pc-table">
        <thead><tr><th>Product</th><th>Type</th><th>Price</th><th>Per month</th><th>Retail</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  </section>`;
}).join('\n');

// global "best in market" cross-shop leaderboard: pick the top saving-% deal per shop
const leaderboard = shopRows
  .map(({ shop, best }) => ({ shop, best }))
  .sort((a, b) => {
    const sa = a.best.retail ? 1 - a.best.price / a.best.retail : 0;
    const sb = b.best.retail ? 1 - b.best.price / b.best.retail : 0;
    return sb - sa;
  });

const leaderHTML = leaderboard.map(({ shop, best }, i) => {
  const save = best.retail ? Math.round((1 - best.price / best.retail) * 100) : null;
  return `<a class="lead-row" href="#shop-${shop.id}">
    <span class="lead-rank">${String(i + 1).padStart(2, '0')}</span>
    <span class="pc-logo" style="--br:${Y.brands[best.brand] || '#888'}">${logo(best.brand)}</span>
    <span class="lead-info">
      <span class="lead-name">${esc(best.name)}</span>
      <span class="lead-shop">${shop.name}</span>
    </span>
    <span class="lead-price">
      <span class="lead-p">${money(best.price)}</span>
      ${save !== null ? `<span class="lead-save">−${save}%</span>` : ''}
    </span>
  </a>`;
}).join('\n');

const navHTML = Y.shops.map(s => `<a href="#shop-${s.id}" class="nav-chip">${s.name.replace(' Shop', '')}</a>`).join('');

const totalProducts = Y.products.length;
const totalShops = Y.shops.length;

const indexHTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Yslem Price Index</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;700&display=swap">
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{
  --bg:#050506; --surface:#0b0b0e; --surface2:#111114; --line:#1c1c22;
  --text:#ececf2; --sub:#9d9db0; --mute:#5c5c6b; --accent:#ececf2;
  --good:#7fe0a8; --save:#0a0a0d;
}
html{background:var(--bg)}
body{background:var(--bg);color:var(--text);font-family:'Inter',-apple-system,sans-serif;-webkit-font-smoothing:antialiased;min-height:100vh}
a{color:inherit;text-decoration:none}
.wrap{max-width:960px;margin:0 auto;padding:0 20px}
.top{padding:48px 0 28px;text-align:center;border-bottom:1px solid var(--line)}
.eyebrow{font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:4px;color:var(--mute);text-transform:uppercase;margin-bottom:14px}
h1{font-family:'Cinzel',serif;font-size:clamp(28px,6vw,44px);letter-spacing:3px;font-weight:700;text-wrap:balance}
.top p{color:var(--sub);font-size:14px;margin-top:14px;max-width:480px;margin-left:auto;margin-right:auto;line-height:1.6}
.stats-row{display:flex;justify-content:center;gap:10px;margin-top:24px;flex-wrap:wrap}
.stat-chip{padding:10px 18px;border:1px solid var(--line);border-radius:12px;background:var(--surface);text-align:center;min-width:96px}
.stat-chip b{display:block;font-family:'JetBrains Mono',monospace;font-size:18px;font-variant-numeric:tabular-nums}
.stat-chip span{font-size:9px;color:var(--mute);text-transform:uppercase;letter-spacing:1px}

.nav-strip{position:sticky;top:0;z-index:10;background:rgba(5,5,6,.92);backdrop-filter:blur(6px);border-bottom:1px solid var(--line);overflow-x:auto;white-space:nowrap;padding:12px 20px}
.nav-strip::-webkit-scrollbar{display:none}
.nav-chip{display:inline-block;padding:7px 13px;margin-right:7px;border:1px solid var(--line);border-radius:100px;font-size:12px;color:var(--sub);background:var(--surface)}
.nav-chip:hover{color:var(--text);border-color:#2b2b34}

.section-title{display:flex;align-items:baseline;gap:10px;padding:40px 0 16px}
.section-title h2{font-size:13px;text-transform:uppercase;letter-spacing:2px;color:var(--mute);font-family:'JetBrains Mono',monospace;white-space:nowrap}
.section-title .rule{flex:1;height:1px;background:linear-gradient(90deg,var(--line),transparent)}

.leaderboard{display:flex;flex-direction:column;gap:8px;margin-bottom:8px}
.lead-row{display:flex;align-items:center;gap:12px;padding:12px 14px;border:1px solid var(--line);border-radius:13px;background:var(--surface);transition:border-color .15s}
.lead-row:hover{border-color:#33333d}
.lead-rank{font-family:'JetBrains Mono',monospace;font-size:11px;color:var(--mute);width:20px;flex-shrink:0}
.pc-logo{width:30px;height:30px;border-radius:8px;background:rgba(255,255,255,.05);border:1px solid var(--line);display:flex;align-items:center;justify-content:center;flex-shrink:0;position:relative;overflow:hidden}
.pc-logo::after{content:'';position:absolute;inset:0;background:var(--br);opacity:.12}
.pc-logo svg{width:16px;height:16px;position:relative;z-index:1}
.pc-logo.lg{width:38px;height:38px;border-radius:10px}
.pc-logo.lg svg{width:20px;height:20px}
.lead-info{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}
.lead-name{font-size:13px;font-weight:600}
.lead-shop{font-size:10.5px;color:var(--mute)}
.lead-price{text-align:right;flex-shrink:0}
.lead-p{display:block;font-family:'JetBrains Mono',monospace;font-size:14px;font-weight:700;font-variant-numeric:tabular-nums}
.lead-save{display:inline-block;margin-top:2px;font-family:'JetBrains Mono',monospace;font-size:9.5px;font-weight:700;color:var(--save);background:var(--good);padding:1px 5px;border-radius:4px}

.shop-card{border:1px solid var(--line);border-radius:18px;background:var(--surface);margin-bottom:18px;overflow:hidden;scroll-margin-top:64px}
.shop-head{display:flex;align-items:center;gap:14px;padding:20px}
.shop-icon{width:44px;height:44px;border-radius:12px;background:var(--surface2);border:1px solid var(--line);display:flex;align-items:center;justify-content:center;font-family:'JetBrains Mono',monospace;font-size:12px;font-weight:700;letter-spacing:.5px;color:var(--sub);flex-shrink:0}
.shop-meta h2{font-size:16px;font-weight:700;letter-spacing:-.2px}
.shop-meta p{font-size:11.5px;color:var(--mute);margin-top:2px}
.shop-stat{margin-left:auto;text-align:right}
.shop-stat-n{font-family:'JetBrains Mono',monospace;font-size:20px;font-weight:700;font-variant-numeric:tabular-nums}
.shop-stat-l{font-size:9px;color:var(--mute);text-transform:uppercase;letter-spacing:1px}

.best-strip{margin:0 20px 16px;padding:14px;border:1px solid #2a2a34;border-radius:13px;background:linear-gradient(180deg,rgba(255,255,255,.035),rgba(255,255,255,.01))}
.best-tag{font-family:'JetBrains Mono',monospace;font-size:9px;letter-spacing:1.6px;color:var(--good);text-transform:uppercase;margin-bottom:10px}
.best-row{display:flex;align-items:center;gap:12px}
.best-info{flex:1;min-width:0}
.best-name{font-size:13.5px;font-weight:700}
.best-sub{font-size:10.5px;color:var(--sub);margin-top:2px}
.best-price{font-family:'JetBrains Mono',monospace;font-size:19px;font-weight:700;font-variant-numeric:tabular-nums;flex-shrink:0}

.table-wrap{overflow-x:auto;padding:0 20px 20px}
.pc-table{width:100%;border-collapse:collapse;font-size:12.5px;min-width:480px}
.pc-table thead th{text-align:left;font-family:'JetBrains Mono',monospace;font-size:9.5px;letter-spacing:1px;text-transform:uppercase;color:var(--mute);padding:8px 10px;border-bottom:1px solid var(--line);white-space:nowrap}
.pc-table tbody td{padding:9px 10px;border-bottom:1px solid #131318}
.pc-table tbody tr:last-child td{border-bottom:none}
.pc-table tbody tr:hover{background:rgba(255,255,255,.02)}
.pc-name{display:flex;align-items:center;gap:9px;font-weight:600;white-space:nowrap}
.pc-dur{display:block;font-size:9.5px;color:var(--mute);font-weight:500;font-family:'JetBrains Mono',monospace}
.pc-kind{color:var(--sub);font-family:'JetBrains Mono',monospace;font-size:10.5px;white-space:nowrap}
.pc-price{font-family:'JetBrains Mono',monospace;font-weight:700;font-variant-numeric:tabular-nums;white-space:nowrap}
.pc-pm{font-family:'JetBrains Mono',monospace;color:var(--sub);font-variant-numeric:tabular-nums;white-space:nowrap}
.pc-retail{font-family:'JetBrains Mono',monospace;color:var(--mute);font-variant-numeric:tabular-nums;white-space:nowrap}

.foot{text-align:center;padding:36px 20px 60px;color:var(--mute);font-size:11px;line-height:1.8;border-top:1px solid var(--line);margin-top:20px}
.foot a{color:var(--sub);text-decoration:underline}
</style>
</head>
<body>
<div class="top">
  <div class="eyebrow">Yslem Market</div>
  <h1>PRICE INDEX</h1>
  <p>Every shop, every product, sorted cheapest first — with the single best deal in each shop pinned at the top.</p>
  <div class="stats-row">
    <div class="stat-chip"><b>${totalShops}</b><span>Shops</span></div>
    <div class="stat-chip"><b>${totalProducts}</b><span>Products</span></div>
    <div class="stat-chip"><b>${money(Math.min(...Y.products.map(p => p.price)))}</b><span>Lowest price</span></div>
  </div>
</div>
<nav class="nav-strip">${navHTML}</nav>
<div class="wrap">

  <div class="section-title"><h2>Best deal per shop</h2><div class="rule"></div></div>
  <div class="leaderboard">${leaderHTML}</div>

  <div class="section-title"><h2>Full catalogue by shop</h2><div class="rule"></div></div>
  ${shopCardHTML}

  <div class="foot">
    Prices in EUR, pulled from the live storefront catalogue. "Per month" only applies to timed subscriptions.<br>
    To order, open the <a href="javascript:history.back()">storefront</a> and use the ticket system on any product.
  </div>
</div>
</body>
</html>`;

fs.writeFileSync(path.join(DIR, 'dist', 'price-index.html'), indexHTML);
console.log('price-index.html written', indexHTML.length, 'bytes');
