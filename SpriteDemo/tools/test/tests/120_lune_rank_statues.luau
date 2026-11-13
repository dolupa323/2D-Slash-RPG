-- 「달의 계승자」 — 마을의 랭킹 석상(2026-11-03 사용자 "마을에 랭킹 1,2,3 등 석상 만들자 말걸면 멋진말 나오고"). 보는 것:
--  ① 초승달 마을(town)에 석상 셋(statue 1 · 2 · 3) — 그림 없는 주민(stone)이라 이름표와 말만 · 말이 있다 · 같은 발판(명예의 전당의 섬) ·
--     받침대끼리 겹치지 않는다 · 명예의 전당의 문(포탈 그림)을 가리지 않는다 · 2위 이름표는 한 줄 아래(1위와 겹치지 않게)
--  ② 그림: 받침대 plinth1 ~ 3(1위가 가장 높다) · 다섯 직업의 돌 석상 stone_<직업>이 캐릭터 그림판에 있고 그 판이 로블록스에 올라가 있다
--  ③ client/lune/rankStatues.luau: 들어서면 받침대 셋 · 레벨 판을 받으면 그 직업의 돌 석상이 받침대 윗면에 서고 이름표 = 「레벨 n위 이름」 ·
--     순위가 비면 석상 없이 이름표 「레벨 n위 석상」 · 1위가 바뀌면 석상도 바뀐다 · 떠나면 다 걷는다
--  2026-11-12 사용자 "석상은 150레벨때 찍은 순서대로 랭킹 1,2,3등이 박제되는거야 200확장으로인해서 랭킹변동된다고 석상사람이 바뀌면 안되지":
--   석상은 레벨 판(got.level)이 아니라 Lv.150에 오른 차례의 기록(got.statues — 서버 World.statueRows · 시험 88)을 본다 → 레벨 판이 바뀌어도 그대로
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local ASSETS = req("ReplicatedStorage/shared/lune/data/assets.generated")
local PORTAL = req("ReplicatedStorage/shared/lune/data/portal.generated")
local CLASSES = { "axion", "riven", "reaper", "mooni", "salamander" }

-- ① 마을의 석상 셋
local town = SCENES.scenes.town
local statues = {}
for _, n in town.npcs or {} do
	if n.statue then
		statues[n.statue] = n
	end
end
for rank = 1, 3 do
	local n = statues[rank]
	expect(n ~= nil, ("마을에 %d위 석상"):format(rank))
	if n then
		expect(n.stone == true, ("%d위 석상은 그림 없는 주민(받침대 · 석상은 rankStatues가 그린다)"):format(rank))
		expect(typeof(n.lines) == "table" and #n.lines >= 1, ("%d위 석상에 말을 걸면 말이 나온다"):format(rank))
		expect(string.find(n.role, tostring(rank), 1, true) ~= nil, ("%d위 석상의 구실에 순위"):format(rank))
	end
end
if statues[1] and statues[2] and statues[3] then
	expect(statues[1].y == statues[2].y and statues[2].y == statues[3].y, "셋이 같은 발판 위")
	eq(statues[2].tagRow, 1, "2위 이름표는 한 줄 아래(1위와 30점 떨어져 있다)")
	-- 받침대의 폭(그림판) — 왼쪽부터 늘어놓고 겹치지 않는가
	local spans = {}
	for rank = 1, 3 do
		local n, c = statues[rank], CHARS.chars["plinth" .. rank]
		if c then
			table.insert(spans, { a = n.x - c.ox, b = n.x - c.ox + c.fw, rank = rank })
		end
	end
	table.sort(spans, function(p, q)
		return p.a < q.a
	end)
	for i = 2, #spans do
		expect(spans[i - 1].b <= spans[i].a, ("받침대 %d위 · %d위가 겹치지 않는다"):format(spans[i - 1].rank, spans[i].rank))
	end
	-- 같은 발판의 문(명예의 전당) — 포탈 그림 폭 안에 받침대가 들지 않는다
	local door = nil
	for _, p in town.portals or {} do
		if math.abs(p.y - statues[1].y) < 4 and p.x > spans[1].a - 40 and p.x < spans[#spans].b + 40 then
			door = p
		end
	end
	expect(door ~= nil, "석상 곁에 명예의 전당의 문")
	if door then
		local half = PORTAL.w / 2
		for _, s in spans do
			expect(s.b <= door.x - half or s.a >= door.x + half, ("%d위 받침대가 문을 가리지 않는다"):format(s.rank))
		end
	end
end

-- ①-2 은달 항구(2026-11-03 사용자 "석상 은달항구에도 만들어주고"): 3층 대영주의 성 앞에 셋 · 순위의 구실 · 말은 마을의 것과 같다 · 받침대끼리 · 성의 문과 겹치지 않는다
do
	local ct = SCENES.scenes.ct
	local got = {}
	for _, n in ct.npcs or {} do
		if n.statue then
			got[n.statue] = n
		end
	end
	local door = nil
	for _, p in ct.portals or {} do
		if p.to == "ct_castle" then
			door = p
		end
	end
	expect(door ~= nil, "은달 항구에 대영주의 성 문")
	local spans = {}
	for rank = 1, 3 do
		local n, t = got[rank], statues[rank]
		expect(n ~= nil and n.stone == true, ("은달 항구에 %d위 석상"):format(rank))
		if n and t then
			eq(n.role, t.role, ("%d위 석상의 구실 = 마을의 것"):format(rank))
			eq(table.concat(n.lines, "/"), table.concat(t.lines, "/"), ("%d위 석상의 말 = 마을의 것"):format(rank))
			eq(n.tagRow, t.tagRow, ("%d위 이름표 줄 = 마을의 것"):format(rank))
			expect(door ~= nil and n.y == door.y, ("%d위 석상이 성 문과 같은 층(3층)"):format(rank))
			local c = CHARS.chars["plinth" .. rank]
			table.insert(spans, { a = n.x - c.ox, b = n.x - c.ox + c.fw, rank = rank })
		end
	end
	table.sort(spans, function(p, q)
		return p.a < q.a
	end)
	for i = 2, #spans do
		expect(spans[i - 1].b <= spans[i].a, ("은달 항구: 받침대 %d위 · %d위가 겹치지 않는다"):format(spans[i - 1].rank, spans[i].rank))
	end
	if door then
		for _, sp in spans do
			expect(sp.b <= door.x - PORTAL.w / 2 or sp.a >= door.x + PORTAL.w / 2, ("은달 항구: %d위 받침대가 성 문을 가리지 않는다"):format(sp.rank))
		end
	end
end

-- ② 그림판과 판
local function uploaded(c)
	local ok = c ~= nil
	for _, clip in (c and c.clips or {}) do
		for _, f in clip.frames do
			if f then
				local file = CHARS.pages[f[1]]
				ok = ok and ASSETS[file] ~= nil and ASSETS[file] ~= ""
			end
		end
	end
	return ok
end
local hs = {}
for rank = 1, 3 do
	local c = CHARS.chars["plinth" .. rank]
	expect(c ~= nil and c.clips.idle ~= nil and #c.clips.idle.frames == 1, ("받침대 plinth%d(서 있는 한 장)"):format(rank))
	expect(uploaded(c), ("받침대 plinth%d의 판이 올라가 있다"):format(rank))
	hs[rank] = c and c.fh or 0
end
expect(hs[1] > hs[2] and hs[2] > hs[3], "1위 받침대가 가장 높고 3위가 가장 낮다")
for _, cls in CLASSES do
	local c = CHARS.chars["stone_" .. cls]
	expect(c ~= nil and c.clips.idle ~= nil, ("돌 석상 stone_%s"):format(cls))
	expect(uploaded(c), ("돌 석상 stone_%s의 판이 올라가 있다"):format(cls))
	expect(c and c.oy == c.fh, ("돌 석상 stone_%s의 발밑 = 그림의 밑"):format(cls))
end

-- ③ 게임에서 세우기(화면 없이)
local made = {}
MOCK("Client/lune/sprite", {
	new = function(parent, who, z)
		local sp = { who = who, z = z, parent = parent, label = {} }
		function sp.set(_, clip, f, x, y, dir)
			sp.clip, sp.f, sp.x, sp.y, sp.dir = clip, f, x, y, dir
		end
		function sp.destroy()
			sp.gone = true
		end
		table.insert(made, sp)
		return sp
	end,
})
MOCK("Client/lune/stage", {
	group = function(_, name, z)
		local f = { Name = name, z = z }
		function f.Destroy()
			f.gone = true
		end
		return f
	end,
})
local answer = { level = { { name = "레벨판1위", class = "riven" } }, statues = { { name = "가나다", class = "mooni" }, { name = "라마", class = "axion" }, false } } -- (레벨 판의 1위는 석상과 다른 사람)
local asked = 0
MOCK("ReplicatedStorage/shared/lune/net/net", {
	Invoke = function(name)
		if name == "Rank" then
			asked += 1
			return answer
		end
		return nil
	end,
})
local Statues = req("Client/lune/rankStatues")
local view = { world = {}, npcs = {} }
for rank = 1, 3 do
	local n = statues[rank]
	if n then
		local tag = { text = "" }
		function tag.SetText(_, t)
			tag.text = t
		end
		table.insert(view.npcs, { def = n, tag = tag })
	end
end
table.insert(view.npcs, { def = { id = "someone", x = 10, y = 10 }, tag = {} }) -- 석상이 아닌 주민은 건드리지 않는다
Statues.enter(view)
local bases = {}
for _, sp in made do
	if string.sub(sp.who, 1, 6) == "plinth" then
		bases[tonumber(string.sub(sp.who, 7))] = sp
	end
end
for rank = 1, 3 do
	local b, n = bases[rank], statues[rank]
	expect(b ~= nil and n ~= nil and b.x == n.x and b.y == n.y, ("%d위 받침대가 그 자리(발밑)"):format(rank))
end
Statues.update()
eq(asked, 1, "들어서면 레벨 판을 묻는다")
local figs = {}
for _, sp in made do
	if string.sub(sp.who, 1, 6) == "stone_" and not sp.gone then
		table.insert(figs, sp)
	end
end
eq(#figs, 2, "순위가 둘이면 석상 둘")
local function figOf(rank)
	for _, sp in figs do
		local n = statues[rank]
		if n and sp.x == n.x then
			return sp
		end
	end
	return nil
end
local f1, f2 = figOf(1), figOf(2)
expect(f1 ~= nil and f1.who == "stone_mooni", "1위 = 그 사람의 직업(무니)의 돌 석상")
expect(f2 ~= nil and f2.who == "stone_axion", "2위 = 액시온의 돌 석상")
if f1 and statues[1] then
	eq(f1.y, statues[1].y - CHARS.chars.plinth1.oy, "석상은 받침대의 윗면에 선다")
	eq(f1.dir, statues[1].dir or 1, "석상은 설계의 쪽을 본다")
end
expect(figOf(3) == nil, "순위가 비면 석상 없이 받침대만")
local tags = {}
for _, v in view.npcs do
	if v.def.statue then
		tags[v.def.statue] = v.tag.text
	end
end
eq(tags[1], statues[1].role .. " 가나다", "1위 이름표 = 「레벨 1위 이름」")
eq(tags[2], statues[2].role .. " 라마", "2위 이름표")
eq(tags[3], statues[3].role .. " " .. statues[3].name, "빈 순위의 이름표 = 「레벨 3위 석상」")
-- 1위가 바뀌었다(만렙 최초 달성 등) → 곧 다시 묻고 석상을 바꾼다
answer = { level = { { name = "Lv200사람", class = "riven" } }, statues = { { name = "새1위", class = "reaper" }, { name = "라마", class = "axion" }, { name = "셋째", class = "salamander" } } }
Statues.soon()
Statues.update()
eq(asked, 2, "soon → 다시 묻는다")
local live = {}
for _, sp in made do
	if string.sub(sp.who, 1, 6) == "stone_" and not sp.gone then
		live[sp.x] = sp.who
	end
end
eq(live[statues[1].x], "stone_reaper", "1위 석상이 새 사람의 직업으로 바뀐다")
eq(live[statues[3].x], "stone_salamander", "3위가 생기면 석상이 선다")
expect(live[statues[1].x] ~= "stone_riven", "레벨 판의 1위(Lv.200 · 리븐)는 석상에 서지 않는다")
Statues.update()
eq(asked, 2, "다시 묻는 것은 60초에 한 번")
Statues.leave()
Statues.update()
eq(asked, 2, "떠나면 묻지 않는다")

-- ④ 석상이 될 뻔한 돌(2026-11-07 사용자: "랭킹석상 옆에 약간 찌그러진 돌 추가하고 말걸면 석상이 될뻔한 돌이다. 이렇게 나오게해줘"):
--  마을의 석상 곁(같은 발판 · 3위 받침대와 겹치지 않는다 · 섬 안) · 그림 없는 주민 + rock = statue_rock · 말 = 사용자의 말 그대로 · 이름표는 이름만(구실이 비었다) ·
--  그림판에 있고 올라가 있다 · rankStatues가 그 자리에 그린다 · 3위와 사이에 서면 가까운 쪽(↑)
local rockNpc = nil
for _, n in town.npcs or {} do
	if n.rock then
		rockNpc = n
	end
end
expect(rockNpc ~= nil and rockNpc.rock == "statue_rock" and rockNpc.stone == true, "마을에 석상이 될 뻔한 돌(그림 없는 주민 + 돌 그림)")
if rockNpc then
	eq(rockNpc.lines and rockNpc.lines[1], "석상이 될뻔한 돌이다.", "말을 걸면 「석상이 될뻔한 돌이다.」")
	eq(rockNpc.role, "", "구실이 비었다(이름표 = 이름만)")
	local c = CHARS.chars.statue_rock
	expect(c ~= nil and c.clips.idle ~= nil and #c.clips.idle.frames == 1 and uploaded(c), "돌 그림 statue_rock이 그림판에 있고 올라가 있다")
	if c and statues[3] then
		local p3 = CHARS.chars.plinth3
		eq(rockNpc.y, statues[3].y, "석상과 같은 발판 위")
		expect(statues[3].x - p3.ox + p3.fw <= rockNpc.x - c.ox, "3위 받침대와 겹치지 않는다")
		expect(rockNpc.x - c.ox + c.fw <= 832, "명예의 전당의 섬(832점까지) 안")
		expect(c.fh < CHARS.chars.plinth3.fh + 10, "석상보다 훨씬 낮다(받침대 높이 언저리)")
	end
	expect(rockNpc.tagRow == 1, "이름표는 한 줄 아래(3위의 이름표와 겹치지 않게)")
	-- rankStatues가 그 자리에 돌을 그린다 · 순위가 바뀌어도 건드리지 않는다
	table.clear(made)
	Statues.enter({ world = {}, npcs = { { def = rockNpc, tag = {} } } })
	local rockSp = nil
	for _, sp in made do
		if sp.who == "statue_rock" then
			rockSp = sp
		end
	end
	expect(rockSp ~= nil and rockSp.x == rockNpc.x and rockSp.y == rockNpc.y and rockSp.dir == -1, "돌이 그 자리(발밑)에 그려진다(그린 그대로)")
	Statues.leave()
	-- ↑: 3위와 돌 사이에서는 가까운 쪽(게임 client/lune/sceneView.luau의 npcNear와 같은 규칙 — 30점 안에서 가장 가까운 주민. 이 시험의 가짜 모듈로는 sceneView를 불러올 수 없어 규칙을 옮겨 본다)
	local mid = math.floor((statues[3].x + rockNpc.x) / 2)
	local function near(x)
		local best, bestD = nil, 30
		for _, d in { statues[3], rockNpc } do
			local dd = math.abs(d.x - x)
			if dd < bestD then
				best, bestD = d, dd
			end
		end
		return best
	end
	expect(near(rockNpc.x) == rockNpc and near(mid + 2) == rockNpc and near(mid - 2) == statues[3], "돌 앞에서 ↑ = 돌 · 3위 앞에서 ↑ = 3위")
end
