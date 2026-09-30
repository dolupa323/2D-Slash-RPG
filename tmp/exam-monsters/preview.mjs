import { Sprite } from './js/pixel.js';
import { buildDex, idleFrames, walkFrames, CW, CH } from './js/buns.js';
import { savePng } from './tools/png.mjs';
import { fileURLToPath } from 'node:url';

const ids = ['norok', 'dalko', 'rapi', 'amro', 'oreubi'];
const removed = ['buldam', 'mulahol', 'ikkigoseum'];
const dex = buildDex();
for (const id of removed) if (dex.some((entry) => entry.species === id)) throw new Error(`Still present: ${id}`);
const sheet = new Sprite(CW * 8 * 4, CH * ids.length * 4);
for (const [row, id] of ids.entries()) {
  const entry = dex.find((d) => d.species === id);
  if (!entry) throw new Error(`Missing: ${id}`);
  const frames = [...idleFrames(entry), ...walkFrames(entry)];
  if (frames.length !== 8) throw new Error(`Wrong frame count: ${id}`);
  frames.forEach((frame, col) => sheet.paste(frame.scaled(4), col * CW * 4, row * CH * 4));
  console.log(entry.no, entry.name, entry.element);
}
savePng(sheet, fileURLToPath(new URL('exam-five-preview.png', import.meta.url)));
// Roblox에 내보낼 아틀라스와 같은 2종/줄 배치까지 확인한다.
const atlas = new Sprite(CW * 16 * 2, CH * Math.ceil(dex.length / 2));
if (atlas.w > 1024 || atlas.h > 1024) throw new Error(`Atlas too large: ${atlas.w}x${atlas.h}`);
for (const [i, entry] of dex.entries()) {
  const idle = idleFrames(entry), walk = walkFrames(entry);
  const frames = [...idle, ...walk, ...idle.map((frame) => frame.flipX()), ...walk.map((frame) => frame.flipX())];
  const x = (i % 2) * 16 * CW;
  const y = Math.floor(i / 2) * CH;
  frames.forEach((frame, col) => atlas.paste(frame, x + col * CW, y));
  if (!frames[0].d.some((value, channel) => channel % 4 === 3 && value > 0)) throw new Error(`Empty frame: ${entry.species}`);
}
savePng(atlas, fileURLToPath(new URL('exam-monsters-atlas.png', import.meta.url)));
console.log('atlas', atlas.w, atlas.h);
console.log('total', dex.length);
