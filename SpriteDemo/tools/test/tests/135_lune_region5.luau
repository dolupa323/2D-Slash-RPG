-- 「달의 계승자」 — 5지역 윤슬 호수 · 제5편 「달이 고이는 곳」(2026-11-07 — 공방 design/world.js의 r5 · questplay.js의 PLAY5 · cine.js의 r5_* · maps.js의 r5t ~ r5s · city.js의 별고래).
--  사용자: "현재 가장 레벨높은 사냥터 이후로 신지역을 출시하고 … 신지역에서는 다음 사냥터와 메인 마을도 있어야하고, 비행선, 배 말고 새로운 재미있는 그 마을 컨셉에 맞는 새로운 이동수단으로 이동하게 해줘"
--   · "현재 메인스토리와 자연스럽게 이야기가 이어져야해"
local D = req("ReplicatedStorage/shared/lune/data/quests.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CITY = req("ReplicatedStorage/shared/lune/data/city.generated")
local CINE = req("ReplicatedStorage/shared/lune/data/cine.generated")
local WM = req("ReplicatedStorage/shared/lune/data/worldmap.generated")

local Q = {}
for _, def in D.list do
	Q[def.id] = def
end
-- 아직 열지 않은 지역(2026-11-10 사용자 "일단 신지역은 아직 막아둬" — 공방 world.js CLOSED_REGIONS): 닫혀 있으면 ①의 「할 수 있다」 · ⑥의 「호수의 의뢰가 나온다」 대신 닫힌 것을 본다(⑦). 열면 원래대로
local CLOSED = WM.regions.r5 ~= nil and WM.regions.r5.closed == true

-- ① 메인 열둘: 4편의 끝(「봉인의 문」 r4m9) 뒤에 이어 열린다 · 한 줄 · 모두 할 수 있다 · 일곱째까지 Lv.150 안 · 여덟째부터(물안개 숲 · 등롱 사당 · 달빛 버드나무 · 심연 · 용의 무덤 — 2026-11-11 · 다시 놓기 저녁)는 Lv.150~160 안
for i = 1, 12 do
	local q = Q["r5m" .. i]
	expect(q ~= nil, "메인 r5m" .. i .. "가 있다")
	if q then
		if CLOSED then
			expect(q.kind == "main" and not q.playable, q.id .. ": 닫힌 지역 — 받지 못하는 메인")
		else
			expect(q.kind == "main" and q.playable, q.id .. ": 할 수 있는 메인")
		end
		if i <= 7 then
			expect(q.lv <= 150, q.id .. ": Lv.150 안(Lv.150부터 한 레벨이 아주 길다) — " .. q.lv)
		else
			expect(q.lv > 150 and q.lv <= 160, q.id .. ": Lv.150~160 안(윤슬 호수의 깊은 곳) — " .. q.lv)
		end
		eq(q.after, if i == 1 or CLOSED then "r4m9" else "r5m" .. (i - 1), q.id .. ": 앞의 메인을 끝내야 열린다(닫혀 있으면 모두 「봉인의 문」 뒤 — 받지는 못한다)")
		for _, st in q.steps do
			expect(st.type ~= "boss", q.id .. ": 메인은 보스와 싸우지 않는다")
			if st.type == "kill" or st.type == "gather" then
				local scene = SCENES.scenes[q.scene]
				local has = false
				for _, m in (scene and scene.mobs) or {} do
					if m.kind == st.mob then
						has = true
					end
				end
				expect(has, q.id .. ": 잡을 몬스터 " .. tostring(st.mob) .. "가 그 맵(" .. tostring(q.scene) .. ")에 산다")
			end
		end
	end
end

-- ② 맵: 마을 하나 · 사냥터 다섯(한 맵 = 한 몬스터 — 넷째 · 다섯째 2026-11-11) · 이야기 맵
local want = { r5t = 0, r5a1 = "lotusbud", r5a2 = "starshard", r5a3 = "rippleknight", r5s = 0, r5a4 = "mistcrane", r5a5 = "lurefish", r5b1 = 0, r5b2 = "willowisp", r5c1 = 0 } -- (등롱 사당 · 달빛 버드나무 · 용의 무덤 — 2026-11-11 저녁)
for id, mob in want do
	local s = SCENES.scenes[id]
	expect(s ~= nil, "장면 " .. id)
	if s then
		local kinds = {}
		for _, m in s.mobs or {} do
			kinds[m.kind] = true
		end
		if mob == 0 then
			expect(next(kinds) == nil, id .. ": 몬스터가 없다")
		else
			local n = 0
			for _ in kinds do
				n += 1
			end
			expect(n == 1 and kinds[mob], id .. ": 몬스터는 " .. mob .. " 한 종류")
		end
	end
end
expect(SCENES.homes and SCENES.homes.r5t ~= nil, "물별 마을은 귀환 · 쓰러졌을 때의 마을(HOMES)")

-- ③ 별고래: 만월성 옛 근위대 숙소 ↔ 물별 마을 · 「봉인의 문」을 마친 뒤 · 갑판 장면이 있다 · 고래지기가 두 곳에
local out, home
for _, r in CITY.voyage.routes do
	if r.id == "r4ch_r5t" then
		out = r
	elseif r.id == "r5t_r4ch" then
		home = r
	end
end
expect(out and out.kind == "whale" and out.from == "r4ch" and out.to == "r5t" and out.need == "r4m9", "별고래: 옛 근위대 숙소 → 물별 마을(r4m9 뒤)")
expect(home and home.kind == "whale" and home.from == "r5t" and home.to == "r4ch", "별고래: 물별 마을 → 옛 근위대 숙소")
expect(SCENES.scenes.whale_out ~= nil and SCENES.scenes.whale_home ~= nil, "별고래의 등(갑판 장면) 둘")
for _, sid in { "r4ch", "r5t" } do
	local found = false
	for _, n in SCENES.scenes[sid].npcs or {} do
		if n.id == "whalekeeper" then
			found = true
		end
	end
	expect(found, sid .. ": 고래지기 단비가 선다")
end

-- ④ 장면: 사제의 약속 · 도착 · 다섯 집안 · 석상 · 달샘의 용 · 끝(물음으로 닫는다)
local C = {}
for _, c in CINE.list or CINE.cines or {} do
	C[c.id] = c
end
for _, id in { "r5_promise", "r5_arrive", "r5_five", "r5_statue", "r5_spring", "r5_end" } do
	expect(C[id] ~= nil, "장면 " .. id)
end

-- ⑤ 월드맵: 윤슬 호수 탭과 마을 · 사냥터 셋
local reg = WM.regions.r5
expect(reg ~= nil, "월드맵에 윤슬 호수")
if reg then
	local ids = {}
	for _, n in reg.nodes do
		ids[n.id] = true
	end
	for _, id in { "r5t", "r5a1", "r5a2", "r5a3", "r5s", "r5a4", "r5a5", "r5b1", "r5b2", "r5c1" } do
		expect(ids[id], "월드맵 마디 " .. id)
	end
end

-- ⑥ 기도 탑(모든 지역의 사냥터에서 뽑는 일일 의뢰): 별고래를 탈 수 없는 사람(4편 「봉인의 문」을 끝내지 않음)에게는 호수의 의뢰가 나오지 않는다(2026-11-07)
do
	local Daily = req("ReplicatedStorage/shared/lune/sim/daily")
	local DD = req("ReplicatedStorage/shared/lune/data/daily.generated")
	local lake = { lotusbud = true, starshard = true, rippleknight = true, mistcrane = true, lurefish = true, willowisp = true, lotustoad = true, lakeserpent = true, lanternturtle = true } -- (두루미 · 아귀 2026-11-11 · 버들 정령 저녁 · 두꺼비 · 이무기 · 거북 2026-11-13)
	local needs = 0
	for _, q in DD.boards.tower.pool do
		if lake[q.mob] then
			eq(q.need, "r4m9", "기도 탑의 풀: 호수의 사냥터는 「봉인의 문」을 끝내야 — " .. q.mob)
			needs += 1
		else
			eq(q.need, nil, "기도 탑의 풀: 걸어서 · 배로 가는 사냥터에는 조건이 없다 — " .. q.mob)
		end
	end
	eq(needs, if CLOSED then 0 else 9, if CLOSED then "닫힌 지역: 기도 탑의 풀에 호수의 사냥터가 없다" else "기도 탑의 풀에 호수의 사냥터 아홉(연잎 늪 · 이무기 굴 · 이끼 여울 2026-11-13)")
	local function lakeTasks(book)
		local n = 0
		for day = 0, 20 do
			local h = { level = 150, quests = book, daily = {} }
			local st = Daily.sync(h, "tower", day * 86400 + 3600 * 12)
			for _, t in (st and st.tasks) or {} do
				if lake[t.mob] then
					n += 1
				end
			end
		end
		return n
	end
	eq(lakeTasks({}), 0, "Lv.150 · 4편을 끝내지 않음: 스무하루 동안 호수의 의뢰가 하나도 없다")
	local done = {}
	for _, def in D.list do
		if def.region == "r4" or def.region == "r1" or def.region == "r2" or def.region == "r3" then
			done[def.id] = { done = true, c = {} }
		end
	end
	done.r4m9 = { done = true, c = {} }
	if CLOSED then
		eq(lakeTasks(done), 0, "닫힌 지역: 4편을 끝내도 호수의 의뢰가 나오지 않는다")
	else
		expect(lakeTasks(done) > 0, "Lv.150 · 4편을 끝냄: 호수의 의뢰가 나온다")
	end
end

-- ⑦ 닫힌 지역(2026-11-10 사용자 "일단 신지역은 아직 막아둬"): 별고래는 관리자만 태운다 · 돌아오는 별고래는 열려 있다 · 월드맵의 탭과 만월성의 출구에 없다 · 제5편을 받지 못한다
if CLOSED then
	local Voyage = req("ReplicatedStorage/shared/lune/sim/voyage")
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local WMU = req("ReplicatedStorage/shared/lune/ui/worldmap")
	local out = Voyage.route("r4ch", "whalekeeper")
	local home = Voyage.route("r5t", "whalekeeper")
	local book = { r4m9 = { done = true, c = {} } }
	expect(out ~= nil and typeof(out.closed) == "string" and out.closed ~= "", "가는 별고래: 닫혔다(시몬의 말이 있다)")
	expect(not Voyage.open(book, out), "「봉인의 문」을 끝내도 태우지 않는다")
	expect(Voyage.open(book, out, true), "관리자는 탄다(시험)")
	expect(home ~= nil and Voyage.open({}, home) and not home.closed, "돌아오는 별고래는 열려 있다(물별 마을에 있는 관리자)")
	for _, rid in WMU.arted() do
		expect(rid ~= "r5", "월드맵의 탭에 윤슬 호수가 없다")
	end
	for _, ex in WMU.exits("r4") do
		expect(ex.to ~= "r5", "만월성의 지도에 윤슬 호수로 가는 출구가 없다")
	end
	eq(Quests.state(book, 150, "r5m1"), "locked", "4편을 끝낸 Lv.150: 제5편 첫 메인을 받지 못한다")
end

-- 2026-11-12(사용자 "메인퀘 초승달마을에서 안받아지는데"): 제5편의 첫 메인은 초승달 마을의 촌장(보름 영감 — 「봉인의 문」을 돌려받은 사람)이 준다.
--  「주민은 제 지역의 퀘스트만」(Quests.givesIn)에 걸려 받을 수 없었다 → 지역이 넘어가는 메인(앞 메인이 다른 지역)은 주는 사람이 선 곳이면 어디서든
do
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local first = Quests.def("r5m1")
	expect(first ~= nil and first.giver == "elder" and first.after == "r4m9", "제5편의 첫 메인 = 촌장(elder)이 · 「봉인의 문」 다음")
	local town = nil -- 촌장이 선 곳(초승달 마을의 촌장의 집 — 1지역)
	for key, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			if n.id == "elder" then
				town = sc
			end
		end
	end
	expect(town ~= nil and town.region == "r1", "촌장은 1지역(초승달 마을)에 선다")
	town = town or SCENES.scenes.town
	expect(Quests.givesIn(first, town.region, town.also), "초승달 마을(1지역)에서도 제5편의 첫 메인을 준다")
	-- 「봉인의 문」까지 끝낸 Lv.150 캐릭터: 초승달 마을의 촌장에게 「!」(받을 것)
	local book = {}
	for _, def in D.list do
		if def.kind == "main" and def.region ~= "r5" and def.playable then
			book[def.id] = { done = true }
		end
	end
	local at = Quests.atNpc(book, 150, "elder", town.region, town.also)
	expect(table.find(at.offer, "r5m1") ~= nil, "촌장에게 제5편의 첫 메인이 「받을 것」으로 뜬다")
	local second = Quests.def("r5m2")
	expect(not Quests.givesIn(second, town.region, town.also), "제5편의 둘째 메인부터는 윤슬 호수에서만(지역 안의 것)")
end

-- 모든 지역: 받을 수 있는 퀘스트는 주는 사람이 선 곳 어딘가에서 실제로 준다(2026-11-12 — 제5편의 첫 메인 · 윤슬 호수의 지역 없음(r[1-4]) 두 가지를 이것으로 잡는다)
do
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local bad = {}
	local n = 0
	for _, def in D.list do
		if def.playable and not def.auto and typeof(def.giver) == "string" and def.kind ~= "job" then
			n += 1
			local ok = false
			for _, sc in SCENES.scenes do
				for _, npc in sc.npcs or {} do
					if npc.id == def.giver and Quests.givesIn(def, sc.region, sc.also) then
						ok = true
					end
				end
			end
			if not ok then
				table.insert(bad, def.id .. "(" .. def.giver .. ")")
			end
		end
	end
	expect(n > 100, "받을 수 있는 퀘스트를 모두 봤다(" .. n .. ")")
	eq(table.concat(bad, ", "), "", "주는 사람에게서 받을 수 없는 퀘스트가 없다")
	for _, key in { "r5t", "r5a1", "r5s", "r5c1" } do
		eq(SCENES.scenes[key].region, "r5", "윤슬 호수의 맵은 지역 r5: " .. key)
	end
end
