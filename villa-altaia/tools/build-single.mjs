#!/usr/bin/env node
/* ---------------------------------------------------------------------------
 * build-single.mjs — replie tout le site dans un seul fichier HTML.
 *
 *   node tools/build-single.mjs
 *
 * Produit deux sorties dans dist/ :
 *   villa-altaia.html   document complet, à ouvrir d'un double-clic
 *   artifact.html       même page sans l'enveloppe <html>/<head>/<body>,
 *                       pour publication en Artifact
 *
 * CSS, JavaScript, illustrations, affiche et vidéo sont intégrés : la page
 * n'a plus besoin d'aucun fichier voisin. Seules les fontes restent distantes
 * (repli sur les piles système hors ligne).
 * ------------------------------------------------------------------------- */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(join(root, p), 'utf8');
const MIME = {
  '.svg': 'image/svg+xml', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.png': 'image/png', '.webm': 'video/webm', '.mp4': 'video/mp4'
};

function dataURI (rel) {
  const buf = readFileSync(join(root, rel));
  const mime = MIME[extname(rel).toLowerCase()];
  if (!mime) throw new Error('type inconnu : ' + rel);
  return `data:${mime};base64,${buf.toString('base64')}`;
}

let html = read('index.html');

/* — 1. feuille de style ------------------------------------------------- */
html = html.replace(
  /<link rel="stylesheet" href="assets\/css\/villa\.css">/,
  `<style>\n${read('assets/css/villa.css')}\n</style>`
);

/* — 2. scripts, dans l'ordre de chargement ------------------------------- */
html = html.replace(/\n?<script src="(assets\/[^"]+)" defer><\/script>/g,
  (_, src) => `\n<script>\n/* ${src} */\n${read(src)}\n</script>`);

/* — 3. médias ------------------------------------------------------------ */
const seen = new Map();
const embed = (rel) => {
  if (!seen.has(rel)) seen.set(rel, dataURI(rel));
  return seen.get(rel);
};
html = html.replace(/(src|data-src|poster)="(assets\/(?:img|video)\/[^"]+)"/g,
  (_, attr, rel) => `${attr}="${embed(rel)}"`);

/* — 4. références devenues inutiles ou cassées une fois repliées --------- */
html = html.replace(/\n<link rel="preload" as="image"[^>]*>/g, '');
html = html.replace(/\n<meta property="og:image"[^>]*>/g, '');

/* — 5. écriture ---------------------------------------------------------- */
mkdirSync(join(root, 'dist'), { recursive: true });
writeFileSync(join(root, 'dist', 'villa-altaia.html'), html);

/* La publication en Artifact fournit elle-même <!doctype>, <head> et <body>. */
const fragment = html
  .replace(/^[\s\S]*?<title>[^<]*<\/title>/, '<title>Villa Altaïa</title>')
  .replace(/\n<meta[^>]*>/g, '')
  .replace(/\n<link rel="icon"[^>]*>/g, '')
  .replace(/<\/head>\s*<body>/, '')
  .replace(/<\/body>\s*<\/html>\s*$/, '');
writeFileSync(join(root, 'dist', 'artifact.html'), fragment);

const ko = (p) => (readFileSync(join(root, p)).length / 1024).toFixed(0);
console.log(`dist/villa-altaia.html  ${ko('dist/villa-altaia.html')} Ko`);
console.log(`dist/artifact.html      ${ko('dist/artifact.html')} Ko`);
console.log(`${seen.size} médias intégrés`);
