// 도트 스타일 규칙(공용) — 공방에서 새로 찍는 도트가 모두 같은 명암·외곽선 규칙을 따르게 한다.
//  1) 색 사다리 ramp(기본색): 기본색에서 명암 5단계(0 가장 어두움 ~ 4 가장 밝음)를 만든다.
//     밝아질수록 색상을 노란 쪽(따뜻하게), 어두워질수록 보라 쪽(차갑게)으로 조금씩 튼다(hue shift) — 단조로운 명암보다 생기 있다.
//  2) 빛은 항상 왼쪽 위: 설계도에서 왼쪽/위 면에 밝은 단계, 오른쪽/아래 면에 어두운 단계를 쓴다.
//  3) 부분 외곽선 selectiveOutline(그림): 외곽선을 전부 진보라로 치지 않고, 닿은 부분 색을 진보라 쪽으로 어둡게 한 색으로 친다.
//  설계도(rows): 글자마다 색을 정해(key → [사다리, 단계]) stamp()로 찍는다. '.'은 빈칸.
import { Sprite, rgb, mix } from './pixel.js';

export const INK = rgb('#3b2a4f'); // 게임 공통 진보라(외곽선 기준색)

function toHsl([r, g, b]) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return [0, 0, l];
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [h * 60, s, l];
}
function fromHsl(h, s, l) {
  h = ((h % 360) + 360) % 360;
  s = Math.max(0, Math.min(1, s)); l = Math.max(0, Math.min(1, l));
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = l - c / 2;
  const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255), 255];
}
// 색상 h를 목표 색상 쪽으로 deg만큼 돌린다(가까운 방향)
function turn(h, target, deg) {
  const diff = ((target - h + 540) % 360) - 180;
  return h + Math.sign(diff) * Math.min(Math.abs(diff), deg);
}

// 기본색(hex) → 명암 5단계 [0 가장 어두움 … 2 기본 … 4 가장 밝음]
// opt: step(밝기 간격), shift(단계당 색상 회전 각), warm/cool(밝은 쪽·어두운 쪽 목표 색상)
export function ramp(hex, opt = {}) {
  const { step = 0.13, shift = 9, warm = 55, cool = 275, satDark = 0.03 } = opt;
  const [h, s, l] = toHsl(rgb(hex));
  const out = [];
  for (let i = -2; i <= 2; i++) {
    const hh = i > 0 ? turn(h, warm, shift * i) : i < 0 ? turn(h, cool, shift * -i) : h;
    const ss = s * (i < 0 ? 1 + satDark * -i : 1 - 0.1 * i); // 어두운 쪽은 살짝 진하게(과하면 주황·갈색이 탁해짐), 밝은 쪽은 조금 옅게
    out.push(fromHsl(hh, ss, l + step * i));
  }
  return out;
}

// 설계도 찍기: key = { 글자: [사다리, 단계] }
export function stamp(rows, key, w = rows[0].length, h = rows.length) {
  const s = new Sprite(w, h);
  rows.forEach((row, y) => [...row].forEach((ch, x) => {
    const k = key[ch];
    if (k) s.set(x, y, k[0][k[1]]);
  }));
  return s;
}

// 부분 외곽선: 빈칸 중 채워진 칸과 맞닿은 곳에, 닿은 색을 진보라 쪽으로 어둡게 한 색을 칠한다.
// 밝은 색일수록 더 많이 어둡게(밝은 면 옆 외곽선이 회색으로 뜨지 않게) — amount를 주면 고정 비율.
const lum = ([r, g, b]) => (0.299 * r + 0.587 * g + 0.114 * b) / 255;
// 외곽선 색 하나 정하기(닿은 색 → 외곽선 색). 다른 그림 코드(몬스터 등)의 outline(colorFn)에도 그대로 쓴다.
export const outlineColor = (near, amount = null) => mix(near, INK, amount ?? 0.55 + 0.35 * lum(near));
// 이미 외곽선이 그려진 그림(설계도 스탬프 등)의 가장자리를 새 규칙으로 통일: 실루엣 가장자리 픽셀 중 밝은 것(밝기 > threshold)을
// 그 색의 외곽선 색(outlineColor)으로 바꾼다. 그림 크기는 그대로(배치가 바뀌지 않음).
export function darkenEdges(spr, threshold = 0.45) {
  const solid = (x, y) => spr.alpha(x, y) >= 128;
  const changes = [];
  for (let y = 0; y < spr.h; y++) for (let x = 0; x < spr.w; x++) {
    if (!solid(x, y)) continue;
    if (solid(x + 1, y) && solid(x - 1, y) && solid(x, y + 1) && solid(x, y - 1)) continue;
    const c = spr.get(x, y);
    if (lum(c) > threshold) changes.push([x, y, outlineColor(c)]);
  }
  for (const [x, y, c] of changes) spr.set(x, y, c);
  return spr;
}

export function selectiveOutline(spr, amount = null) {
  const out = new Sprite(spr.w, spr.h);
  out.paste(spr, 0, 0);
  for (let y = 0; y < spr.h; y++) for (let x = 0; x < spr.w; x++) {
    if (spr.alpha(x, y)) continue;
    let near = null;
    for (const [ox, oy] of [[0, 1], [1, 0], [-1, 0], [0, -1]]) { // 아래·옆 우선(그늘 쪽 색을 따라감)
      const c = spr.get(x + ox, y + oy);
      if (c) { near = c; break; }
    }
    if (near) out.set(x, y, outlineColor(near, amount));
  }
  return out;
}
