#!/usr/bin/env node
/* ---------------------------------------------------------------------------
 * build-art.mjs — génère toutes les illustrations SVG du site.
 *   node tools/build-art.mjs
 * Les fichiers produits sont versionnés : le site reste utilisable hors ligne
 * et sans étape de build. Relancer ce script après toute retouche des scènes.
 * ------------------------------------------------------------------------- */
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as out from './art-outdoor.mjs';
import * as int from './art-interior.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const dir = join(here, '..', 'assets', 'img');
mkdirSync(dir, { recursive: true });

const files = {
  'sky.svg': out.sky(),
  'peaks-far.svg': out.peaksFar(),
  'peaks-mid.svg': out.peaksMid(),
  'forest.svg': out.forest(),
  'chalet.svg': out.chalet(),
  'drift.svg': out.drift(),
  'view.svg': out.windowView(),
  'salon.svg': int.salon(),
  'chambre.svg': int.chambre(),
  'spa.svg': int.spa(),
  'terrasse.svg': int.terrasse(),
  'card-cuisine.svg': int.cuisine(),
  'card-cave.svg': int.cave(),
  'card-ski.svg': int.ski(),
  'card-cinema.svg': int.cinema()
};

let total = 0;
for (const [name, body] of Object.entries(files)) {
  writeFileSync(join(dir, name), body);
  total += body.length;
  console.log(String(body.length).padStart(8), name);
}
console.log(`\n${Object.keys(files).length} fichiers — ${(total / 1024).toFixed(1)} Ko`);
