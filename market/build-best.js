const fs = require('fs');
const path = require('path');
const DIR = __dirname;
const Y = require('./catalog.js');

function money(v) { return '€' + v.toFixed(2); }
function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }

const iconsSrc = fs.readFileSync(path.join(DIR, 'icons.js'), 'utf8');
const vm = require('vm');
const iconsSandbox = { window: {} };
vm.createContext(iconsSandbox);
vm.runInContext(iconsSrc, iconsSandbox);
const iconsMap = iconsSandbox.window.YSLEM_ICONS;
function logo(b) { return iconsMap[b] || ''; }

// best value per shop = highest saving % vs retail; falls back to cheapest if no retail products
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

const rows = Y.shops.map(shop => {
  const items = Y.products.filter(p => p.shop === shop.id);
  const best = bestOf(items);
  const save = best.retail ? Math.round((1 - best.price / best.retail) * 100) : null;
  return { shop, best, save };
}).sort((a, b) => (b.save || 0) - (a.save || 0));

const rowsHTML = rows.map(({ shop, best, save }, i) => `
      <a class="row" href="javascript:void(0)" title="${esc(shop.name)}">
        <span class="rank">${i + 1}</span>
        <span class="logo" style="--br:${Y.brands[best.brand] || '#888'}">${logo(best.brand)}</span>
        <span class="info">
          <span class="pname">${esc(best.name)}</span>
          <span class="shop"><span class="shop-ic">${shop.icon}</span>${esc(shop.name)}</span>
        </span>
        <span class="price-col">
          <span class="price">${money(best.price)}</span>
          ${save !== null ? `<span class="save">−${save}%</span>` : `<span class="save flat">best price</span>`}
        </span>
      </a>`).join('');

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Yslem Best Picks</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@700&family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;700&display=swap">
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{--bg:#050506;--surface:#0b0b0e;--line:#1c1c22;--text:#ececf2;--sub:#9d9db0;--mute:#5c5c6b;--good:#7fe0a8}
html{background:var(--bg)}
body{background:var(--bg);color:var(--text);font-family:'Inter',-apple-system,sans-serif;-webkit-font-smoothing:antialiased;min-height:100vh;display:flex;justify-content:center;padding:36px 14px 60px}
.wrap{width:100%;max-width:440px}
.top{text-align:center;margin-bottom:22px}
.crest{font-family:'Cinzel',serif;font-size:13px;letter-spacing:4px;color:var(--mute);text-transform:uppercase;margin-bottom:8px}
h1{font-size:22px;font-weight:800;letter-spacing:-.4px}
.top p{color:var(--sub);font-size:12.5px;margin-top:8px;line-height:1.5}
.list{display:flex;flex-direction:column;gap:8px}
.row{display:flex;align-items:center;gap:11px;padding:12px 13px;border:1px solid var(--line);border-radius:14px;background:var(--surface);text-decoration:none;color:inherit;transition:border-color .15s,transform .1s}
.row:hover{border-color:#33333d}
.row:active{transform:scale(.98)}
.rank{font-family:'JetBrains Mono',monospace;font-size:11px;color:var(--mute);width:16px;flex-shrink:0;text-align:center}
.logo{width:34px;height:34px;border-radius:9px;background:rgba(255,255,255,.05);border:1px solid var(--line);display:flex;align-items:center;justify-content:center;flex-shrink:0;position:relative;overflow:hidden}
.logo::after{content:'';position:absolute;inset:0;background:var(--br);opacity:.13}
.logo svg{width:18px;height:18px;position:relative;z-index:1}
.info{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px}
.pname{font-size:13px;font-weight:650;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.shop{font-size:10.5px;color:var(--mute);display:flex;align-items:center;gap:5px}
.shop-ic{font-size:11px}
.price-col{text-align:right;flex-shrink:0}
.price{display:block;font-family:'JetBrains Mono',monospace;font-size:15px;font-weight:700;font-variant-numeric:tabular-nums}
.save{display:inline-block;margin-top:3px;font-family:'JetBrains Mono',monospace;font-size:9px;font-weight:800;color:#0a0a0d;background:var(--good);padding:2px 6px;border-radius:5px}
.save.flat{background:rgba(255,255,255,.1);color:var(--sub)}
.foot{text-align:center;margin-top:22px;font-size:10.5px;color:var(--mute);line-height:1.7}
</style>
</head>
<body>
<div class="wrap">
  <div class="top">
    <div class="crest">Yslem Market</div>
    <h1>Best price per shop</h1>
    <p>The single best deal in each of the ${rows.length} shops, ranked by savings vs retail.</p>
  </div>
  <div class="list">${rowsHTML}
  </div>
  <div class="foot">Prices in EUR · ${Y.products.length} products total across all shops</div>
</div>
</body>
</html>`;

fs.writeFileSync(path.join(DIR, 'dist', 'best-picks.html'), html);
console.log('best-picks.html written', html.length, 'bytes');
