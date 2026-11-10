-- 「달의 계승자」 — 직업 · 차수마다의 보스 보정(2026-11-08 — 공방 combat.js RULES.bossClass · sim/room.luau Room:bossMul · Room:strike)
--  사용자 2026-11-07: "지금 보스 dps 밸런스가 안맞는데? … 밸런스를 똑바로 잡아야해" — 보스에게 넣는 모든 피해에 그 직업 · 차수의 배수를 한 번 곱한다.
--  덧타(그 타 피해의 몇 % — 살라맨더의 불꽃 · 액시온의 메아리 도끼 · 리븐의 표창 …)는 맞힌 목록(landed)의 「배수를 나눈 피해」에서 나와 Room:strike에서 한 번만 곱해진다(전에는 두 번 — 배수가 1보다 크면 더 세게 · 작으면 더 약하게).
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타 없이 피해를 그대로 잰다
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local RULES = COMBAT.rules
local KIT = COMBAT.kit

local X, Y = 300, 176
local function near(a, b, tol, msg)
	expect(math.abs(a - b) <= tol * math.max(1, math.abs(b)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end

-- 자료: 다섯 직업 모두 [1차, 2차, 3차, 4차]의 양수
for _, class in { "axion", "riven", "reaper", "mooni", "salamander" } do
	local v = RULES.bossClass[class]
	expect(typeof(v) == "table" and #v == 4, class .. ": 차수 넷의 배수")
	for i = 1, 4 do
		expect(typeof(v[i]) == "number" and v[i] > 0, ("%s %d차의 배수는 양수"):format(class, i))
	end
	eq(v[1], 1, class .. ": 1차는 1(레이드가 없어 재지 않았다)")
end

-- 방 하나 · 살라맨더(Lv.20 · 1차) · 앞의 졸개 a를 보스로(boss = true) — 같은 씨앗이면 피해의 흔들림이 같다
local function arena(boss: boolean)
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(7))
	local h = Hero.new(1, "salamander")
	h.level = 20
	h.skills.sl_heat = 10
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y = X, Y
	for i, mob in room.mobs do
		mob.state, mob.t = "idle", 0
		mob.a, mob.b = 0, 2000
		mob.y = Y
		mob.x = 1500 + i * 30
		mob.hp, mob.maxHp = 1e12, 1e12
	end
	local a = room.mobs[1]
	a.x = X + 20
	if boss then
		a.def = setmetatable({ boss = true }, { __index = a.def })
	end
	h.kit.heat = KIT.salamander.core.max -- 달아올랐다: 맞힐 때마다 불꽃이 한 번 더(그 타의 share)
	return room, h, a
end
local function hitOnce(boss: boolean)
	local room, h, a = arena(boss)
	local def = COMBAT.skills.sl_punch
	local out = room:skillHit(h, def.hits[1], h.x, h.y, 1, 1, nil, def.type, "sl_punch", nil)
	local main, flame = 0, 0
	for _, e in out.hits do
		if e.mob == a.id then
			if e.proc == "flame" then
				flame += e.dmg
			elseif not e.proc then
				main += e.dmg
			end
		end
	end
	return main, flame, room, h, a
end

local keep = RULES.bossClass.salamander
RULES.bossClass.salamander = { 1, 1, 1, 1 }
local m1, f1, room1, h1, a1 = hitOnce(true)
expect(m1 > 0 and f1 > 0, "보스를 쳤다(불꽃까지)")
eq(room1:bossMul(h1, a1), 1, "배수 1")
local mn1, fn1 = hitOnce(false)

RULES.bossClass.salamander = { 3, 5, 7, 9 }
local m3, f3, room3, h3, a3 = hitOnce(true)
eq(room3:bossMul(h3, a3), 3, "Lv.20 = 1차의 값")
h3.job = 3
eq(room3:bossMul(h3, a3), 7, "3차면 셋째 값")
h3.job = 9
eq(room3:bossMul(h3, a3), 9, "넘으면 마지막 값")
near(m3 / m1, 3, 0.01, "보스에게 넣는 타 x3")
near(f3 / f1, 3, 0.02, "덧타(불꽃 — 그 타의 share)도 x3 한 번만(두 번이면 x9)")
local mn3, fn3, roomN, hN, aN = hitOnce(false)
eq(roomN:bossMul(hN, aN), 1, "보스가 아니면 1")
eq(mn3, mn1, "보스가 아닌 졸개에게는 그대로")
eq(fn3, fn1, "졸개의 덧타도 그대로")
RULES.bossClass.salamander = keep

-- 백귀야행(2026-11-09 사용자: "백귀야행의 깡데미지를 한참더 줄이고 그비율만큼 일반몹데미지로 보정해 사신화 백귀야행 초기화의 매커니즘이 사냥에서만 쓰이게"):
--  쓰임 1/4(스킬 창의 %도) · 보스가 아닌 적에게 4배(일반 몬스터에게는 그 전과 같다 — Caster:context의 mob · Caster:strike) · 사신 각성의 다시 쓰기 없음은 사냥터에서만(Kit.noCd의 hunt — Room.huntRoom)
--  (그 전 같은 날의 free — 다시 쓰기 없이 나간 공격기는 보스에게 사냥기처럼 — 은 뺐다: 보스 방에서는 다시 쓰기가 그대로)
do
	local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
	local P = COMBAT.cast.rp_parade
	eq(P.mob, 4, "백귀야행: 보스가 아닌 적에게 4배")
	near(P.tune, 0.25, 1e-6, "백귀야행: 쓰임 1/4(보스에게 넣는 피해 · 스킬 창의 %)")
	near(P.tune * P.mob, 1, 1e-6, "보스가 아닌 적에게는 그 전과 같다")
	eq(COMBAT.cast.rp_behead.mob, nil, "참수는 그대로")
	-- 같은 씨앗의 방 둘 · 같은 타 하나 — 보스에게 / 졸개에게
	local function parade(boss: boolean): number
		local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(11))
		local h = Hero.new(2, "reaper")
		h.level, h.job = 150, 4
		h.skills.rp_parade = 10
		Hero.recalc(h)
		h.hp, h.x, h.y = h.maxHp, X, Y
		local m = room.mobs[1]
		m.state, m.t, m.y, m.x = "idle", 0, Y, X + 20
		m.hp, m.maxHp = 1e12, 1e12
		if boss then
			m.def = setmetatable({ boss = true }, { __index = m.def })
		end
		local a = { hero = h, out = { hits = {}, kills = {} } }
		a.ctx = room.caster:context(a, "rp_parade", 0, nil)
		eq(a.ctx.mob, 4, "그 판의 ctx에 mob")
		room.caster:strike(a, m, 1, {}, {})
		return 1e12 - m.hp
	end
	local keepR = RULES.bossClass.reaper
	RULES.bossClass.reaper = { 1, 1, 1, 1 }
	local onBoss, onMob = parade(true), parade(false)
	RULES.bossClass.reaper = keepR
	expect(onBoss > 0 and onMob > 0, "둘 다 맞았다")
	near(onMob / onBoss, 4, 0.03, "같은 타: 졸개에게 4배(보스에게 1/4 — 흩어짐 ±10%의 굴림이 방마다 조금 다르다)")
	-- 사신 각성의 다시 쓰기 없음: 사냥터에서만
	local h = Hero.new(3, "reaper")
	h.level, h.job = 150, 4
	h.skills.rp_awaken = 15
	Hero.recalc(h)
	h.buffs[Kit.FORM] = { t = 20, dur = 20 }
	expect(Kit.noCd(h, "attack") and Kit.noCd(h, "mob"), "사신화 + 사신 각성 = 사냥기 · 공격기의 다시 쓰기가 없다 — 보스 방 · 레이드 · 스토리 · 던전도(2026-11-10 사용자: 보스에게는 백귀야행이 이미 1/4)")
	expect(Room.huntRoom(SCENES.scenes.hunt), "시험의 사냥터는 사냥터")
	for _, key in { "r3d5", "r3d6", "r3d7" } do
		expect(SCENES.scenes[key] ~= nil and not Room.huntRoom(SCENES.scenes[key]), key .. "(용암 거인의 방)은 사냥터가 아니다")
	end
	h.skills.rp_awaken = 0
	expect(not Kit.noCd(h, "attack"), "사신 각성이 없으면 다시 쓰기가 있다")
end
