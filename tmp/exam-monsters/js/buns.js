// 만두형 몬스터 — 예시 영상(Dumpling Dell)처럼 "머리만 있는" 둥근 몸 하나에
// 그 동물다운 특징 하나둘(귀, 부리, 꼬리, 얼굴 무늬)만 붙여서 구분한다.
// 동물마다 어울리는 속성은 딱 하나(펭귄=물, 여우=불, 토끼=풀 …), 몬스터도 종마다 딱 하나.
// 몸 크기·비율(폭 w, 높이 h, 모양 shape)은 종마다 다르다.
import { Sprite, rgb, darken, lighten, mix } from './pixel.js';
import { outlineColor } from './pixelStyle.js';

export const CW = 32;
export const CH = 30;
const CX = 16; // 좌우 대칭 축(픽셀 15와 16 사이)
const BOT = CH - 4; // 몸 맨 아랫줄(아래는 그림자, 위는 귀·뿔 여유)
const mx = (x) => 2 * CX - 1 - x; // 픽셀 좌우 대칭
const mc = (c) => 2 * CX - c; // 연속 좌표(타원 중심 등) 좌우 대칭

export const ELEMENTS = {
  fire: { name: '불', color: '#ff8f5e', icon: '🔥' },
  grass: { name: '풀', color: '#6cc25a', icon: '🌿' },
  water: { name: '물', color: '#5aaef0', icon: '💧' },
};

const EYE = rgb('#3b2a3f');
const WHITE = rgb('#ffffff');
const BLUSH = rgb('#ff8fae', 170);
const PINK = rgb('#ffb3c6');
const NOSE = rgb('#4a3440');
const F_R = rgb('#ff5a3c'), F_O = rgb('#ff9a3c'), F_Y = rgb('#ffe066');
const G_D = rgb('#4f9e3f'), G_M = rgb('#7fcf5a'), G_L = rgb('#b4ec8a');

// ---- 기본 도구 ----
const pts = (s, list, c, mirror = false) => {
  for (const [x, y] of list) {
    s.set(x, y, c);
    if (mirror) s.set(mx(x), y, c);
  }
};

// 불꽃(x = 가운데 두 픽셀 중 오른쪽, y = 맨 위)
function flame(s, x, y, size = 'big') {
  const big = [[0, 0, F_R], [-1, 1, F_R], [0, 1, F_O], [-2, 2, F_R], [-1, 2, F_O], [0, 2, F_O], [1, 2, F_R],
    [-2, 3, F_R], [-1, 3, F_O], [0, 3, F_Y], [1, 3, F_R], [-1, 4, F_O], [0, 4, F_Y]];
  const small = [[0, 0, F_R], [-1, 1, F_R], [0, 1, F_O], [-1, 2, F_O], [0, 2, F_Y]];
  for (const [dx, dy, c] of size === 'big' ? big : small) s.set(x + dx, y + dy, c);
}

// 새싹 두 잎(가운데 축 위)
function sprout(s, y, narrow = false) {
  pts(s, [[CX - 1, y + 2], [CX - 1, y + 3]], G_D, true);
  if (narrow) { pts(s, [[CX - 2, y + 1], [CX - 3, y]], G_M, true); pts(s, [[CX - 2, y]], G_L, true); return; }
  pts(s, [[CX - 4, y], [CX - 3, y + 1], [CX - 2, y + 1], [CX - 2, y + 2]], G_M, true);
  pts(s, [[CX - 3, y]], G_L, true);
}

// 잎 하나(x,y = 잎 뿌리, dir = 1 오른쪽 / -1 왼쪽)
function leaf(s, x, y, dir = 1) {
  s.set(x, y, G_D);
  pts(s, [[x + dir, y - 1], [x + 2 * dir, y - 1], [x + dir, y - 2], [x + 2 * dir, y - 2], [x + 3 * dir, y - 2]], G_M);
  s.set(x + 3 * dir, y - 3, G_M);
  s.set(x + 2 * dir, y - 2, G_L);
}

// ---- 몸 ----
// shape: bun(아래가 납작한 만두) / round(동그라미) / drop(위가 뾰족한 물방울) / flat(넓적)
function makeBody(w, h, shape) {
  const k = { bun: 0.8, round: 0.54, drop: 0.64, flat: 0.86 }[shape] ?? 0.8;
  const top = BOT - h + 1;
  const ry = h * k;
  const cy = top + ry;
  const rx = w / 2;
  const rows = new Map();
  for (let y = top; y <= BOT; y++) {
    const dy = (y + 0.5 - cy) / ry;
    if (Math.abs(dy) > 1) continue;
    let hw = rx * Math.sqrt(1 - dy * dy);
    if (shape === 'drop' && dy < 0) hw *= 1 + dy * 0.6;
    let half = Math.round(hw);
    if (y === BOT && shape !== 'round') half -= 1; // 아래 모서리 둥글게
    if (half > 0) rows.set(y, [CX - half, CX + half - 1]);
  }
  const ys = [...rows.keys()];
  return { w, h, top: Math.min(...ys), bot: BOT, rows, L: CX - w / 2, R: CX + w / 2 - 1,
    inBody: (x, y) => rows.has(y) && x >= rows.get(y)[0] && x <= rows.get(y)[1] };
}

function paintBody(s, g, base) {
  const shade = darken(base, 0.13);
  const hi = lighten(base, 0.5);
  for (const [y, [x0, x1]] of g.rows) {
    for (let x = x0; x <= x1; x++) {
      let c = base;
      if (y === g.bot) c = shade;
      else if (y >= g.bot - 2 && x >= CX + 1) c = shade;
      else if (x === x1 && y >= g.top + g.h * 0.45) c = shade;
      s.set(x, y, c);
    }
  }
  // 왼쪽 위 반짝이
  const r1 = g.rows.get(g.top + 1), r2 = g.rows.get(g.top + 2);
  if (r1) { s.set(r1[0] + 1, g.top + 1, hi); s.set(r1[0] + 2, g.top + 1, hi); }
  if (r2) s.set(r2[0] + 1, g.top + 2, hi);
}

// 몸 안쪽에만 칠하기(얼굴 무늬 등)
function clipEllipse(s, g, cx, cy, rx, ry, c) {
  s.ellipse(cx, cy, rx, ry, null, (x, y) => (g.inBody(x, y) ? c : s.get(x, y)));
}

// ---- 얼굴 ----
function face(s, g, sp, o) {
  const ey = g.ey;
  const ex = g.ex;
  const eye = sp.eyeColor ? rgb(sp.eyeColor) : EYE;
  if (!sp.customEyes) {
    if (o.blink) pts(s, [[ex, ey + 1]], eye, true);
    else pts(s, [[ex, ey], [ex, ey + 1]], eye, true);
  }
  if (sp.blush !== false) pts(s, [[ex - 2, ey + 2]], BLUSH, true);
  const my = ey + 2;
  switch (sp.mouth === undefined ? 'dot' : sp.mouth) {
    case 'dot': pts(s, [[CX - 1, my]], EYE, true); break;
    case 'wide': pts(s, [[CX - 3, my - 1], [CX - 2, my], [CX - 1, my]], EYE, true); break;
    case 'o': pts(s, [[CX - 1, my]], rgb('#e0607a'), true); break;
    default: break;
  }
}

// ---- 종 목록 ----
// back: 몸 뒤(귀, 꼬리, 갈기), under: 몸 위·얼굴 아래(얼굴 무늬), front: 얼굴 위(부리, 불꽃, 잎)
export const SPECIES = [
  // ===== 불 =====
  {
    id: 'piyo', name: '불꽃병아리', element: 'fire', animal: '병아리', motif: '머리에 불꽃 볏이 난 병아리',
    color: '#ffd35c', w: 14, h: 11, shape: 'round', mouth: null,
    back(s, g, c) { pts(s, [[g.L - 1, g.ey + 2], [g.L - 1, g.ey + 3], [g.L, g.ey + 4]], c.dk, true); },
    front(s, g) {
      flame(s, CX, g.top - 4);
      pts(s, [[CX - 1, g.ey + 2]], rgb('#ff9a3c'), true);
      pts(s, [[CX - 1, g.ey + 3]], rgb('#e07f2a'), true);
    },
  },
  {
    id: 'yeowoo', name: '불여우', element: 'fire', animal: '여우', motif: '꼬리 끝이 불꽃인 여우',
    color: '#ff9a4d', w: 18, h: 11, shape: 'bun',
    back(s, g, c) {
      s.tri(g.L + 1, g.top + 4, g.L + 2, g.top - 4, g.L + 7, g.top + 1, c.base);
      s.tri(mc(g.L + 1), g.top + 4, mc(g.L + 2), g.top - 4, mc(g.L + 7), g.top + 1, c.base);
      s.tri(g.L + 2.2, g.top + 2, g.L + 2.4, g.top - 1, g.L + 4.8, g.top + 1, F_Y);
      s.tri(mc(g.L + 2.2), g.top + 2, mc(g.L + 2.4), g.top - 1, mc(g.L + 4.8), g.top + 1, F_Y);
      // 불꽃 꼬리(오른쪽 뒤)
      s.ellipse(g.R + 2, g.bot - 2.5, 2.6, 2.5, c.dk);
      flame(s, g.R + 3, g.bot - 9);
    },
    under(s, g) { clipEllipse(s, g, CX, g.bot - 1, 4.6, 2.6, rgb('#fff1dc')); },
  },
  {
    id: 'wonsung', name: '불원숭이', element: 'fire', animal: '원숭이', motif: '머리에 불꽃이 타는 원숭이',
    color: '#b8784e', w: 14, h: 12, shape: 'bun',
    back(s, g, c) {
      s.ellipse(g.L + 0.5, g.ey + 0.5, 2.4, 2.4, c.base);
      s.ellipse(mc(g.L + 0.5), g.ey + 0.5, 2.4, 2.4, c.base);
      pts(s, [[g.L - 1, g.ey], [g.L - 1, g.ey + 1]], rgb('#f5d2a8'), true);
    },
    under(s, g) {
      const cream = rgb('#f5d8b0');
      clipEllipse(s, g, CX - 2, g.ey + 1, 2.8, 2.8, cream);
      clipEllipse(s, g, mc(CX - 2), g.ey + 1, 2.8, 2.8, cream);
      clipEllipse(s, g, CX, g.ey + 3, 4.2, 2.2, cream);
    },
    front(s, g) { flame(s, CX, g.top - 4); },
  },

  {
    id: 'bulpanda', name: '불판다', element: 'fire', animal: '레서판다', motif: '흰 눈썹과 줄무늬 꼬리의 레서판다',
    color: '#e8743c', w: 18, h: 11, shape: 'bun', mouth: null,
    back(s, g, c) {
      // 줄무늬 꼬리(오른쪽 뒤, 위로 말림)
      const ring = rgb('#fff1dc');
      for (let i = 0; i < 6; i++) {
        const col = i % 2 === 0 ? c.base : ring;
        s.rect(g.R + 1 + Math.min(i, 2), g.bot - 2 - i, 3, 1, col);
      }
      flame(s, g.R + 5, g.bot - 11, 'small');
      // 둥근 귀(흰 테두리)
      s.ellipse(g.L + 3.5, g.top + 1, 2.4, 2.4, rgb('#fff1dc'));
      s.ellipse(mc(g.L + 3.5), g.top + 1, 2.4, 2.4, rgb('#fff1dc'));
      s.ellipse(g.L + 3.5, g.top + 1.5, 1.4, 1.4, rgb('#7a3a2a'));
      s.ellipse(mc(g.L + 3.5), g.top + 1.5, 1.4, 1.4, rgb('#7a3a2a'));
    },
    under(s, g) {
      const w = rgb('#fff1dc');
      clipEllipse(s, g, CX, g.bot - 1.5, 4.2, 2.4, w);
      pts(s, [[g.ex, g.ey - 2], [g.ex - 1, g.ey - 2]], w, true);
    },
    front(s, g) { pts(s, [[CX - 1, g.ey + 2]], NOSE, true); },
  },
  {
    id: 'bulham', name: '불햄찌', element: 'fire', animal: '햄스터', motif: '볼주머니가 불씨처럼 빛나는 햄스터',
    color: '#ffc98a', w: 14, h: 12, shape: 'round', mouth: 'dot', blush: false,
    back(s, g, c) {
      s.ellipse(g.L + 2.5, g.top + 1.5, 1.8, 1.8, c.base);
      s.ellipse(mc(g.L + 2.5), g.top + 1.5, 1.8, 1.8, c.base);
      pts(s, [[g.L + 2, g.top + 1]], PINK, true);
    },
    under(s, g) {
      const cream = rgb('#fff4e2');
      clipEllipse(s, g, CX, g.bot - 2, 4.5, 3.4, cream);
      // 불씨 볼주머니
      s.ellipse(g.L + 2.5, g.ey + 3, 2.2, 1.8, rgb('#ffb070'));
      s.ellipse(mc(g.L + 2.5), g.ey + 3, 2.2, 1.8, rgb('#ffb070'));
      pts(s, [[g.L + 2, g.ey + 3]], F_R, true);
    },
    front(s, g) { flame(s, CX, g.top - 2, 'small'); },
  },

  {
    id: 'kkulkkul', name: '불꿀꿀', element: 'fire', animal: '돼지', motif: '동글 분홍 코의 아기 돼지',
    color: '#ffb49a', w: 18, h: 10, shape: 'bun', mouth: null,
    back(s, g, c) {
      s.tri(CX - 7, g.top + 3, CX - 7, g.top - 2, CX - 3, g.top + 1, c.dk);
      s.tri(mc(CX - 7), g.top + 3, mc(CX - 7), g.top - 2, mc(CX - 3), g.top + 1, c.dk);
    },
    front(s, g) {
      // 동글 코: 가운데가 넓은 둥근 분홍 코 + 콧구멍 두 점
      const sn = rgb('#ff9fb4'), sh = rgb('#f27f98'), hole = rgb('#b8506a');
      s.rect(CX - 2, g.ey + 2, 4, 1, sn);
      s.rect(CX - 3, g.ey + 3, 6, 1, sn);
      s.rect(CX - 2, g.ey + 4, 4, 1, sh);
      s.set(CX - 2, g.ey + 2, rgb('#ffc8d4'));
      pts(s, [[CX - 2, g.ey + 3]], hole, true);
      flame(s, CX, g.top - 2, 'small');
    },
  },
  {
    id: 'bulbu', name: '불부엉이', element: 'fire', animal: '부엉이', motif: '불꽃 귀깃과 둥근 얼굴판',
    color: '#c98a5a', w: 14, h: 12, shape: 'round', mouth: null,
    back(s, g) {
      flame(s, g.L + 3, g.top - 3, 'small');
      flame(s, mx(g.L + 3) + 1, g.top - 3, 'small');
    },
    under(s, g, c) {
      const disc = rgb('#f6dcbc');
      clipEllipse(s, g, g.ex + 0.5, g.ey + 1, 2.6, 2.6, disc);
      clipEllipse(s, g, mc(g.ex + 0.5), g.ey + 1, 2.6, 2.6, disc);
      pts(s, [[CX - 3, g.bot - 2], [CX - 2, g.bot - 1]], darken(c.base, 0.2), true);
    },
    front(s, g) {
      pts(s, [[CX - 1, g.ey + 2]], rgb('#ffa93c'), true);
      s.set(CX - 1, g.ey + 3, rgb('#e07f2a')); s.set(CX, g.ey + 3, rgb('#e07f2a'));
    },
  },
  {
    id: 'bulyeomso', name: '불염소', element: 'fire', animal: '염소', motif: '돌돌 만 뿔과 하얀 턱수염',
    color: '#f6f2ec', w: 14, h: 11, shape: 'bun', mouth: null,
    back(s, g, c) {
      pts(s, [[g.L + 2, g.top], [g.L + 1, g.top - 1], [g.L + 1, g.top - 2], [g.L + 2, g.top - 3], [g.L + 3, g.top - 2]], rgb('#c9a06a'), true);
      pts(s, [[g.L - 1, g.ey], [g.L - 2, g.ey + 1], [g.L - 1, g.ey + 1]], c.dk, true);
    },
    under(s, g) { clipEllipse(s, g, CX, g.bot - 1, 2, 2.2, rgb('#e2d8c8')); },
    front(s, g) {
      flame(s, CX, g.top - 2, 'small');
      pts(s, [[CX - 1, g.ey + 2]], rgb('#ff9aa8'), true);
    },
  },
  {
    id: 'bulbakjwi', name: '불박쥐', element: 'fire', animal: '박쥐', motif: '큰 귀와 노을빛 날개',
    color: '#8a6a9a', w: 12, h: 10, shape: 'round', mouth: null,
    back(s, g, c) {
      const wing = rgb('#6a4a7a'), mem = rgb('#ff9a6a');
      s.tri(g.L + 1, g.ey - 1, g.L - 6, g.ey - 3, g.L - 5, g.bot - 2, wing);
      s.tri(mc(g.L + 1), g.ey - 1, mc(g.L - 6), g.ey - 3, mc(g.L - 5), g.bot - 2, wing);
      s.tri(g.L, g.ey, g.L - 4, g.ey - 1, g.L - 3, g.bot - 3, mem);
      s.tri(mc(g.L), g.ey, mc(g.L - 4), g.ey - 1, mc(g.L - 3), g.bot - 3, mem);
      s.tri(g.L + 1, g.top + 3, g.L + 1, g.top - 3, g.L + 5, g.top + 1, c.base);
      s.tri(mc(g.L + 1), g.top + 3, mc(g.L + 1), g.top - 3, mc(g.L + 5), g.top + 1, c.base);
      pts(s, [[g.L + 1, g.top - 3], [g.L + 1, g.top - 2]], F_O, true);
    },
    front(s, g) { pts(s, [[CX - 1, g.ey + 2]], EYE, true); s.set(CX + 1, g.ey + 3, WHITE); },
  },
  {
    id: 'buldudu', name: '불두더지', element: 'fire', animal: '두더지', motif: '분홍 별 코와 큰 앞발',
    color: '#8a6660', w: 16, h: 10, shape: 'flat', mouth: null, eyeGap: 3,
    back(s, g) {
      pts(s, [[g.L - 1, g.bot - 2], [g.L - 2, g.bot - 1], [g.L - 1, g.bot], [g.L, g.bot]], rgb('#ffe6d8'), true);
    },
    under(s, g) { clipEllipse(s, g, CX, g.bot - 0.5, 4, 2, rgb('#b89088')); },
    front(s, g) {
      const n = rgb('#ff8fae');
      pts(s, [[CX - 1, g.ey + 2], [CX - 1, g.ey + 3], [CX - 1, g.ey + 4], [CX - 2, g.ey + 3]], n, true);
      flame(s, CX, g.top - 3, 'small');
    },
  },

  // ===== 물 =====
  {
    id: 'penggu', name: '물펭구', element: 'water', animal: '펭귄', motif: '하얀 얼굴의 통통한 펭귄',
    color: '#3f5a8a', w: 14, h: 13, shape: 'bun', mouth: null,
    back(s, g, c) { pts(s, [[g.L - 1, g.bot - 4], [g.L - 1, g.bot - 3], [g.L - 2, g.bot - 2]], c.dk, true); },
    under(s, g) {
      const wh = rgb('#f4f8ff');
      clipEllipse(s, g, CX - 2, g.ey + 0.5, 2.8, 3, wh);
      clipEllipse(s, g, mc(CX - 2), g.ey + 0.5, 2.8, 3, wh);
      clipEllipse(s, g, CX, g.ey + 3, 4.6, 3.4, wh);
    },
    front(s, g) {
      pts(s, [[CX - 1, g.ey + 2]], rgb('#ffa93c'), true);
      pts(s, [[CX - 1, g.ey + 3]], rgb('#e07f2a'), true);
    },
  },
  {
    id: 'sudal', name: '조개수달', element: 'water', animal: '수달', motif: '이마에 조개를 붙인 수달',
    color: '#b88a64', w: 16, h: 10, shape: 'bun', mouth: null,
    back(s, g, c) { s.rect(g.L + 1, g.top + 1, 2, 2, c.dk); s.rect(mx(g.L + 2), g.top + 1, 2, 2, c.dk); },
    under(s, g) { clipEllipse(s, g, CX, g.bot - 1, 5.6, 2.4, rgb('#f7e6d0')); },
    front(s, g, c) {
      pts(s, [[CX - 1, g.ey + 2]], NOSE, true);
      pts(s, [[g.L + 1, g.ey + 3], [g.L + 2, g.ey + 4]], c.dk, true);
      const sh = rgb('#9fe0ff'), sd = rgb('#5ab8f0');
      pts(s, [[CX - 1, g.top]], sh, true);
      pts(s, [[CX - 2, g.top + 1], [CX - 1, g.top + 1]], sh, true);
      pts(s, [[CX - 2, g.top + 2]], sd, true);
      pts(s, [[CX - 1, g.top + 2]], sh, true);
    },
  },
  {
    id: 'mulbeom', name: '점박이물범', element: 'water', animal: '물범', motif: '콧수염 점이 있는 하얀 물범',
    color: '#e8f0f8', w: 16, h: 11, shape: 'bun', mouth: null,
    front(s, g) {
      pts(s, [[CX - 1, g.ey + 2]], NOSE, true);
      pts(s, [[CX - 3, g.ey + 3], [CX - 4, g.ey + 2]], rgb('#a8b8cc'), true);
      pts(s, [[CX - 4, g.top + 2], [CX + 2, g.top + 1], [CX + 4, g.top + 3], [CX - 1, g.top + 3]], rgb('#b8cce0'));
    },
  },

  {
    id: 'mulori', name: '물오리', element: 'water', animal: '오리', motif: '물결 목도리를 한 넓적 부리 오리',
    color: '#f6fbff', w: 14, h: 11, shape: 'round', mouth: null,
    back(s, g, c) {
      pts(s, [[g.L - 1, g.ey + 2], [g.L - 1, g.ey + 3], [g.L, g.ey + 4]], rgb('#cfe4f5'), true);
      // 머리 위 말린 깃털
      pts(s, [[CX, g.top - 1], [CX + 1, g.top - 2], [CX, g.top - 3]], rgb('#bfe0f8'));
    },
    under(s, g) {
      // 물결 목도리
      for (let x = 0; x < 32; x++) if (g.inBody(x, g.ey + 5)) s.set(x, g.ey + 5 + ((x & 1) ? 0 : 1), rgb('#6fb4ec'));
    },
    front(s, g) {
      const bill = rgb('#ffb33c');
      pts(s, [[CX - 2, g.ey + 2], [CX - 1, g.ey + 2]], bill, true);
      pts(s, [[CX - 2, g.ey + 3], [CX - 1, g.ey + 3]], rgb('#e8922a'), true);
    },
  },

  {
    id: 'mulkkotge', name: '물꽃게', element: 'water', animal: '게', motif: '눈자루와 번쩍 든 집게발',
    color: '#7ab8e8', w: 18, h: 9, shape: 'flat', mouth: 'wide', customEyes: true, eyeGap: 4,
    back(s, g, c) {
      pts(s, [[CX - 4, g.top], [CX - 4, g.top - 1]], c.dk, true);
      s.ellipse(CX - 3.5, g.top - 2.5, 1.6, 1.6, WHITE);
      s.ellipse(mc(CX - 3.5), g.top - 2.5, 1.6, 1.6, WHITE);
      for (const cx of [g.L - 1.5, mc(g.L - 1.5)]) {
        s.ellipse(cx, g.top + 1, 2.6, 2.6, c.base);
        s.erase(Math.floor(cx), g.top - 1);
        s.erase(Math.floor(cx), g.top);
      }
      pts(s, [[g.L, g.top + 3], [g.L + 1, g.top + 4]], c.base, true);
    },
    front(s, g, c, o) {
      if (o.blink) pts(s, [[CX - 4, g.top - 2]], EYE, true);
      else pts(s, [[CX - 4, g.top - 3], [CX - 4, g.top - 2]], EYE, true);
    },
  },
  {
    id: 'mulbiber', name: '물비버', element: 'water', animal: '비버', motif: '큰 앞니와 넓적한 꼬리',
    color: '#b07850', w: 16, h: 11, shape: 'bun', mouth: null,
    back(s, g, c) {
      const tl = rgb('#6a4a3a');
      s.ellipse(g.R + 2.5, g.bot - 2, 3, 2, tl);
      pts(s, [[g.R + 1, g.bot - 2], [g.R + 3, g.bot - 2], [g.R + 2, g.bot - 1], [g.R + 4, g.bot - 1]], darken(tl, 0.25));
      s.ellipse(g.L + 2.5, g.top + 1, 1.6, 1.6, c.dk);
      s.ellipse(mc(g.L + 2.5), g.top + 1, 1.6, 1.6, c.dk);
    },
    under(s, g) { clipEllipse(s, g, CX, g.bot - 1.5, 4, 2.4, rgb('#e8c8a0')); },
    front(s, g) {
      pts(s, [[CX - 1, g.ey + 2]], NOSE, true);
      pts(s, [[CX - 1, g.ey + 3], [CX - 1, g.ey + 4]], WHITE, true);
      pts(s, [[CX + 3, g.top - 3], [CX + 3, g.top - 2], [CX + 2, g.top - 2], [CX + 4, g.top - 2]], rgb('#9fd8ff'));
    },
  },
  {
    id: 'mulakeo', name: '물악어', element: 'water', animal: '악어', motif: '긴 주둥이와 삐죽 이빨',
    color: '#6cbfa0', w: 20, h: 9, shape: 'flat', mouth: null, customEyes: true,
    back(s, g, c) {
      s.ellipse(CX - 4.5, g.top + 0.5, 2, 2, c.base);
      s.ellipse(mc(CX - 4.5), g.top + 0.5, 2, 2, c.base);
    },
    under(s, g, c) {
      for (let x = CX - 7; x <= CX + 6; x++) s.set(x, g.bot - 2, darken(c.base, 0.32));
      pts(s, [[CX - 6, g.bot - 1], [CX - 3, g.bot - 1]], WHITE, true);
      pts(s, [[CX - 1, g.top + 3]], c.dk, true);
    },
    front(s, g, c, o) {
      if (o.blink) pts(s, [[CX - 5, g.top]], EYE, true);
      else pts(s, [[CX - 5, g.top - 1], [CX - 5, g.top]], EYE, true);
    },
  },
  {
    id: 'mulbukgeuk', name: '물북극곰', element: 'water', animal: '북극곰', motif: '눈송이를 얹은 새하얀 곰',
    color: '#f4f8fc', w: 18, h: 12, shape: 'bun', mouth: null,
    back(s, g, c) {
      s.ellipse(CX - 5.5, g.top + 1.5, 2.2, 2.2, c.base);
      s.ellipse(mc(CX - 5.5), g.top + 1.5, 2.2, 2.2, c.base);
      pts(s, [[CX - 6, g.top + 1]], rgb('#d8e4f0'), true);
    },
    under(s, g) { clipEllipse(s, g, CX, g.ey + 3, 3, 2, rgb('#e2eaf6')); },
    front(s, g) {
      pts(s, [[CX - 1, g.ey + 2]], NOSE, true);
      const b = rgb('#8fcbf0'), x = CX + 3, y = g.top - 1;
      pts(s, [[x, y - 2], [x, y - 1], [x, y + 1], [x, y + 2], [x - 2, y], [x - 1, y], [x + 1, y], [x + 2, y], [x - 1, y - 1], [x + 1, y + 1], [x + 1, y - 1], [x - 1, y + 1]], b);
      s.set(x, y, WHITE);
    },
  },
  {
    id: 'mulgalme', name: '물갈매기', element: 'water', animal: '갈매기', motif: '세일러 모자를 쓴 갈매기',
    color: '#ffffff', w: 14, h: 11, shape: 'round', mouth: null,
    back(s, g) { pts(s, [[g.L - 1, g.ey + 2], [g.L - 1, g.ey + 3], [g.L, g.ey + 4]], rgb('#b8c4d4'), true); },
    front(s, g) {
      s.rect(CX - 3, g.top - 2, 6, 2, WHITE);
      s.rect(CX - 4, g.top, 8, 1, rgb('#4a6fb8'));
      const bk = rgb('#ffcf4a');
      pts(s, [[CX - 1, g.ey + 2]], bk, true);
      s.set(CX - 1, g.ey + 3, bk); s.set(CX, g.ey + 3, rgb('#ff6f5a'));
    },
  },

  // ===== 풀 =====
  {
    id: 'ssakto', name: '새싹토끼', element: 'grass', animal: '토끼', motif: '긴 귀 사이에 새싹이 난 토끼',
    color: '#f4f0e0', w: 14, h: 11, shape: 'bun',
    back(s, g, c) {
      for (let y = g.top - 7; y <= g.top + 2; y++) {
        pts(s, [[CX - 5, y], [CX - 4, y]], c.base, true);
        if (y > g.top - 6 && y < g.top + 1) pts(s, [[CX - 4, y]], PINK, true);
      }
      s.erase(CX - 5, g.top - 7); s.erase(mx(CX - 5), g.top - 7); // 귀 끝 둥글게
    },
    front(s, g) { sprout(s, g.top - 3, true); },
  },
  {
    id: 'supgom', name: '숲곰', element: 'grass', animal: '곰', motif: '머리에 잎사귀를 얹은 곰',
    color: '#b08a60', w: 18, h: 12, shape: 'bun', mouth: null,
    back(s, g, c) {
      s.ellipse(CX - 5.5, g.top + 1.5, 2.3, 2.3, c.base);
      s.ellipse(mc(CX - 5.5), g.top + 1.5, 2.3, 2.3, c.base);
      pts(s, [[CX - 6, g.top + 1]], c.dk, true);
    },
    under(s, g) { clipEllipse(s, g, CX, g.ey + 3, 3, 2, rgb('#f0dcc0')); },
    front(s, g) { pts(s, [[CX - 1, g.ey + 2]], NOSE, true); leaf(s, CX + 1, g.top, 1); },
  },
  {
    id: 'daram', name: '도토리다람', element: 'grass', animal: '다람쥐', motif: '도토리 모자에 큰 꼬리를 가진 다람쥐',
    color: '#e8a868', w: 14, h: 11, shape: 'bun',
    back(s, g, c) {
      s.ellipse(g.R + 2.5, g.bot - 5, 3.2, 5.5, rgb('#c9884c'));
      s.ellipse(g.R + 2, g.bot - 5, 1.4, 3.5, rgb('#f0c898'));
      s.tri(CX - 6, g.top + 3, CX - 6, g.top - 2, CX - 3, g.top + 1, c.base);
      s.tri(mc(CX - 6), g.top + 3, mc(CX - 6), g.top - 2, mc(CX - 3), g.top + 1, c.base);
    },
    under(s, g) {
      const cap = rgb('#8a5a3a');
      for (let y = g.top; y <= g.top + 1; y++) for (let x = 0; x < CW; x++) if (g.inBody(x, y)) s.set(x, y, cap);
      s.set(CX, g.top - 1, G_D);
    },
  },
  {
    id: 'saseum', name: '새싹사슴', element: 'grass', animal: '사슴', motif: '가지 뿔 끝에 잎이 난 아기 사슴',
    color: '#e6b47e', w: 14, h: 12, shape: 'bun',
    back(s, g, c) {
      const br = rgb('#8a5a3a');
      pts(s, [[CX - 3, g.top + 1], [CX - 3, g.top], [CX - 4, g.top - 1], [CX - 4, g.top - 2], [CX - 5, g.top - 2], [CX - 6, g.top - 3], [CX - 4, g.top - 3]], br, true);
      pts(s, [[CX - 7, g.top - 4], [CX - 4, g.top - 4]], G_M, true);
      pts(s, [[CX - 6, g.top - 4]], G_L, true);
      s.tri(g.L + 1, g.top + 4, g.L - 3, g.top + 2, g.L + 1, g.top + 2, c.dk);
      s.tri(mc(g.L + 1), g.top + 4, mc(g.L - 3), g.top + 2, mc(g.L + 1), g.top + 2, c.dk);
    },
    front(s, g) { pts(s, [[CX - 3, g.top + 3], [CX - 1, g.top + 2]], rgb('#fff6e8'), true); },
  },
  {
    id: 'dalpaeng', name: '이끼달팽', element: 'grass', animal: '달팽이', motif: '이끼 낀 껍데기를 진 달팽이',
    color: '#cde8a8', w: 16, h: 9, shape: 'flat', eyeGap: 4,
    back(s, g, c) {
      const sh = rgb('#b08a60');
      s.ellipse(g.R - 1, g.top - 1, 5, 5, sh);
      pts(s, [[g.R - 1, g.top - 1], [g.R, g.top - 1], [g.R, g.top - 2], [g.R - 2, g.top - 2], [g.R - 2, g.top - 1], [g.R - 2, g.top], [g.R - 1, g.top + 1], [g.R + 1, g.top + 1], [g.R + 2, g.top]], darken(sh, 0.3));
      for (let x = g.R - 4; x <= g.R + 2; x++) s.set(x, g.top - 5 + (x & 1), G_M);
      pts(s, [[CX - 5, g.top - 1], [CX - 5, g.top - 2]], c.dk);
      s.set(CX - 5, g.top - 3, c.dk);
    },
  },
  {
    id: 'panda', name: '대나무판다', element: 'grass', animal: '판다', motif: '대나무 잎을 꽂은 판다',
    color: '#f7f5f0', w: 16, h: 12, shape: 'bun', eyeColor: '#ffffff',
    back(s, g) {
      const bk = rgb('#4a4252');
      s.ellipse(CX - 5.5, g.top + 1.5, 2.3, 2.3, bk);
      s.ellipse(mc(CX - 5.5), g.top + 1.5, 2.3, 2.3, bk);
    },
    under(s, g) {
      const bk = rgb('#4a4252');
      clipEllipse(s, g, g.ex + 0.5, g.ey + 1, 1.7, 2.1, bk);
      clipEllipse(s, g, mc(g.ex + 0.5), g.ey + 1, 1.7, 2.1, bk);
    },
    front(s, g) { pts(s, [[CX - 1, g.ey + 2]], NOSE, true); leaf(s, CX - 3, g.top, -1); leaf(s, CX - 2, g.top, 1); },
  },
  {
    id: 'kkotyang', name: '꽃양', element: 'grass', animal: '양', motif: '몽실한 털에 꽃이 핀 양',
    color: '#eef8e0', w: 16, h: 12, shape: 'round', mouth: null,
    back(s, g, c) {
      const cy = g.top + g.h / 2;
      const wool = darken(c.base, 0.06);
      for (let i = 0; i < 9; i++) {
        const a = Math.PI * 0.85 + (i / 8) * Math.PI * 1.3;
        s.ellipse(CX + Math.cos(a) * (g.w / 2 + 0.3), cy + Math.sin(a) * (g.h / 2 + 0.3), 2.2, 2.2, wool);
      }
      pts(s, [[g.L - 1, g.ey + 1], [g.L - 2, g.ey + 2], [g.L - 1, g.ey + 3]], rgb('#c9a06a'), true);
    },
    under(s, g) { clipEllipse(s, g, CX, g.ey + 1.5, 4.4, 3.6, rgb('#f7dcc0')); },
    front(s, g) {
      pts(s, [[CX - 1, g.ey + 3]], NOSE, true);
      const P = rgb('#ff8fb8');
      pts(s, [[CX + 3, g.top], [CX + 2, g.top + 1], [CX + 4, g.top + 1], [CX + 3, g.top + 2]], P);
      s.set(CX + 3, g.top + 1, F_Y);
    },
  },
  {
    id: 'ipkoala', name: '잎코알라', element: 'grass', animal: '코알라', motif: '큰 코와 복슬 귀, 머리에 유칼립투스 잎',
    color: '#b8bccc', w: 16, h: 12, shape: 'bun', mouth: null,
    back(s, g, c) {
      s.ellipse(g.L + 1.5, g.top + 3, 3, 3, c.base);
      s.ellipse(mc(g.L + 1.5), g.top + 3, 3, 3, c.base);
      s.ellipse(g.L + 1.5, g.top + 3, 1.6, 1.6, rgb('#f4f4f8'));
      s.ellipse(mc(g.L + 1.5), g.top + 3, 1.6, 1.6, rgb('#f4f4f8'));
    },
    under(s, g) { clipEllipse(s, g, CX, g.bot - 1, 4, 2, rgb('#eceef4')); },
    front(s, g) {
      const n = rgb('#4a4252');
      s.rect(CX - 2, g.ey + 1, 4, 3, n);
      s.set(CX - 2, g.ey + 1, rgb('#6a6272'));
      leaf(s, CX - 1, g.top, -1);
      leaf(s, CX, g.top, 1);
    },
  },
  {
    id: 'ipneoguri', name: '잎너구리', element: 'grass', animal: '너구리', motif: '눈가 검은 띠와 머리 위 나뭇잎',
    color: '#b3a392', w: 16, h: 11, shape: 'bun', mouth: null, eyeColor: '#ffffff',
    back(s, g, c) {
      s.tri(g.L + 1, g.top + 3, g.L + 2, g.top - 2, g.L + 5, g.top + 1, c.dk);
      s.tri(mc(g.L + 1), g.top + 3, mc(g.L + 2), g.top - 2, mc(g.L + 5), g.top + 1, c.dk);
    },
    under(s, g) {
      const m = rgb('#5a4a52');
      for (let y = g.ey - 1; y <= g.ey + 2; y++) for (let x = g.ex - 2; x <= g.ex + 1; x++) if (g.inBody(x, y)) pts(s, [[x, y]], m, true);
      clipEllipse(s, g, CX, g.bot - 1.5, 3.6, 2.4, rgb('#f4ece2'));
    },
    front(s, g) { pts(s, [[CX - 1, g.bot - 3]], NOSE, true); leaf(s, CX - 1, g.top, 1); },
  },
  {
    id: 'ipkapi', name: '풀카피바라', element: 'grass', animal: '카피바라', motif: '느긋한 얼굴에 귤과 잎',
    color: '#c49a6a', w: 18, h: 12, shape: 'flat', mouth: null, eyeGap: 4,
    back(s, g, c) { pts(s, [[g.L + 2, g.top], [g.L + 3, g.top]], c.dk, true); },
    under(s, g) { clipEllipse(s, g, CX, g.bot - 2, 4, 2.4, rgb('#8a6448')); },
    front(s, g) {
      s.ellipse(CX, g.top - 1.5, 2.6, 2.2, rgb('#ffa03c'));
      s.set(CX - 1, g.top - 3, rgb('#ffd08a'));
      leaf(s, CX, g.top - 3, 1);
    },
  },
  {
    id: 'pulsong', name: '풀송아지', element: 'grass', animal: '송아지', motif: '얼룩 무늬와 분홍 코, 머리 위 클로버',
    color: '#ffffff', w: 16, h: 11, shape: 'bun', mouth: null,
    back(s, g) {
      pts(s, [[g.L + 3, g.top - 1], [g.L + 3, g.top]], rgb('#f0d8a8'), true);
      pts(s, [[g.L - 1, g.ey], [g.L - 2, g.ey], [g.L - 1, g.ey + 1]], rgb('#e8dcd0'), true);
    },
    under(s, g) {
      const sp = rgb('#5a4a5a');
      clipEllipse(s, g, g.L + 3, g.top + 1.5, 2.4, 1.8, sp);
      clipEllipse(s, g, mc(g.L + 5), g.top + 1, 2, 1.4, sp);
      clipEllipse(s, g, CX, g.bot - 1.5, 4.6, 2.4, rgb('#ffc0cc'));
      pts(s, [[CX - 2, g.bot - 2]], rgb('#d0808c'), true);
    },
    front(s, g) {
      pts(s, [[CX, g.top - 3], [CX - 1, g.top - 2], [CX + 1, g.top - 2], [CX, g.top - 1]], G_M);
      s.set(CX, g.top - 2, G_D);
    },
  },
  {
    id: 'pulneulbo', name: '풀늘보', element: 'grass', animal: '나무늘보', motif: '졸린 눈가 줄무늬와 머리 위 이끼',
    color: '#c8b090', w: 16, h: 11, shape: 'bun',
    under(s, g) {
      clipEllipse(s, g, CX, g.ey + 1.5, 6, 4, rgb('#f2e4cc'));
      pts(s, [[g.ex, g.ey - 1], [g.ex - 1, g.ey], [g.ex - 1, g.ey + 1], [g.ex - 2, g.ey + 2]], rgb('#8a6a58'), true);
      for (let x = 0; x < 32; x++) if (g.inBody(x, g.top)) s.set(x, g.top, (x & 1) ? G_M : G_L);
    },
    front(s, g) { leaf(s, CX + 2, g.top, 1); },
  },
  // exam.png에서 고른 5종. 기존 31종의 행 번호는 유지한다.
  {
    id: 'norok', name: '노록', element: 'water', animal: '별 촉각 짐승', motif: '밤하늘을 담은 몸과 별 촉각',
    color: '#55517d', w: 17, h: 11, shape: 'round', eyeColor: '#ffe59a', mouth: 'dot', blush: false,
    back(s, g, c) {
      // 둥근 양쪽 귀와 끝에 빛이 달린 두 촉각.
      s.ellipse(g.L, g.ey + 1, 3, 3, c.dk);
      s.ellipse(g.R + 1, g.ey + 1, 3, 3, c.dk);
      pts(s, [[g.L - 1, g.ey], [g.L - 2, g.ey + 1]], rgb('#7974a8'), true);
      s.line(CX - 4, g.top, CX - 5, g.top - 5, rgb('#877fbb'));
      s.line(CX + 3, g.top, CX + 4, g.top - 5, rgb('#877fbb'));
      pts(s, [[CX - 5, g.top - 5]], rgb('#c3b9f3'), true);
    },
    under(s, g) {
      pts(s, [[g.L + 3, g.ey - 2], [g.L + 5, g.top + 2]], rgb('#918bc4'), true);
    },
    front(s, g) {
      const gold = rgb('#ffe4a0');
      pts(s, [[CX - 1, g.top - 7], [CX - 2, g.top - 6], [CX - 3, g.top - 4],
        [CX - 2, g.top - 3], [CX - 1, g.top - 2]], gold, true);
      pts(s, [[CX - 1, g.top - 4]], WHITE, true);
    },
  },
  {
    id: 'dalko', name: '달코', element: 'grass', animal: '버섯 짐승', motif: '살구색 버섯포자를 품은 크림빛 몸',
    color: '#ffe5b7', w: 17, h: 11, shape: 'bun', mouth: 'dot',
    back(s, g) {
      // 커다란 주황 버섯 갓과 양옆의 작은 포자 귀.
      s.ellipse(CX, g.top - 2, 10, 4, rgb('#e8925d'));
      s.ellipse(CX, g.top - 3, 8, 2, rgb('#ffc283'));
      s.line(CX - 8, g.top, CX + 7, g.top, rgb('#a76353'));
      pts(s, [[CX - 5, g.top - 4], [CX + 4, g.top - 5]], rgb('#ffe5ac'));
      s.ellipse(g.L - 1, g.ey + 1, 2, 3, rgb('#e58a5c'));
      s.ellipse(g.R + 2, g.ey + 1, 2, 3, rgb('#e58a5c'));
    },
    under(s, g) {
      clipEllipse(s, g, CX, g.ey + 2, 6, 3, rgb('#fff2cf'));
      pts(s, [[g.ex - 2, g.ey + 2]], rgb('#f6a28d'), true);
    },
    front(s, g) { pts(s, [[CX - 1, g.ey + 2]], rgb('#ac685d'), true); },
  },
  {
    id: 'rapi', name: '라피', element: 'grass', animal: '잎 등껍질 짐승', motif: '연두빛 잎과 수정이 돋는 등껍질',
    color: '#a9e1c7', w: 18, h: 12, shape: 'bun', mouth: 'dot',
    back(s, g) {
      const jade = rgb('#6bb995');
      const mint = rgb('#c8f3dc');
      // 뾰족한 잎 귀와 빛나는 수정이 등 위로 솟는다.
      s.tri(g.L + 1, g.top + 3, g.L - 1, g.top - 6, g.L + 5, g.top - 3, jade);
      s.tri(g.R - 1, g.top + 3, g.R + 1, g.top - 6, g.R - 5, g.top - 3, jade);
      pts(s, [[g.L + 1, g.top - 4], [g.L + 2, g.top - 3]], mint, true);
      s.tri(CX - 3, g.top + 1, CX, g.top - 6, CX + 3, g.top + 1, rgb('#e0ffe9'));
    },
    under(s, g) {
      clipEllipse(s, g, CX, g.top + 3, 8, 3, rgb('#77cba4'));
      clipEllipse(s, g, CX, g.ey + 2, 5, 4, rgb('#ddfae4'));
      pts(s, [[g.L + 2, g.ey], [g.L + 3, g.ey - 1]], rgb('#69b99b'), true);
    },
    front(s, g) { pts(s, [[CX - 1, g.ey + 2]], rgb('#568a78'), true); },
  },
  {
    id: 'amro', name: '암로', element: 'fire', animal: '불꽃 귀 짐승', motif: '어두운 몸 위에 피어오르는 푸른 불꽃 귀',
    color: '#4d4b75', w: 17, h: 11, shape: 'round', eyeColor: '#fff0a4', mouth: 'wide', blush: false,
    back(s, g) {
      const blue = rgb('#438ce1');
      const light = rgb('#8cecff');
      const pale = rgb('#c1fff5');
      // 좌우 불꽃은 붉은 불씨와 다른 차가운 실루엣.
      pts(s, [[g.L + 2, g.top + 1], [g.L + 1, g.top - 1], [g.L + 1, g.top - 3],
        [g.L + 2, g.top - 5], [g.L + 3, g.top - 7], [g.L + 4, g.top - 4],
        [g.L + 5, g.top - 2]], blue, true);
      pts(s, [[g.L + 2, g.top - 2], [g.L + 3, g.top - 3], [g.L + 3, g.top - 4],
        [g.L + 4, g.top - 2]], light, true);
      pts(s, [[g.L + 3, g.top - 2]], pale, true);
    },
    under(s, g) {
      clipEllipse(s, g, CX, g.ey + 2, 5, 3, rgb('#62668f'));
      pts(s, [[g.L + 2, g.ey + 3]], rgb('#768ddd'), true);
    },
    front(s, g) { pts(s, [[CX - 1, g.ey + 2]], rgb('#bcb8da'), true); },
  },
  {
    id: 'oreubi', name: '오르비', element: 'water', animal: '고리 짐승', motif: '푸른 몸 둘레의 고리로 중력을 조절',
    color: '#669dd0', w: 18, h: 11, shape: 'bun', eyeColor: '#d8f6ff', mouth: 'dot', blush: false,
    back(s, g) {
      const ring = rgb('#9ecff5');
      // 좌우로 튀어나오는 궤도와 머리 위의 작은 원형 안테나.
      s.ellipse(CX, g.ey + 3, 14, 5, ring);
      s.ellipse(CX, g.ey + 3, 11, 3, rgb('#426fa4'));
      s.line(CX, g.top, CX, g.top - 5, rgb('#8dcaf3'));
      s.ellipse(CX, g.top - 6, 3, 2, rgb('#a8daf7'));
      s.ellipse(CX, g.top - 6, 1, 1, rgb('#477cb9'));
    },
    under(s, g) {
      clipEllipse(s, g, CX, g.ey + 2, 6, 3, rgb('#8dc7e9'));
      pts(s, [[g.L + 3, g.top + 3]], rgb('#caecfa'), true);
    },
    front(s, g) {
      const ring = rgb('#b8e6fb');
      s.line(g.L - 4, g.bot - 4, g.L + 1, g.bot - 1, ring);
      s.line(g.R - 1, g.bot - 1, g.R + 4, g.bot - 4, ring);
      pts(s, [[CX - 1, g.ey + 2]], rgb('#315b89'), true);
    },
  },
];

export function speciesOf(id) {
  return SPECIES.find((s) => s.id === id);
}

export function drawCreature(spec, opt = {}) {
  const sp = speciesOf(spec.species);
  const base = rgb(sp.color);
  const c = { base, dk: darken(base, 0.25), lt: lighten(base, 0.5) };
  const g = makeBody(opt.squash ? sp.w + 2 : sp.w, opt.squash ? sp.h - 1 : sp.h, sp.shape);
  g.ey = g.bot - Math.round(sp.h * 0.42) - 1;
  g.ex = CX - 2 - (sp.eyeGap ?? Math.round(sp.w * 0.13));
  const s = new Sprite(CW, CH);
  sp.back?.(s, g, c, opt);
  paintBody(s, g, base);
  sp.under?.(s, g, c, opt);
  face(s, g, sp, opt);
  sp.front?.(s, g, c, opt);
  // 부분 외곽선: 닿은 색을 진보라 쪽으로 — 밝은 몸(판다·염소 등)일수록 더 어둡게(공용 규칙 js/pixelStyle.js)
  s.outline(null, (col) => outlineColor(col));
  if (!opt.hop) return s;
  const out = new Sprite(CW, CH);
  out.paste(s, 0, opt.hop);
  return out;
}

function withShadow(spr, lift = 0) {
  const s = new Sprite(CW, CH);
  s.ellipse(CX, BOT + 2, lift ? 5 : 7, 1.2, rgb('#5a4a6a', 55));
  s.paste(spr, 0, 0);
  return s;
}

export function idleFrames(spec) {
  return [
    withShadow(drawCreature(spec, {})),
    withShadow(drawCreature(spec, { squash: true })),
    withShadow(drawCreature(spec, {})),
    withShadow(drawCreature(spec, { blink: true })),
  ];
}

// 걷기 = 통통 뛰기(만두는 발이 없다)
export function walkFrames(spec) {
  return [
    withShadow(drawCreature(spec, { squash: true })),
    withShadow(drawCreature(spec, { hop: -1 }), 1),
    withShadow(drawCreature(spec, { hop: -2 }), 1),
    withShadow(drawCreature(spec, { hop: -1 }), 1),
  ];
}

// 도감: 종마다 딱 한 마리
export function buildDex() {
  return SPECIES.map((sp, i) => ({ no: i + 1, species: sp.id, element: sp.element, name: sp.name }));
}
