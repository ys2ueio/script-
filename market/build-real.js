const fs = require('fs');
const path = require('path');
const DIR = __dirname;
const Y = require('./catalog.js');

const iconsSrc = fs.readFileSync(path.join(DIR, 'icons.js'), 'utf8');
function extractMap(varname) {
  const m = iconsSrc.match(new RegExp('window\\.' + varname + '\\s*=\\s*\\{([\\s\\S]*?)\\n\\};'));
  return m[1];
}
const iconEntries = extractMap('YSLEM_ICONS');
function iconLiteral(key) {
  // handles both entries inside the object literal and the later
  // window.YSLEM_ICONS.key='...'; append-style assignments
  let re = new RegExp("(?:^|\\n)" + key + ":'((?:[^'\\\\]|\\\\.)*)'");
  let m = iconEntries.match(re);
  if (m) return m[1];
  re = new RegExp("window\\.YSLEM_ICONS\\." + key + "\\s*=\\s*'((?:[^'\\\\]|\\\\.)*)'");
  m = iconsSrc.match(re);
  if (m) return m[1];
  throw new Error('missing icon for ' + key);
}

// brand keys already hardcoded in the base script (original/script.js)
const BASE_KEYS = ['telegram', 'tiktok', 'instagram', 'twitter', 'twitch', 'adobe', 'duolingo', 'roblox', 'steam',
  'discord', 'openai', 'claude', 'gemini', 'netflix', 'spotify', 'disney', 'hbo', 'crunchy', 'youtube', 'prime',
  'deezer', 'nord', 'express', 'minecraft', 'fortnite', 'xbox', 'capcut', 'canva'];

const usedBrandKeys = [...new Set(Y.products.map(p => p.brand))];
const newBrandKeys = usedBrandKeys.filter(k => !BASE_KEYS.includes(k));

const svgAddBlock = newBrandKeys.map(k => `${k}:'${iconLiteral(k)}'`).join(',\n');
const brandAddBlock = newBrandKeys.map(k => `${k}:'${Y.brands[k]}'`).join(',');

// ── product entries in the ORIGINAL P-array schema, plus a real `stk` field ──
const KIND_T = { FA: 'FA', KEY: 'KEY', GIFT: 'GIFT LINK', LINK: 'LINK', METHOD: 'METHOD', TOOL: 'TOOL', SERVICE: 'SERVICE' };
function durTag(dur) {
  const map = {
    'Lifetime': 'LIFETIME', 'Permanent': 'PERMANENT', '1 day': '1 DAY', '1 week': '1 WEEK',
    '1 month': '1 MONTH', '3 months': '3 MONTHS', '12 months': '12 MONTHS', '18 months': '18 MONTHS',
    'Per 1000': 'PER 1K', 'Per account': 'PER ACCOUNT'
  };
  return map[dur] || dur.toUpperCase();
}
function jsStr(s) { return "'" + String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'"; }
function jsArr(arr) { return '[' + arr.map(jsStr).join(',') + ']'; }
function jsSpecs(sp) { return '{' + Object.keys(sp).map(k => `${k}:${jsStr(sp[k])}`).join(',') + '}'; }
function jsStock(stk) { return stk === 'instock' ? "'instock'" : stk; }

const productBlocks = Y.products.map(p => {
  const t = jsArr([KIND_T[p.kind], durTag(p.dur)]);
  const w = p.retail ? jsStr(p.retail.toFixed(2)) : "''";
  const f = p.flag ? jsStr(p.flag) : 'null';
  return `{id:${p.id},c:${jsStr(p.shop)},lg:${jsStr(p.brand)},n:${jsStr(p.name)},t:${t},p:${jsStr(p.price.toFixed(2))},w:${w},f:${f},ac:'#ececf2',stk:${jsStock(p.stock)},
 desc:${jsArr(p.desc)},
 warn:${jsArr(p.warn)},
 sp:${jsSpecs(p.sp)}}`;
}).join(',\n\n');

// ── INT configurator entries ────────────────────────────────
const OWNACCT_LABEL = { 9: 'Spotify account email' };
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
    case 'duration':
      return `${p.id}:{type:'duration',prices:[${(p.prices || [['Standard', p.price]]).map(o => `[${jsStr(o[0])},${jsStr(o[1].toFixed ? o[1].toFixed(2) : o[1])}]`).join(',')}]}`;
    default:
      return null;
  }
}
const intBlocks = Y.products.map(intEntry).filter(Boolean).join(',\n ');

// ── splice into the (already-fixed) base script ────────────────
let script = fs.readFileSync(path.join(DIR, 'original', 'script.js'), 'utf8');

// 1) SVG map: append only the brand keys this catalogue actually needs
script = script.replace(
  /(var SVG=\{[\s\S]*?)\n\};/,
  (m, body) => newBrandKeys.length ? `${body},\n${svgAddBlock}\n};` : m
);

// 2) BRAND map
script = script.replace(
  /(var BRAND=\{[\s\S]*?)\};/,
  (m, body) => newBrandKeys.length ? `${body},${brandAddBlock}};` : m
);

// 3) P array: REPLACE entirely (this catalogue is the full product list, not an extension)
script = script.replace(
  /var P=\[[\s\S]*?\n\];/,
  `var P=[\n\n${productBlocks}\n];`
);

// 4) INT config: REPLACE entirely
script = script.replace(
  /var INT = \{[\s\S]*?\n\};/,
  `var INT = {\n ${intBlocks}\n};`
);

// keep the visible product-count stat in sync
script = script.replace('render();', "document.getElementById('stat-n').textContent=P.length;\nrender();");

fs.writeFileSync(path.join(DIR, 'dist', 'script.real.js'), script);
console.log('real script written —', Y.products.length, 'products,', newBrandKeys.length, 'brand keys added:', newBrandKeys.join(', '));

try { new Function(script); console.log('syntax OK'); }
catch (e) { console.log('SYNTAX ERROR:', e.message); }
