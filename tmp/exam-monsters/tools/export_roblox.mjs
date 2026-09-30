// 공방 프로젝트(맵 탭 → "프로젝트 저장"으로 받은 JSON)를 로블록스(SpriteDemo)용으로 내보낸다.
//   node tools/export_roblox.mjs <monster_project.json>
//   (파일을 안 주면 기본 프로젝트 = 자동 생성 마을 한 씬)
// 크기·충돌·스폰 규칙은 공방 편집기와 같은 js/world.js를 그대로 쓴다 — 공방에서 본 그대로 들어간다.
// 결과:
//   SpriteDemo/assets/bunvillage/ground_<씬id>.png — 씬마다 바닥 한 장(오브젝트 그림자 포함)
//   SpriteDemo/assets/bunvillage/objects.png / monsters.png / player.png / npcs.png — 공용 시트
//   SpriteDemo/src/shared/data/townWorld.generated.luau — 씬 전부의 데이터(충돌 격자, 오브젝트, 스폰 구역, 포탈, 시작 위치)
// 이미지를 업로드한 뒤 tools/write_asset_ids.mjs로 에셋 id 파일을 만든다.
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { Sprite } from '../js/pixel.js';
import { T, GROUND, OBJECTS, objectSprite } from '../js/tiles.js';
import { buildDex, idleFrames, walkFrames, SPECIES, CW, CH } from '../js/buns.js';
import { heroFrames, HERO_W, HERO_H, DIRS as HERO_DIRS, WALK_FRAMES, ATTACK_FRAMES, ATTACK_HIT_FRAME } from '../js/hero.js';
import { NPCS, npcFrames, NPC_W, NPC_H, NPC_FRAMES } from '../js/npc.js';
import { renderGround } from '../js/render.js';
import {
  SCALE, MONSTER_SCALE, CHAR_SCALE, FINE, MONSTER_ROAM, MONSTER_WAIT, NPC_FEET, npcFeet, PLAYER_FEET, MONSTER_FEET, PLAYER_SPEED, MONSTER_SPEED,
  objScale, shrink, objectPlacement, buildGrid, villageMap, newId, deserializeProject,
} from '../js/world.js';
import { savePng } from './png.mjs';

const ROOT = 'C:/YJS/Roblox/sprite-gen/SpriteDemo';
const OUT = `${ROOT}/assets/bunvillage`;
mkdirSync(OUT, { recursive: true });

const dex = buildDex();
let project;
if (process.argv[2]) {
  project = deserializeProject(JSON.parse(readFileSync(process.argv[2], 'utf8')), dex);
} else {
  const s = { id: 'village', name: '마을', map: villageMap(7, dex) };
  project = { scenes: [s], start: s.id };
}
// 로블록스 테이블 키로 쓰기 좋게 씬 id를 영숫자로 맞춘다.
const keyOf = new Map(project.scenes.map((s, i) => [s.id, /^[A-Za-z][A-Za-z0-9]*$/.test(s.id) ? s.id : `scene${i + 1}`]));

// 1) 공용 시트: 오브젝트 아틀라스(높이순 선반 채우기)
const ids = Object.keys(OBJECTS);
const sprites = ids.map((id) => [id, objectSprite(id)]).sort((a, b) => b[1].h - a[1].h);
const ATLAS_W = 512;
const rects = {};
let ax = 0, ay = 0, shelfH = 0;
for (const [id, s] of sprites) {
  if (ax + s.w > ATLAS_W) { ax = 0; ay += shelfH + 1; shelfH = 0; }
  rects[id] = { x: ax, y: ay, w: s.w, h: s.h };
  ax += s.w + 1;
  shelfH = Math.max(shelfH, s.h);
}
const atlas = new Sprite(ATLAS_W, ay + shelfH);
for (const [id, s] of sprites) atlas.paste(s, rects[id].x, rects[id].y);
savePng(atlas, `${OUT}/objects.png`);

// 몬스터 시트: 한 줄에 두 종, 종마다 가로 16칸(대기R4 걷기R4 대기L4 걷기L4).
// 36종을 세로 한 줄씩 쌓으면 1080px이 되어 Roblox 이미지 1024px 한계를 넘는다.
const MCOLS = 16;
const SPECIES_PER_ROW = 2;
const mons = new Sprite(CW * MCOLS * SPECIES_PER_ROW, CH * Math.ceil(SPECIES.length / SPECIES_PER_ROW));
if (mons.w > 1024 || mons.h > 1024) throw new Error(`몬스터 시트가 Roblox 1024px 한계를 넘습니다: ${mons.w}x${mons.h}`);
dex.forEach((d, i) => {
  const idle = idleFrames(d), walk = walkFrames(d);
  const x = (i % SPECIES_PER_ROW) * MCOLS * CW;
  const y = Math.floor(i / SPECIES_PER_ROW) * CH;
  [...idle, ...walk, ...idle.map((f) => f.flipX()), ...walk.map((f) => f.flipX())].forEach((f, c) => mons.paste(f, x + c * CW, y));
});
savePng(mons, `${OUT}/monsters.png`);

// 플레이어 시트(새 캐릭터 hero.js, 기본 외형): 줄 = 아래·위·왼·오, 칸 = 걷기 4 + 공격 4 (32x32)
// 캐릭터 선택이 생기기 전까지는 이 기본 외형 하나를 쓴다.
const HERO_LOOK = { gender: 'male', style: 'short', hair: '#4a3348', cloth: '#8fb6f0' };
const hf = heroFrames(HERO_LOOK);
const player = new Sprite(HERO_W * (WALK_FRAMES + ATTACK_FRAMES), HERO_H * 4);
HERO_DIRS.forEach((dir, r) => [...hf.walk[dir], ...hf.attack[dir]].forEach((f, c) => player.paste(f, c * HERO_W, r * HERO_H)));
savePng(player, `${OUT}/player.png`);

// NPC 시트(js/npc.js): 역할마다 한 줄, 칸 = 대기 NPC_FRAMES장 (32x32, 발바닥 = 칸 위에서 30도트)
const npcSheet = new Sprite(NPC_W * NPC_FRAMES, NPC_H * NPCS.length);
NPCS.forEach((n, r) => npcFrames(n.id).forEach((f, c) => npcSheet.paste(f, c * NPC_W, r * NPC_H)));
savePng(npcSheet, `${OUT}/npcs.png`);
const npcRow = new Map(NPCS.map((n, i) => [n.id, i + 1]));

// 2) 씬마다
const speciesRow = new Map(SPECIES.map((s, i) => [s.id, i + 1]));
const scenes = {};
const grounds = [];
for (const sc of project.scenes) {
  const key = keyOf.get(sc.id);
  const m = sc.map;
  if (m.w * T > 1024 || m.h * T > 1024) throw new Error(`${sc.name}: 로블록스 이미지 한계(1024) 때문에 64칸을 넘을 수 없습니다`);
  const ground = renderGround(m, 0, { shadowScale: shrink });
  const file = `ground_${key}.png`;
  savePng(ground, `${OUT}/${file}`);
  grounds.push({ key, file, name: sc.name });
  const grid = buildGrid(m);
  const blocked = [];
  for (let gy = 0; gy < grid.FH; gy++) {
    let row = '';
    for (let gx = 0; gx < grid.FW; gx++) row += grid.cells[gy * grid.FW + gx] ? '1' : '0';
    blocked.push(row);
  }
  const objects = [];
  for (const o of m.objects) {
    const p = objectPlacement(o);
    if (!p || !rects[o.id]) continue; // PNG로 가져온 임시 오브젝트는 아틀라스에 없어서 건너뛴다
    objects.push({ id: o.id, x: p.left, y: p.bottom - p.spr.h, bottom: p.bottom, scale: objScale(o.id) });
  }
  scenes[key] = {
    name: sc.name,
    w: m.w, h: m.h,
    ground: { w: ground.w, h: ground.h },
    // 실내 씬(실내 바닥·벽 타일을 쓴 씬)은 맵 바깥을 벽 윗면 색으로 채운다(마을은 잔디색)
    indoor: m.ground.some((row) => row.some((g) => GROUND[g.id]?.indoor)),
    spawn: m.spawn ? { x: m.spawn.x * T + T / 2, y: m.spawn.y * T + T - 2 } : null,
    blocked,
    objects,
    zones: m.zones.map((z) => ({
      name: z.name, count: z.count,
      x0: z.x0 * T, y0: z.y0 * T, x1: z.x1 * T, y1: z.y1 * T,
      species: z.species.map((id) => speciesRow.get(id)).filter(Boolean),
    })),
    portals: m.portals.map((p) => ({ name: p.name, x0: p.x * T, y0: p.y * T, x1: (p.x + (p.w ?? 1)) * T, y1: (p.y + (p.h ?? 1)) * T, to: p.to ? keyOf.get(p.to) ?? null : null, arrive: p.arrive ?? null })),
    mons: m.mons.map((d) => ({ species: speciesRow.get(dex[d.dex].species), x: Math.round(d.x * T), y: Math.round(d.y * T) })),
    npcs: m.npcs.filter((n) => npcRow.has(n.type)).map((n) => ({ type: n.type, row: npcRow.get(n.type), name: n.name, ...npcFeet(n) })),
  };
}

// 3) 루아 데이터
const lua = (v, ind = '') => {
  if (v === null || v === undefined) return 'nil';
  if (Array.isArray(v)) return v.length ? `{\n${v.map((e) => `${ind}\t${lua(e, ind + '\t')},`).join('\n')}\n${ind}}` : '{}';
  if (typeof v === 'object') {
    const ent = Object.entries(v).filter(([, e]) => e !== null && e !== undefined);
    return `{ ${ent.map(([k, e]) => `${/^[A-Za-z_]\w*$/.test(k) ? k : `[${JSON.stringify(k)}]`} = ${lua(e, ind)}`).join(', ')} }`;
  }
  if (typeof v === 'string') return JSON.stringify(v);
  return String(v);
};
const sceneLua = Object.entries(scenes).map(([key, s]) => `\t\t${key} = {
\t\t\tname = ${lua(s.name)}, w = ${s.w}, h = ${s.h}, indoor = ${s.indoor},
\t\t\tground = ${lua(s.ground)},
\t\t\tspawn = ${lua(s.spawn)},
\t\t\tblocked = ${lua(s.blocked, '\t\t\t')},
\t\t\tobjects = ${lua(s.objects, '\t\t\t')},
\t\t\tzones = ${lua(s.zones, '\t\t\t')},
\t\t\tportals = ${lua(s.portals, '\t\t\t')},
\t\t\tmons = ${lua(s.mons, '\t\t\t')},
\t\t\tnpcs = ${lua(s.npcs, '\t\t\t')},
\t\t},`).join('\n');

const out = `-- 자동 생성 파일 — 직접 고치지 말 것.
-- 만든 곳: C:/YJS/Roblox/dino-workshop/tools/export_roblox.mjs (공방 프로젝트 → 로블록스)
-- 좌표 단위는 "도트"(바닥 타일 1칸 = ${T}도트). 화면에서는 바닥 1도트 = scale px.
-- 크기·충돌·속도 규칙은 공방 js/world.js와 같다(공방에서 본 그대로).
return {
	tile = ${T},
	scale = ${SCALE}, -- 바닥 1도트 = 화면 px
	monsterScale = ${MONSTER_SCALE},
	charScale = ${CHAR_SCALE},
	fine = ${FINE}, -- 충돌 격자 한 칸 = fine x fine 도트
	playerFeet = ${lua(PLAYER_FEET)},
	monsterFeet = ${lua(MONSTER_FEET)},
	playerSpeed = ${PLAYER_SPEED},
	monsterSpeed = ${MONSTER_SPEED},
	monsterRoam = ${MONSTER_ROAM}, -- 나타난 자리에서 이 반경(도트) 안을 자유롭게 돌아다닌다(스폰 구역 밖도 됨)
	monsterWait = ${lua(MONSTER_WAIT)}, -- 한 번 걸은 뒤 쉬는 시간(초) 범위
	objectAtlas = { w = ${ATLAS_W}, h = ${atlas.h} },
	monsterSheet = { cellW = ${CW}, cellH = ${CH}, cols = ${MCOLS}, speciesPerRow = ${SPECIES_PER_ROW} },
	-- 플레이어: 줄 = 아래·위·왼·오, 칸 = 걷기 walk장 + 공격 attack장. 발바닥 = 칸 위에서 feetY 도트. 공격 판정은 hitFrame번째 장.
	playerSheet = { cellW = ${HERO_W}, cellH = ${HERO_H}, walk = ${WALK_FRAMES}, attack = ${ATTACK_FRAMES}, hitFrame = ${ATTACK_HIT_FRAME}, feetY = 30 },
	-- NPC: 역할마다 한 줄(row), 칸 = 대기 frames장. 씬의 npcs = { type, row, name, x, y(발 위치 도트) }.
	npcSheet = { cellW = ${NPC_W}, cellH = ${NPC_H}, frames = ${NPC_FRAMES}, feetY = 30 },
	npcFeet = ${lua(NPC_FEET)},
	npcTypes = ${lua(NPCS.map((n) => ({ id: n.id, name: n.name, role: n.role })), '\t')},
	rects = {
${Object.entries(rects).map(([id, r]) => `\t\t${id} = ${lua(r)},`).join('\n')}
	},
	species = ${lua(SPECIES.map((s) => ({ id: s.id, name: s.name, element: s.element })), '\t')},
	start = ${lua(keyOf.get(project.start) ?? Object.keys(scenes)[0])},
	-- 씬: blocked는 충돌 격자(1 = 못 지나감), objects는 원래 크기 기준 위치 + 그리기 배율(scale),
	-- zones는 몬스터 스폰 구역(도트 사각형, species는 시트 줄 번호 — 비면 전체), portals.to는 도착 씬 키.
	scenes = {
${sceneLua}
	},
}
`;
writeFileSync(`${ROOT}/src/shared/data/townWorld.generated.luau`, out);
writeFileSync(`${OUT}/grounds.json`, JSON.stringify(grounds, null, 2));
console.log('scenes', grounds.map((g) => `${g.key}(${g.name})`).join(', '), '| start', keyOf.get(project.start));
console.log('files', ['objects.png', 'monsters.png', 'player.png', 'npcs.png', ...grounds.map((g) => g.file)].join(', '));

// 도트 품질 검사(js/pixelQA.js) — 요약만 남기고 보내기는 막지 않는다. 자세히: previews/qa_report.html
try {
  const { runQA, summarize, writeReport } = await import('./qa_pixels.mjs');
  const sum = summarize(runQA());
  writeReport(sum);
  console.log(`도트 품질 검사: ${sum.total}개 · 꼭 고침 ${sum.hard} · 살펴보기 ${sum.soft} (previews/qa_report.html에서 자세히)`);
} catch (e) {
  console.log('도트 품질 검사를 건너뜀:', e.message);
}
