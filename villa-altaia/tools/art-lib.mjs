/* ---------------------------------------------------------------------------
 * art-lib.mjs — primitives de génération d'illustrations SVG
 * Palette bi-ton : bois chaud / beige  +  anthracite profond.
 * Aucune dépendance : tout est déterministe (seed) et rejouable.
 * ------------------------------------------------------------------------- */

export const PAL = {
  ink0: '#0d0f11',   // anthracite le plus profond
  ink1: '#16191c',
  ink2: '#20242a',
  ink3: '#2c3238',
  stone: '#3b424a',
  slate: '#4d555e',
  mist: '#7c848d',
  haze: '#9aa1a8',
  sand: '#cdbca6',   // beige
  cream: '#efe7db',
  snow: '#f6f2ec',
  wood: '#a8865f',   // bois chaud
  woodD: '#7d6244',
  woodL: '#c6a781',
  ember: '#d99a5c',  // accent lumière chaude
  emberL: '#f0c48d'
};

/* — aléatoire déterministe ------------------------------------------------ */
export function rng (seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const n = (v, d = 2) => Number(v.toFixed(d));

/* — déplacement de point milieu (crêtes fractales) ------------------------ */
export function fractal (rnd, levels = 7, rough = 0.55) {
  let arr = [rnd(), rnd()];
  let amp = 1;
  for (let l = 0; l < levels; l++) {
    const next = [];
    for (let i = 0; i < arr.length - 1; i++) {
      next.push(arr[i]);
      next.push((arr[i] + arr[i + 1]) / 2 + (rnd() - 0.5) * amp);
    }
    next.push(arr[arr.length - 1]);
    arr = next;
    amp *= rough;
  }
  const min = Math.min(...arr), max = Math.max(...arr);
  return arr.map(v => (v - min) / (max - min || 1));
}

/* Enveloppe gaussienne : impose 2–3 sommets dominants à la crête. */
export function envelope (len, peaks) {
  const out = new Array(len).fill(0.12);
  for (let i = 0; i < len; i++) {
    const x = i / (len - 1);
    for (const p of peaks) {
      out[i] = Math.max(out[i], p.h * Math.exp(-((x - p.x) ** 2) / (2 * p.w * p.w)));
    }
  }
  return out;
}

/* — chemin d'une crête : sommet fractal, puis fermeture vers le bas ------- */
export function ridgePath (heights, { w, baseY, amp, y0 = 0 }) {
  const pts = heights.map((v, i) => [
    n((i / (heights.length - 1)) * w),
    n(baseY - v * amp - y0)
  ]);
  let d = `M ${pts[0][0]} ${pts[0][1]}`;
  for (let i = 1; i < pts.length; i++) d += ` L ${pts[i][0]} ${pts[i][1]}`;
  return { open: d, closed: `${d} L ${w} ${baseY + amp} L 0 ${baseY + amp} Z`, pts };
}

/* Ligne de neige irrégulière suivant la crête, décalée vers le bas. */
export function snowPath (pts, drop, rnd, w, baseY) {
  const low = pts.map(([x, y], i) => [x, n(y + drop * (0.55 + 0.9 * rnd()))]);
  let d = `M ${pts[0][0]} ${pts[0][1]}`;
  for (let i = 1; i < pts.length; i++) d += ` L ${pts[i][0]} ${pts[i][1]}`;
  for (let i = low.length - 1; i >= 0; i--) d += ` L ${low[i][0]} ${low[i][1]}`;
  return d + ' Z';
}

/* — sapin : tronc + étages triangulaires légèrement irréguliers ----------- */
export function fir (x, groundY, h, rnd) {
  const w = h * (0.34 + rnd() * 0.1);
  const tiers = 5 + Math.floor(rnd() * 3);
  const trunkW = Math.max(1.2, h * 0.035);
  let d = `M ${n(x - trunkW)} ${n(groundY)} L ${n(x - trunkW)} ${n(groundY - h * 0.18)} ` +
          `L ${n(x + trunkW)} ${n(groundY - h * 0.18)} L ${n(x + trunkW)} ${n(groundY)} Z`;
  for (let t = 0; t < tiers; t++) {
    const f = t / (tiers - 1);                 // 0 = bas, 1 = haut
    const yB = groundY - h * (0.14 + f * 0.72);
    const yT = yB - h * (0.30 - f * 0.13);
    const hw = (w / 2) * (1 - f * 0.78) * (0.9 + rnd() * 0.2);
    const sway = (rnd() - 0.5) * w * 0.07;
    d += ` M ${n(x - hw + sway)} ${n(yB)} L ${n(x + sway)} ${n(yT)} ` +
         `L ${n(x + hw + sway)} ${n(yB)} L ${n(x + hw * 0.42)} ${n(yB)} ` +
         `L ${n(x - hw * 0.42)} ${n(yB)} Z`;
  }
  return d;
}

/* Rideau de sapins : renvoie un seul chemin (léger à rendre). */
export function firLine (rnd, { w, groundY, count, hMin, hMax, jitterY = 0 }) {
  let d = '';
  for (let i = 0; i < count; i++) {
    const x = ((i + rnd() * 0.85) / count) * w * 1.04 - w * 0.02;
    const h = hMin + rnd() * (hMax - hMin);
    d += fir(n(x), n(groundY + (rnd() - 0.5) * jitterY), h, rnd) + ' ';
  }
  return d.trim();
}

/* — projection en perspective à un point de fuite ------------------------- */
/* x : -1 (mur gauche) → 1 (mur droit) | y : 0 (sol) → 1 (plafond)
 * z : 0 (plan de l'objectif) → 1 (mur du fond)                             */
export function projector ({ vx, vy, halfW, halfH, k = 1.35 }) {
  return function p (x, y, z) {
    const s = 1 / (1 + z * k);
    return [n(vx + x * halfW * s), n(vy - (y - 0.5) * 2 * halfH * s)];
  };
}

export const quad = (p, a, b, c, d2) => {
  const A = p(...a), B = p(...b), C = p(...c), D = p(...d2);
  return `M ${A[0]} ${A[1]} L ${B[0]} ${B[1]} L ${C[0]} ${C[1]} L ${D[0]} ${D[1]} Z`;
};

/* — filtres et habillage partagés ---------------------------------------- */
export function defsCommon (id = '') {
  return `
    <filter id="grain${id}" x="-2%" y="-2%" width="104%" height="104%">
      <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="3" seed="7" result="n"/>
      <feColorMatrix in="n" type="saturate" values="0"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.55"/></feComponentTransfer>
    </filter>
    <filter id="soft${id}" x="-25%" y="-25%" width="150%" height="150%">
      <feGaussianBlur stdDeviation="26"/>
    </filter>
    <filter id="haze${id}" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="9"/>
    </filter>`;
}

export const grainOverlay = (w, h, o = 0.075, id = '') =>
  `<rect width="${w}" height="${h}" filter="url(#grain${id})" opacity="${o}" style="mix-blend-mode:overlay"/>`;

export const vignette = (w, h, id = 'vg') => `
  <radialGradient id="${id}" cx="50%" cy="46%" r="72%">
    <stop offset="55%" stop-color="#000" stop-opacity="0"/>
    <stop offset="100%" stop-color="#000" stop-opacity="0.62"/>
  </radialGradient>`;

export function svg (w, h, body, extra = '') {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" ` +
         `width="${w}" height="${h}" preserveAspectRatio="xMidYMid slice"${extra}>\n${body}\n</svg>\n`;
}
