-- 유파 · 전직 · 인술(「오문 닌자전」 NINJA_DESIGN.md §0-1 · §4) — 수치는 전부 여기서 고친다. 클라이언트·서버 공용.
--  전직(메이플식, 사용자 지시 2026-10-03): Lv.1~9는 견습 닌자(유파 없음). 1차 전직(Lv.10) 때 유파를 고르고, 2차 30 · 3차 60 · 4차 100.
--   전직은 마을 스승 곁에서. 전직 단계(Job 0~4)마다 그 유파의 인술 칸이 하나씩 열린다 — skills[n] = n차 전직에 배우는 인술.
--   유파를 바꾸려면 스승 곁에서 엽전 CHANGE_COST(전직 단계는 그대로).
--  기력: 인술에 쓰는 자원. 초당 ENERGY_REGEN씩 차고, 기본 공격이 맞을 때마다 ENERGY_PER_HIT.
--  스킬 레벨 · SP · 단축칸은 아래 「스킬 나무」 절. (MAX_LEVEL · LEVEL_BONUS · LevelScale은 옛 두루마리 단계 — 더는 쓰지 않는다)
-- 거리 단위는 "도트"(바닥 타일 1칸 = 16도트). 피해 = 내 공격력 × power × 단계 보정.
--
-- 인술 종류(kind):
--  projectile — 바라보는 방향 직선으로 날아가(range · speed · width) 처음 닿은 몬스터에서 터짐(radius 안 모두)
--  line       — 바라보는 방향 앞 긴 사각형(length × width*2) 안 모두(꿰뚫음), delay초 뒤
--  circle     — 쓴 자리 둘레 radius 안 모두, delay초 뒤. hits · interval이 있으면 여러 번
--  chain      — range 안 가장 가까운 몬스터 → jumpRange 안 다음 몬스터로 jumps번 옮겨 감(옮길 때마다 피해 × falloff)
--  heal       — 내 체력을 최대 체력의 ratio만큼 회복(vigorCost가 있으면 기력 대신 생기를 쓴다)
--  seed       — 투사체처럼 날아가 처음 닿은 몬스터에 박히고(power), fuse초 뒤 그 자리 둘레 radius에 터진다(burstPower)
--  guard      — seconds초 동안 받는 피해 × mult
-- 연출(fx — 이름은 shared/data/ninjaFx.generated.luau의 팩 이펙트, 클라 town/ninjutsuFx.luau · 공방 「닌자 맵」 탭이 읽는다):
--  shot = 날아가는 그림 · burst = 도착(가운데) 자리에서 한 번 · ring = 둘레에 ringCount개 · row = 앞으로 한 줄에 rowCount개
--  self = 쓴 사람 몸(loop면 지속 시간 동안 되풀이) · hit = 맞은 몬스터 몸 위
-- 덧붙는 효과: ember(불씨 중첩 — f_ember를 배웠을 때) · frost(서리 중첩 — i_frost를 배웠을 때) · selfHeal(쓴 사람 체력을 최대 체력의 그 비율만큼 회복) · burn(ticks번 · interval초마다 공격력 × power) · slow(mult배 속도로 seconds초) · stun(seconds초 멈춤) · push(도트만큼 밀림)
local exports = {}

exports.ENERGY_MAX = 100
exports.ENERGY_REGEN = 6
exports.ENERGY_PER_HIT = 4
exports.JOB_LEVELS = { 10, 30, 60, 100 } -- n차 전직을 할 수 있는 레벨(= n번 인술 칸이 열리는 전직)
exports.JOB_NAMES = { [0] = "견습", "하닌", "중닌", "상닌", "닌자 마스터" } -- 전직 단계별 계급 이름
exports.MAX_LEVEL = 5
exports.LEVEL_BONUS = 0.15
exports.CHANGE_COST = 1000
exports.CHANGE_NPC = "elder" -- 유파를 바꿔 주는 NPC 역할(스승)
exports.HAND_Y = 7 -- 손 높이(발에서 위로, 도트) — 투사체·직선 인술이 나가는 자리
exports.BODY_Y = 6 -- 몬스터 몸 가운데(발에서 위로, 도트)
-- 대쉬(이동기, 사용자 지시 2026-10-03): 견습은 "구르기", 1차 전직부터 유파의 대쉬(같은 키 — Shift · 화면 버튼).
--  순수 이동기다 — 피해도, 적을 멈추거나 느리게 하거나 밀치는 효과도 없다(사용자 지시). 길에 남는 그림은 보이기만 한다.
--  유파마다 무게가 다르다 — 불 · 번개는 빠르게, 얼음은 중간, 풀 · 바위는 무겁게(준비 동작 windup이 있고 느리다).
--  windup초 멈췄다가 time초 동안 바라보는 쪽으로 distance도트(벽에 막히면 거기까지). cost = 기력.
--  fx: start(떠난 자리) · path(길을 따라 pathStep도트마다. pathHold = 머무는 장에서 머무는 초, pathLoop = 그 초 동안 되풀이) · finish(닿은 자리)
exports.DASH = {
	novice = { name = "구르기", feel = "견습", windup = 0, distance = 36, time = 0.22, cooldown = 3, cost = 0,
		fx = { start = "smoke" },
		desc = "바라보는 쪽으로 짧게 구른다." },
	fire = { name = "불길 걸음", feel = "빠름", windup = 0, distance = 64, time = 0.16, cooldown = 3, cost = 8,
		fx = { start = "smoke", path = "flam", pathStep = 11, pathLoop = 0.6 },
		desc = "불꽃처럼 내달린다. 지나간 자리에 불길이 잠깐 인다." },
	thunder = { name = "번쩍", feel = "가장 빠름", windup = 0, distance = 72, time = 0.06, cooldown = 2.5, cost = 8,
		fx = { start = "spark", path = "boltLine", pathStep = 16, finish = "spark" },
		desc = "눈 깜짝할 사이에 옮겨 간다. 지나간 길에 번개 줄기가 남는다." },
	ice = { name = "얼음 길", feel = "중간", windup = 0.05, distance = 56, time = 0.28, cooldown = 4, cost = 8,
		fx = { start = "iceFlake", path = "iceFloor", pathStep = 12, pathHold = 0.7 },
		desc = "얼음 길을 깔며 미끄러진다." },
	plant = { name = "덩굴 도약", feel = "무거움", windup = 0.18, distance = 48, time = 0.34, cooldown = 5, cost = 8,
		fx = { path = "vine", pathStep = 16, pathHold = 0.5, finish = "plant" },
		desc = "덩굴이 몸을 감았다가 앞으로 튕겨 낸다." },
	rock = { name = "돌진", feel = "가장 무거움", windup = 0.22, distance = 48, time = 0.42, cooldown = 6, cost = 8,
		fx = { start = "smoke", path = "rockBits", pathStep = 12, finish = "dustRing" },
		desc = "몸을 낮췄다가 묵직하게 내달린다." },
}
exports.DASH_KEY = "LeftShift"

exports.BURN_FX = "flam" -- 불붙어 타는 동안 맞은 몬스터 위(피격 출처 "nin:burn")

-- 유파 순서 = 캐릭터 시트 줄 순서(townWorld.generated schools와 같아야 한다 — 테스트가 확인)
exports.SCHOOLS = { "fire", "ice", "plant", "rock", "thunder" }

exports.SCHOOL_INFO = {
	fire = { name = "불", title = "화문", color = { 228, 109, 58 }, desc = "한 방이 센 유파. 불씨가 남아 계속 태운다.", skills = { "fire_ball", "fire_burst", "fire_rain", "fire_dragon" } },
	ice = { name = "얼음", title = "빙문", color = { 99, 171, 214 }, desc = "적을 느리게 하고 얼려 세운다.", skills = { "ice_spike", "ice_freeze", "ice_lance", "ice_storm" } },
	plant = { name = "풀", title = "초문", color = { 122, 168, 62 }, desc = "덩굴로 묶고 잎으로 상처를 낫게 한다.", skills = { "plant_bind", "plant_heal", "plant_thorn", "plant_bloom" } },
	rock = { name = "바위", title = "암문", color = { 168, 122, 84 }, desc = "적을 밀쳐 내고 바위로 몸을 지킨다.", skills = { "rock_spike", "rock_guard", "rock_quake", "rock_meteor" } },
	thunder = { name = "번개", title = "뇌문", color = { 240, 200, 72 }, desc = "빠르고, 번개가 옆 적에게 튄다.", skills = { "thunder_bolt", "thunder_storm", "thunder_chain", "thunder_judge" } },
}

exports.SKILLS = {
	-- ===== 불 =====
	fire_ball = {
		name = "화염구", school = "fire", kind = "projectile", cost = 30, cooldown = 4,
		range = 112, speed = 200, width = 7, radius = 20, power = 2.2,
		ember = 1,
		fx = { shot = "fireball", burst = "explosion", hit = "flam" },
		desc = "불덩이를 던진다. 닿은 자리에서 터지며 불씨를 붙인다.",
	},
	fire_burst = {
		name = "불꽃 폭발", school = "fire", kind = "circle", cost = 45, cooldown = 9,
		radius = 36, power = 2.6, delay = 0.25,
		ember = 1,
		fx = { ring = "flam", ringCount = 6, burst = "explosion", hit = "flam" },
		desc = "내 둘레를 불태운다.",
	},
	-- ===== 얼음 =====
	ice_spike = {
		name = "얼음 가시", school = "ice", kind = "line", cost = 28, cooldown = 4,
		length = 88, width = 9, power = 1.7, delay = 0.2,
		frost = 1,
		fx = { shot = "iceSpike", hit = "iceB" },
		desc = "앞으로 얼음 가시를 쏜다. 꿰뚫고, 맞은 적에게 서리가 쌓인다.",
	},
	ice_freeze = {
		name = "빙결", school = "ice", kind = "circle", cost = 45, cooldown = 10,
		radius = 40, power = 1.4, delay = 0.25, stun = 2.5,
		fx = { ring = "ice", ringCount = 6, hit = "iceB" },
		desc = "내 둘레의 적을 얼려 세운다.",
	},
	-- ===== 풀 =====
	plant_bind = {
		name = "덩굴 묶기", school = "plant", kind = "circle", cost = 28, cooldown = 5,
		radius = 34, power = 1.5, delay = 0.2, stun = 2,
		fx = { ring = "plantB", ringCount = 5, hit = "plant" },
		desc = "덩굴이 내 둘레의 적을 묶는다.",
	},
	plant_heal = {
		name = "치유의 잎", school = "plant", kind = "heal", cost = 0, vigorCost = 30, cooldown = 6,
		ratio = 0.22,
		fx = { self = "boost" },
		desc = "생기 30을 써서 체력을 회복한다.",
	},
	-- ===== 바위 =====
	rock_spike = {
		name = "바위 주먹", school = "rock", kind = "line", cost = 26, cooldown = 3.5,
		length = 40, width = 14, power = 2.5, delay = 0.2, push = 22,
		fx = { row = "rockSpike", rowCount = 2 },
		desc = "앞을 크게 내리친다. 짧지만 세고, 맞은 적이 멀리 밀려난다.",
	},
	rock_guard = {
		name = "바위 갑옷", school = "rock", kind = "guard", cost = 35, cooldown = 14,
		mult = 0.5, seconds = 6,
		fx = { self = "shield", loop = true },
		desc = "6초 동안 받는 피해가 절반이 된다.",
	},
	-- ===== 번개 =====
	thunder_bolt = {
		name = "번개", school = "thunder", kind = "chain", cost = 26, cooldown = 3,
		range = 84, jumps = 2, jumpRange = 44, power = 1.7, falloff = 0.7,
		fx = { hit = "thunder" },
		desc = "가까운 적에게 번개가 떨어지고 옆 적 둘에게 옮겨 간다.",
	},
	thunder_storm = {
		name = "뇌우", school = "thunder", kind = "circle", cost = 45, cooldown = 10,
		radius = 44, power = 0.9, delay = 0.2, hits = 3, interval = 0.4,
		fx = { ring = "thunder", ringCount = 4, hit = "thunder" },
		desc = "내 둘레에 번개가 세 번 내리친다.",
	},
	-- ===== 3차 전직(Lv.60) =====
	fire_rain = {
		name = "불비", school = "fire", kind = "circle", cost = 55, cooldown = 14,
		radius = 48, power = 1.6, delay = 0.25, hits = 3, interval = 0.35,
		ember = 1,
		fx = { ring = "explosion", ringCount = 5, hit = "flam" },
		desc = "내 둘레에 불덩이가 세 번 쏟아진다.",
	},
	ice_lance = {
		name = "빙창", school = "ice", kind = "projectile", cost = 50, cooldown = 12,
		range = 140, speed = 260, width = 8, radius = 26, power = 3.2,
		frost = 2,
		fx = { shot = "iceSpike", burst = "ice", hit = "iceB" },
		desc = "얼음 창을 던진다. 닿은 자리 둘레가 얼어붙어 느려진다.",
	},
	plant_thorn = {
		name = "가시덤불", school = "plant", kind = "line", cost = 45, cooldown = 10,
		length = 80, width = 14, power = 2.6, delay = 0.2, stun = 1.5,
		fx = { row = "plant", rowCount = 3, hit = "plant" },
		desc = "앞으로 가시덤불이 뻗어 적을 꿰고 묶는다.",
	},
	rock_quake = {
		name = "지진", school = "rock", kind = "circle", cost = 50, cooldown = 12,
		radius = 44, power = 2.8, delay = 0.25, push = 18,
		fx = { ring = "rockSpike", ringCount = 5 },
		desc = "땅을 울려 둘레의 적을 멀리 밀쳐 낸다.",
	},
	thunder_chain = {
		name = "연쇄 번개", school = "thunder", kind = "chain", cost = 45, cooldown = 9,
		range = 96, jumps = 5, jumpRange = 52, power = 2.2, falloff = 0.85,
		fx = { hit = "thunder" },
		desc = "번개가 적 여섯에게 차례로 옮겨 간다.",
	},
	-- ===== 4차 전직(Lv.100) =====
	fire_dragon = {
		name = "화룡", school = "fire", kind = "line", cost = 80, cooldown = 24,
		length = 120, width = 16, power = 5, delay = 0.3,
		ember = 2,
		fx = { shot = "fireball", row = "explosion", rowCount = 4, hit = "flam" },
		desc = "불의 용이 앞을 길게 휩쓴다.",
	},
	ice_storm = {
		name = "눈보라", school = "ice", kind = "circle", cost = 80, cooldown = 26,
		radius = 56, power = 1.5, delay = 0.25, hits = 4, interval = 0.4, stun = 1.2,
		frost = 1,
		fx = { ring = "ice", ringCount = 8, hit = "iceB" },
		desc = "넓은 둘레에 눈보라가 네 번 몰아쳐 적을 얼린다.",
	},
	plant_bloom = {
		name = "만개", school = "plant", kind = "circle", cost = 80, cooldown = 26,
		radius = 50, power = 3.2, delay = 0.3, stun = 2, selfHeal = 0.25,
		fx = { ring = "plantB", ringCount = 8, hit = "plant" },
		desc = "꽃이 피어 둘레의 적을 묶고, 내 체력을 25% 회복한다.",
	},
	rock_meteor = {
		name = "낙석", school = "rock", kind = "projectile", cost = 85, cooldown = 26,
		range = 110, speed = 150, width = 10, radius = 40, power = 5.5, stun = 1.5,
		fx = { shot = "rockShot", burst = "explosion" },
		desc = "큰 바위를 던진다. 떨어진 자리 둘레가 무너진다.",
	},
	thunder_judge = {
		name = "천벌", school = "thunder", kind = "circle", cost = 85, cooldown = 26,
		radius = 60, power = 1.6, delay = 0.2, hits = 5, interval = 0.3, stun = 0.8,
		fx = { ring = "thunder", ringCount = 6, hit = "thunder" },
		desc = "넓은 둘레에 벼락이 다섯 번 내리친다.",
	},
}

-- ===== 스킬 나무(메이플식 1~4차 — 공방 설계 dino-workshop/js/ninja/design/skills.js를 옮기는 중) =====
--  지금: 1차 전직 스킬은 새 설계대로(주력기 · 핵심 장치 · 패시브/보조 + 공용 2개). 2~4차는 옛 인술이 자리를 지킨다(옮기는 대로 바뀐다).
--  스킬 포인트(SP): 레벨업마다 SP_PER_LEVEL, 전직할 때 SP_ON_JOB — 그 전직 구간에서 얻은 SP는 그 전직 스킬에만 쓴다.
--  스킬마다 마스터 레벨(max). 쓰는 인술은 레벨이 오를수록 피해 · 회복량이 는다(마스터에서 +GROW). 0레벨 = 아직 안 배움.
--  전직하면 그 전직의 주력기와 핵심 장치는 1레벨로 바로 배운다(auto). 배운 쓰는 인술은 단축칸 SLOTS개에 골라 넣는다.
--  두루마리(자기 유파): 지금 전직의 SP를 1 준다.
exports.SP_PER_LEVEL = 3
exports.SP_ON_JOB = 3
exports.GROW = 0.8
exports.SLOTS = 4

-- 1차 새 스킬 — 쓰는 인술
exports.SKILLS.p_seed = {
	name = "가시 씨앗", school = "plant", kind = "seed", cost = 24, cooldown = 3,
	range = 104, speed = 180, width = 7, power = 0.6, fuse = 2, radius = 24, burstPower = 2.0,
	fx = { shot = "plantSpike", hit = "plantB", burstHit = "plant" },
	desc = "씨앗을 쏜다. 맞은 적에게 박혀 있다가 2초 뒤 가시로 터진다.",
}
-- 1차 새 스킬 — 핵심 장치(core) · 패시브. kind = "passive"는 쓰는 인술이 아니다(단축칸에 못 넣는다).
--  핵심 장치는 서버 ninjutsuService가 돌린다: 불씨 · 서리 = 몬스터에 쌓임, 생기 · 견고 · 전하 = 내게 쌓임(CoreUpdated로 화면에 보임).
exports.SKILLS.f_ember = {
	name = "불씨", school = "fire", kind = "passive", core = true,
	stacks = 3, seconds = 6, interval = 1, power = 0.10, perLevel = 0.01,
	desc = "불 인술에 맞은 적에게 불씨가 쌓인다(최대 3). 하나마다 1초에 한 번 피해.",
}
exports.SKILLS.f_blade = {
	name = "달궈진 칼날", school = "fire", kind = "passive",
	every = 3, power = 0.2, perLevel = 0.03, ember = 1, fx = { hit = "flam" },
	desc = "기본 공격이 3번째로 맞을 때마다 불꽃이 튀어 추가 피해와 불씨 1.",
}
exports.SKILLS.i_frost = {
	name = "서리", school = "ice", kind = "passive", core = true,
	stacks = 5, seconds = 8, slowPer = 0.1, freeze = 2, perLevel = 0.1,
	desc = "얼음 인술에 맞은 적에게 서리가 쌓인다. 하나마다 느려지고, 5가 되면 얼어붙는다.",
}
exports.SKILLS.i_armor = {
	name = "얼음 갑옷", school = "ice", kind = "passive",
	perLevel = 0.01, frost = 1,
	desc = "받는 피해가 줄고, 나를 때린 적에게 서리 1.",
}
exports.SKILLS.p_vigor = {
	name = "생기", school = "plant", kind = "passive", core = true,
	stacks = 100, perHit = 6, perLevel = 0.4,
	desc = "풀 인술이 맞을 때마다 생기가 쌓인다(최대 100). 회복 인술은 생기를 쓴다.",
}
exports.SKILLS.r_firm = {
	name = "견고", school = "rock", kind = "passive", core = true,
	stacks = 5, seconds = 8, reduce = 0.04, perLevel = 0.002, guardGain = 2,
	desc = "맞을 때마다 견고가 쌓인다(최대 5). 하나마다 받는 피해가 줄어든다.",
}
exports.SKILLS.t_charge = {
	name = "전하", school = "thunder", kind = "passive", core = true,
	stacks = 10, seconds = 3, speedPer = 0.02, perLevel = 0.001,
	desc = "공격이 맞을 때마다 전하가 쌓인다(최대 10). 하나마다 공격이 빨라진다.",
}
exports.SKILLS.t_static = {
	name = "정전기", school = "thunder", kind = "passive",
	every = 4, power = 0.4, perLevel = 0.04, fx = { hit = "thunder" },
	desc = "기본 공격이 4번째로 맞을 때마다 작은 번개가 한 번 더 친다.",
}
-- 공용(전 유파)
exports.SKILLS.c_mastery = {
	name = "무기 단련", school = "", kind = "passive",
	perLevel = 0.015,
	desc = "무기를 다루는 솜씨. 공격력이 오른다.",
}
exports.SKILLS.c_energy = {
	name = "기력 단련", school = "", kind = "passive",
	maxPerLevel = 4, regenPerLevel = 0.2,
	desc = "최대 기력과 기력 회복이 는다.",
}

-- 유파 → 전직(1~4) → 스킬 id. 각 전직의 첫 번째 = 주력기.
exports.TREE = {
	fire = { { "fire_ball", "f_ember", "f_blade" }, { "fire_burst" }, { "fire_rain" }, { "fire_dragon" } },
	ice = { { "ice_spike", "i_frost", "i_armor" }, { "ice_freeze" }, { "ice_lance" }, { "ice_storm" } },
	plant = { { "p_seed", "p_vigor", "plant_heal" }, { "plant_bind" }, { "plant_thorn" }, { "plant_bloom" } },
	rock = { { "rock_spike", "r_firm", "rock_guard" }, {}, { "rock_quake" }, { "rock_meteor" } },
	thunder = { { "thunder_bolt", "t_charge", "t_static" }, { "thunder_storm" }, { "thunder_chain" }, { "thunder_judge" } },
}
exports.COMMON = { { "c_mastery", "c_energy" }, {}, {}, {} }
-- 마스터 레벨(없으면 전직별 기본: 1차 20 · 2차 15 · 3차 20 · 4차 30)
local MAX = {
	f_ember = 10, f_blade = 10, i_frost = 10, i_armor = 10, p_vigor = 10, plant_heal = 10, r_firm = 10, rock_guard = 10,
	t_charge = 10, t_static = 10, c_mastery = 10, c_energy = 5,
}
local JOB_MAX = { 20, 15, 20, 30 }
local jobOf = {}
for _, jobs in exports.TREE do
	for job, list in jobs do
		for _, id in list do
			jobOf[id] = job
		end
	end
end
for job, list in exports.COMMON do
	for _, id in list do
		jobOf[id] = job
	end
end

function exports.JobOf(id: string): number?
	return jobOf[id]
end

function exports.MaxOf(id: string): number
	return MAX[id] or JOB_MAX[jobOf[id] or 1]
end

function exports.IsActive(id: string): boolean
	local s = exports.SKILLS[id]
	return s ~= nil and s.kind ~= "passive"
end

-- 그 유파 · 전직의 스킬 목록(고유 + 공용)
function exports.TreeFor(school: string?, job: number): { string }
	local out = {}
	for _, id in (exports.TREE[school or ""] or {})[job] or {} do
		table.insert(out, id)
	end
	for _, id in exports.COMMON[job] or {} do
		table.insert(out, id)
	end
	return out
end

-- 전직하면 바로 1레벨로 배우는 것: 그 전직의 주력기(첫 번째) + 핵심 장치
function exports.AutoFor(school: string?, job: number): { string }
	local out = {}
	for i, id in (exports.TREE[school or ""] or {})[job] or {} do
		if i == 1 or exports.SKILLS[id].core then
			table.insert(out, id)
		end
	end
	return out
end

-- 그 유파 스킬인가(공용 포함)
function exports.Belongs(id: string, school: string?): boolean
	local s = exports.SKILLS[id]
	return s ~= nil and jobOf[id] ~= nil and (s.school == "" or s.school == school)
end

-- 스킬 레벨 보정(피해 · 회복량): 1레벨 = 1, 마스터 = 1 + GROW
function exports.Scale(id: string, level: number?): number
	local max = exports.MaxOf(id)
	local l = math.clamp(level or 1, 1, max)
	return if max <= 1 then 1 else 1 + (l - 1) * exports.GROW / (max - 1)
end

-- 레벨업 SP: 전직한 뒤로는 레벨이 오를 때마다 지금 전직에 SP_PER_LEVEL(progressionService가 부른다). 받았으면 true
function exports.GrantLevelSp(data, gained: number): boolean
	local job = data.Job or 0
	if gained <= 0 or job < 1 then
		return false
	end
	if typeof(data.SP) ~= "table" then
		data.SP = { 0, 0, 0, 0 }
	end
	data.SP[job] = (data.SP[job] or 0) + gained * exports.SP_PER_LEVEL
	return true
end

-- 그 레벨까지 그 전직 구간에서 얻는 SP(전직할 때 SP_ON_JOB + 구간 안에서 오른 레벨 × SP_PER_LEVEL)
function exports.SpEarned(job: number, level: number): number
	local from = exports.JOB_LEVELS[job]
	if not from or level < from then
		return 0
	end
	local to = (exports.JOB_LEVELS[job + 1] or math.huge) - 1
	return exports.SP_ON_JOB + (math.min(level, to) - from) * exports.SP_PER_LEVEL
end

-- 유파 번호(0부터 — 캐릭터 시트 줄). 유파가 없으면(아직 안 고름) 0.
-- 그 사람의 대쉬 id("novice" = 견습 구르기)와 정의
function exports.DashFor(school: string?, job: number?): (string, any)
	local id = if (job or 0) >= 1 and exports.DASH[school or ""] then school :: string else "novice"
	return id, exports.DASH[id]
end

function exports.SchoolIndex(school: string?): number
	local i = table.find(exports.SCHOOLS, school or "")
	return if i then i - 1 else 0
end

-- 그 유파의 칸(1~4 = n차 전직 인술)에 들어가는 인술 id
function exports.SkillFor(school: string?, slot: number): string?
	local info = exports.SCHOOL_INFO[school or ""]
	return info and info.skills[slot]
end

-- 그 레벨에서 할 수 있는 전직 단계(0~4)
function exports.JobFor(level: number): number
	local job = 0
	for i, need in exports.JOB_LEVELS do
		if level >= need then
			job = i
		end
	end
	return job
end

-- 단계 보정(1단계 = 1.0)
function exports.LevelScale(level: number?): number
	return 1 + (math.clamp(level or 1, 1, exports.MAX_LEVEL) - 1) * exports.LEVEL_BONUS
end

-- 저장 데이터(data.Ninjutsu = { [인술 id] = 단계 })에서 그 인술 단계(없으면 1)
function exports.LevelOf(levels, id: string): number
	local level = levels and levels[id]
	return if typeof(level) == "number" then math.clamp(math.floor(level), 0, exports.MaxOf(id)) else 0
end

return exports
