// 순수 JS 픽셀 버퍼 — 브라우저와 Node 양쪽에서 쓴다(DOM 의존 없음).
// 모든 그림(공룡, 캐릭터, 타일, 오브젝트)은 이 Sprite 위에 코드로 픽셀을 찍어서 만든다.

export class Sprite {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.d = new Uint8ClampedArray(w * h * 4);
  }

  inb(x, y) {
    return x >= 0 && y >= 0 && x < this.w && y < this.h;
  }

  set(x, y, c) {
    x = Math.floor(x);
    y = Math.floor(y);
    if (!c || !this.inb(x, y)) return;
    const i = (y * this.w + x) * 4;
    const a = c[3] ?? 255;
    if (a < 255 && this.d[i + 3] > 0) {
      // 반투명 색은 아래 색과 섞는다(유령 공룡, 물 반짝임 등)
      const t = a / 255;
      this.d[i] = this.d[i] * (1 - t) + c[0] * t;
      this.d[i + 1] = this.d[i + 1] * (1 - t) + c[1] * t;
      this.d[i + 2] = this.d[i + 2] * (1 - t) + c[2] * t;
      this.d[i + 3] = Math.max(this.d[i + 3], a);
      return;
    }
    this.d[i] = c[0];
    this.d[i + 1] = c[1];
    this.d[i + 2] = c[2];
    this.d[i + 3] = a;
  }

  get(x, y) {
    if (!this.inb(x, y)) return null;
    const i = (y * this.w + x) * 4;
    if (this.d[i + 3] === 0) return null;
    return [this.d[i], this.d[i + 1], this.d[i + 2], this.d[i + 3]];
  }

  alpha(x, y) {
    return this.inb(x, y) ? this.d[(y * this.w + x) * 4 + 3] : 0;
  }

  erase(x, y) {
    if (this.inb(x, y)) this.d[(y * this.w + x) * 4 + 3] = 0;
  }

  rect(x, y, w, h, c) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, c);
  }

  // 픽셀 중심 기준으로 채운 타원. fn을 주면 픽셀마다 색을 계산한다(dx, dy는 -1~1 정규화 좌표).
  ellipse(cx, cy, rx, ry, c, fn) {
    for (let y = Math.floor(cy - ry - 1); y <= cy + ry + 1; y++) {
      for (let x = Math.floor(cx - rx - 1); x <= cx + rx + 1; x++) {
        const dx = (x + 0.5 - cx) / rx;
        const dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) this.set(x, y, fn ? fn(x, y, dx, dy) : c);
      }
    }
  }

  tri(ax, ay, bx, by, cx, cy, c) {
    const minX = Math.floor(Math.min(ax, bx, cx));
    const maxX = Math.ceil(Math.max(ax, bx, cx));
    const minY = Math.floor(Math.min(ay, by, cy));
    const maxY = Math.ceil(Math.max(ay, by, cy));
    const area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    if (area === 0) return;
    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        const px = x + 0.5;
        const py = y + 0.5;
        const w0 = ((bx - px) * (cy - py) - (by - py) * (cx - px)) / area;
        const w1 = ((cx - px) * (ay - py) - (cy - py) * (ax - px)) / area;
        const w2 = 1 - w0 - w1;
        if (w0 >= -0.01 && w1 >= -0.01 && w2 >= -0.01) this.set(x, y, c);
      }
    }
  }

  line(x0, y0, x1, y1, c) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0);
    const dy = -Math.abs(y1 - y0);
    const sx = x0 < x1 ? 1 : -1;
    const sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      this.set(x0, y0, c);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }

  // 바깥쪽 1px 외곽선(상하좌우 이웃 기준). colorFn을 주면 안쪽 픽셀 색에 맞춰 외곽선 색을 정한다.
  outline(c, colorFn) {
    const pts = [];
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        if (this.alpha(x, y) > 0) continue;
        const nb = [[1, 0], [-1, 0], [0, 1], [0, -1]].find(([ox, oy]) => this.alpha(x + ox, y + oy) > 0);
        if (nb) pts.push([x, y, nb]);
      }
    }
    for (const [x, y, [ox, oy]] of pts) {
      this.set(x, y, colorFn ? colorFn(this.get(x + ox, y + oy)) : c);
    }
  }

  paste(src, ox, oy) {
    for (let y = 0; y < src.h; y++) {
      for (let x = 0; x < src.w; x++) {
        const c = src.get(x, y);
        if (c) this.set(x + ox, y + oy, c);
      }
    }
  }

  flipX() {
    const s = new Sprite(this.w, this.h);
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        const c = this.get(x, y);
        if (c) s.set(this.w - 1 - x, y, c);
      }
    }
    return s;
  }

  scaled(k) {
    const s = new Sprite(this.w * k, this.h * k);
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        const c = this.get(x, y);
        if (c) s.rect(x * k, y * k, k, k, c);
      }
    }
    return s;
  }
}

export function rgb(hex, a = 255) {
  const h = hex.replace('#', '');
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), a];
}

export function mix(c1, c2, t) {
  return [
    Math.round(c1[0] + (c2[0] - c1[0]) * t),
    Math.round(c1[1] + (c2[1] - c1[1]) * t),
    Math.round(c1[2] + (c2[2] - c1[2]) * t),
    c1[3] ?? 255,
  ];
}

// 파스텔 게임답게 어두운 색도 순수 검정이 아니라 보랏빛 갈색 쪽으로 섞는다.
export const darken = (c, t) => mix(c, [58, 38, 62, c[3] ?? 255], t);
export const lighten = (c, t) => mix(c, [255, 255, 255, c[3] ?? 255], t);

export function hsl(h, s, l, a = 255) {
  s /= 100;
  l /= 100;
  const k = (n) => (n + h / 30) % 12;
  const f = (n) => l - s * Math.min(l, 1 - l) * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  return [Math.round(f(0) * 255), Math.round(f(8) * 255), Math.round(f(4) * 255), a];
}

// 시드 고정 난수(같은 시드면 항상 같은 결과 — 도감/맵이 매번 똑같이 나오게)
export function rng(seed) {
  let a = seed >>> 0;
  const r = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  r.int = (n) => Math.floor(r() * n);
  r.pick = (arr) => arr[Math.floor(r() * arr.length)];
  r.chance = (p) => r() < p;
  return r;
}

// 여러 스프라이트를 격자 시트 하나로 합친다(셀 크기는 가장 큰 스프라이트 기준, 바닥 정렬).
export function makeSheet(sprites, cols, pad = 0) {
  const cw = Math.max(...sprites.map((s) => s.w)) + pad * 2;
  const ch = Math.max(...sprites.map((s) => s.h)) + pad * 2;
  const rows = Math.ceil(sprites.length / cols);
  const sheet = new Sprite(cw * cols, ch * rows);
  sprites.forEach((s, i) => {
    const cx = (i % cols) * cw + Math.floor((cw - s.w) / 2);
    const cy = Math.floor(i / cols) * ch + (ch - s.h) - pad;
    sheet.paste(s, cx, cy);
  });
  return { sheet, cw, ch, cols, rows };
}
