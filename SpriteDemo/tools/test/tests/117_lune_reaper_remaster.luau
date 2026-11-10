-- 「달의 계승자」 — 리퍼 리마스터(2026-10-31 사용자: "리퍼도 컨셉에 맞게 리마스터해야해" → "피흡도 처치시 흡혈로 해서 보스전에서는 흡혈효율이 좋지않은데 사냥에서는 흡혈 잘되게 해서
--  이펙트도 멋지게 기존 이펙트랑 잘어우러지고"). 보는 것(서버 sim/room.luau Room:reaperKill · kits/reaper.luau · design/combat.js):
--  ① (같은 날 「게이지 직업」으로 다시 — 사신의 일격은 뺐다) 사신 각성: 사신화 동안 공격기의 다시 쓰기가 없다 ② 이중 낫질의 둘째 타가 끌어당긴다 ③ 망령 낫: 두 번 · 리퍼 쪽으로 끌려온다 ④ 넋 거두기 · 그림자 낫의 그림이 있다(화면)
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")
local Kitset = req("ReplicatedStorage/shared/lune/kitset")
local X, Y = 200, 176
local SUB = 1 / 60

local function arena(skills)
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(7))
	local h = Hero.new(1, "reaper")
	h.level = 60
	for id, lv in skills do
		h.skills[id] = lv
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y, h.dir = X, Y, 1
	for i, mob in room.mobs do
		mob.state, mob.t = "idle", 0
		mob.a, mob.b = 0, 2000
		mob.y = Y
		mob.x = 1500 + i * 30
		mob.hp, mob.maxHp = 1e12, 1e12
	end
	return room, h, room.mobs[1], room.mobs[2], room.mobs[3]
end
local function reaps(out)
	local list = {}
	for _, e in out.hits do
		if e.proc == "reap" then
			table.insert(list, e)
		end
	end
	return list
end
local hit1 = COMBAT.skills.rp_double.hits[1]

-- ① 사신화 동안 4차 「사신 각성」: 공격기(영혼 수확 · 백귀야행)의 다시 쓰기가 없다 → 광역 난사(서버 world.luau가 Kit.noCd를 본다)
do
	local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
	local room, h = arena({ rp_reap = 10, rp_parade = 10, rp_soul = 10, rp_awaken = 15 })
	h.job = 4
	expect(not Kit.noCd(h, COMBAT.cast.rp_parade.type), "사신화가 아니면 백귀야행의 다시 쓰기(12초)가 있다")
	h.kit.gauge = Kit.gaugeMax(h)
	expect(Buffs.cast(h, "rp_form", 0) ~= nil, "게이지가 가득 → 사신화")
	expect(Kit.noCd(h, COMBAT.cast.rp_parade.type) and Kit.noCd(h, COMBAT.cast.rp_reap.type), "사신화 동안 백귀야행 · 영혼 수확의 다시 쓰기가 없다 — 어디서나(2026-11-10 — 보스 방 · 레이드 · 스토리 · 던전도)")
	expect(math.abs(h.buffs.rp_form.t - (COMBAT.kit.reaper.core.form.dur[4] + 5)) < 1e-6, "4차 15초 + 사신 각성 5초")
	room.time += 1
end

-- ② 이중 낫질의 둘째 타가 끌어당긴다(그 전: 화면에서만 멀리 밀었다)
do
	local hit2 = COMBAT.skills.rp_double.hits[2]
	expect((hit2.pull or 0) > 0, "둘째 타에 끌어당김")
	local room, h, a = arena({ rp_double = 20 })
	a.x = X + 44
	room:skillHit(h, hit2, h.x, h.y, 1, 1, nil, "mob", "rp_double")
	expect(a.x < X + 44, ("리퍼 쪽으로 끌려왔다(%.0f → %.0f)"):format(X + 44, a.x))
end

-- ③ 회전 낫(2026-11-01 — 리마스터의 망령 낫을 빼고 리마스터 전으로 되돌렸다): 던진 낫이 가는 길 · 오는 길에 한 번씩 — 두 번
do
	local room, h, a = arena({ rp_throw = 20 })
	h.job = 2
	a.x = X + 120
	local c = room.caster
	local actor = c:actor(h)
	actor.out = { hits = {}, kills = {} }
	expect(c:begin(h, "rp_throw", 1, nil), "회전 낫을 쓴다")
	for _ = 1, 60 do
		room.time += SUB
		c:sub(SUB)
	end
	local n = 0
	for _, e in actor.out.hits do
		if e.mob == a.id then
			n += 1
		end
	end
	eq(n, 2, "두 번 맞는다(가는 길 · 오는 길)")
end

-- ④ 화면의 그림(kits/reaper.luau): 넋 거두기 · 사신의 일격
do
	local kit = Kitset.of("reaper")
	expect(type(kit.onKillFx) == "function", "쓰러뜨리면 넋 · 피가 빨려 드는 그림(onKillFx)")
	expect(type(kit.procs.shade) == "function", "사신화의 그림자 낫 그림(procs.shade)")
	local names = {}
	for _, s in kit.skills do
		names[s.id] = true
	end
	expect(names.rp_throw and names.rp_wisp, "스킬 번호는 그대로(찍은 포인트 · 퀵슬롯)")
end

-- ⑤ 그림자 흡혈(3차 — 2026-11-03 사용자 "몬스터가 안끌려오는데? 플레이어 코앞까지 끌려와야하는거야"): 진짜 사냥터의 졸개는 활동 구간이 좁다(22점짜리도 있다) —
--  끌어당기기는 구간이 아니라 그 졸개가 선 발판의 끝까지 옮기고(Room:pullMob), 구간 밖으로 끌려가면 구간을 넓힌다(다음 걸음에 되돌아가지 않게) · 다시 나타나면 처음 구간
do
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(7))
	local h = Hero.new(1, "reaper")
	h.level, h.job = 70, 3
	h.skills.rp_hands = 20
	Hero.recalc(h)
	h.hp = h.maxHp
	local near, far = room.mobs[1], nil
	for _, mob in room.mobs do
		mob.state, mob.t = "idle", 0
	end
	h.x, h.y, h.dir = (near.a + near.b) / 2, near.y, 1
	for _, mob in room.mobs do -- 같은 층 · 앞 100 ~ 200점 · 활동 구간이 리퍼에게 닿지 않는 졸개
		if mob.y == h.y and mob.x - h.x > 100 and mob.x - h.x < 200 and mob.a > h.x + 20 then
			far = mob
		end
	end
	expect(far ~= nil, "구간이 좁고 먼 졸개가 있다(시험의 바탕)")
	if far then
		local a0, x0 = far.a, far.x
		expect(room.caster:begin(h, "rp_hands", 1, nil), "그림자 흡혈을 쓴다")
		for _ = 1, 60 do
			h.invuln = 5
			room:step({ h }, 1 / 60)
		end
		expect(math.abs(far.x - h.x) <= 20, ("활동 구간(%.0f ~)에 묶이지 않고 리퍼 코앞까지 끌려왔다(%.0f → %.0f · 리퍼 %.0f)"):format(a0, x0, far.x, h.x))
		expect(far.a <= far.x, "끌려온 자리까지 구간이 넓어졌다(되돌아가지 않는다)")
		far.state, far.respawn = "gone", 0
		room:step({ h }, 1 / 60)
		eq(far.a, a0, "다시 나타나면 처음 구간")
	end
end

-- ⑥ 그림자 흡혈은 지형과 상관없이 끌어 모은다(2026-11-03 사용자 "아직도 플레이어 위치까지 몬스터가 안끌려와 보스는 끌려오면 안되는거고 일반몬스터는 지형상관없이 쫙 끌려와야하는건데"):
--  다른 높이의 발판에 선 졸개도 리퍼의 발밑 코앞으로 · 높이를 화면에 보낸다(snapshot의 열셋째) · 다시 나타나면 처음 높이 · 구간 · 보스는 끌려오지 않는다
do
	local room = Room.new("r4d1", SCENES.scenes.r4d1, Random.new(7))
	local h = Hero.new(1, "reaper")
	h.level, h.job = 70, 3
	h.skills.rp_hands = 20
	Hero.recalc(h)
	h.hp = h.maxHp
	local first = room.mobs[1]
	h.x, h.y, h.dir = first.x, first.y, 1
	local up, boss = nil, first -- 리퍼가 선 자리의 졸개를 보스로 친다(끌려오면 곁으로 옮겨진다)
	for _, mob in room.mobs do
		mob.state, mob.t = "gone", 0
		mob.respawn = math.huge
		if not up and mob ~= first and mob.y < h.y - 8 and h.y - mob.y <= 60 and math.abs(mob.x - h.x) <= 150 and not mob.def.boss then
			up = mob
		end
	end
	expect(up ~= nil, "다른 높이의 발판에 선 졸개가 있다(시험의 바탕)")
	if up and boss then
		up.state = "idle"
		local y0, a0, x0 = up.y, up.a, up.x
		expect(room.caster:begin(h, "rp_hands", 1, nil), "그림자 흡혈을 쓴다")
		for _ = 1, 30 do
			h.invuln = 5
			room:step({ h }, 1 / 60)
		end
		-- 2026-11-05 사용자 "리퍼3차스킬이 끝까지 안끌어와도 되니까 몬스터가 스폰은 정상적으로되고, 이동도 정상적으로 되어야해": 다른 높이의 졸개는 제 발판에 그대로(높이가 바뀌지 않는다) —
		--  그 전(11-03): 리퍼의 발판으로 옮겼다가 살아남은 졸개가 그 자리에 머물고 화면과 어긋났다
		eq(up.y, y0, ("다른 높이(%.0f)의 졸개는 제 발판에 그대로 — 리퍼의 발판(%.0f)으로 옮겨지지 않는다"):format(y0, h.y))
		local lo, hi = room:footSpan(up)
		expect(up.x >= lo and up.x <= hi, ("제 발판 안에서만 움직였다(%.0f · 발판 %.0f ~ %.0f)"):format(up.x, lo, hi))
		-- 보스는 끌려오지 않는다: 리퍼 곁의 졸개를 잠깐 보스로 쳐서 같은 타(끌어 모으기)를 맞힌다
		local def, bx, by = boss.def, boss.x, boss.y
		boss.state, boss.def = "idle", setmetatable({ boss = true }, { __index = def })
		boss.x = h.x + 120
		bx = boss.x
		room.caster:strike({ hero = h }, boss, 0, { pull = 800, gather = true }, {})
		boss.def = def
		expect(boss.x == bx and boss.y == by, "보스는 끌려오지 않는다")
		local row
		for _, r in room:snapshot() do
			if r[1] == up.id then
				row = r
			end
		end
		expect(row and row[13] == nil, "높이가 바뀌지 않았으니 높이를 보내지 않는다(화면은 제 발판의 높이로 그린다)")
		up.state, up.respawn = "gone", 0
		room:step({ h }, 1 / 60)
		eq(up.y, y0, "다시 나타나면 처음 높이")
		eq(up.a, a0, "다시 나타나면 처음 구간")
		for _, r in room:snapshot() do
			if r[1] == up.id then
				expect(r[13] == nil, "처음 자리에서는 높이를 보내지 않는다")
			end
		end
	end
end

-- ⑦ 대수확(4차 사냥기 — 2026-11-03 사용자 "4차 사냥기도 플레이어 중심 사거리로 사신이 멋지게 세로로 베어내는 스킬로 … 3차사냥이고 모아서 4차사냥기로 한번에 처리하는 구조로"):
--  리퍼를 가운데로 양옆 120을 한 번에 — 등 뒤의 적도 맞고, 15마리까지 · 그 밖은 맞지 않는다 · 그림자 흡혈 자리를 빼앗지 않는다(둘 다 칸에 남는다)
do
	local room, h = arena({ rp_harvest = 30 })
	h.job = 4
	for i, mob in room.mobs do
		mob.x = if i <= 16 then X + (if i % 2 == 0 then 1 else -1) * (6 + i * 6) else X + 400
	end
	expect(#room.mobs >= 17, "졸개가 17마리 넘게 있다(시험의 바탕)")
	expect(room.caster:begin(h, "rp_harvest", 1, nil), "대수확을 쓴다")
	for _ = 1, 60 do
		h.invuln = 5
		room:step({ h }, SUB)
	end
	local front, back, far = 0, 0, 0
	for i, mob in room.mobs do
		if mob.hp < mob.maxHp then
			if i > 16 then
				far += 1
			elseif mob.x > X then
				front += 1
			else
				back += 1
			end
		end
	end
	expect(front > 0 and back > 0, ("앞(%d) · 등 뒤(%d)의 적이 다 맞는다(리퍼 둘레)"):format(front, back))
	eq(front + back, 15, "한 번에 15마리까지")
	eq(far, 0, "양옆 120 밖은 맞지 않는다")
	local hv
	local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
	for _, t in CLASSES.classes.reaper.tiers do
		for _, s in t.skills do
			if s.id == "rp_harvest" then
				hv = s
			end
		end
	end
	expect(hv and hv.replaces == nil, "대수확은 그림자 흡혈의 칸을 빼앗지 않는다(3차로 모으고 4차로 벤다 — 둘 다 쓴다)")
end

-- ⑧ 대수확의 그림(2026-11-03 사용자 "사신형태 이거아니야 원래 다른스킬들이랑 사신이펙트 다르잖아 그리고 4차 베어내는 이펙트 둥근거 쓰지마" ·
--  그 전 "사신이뒤에서 베는모션을하고 사라지고 베이는 모션이 나오면서 다다다다"): 화면의 그림을 끝까지 돌려 본다 — 사신 = 다른 스킬과 같은 사신 그림자(리퍼의 dslash를 칠흑 0x12161c로) ·
--  크게(두 배 넘게) · 둥근 큰 휘두름(9째 장)은 쓰지 않는다 · 연하게(0.75 아래) · 끝에 사라진다 · 베이는 자국은 캐릭터 앞에 여덟 번 0.045초씩 · 판정의 너비로 퍼진다 ·
--  자국은 손톱 할퀴기 하나(pixelfx로 만든 우리 것 — "손톱효과 만 남기고 다른 이상한 베어내는것처럼 넣은효과는 빼고") · 찍는 장이 모두 그림(fxart rp_harvest5) 안
do
	local FXART = req("ReplicatedStorage/shared/lune/data/fxart.generated")
	local art = FXART.rp_harvest5
	expect(art ~= nil, "대수확의 그림(rp_harvest5)이 있다")
	local kit = Kitset.of("reaper")
	local ev
	for _, s in kit.skills do
		if s.id == "rp_harvest" then
			ev = s.segs[1].ev[1]
		end
	end
	local adds, shots, blits, bad, cur, cutX, cutSrc, phase = {}, {}, 0, 0, nil, {}, {}, nil
	local shade = { n = 0, maxF = -1, minScale = math.huge, maxA = 0, lastA = nil, color = true }
	local ctx = {}
	function ctx:blit(_img, sx, sy, w, h, x, _y, _ox, _oy, _flip, _scale, _alpha)
		blits += 1
		if sx < 0 or sy < 0 or sx + w > art.w or sy + h > art.h then
			bad += 1
		end
		if cur and cur.kind == "cut" then
			table.insert(cutX, x)
			cur.first = cur.first or (sx .. ":" .. sy) -- 그 자국의 첫 장(자국의 가지를 센다)
		end
	end
	local g
	g = {
		x = 200, y = 176, dir = 1, rnd = math.random, art = { rp_harvest5 = art }, s = {},
		fx = { add = function(life, fn, o)
			table.insert(adds, { life = life, fn = fn, kind = if phase == "hit" then "cut" else "smoke", delay = o and o.delay or 0 }) -- 치는 때(after 0.15)에 놓인 것 = 베이는 자국
		end },
		shot = function(o)
			table.insert(shots, o)
		end,
		sprite = function(clip, f, _x, _y, _dir, o)
			shade.n += 1
			shade.maxF = math.max(shade.maxF, if clip == "dslash" then f else 99)
			shade.minScale = math.min(shade.minScale, o.scale or 1)
			shade.maxA, shade.lastA = math.max(shade.maxA, o.alpha), o.alpha
			shade.color = shade.color and o.color == 0x12161c
		end,
		after = function(t, fn)
			phase = if t < 0.2 then "hit" else "smoke"
			fn()
			phase = nil
		end,
		hit = function()
			return {}
		end,
		shake = function() end,
	}
	local ok, err = pcall(function()
		ev(g)
		for _, o in shots do
			for t = 0, o.life + 1e-6, o.life / 40 do
				o.draw(ctx, { t = math.min(t, o.life), life = o.life, x = o.x, y = o.y })
			end
		end
		for _, a in adds do
			cur = a
			for k = 0, 1.0001, 0.05 do
				a.fn(ctx, math.min(k, 1))
			end
		end
	end)
	expect(ok, "대수확의 그림이 오류 없이 돈다 " .. tostring(err))
	local cuts, delays = 0, {}
	for _, a in adds do
		if a.kind == "cut" then
			cuts += 1
			table.insert(delays, a.delay)
		end
	end
	table.sort(delays)
	local lo, hi, kinds = math.huge, -math.huge, 0
	for _, x in cutX do
		lo, hi = math.min(lo, x), math.max(hi, x)
	end
	for _, a in adds do
		if a.kind == "cut" and a.first then
			cutSrc[a.first] = true
		end
	end
	for _ in cutSrc do
		kinds += 1
	end
	expect(shade.n > 0 and shade.color and shade.maxF >= 3 and shade.maxF <= 6, "사신 = 다른 스킬과 같은 칠흑의 dslash · 벤 뒤 거둔다(마지막 장 " .. shade.maxF .. " — 둥근 9째 장은 안 쓴다)")
	expect(shade.minScale >= 2, "사신 그림자가 크다(" .. shade.minScale .. "배)")
	expect(shade.maxA > 0 and shade.maxA <= 0.75 and shade.lastA < 1e-6, "사신 그림자는 연하게(" .. shade.maxA .. ") · 끝에 사라진다(" .. tostring(shade.lastA) .. ")")
	expect(blits > 0 and bad == 0, "찍는 장이 모두 그림 안에 있다(" .. blits .. "번 · 밖 " .. bad .. ")")
	expect(cuts == 8 and math.abs(delays[8] - delays[1] - 7 * 0.045) < 1e-6, "베이는 자국이 0.045초씩 여덟 번(" .. cuts .. ")")
	expect(kinds == 1, "베이는 자국은 손톱 할퀴기 하나(" .. kinds .. "가지)")
	expect(lo <= 200 - 90 and hi >= 200 + 90, "베이는 자국이 판정의 너비로 퍼진다(" .. (lo - 200) .. " ~ " .. (hi - 200) .. ")")
end

-- ⑨ 끌려온 졸개를 잡으면 떨어지는 것이 발판 위에(2026-11-03 사용자 "3차스킬로 당겨서 처치했을 때 지형 안쪽으로 아이템이 떨어져서 못주워"): 진짜 사냥터 r4c1(조사 때 가장 많던 곳)에서
--  리퍼가 졸개마다 그 곁에 서서 그림자 흡혈로 모으면 — 모인 졸개가 선 자리 · 떨어지는 자리(첫째 ~ 다섯째 — Room:dropX)가 모두 디딜 수 있는 발판 위(벽 속 · 허공이 아니다)
do
	local Physics = req("ReplicatedStorage/shared/lune/sim/physics")
	local scene = SCENES.scenes.r4c1
	local function onFloor(x, y)
		local tx, ty = math.floor(x / 16), math.floor(y / 16 + 0.5)
		local under = Physics.cell(scene, tx, ty)
		return Physics.cell(scene, tx, ty - 1) ~= "#" and (under == "#" or under == "=")
	end
	local n, badStand, badDrop = 0, 0, 0
	local base = Room.new("r4c1", scene, Random.new(3))
	for _, anchor in base.mobs do
		if not anchor.away and not anchor.def.boss and not anchor.def.fly then
			local room = Room.new("r4c1", scene, Random.new(3))
			local h = Hero.new(1, "reaper")
			h.level, h.job = 70, 3
			Hero.recalc(h)
			h.x, h.y = anchor.x, anchor.y
			for _, m in room.mobs do
				m.state, m.t = "idle", 0
			end
			for _, m in room.mobs do
				if not m.away and not m.def.boss and not m.def.fly and math.abs(m.x - h.x) <= 150 and m.y - h.y <= 32 and h.y - m.y <= 80 then
					room.caster:strike({ hero = h }, m, 0, { gather = true }, {})
					n += 1
					if not onFloor(m.x, m.y) then
						badStand += 1
					end
					for k = 0, 4 do
						if not onFloor(room:dropX(m, k), m.y) then
							badDrop += 1
						end
					end
				end
			end
		end
	end
	expect(n > 50, "모은 졸개가 충분하다(" .. n .. ")")
	expect(badStand == 0, "모인 졸개가 발판 위에 선다(벽 속 · 허공 " .. badStand .. ")")
	expect(badDrop == 0, "떨어지는 것이 발판 위에 놓인다(벽 속 · 허공 " .. badDrop .. ")")
end
