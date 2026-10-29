-- 「달의 계승자」 — 액시온 리마스터(2026-10-28 사용자: "차징을 모으고 한방에 강력한데미지를 보이는거야 딜도 단일타수로 빵 뜨고 … 많은 타수로 패시브를 터트려 딜을 넣는형식이 이상해
--  커지고 차징해서 한방 빵 이런식이여야해" → 고르심: 메아리 도끼 「다 모은 한 방에만」 · 커지기 「모을 때마다」 · 피해 숫자 「모은 한 방만 한 숫자」).
--  도끼 기술은 모았다가 한 방(붙어 있는 적에게 한 번) · 모아 친 한 방은 피해 숫자 한 줄 · 힘 모으기 4단계(만근) · 전투 호흡 = 모으는 시간 −25% · 충격파는 넘어뜨린다 · 몸이 커진다(그리기).
--  메아리 도끼(끝까지 모은 한 방에만)는 19_lune_kit · 21_lune_cast, 충격파 · 전투 호흡의 서버 흐름은 13_lune_world.
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Kitset = req("ReplicatedStorage/shared/lune/kitset")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local SUB = 1 / 60
local X, Y = 2000, 176

-- 모았다가 한 방인 기술(1차 둘 · 2차 둘 · 3차 둘 · 4차 둘)
local ONE = { "ax_slam", "ax_combo", "ax_crescent", "ax_rend", "ax_whirl", "ax_wheel", "ax_moonfall", "ax_execute" }
local FIRST = { ax_slam = true, ax_combo = true }

local function hero(skills)
	local h = Hero.new(1, "axion")
	h.level = 120
	h.skills = {}
	for id, lv in skills or {} do
		h.skills[id] = lv
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y, h.dir = X, Y, 1
	return h
end
local function dry(h)
	local room, foe = Caster.makeDry(X + 14, Y)
	local c = Caster.new(room)
	c.dry = true
	local function tick()
		room.time += SUB
		foe.rend = 0
		c:sub(SUB)
	end
	return room, foe, c, tick
end
local function drain(c, tick)
	local guard = 0
	while (#c.timers > 0 or #c.shots > 0) and guard < 20 do
		tick()
		guard += SUB
	end
end

-- ---- 1) 묶음: 모으는 구간 다음에 한 방 ----
do
	local kit = Kitset.of("axion")
	eq(kit.grow, 0.15, "모은 단계마다 몸이 15% 커진다(그리기)")
	eq(kit.onHit, nil, "도끼질마다 세던 메아리 도끼는 없다(서버가 끝까지 모은 한 방에 정한다)")
	eq(kit.haste, nil, "전투 호흡은 공격 속도가 아니다")
	eq(kit.drawMarks, nil, "처단의 빛 조각 쌓기는 없다")
	for _, id in ONE do
		local sk = Kitset.skill(id)
		expect(sk ~= nil and #sk.segs == 2, "구간 둘(모으기 · 한 방) " .. id)
		if sk and #sk.segs == 2 then
			expect(sk.segs[1].charge == true and sk.segs[1].loopFrom ~= nil, "첫 구간은 모으는 구간(끝 장에서 되풀이) " .. id)
			expect(not sk.segs[2].charge and not sk.segs[2].needPress, "둘째 구간은 저절로 나가는 한 방 " .. id)
			expect((sk.holdFor or 0) > 0, "시험 탭이 누르고 있는 시간 " .. id)
		end
	end
	local whirl = Kitset.skill("ax_whirl").segs[1]
	expect(whirl.free == true and whirl.walk == 1 and whirl.turn == true, "대지 분쇄: 모으는 동안 제 빠르기로 걷고 · 뛰고 · 대쉬한다(2026-10-25 사용자 요청 그대로)")
	-- 1차의 설계: 한 타
	eq(#COMBAT.skills.ax_combo.hits, 1, "도끼 내려찍기는 한 타")
	expect(COMBAT.skills.ax_combo.segs[1].charge and #COMBAT.skills.ax_combo.segs == 2, "도끼 내려찍기: 모으기 → 한 방")
	local center = 0
	for _, h in COMBAT.skills.ax_slam.hits do
		if not h.except then
			center += 1
		end
	end
	eq(center, 1, "대지 강타: 가운데 한 방(바깥 가시는 가운데에 맞지 않은 적만)")
	-- 이름(이름표는 그대로)
	local names = {}
	for _, t in CLASSES.classes.axion.tiers do
		for _, sk in t.skills do
			names[sk.id] = sk.name
		end
	end
	eq(names.ax_combo, "도끼 내려찍기", "삼단 베기 → 도끼 내려찍기")
	eq(names.ax_whirl, "대지 분쇄", "몰아치기 → 대지 분쇄")
	eq(names.ax_wheel, "천근 내려치기", "회전 내려치기 → 천근 내려치기")
	eq(names.ax_execute, "월광 처단", "처단 → 월광 처단")
	eq(names.ax_echo2, "무거운 메아리", "겹 메아리 → 무거운 메아리")
	eq(names.ax_echo4, "만근", "달 그림자 도끼 → 만근")
	-- 같은 날 두 번째(사용자 "차징중에 느리게 이동 및 방향전환이 가능해야하고"): 1차의 모으는 구간도 천천히 걷고 돌아본다(게임의 1차는 설계의 구간을 쓴다)
	for _, id in { "ax_slam", "ax_combo" } do
		local s1 = COMBAT.skills[id].segs[1]
		expect(s1.charge and s1.walk == 0.5 and s1.turn == true, "1차의 모으는 구간: 0.5배로 걷고 돌아본다 " .. id)
	end
	eq(COMBAT.kit.axion.toggle.share, 0.2, "메아리 도끼 = 그 타의 20%(한 방이 모은 시간만큼 커져서 — 처음 설계의 「사출기 +20%」)")
end

-- ---- 2) 붙어 있는 적에게 한 번 · 모아 친 한 방은 숫자 한 줄 ----
for _, id in ONE do
	if FIRST[id] then
		continue
	end
	eq(Caster.profile(id, 0).hits, 1, "붙어 있는 적이 한 번 맞는다 " .. id)
	local h = hero({ [id] = 30, ax_charge = 10, ax_charge2 = 10, ax_echo4 = 10 })
	local levels = Kit.chargeLevels(h)
	local _, foe, c, tick = dry(h)
	c:dryCast(h, id, levels, tick)
	drain(c, tick)
	local mine = {}
	for _, e in c:actor(h).out.hits do
		if e.mob == foe.id and not e.proc then
			table.insert(mine, e)
		end
	end
	eq(#mine, 1, "끝까지 모아 쳐도 한 방 " .. id)
	expect(mine[1] ~= nil and mine[1].lines == nil, "모아 친 한 방은 피해 숫자 한 줄 " .. id)
	-- 모으지 않으면 예전처럼 나눠 적는다(그 기술의 줄 수)
	local _, foe0, c0, tick0 = dry(h)
	c0:dryCast(h, id, 0, tick0)
	drain(c0, tick0)
	local plain = nil
	for _, e in c0:actor(h).out.hits do
		if e.mob == foe0.id and not e.proc then
			plain = e
		end
	end
	local n = Caster.lines(id)
	expect(plain ~= nil and (if n > 1 then plain.lines ~= nil and #plain.lines == n else plain.lines == nil), ("모으지 않은 한 방은 %d줄 %s"):format(n, id))
end
-- 1차: 모아 친 대지 강타 · 도끼 내려찍기도 한 줄
do
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(3))
	local h = hero({ ax_charge = 10 })
	for i, m in room.mobs do
		m.state, m.a, m.b, m.y = "idle", 0, 4000, Y
		m.hp, m.maxHp = 1e12, 1e12
		m.x = X + 1200 + i * 30
	end
	local foe = room.mobs[1]
	foe.x = X + 20
	for _, id in { "ax_slam", "ax_combo" } do
		local def = COMBAT.skills[id]
		local out = room:skillHit(h, def.hits[1], X, Y, 1, 1, nil, def.type, id, { mul = 2, reach = 20, level = 2 })
		expect(#out.hits == 1 and out.hits[1].lines == nil, "모아 친 1차 기술은 피해 숫자 한 줄 " .. id)
	end
end

-- ---- 3) 힘 모으기의 단계: 2 → 깊은 호흡 3 → 만근 4 ----
do
	eq(Kit.chargeLevels(hero({ ax_charge = 10 })), 2, "1차: 2단계")
	eq(Kit.chargeLevels(hero({ ax_charge = 10, ax_charge2 = 10 })), 3, "깊은 호흡: 3단계")
	eq(Kit.chargeLevels(hero({ ax_charge = 10, ax_charge2 = 10, ax_echo4 = 1 })), 4, "만근: 4단계")
	local h = hero({ ax_charge = 10, ax_charge2 = 10, ax_echo4 = 1 })
	local per = COMBAT.kit.axion.core.per.ax_slam
	eq((Kit.charge(h, "ax_slam", per * 4)), 4, "대지 강타를 네 단계만큼 모으면 4단계")
	local m4 = select(2, Kit.charge(h, "ax_slam", per * 4))
	local m3 = select(2, Kit.charge(h, "ax_slam", per * 3))
	expect(m4 > m3, "4단계가 3단계보다 세다")
	-- 2~4차의 모으는 구간도 같은 단계 수
	local _, levels = Caster.chargeOf(h, Kitset.skill("ax_execute").segs[1])
	eq(levels, 4, "월광 처단도 4단계까지")
	local cut = table.clone(h)
	cut.buffs = { ax_breath = { pow = 1, t = 60 } }
	local perCut = Caster.chargeOf(cut, Kitset.skill("ax_execute").segs[1])
	local perAll = Caster.chargeOf(h, Kitset.skill("ax_execute").segs[1])
	expect(math.abs(perCut / perAll - 0.75) < 1e-6, "전투 호흡: 2~4차의 한 단계도 0.75배의 시간")
end

-- ---- 4) 넘어뜨리는 타(충격파): 보통 적만 ----
do
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(5))
	local h = hero({ ax_charge = 10 })
	for i, m in room.mobs do
		m.state, m.a, m.b, m.y = "idle", 0, 4000, Y
		m.hp, m.maxHp = 1e12, 1e12
		m.x = X + 1200 + i * 30
		m.stun = 0
	end
	local foe = room.mobs[1]
	foe.x = X + 20
	local hit = table.clone(COMBAT.skills.ax_slam.hits[1])
	hit.stun = 1.5
	room:skillHit(h, hit, X, Y, 1, 1, nil, "mob", "ax_slam", { mul = 1, reach = 0, level = 2 })
	expect(foe.stun >= 1.5 - 1e-6, "보통 적은 넘어진다")
	local def = foe.def
	foe.def = table.clone(def)
	foe.def.boss = true
	foe.stun = 0
	room:skillHit(h, hit, X, Y, 1, 1, nil, "mob", "ax_slam", { mul = 1, reach = 0, level = 2 })
	eq(foe.stun, 0, "우두머리는 넘어지지 않는다")
	foe.def = def
	-- 충격파 패시브의 수치
	local SHOCK = COMBAT.passive.ax_shock.fx
	expect(SHOCK.shock > 0 and SHOCK.wide >= 150 and SHOCK.stun > 0, "충격파: 피해 + · 양옆 150도트 · 넘어뜨리는 시간")
end

-- ---- 5) 넘치는 힘: 끝까지 모은 강타를 맞힌 직후의 강타는 2단계에서 「시작」한다(2026-10-28 사용자 "넘치는힘 패시브가 적용되는게 맞아?") ----
do
	local h = hero({ ax_charge = 10, ax_charge2 = 10, ax_echo4 = 1, ax_charge3 = 10, ax_execute = 30 })
	local SURGE = COMBAT.passive.ax_charge3.fx
	eq(Kit.chargeLevels(h), 4, "4단계")
	-- 1차의 셈(Kit.charge의 from)
	local per1 = COMBAT.kit.axion.core.per.ax_slam
	eq((Kit.charge(h, "ax_slam", 0, SURGE.surgeFrom)), 2, "1차: 톡 쳐도 2단계")
	eq((Kit.charge(h, "ax_slam", per1, SURGE.surgeFrom)), 3, "1차: 한 단계 모으면 3단계")
	eq((Kit.charge(h, "ax_slam", per1 * 2, SURGE.surgeFrom)), 4, "1차: 두 단계 모으면 끝까지(4단계)")
	eq((Kit.charge(h, "ax_slam", per1 * 2)), 2, "넘치는 힘이 없으면 두 단계는 2단계")
	-- 2~4차(서버가 흐른 시간으로 세는 begin)
	local seg1 = Kitset.skill("ax_execute").segs[1]
	local base = Caster.segTime("axion", seg1)
	local function release(held: number, surge: boolean): (number, any)
		local room, _, c = dry(h)
		c.dry = false
		h.pass.surge = if surge then room.time + SURGE.surge else -1e9
		expect(c:begin(h, "ax_execute", 1, nil), "모으는 구간")
		for _ = 1, math.floor((base + held) / SUB + 0.5) do
			room.time += SUB
			c:sub(SUB)
		end
		local ok, lv = c:begin(h, "ax_execute", 2, nil)
		expect(ok, "한 방의 구간")
		return lv, c:actor(h).skill
	end
	eq((release(0, true)), 2, "2~4차: 톡 쳐도 2단계")
	local lv4, sk = release(seg1.per * 2 + 0.02, true)
	eq(lv4, 4, "2~4차: 두 단계만 더 모으면 끝까지(4단계)")
	expect(sk and sk.ctx and sk.ctx.surged == true, "넘치는 힘으로 간 한 방(이 한 방으로는 다시 켜지지 않는다)")
	expect(h.pass.surge < 0, "한 번 쓰면 사라진다")
	eq((release(seg1.per * 2 + 0.02, false)), 2, "넘치는 힘이 없으면 두 단계는 2단계")
end


-- ---- 6) 끝까지 모은 뒤 늦게 온 「뗐다」(2026-10-29 사용자 제보: 전투 호흡을 건 채 초승달 가르기를 끝까지 모아 쓰면 이펙트는 나가는데 피해가 없다 — 곡괭이 코볼트 맵(r3a3) 왼쪽 끝의 벽에 붙어서) ----
--  서버는 끝까지 모으면 GRACE 뒤에 구간을 닫는다. 화면이 멈칫하거나 네트워크가 흔들려 「뗐다」가 그 뒤에 오면 전에는 0단계로 셌다 —
--  0단계 초승달은 낮게 날아 바로 앞의 한 칸 높이 바위에 부딪혀 사라졌다(화면은 4단계 — 바위를 넘는 것을 그렸다). 이제 닫힌 구간도 흐른 시간(= 끝까지)으로 센다
do
	local scene = SCENES.scenes.r3a3
	local seg1 = Kitset.skill("ax_crescent").segs[1]
	local function late(extra: number): (boolean, number?, number, boolean)
		local room = Room.new("r3a3", scene, Random.new(1))
		local h = hero({ ax_crescent = 20, ax_charge = 10, ax_charge2 = 10, ax_echo4 = 1, ax_breath = 10 })
		h.x, h.y, h.dir = 20, 176, 1 -- 왼쪽 끝 · 오른쪽(한 칸 높이 바위 x 64~112)을 본다
		h.buffs = { ax_breath = { pow = 1, t = 60 } }
		for _, m in room.mobs do
			m.state, m.a, m.b = "idle", 0, 9000
			m.hp, m.maxHp = 1e12, 1e12
		end
		local c = room.caster
		local per, levels = Caster.chargeOf(h, seg1)
		eq(levels, 4, "만근: 4단계")
		expect(math.abs(per - seg1.per * 0.75) < 1e-6, "전투 호흡: 한 단계 0.75배")
		expect(c:begin(h, "ax_crescent", 1, nil), "모으는 구간")
		for _ = 1, math.floor((Caster.segTime("axion", seg1) + per * levels + extra) / SUB + 0.5) do
			room.time += SUB
			c:sub(SUB)
		end
		local ok, lv = c:begin(h, "ax_crescent", 2, nil)
		for _ = 1, 90 do
			room.time += SUB
			c:sub(SUB)
		end
		local hurt, onRock = 0, false
		for _, m in room.mobs do
			if m.hp < 1e12 then
				hurt += 1
				if m.y == 160 then
					onRock = true -- 바위 위의 코볼트(바위 너머)
				end
			end
		end
		return ok, lv, hurt, onRock
	end
	for _, extra in { 0, 0.5, 0.9 } do
		local ok, lv, hurt, onRock = late(extra)
		expect(ok and lv == 4, ("끝까지 모은 뒤 %.1f초 늦게 떼도 4단계(%s · %s)"):format(extra, tostring(ok), tostring(lv)))
		expect(hurt >= 3 and onRock, ("4단계 초승달은 바위를 넘어 코볼트를 벤다(%.1f초 늦게 — %d마리)"):format(extra, hurt))
	end
	local okFar = late(3)
	expect(not okFar, "아주 늦은(3초) 「뗐다」는 받지 않는다")
end
