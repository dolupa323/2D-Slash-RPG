-- 「달의 계승자」 — 퀘스트 연출(장면, 2026-10-15): 말을 듣고 잡으러 가는 것만 되풀이하던 메인 줄 사이사이의 장면 · 장의 이름 · 여러 사람이 말하는 대화.
--  사용자: "현재 메인 퀘스트 라인 너무스토리 몰입이 안됩니다. 그냥 뭐해라, 뭐잡아라 반복만되고, 무슨 이야기가 풀리지도않고, 몰입되는 중간에 연출이 있는것도아니고 …"
--  자료: 공방 js/lune/design/cine.js → data/cine.generated.luau · 셈 shared/lune/cine.luau(공방 js/lune/cine.js를 옮긴 것) · 그리기 client/lune/cineView.luau.
local Cine = req("ReplicatedStorage/shared/lune/cine")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local QUESTS = req("ReplicatedStorage/shared/lune/data/quests.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local ASSETS = req("ReplicatedStorage/shared/lune/data/assets.generated")
local F = req("ReplicatedStorage/shared/lune/ui/format")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})

local D = Cine.DATA
local qById = {}
for _, q in QUESTS.list do
	qById[q.id] = q
end
-- 주민 id → 이름(어느 장면에든 서 있는 주민)
local npcName = {}
for _, sc in SCENES.scenes do
	for _, n in sc.npcs or {} do
		npcName[n.id] = n.name
	end
end

-- ---- 1) 자료: 장면마다 퀘스트 · 맵 · 사람 · 그림이 있다 ----
local ON = { before = true, enter = true, accept = true, goal = true, complete = true }
local ids = {}
local MAX_LINES = F.DIALOG.lines
for _, c in D.list do
	expect(not ids[c.id], "장면 id가 겹치지 않는다 " .. c.id)
	ids[c.id] = true
	local w = c.when
	expect(ON[w.on] == true, c.id .. ": 때(on)를 안다 — " .. tostring(w.on))
	expect(qById[w.quest] ~= nil, c.id .. ": 그 퀘스트가 있다 " .. tostring(w.quest))
	if w.on == "enter" or w.on == "before" then
		expect(w.map ~= nil and SCENES.scenes[w.map] ~= nil, c.id .. ": 들어설 맵이 게임에 있다 " .. tostring(w.map))
	end
	expect(#c.steps > 0, c.id .. ": 단계가 있다")
	local spawned = {}
	for i, s in c.steps do
		local v = Cine.verbOf(s)
		expect(v ~= nil, ("%s %d째 단계: 갈래를 안다"):format(c.id, i))
		if s.spawn then
			spawned[s.spawn] = true
			if s.mob then
				expect(CHARS.chars[s.mob] ~= nil, c.id .. ": 세우는 졸개의 그림이 있다 " .. s.mob)
			else
				expect(npcName[s.npc] ~= nil, c.id .. ": 세우는 주민이 어느 맵에 서 있다(그 그림을 빌린다) " .. tostring(s.npc))
			end
		end
		-- 사람: hero · none · boss · 세운 것 · 주민(그 맵에 없어도 이름은 어딘가에서 찾는다)
		for _, k in { "say", "walk", "face", "mark", "die", "hide", "show" } do
			local who = s[k]
			if typeof(who) == "string" then
				local ok = who == "hero" or who == "none" or who == "boss" or spawned[who] or npcName[who] ~= nil
				expect(ok, ("%s %d째 단계(%s): 누구인지 안다 — %s"):format(c.id, i, k, who))
			end
		end
		if s.say then
			-- 말이 대화창에 들어간다(세 줄 — {weapon}은 가장 긴 무기 낱말로)
			local text = string.gsub(s.text, "{weapon}", "대검")
			local n = #string.split(pixelText.Wrap(text, F.DIALOG_TEXT_W, "body"), "\n")
			expect(n <= MAX_LINES, ("%s: 말이 대화창에 들어간다(%d줄) — %s"):format(c.id, n, s.text))
		end
		if s.picture then
			local pd = D.pictures[s.picture]
			expect(pd ~= nil, c.id .. ": 큰 그림의 자료가 있다 " .. s.picture)
			if pd then
				for cls, file in pd.files do
					expect(ASSETS[file] ~= nil, ("큰 그림 %s의 %s 그림이 올릴 목록에 있다"):format(s.picture, cls))
					expect(pd.cols[cls] ~= nil, ("큰 그림 %s: %s의 빛을 얹을 자리가 있다"):format(s.picture, cls))
				end
			end
		end
	end
end
-- 장의 이름: 1지역의 장 다섯 — 장의 첫 퀘스트를 받으면 뜬다
local cards = 0
for _, c in D.list do
	if string.find(c.id, "r1_ch_", 1, true) then
		cards += 1
		eq(c.when.on, "accept", c.id .. ": 장의 이름은 받을 때")
	end
end
eq(cards, 5, "1지역의 장은 다섯")

-- ---- 2) 셈: 모든 장면이 끝까지 돈다(말은 넘기고) · 건너뛰기 · 끝나면 다 거둔다 ----
local function world(npcs)
	return {
		hero = function()
			return { x = 200, y = 176, dir = 1 }
		end,
		npc = function(id)
			local n = npcs[id]
			return n and { x = n, y = 176, dir = -1, name = npcName[id] } or nil
		end,
		npcName = function(id)
			return npcName[id]
		end,
		boss = function()
			return { x = 320, y = 176 }
		end,
		cls = "riven",
		heroName = "시험",
	}
end
for _, c in D.list do
	local st = Cine.new(c, world({ master = 260, elder = 240, guide = 120, oldman = 230, guard1 = 250 }))
	local t, says, notes = 0, 0, 0
	while not st.done and t < 120 do
		if st.wait and st.wait.input == "say" then
			says += 1
			expect(st.say.name == nil or #st.say.name > 0, c.id .. ": 말의 이름표는 비어 있지 않다(없으면 속마음)")
			expect(not string.find(st.say.text, "{", 1, true), c.id .. ": 바꿔 넣지 못한 자리가 없다 " .. st.say.text)
			Cine.input(st, "next", 30) -- 나오는 중이면 다 보이고
			Cine.input(st, "next", 30) -- 다음으로
		elseif st.wait and st.wait.input == "note" then
			notes += 1
			Cine.input(st, "next", 30)
		else
			Cine.step(st, 1 / 30)
			t += 1 / 30
		end
	end
	expect(st.done, ("%s: 끝까지 돈다(%.1f초)"):format(c.id, t))
	expect(t < 40, ("%s: 기다리는 시간이 너무 길지 않다(%.1f초 — 말을 읽는 시간은 빼고)"):format(c.id, t))
	expect(st.bars == 0 and st.fade == 0 and st.picture == nil and st.tint == nil and next(st.actors) == nil and next(st.over) == nil and st.cam == nil, c.id .. ": 끝나면 덮개 · 세운 것 · 카메라를 다 거둔다")
	-- 건너뛰기: 처음 단계에서 바로
	local sk = Cine.new(c, world({ master = 260, elder = 240, guide = 120, oldman = 230, guard1 = 250 }))
	Cine.input(sk, "skip")
	expect(sk.done and sk.bars == 0 and sk.fade == 0 and next(sk.actors) == nil, c.id .. ": 건너뛰면 바로 끝나고 다 거둔다")
end
-- 벽 그림: 내 직업의 무기 낱말이 말에 들어간다
do
	local mural
	for _, c in D.list do
		if c.id == "r1_mural" then
			mural = c
		end
	end
	expect(mural ~= nil, "벽 그림 장면이 있다")
	if mural then
		local st = Cine.new(mural, world({}))
		local saw = false
		local guard = 0
		while not st.done and guard < 5000 do
			guard += 1
			if st.say then
				saw = saw or string.find(st.say.text, "창…", 1, true) ~= nil
				st.say.t = 1e9
				Cine.input(st, "next", 30)
			else
				Cine.step(st, 1 / 30)
			end
		end
		expect(saw, "벽 그림: 리븐에게는 「창… 나와 같은 무기다」")
	end
end
-- 찾기: 받기 전(before) · 하는 중에 들어섬(enter) · 본 것은 다시 틀지 않는다 · 장의 이름이 먼저
do
	local list = Cine.before("in_shrine", {}, {})
	expect(#list == 1 and list[1].id == "r1_wake", "새 캐릭터가 사당에 들어서면 깨어나는 장면")
	eq(#Cine.before("in_shrine", { r1m1 = { done = false, c = {} } }, {}), 0, "첫 기술을 받은 뒤에는 깨어나는 장면이 없다")
	eq(#Cine.findAll("enter", "r1m2", "r1a1", {}), 1, "마을 밖의 그림자를 하는 중에 마을 어귀에 들어서면 처음 본 병사들")
	eq(#Cine.findAll("enter", "r1m2", "town", {}), 0, "다른 맵에서는 틀지 않는다")
	eq(#Cine.findAll("enter", "r1m2", "r1a1", { r1_sight = true }), 0, "본 장면은 다시 틀지 않는다")
	local acc = Cine.findAll("accept", "r1m1", nil, {})
	expect(#acc >= 1 and string.find(acc[1].id, "_ch_", 1, true) ~= nil, "첫 기술을 받으면 장의 이름(제1장)")
	local tint = Cine.lookAt("town", { r1m9 = true })
	expect(tint ~= nil, "불타는 마을을 하는 동안 마을의 하늘이 붉다")
	expect(Cine.lookAt("town", {}) == nil, "그 밖에는 덮지 않는다")
	expect(Cine.known("r1_mural") and not Cine.known("없는 장면") and not Cine.known(3), "서버는 아는 장면 id만 적는다")
end

-- ---- 3) 퀘스트의 대화에 여러 사람: 「@id 」의 사람이 있다 ----
for _, q in QUESTS.list do
	for _, list in { q.offer, q.wait, q.done } do
		for _, line in list do
			local id = string.match(line, "^@(%w+) ")
			if id then
				expect(id == "hero" or npcName[id] ~= nil, ("「%s」: 말하는 사람을 안다 — %s"):format(q.name, id))
			end
		end
	end
end
