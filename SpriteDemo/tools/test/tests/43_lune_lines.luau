-- 「달의 계승자」 — 타수 나누기(2026-10-14): 공격 스킬의 한 타를 여러 줄(숫자 여럿)로 쪼갠다. 피해의 합은 그대로다.
--  사용자: "현재 스킬들 거의다 타수가 너무 적습니다. 동일데미지에서 타수분할을 하세요 7~8번 다다다다다 데미지가 올라오는맛이 있어야합니다.
--   극딜기의 경우 더 높은 타수가 들어가야하구요 100% 데미지로 1타가 아닌 10% 데미지로 10번 이런식이여야합니다."
--  보는 것: ① 줄 수의 규칙(sim/lines.luau = 공방 design/combat.js의 linesFor) ② 쪼갠 줄의 합 = 그 타의 피해, 줄마다 1 이상, 줄마다 조금씩 다르다
--           ③ 1차의 사냥기 · 보스기 · 2~4차의 쓰는 스킬을 붙어 있는 졸개에게 쓰면 한 번에 숫자가 7번 넘게(극딜기는 14번 넘게) 뜬다
--           ④ 사출기처럼 따라 나가는 타는 쪼개지 않는다 ⑤ 피해의 합은 쪼개기 전과 같다(줄은 숫자만 나눈다)
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local Lines = req("ReplicatedStorage/shared/lune/sim/lines")
local _ = Room
local RULES = COMBAT.rules
local R = RULES.lines
local CAST = COMBAT.cast
local SUB = 1 / 60
local X, Y = 2000, 176

-- ---- 1) 줄 수의 규칙 ----
-- 차수마다(2026-10-15 — 사용자: "현재 저 차수 스킬은 타수가 너무 많습니다. 타수는 밸런스 있게 맞추고"): 1차 3 · 2차 4 · 3차 6 · 4차 8(7~8번은 4차에서)
eq(R.per[1], 3, "1차는 한 번에 3줄쯤")
eq(R.per[4], 8, "4차는 한 번에 8줄쯤(10-14: 7~8번)")
for job = 2, 4 do
	expect(R.per[job] > R.per[job - 1], ("%d차는 %d차보다 줄이 많다"):format(job, job - 1))
	expect(R.nuke[job] > R.per[job], ("%d차의 극딜기는 더 많이"):format(job))
end
eq(Lines.count(1, false, 4), 8, "4차 한 타 = 8줄")
eq(Lines.count(2, false, 4), 4, "4차 두 타 = 4줄씩")
eq(Lines.count(3, false, 4), 3, "4차 세 타 = 3줄씩(9)")
eq(Lines.count(6, false, 4), 2, "4차 여섯 타 = 2줄씩(12 — 1줄씩이면 6이라 모자란다)")
eq(Lines.count(12, false, 4), 1, "열두 타 = 1줄씩")
eq(Lines.count(1, false, 1), 3, "1차 한 타 = 3줄")
eq(Lines.count(3, false, 1), 1, "1차 세 타 = 1줄씩")
eq(Lines.count(1, true, 4), R.nuke[4], "4차 극딜기 한 타 = nuke줄")
eq(Lines.count(0, false, 1), 1, "타가 없으면 1")
for job = 1, 4 do
	for hits = 1, 30 do
		for _, nuke in { false, true } do
			local L = Lines.count(hits, nuke, job)
			local per = (if nuke then R.nuke else R.per)[job]
			expect(L >= 1 and L <= R.max, "1 ~ max줄")
			expect(hits * L >= per - 1 or L == R.max, ("%d차: 한 번에 적어도 %d번(타 %d)"):format(job, per - 1, hits))
		end
	end
end

-- ---- 2) 쪼개기 ----
do
	local rng = Random.new(7)
	for _, total in { 1, 5, 8, 9, 37, 1234, 98765 } do
		for _, n in { 1, 3, 8, 15 } do
			local parts = Lines.split(total, n, rng)
			local sum, ok = 0, true
			for _, d in parts do
				sum += d
				ok = ok and d >= 1 and d == math.floor(d)
			end
			eq(sum, total, ("합 = 그 타의 피해(%d를 %d줄)"):format(total, n))
			expect(ok, "줄마다 1 이상의 정수")
			eq(#parts, math.min(n, total), "줄 수(피해가 줄 수보다 작으면 피해만큼)")
		end
	end
	local parts = Lines.split(10000, 8, rng)
	local differ = false
	for i = 2, #parts do
		differ = differ or parts[i] ~= parts[1]
	end
	expect(differ, "줄마다 숫자가 조금씩 다르다(메이플처럼)")
	for _, d in parts do
		expect(math.abs(d - 1250) <= 1250 * R.jitter * 1.3 + 2, "한 줄은 고른 몫에서 크게 벗어나지 않는다")
	end
end

local function hero(class: string, skills)
	local h = Hero.new(1, class)
	h.level = 120
	h.skills = {}
	for id, lv in skills do
		h.skills[id] = lv
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y, h.dir = X, Y, 1
	return h
end
-- 한 칸이 띄우는 숫자의 수 · 그 칸의 줄 합이 피해와 같은가
local function count(e): number
	if e.lines then
		local sum = 0
		for _, d in e.lines do
			sum += d
		end
		eq(sum, e.dmg, "줄의 합 = 그 타의 피해")
		return #e.lines
	end
	return 1
end

-- ---- 2b) 크리티컬은 줄마다 따로 굴린다(사용자 2026-10-14: "한 스킬이 5%로 크리티컬이 발동되어서 타수 전부다 크리티컬이 뜨는게 아니라 … 모든타수가 별개로 크리티컬 확률이 적용되는겁니다") ----
do
	local def = COMBAT.skills.rv_fan -- 1차 한 타 = 3줄(2026-10-15부터 — 차수마다)
	local h = hero(def.who, { [def.id or "rv_fan"] = 1 })
	h.skills.rv_fan = 1
	local room, foe = Caster.makeDry(X + 14, Y)
	local keep = RULES.critChance
	RULES.critChance = 50
	local hits, mixed, critLines, allLines = 0, 0, 0, 0
	for _ = 1, 200 do
		foe.hp, foe.state, foe.x = foe.maxHp, "idle", X + 14 -- 쓰러져도 다시 세운다
		local res = room:skillHit(h, def.hits[1], h.x, h.y, 1, 1, nil, def.type, "rv_fan")
		for _, e in res.hits do
			if e.mob == foe.id and e.lines then
				hits += 1
				local n, sum = 0, 0
				for i, d in e.lines do
					sum += d
					allLines += 1
					if e.crits and e.crits[i] then
						n += 1
						critLines += 1
					end
				end
				eq(sum, e.dmg, "줄의 합 = 그 타의 피해(크리티컬까지)")
				if n > 0 and n < #e.lines then
					mixed += 1
				end
				expect((n > 0) == (e.crit == true), "한 줄이라도 크리티컬이면 그 타는 crit")
			end
		end
	end
	RULES.critChance = keep
	expect(hits >= 190, "한 타 = 여러 줄로 왔다 — " .. hits)
	local L1 = Lines.first("rv_fan")
	local want = 1 - 2 * 0.5 ^ L1 -- 줄마다 50%로 따로 굴리면 L줄이 섞일 확률
	expect(mixed > hits * want * 0.85, ("한 타 안에서 크리티컬인 줄과 아닌 줄이 섞인다(%d / %d — %d줄이면 %.0f%%쯤)"):format(mixed, hits, L1, want * 100))
	expect(math.abs(critLines / allLines - 0.5) < 0.05, ("줄마다 50%%로 따로 터진다(%.3f)"):format(critLines / allLines))
end
do
	-- 2~4차: 붙어 있는 적에게 열 번 — 줄마다 따로(크리티컬 5%면 한 타의 줄이 다 크리티컬인 일은 거의 없다)
	local id = "ax_crescent"
	local def = CAST[id]
	local h = hero(def.who, { [id] = 1 })
	local room, foe = Caster.makeDry(X + (def.at or 14), Y)
	local c = Caster.new(room)
	c.dry = true
	local keep = RULES.critChance
	RULES.critChance = 50
	local a = c:actor(h)
	for _ = 1, 10 do
		h.x, h.y, h.dir = X, Y, 1
		foe.x, foe.hp, foe.state = X + (def.at or 14), foe.maxHp, "idle"
		c:dryCast(h, id, 0, function()
			room.time += SUB
			c:sub(SUB)
		end)
	end
	RULES.critChance = keep
	local mixed, lined = 0, 0
	for _, e in a.out.hits do
		if e.lines and not e.proc then
			lined += 1
			local n = 0
			for i in e.lines do
				if e.crits and e.crits[i] then
					n += 1
				end
			end
			if n > 0 and n < #e.lines then
				mixed += 1
			end
		end
	end
	expect(lined > 0 and mixed > lined * 0.7, ("2차 기술도 줄마다 따로(%d / %d)"):format(mixed, lined))
end

-- ---- 3) 1차의 사냥기 · 보스기: 붙어 있는 졸개에게 한 번 다 맞히면 숫자가 7번 넘게 ----
do
	local seen = 0
	for id, def in COMBAT.skills do
		if def.job ~= 1 or #def.hits == 0 or (def.type ~= "mob" and def.type ~= "boss") then
			continue
		end
		seen += 1
		local L = Lines.first(id)
		local h = hero(def.who, { [id] = 1 })
		local room, foe = Caster.makeDry(X + 14, Y)
		local numbers = 0
		for _, hit in def.hits do
			if hit.except then
				continue -- 가운데 타의 범위 밖의 적만 맞는 타
			end
			foe.hp = foe.maxHp
			local res = room:skillHit(h, hit, h.x, h.y, 1, 1, nil, def.type, id)
			for _, e in res.hits do
				if e.mob == foe.id and not e.proc then
					numbers += count(e)
					if L > 1 then
						expect(e.lines ~= nil and #e.lines == L, ("%s: 한 타가 %d줄"):format(id, L))
					end
				end
			end
		end
		expect(numbers >= R.per[1] - 1, ("%s: 한 번에 숫자가 %d번 넘게 뜬다(실제 %d)"):format(id, R.per[1] - 2, numbers))
	end
	expect(seen >= 10, "1차 공격 스킬을 다 봤다 — " .. seen)
end

-- ---- 4) 2~4차의 쓰는 스킬: 열 번 쓴 평균이 한 번에 7번(극딜기 14번) 넘게 · 사출기의 타는 한 줄 ----
do
	local seen, nukes = 0, 0
	for id, def in CAST do
		local p = Caster.profile(id, 0)
		if p.measured <= 0 or def.rate <= 0 or def.w then
			continue -- 피해가 없는 것 · 장치를 다 갖췄을 때가 기준인 것(공명 폭발 · 열 방출 — 빈 방에서는 다 못 맞힌다)
		end
		seen += 1
		local nuke = def.type == "nuke"
		if nuke then
			nukes += 1
		end
		eq(Caster.lines(id), Lines.count(p.hits, nuke, CAST[id].job), "줄 수 = 잰 타의 수로 정한 것(그 차수의 규칙) " .. id)
		local h = hero(def.who, { [id] = 1 })
		local room, foe = Caster.makeDry(X + (def.at or 14), Y)
		local c = Caster.new(room)
		c.dry = true
		local function tick()
			room.time += SUB
			foe.rend = 0
			c:sub(SUB)
		end
		local a = c:actor(h)
		for _ = 1, 10 do
			h.x, h.y, h.dir = X, Y, 1
			foe.x, foe.stun, foe.bind, foe.bindImm, foe.hp = X + (def.at or 14), 0, 0, 0, foe.maxHp
			if id == "sl_vent" then
				h.kit.heat = 0
			end
			c:dryCast(h, id, 0, tick)
		end
		local guard = 0
		while (#c.timers > 0 or #c.shots > 0) and guard < 20 do
			tick()
			guard += SUB
		end
		local numbers = 0
		for _, e in a.out.hits do
			if e.mob == foe.id then
				if e.proc then
					expect(e.lines == nil, "따라 나가는 타(사출기 · 장치)는 쪼개지 않는다 " .. id)
				else
					numbers += count(e)
				end
			end
		end
		local per = (if nuke then R.nuke else R.per)[def.job]
		expect(numbers / 10 >= (per - 1) * 0.85, ("%s: 한 번 쓰면 숫자가 %d번쯤 뜬다(열 번 평균 %.1f)"):format(id, per - 1, numbers / 10))
	end
	expect(seen >= 30, "쓰는 스킬을 다 봤다 — " .. seen)
	expect(nukes >= 4, "극딜기(큰 기술)도 봤다 — " .. nukes)
end
