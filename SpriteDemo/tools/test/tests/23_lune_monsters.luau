-- 「달의 계승자」 — 새 몬스터(1지역의 열둘 + 2지역 수정이 자라는 숲의 넷): 자료의 짜임 · 배치 · 몸 크기 · 양쪽 치기 · 제자리 · 나는 몬스터 · 쏘는 몬스터 · 마법 · 터지는 몬스터
--  사용자 2026-10-09: "어느몬스터를 어디에 배치해야하는지 정확하게 파악하고 게임에 적용하세요"
--  자료는 공방(dino-workshop)에서 온다: 배치 js/lune/design/monsterPlace.js · 수치 monsters.js(MONSTER_PLAY) → monsterMobs.js · 마법 monsterFx.js.
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local DT = 1 / 20

-- 어느 몬스터가 어느 장면에 몇 마리(배치 표의 1지역 — 달그림자 사냥터의 장면 이름은 hunt)
local PLACE = {
	-- 1지역(2026-10-14 — 한 맵에 한 종류): 제 몬스터가 주인인 맵. 나머지 맵의 주인은 병사다(아래 ONE). 수련 인형은 사당 지하(2차 전직 동안만)
	r1a3 = { puff = 11 }, r1a4 = { crow = 9 }, r1b3 = { crab = 5 }, r1b4 = { mole = 11 }, r1c3 = { helm = 9 }, in_cellar = { dummy = 4 },
	-- 2지역 수정이 자라는 숲(2026-10-09 밤): 병사 없이 제 몬스터만
	r2a1 = { stump = 9 }, r2a2 = { snail = 11 }, r2a3 = { frog = 8 }, r2a4 = { spider = 9 },
	r2b1 = { fox = 9 }, r2b2 = { bud = 12 }, r2b3 = { quill = 10 }, r2b4 = { dshard = 9 },
	r2c1 = { golem = 10 }, r2c2 = { censer = 9 }, r2c3 = { bell = 9 },
	-- 3지역 땅속 화롯골의 첫 구역(내려가는 굴)
	r3a1 = { rat = 10 }, r3a2 = { stalag = 10 }, r3a3 = { kobold = 10 }, r3a4 = { cart = 8 },
	r3b1 = { slag = 10 }, r3b2 = { worm = 10 }, r3c1 = { cinder = 10 }, r3c2 = { chimney = 8 }, r3c3 = { anvil = 8 },
	-- 4지역 만월성의 첫 구역(병사와 같이) · 물마루 바다의 뭍
	r4a3 = { banner = 6 }, r4a4 = { statue = 5 }, sea1 = { clam = 10 }, sea2 = { barnacle = 9 }, sea3 = { jelly = 10 }, sea4 = { eel = 10 }, sea7 = { anchor = 9 }, sea5 = { tangle = 5, urchin = 5 }, sea6 = { mimic = 9 }, r3b3 = { thief = 10 }, r4d3 = { gloom = 9 }, r4e1 = { pool = 9 },
	-- 3지역의 분화구 · 4지역의 내성과 봉인의 회랑
	r3d3 = { scorpion = 10 }, r4c2 = { book = 6 }, r4d1 = { eye = 10 }, r4d2 = { mage = 9 },
}
-- 1지역의 사냥터: 한 맵에 한 종류 · 한 종류는 한 맵(사용자 2026-10-14: "퀘스트에는 등장하지도않는 폭탄병이랑 큰 달버섯이 맵구조의 절반 젠을 담당해버리는겁니다 … 궁병이 중복으로 등장할 이유가없음")
local ONE = { r1a1 = "trainee", hunt = "warrior", r1a3 = "puff", r1a4 = "crow", r1b1 = "archer", r1b2 = "bomber", r1b3 = "crab", r1b4 = "mole", r1c1 = "ewarrior", r1c2 = "earcher", r1c3 = "helm" }
-- 1지역에서 빠져 쉬는 제 몬스터(맵이 모자라 — 2026-10-14): 싸움 수치와 그림은 남는다 · 어느 장면에도 없다. 동작 시험은 빌린 자리에서 그 레벨로 한다
local BENCH = { shroom = 2, bigshroom = 5, piglet = 12, goat = 15, bat = 16, torch = 24 }

-- ---- 1) 자료의 짜임 ----
local newKinds = 0
for kind, m in COMBAT.mobs do
	if m.bare and not m.story then -- 스토리 보스(bare이지만 졸개가 아니다)는 33_lune_boss.luau가 본다
		newKinds += 1
		local char = CHARS.chars[m.sprite]
		expect(char ~= nil, "새 몬스터의 그림 " .. kind)
		for _, c in { "idle", "run", "atk" } do
			expect(char.clips[c] ~= nil and #char.clips[c].frames > 0, ("새 몬스터의 동작 %s.%s"):format(kind, c))
		end
		expect(m.body ~= nil and m.body[1] > 0 and m.body[2] > 0, "새 몬스터의 몸 크기 " .. kind)
		expect(m.atk.windup < m.atk.time, "치는 때가 동작 안이다 " .. kind)
		expect(m.atk.frame < #char.clips.atk.frames, "맞는 장이 동작 안이다 " .. kind)
		if m.atk.cast then
			local clip = char.clips[m.atk.cast.clip]
			expect(clip ~= nil and clip.ox ~= nil and clip.oy ~= nil, "마법 그림과 그 기준점 " .. kind)
			-- 예고: 발밑 · 몸에 뜨는 마법은 뜨고 나서 맞기까지(wait), 앞으로 뻗는 마법(front — 등불 해파리)은 몸이 먼저 밝아지는 동작(windup)까지 더한 시간
			local lead = if m.atk.cast.place == "front" then m.atk.windup + m.atk.cast.wait else m.atk.cast.wait
			expect(lead > 0.2, ("마법은 예고가 있다(피할 틈) %s — %.2f초"):format(kind, lead))
			if m.atk.cast.place == "front" then
				expect(m.atk.cast.from ~= nil and #m.atk.cast.from == 2, "앞으로 뻗는 마법은 나오는 자리(from)가 있다 " .. kind)
			end
			expect(m.atk.cast.wait < m.atk.cast.life, "맞는 때가 마법 그림 안이다 " .. kind)
			expect(math.abs(m.atk.cast.life - #clip.frames / clip.fps) < 0.01, "마법 그림의 길이 " .. kind)
		end
		if m.atk.shot and m.atk.shot.clip then
			local clip = char.clips[m.atk.shot.clip]
			expect(clip ~= nil and clip.ox ~= nil, "날아가는 그림과 그 기준점 " .. kind)
			if kind == "frog" then
				-- 따로 그린 날아가는 이펙트(침 덩어리): 두 장을 돌려 가며 그린다(빈 투구의 덩어리는 한 장)
				eq(#clip.frames, 2, "침 덩어리는 두 장")
			end
		end
		if m.fly then
			-- 사용자 2026-10-09: "박쥐가 너무 높이있는데 그냥 때릴수가없어서" — 서서 치는 기술이 닿는 높이(발에서 16점) 아래에 몸의 아래 끝이 있어야 한다
			expect(m.fly.alt + m.fly.bob < 16, "나는 몬스터는 서서 치는 기술로 맞는다 " .. kind)
			expect(m.fly.low < m.fly.alt, "덮칠 때 더 낮아진다 " .. kind)
		end
	end
end
eq(newKinds, 49, "새 몬스터 마흔아홉(바닷속의 셋 · 남은 맵의 여섯 포함)")

-- ---- 2) 배치: 표대로 놓였는가 · 레벨이 그 장면의 다른 몬스터와 이어지는가 · 퀘스트의 병사가 남았는가 ----
local placed = {}
for key, want in PLACE do
	local scene = SCENES.scenes[key]
	expect(scene ~= nil, "장면 " .. key)
	local count = {}
	for _, m in scene.mobs do
		count[m.kind] = (count[m.kind] or 0) + 1
		expect(COMBAT.mobs[m.kind] ~= nil, ("%s: 아는 종류 %s"):format(key, m.kind))
	end
	for kind, n in want do
		eq(count[kind] or 0, n, ("%s의 %s"):format(key, kind))
		expect(placed[kind] == nil, "한 몬스터는 한 장면에만 " .. kind)
		placed[kind] = key
	end
end
do
	local owner = {}
	for key, kind in ONE do
		local scene = SCENES.scenes[key]
		local kinds = {}
		for _, m in scene.mobs do
			kinds[m.kind] = true
		end
		local n = 0
		for k in kinds do
			n += 1
			expect(owner[k] == nil, ("%s가 두 맵에 있다(%s · %s)"):format(k, tostring(owner[k]), key))
			owner[k] = key
		end
		expect(n == 1 and kinds[kind], ("%s에는 %s 한 종류만"):format(key, kind))
	end
	for key, scene in SCENES.scenes do
		if scene.region == "r1" and not scene.story and not scene.tut and #scene.mobs > 0 then -- tut = 튜토리얼의 꿈(사냥터가 아니다)
			expect(ONE[key] ~= nil, "1지역의 사냥터는 모두 표에 있다 " .. key)
		end
	end
end
for kind, m in COMBAT.mobs do
	if m.bare and not m.story then
		expect((placed[kind] ~= nil) ~= (BENCH[kind] ~= nil), "새 몬스터는 놓였거나 쉰다(둘 다는 아니다) " .. kind)
	end
end
-- 새 몬스터는 표에 없는 장면에는 없다
for key, scene in SCENES.scenes do
	for _, m in scene.mobs do
		-- 이야기의 방(사당 지하 — 2차 전직의 수련 인형)은 사냥터가 아니다: 그 퀘스트를 하는 동안에만 나온다(2026-10-13)
		if COMBAT.mobs[m.kind].bare and not scene.story and not scene.tut then -- tut = 튜토리얼의 꿈(2026-10-14 — 수련 인형을 빌려 쓴다)
			eq(placed[m.kind], key, ("%s는 %s에만"):format(m.kind, tostring(placed[m.kind])))
		end
	end
end

-- ---- 도우미 ----
local function fresh(class, lv)
	local hero = Hero.new(9, class)
	if lv > 1 then
		local xp = 0
		for L = 1, lv - 1 do
			xp += N.xpNeed(L)
		end
		Hero.gainXp(hero, xp)
	end
	return hero
end
-- 그 종류 한 마리만 있는 방(그 몬스터가 놓인 장면에서 구간이 가장 넓은 자리)
local function solo(kind, seed)
	local scene = SCENES.scenes[placed[kind] or "hunt"] -- 쉬는 몬스터는 달그림자 사냥터의 자리를 빌린다
	local def = nil
	for _, m in scene.mobs do
		if (m.kind == kind or BENCH[kind]) and (not def or m.range[2] - m.range[1] > def.range[2] - def.range[1]) then
			def = m
		end
	end
	assert(def, kind .. "가 없다")
	if BENCH[kind] then
		def = table.clone(def)
		def.kind, def.lv = kind, BENCH[kind]
	end
	local one = { w = scene.w, h = scene.h, rows = scene.rows, spawn = scene.spawn, mobs = { def } }
	local r = Room.new("solo", one, Random.new(seed))
	for _ = 1, 30 do
		r:step({}, DT) -- 나타나는 동안
	end
	return r, r.mobs[1]
end
local function play(room, hero, seconds, each)
	local all = {}
	for i = 1, math.floor(seconds / DT + 0.5) do
		Hero.tick(hero, DT)
		for _, e in room:step({ [hero.id] = hero }, DT) do
			table.insert(all, e)
		end
		if each then
			each(i, all)
		end
	end
	return all
end
local function countOf(events, kind)
	local n = 0
	for _, e in events do
		if e.type == kind then
			n += 1
		end
	end
	return n
end

-- ---- 3) 걸어 다니며 치는 몬스터: 다가와 제 수치대로 친다(달버섯 · 큰 달버섯 · 재까마귀 · 엄니 새끼 · 바위 산양 · 수련 인형 · 바위 게) ----
for _, kind in { "shroom", "bigshroom", "crow", "piglet", "goat", "dummy", "crab" } do
	local room, mob = solo(kind, 5)
	local me = fresh("axion", math.max(1, mob.lv))
	me.x, me.y = math.clamp(mob.x + 14, mob.a, mob.b), mob.y
	local ev = play(room, me, 6)
	local hurt = countOf(ev, "hurt")
	expect(hurt >= 1, ("%s가 다가와 친다(%d)"):format(kind, hurt))
	for _, e in ev do
		if e.type == "hurt" then
			eq(e.dmg, math.max(1, math.floor(N.rawHit("mob", mob.lv) * (1 - Hero.cut(me, mob.lv) / 100) * mob.def.atk.mul + 0.5)), kind .. "의 한 방")
			break
		end
	end
	expect(mob.x >= mob.a - 0.01 and mob.x <= mob.b + 0.01, kind .. "는 제 구간을 벗어나지 않는다")
end

-- ---- 4) 몸 크기: 큰 몬스터는 넓게 맞고, 병사는 그대로다 ----
do
	local room, big = solo("bigshroom", 3)
	local hw = big.def.body[1] / 2
	expect(hw > 10, "큰 달버섯의 몸은 병사(반폭 6)보다 넓다")
	eq(#room:mobsInBox(big.x + hw - 2, big.x + hw - 1, big.y - 8, big.y - 4, big.x), 1, "큰 달버섯: 몸의 가장자리가 맞는다")
	eq(#room:mobsInBox(big.x + hw + 2, big.x + hw + 6, big.y - 8, big.y - 4, big.x), 0, "큰 달버섯: 몸 밖은 맞지 않는다")
	eq(#room:mobsInBox(big.x - 2, big.x + 2, big.y - big.def.body[2] + 1, big.y - big.def.body[2] + 2, big.x), 1, "큰 달버섯: 머리 높이도 맞는다")
	local roomS, soldier = solo("crab", 3) -- 병사와 견주려고: 같은 식으로 병사 한 마리
	local sceneH = SCENES.scenes.hunt
	local wdef = nil
	for _, m in sceneH.mobs do
		if m.kind == "warrior" and not wdef then
			wdef = m
		end
	end
	local rw = Room.new("w", { w = sceneH.w, h = sceneH.h, rows = sceneH.rows, spawn = sceneH.spawn, mobs = { wdef } }, Random.new(1))
	for _ = 1, 30 do
		rw:step({}, DT)
	end
	local w = rw.mobs[1]
	eq(#rw:mobsInBox(w.x + 5, w.x + 6, w.y - 8, w.y - 4, w.x), 1, "병사의 몸은 그대로다(반폭 6)")
	eq(#rw:mobsInBox(w.x + 8, w.x + 12, w.y - 8, w.y - 4, w.x), 0, "병사의 몸 밖")
	expect(soldier ~= nil and roomS ~= nil, "게")
end

-- ---- 5) 양쪽 치기(바위 게): 치는 동안 뒤로 돌아가도 맞는다 ----
do
	local room, crab = solo("crab", 9)
	local me = fresh("axion", crab.lv)
	me.x, me.y = math.clamp(crab.x + 10, crab.a, crab.b), crab.y
	local jumped, hurtAfter = false, 0
	play(room, me, 6, function(_, all)
		if crab.state == "atk" and not jumped and crab.t < crab.def.atk.windup - 0.1 then
			jumped = true
			me.x = crab.x - crab.dir * 12 -- 등 뒤로
		end
		if jumped and #all > 0 and all[#all].type == "hurt" then
			hurtAfter += 1
		end
	end)
	expect(jumped, "게가 치기 시작했다")
	expect(hurtAfter >= 1, "게의 집게는 뒤에 있어도 맞는다")
	expect(crab.def.atk.both == true, "게는 양쪽을 친다")
end

-- ---- 6) 제자리 몬스터(굴 두더지): 오가지 않고 밀리지도 않는다 · 다가가면 친다 ----
do
	local room, mole = solo("mole", 4)
	local x0 = mole.x
	for _ = 1, 400 do
		room:step({}, DT)
	end
	eq(mole.x, x0, "두더지는 오가지 않는다")
	room:damageMob(mole, 1, mole.x - 20, 9)
	eq(mole.x, x0, "두더지는 맞아도 밀리지 않는다")
	for _ = 1, 10 do
		room:step({}, DT)
	end
	local me = fresh("axion", mole.lv)
	me.x, me.y = x0 - 16, mole.y -- 왼쪽에 서도
	local ev = play(room, me, 5)
	expect(countOf(ev, "hurt") >= 1, "두더지는 다가온 사람을 친다(어느 쪽이든)")
	eq(mole.x, x0, "두더지는 칠 때도 제자리다")
end

-- ---- 7) 나는 몬스터(골짜기 박쥐): 떠서 오가다가 덮친다 · 높이는 상태와 시간에서 나온다 ----
do
	local room, bat = solo("bat", 6)
	local fly, atk = bat.def.fly, bat.def.atk
	eq(bat.alt, fly.alt, "박쥐는 제 높이에 떠 있다")
	-- 떠 있는 몸: 발밑 높이의 네모에는 걸리지 않고, 몸 높이의 네모에 걸린다
	eq(#room:mobsInBox(bat.x - 4, bat.x + 4, bat.y - 6, bat.y, bat.x), 0, "박쥐: 발밑은 빈 곳이다")
	eq(#room:mobsInBox(bat.x - 4, bat.x + 4, bat.y - fly.alt - 8, bat.y - fly.alt - 2, bat.x), 1, "박쥐: 떠 있는 몸이 맞는다")
	eq(#room:mobsInBox(bat.x - 4, bat.x + 4, bat.y - 16, bat.y - 12, bat.x), 1, "박쥐: 서서 치는 높이(발에서 16점)에 닿는다")
	local me = fresh("riven", bat.lv)
	me.x, me.y = math.clamp(bat.x + 30, bat.a, bat.b), bat.y
	local lowest, dove, hurt = fly.alt, false, 0
	play(room, me, 5, function(_, all)
		if bat.state == "atk" then
			dove = true
			lowest = math.min(lowest, bat.alt)
		end
		if #all > 0 and all[#all].type == "hurt" then
			hurt += 1
		end
		expect(bat.x >= bat.a - 0.01 and bat.x <= bat.b + 0.01, "박쥐는 제 구간 안에서 덮친다")
	end)
	expect(dove, "박쥐가 덮친다")
	expect(lowest <= fly.low + 0.5, ("덮칠 때 낮게 내려온다(%.1f)"):format(lowest))
	expect(hurt >= 1, "덮쳐서 맞힌다")
	-- 덮치는 시간이 끝나면 다시 제 높이
	for _ = 1, math.floor((atk.time + 0.2) / DT) do
		room:step({}, DT)
	end
	eq(bat.alt, fly.alt, "덮친 뒤 제 높이로 돌아온다")
end

-- ---- 8) 쏘는 몬스터(빈 투구): 다가오지 않고 제 덩어리를 쏜다(종류가 실려 간다 · 나오는 자리) ----
do
	local room, helm = solo("helm", 8)
	local x0 = helm.x
	local me = fresh("riven", helm.lv)
	me.x, me.y = math.clamp(helm.x + 60, 8, room.scene.w * 16 - 8), helm.y
	local shots, hurt = 0, 0
	local ev = play(room, me, 8)
	for _, e in ev do
		if e.type == "shot" then
			shots += 1
			eq(e.kind, "helm", "쏜 종류가 실려 간다")
			eq(e.y, helm.y - helm.def.atk.shot.dy, "덩어리가 나오는 높이")
			eq(e.speed, helm.def.atk.shot.speed, "덩어리의 빠르기")
		elseif e.type == "hurt" then
			hurt += 1
		end
	end
	expect(shots >= 1 and hurt >= 1, ("투구가 쏘고 맞힌다(쏜 것 %d · 맞은 것 %d)"):format(shots, hurt))
	expect(helm.def.chase == 0, "투구는 쫓지 않는다")
	-- 바짝 붙어 서도 맞는다(덩어리는 몸의 27점 앞에서 생긴다 — 그 사이가 빈 곳이면 안 된다)
	local room2, helm2 = solo("helm", 8)
	local close = fresh("riven", helm2.lv)
	close.x, close.y = helm2.x + 12, helm2.y
	local evc = play(room2, close, 8)
	expect(countOf(evc, "hurt") >= 1, "투구에 바짝 붙어 서도 맞는다")
	eq(countOf(evc, "shot"), 0, "붙어서 맞으면 덩어리는 날아가지 않는다")
	expect(math.abs(helm.x - x0) <= helm.b - helm.a + 0.01, "투구는 제 구간 안")
end

-- ---- 9) 마법(횃불지기): 몸 동작과 따로 뜨는 달불 기둥 — 그 자리에 있으면 맞고, 예고 동안 비키면 맞지 않는다 ----
do
	local cast = COMBAT.mobs.torch.atk.cast
	-- 그 자리에 서 있으면 맞는다
	local room, torch = solo("torch", 2)
	local me = fresh("axion", torch.lv)
	me.x, me.y = math.clamp(torch.x + 40, 8, room.scene.w * 16 - 8), torch.y
	local castAt, hurtAt = nil, nil
	local ev = play(room, me, 6, function(i, all)
		local e = all[#all]
		if e and e.type == "cast" and not castAt then
			castAt = i
			eq(e.kind, "torch", "마법을 쓴 종류")
			eq(e.x, me.x, "마법은 그때 사람이 선 자리에")
			eq(e.y, torch.y, "발밑의 땅에")
		elseif e and e.type == "hurt" and castAt and not hurtAt then
			hurtAt = i
		end
	end)
	expect(castAt ~= nil, "횃불지기가 마법을 쓴다")
	expect(hurtAt ~= nil, "그 자리에 서 있으면 맞는다")
	if castAt and hurtAt then
		expect(math.abs((hurtAt - castAt) * DT - cast.wait) <= DT * 1.5, ("예고(%.2f초) 뒤에 맞는다 — %.2f초"):format(cast.wait, (hurtAt - castAt) * DT))
	end
	expect(countOf(ev, "cast") >= 1, "마법이 뜬다")
	-- 예고 동안 비키면 맞지 않는다
	local room2, torch2 = solo("torch", 2)
	local runner = fresh("axion", torch2.lv)
	runner.x, runner.y = math.clamp(torch2.x + 40, 8, room2.scene.w * 16 - 8), torch2.y
	local dodged, hurt2 = false, 0
	play(room2, runner, 2.5, function(_, all)
		local e = all[#all]
		if e and e.type == "cast" and not dodged then
			dodged = true
			runner.x = e.x + cast.w + 20 -- 기둥의 폭 밖으로
		end
	end)
	for _, e in play(room2, runner, 0.1) do
		if e.type == "hurt" then
			hurt2 += 1
		end
	end
	expect(dodged, "마법이 떴다")
	eq(runner.hp, runner.maxHp, "예고 동안 비키면 맞지 않는다")
	eq(hurt2, 0, "비킨 뒤에도 맞지 않는다")
	-- 마법은 끝까지 돌고 사라진다
	for _ = 1, math.floor((cast.life + 0.5) / DT) do
		room2:step({}, DT)
	end
	expect(torch2.def.chase == 0, "횃불지기는 쫓지 않는다")
end

-- ---- 10) 터뜨리는 몬스터(포자 주머니): 다가와 터뜨린다 — 사라지지 않고 기다렸다가 또 터뜨린다(폭탄병과 같다 · 사용자 2026-10-11) ----
do
	local room, puff = solo("puff", 13)
	local victim = fresh("mooni", puff.lv)
	victim.x, victim.y = math.clamp(puff.x + 20, puff.a, puff.b), puff.y
	local ev = play(room, victim, 6)
	eq(countOf(ev, "burst"), 0, "「터져서 사라졌다」는 일은 없다")
	expect(countOf(ev, "hurt") >= 2, ("6초 동안 되풀이해 터뜨린다(%d번)"):format(countOf(ev, "hurt")))
	expect(puff.hp > 0 and puff.state ~= "gone" and puff.state ~= "dead", "터뜨린 포자 주머니는 사라지지 않는다 " .. puff.state)
end

-- ---- 11) 앞으로 뻗는 마법(등불 해파리 — 2026-10-10 바닷속을 게임에 옮기며): 몬스터의 앞에 붙는다. 앞에 서 있으면 맞고, 예고 동안 뒤로 돌아가면 맞지 않는다 ----
do
	local cast = COMBAT.mobs.jelly.atk.cast
	eq(cast.place, "front", "해파리의 번개는 앞으로 뻗는다")
	-- 앞에 서 있으면 맞는다
	local room, jelly = solo("jelly", 3)
	local me = fresh("axion", jelly.lv)
	me.x, me.y = jelly.x + 30, jelly.y
	local seen = nil
	local ev = play(room, me, 8, function(_, all)
		local e = all[#all]
		if e and e.type == "cast" and not seen then
			seen = e
		end
	end)
	expect(seen ~= nil, "해파리가 번개를 쓴다")
	if seen then
		eq(seen.kind, "jelly", "번개를 쓴 종류")
		eq(seen.dir, 1, "쓴 쪽(오른쪽)을 알린다")
		expect(seen.x > jelly.x - 1 and math.abs(seen.x - (jelly.x + cast.from[1])) <= 12, "번개는 해파리의 앞에서 나온다")
		eq(seen.y, jelly.y - cast.from[2], "갓의 높이에서")
	end
	expect(countOf(ev, "hurt") >= 1, "앞에 서 있으면 맞는다")
	-- 예고 동안 뒤로 돌아가면 맞지 않는다(번개가 사라질 때까지)
	local room2, jelly2 = solo("jelly", 3)
	local runner = fresh("axion", jelly2.lv)
	runner.x, runner.y = jelly2.x + 30, jelly2.y
	local hurt, castSeen, left = 0, false, nil
	for _ = 1, math.floor(10 / DT) do
		Hero.tick(runner, DT)
		for _, e in room2:step({ [runner.id] = runner }, DT) do
			if e.type == "cast" and not castSeen then
				castSeen = true
				runner.x = jelly2.x - 30 -- 등 뒤로
				left = cast.life + 0.1
			elseif e.type == "hurt" and castSeen then
				hurt += 1
			end
		end
		if left then
			left -= DT
			if left <= 0 then
				break
			end
		end
	end
	expect(castSeen, "해파리가 번개를 쓴다(뒤로 도는 쪽)")
	eq(hurt, 0, "뒤로 돌아가면 맞지 않는다")
end

-- ---- 12) 바닷속의 움직임(scene.sea): 걷기는 조금 느리고, 뛰면 느리게 높이 떴다가 천천히 가라앉는다(공방 combat.js의 sea) ----
do
	local P = req("ReplicatedStorage/shared/lune/sim/physics")
	local SEA = COMBAT.rules.sea
	for _, key in { "sea3", "seaf", "sea4", "sea7" } do
		expect(SCENES.scenes[key] ~= nil and SCENES.scenes[key].sea == true, key .. "는 바닷속이다")
	end
	expect(SCENES.scenes.sea1.sea ~= true and SCENES.scenes.hunt.sea ~= true, "땅 위의 맵은 바닷속이 아니다")
	local function jump(sea)
		local rows = {}
		for y = 0, 13 do
			rows[y + 1] = if y >= 11 then string.rep("#", 60) else string.rep(".", 60)
		end
		local sc = { w = 60, h = 14, rows = rows, spawn = { x = 100, y = 176 }, sea = sea }
		local b = { x = 100, y = 176, vx = 0, vy = 0, ground = true }
		local top, n = 176, 0
		P.step(sc, b, { mx = 1, jump = true }, DT)
		while not b.ground and n < 4000 do
			n += 1
			top = math.min(top, b.y)
			P.step(sc, b, { mx = 1 }, DT)
		end
		return 176 - top, n * DT, b.x - 100
	end
	local h0, t0, d0 = jump(false)
	local h1, t1, d1 = jump(true)
	expect(h0 > 45 and h0 <= 58, ("땅에서 뛰는 높이 57점쯤 — %.1f"):format(h0))
	expect(h1 > h0 * 1.4 and h1 < h0 * 2, ("바닷속에서는 더 높이 뜬다 — %.1f점"):format(h1))
	expect(t1 > t0 * 1.8, ("더 오래 떠 있다 — %.2f초(땅 %.2f초)"):format(t1, t0))
	expect(d1 > d0 * 1.5, ("뛰는 동안 옆으로 더 멀리 간다 — %.0f점(땅 %.0f점)"):format(d1, d0))
	-- 걷기: 같은 시간에 85%만 간다
	local function walk(sea)
		local rows = {}
		for y = 0, 13 do
			rows[y + 1] = if y >= 11 then string.rep("#", 60) else string.rep(".", 60)
		end
		local sc = { w = 60, h = 14, rows = rows, spawn = { x = 100, y = 176 }, sea = sea }
		local b = { x = 100, y = 176, vx = 0, vy = 0, ground = true }
		for _ = 1, 60 do
			P.step(sc, b, { mx = 1 }, DT)
		end
		return b.x - 100
	end
	local w0, w1 = walk(false), walk(true)
	expect(math.abs(w1 / w0 - SEA.run) < 0.02, ("바닷속의 걷기는 땅의 %d%% — %.0f / %.0f점"):format(SEA.run * 100, w1, w0))
end
