const fs = require('fs');
const path = require('path');
const DIR = __dirname;
const Y = require('./catalog.js');

// ── logo svg + brand color sources (already authored) ─────────
const iconsSrc = fs.readFileSync(path.join(DIR, 'icons.js'), 'utf8');
function extractMap(varname) {
  const m = iconsSrc.match(new RegExp('window\\.' + varname + '=\\{([\\s\\S]*?)\\n\\};'));
  return m[1];
}
const iconEntries = extractMap('YSLEM_ICONS'); // key:'<svg...>', ... text block

// keys already present in the ORIGINAL script's SVG / BRAND objects
const ORIG_KEYS = ['telegram','tiktok','instagram','twitter','twitch','adobe','duolingo','roblox','steam',
  'discord','openai','claude','gemini','netflix','spotify','disney','hbo','crunchy','youtube','prime',
  'deezer','nord','express','minecraft','fortnite','xbox','capcut','canva'];

const newBrandKeys = [...new Set(Y.products.filter(p => p.id > 35).map(p => p.brand))]
  .filter(b => !ORIG_KEYS.includes(b));

// pull each needed icon's literal text out of icons.js source (key:'<svg ...>')
function iconLiteral(key) {
  const re = new RegExp("(?:^|\\n)" + key + ":'((?:[^'\\\\]|\\\\.)*)'");
  const m = iconEntries.match(re);
  if (!m) throw new Error('missing icon for ' + key);
  return m[1];
}
const svgAddBlock = newBrandKeys.map(k => `${k}:'${iconLiteral(k)}'`).join(',\n');
const brandAddBlock = newBrandKeys.map(k => `${k}:'${Y.brands[k]}'`).join(',');

// ── product entries (id > 35) in ORIGINAL P-array schema ───────
const KIND_T = { FA: 'FA', KEY: 'KEY', GIFT: 'GIFT LINK', LINK: 'LINK', METHOD: 'METHOD', TOOL: 'TOOL', SERVICE: 'SERVICE' };
function durTag(dur) {
  const map = {
    'Lifetime': 'LIFETIME', 'Permanent': 'PERMANENT', '1 month': '1 MONTH', '3 months': '3 MONTHS',
    '6 months': '6 MONTHS', '12 months': '12 MONTHS', '18 months': '18 MONTHS', '3 years': '3 YEARS',
    'Per 1000': 'PER 1K', 'Per 1000 h': 'PER 1K H', 'Per 100 / h': 'PER 100/H', 'One-off': 'ONE-OFF'
  };
  return map[dur] || dur.toUpperCase();
}
function jsStr(s) { return "'" + String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'"; }
function jsArr(arr) { return '[' + arr.map(jsStr).join(',') + ']'; }
function jsSpecs(sp) {
  return '{' + Object.keys(sp).map(k => `${k}:${jsStr(sp[k])}`).join(',') + '}';
}

const newProducts = Y.products.filter(p => p.id > 35);
const productBlocks = newProducts.map(p => {
  const t = jsArr([KIND_T[p.kind], durTag(p.dur)]);
  const w = p.retail ? jsStr(p.retail.toFixed(2)) : "''";
  const f = p.flag ? jsStr(p.flag) : 'null';
  return `{id:${p.id},c:${jsStr(p.shop)},lg:${jsStr(p.brand)},n:${jsStr(p.name)},t:${t},p:${jsStr(p.price.toFixed(2))},w:${w},f:${f},ac:'#ececf2',
 desc:${jsArr(p.desc)},
 warn:${jsArr(p.warn)},
 sp:${jsSpecs(p.sp)}}`;
}).join(',\n\n');

// ── INT configurator entries for new products ──────────────────
const OWNACCT_LABEL = {
  70: 'Apple ID email', 86: 'Roblox account username'
};
function intEntry(p) {
  switch (p.int) {
    case 'nitro': case 'boost': case 'aged': case 'ai': case 'link':
    case 'vpn': case 'fortnite': case 'region': case 'platform':
    case 'method': case 'robux':
      return `${p.id}:{type:${jsStr(p.int)}}`;
    case 'ownacct':
      return `${p.id}:{type:'ownacct',label:${jsStr(OWNACCT_LABEL[p.id] || (p.name + ' account email'))}}`;
    case 'stream':
      return `${p.id}:{type:'stream',plans:[${(p.opts || [['Standard', 0]]).map(o => `[${jsStr(o[0])},${jsStr(o[1].toFixed ? o[1].toFixed(2) : o[1])}]`).join(',')}]}`;
    case 'game':
      return `${p.id}:{type:'game',opts:[${(p.opts || [['Standard', 0]]).map(o => `[${jsStr(o[0])},${jsStr(o[1].toFixed ? o[1].toFixed(2) : o[1])}]`).join(',')}]}`;
    case 'smm':
      const c = p.smm;
      return `${p.id}:{type:'smm',unit:${jsStr(c.unit)},min:${c.min},max:${c.max},step:${c.step},rate:${c.rate},field:${jsStr(c.field)},ph:${jsStr(c.ph)}}`;
    default:
      return null; // 'basic' -> no INT entry needed
  }
}
const intBlocks = newProducts.map(intEntry).filter(Boolean).join(',\n ');

// ── splice into the original script ────────────────────────────
let script = fs.readFileSync(path.join(DIR, 'original', 'script.js'), 'utf8');

// 1) SVG map: insert before the closing "};" of var SVG={...};
script = script.replace(
  /(var SVG=\{[\s\S]*?)\n\};/,
  (m, body) => `${body},\n${svgAddBlock}\n};`
);

// 2) BRAND map: insert before its closing "};"
script = script.replace(
  /(var BRAND=\{[\s\S]*?)\};/,
  (m, body) => `${body},${brandAddBlock}};`
);

// 3) P array: insert new product objects before the closing "\n];"
script = script.replace(
  /(var P=\[[\s\S]*?)\n\];/,
  (m, body) => `${body},\n\n${productBlocks}\n];`
);

// 4) INT config: insert before its closing "\n};"
script = script.replace(
  /(var INT = \{[\s\S]*?)\n\};/,
  (m, body) => `${body},\n ${intBlocks}\n};`
);

// keep the visible product-count stat in sync with the real catalogue
script = script.replace('render();', "document.getElementById('stat-n').textContent=P.length;\nrender();");

fs.writeFileSync(path.join(DIR, 'dist', 'script.extended.js'), script);
console.log('extended script written,', newProducts.length, 'new products,', newBrandKeys.length, 'new brands');

// sanity check syntax
try { new Function(script); console.log('syntax OK'); }
catch (e) { console.log('SYNTAX ERROR:', e.message); }
