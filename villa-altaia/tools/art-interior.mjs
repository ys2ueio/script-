/* ---------------------------------------------------------------------------
 * art-interior.mjs — intérieurs en perspective à un point de fuite.
 *
 * Principe photographique : une seule source dominante par pièce (la baie, le
 * foyer, le bassin). Tout le reste est une silhouette anthracite qui ne reçoit
 * qu'un liseré. C'est ce qui donne la lecture immédiate du volume — et la
 * hiérarchie de valeurs d'une vraie photographie d'architecture.
 * ------------------------------------------------------------------------- */
import { PAL, n, rng, projector, quad, defsCommon, grainOverlay, svg } from './art-lib.mjs';

const W = 1800, H = 1200;
const P = projector({ vx: 900, vy: 620, halfW: 1500, halfH: 900, k: 1.35 });

/* — volume : sol, plafond, murs, mur du fond ----------------------------- */
function shell (o = {}) {
  const {
    floor = '#1a1512', ceil = '#0c0e10', wallL = '#272c32',
    wallR = '#131619', back = '#171b1f', zFar = 1
  } = o;
  return `
  <path d="${quad(P, [-1, 1, 0], [1, 1, 0], [1, 1, zFar], [-1, 1, zFar])}" fill="${ceil}"/>
  <path d="${quad(P, [-1, 0, 0], [1, 0, 0], [1, 0, zFar], [-1, 0, zFar])}" fill="${floor}"/>
  <path d="${quad(P, [-1, 0, 0], [-1, 0, zFar], [-1, 1, zFar], [-1, 1, 0])}" fill="${wallL}"/>
  <path d="${quad(P, [1, 0, 0], [1, 0, zFar], [1, 1, zFar], [1, 1, 0])}" fill="${wallR}"/>
  <path d="${quad(P, [-1, 0, zFar], [1, 0, zFar], [1, 1, zFar], [-1, 1, zFar])}" fill="${back}"/>`;
}

/* arêtes du volume : quatre fuyantes + le cadre du fond, tracées finement */
function edges (op = 0.16, zFar = 1) {
  const seg = (a, b) => {
    const A = P(...a), B = P(...b);
    return `M ${A[0]} ${A[1]} L ${B[0]} ${B[1]} `;
  };
  const d =
    seg([-1, 0, 0], [-1, 0, zFar]) + seg([1, 0, 0], [1, 0, zFar]) +
    seg([-1, 1, 0], [-1, 1, zFar]) + seg([1, 1, 0], [1, 1, zFar]) +
    seg([-1, 0, zFar], [1, 0, zFar]) + seg([-1, 1, zFar], [1, 1, zFar]) +
    seg([-1, 0, zFar], [-1, 1, zFar]) + seg([1, 0, zFar], [1, 1, zFar]);
  return `<path d="${d}" stroke="#e8e0d2" stroke-width="1.4" fill="none" opacity="${op}"/>`;
}

/* lames de parquet : segments à x constant, fortement fuyants */
function boards (count = 22, y = 0.0005, zA = 0, zB = 1, stroke = '#000', op = 0.42) {
  let d = '';
  for (let i = 0; i <= count; i++) {
    const x = -1 + (2 * i) / count;
    const a = P(x, y, zA), b = P(x, y, zB);
    d += `M ${a[0]} ${a[1]} L ${b[0]} ${b[1]} `;
  }
  return `<path d="${d}" stroke="${stroke}" stroke-width="1.7" opacity="${op}" fill="none"/>`;
}

/* poutres apparentes : bandes à z constant, plus fines en s'éloignant */
function beams (count = 9, fill = '#1d1710', zA = 0.02, zB = 0.98) {
  let s = '';
  for (let i = 0; i < count; i++) {
    const z = zA + ((zB - zA) * i) / (count - 1);
    const t = 0.014 + 0.022 * (1 - z);
    s += `<path d="${quad(P, [-1, 1, z], [1, 1, z], [1, 1, z + t], [-1, 1, z + t])}" fill="${fill}"/>` +
         `<path d="${quad(P, [-1, 1, z + t], [1, 1, z + t], [1, 1, z + t + 0.004], [-1, 1, z + t + 0.004])}"
                fill="#4a3a26" opacity="0.5"/>`;
  }
  return s;
}

/* Silhouette : face avant + dessus, plus un liseré sur l'arête éclairée.
   Un meuble ne se lit pas par sa matière mais par sa découpe sur la lumière. */
function mass (x0, x1, y0, y1, z0, z1, o = {}) {
  const { fill = '#0c0e10', top = '#14181c', rim = null, rimOp = 0.5 } = o;
  let s =
    `<path d="${quad(P, [x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1])}" fill="${top}"/>` +
    `<path d="${quad(P, [x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0])}" fill="${fill}"/>`;
  if (rim) {
    const a = P(x0, y1, z0), b = P(x1, y1, z0);
    s += `<path d="M ${a[0]} ${a[1]} L ${b[0]} ${b[1]}" stroke="${rim}" ` +
         `stroke-width="2.6" opacity="${rimOp}" fill="none"/>`;
  }
  return s;
}

/* ouverture dans un mur latéral (x constant) / dans le mur du fond (z constant) */
const sideWin = (x, y0, y1, z0, z1, fill, extra = '') =>
  `<path d="${quad(P, [x, y0, z0], [x, y0, z1], [x, y1, z1], [x, y1, z0])}" fill="${fill}"${extra}/>`;
const backWin = (x0, x1, y0, y1, z, fill, extra = '') =>
  `<path d="${quad(P, [x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z])}" fill="${fill}"${extra}/>`;

/* faisceau : la lumière de la baie posée au sol, en dégradé */
function shaft (pts, grad, op = 0.5, blur = '') {
  const d = pts.map((p, i) => `${i ? 'L' : 'M'} ${P(...p)[0]} ${P(...p)[1]}`).join(' ') + ' Z';
  return `<path d="${d}" fill="url(#${grad})" opacity="${op}"` +
         (blur ? ` filter="url(#soft${blur})"` : '') +
         ` style="mix-blend-mode:screen"/>`;
}

/* crêtes miniatures à l'intérieur d'une baie (mur du fond) */
function ridgesIn (x0, x1, y0, y1, z, seed) {
  const rnd = rng(seed);
  const layers = [
    { k: 0.70, col: '#6f7780', op: 0.75 },
    { k: 0.52, col: '#3f464e', op: 0.9 },
    { k: 0.36, col: '#1b1f24', op: 1 }
  ];
  let out = '';
  for (const L of layers) {
    const steps = 30;
    let d = `M ${P(x0, y0, z)[0]} ${P(x0, y0, z)[1]}`;
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const yy = y0 + (y1 - y0) * L.k *
        (0.40 + 0.60 * Math.abs(Math.sin(t * 7.3 + seed))) * (0.65 + 0.5 * rnd());
      const p = P(x0 + (x1 - x0) * t, Math.min(y1, yy), z);
      d += ` L ${p[0]} ${p[1]}`;
    }
    const e = P(x1, y0, z);
    d += ` L ${e[0]} ${e[1]} Z`;
    out += `<path d="${d}" fill="${L.col}" opacity="${L.op}"/>`;
  }
  return out;
}

/* — dégradés partagés ---------------------------------------------------- */
const DEFS = `
  <linearGradient id="day" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%"   stop-color="#7d8b98"/>
    <stop offset="46%"  stop-color="#c3c8cb"/>
    <stop offset="78%"  stop-color="#e8dcc8"/>
    <stop offset="100%" stop-color="#f3e9d8"/>
  </linearGradient>
  <linearGradient id="dawn" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%"   stop-color="#2b3742"/>
    <stop offset="38%"  stop-color="#8d9499"/>
    <stop offset="74%"  stop-color="#dcc7a6"/>
    <stop offset="100%" stop-color="#f0dcbb"/>
  </linearGradient>
  <linearGradient id="fire" x1="0" y1="1" x2="0" y2="0">
    <stop offset="0%"   stop-color="#ffe6bb"/>
    <stop offset="46%"  stop-color="#f0a95e"/>
    <stop offset="100%" stop-color="#6d3512"/>
  </linearGradient>
  <linearGradient id="woodv" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="${PAL.woodL}"/><stop offset="100%" stop-color="#3f2f1f"/>
  </linearGradient>
  <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#f2ece3" stop-opacity="0.55"/>
    <stop offset="100%" stop-color="#f2ece3" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="beamw" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="${PAL.emberL}" stop-opacity="0.5"/>
    <stop offset="100%" stop-color="${PAL.ember}" stop-opacity="0"/>
  </linearGradient>
  <radialGradient id="warm" cx="50%" cy="50%" r="50%">
    <stop offset="0%"  stop-color="${PAL.emberL}" stop-opacity="0.9"/>
    <stop offset="40%" stop-color="${PAL.ember}"  stop-opacity="0.34"/>
    <stop offset="100%" stop-color="${PAL.ember}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="cool" cx="50%" cy="50%" r="50%">
    <stop offset="0%"  stop-color="#dde6ee" stop-opacity="0.55"/>
    <stop offset="100%" stop-color="#dde6ee" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="aqua" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%"   stop-color="#2f6a79" stop-opacity="0.55"/>
    <stop offset="42%"  stop-color="#3f8494" stop-opacity="0.30"/>
    <stop offset="100%" stop-color="#8fd0dd" stop-opacity="0.18"/>
  </linearGradient>
  <radialGradient id="vg" cx="50%" cy="46%" r="72%">
    <stop offset="52%" stop-color="#000" stop-opacity="0"/>
    <stop offset="100%" stop-color="#000" stop-opacity="0.52"/>
  </radialGradient>`;

const finish = (id) =>
  `${grainOverlay(W, H, 0.055, id)}<rect width="${W}" height="${H}" fill="url(#vg)"/>`;

const page = (id, body) =>
  svg(W, H, `<defs>${defsCommon(id)}${DEFS}</defs>\n${body}\n${finish(id)}`);

/* =======================  SALON  ========================================
   Deux sources : la baie ouest (froide, à gauche) et le foyer (chaude, au
   fond). Le mobilier n'est qu'une découpe noire entre les deux.           */
export function salon () {
  return page('S', `
  ${shell({ floor: '#20180f', ceil: '#0a0c0e', wallL: '#2b3138', wallR: '#111417', back: '#151a1e' })}
  ${boards(24, 0.0005, 0, 1, '#080a0b', 0.48)}
  ${beams(9)}

  <!-- baie ouest : la source principale -->
  ${sideWin(-0.999, 0.14, 0.88, 0.20, 0.74, 'url(#day)')}
  ${sideWin(-0.997, 0.14, 0.88, 0.455, 0.475, '#0b0d0f')}
  ${sideWin(-0.997, 0.505, 0.525, 0.20, 0.74, '#0b0d0f')}

  <!-- faisceau posé au sol -->
  ${shaft([[-1, 0.001, 0.20], [-1, 0.001, 0.74], [0.28, 0.001, 0.82], [0.16, 0.001, 0.18]], 'beam', 0.34, 'S')}
  <ellipse cx="400" cy="880" rx="430" ry="165" fill="url(#cool)" opacity="0.8" style="mix-blend-mode:screen"/>

  <!-- masse de pierre du foyer, du sol au plafond -->
  ${backWin(-0.58, -0.02, 0, 1, 0.999, '#1f242a')}
  ${backWin(-0.58, -0.565, 0, 1, 0.998, '#0d0f11')}
  ${backWin(-0.035, -0.02, 0, 1, 0.998, '#0d0f11')}
  ${backWin(-0.58, -0.02, 0.500, 0.523, 0.998, '#2c333b')}
  ${backWin(-0.62, 0.02, 0.523, 0.550, 0.997, 'url(#woodv)')}
  <!-- foyer -->
  ${backWin(-0.47, -0.13, 0.045, 0.40, 0.997, '#07080a')}
  ${backWin(-0.455, -0.145, 0.058, 0.372, 0.996, 'url(#fire)')}
  ${shaft([[-0.44, 0.001, 0.99], [-0.10, 0.001, 0.99], [0.24, 0.001, 0.10], [-0.78, 0.001, 0.10]], 'beamw', 0.42, 'S')}
  <ellipse cx="700" cy="822" rx="340" ry="140" fill="url(#warm)" opacity="0.85"/>
  <ellipse cx="720" cy="756" rx="185" ry="110" fill="url(#warm)" style="mix-blend-mode:screen"/>

  <!-- silhouettes : canapé, méridienne, table basse -->
  ${mass(-0.66, -0.02, 0, 0.155, 0.30, 0.54, { rim: '#e6ddcd', rimOp: 0.34 })}
  ${mass(-0.66, -0.02, 0.155, 0.335, 0.49, 0.54, { rim: '#e6ddcd', rimOp: 0.22 })}
  ${mass(0.20, 0.68, 0, 0.14, 0.32, 0.52, { rim: '#f0c48d', rimOp: 0.28 })}
  ${mass(-0.19, 0.17, 0, 0.085, 0.15, 0.25, { fill: '#181109', top: '#3a2a18', rim: '#f0c48d', rimOp: 0.4 })}

  <!-- suspension -->
  ${backWin(-0.028, 0.028, 0.815, 0.845, 0.34, '#101315')}
  <ellipse cx="900" cy="470" rx="112" ry="40" fill="url(#warm)" opacity="0.55"/>
  ${edges(0.13)}`);
}

/* =======================  SUITE  ========================================
   Un seul mur : la baie. Le lit n'est qu'une découpe sombre devant l'aube. */
export function chambre () {
  return page('B', `
  ${shell({ floor: '#1d1710', ceil: '#0b0d0f', wallL: '#1b1f24', wallR: '#15181c', back: '#0d1013' })}
  ${boards(20, 0.0005, 0, 1, '#08090a', 0.4)}

  <!-- baie panoramique plein cadre -->
  ${backWin(-0.82, 0.82, 0.10, 0.88, 0.999, 'url(#dawn)')}
  ${ridgesIn(-0.82, 0.82, 0.10, 0.88, 0.998, 3)}
  ${backWin(-0.011, 0.011, 0.10, 0.88, 0.997, '#0a0c0e')}
  ${backWin(-0.44, -0.42, 0.10, 0.88, 0.997, '#0a0c0e', ' opacity="0.7"')}
  ${backWin(0.42, 0.44, 0.10, 0.88, 0.997, '#0a0c0e', ' opacity="0.7"')}
  ${backWin(-0.82, 0.82, 0.10, 0.118, 0.996, '#0a0c0e')}
  ${backWin(-0.82, 0.82, 0.862, 0.88, 0.996, '#0a0c0e')}

  <!-- la lumière du jour glisse sur le sol -->
  ${shaft([[-0.82, 0.001, 0.99], [0.82, 0.001, 0.99], [1, 0.001, 0.05], [-1, 0.001, 0.05]], 'beam', 0.26, 'B')}
  <ellipse cx="900" cy="700" rx="620" ry="230" fill="url(#cool)" opacity="0.7"/>

  <!-- lit : silhouette, seul le bord du drap accroche la lumière -->
  ${mass(-0.52, 0.52, 0.10, 0.40, 0.72, 0.76, { fill: '#0a0c0e', top: '#141118', rim: '#e9dcc4', rimOp: 0.5 })}
  ${mass(-0.50, 0.50, 0, 0.115, 0.24, 0.72, { fill: '#0b0d0f', top: '#191410' })}
  ${mass(-0.50, 0.50, 0.115, 0.20, 0.24, 0.72, { fill: '#15100b', top: '#2c241a', rim: '#efe2ca', rimOp: 0.55 })}
  ${mass(-0.50, 0.50, 0.20, 0.235, 0.24, 0.42, { fill: '#241d14', top: '#5d4c35', rim: '#f2e7d3', rimOp: 0.45 })}
  ${mass(-0.38, -0.05, 0.20, 0.275, 0.62, 0.71, { fill: '#1d1811', top: '#4a3f2e', rim: '#f2e7d3', rimOp: 0.5 })}
  ${mass(0.05, 0.38, 0.20, 0.275, 0.62, 0.71, { fill: '#1d1811', top: '#4a3f2e', rim: '#f2e7d3', rimOp: 0.5 })}

  <!-- chevets et liseuses -->
  ${mass(-0.76, -0.56, 0, 0.14, 0.62, 0.74, { fill: '#0a0c0e', top: '#17130e', rim: '#f0c48d', rimOp: 0.3 })}
  ${mass(0.56, 0.76, 0, 0.14, 0.62, 0.74, { fill: '#0a0c0e', top: '#17130e', rim: '#f0c48d', rimOp: 0.3 })}
  <ellipse cx="440" cy="628" rx="105" ry="82" fill="url(#warm)" opacity="0.75"/>
  <ellipse cx="1360" cy="628" rx="105" ry="82" fill="url(#warm)" opacity="0.75"/>
  ${beams(5, '#181209', 0.02, 0.42)}
  ${edges(0.1)}`);
}

/* =======================  SPA  ==========================================
   La source est sous l'eau : le bassin éclaire la pièce par en dessous.
   Le cadrage est décalé vers le haut pour que le plan d'eau occupe la scène. */
export function spa () {
  const rnd = rng(4242);
  let ripples = '';
  for (let i = 0; i < 22; i++) {
    const z = 0.30 + rnd() * 0.62;
    const a = P(-0.52 + rnd() * 0.22, 0.002, z), b = P(0.14 + rnd() * 0.38, 0.002, z);
    ripples += `<path d="M ${a[0]} ${a[1]} L ${b[0]} ${b[1]}" stroke="#eaf5f7" ` +
               `stroke-width="${n(1 + rnd() * 2.2, 1)}" opacity="${n(0.05 + rnd() * 0.16, 3)}"/>`;
  }
  return page('P', `
  <g transform="translate(0 -168)">
  ${shell({ floor: '#15181b', ceil: '#0a0c0d', wallL: '#1c2127', wallR: '#111417', back: '#151a20' })}

  <!-- meurtrière à hauteur d'eau, volontairement retenue -->
  ${backWin(-0.66, 0.66, 0.62, 0.80, 0.999, 'url(#day)', ' opacity="0.48"')}
  ${ridgesIn(-0.66, 0.66, 0.62, 0.80, 0.998, 11)}
  ${backWin(-0.66, 0.66, 0.62, 0.634, 0.997, '#0a0c0e')}
  ${backWin(-0.66, 0.66, 0.786, 0.80, 0.997, '#0a0c0e')}
  ${backWin(-0.011, 0.011, 0.62, 0.80, 0.997, '#0a0c0e')}

  <!-- margelle de pierre -->
  <path d="${quad(P, [-0.64, 0.02, 0.24], [0.64, 0.02, 0.24], [0.64, 0.02, 0.30], [-0.64, 0.02, 0.30])}" fill="#2b3239"/>
  <path d="${quad(P, [-0.64, 0.02, 0.24], [-0.58, 0.02, 0.24], [-0.58, 0.02, 0.99], [-0.64, 0.02, 0.99])}" fill="#262c33"/>
  <path d="${quad(P, [0.58, 0.02, 0.24], [0.64, 0.02, 0.24], [0.64, 0.02, 0.99], [0.58, 0.02, 0.99])}" fill="#262c33"/>

  <!-- le bassin : profond, puis illuminé par en dessous -->
  <path d="${quad(P, [-0.58, 0.001, 0.30], [0.58, 0.001, 0.30], [0.58, 0.001, 0.97], [-0.58, 0.001, 0.97])}" fill="#0e2a31"/>
  <path d="${quad(P, [-0.58, 0.001, 0.30], [0.58, 0.001, 0.30], [0.58, 0.001, 0.97], [-0.58, 0.001, 0.97])}"
        fill="url(#aqua)" style="mix-blend-mode:screen"/>
  ${ripples}
  <ellipse cx="900" cy="1010" rx="420" ry="120" fill="#7fc6d6" opacity="0.22"
           filter="url(#softP)" style="mix-blend-mode:screen"/>

  <!-- la vapeur ne monte qu'au-dessus de l'eau -->
  <g filter="url(#softP)" opacity="0.16">
    <ellipse cx="760" cy="880" rx="250" ry="62" fill="#eaf1f3"/>
    <ellipse cx="1120" cy="856" rx="200" ry="52" fill="#eaf1f3"/>
  </g>

  <!-- reflets du bassin remontant sur les murs -->
  <g filter="url(#softP)" opacity="0.35" style="mix-blend-mode:screen">
    ${sideWin(-0.996, 0.10, 0.34, 0.30, 0.92, '#7fc6d6')}
    ${sideWin(0.996, 0.10, 0.34, 0.30, 0.92, '#7fc6d6')}
  </g>

  <!-- bains de soleil et appliques -->
  ${mass(-1.02, -0.68, 0, 0.12, 0.06, 0.34, { fill: '#08090b', top: '#181309', rim: '#f0c48d', rimOp: 0.4 })}
  ${mass(0.68, 1.02, 0, 0.12, 0.06, 0.34, { fill: '#08090b', top: '#181309', rim: '#f0c48d', rimOp: 0.4 })}
  ${sideWin(-0.998, 0.40, 0.56, 0.16, 0.21, 'url(#fire)')}
  ${sideWin(0.998, 0.40, 0.56, 0.16, 0.21, 'url(#fire)')}
  <ellipse cx="230" cy="640" rx="180" ry="160" fill="url(#warm)" opacity="0.45"/>
  <ellipse cx="1570" cy="640" rx="180" ry="160" fill="url(#warm)" opacity="0.45"/>
  ${edges(0.1)}
  </g>`);
}

/* =======================  TERRASSE  =====================================
   Extérieur : le ciel est la source, le plancher reste dans l'ombre.      */
export function terrasse () {
  const rnd = rng(9001);
  let rail = '';
  for (let i = 0; i <= 17; i++) {
    const x = -0.94 + (1.88 * i) / 17;
    const a = P(x, 0.02, 0.86), b = P(x, 0.215, 0.86);
    rail += `<path d="M ${a[0]} ${a[1]} L ${b[0]} ${b[1]}" stroke="#0e1114" stroke-width="2.6" opacity="0.85"/>`;
  }
  let ridges = '';
  const bands = [
    { y: 452, a: 215, c: '#7f8892', o: 0.55 },
    { y: 548, a: 195, c: '#434a52', o: 0.9 },
    { y: 632, a: 165, c: '#1e2328', o: 1 }
  ];
  for (const B of bands) {
    let d = `M 0 ${B.y + B.a}`;
    for (let i = 0; i <= 44; i++) {
      const t = i / 44;
      const y = B.y - B.a * (0.34 + 0.66 * Math.abs(Math.sin(t * 6.1 + B.a))) * (0.62 + 0.55 * rnd());
      d += ` L ${n(t * W)} ${n(y)}`;
    }
    d += ` L ${W} ${B.y + B.a} Z`;
    ridges += `<path d="${d}" fill="${B.c}" opacity="${B.o}"/>`;
  }
  return page('X', `
  <defs>
    <linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%"   stop-color="#121820"/>
      <stop offset="34%"  stop-color="#3d4149"/>
      <stop offset="62%"  stop-color="#8e7f6c"/>
      <stop offset="84%"  stop-color="#cfa77a"/>
      <stop offset="100%" stop-color="#e7cba1"/>
    </linearGradient>
    <radialGradient id="lowsun" cx="63%" cy="56%" r="42%">
      <stop offset="0%"   stop-color="#ffdcac" stop-opacity="0.85"/>
      <stop offset="46%"  stop-color="${PAL.ember}" stop-opacity="0.22"/>
      <stop offset="100%" stop-color="${PAL.ember}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="brasier" cx="50%" cy="50%" r="50%">
      <stop offset="0%"   stop-color="#ffe2b4" stop-opacity="0.95"/>
      <stop offset="26%"  stop-color="${PAL.ember}" stop-opacity="0.5"/>
      <stop offset="100%" stop-color="${PAL.ember}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#dusk)"/>
  <rect width="${W}" height="${H}" fill="url(#lowsun)" style="mix-blend-mode:screen"/>
  ${ridges}

  <!-- plancher de mélèze, volontairement sombre : le texte se pose dessus -->
  <path d="${quad(P, [-1, 0, 0], [1, 0, 0], [1, 0, 0.87], [-1, 0, 0.87])}" fill="#191510"/>
  ${boards(26, 0.0005, 0, 0.87, '#0a0806', 0.55)}
  <path d="${quad(P, [-1, 0, 0], [1, 0, 0], [1, 0, 0.87], [-1, 0, 0.87])}"
        fill="url(#lowsun)" opacity="0.30" style="mix-blend-mode:screen"/>

  <!-- garde-corps -->
  <path d="${quad(P, [-0.96, 0.215, 0.86], [0.96, 0.215, 0.86], [0.96, 0.245, 0.86], [-0.96, 0.245, 0.86])}" fill="#171310"/>
  ${rail}

  <!-- bains nordiques et brasero -->
  ${mass(-0.72, -0.34, 0, 0.11, 0.28, 0.58, { fill: '#0d0b09', top: '#241d14', rim: '#f0c48d', rimOp: 0.35 })}
  ${mass(0.34, 0.72, 0, 0.11, 0.28, 0.58, { fill: '#0d0b09', top: '#241d14', rim: '#f0c48d', rimOp: 0.35 })}
  ${mass(-0.13, 0.13, 0, 0.075, 0.18, 0.32, { fill: '#0b0a09', top: '#20242a', rim: '#ffdcac', rimOp: 0.75 })}
  <ellipse cx="900" cy="864" rx="300" ry="130" fill="url(#brasier)"/>
  ${edges(0.06, 0.87)}`);
}

/* =======================  VIGNETTES DES CARTES  ========================= */
export const cuisine = () => page('K', `
  ${shell({ floor: '#1d1710', ceil: '#0b0d0f', wallL: '#20252b', wallR: '#14171a', back: '#171c21' })}
  ${boards(18, 0.0005, 0, 1, '#08090a', 0.4)}
  ${backWin(-0.88, 0.88, 0.36, 0.60, 0.999, '#0c0f12')}
  ${backWin(-0.88, 0.88, 0.60, 0.632, 0.998, 'url(#woodv)')}
  ${backWin(-0.88, 0.88, 0.30, 0.36, 0.998, '#0a0c0e')}
  ${mass(-0.48, 0.48, 0, 0.29, 0.22, 0.52, { fill: '#0d1013', top: '#1a1e23' })}
  ${mass(-0.50, 0.50, 0.29, 0.325, 0.20, 0.54, { fill: '#3f3227', top: '#8d7757', rim: '#e9dcc4', rimOp: 0.45 })}
  <ellipse cx="640" cy="446" rx="86" ry="34" fill="url(#warm)"/>
  <ellipse cx="900" cy="446" rx="86" ry="34" fill="url(#warm)"/>
  <ellipse cx="1160" cy="446" rx="86" ry="34" fill="url(#warm)"/>
  <ellipse cx="900" cy="700" rx="520" ry="190" fill="url(#warm)" opacity="0.35"/>
  ${edges(0.12)}`);

export const cave = () => {
  let racks = '';
  for (let r = 0; r < 7; r++) {
    for (let c = 0; c < 9; c++) {
      const y = 0.14 + r * 0.105, z = 0.28 + c * 0.078;
      racks += sideWin(-0.998, y, y + 0.075, z, z + 0.058, '#4e3d29');
      racks += sideWin(0.998, y, y + 0.075, z, z + 0.058, '#372b1d');
    }
  }
  return page('K', `
  ${shell({ floor: '#141618', ceil: '#0a0b0d', wallL: '#1b1f24', wallR: '#131518', back: '#171a1e' })}
  ${racks}
  ${backWin(-0.30, 0.30, 0.08, 0.70, 0.999, '#241a10')}
  ${backWin(-0.16, 0.16, 0.30, 0.52, 0.998, 'url(#fire)', ' opacity="0.55"')}
  <ellipse cx="900" cy="600" rx="300" ry="250" fill="url(#warm)" opacity="0.5"/>
  ${mass(-0.26, 0.26, 0, 0.21, 0.18, 0.40, { fill: '#0b0d0f', top: '#241c13', rim: '#f0c48d', rimOp: 0.4 })}
  ${edges(0.1)}`);
};

export const ski = () => {
  let skis = '';
  for (let i = 0; i < 9; i++) {
    const x = -0.62 + i * 0.155;
    skis += backWin(x, x + 0.032, 0.03, 0.60, 0.985, i % 2 ? '#8d7757' : '#2b3038');
  }
  return page('K', `
  ${shell({ floor: '#17191c', ceil: '#0b0d0e', wallL: '#1c2024', wallR: '#141719', back: '#1a1e23' })}
  ${boards(16, 0.0005, 0, 1, '#08090a', 0.4)}
  ${skis}
  ${mass(-0.72, 0.72, 0, 0.13, 0.28, 0.46, { fill: '#0c0e10', top: '#2e2417', rim: '#f0c48d', rimOp: 0.4 })}
  <ellipse cx="900" cy="520" rx="440" ry="170" fill="url(#warm)" opacity="0.34"/>
  ${edges(0.12)}`);
};

export const cinema = () => page('K', `
  ${shell({ floor: '#111315', ceil: '#08090b', wallL: '#171a1e', wallR: '#111315', back: '#0a0b0d' })}
  ${backWin(-0.74, 0.74, 0.24, 0.82, 0.999, '#2e363e')}
  ${backWin(-0.71, 0.71, 0.26, 0.80, 0.998, '#98a4ae')}
  <ellipse cx="900" cy="540" rx="620" ry="250" fill="url(#cool)" opacity="0.55"/>
  ${mass(-0.80, -0.10, 0, 0.20, 0.26, 0.44, { fill: '#0b0d0f', top: '#1a1e23', rim: '#c9d3db', rimOp: 0.35 })}
  ${mass(0.10, 0.80, 0, 0.20, 0.26, 0.44, { fill: '#0b0d0f', top: '#1a1e23', rim: '#c9d3db', rimOp: 0.35 })}
  ${mass(-0.80, -0.10, 0, 0.24, 0.04, 0.20, { fill: '#0a0b0d', top: '#181c20', rim: '#c9d3db', rimOp: 0.28 })}
  ${mass(0.10, 0.80, 0, 0.24, 0.04, 0.20, { fill: '#0a0b0d', top: '#181c20', rim: '#c9d3db', rimOp: 0.28 })}
  ${edges(0.08)}`);
