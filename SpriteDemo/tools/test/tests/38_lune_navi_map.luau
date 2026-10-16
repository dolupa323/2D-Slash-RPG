-- 「달의 계승자」 — 월드맵은 실제 포탈과 같다 · 퀘스트 길찾기(shared/lune/ui/navi.luau · client/lune/questHud.luau · client/lune/naviArrow.luau).
--  사용자 2026-10-13: "아니 월드맵이랑 실제 포탈이랑 안맞잖아요 … 고갯길 초입에서 포탈타면 고갯마루 주막인데 월드맵에서는 코갯길 초입  굽잇길  고갯마루 주막 이렇게 배치되어있으면
--                     당연히 고갯길 초입다음 포탈이 굽잇길인것처럼 느껴지고  한참 헤멘다구요 기본적인건 놓치지맙시다"
--                    "우측상단 퀘스트 ui에 각각 퀘스트마다  간단한 화살표 버튼 생기게해서  그 버튼 누르면  길찾기 되면서 가야하는 방향 캐릭터 머리위에 화살표로 알려주는 기능 추가하세요
--                     진행도마다 정확하게 되어야합니다.  만약에 아이템을 줍는 퀘스트라면  사냥을 해야할때는 그 해당 사냥터로  만약에 그 아이템을 모두 파밍했다면  완료해야하는 장소를 안내해주고"
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local WM = req("ReplicatedStorage/shared/lune/ui/worldmap")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Daily = req("ReplicatedStorage/shared/lune/sim/daily")
local Navi = req("ReplicatedStorage/shared/lune/ui/navi")
local Panel = req("ReplicatedStorage/shared/lune/ui/questPanel")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})
local D = WM.data

-- ---- 1) 월드맵의 줄 = 실제 포탈(그림이 있는 지역마다) ----
local function pairKey(a: string, b: string): string
	return if a < b then a .. "|" .. b else b .. "|" .. a
end
for _, rid in WM.arted() do
	local region = D.regions[rid]
	-- 실제: 장면의 문을 따라 — 두 장면이 서로 다른 장소(마디)에 딸렸으면 그 두 장소는 문 하나로 오간다
	local real = {}
	for key, sc in SCENES.scenes do
		local r1, a = WM.nodeOf(key)
		if r1 == rid then
			for _, p in sc.portals or {} do
				local r2, b = WM.nodeOf(p.to)
				if r2 == rid and b ~= a then
					real[pairKey(a, b)] = key .. " → " .. p.to
				end
			end
		end
	end
	local drawn = {}
	for _, link in region.links do
		drawn[pairKey(link[1], link[2])] = true
		expect(real[pairKey(link[1], link[2])] ~= nil, ("월드맵에 그린 줄에 실제 포탈이 있다 %s – %s"):format(link[1], link[2]))
	end
	for k, how in real do
		expect(drawn[k], ("실제 포탈로 오가는 두 곳이 월드맵에서 줄로 이어져 있다 %s(%s)"):format(k, how))
	end
	-- 줄이 남의 표시를 지나가지 않는다: 표시가 그 줄에 가까우면(12점 안) 그곳을 거쳐 가는 길로 읽힌다 — 이번에 틀린 것(굽잇길이 초입 – 주막의 줄 위에 있었다)
	local at = region.art.at
	for _, link in region.links do
		local a, b = at[link[1]], at[link[2]]
		for _, n in region.nodes do
			local p = at[n.id]
			if p and n.id ~= link[1] and n.id ~= link[2] then
				local dx, dy = b[1] - a[1], b[2] - a[2]
				local t = math.clamp(((p[1] - a[1]) * dx + (p[2] - a[2]) * dy) / (dx * dx + dy * dy), 0, 1)
				local d = math.sqrt((a[1] + dx * t - p[1]) ^ 2 + (a[2] + dy * t - p[2]) ^ 2)
				expect(d >= 12, ("줄 %s – %s가 %s의 표시를 지나가지 않는다(떨어진 거리 %.1f점)"):format(link[1], link[2], n.id, d))
			end
		end
	end
	-- 줄끼리 엇갈리지 않는다(엇갈리면 그 자리에 갈림길이 있는 것으로 읽힌다)
	local function cross(p1, p2, p3, p4): boolean
		local function side(a, b, c): number
			return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
		end
		return side(p1, p2, p3) * side(p1, p2, p4) < 0 and side(p3, p4, p1) * side(p3, p4, p2) < 0
	end
	for i, l1 in region.links do
		for j = i + 1, #region.links do
			local l2 = region.links[j]
			if l1[1] ~= l2[1] and l1[1] ~= l2[2] and l1[2] ~= l2[1] and l1[2] ~= l2[2] then
				expect(not cross(at[l1[1]], at[l1[2]], at[l2[1]], at[l2[2]]), ("줄끼리 엇갈리지 않는다 %s – %s · %s – %s"):format(l1[1], l1[2], l2[1], l2[2]))
			end
		end
	end
end
-- 말씀하신 자리 그대로: 고갯길 초입에서 문 하나로 고갯마루 주막 · 굽잇길은 주막의 가지
do
	local function door(from: string, to: string): boolean
		for _, p in SCENES.scenes[from].portals do
			if p.to == to then
				return true
			end
		end
		return false
	end
	expect(door("r1b1", "r1bv") and not door("r1b1", "r1b2") and door("r1bv", "r1b2"), "고갯길 초입 → 고갯마루 주막(문 하나) · 굽잇길은 주막에서만 간다")
	local has = {}
	for _, link in D.regions.r1.links do
		has[pairKey(link[1], link[2])] = true
	end
	expect(has[pairKey("r1b1", "r1bv")] and not has[pairKey("r1b1", "r1b2")] and has[pairKey("r1bv", "r1b2")], "월드맵의 줄도 그렇다")
end

-- ---- 2) 길찾기: 진행도마다 가야 할 곳 ----
local function npcIn(scene: string, id: string): boolean
	for _, n in SCENES.scenes[scene].npcs or {} do
		if n.id == id then
			return true
		end
	end
	return false
end
local function mobIn(scene: string, kind: string): boolean
	for _, m in SCENES.scenes[scene].mobs or {} do
		if m.kind == kind then
			return true
		end
	end
	-- 스토리 보스(장면의 bosses — 방에서는 졸개의 목록 끝에 선다 · 그 퀘스트를 하는 사람이 있을 때만)
	for _, m in SCENES.scenes[scene].bosses or {} do
		if m.kind == kind then
			return true
		end
	end
	return false
end
-- 문을 따라 걸어 본다: 화살표가 가리키는 문을 타고 또 타면 그 맵에 닿는다. 지난 문의 수를 돌려준다(못 닿으면 nil)
local function walk(from: string, target, book): number?
	local key, hops = from, 0
	while key ~= target.scene do
		local x, y, what, portal = Navi.aim(key, 0, 0, target, book, {})
		if what ~= "portal" or not portal then
			-- 사냥하러 가는 길: 가는 도중의 맵에도 그 몬스터가 살면 거기서 잡는다(어느 맵에서 잡든 센다 — 사용자 2026-10-13: 맵으로 가리지 않는다)
			if target.kind == "hunt" and not target.only and mobIn(key, target.mob) and what ~= nil then
				return hops
			end
			return nil
		end
		key = portal.to
		hops += 1
		if hops > 40 then
			return nil
		end
	end
	return hops
end
-- 지금 게임에서 할 수 있는 퀘스트 모두: 받기 전 → 일마다 → 다 했을 때
local checked, stages = 0, 0
for _, def in Quests.list do
	if def.playable then
		checked += 1
		-- 앞선 퀘스트는 끝낸 것으로(받을 수 있는 때)
		local book = {}
		local prev = def.after
		while prev do
			book[prev] = { done = true, c = {} }
			prev = Quests.def(prev).after
		end
		local level = math.max(def.lv, 1)
		local start = if def.region == "r1" or def.kind == "job" then "town" else def.scene
		-- ㄱ) 받기 전: 주는 주민이 선 맵
		local t = Navi.target(def.id, book, level, nil)
		expect(t ~= nil and t.kind == "npc" and t.npc == def.giver and t.scene == Quests.giverScene(def) and npcIn(t.scene, def.giver), ("받기 전에는 주는 주민에게 %s"):format(def.id))
		if t and def.region == "r1" then
			expect(walk(start, t, book) ~= nil, ("주는 주민까지 문을 따라 닿는다 %s"):format(def.id))
		end
		expect(Navi.target(def.id, book, level - 1, nil) == nil or level == 1, ("레벨이 모자라면 안내하지 않는다 %s"):format(def.id))
		-- ㄴ) 받았다: 못 다 한 첫 일의 자리
		book[def.id] = { done = false, c = {} }
		for i, step in def.steps do
			t = Navi.target(def.id, book, level, nil)
			stages += 1
			if step.type == "use" then
				expect(t ~= nil and t.kind == "spot" and t.scene == def.scene and t.x == step.x and t.y == step.y, ("살펴볼 자리로 %s #%d"):format(def.id, i))
			elseif step.type == "visit" then
				expect(t ~= nil and t.kind == "visit" and t.scene == step.at, ("들를 맵으로 %s #%d"):format(def.id, i)) -- 2026-10-16
			elseif step.type == "meet" then
				expect(t ~= nil and t.kind == "npc" and t.npc == step.npc and npcIn(t.scene, step.npc), ("만날 사람에게 %s #%d"):format(def.id, i)) -- 2026-10-16(만나면 열림)
			else
				expect(t ~= nil and t.kind == "hunt" and t.scene == def.scene and t.mob == step.mob, ("잡을 · 모을 몬스터의 사냥터로 %s #%d"):format(def.id, i))
				expect(t == nil or mobIn(t.scene, step.mob), ("그 사냥터에 그 몬스터가 있다 %s #%d — %s의 %s"):format(def.id, i, def.scene, tostring(step.mob)))
			end
			if t and def.region == "r1" then
				expect(walk(start, t, book) ~= nil, ("그 자리까지 문을 따라 닿는다 %s #%d"):format(def.id, i))
			end
			-- 하나 모자랄 때까지는 그대로 사냥터 · 다 채우면 다음 일로
			if step.n > 1 then
				book[def.id].c[i] = step.n - 1
				local still = Navi.target(def.id, book, level, nil)
				expect(still ~= nil and still.kind == (if step.type == "use" then "spot" else "hunt") and still.scene == def.scene, ("하나 모자라면 아직 그 자리 %s #%d"):format(def.id, i))
			end
			book[def.id].c[i] = step.n
		end
		-- ㄷ) 다 했다: 돌려줄 주민이 선 맵
		t = Navi.target(def.id, book, level, nil)
		expect(Quests.isReady(book, def.id), "다 한 퀘스트 " .. def.id)
		expect(t ~= nil and t.kind == "npc" and t.npc == def.endNpc and t.scene == Quests.endScene(def) and npcIn(t.scene, def.endNpc), ("다 하면 돌려줄 주민에게 %s"):format(def.id))
		if t and def.region == "r1" then
			expect(walk(def.scene, t, book) ~= nil, ("하던 맵에서 돌려줄 주민까지 문을 따라 닿는다 %s"):format(def.id))
		end
		-- ㄹ) 끝냈다: 안내가 없다
		book[def.id].done = true
		expect(Navi.target(def.id, book, level, nil) == nil, "끝낸 퀘스트는 안내하지 않는다 " .. def.id)
	end
end
expect(checked >= 20 and stages >= 20, ("길찾기를 확인한 퀘스트 %d개 · 일 %d개"):format(checked, stages))
print(("[NAVI] 퀘스트 %d개 · 일 %d개의 진행마다 확인"):format(checked, stages))

-- 말씀하신 보기 그대로 — 물건을 줍는 퀘스트 「빈 갑옷」(촌장 · 달그림자 사냥터의 검병에게서 갑옷 조각 여덟)
do
	local def = Quests.def("r1m3")
	local step = def.steps[1]
	eq(step.type, "gather", "「빈 갑옷」은 물건을 모으는 퀘스트")
	local bag = 0
	local book = { r1m1 = { done = true, c = {} }, r1m2 = { done = true, c = {} } }
	local function count(item: string): number
		return if item == step.item then bag else 0
	end
	local t = Navi.target("r1m3", book, 4, nil)
	expect(t.kind == "npc" and t.npc == "elder" and t.scene == Quests.giverScene(def), "받기 전: 촌장에게")
	Quests.accept(book, 4, "r1m3")
	Quests.sync(book, count)
	t = Navi.target("r1m3", book, 4, nil)
	expect(t.kind == "hunt" and t.scene == "hunt" and t.mob == "warrior", "받았다: 달그림자 사냥터의 검병에게")
	-- 잡기만 해서는(땅에 떨어진 것을 줍지 않으면) 안 바뀐다 · 주운 만큼만 센다
	Quests.onKill(book, "warrior", "hunt")
	t = Navi.target("r1m3", book, 4, nil)
	expect(t.kind == "hunt", "잡기만 하고 줍지 않았으면 아직 사냥터")
	bag = step.n - 1
	Quests.sync(book, count)
	t = Navi.target("r1m3", book, 4, nil)
	expect(t.kind == "hunt" and t.scene == "hunt", "일곱 개: 아직 사냥터")
	bag = step.n
	Quests.sync(book, count)
	t = Navi.target("r1m3", book, 4, nil)
	expect(t.kind == "npc" and t.npc == def.endNpc and t.scene == Quests.endScene(def), "여덟 개를 다 주웠다: 돌려줄 촌장에게")
	-- 그때 사냥터에 서 있으면 화살표는 마을로 돌아가는 문을 가리킨다(마을 쪽의 문 = 사냥터에서 촌장의 집까지의 길의 첫 문)
	local path = Navi.path("hunt", t.scene, book)
	expect(path ~= nil and path[1] == "hunt" and path[#path] == t.scene, "사냥터에서 촌장까지의 길")
	local ax, ay, what, portal = Navi.aim("hunt", 300, 176, t, book, {})
	expect(what == "portal" and portal.to == path[2], "사냥터에서는 돌아가는 길의 첫 문을 겨눈다")
	local arrow = Navi.arrow("r1m3", "hunt", 300, 176, book, 4, nil, {})
	expect(arrow ~= nil and arrow.dir == (if portal.x < 300 then "left" else "right"), "화살표는 그 문 쪽")
	-- 월드맵의 「가는 길」도 같은 곳: 길찾기를 켜면 그 퀘스트의 지금 진행을 따른다
	local card = WM.goalCard(book, 4, "hunt", "r1m3", nil)
	expect(card ~= nil and card.goal.scene == t.scene and card.goal.kind == "back" and string.find(card.title, "돌려주러", 1, true) ~= nil, "월드맵: 돌려주러 가는 길")
	local last = card.route[#card.route]
	local _, endNode = WM.nodeOf(t.scene)
	eq(last.node, endNode, "월드맵의 길의 끝 = 돌려줄 주민이 선 곳")
	-- 다시 잃으면(버렸다 · 팔았다) 다시 사냥터로
	bag = 3
	Quests.sync(book, count)
	t = Navi.target("r1m3", book, 4, nil)
	expect(t.kind == "hunt" and t.scene == "hunt", "모은 것이 줄면 다시 사냥터")
	card = WM.goalCard(book, 4, "town", "r1m3", nil)
	expect(card ~= nil and card.goal.scene == "hunt" and card.goal.kind == "do", "월드맵: 하러 가는 길(사냥터)")
	-- 켠 것이 없으면 예전처럼 이야기를 따른다 · 켠 것이 끝난 퀘스트면 그것도 예전처럼
	local plain = WM.goalCard(book, 4, "town")
	expect(plain ~= nil and plain.goal.def.id == "r1m3", "켠 것이 없으면 이야기의 다음 곳")
	expect(WM.goalCard(book, 4, "town", "r1m1", nil).goal.def.id == "r1m3", "끝낸 퀘스트를 켜 두었으면 이야기의 다음 곳")
end

-- 퀘스트로 열리는 문: 사당 지하는 「불타는 마을」 · 2차 전직을 받은 뒤에만 지난다
do
	expect(Navi.path("town", "in_cellar", {}) == nil, "받기 전에는 사당 지하로 가는 길이 없다")
	local path = Navi.path("town", "in_cellar", { job2 = { done = false, c = {} } })
	expect(path ~= nil and path[#path] == "in_cellar" and path[#path - 1] == "in_shrine", "2차 전직을 받으면 사당을 거쳐 내려간다")
	local book = {}
	for _, def in Quests.list do
		if def.region == "r1" and def.kind == "main" and def.id ~= "r1m9" then
			book[def.id] = { done = true, c = {} }
		end
	end
	-- 「불타는 마을」: 받기 전 = 주는 주민 · 받으면 사당 지하의 정예 창병
	local def = Quests.def("r1m9")
	local t = Navi.target("r1m9", book, 30, nil)
	expect(t ~= nil and t.kind == "npc" and t.npc == def.giver, "「불타는 마을」 받기 전")
	Quests.accept(book, 30, "r1m9")
	t = Navi.target("r1m9", book, 30, nil)
	expect(t ~= nil and t.kind == "hunt" and t.scene == "in_cellar" and t.mob == "espearman", "「불타는 마을」 받은 뒤: 사당 지하(정예 창병 — 2026-10-15)")
	eq(walk("town", t, book), 2, "마을에서 사당 지하까지 문 둘(사당 → 계단)")
end

-- 은달 항구로 가는 배: 초승달 마을의 포구(대장간 너머)에 선 선장 — 「불타는 마을」을 끝낸 뒤에만 태운다
--  사용자 2026-10-13: "은달항구는  초승달 마을에서 갈수있게합니다. 불타는 마을 퀘스트 안깨면 못가게만하고   대장간 넘어로 작은 항구같은 느낌으로 …"
--  사용자 2026-10-16: "왜 대도시로 넘어갈때 배타는건 구현을 안합니까 왜 그냥 포탈이에요" → 문(포탈)을 떼고 선장 → 배의 갑판 → 은달 항구(sim/voyage.luau)
do
	local Voyage = req("ReplicatedStorage/shared/lune/sim/voyage")
	local captain, forge = nil, nil
	for _, n in SCENES.scenes.town.npcs do
		if n.id == "captain" then
			captain = n
		end
	end
	for _, p in SCENES.scenes.town.portals do
		expect(string.sub(p.to, 1, 2) ~= "ct", "마을에 은달 항구로 가는 문(포탈)이 없다 — 배로 간다")
		if p.to == "in_forge" then
			forge = p
		end
	end
	expect(captain ~= nil, "마을의 포구에 선장이 선다")
	expect(forge ~= nil and captain and captain.x > forge.x + 40 and captain.x <= SCENES.scenes.town.w * 16 - 12, "선장은 대장간 너머(마을의 오른쪽 끝)에 있다")
	expect(npcIn("ct", "captain"), "은달 항구의 부두에도 선장(돌아오는 배)")
	-- 배에 오를 수 있는가: 없으면 · 받기만 했으면 못 타고, 끝내면 탄다 · 돌아오는 배는 늘 탄다
	local TR, CR = Voyage.route("town", "captain"), Voyage.route("ct", "captain")
	expect(not Voyage.open({}, TR), "퀘스트가 없으면 태우지 않는다")
	expect(not Voyage.open({ r1m9 = { done = false, c = { 4 } } }, TR), "받기만 해서는(다 잡았어도) 태우지 않는다")
	expect(Voyage.open({ r1m9 = { done = true, c = {} } }, TR), "끝내면 태운다")
	expect(Voyage.open({}, CR), "돌아오는 배는 늘 탄다")
	expect(Quests.finished({ r1m9 = { done = true, c = {} } }, "r1m9") and not Quests.finished({}, "r1m9") and not Quests.finished(nil, "r1m9"), "끝냈는가")
	-- 길찾기의 길도 같은 규칙이다(배는 한 걸음)
	expect(Navi.path("town", "ct", {}) == nil and Navi.path("town", "ct", { r1m9 = { done = false, c = {} } }) == nil, "끝내기 전에는 은달 항구로 가는 길이 없다")
	local path = Navi.path("town", "ct", { r1m9 = { done = true, c = {} } })
	expect(path ~= nil and #path == 2 and path[2] == "ct", "끝내면 마을에서 은달 항구까지 배 한 번")
	local back = Navi.path("ct", "town", {})
	expect(back ~= nil and #back == 2, "돌아오는 배")
	-- 겨누는 곳: 마을에서는 선장 · 갑판 위에서는 기다린다 · 닿은 뒤에는 그 사람
	local goal = { scene = "ct_smith", kind = "npc", npc = "citysmith" }
	local done = { r1m9 = { done = true, c = {} } }
	local ax, ay, kind = Navi.aim("town", 100, 176, goal, done, {})
	expect(kind == "npc" and captain and ax == captain.x and ay == captain.y, "마을에서는 선장에게로")
	local _, _, kind2 = Navi.aim("ship_out", 100, 176, goal, done, {})
	eq(kind2, "here", "갑판 위에서는 화살표를 거둔다(배가 닿기를 기다린다)")
	local _, _, kind3, door = Navi.aim("ct", 100, 480, goal, done, {})
	expect(kind3 == "portal" and door and door.to == "ct_smith", "항구에 닿으면 대장간의 문으로")
	-- 다른 길로는 은달 항구에 갈 수 없다: 1지역의 어느 맵에서도 다른 지역으로 가는 문이 없다
	for key, sc in SCENES.scenes do
		if sc.region == "r1" then
			for _, p in sc.portals or {} do
				local to = SCENES.scenes[p.to]
				expect(to == nil or to.region == "r1", ("1지역에서 다른 지역으로 가는 문이 없다(배로만) %s → %s"):format(key, p.to))
			end
		end
	end
end

-- 방향: 멀면 왼쪽 · 오른쪽, 가로로 다 왔으면 위 · 아래, 문 · 주민 앞이면 ↑(enter), 그 몬스터 곁이면 거둔다
eq(Navi.dir(100, 176, 400, 176, "portal"), "right", "문이 오른쪽")
eq(Navi.dir(400, 176, 100, 176, "portal"), "left", "문이 왼쪽")
eq(Navi.dir(100, 176, 100 + Navi.NEAR_X, 96, "portal"), "up", "문이 윗층")
eq(Navi.dir(100, 96, 100, 176, "npc"), "down", "주민이 아래층")
eq(Navi.dir(100, 176, 110, 176, "portal"), "enter", "문 앞이다")
eq(Navi.dir(100, 176, 110, 176, "npc"), "enter", "주민 앞이다")
eq(Navi.dir(100, 176, 100 + Navi.MOB_NEAR.x, 176, "mob"), "none", "몬스터 곁이면 화살표를 거둔다")
eq(Navi.dir(100, 176, 101 + Navi.MOB_NEAR.x, 176, "mob"), "right", "몬스터가 멀면 그쪽")
eq(Navi.dir(100, 176, 100, 176, "here"), "none", "그 몬스터가 아직 없으면(다시 나오기를 기다린다) 거둔다")
-- 사냥터 안: 가장 가까운 그 몬스터(다른 몬스터 · 다른 층의 것은 뒤로)
do
	local target = { scene = "hunt", kind = "hunt", mob = "warrior" }
	local ax, ay, what = Navi.aim("hunt", 300, 176, target, {}, { { kind = "shroom", x = 310, y = 176 }, { kind = "warrior", x = 600, y = 176 }, { kind = "warrior", x = 500, y = 96 } })
	expect(what == "mob" and ax == 600 and ay == 176, "가장 가까운 그 몬스터(윗층의 것은 멀게 친다)")
	ax, ay, what = Navi.aim("hunt", 300, 176, target, {}, { { kind = "shroom", x = 310, y = 176 } })
	expect(what == "here", "그 몬스터가 없으면 그 자리")
end

-- 일일 의뢰: 받기 전 = 안내 없음 · 잡는 중 = 그 사냥터 · 다 잡았다 = 의뢰 게시판
do
	local now = 1700000000
	local h = { level = 12, daily = {}, money = 0, xp = 0, dust = 0 }
	local view = Daily.view(h, now)
	local key = Navi.dailyKey("r1", 1)
	expect(Navi.target(key, {}, 12, view) == nil, "받지 않은 의뢰는 안내하지 않는다")
	expect(Daily.accept(h, "r1", 1, now), "의뢰를 받는다")
	view = Daily.view(h, now)
	local task = view.boards.r1.tasks[1]
	local t = Navi.target(key, {}, 12, view)
	expect(t ~= nil and t.kind == "hunt" and t.scene == task.scene and t.mob == task.mob and mobIn(t.scene, t.mob), "잡는 중: 그 사냥터의 그 몬스터")
	expect(walk("town", t, {}) ~= nil, "그 사냥터까지 문을 따라 닿는다")
	for _ = 1, task.n - 1 do
		Daily.onKill(h, task.mob, task.scene, now)
	end
	view = Daily.view(h, now)
	t = Navi.target(key, {}, 12, view)
	expect(t ~= nil and t.kind == "hunt", "한 마리 모자라면 아직 사냥터")
	Daily.onKill(h, task.mob, task.scene, now)
	view = Daily.view(h, now)
	t = Navi.target(key, {}, 12, view)
	local board = Daily.DATA.boards.r1
	expect(t ~= nil and t.kind == "npc" and t.scene == board.scene and t.npc == board.npc and npcIn(board.scene, board.npc), "다 잡았다: 의뢰 게시판으로")
	local ax, ay, what = Navi.aim(board.scene, 0, 0, t, {}, {})
	expect(what == "npc" and ax ~= nil, "마을에서는 게시판을 겨눈다")
	expect(Daily.turnIn(h, "r1", 1, now), "낸다")
	view = Daily.view(h, now)
	expect(Navi.target(key, {}, 12, view) == nil, "낸 의뢰는 안내하지 않는다")
	-- 알리미의 줄에 이름표가 붙는다(단추가 그 의뢰를 가리킨다)
	Daily.accept(h, "r1", 2, now)
	view = Daily.view(h, now)
	local tracked = Daily.tracked(view)
	expect(#tracked == 1 and tracked[1].region == "r1" and tracked[1].i == 2, "받아 둔 의뢰의 지역 · 차례")
	local rows = Panel.layout({}, {}, 12, nil, tracked)
	local found = false
	for _, row in rows do
		found = found or (row.kind == "quest" and row.key == Navi.dailyKey("r1", 2))
	end
	expect(found, "일일 의뢰의 줄에 길찾기 이름표")
end

-- ---- 3) 알리미의 단추: 줄마다 · 이름이 단추에 닿지 않는다 ----
do
	local names = {}
	for _, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			names[n.id] = n.name
		end
	end
	expect(Panel.NAV_W >= 14 and Panel.NAV_H >= 11 and Panel.NAME_W > 60 and Panel.GUIDE_W > 100, "단추와 이름의 폭")
	for _, def in Quests.list do
		if def.playable then
			local w = pixelText.Measure(def.name, "body")
			expect(w <= Panel.NAME_W, ("퀘스트 이름이 표와 단추 사이에 들어간다 %s — %s(%d > %d)"):format(def.id, def.name, w, Panel.NAME_W))
		end
	end
	-- 받을 수 있는 퀘스트의 제목(길잡이)도
	for level = 1, 30 do
		local book = {}
		for _, def in Quests.list do
			if def.region == "r1" and def.kind == "main" and def.lv < level then
				book[def.id] = { done = true, c = {} }
			end
		end
		for _, g in Quests.guide(book, level, names) do
			if g.kind ~= "level" then
				expect(g.id ~= nil and Quests.def(g.id) ~= nil, "길잡이의 줄에 퀘스트의 이름표 " .. tostring(g.title))
				local w = pixelText.Measure(g.title, "body")
				expect(w <= Panel.GUIDE_W, ("받을 수 있는 퀘스트의 제목이 단추에 닿지 않는다 %s(%d > %d)"):format(g.title, w, Panel.GUIDE_W))
				expect(Navi.target(g.id, book, level, nil) ~= nil, "길잡이의 줄은 안내할 곳이 있다 " .. tostring(g.id))
			end
		end
	end
	-- 일일 의뢰의 이름(맵의 이름)
	for _, q in Daily.DATA.boards.r1.pool do
		local w = pixelText.Measure(q.place, "body")
		expect(w <= Panel.NAME_W, ("일일 의뢰의 맵 이름이 들어간다 %s(%d)"):format(q.place, w))
	end
end

-- ---- 4) 화면 없이 돌려 본다: 알리미의 단추(client/lune/questHud.luau) · 머리 위의 화살표(client/lune/naviArrow.luau) ----
do
	local boxes, hits = {}, {}
	local function frame(name: string?, parent, x, y, w, h)
		local f = { Name = name or "Frame", ZIndex = 1, Visible = true, parent = parent, Parent = parent, x = x, y = y, w = w, h = h, Size = { X = { Offset = w or 7 }, Y = { Offset = h or 9 } }, kids = {} }
		function f:Destroy() end
		function f:GetChildren()
			return {}
		end
		return f
	end
	local texts = {}
	local panels, scrolls = {}, {}
	MOCK("Client/lune/ui/ui", {
		COLOR = setmetatable({}, { __index = function(_, k) return k end }),
		M = { small = 10, body = 12 },
		measure = function(text: string, font: string?) return (pixelText.Measure(text, font or "small")) end,
		box = function(parent, x, y, w, h, color, alpha)
			expect(w > 0 and h > 0, "네모의 크기가 0보다 크다")
			local f = frame("Box", parent, x, y, w, h)
			f.color = color
			f.BackgroundTransparency = alpha or 0
			table.insert(boxes, f)
			return f
		end,
		panel = function(parent, x, y, w, h)
			local f = frame("Panel", parent, x, y, w, h)
			table.insert(panels, f)
			return f
		end,
		scroll = function(parent, x, y, w, h, contentH, barW)
			expect(h > 0 and contentH >= h - 1e-6, ("스크롤하는 칸: 속(%d)이 칸(%d)보다 짧지 않다"):format(contentH, h))
			local f = frame("Scroll", parent, x, y, w, h)
			f.contentH, f.barW, f.long = contentH, barW, contentH > h
			f.CanvasPosition = Vector2.new(0, 0)
			table.insert(scrolls, f)
			return f
		end,
		group = function(parent, x, y, w, h, name) return frame(name, parent, x, y, w, h) end,
		text = function(parent, text, x, y, width, opts)
			table.insert(texts, { text = text, x = x, y = y, w = width, font = opts and opts.font or "small", parent = parent })
			return { set = function() end }
		end,
		bar = function() return { set = function() end } end,
		hit = function(parent)
			return { Activated = { Connect = function(_, fn) table.insert(hits, { frame = parent, fn = fn }) end } }
		end,
	})
	local KITDATA = req("ReplicatedStorage/shared/lune/data/kit.generated")
	MOCK("Client/lune/ui/kit", {
		part = function(parent, name)
			local q = KITDATA.parts[name]
			expect(q ~= nil, "있는 부품 " .. tostring(name))
			local f = frame("Part", parent, 0, 0, q.w, q.h)
			f.part = name
			return f
		end,
		partSize = function(name) return KITDATA.parts[name].w, KITDATA.parts[name].h end,
	})
	local resize = {}
	local StageMock = { uiH = 540, place = function(root, name, at, x, y, w, h) return frame(name, root, x, y, w, h) end, atPosition = function() return {} end, onResize = function(fn) table.insert(resize, fn) end }
	MOCK("Client/lune/stage", StageMock)
	MOCK("Client/lune/overlay", { layer = function(name) return frame(name) end, x = function(wx) return wx * 2 end, y = function(wy) return wy * 2 end })
	local QuestHud = req("Client/lune/questHud")
	eq(QuestHud.size, Panel.MID, "처음에는 중간 — 중요한 것만 보인다(사용자 2026-10-13: \"퀘스트는 중요한것만 보이는게 디폴트입니다\")")
	QuestHud.size = Panel.MAX -- 아래는 모두 보는 크기에서 본다
	QuestHud.init(frame("Root"))
	local pressed = {}
	QuestHud.onNavi = function(key)
		table.insert(pressed, key)
	end
	-- 하는 중인 메인 하나 + 받을 수 있는 퀘스트들
	local book = { r1m1 = { done = true, c = {} }, r1m2 = { done = true, c = {} }, r1m3 = { done = false, c = { 3 } } }
	local names = {}
	for _, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			names[n.id] = n.name
		end
	end
	local rows = Panel.layout(book, names, 6, Panel.maxH(540, false), nil)
	local keys = 0
	for _, row in rows do
		if row.key then
			keys += 1
		end
	end
	eq(keys, 1, "하는 중인 퀘스트의 줄에만 이름표가 있다(받을 수 있는 퀘스트는 알리미에 적지 않는다 — 사용자 2026-10-13)")
	QuestHud.navi = "r1m3"
	QuestHud.set(book, names, 6, nil)
	eq(#hits, keys + 1, "이름표가 있는 줄마다 길찾기 단추 하나 + 머리줄의 「−」 단추(가장 큰 크기라 「+」는 누를 수 없다)")
	local onCount = 0
	for _, b in boxes do
		if string.sub(b.Name, 1, 5) == "Navi_" then
			-- 단추는 판 안 · 오른쪽 끝
			expect(b.x + b.w == Panel.PAD + Panel.INNER and b.x >= Panel.PAD and b.w == Panel.NAV_W and b.h == Panel.NAV_H, "단추의 자리 " .. b.Name)
			if b.color == "accent" then
				onCount += 1
				eq(b.Name, "Navi_r1m3", "켠 줄의 단추만 민트")
			else
				eq(b.color, "panel2", "꺼진 단추는 원래 색(어두운 바탕)")
			end
			-- 같은 줄의 글이 단추에 닿지 않는다
			for _, t in texts do
				if t.y == b.y and t.parent == b.parent then
					local w = pixelText.Measure(t.text, t.font)
					expect(t.x + math.min(w, t.w) <= b.x, ("이름이 단추에 닿지 않는다 %s(%d + %d > %d)"):format(t.text, t.x, w, b.x))
				end
			end
		end
	end
	eq(onCount, 1, "켠 단추는 하나")
	-- 켠 단추는 빛난다(사용자 2026-10-13: "길찾기 활성화되면  빛나고   다시눌러서 비활성화하면 원래색으로"): 둘레의 밝은 빛이 밝아졌다 옅어졌다 한다 · 끄면 빛이 없다
	local glows, shines = 0, 0
	for _, b in boxes do
		glows += if b.Name == "NaviGlow" then 1 else 0
		shines += if b.Name == "Shine" then 1 else 0
	end
	expect(glows == 1 and shines == 1 and QuestHud.glow ~= nil and QuestHud.glow.color == "accentHot", "켠 단추의 둘레에 밝은 빛 하나 · 위쪽의 밝은 줄")
	expect(QuestHud.glow.w == Panel.NAV_W + 4 and QuestHud.glow.h == Panel.NAV_H + 4, "빛은 단추보다 두 점씩 넓다")
	local seen = {}
	for k = 0, 40 do
		QuestHud.step(k / 20)
		local a = QuestHud.glow.BackgroundTransparency
		expect(a >= QuestHud.GLOW.min - 1e-6 and a <= QuestHud.GLOW.max + 1e-6, "빛의 비침은 정한 사이를 오간다")
		seen[math.floor(a * 10)] = true
	end
	local kinds = 0
	for _ in seen do
		kinds += 1
	end
	expect(kinds >= 4, "빛이 밝아졌다 옅어졌다 한다")
	table.clear(boxes)
	table.clear(hits)
	table.clear(texts)
	QuestHud.navi = nil
	QuestHud.set(book, names, 6, nil)
	for _, b in boxes do
		expect(b.Name ~= "NaviGlow" and b.Name ~= "Shine" and b.color ~= "accent", "끄면 모든 단추가 원래 색이고 빛이 없다")
	end
	expect(QuestHud.glow == nil, "끄면 빛이 없다")
	QuestHud.step(1) -- 빛이 없을 때 불러도 아무 일 없다
	table.clear(boxes)
	table.clear(hits)
	table.clear(texts)
	QuestHud.navi = "r1m3"
	QuestHud.set(book, names, 6, nil)
	for _, hit in table.clone(hits) do
		if hit.frame.Name == "NaviHit" then
			expect(hit.frame.w >= Panel.NAV_W + 6 and hit.frame.h >= Panel.NAV_H + 4, "누르는 자리는 그림보다 넓다(손가락)")
			hit.fn()
		end
	end
	eq(#pressed, keys, "단추를 누르면 그 줄의 이름표가 온다")
	expect(table.find(pressed, "r1m3") ~= nil, "하는 중인 퀘스트의 단추")

	-- 머리 위의 화살표: 방향마다 하나만 보인다 · 「enter」는 위쪽 화살표 · 「none」 · nil이면 감춘다 · 캐릭터 머리 위(발밑에서 UP만큼 위)
	local NaviArrow = req("Client/lune/naviArrow")
	local arrow = NaviArrow.new()
	local function shown(): { string }
		local out = {}
		for name, f in arrow.frames do
			if f.Visible then
				table.insert(out, name)
			end
		end
		return out
	end
	eq(#shown(), 0, "처음에는 안 보인다")
	for _, dir in { "left", "right", "up", "down" } do
		arrow:set(dir, 200, 176, 0)
		local s = shown()
		expect(#s == 1 and s[1] == dir, "가리키는 쪽의 화살표만 보인다 " .. dir)
		local f = arrow.frames[dir]
		local w, h = arrow.size[dir][1], arrow.size[dir][2]
		expect(math.abs(f.Position.X.Offset + w / 2 - 400) <= NaviArrow.WAVE.reach + 1 and math.abs(f.Position.Y.Offset + h / 2 - (176 - NaviArrow.UP) * 2) <= NaviArrow.WAVE.reach + 1, "캐릭터 머리 위에 놓인다 " .. dir)
		expect(f.Position.X.Offset == math.floor(f.Position.X.Offset) and f.Position.Y.Offset == math.floor(f.Position.Y.Offset), "반 점에 걸치지 않는다 " .. dir)
	end
	arrow:set("enter", 200, 176, 0)
	expect(#shown() == 1 and shown()[1] == "up", "문 · 주민 앞에서는 위쪽 화살표(↑를 누른다)")
	arrow:set("none", 200, 176, 0)
	eq(#shown(), 0, "다 왔으면 감춘다")
	arrow:set("left", 200, 176, 0)
	arrow:hide()
	eq(#shown(), 0, "끄면 감춘다")
	expect(NaviArrow.UP >= 36 and NaviArrow.UP <= 60, "머리 위(이름표는 발밑에 있어 가리지 않는다)")
	-- 화살표의 그림: Codex의 그림을 옮긴 부품 넷(사용자 2026-10-13: "화살표 퀄리티 더 올리고") — 방향마다 제 그림이 있고, 정수 배로 키운다(도트가 뭉개지지 않게)
	expect(NaviArrow.SCALE == math.floor(NaviArrow.SCALE) and NaviArrow.SCALE >= 1, "정수 배")
	for dir, part in NaviArrow.PART do
		local q = KITDATA.parts[part]
		expect(q ~= nil and q.w >= 12 and q.w <= 17 and q.h >= 12 and q.h <= 17, "화살표의 부품 " .. dir)
		eq(arrow.frames[dir].part, part, "그 방향의 부품을 쓴다 " .. dir)
		eq(arrow.size[dir][1], q.w * NaviArrow.SCALE, "화면에서의 폭 " .. dir)
	end

	-- ---- 5) 「−」 = 중요한 것만(메인 · 전직 · 일일 의뢰) · 「+」 = 모두 — 판은 정한 높이까지만, 넘치면 스크롤 ----
	--  사용자 2026-10-13: "퀘스트 가 - 누르면 중요한거 메인 , 일퀘 이런거만 뜨고  + 누르면 다보이는 식이여야죠
	--                     그리고 + 누르면  다보일때 그냥 다보이는게 아니라 스크롤을 넣어야죠 무식하게 아래로 계속확장하면 어쩌라는거에요"
	-- 받을 수 있는 만큼(Q.MAX_ACTIVE) 받는다: 1지역의 메인 둘 + 부탁들
	--  (2026-10-13: 1지역의 퀘스트는 모두 줄에 든 메인이다 — 부탁은 다른 지역의 것으로 채운다. 실제로는 한 줄에서 하나씩만 받지만, 여기서는 판이 가득 찼을 때의 모습을 본다)
	local full, mains, sides = {}, 0, 0
	for _, def in Quests.list do
		if def.playable and def.kind == "side" and sides < Quests.MAX_ACTIVE - 2 then
			full[def.id] = { done = false, c = {} }
			sides += 1
		end
	end
	for _, def in Quests.list do
		if def.playable and def.kind == "main" and def.region == "r1" and mains + sides < Quests.MAX_ACTIVE then
			full[def.id] = { done = false, c = {} }
			mains += 1
		end
	end
	local active = #Quests.active(full)
	expect(active == Quests.MAX_ACTIVE and mains >= 2 and sides >= 2 and sides == active - mains, ("받을 수 있는 만큼 받았다(메인 %d · 부탁 %d)"):format(mains, sides))
	local daily2 = { { name = "포자 주머니", place = "달그림자 사냥터", n = 8, have = 3, region = "r1", i = 1 }, { name = "고갯길 염소", place = "굽잇길", n = 8, have = 8, region = "r1", i = 2 } }
	local total = active + #daily2
	-- 판의 가장 큰 높이: 공방의 칸. 창이 작아도 메뉴 단추에 닿지 않는다 · 아래로 끝없이 자라지 않는다
	for _, gridH in { 648, 540, 432 } do
		local maxH = Panel.maxH(gridH, false)
		expect(maxH <= Panel.H and maxH >= 150 and maxH + 60 + (540 - 480) <= gridH, ("판의 가장 큰 높이 %d(격자 %d)"):format(maxH, gridH))
	end
	eq(Panel.maxH(432, true), Panel.H_TOUCH, "스마트폰의 칸")
	-- 모두(「+」를 누른 모습): 받은 것이 다 적힌다 · 판은 가장 큰 높이까지만이고 그 안에서 스크롤한다
	for _, case in { { 540, false }, { 432, false }, { 432, true } } do
		local maxH = Panel.maxH(case[1], case[2])
		local rows2, height, shown2, guided2, info = Panel.layout(full, names, 30, maxH, daily2, false)
		eq(shown2, total, ("모두: 받은 퀘스트 %d개와 일일 의뢰 %d개가 다 적힌다"):format(active, #daily2))
		expect(info.total == total and info.hidden == 0 and info.any, "모두: 숨긴 것이 없다")
		expect(height > maxH and info.scroll and info.view == maxH, ("모두: 적은 것(%d)이 판(%d)보다 길면 판은 그 높이까지만이고 스크롤한다"):format(height, maxH))
		local keysSeen, lastY = {}, 0
		for _, row in rows2 do
			expect(row.y >= lastY, "줄은 위에서 아래로")
			lastY = row.y
			if row.kind == "quest" then
				expect(row.key ~= nil, "줄마다 길찾기 이름표 " .. row.name)
				keysSeen[row.key] = true
			end
		end
		expect(lastY < height, "마지막 줄도 적은 것의 높이 안")
		for id in full do
			expect(keysSeen[id], "받은 퀘스트의 줄이 있다 " .. id)
		end
		expect(keysSeen[Navi.dailyKey("r1", 1)] and keysSeen[Navi.dailyKey("r1", 2)], "일일 의뢰의 줄도 있다")
	end
	-- 중요한 것만(「−」를 누른 모습): 메인 · 전직 · 일일 의뢰만 — 부탁은 빠진다
	do
		local maxH = Panel.maxH(540, false)
		local rows2, height, shown2, guided2, info = Panel.layout(full, names, 30, maxH, daily2, true)
		eq(shown2, mains + #daily2, "중요한 것만: 메인과 일일 의뢰")
		expect(info.hidden == sides and info.total == total and info.fold, "중요한 것만: 부탁은 숨긴 수로 센다 · 받은 것 모두의 수는 그대로")
		for _, row in rows2 do
			if row.kind == "quest" then
				expect(Panel.KEY_TAGS[row.tag] == true, "중요한 것만: 메인 · 전직 · 일일 의뢰의 줄뿐 — " .. row.name)
			elseif row.kind == "guide" then
				expect(row.tone ~= "side", "중요한 것만: 받을 수 있는 부탁은 적지 않는다")
			end
		end
		local _, heightAll = Panel.layout(full, names, 30, maxH, daily2, false)
		expect(height < heightAll - sides * Panel.TITLE and info.view == math.min(height, maxH), ("중요한 것만: 적은 것이 훨씬 짧다(%d < %d)"):format(height, heightAll))
		-- 흔한 모습(메인 하나 + 일일 의뢰 하나): 판이 짧고 스크롤이 없다
		local _, hOne, sOne, _, iOne = Panel.layout({ r1m1 = { done = true, c = {} }, r1m2 = { done = false, c = { 2 } }, r1s1 = nil }, names, 12, maxH, { daily2[1] }, true)
		expect(sOne == 2 and hOne <= maxH and not iOne.scroll and iOne.view == hOne, ("중요한 것만 · 메인 하나 + 일일 하나: 판이 짧다(%d / %d)"):format(hOne, maxH))
		-- 전직 퀘스트도 중요한 것이다
		local withJob = { job2 = { done = false, c = {} } }
		for id, st in full do
			withJob[id] = st
		end
		local rows3 = Panel.layout(withJob, names, 30, maxH, nil, true)
		local seenJob = false
		for _, row in rows3 do
			seenJob = seenJob or (row.kind == "quest" and row.tag == "job")
		end
		expect(seenJob, "중요한 것만: 전직 퀘스트가 뜬다")
		-- 부탁만 받아 두었을 때: 줄은 없어도 적을 것이 있다(머리줄과 「+」가 남는다)
		local onlySide = {}
		for _, def in Quests.list do
			if def.kind == "main" or def.kind == "job" then
				onlySide[def.id] = { done = true, c = {} }
			end
		end
		local sideId = nil
		for _, def in Quests.list do
			if def.playable and def.kind == "side" and not sideId then -- (1지역의 것은 모두 줄에 든 메인이다 — 다른 지역의 부탁)
				sideId = def.id
			end
		end
		onlySide[sideId] = { done = false, c = {} }
		local _, _, s4, _, i4 = Panel.layout(onlySide, names, 200, maxH, nil, true)
		expect(s4 == 0 and i4.total == 1 and i4.hidden == 1 and i4.any, "부탁만 받았을 때: 중요한 것은 없지만 적을 것은 있다")
	end
	-- 적게 받았을 때: 스크롤 없이 적은 만큼만
	do
		local few = { r1m1 = { done = true, c = {} }, r1m2 = { done = false, c = { 2 } } }
		local rows2, height, shown2, _, info = Panel.layout(few, names, 2, Panel.maxH(540, false), nil, false)
		local steps = 0
		for _, row in rows2 do
			steps += if row.kind == "step" then 1 else 0
		end
		expect(shown2 == 1 and steps == 1 and not info.scroll and info.view == height, "적게 받았으면 판은 적은 만큼만이고 스크롤이 없다")
	end
	-- ---- 크기 세 단계(사용자 2026-10-13: "최소화   중간   최대화  이렇게 해서   최소화는 다 닫히는거  중간은  현재 최소화  최대화는  지금 최대화 로 해서  +- 버튼을 몇번더 누르냐에 따라 늘리고 줄일수 있도록") ----
	do
		local maxH = Panel.maxH(540, false)
		eq(Panel.SIZE_FIRST, Panel.MID, "처음의 크기는 중간")
		-- 셈: 최소 = 줄이 없다(머리줄의 높이) · 중간 = 중요한 것만 · 최대 = 모두
		local r0, h0, s0, g0, i0 = Panel.layout(full, names, 30, maxH, daily2, Panel.MIN)
		expect(#r0 == 0 and h0 == Panel.HEAD + 2 and s0 == 0 and g0 == 0 and i0.view == Panel.HEAD + 2 and not i0.scroll and i0.total == total and i0.any and i0.size == Panel.MIN, "최소: 줄이 없고 머리줄만 — 받은 것의 수는 그대로 안다")
		local _, _, s1, _, i1 = Panel.layout(full, names, 30, maxH, daily2, Panel.MID)
		local _, _, s2, _, i2 = Panel.layout(full, names, 30, maxH, daily2, Panel.MAX)
		expect(s1 == mains + #daily2 and i1.size == Panel.MID and s2 == total and i2.size == Panel.MAX and s1 < s2, "중간 = 중요한 것만 · 최대 = 모두")
		-- 예전의 꼴로 불러도 같다(true = 중간 · false / 없음 = 최대)
		local _, _, sa = Panel.layout(full, names, 30, maxH, daily2, true)
		local _, _, sb = Panel.layout(full, names, 30, maxH, daily2, false)
		expect(sa == s1 and sb == s2, "예전의 꼴")
	end
	local function draw()
		table.clear(boxes)
		table.clear(hits)
		table.clear(texts)
		table.clear(panels)
		table.clear(scrolls)
		QuestHud.set(full, names, 30, daily2)
	end
	local function find(name: string)
		for _, b in boxes do
			if b.Name == name then
				return b
			end
		end
		return nil
	end
	local function hitOf(name: string)
		for _, hit in hits do
			if hit.frame.Name == name then
				return hit
			end
		end
		return nil
	end
	local function has(text: string): boolean
		for _, t in texts do
			if t.text == text then
				return true
			end
		end
		return false
	end
	local function naviHits(): number
		local n = 0
		for _, hit in hits do
			n += if hit.frame.Name == "NaviHit" then 1 else 0
		end
		return n
	end
	local function keyRows(size: number, gridH: number): number
		local n = 0
		for _, row in (Panel.layout(full, names, 30, Panel.maxH(gridH, false), daily2, size)) do
			n += if row.key then 1 else 0
		end
		return n
	end
	local function inked(btn): string
		-- 단추의 글씨가 켜져 있는가(누를 수 있다) · 흐린가
		for _, b in boxes do
			if b.parent == btn then
				return b.Name
			end
		end
		return ""
	end
	local maxH = Panel.maxH(540, false)
	-- ① 최대: 모두 · 넘치면 스크롤 · 「−」만 누를 수 있다
	QuestHud.size, QuestHud.navi, QuestHud.scrollY = Panel.MAX, nil, 0
	StageMock.uiH = 540
	draw()
	local minus, plus = find("FoldMinus"), find("FoldPlus")
	expect(minus ~= nil and plus ~= nil, "「−」와 「+」 단추가 늘 둘 다 있다(자리가 바뀌지 않는다)")
	expect(plus.x + plus.w == Panel.PAD + Panel.INNER and minus.x + minus.w + Panel.FOLD_BETWEEN == plus.x and minus.y >= 0 and minus.y + minus.h <= Panel.HEAD, "단추 둘은 머리줄의 오른쪽 끝에 나란히")
	expect(inked(minus) == "Bar" and inked(plus) == "BarOff" and hitOf("MinusHit") ~= nil and hitOf("PlusHit") == nil, "최대: 「−」만 누를 수 있다(「+」는 흐리다)")
	expect(has(("진행 %d"):format(total)) and QuestHud.total == total, "머리줄에 받은 것 모두의 수")
	eq(naviHits(), keyRows(Panel.MAX, 540), "최대: 줄마다 길찾기 단추")
	expect(naviHits() >= total, "최대: 받은 것마다 길찾기 단추가 있다")
	eq(#panels, 1, "판 하나")
	eq(panels[1].h, maxH, "판은 가장 큰 높이까지만 자란다(아래로 계속 늘어나지 않는다)")
	eq(#scrolls, 1, "스크롤하는 칸 하나")
	local sc = scrolls[1]
	expect(sc.long and sc.y == Panel.LIST_TOP and sc.y + sc.h <= panels[1].h and sc.w == Panel.W, "스크롤하는 칸은 머리줄 아래 · 판 안")
	expect(sc.barW == Panel.SCROLL_W and Panel.SCROLL_W <= Panel.W - (Panel.PAD + Panel.INNER), "스크롤 막대는 오른쪽 여백 안(길찾기 단추를 가리지 않는다)")
	local deepest = 0
	for _, b in boxes do
		if b.parent == sc then
			deepest = math.max(deepest, b.y + b.h)
			expect(b.y >= 0, "칸 안의 것은 속의 위에서부터")
		end
	end
	for _, t in texts do
		if t.parent == sc then
			deepest = math.max(deepest, t.y + 10)
		end
	end
	expect(deepest > sc.h and deepest <= sc.contentH, ("끝까지 내리면 마지막 줄이 보인다(속 %d · 마지막 %d · 칸 %d)"):format(sc.contentH, deepest, sc.h))
	for _, hit in hits do
		if hit.frame.Name == "NaviHit" then
			expect(hit.frame.parent == sc, "길찾기 단추도 스크롤하는 칸 안")
		else
			expect(hit.frame.parent == panels[1], "크기를 바꾸는 단추는 머리줄에(스크롤해도 늘 보인다)")
		end
	end
	local mh = hitOf("MinusHit")
	expect(mh.frame.w >= 20 and mh.frame.h >= 20, "단추의 누르는 자리(손가락)")
	expect(mh.frame.x + mh.frame.w <= plus.x, "「−」의 누르는 자리가 「+」에 겹치지 않는다")
	for _, t in texts do
		if string.sub(t.text, 1, 6) == "진행" then
			expect(t.x + t.w <= minus.x - 2, "「진행 N」이 단추에 닿지 않는다")
		end
	end
	local allContent = sc.contentH
	-- 스크롤한 자리는 다시 그려도 그대로다(몬스터를 잡아 숫자가 오를 때마다 다시 그린다)
	sc.CanvasPosition = Vector2.new(0, 77)
	draw()
	eq(scrolls[1].CanvasPosition.Y, 77, "다시 그려도 스크롤한 자리에 머문다")
	scrolls[1].CanvasPosition = Vector2.new(0, 99999)
	draw()
	eq(scrolls[1].CanvasPosition.Y, scrolls[1].contentH - scrolls[1].h, "속이 줄어도 끝을 넘지 않는다")
	-- ② 「−」 한 번: 중간(중요한 것만) · 두 단추 다 누를 수 있다
	hitOf("MinusHit").fn()
	expect(QuestHud.size == Panel.MID and QuestHud.scrollY == 0, "최대에서 「−」 = 중간 · 맨 위부터")
	draw()
	expect(inked(find("FoldMinus")) == "Bar" and inked(find("FoldPlus")) == "Bar" and hitOf("MinusHit") ~= nil and hitOf("PlusHit") ~= nil, "중간: 「−」 · 「+」 둘 다 누를 수 있다")
	local ph, mh2 = hitOf("PlusHit"), hitOf("MinusHit")
	expect(mh2.frame.x + mh2.frame.w <= ph.frame.x, "두 단추의 누르는 자리가 겹치지 않는다")
	eq(naviHits(), keyRows(Panel.MID, 540), "중간: 그 줄들의 길찾기 단추")
	expect(naviHits() >= mains + #daily2 and naviHits() < total, "중간: 메인 · 일일 의뢰는 있고 부탁은 없다")
	expect(has(("진행 %d"):format(total)), "중간에서도 받은 것 모두의 수가 보인다")
	expect(panels[1].h <= maxH and #scrolls == 1 and scrolls[1].contentH < allContent, ("중간: 적은 것이 최대일 때보다 짧다(%d < %d)"):format(scrolls[1].contentH, allContent))
	local tags = 0
	for _, b in boxes do
		tags += if b.Name == "Tag" then 1 else 0
	end
	eq(tags, mains + #daily2, "중간: 갈래의 표는 메인 · 일일 의뢰의 것뿐")
	-- ③ 「−」 한 번 더: 최소(다 닫힌다 — 머리줄만) · 「+」만 누를 수 있다
	hitOf("MinusHit").fn()
	eq(QuestHud.size, Panel.MIN, "중간에서 「−」 = 최소")
	draw()
	expect(#scrolls == 0 and find("HeadLine") == nil and find("Tag") == nil and naviHits() == 0, "최소: 다 닫힌다(줄이 없다)")
	eq(panels[1].h, Panel.HEAD + 2, "최소: 판은 머리줄만")
	expect(has("퀘스트") and has(("진행 %d"):format(total)) and QuestHud.box.Visible == true, "최소에서도 머리줄(「퀘스트」 · 받은 것의 수)은 보인다")
	expect(inked(find("FoldMinus")) == "BarOff" and inked(find("FoldPlus")) == "Bar" and hitOf("MinusHit") == nil and hitOf("PlusHit") ~= nil, "최소: 「+」만 누를 수 있다(「−」는 흐리다)")
	eq(#hits, 1, "최소: 누를 것은 「+」뿐")
	-- ④ 「+」 두 번: 중간 → 최대
	hitOf("PlusHit").fn()
	eq(QuestHud.size, Panel.MID, "최소에서 「+」 = 중간")
	draw()
	eq(naviHits(), keyRows(Panel.MID, 540), "중간으로 돌아왔다")
	hitOf("PlusHit").fn()
	eq(QuestHud.size, Panel.MAX, "중간에서 「+」 = 최대")
	draw()
	eq(naviHits(), keyRows(Panel.MAX, 540), "최대: 다시 모두 뜬다")
	expect(hitOf("PlusHit") == nil, "최대에서는 더 늘릴 수 없다")
	-- 창 크기가 바뀌면(격자가 달라지면) 다시 그린다 — 작은 창에서는 판이 더 낮고, 그래도 모두 스크롤로 볼 수 있다
	expect(#resize >= 1, "격자가 바뀔 때 다시 그리게 걸어 둔다")
	StageMock.uiH = 432
	table.clear(boxes)
	table.clear(hits)
	table.clear(texts)
	table.clear(panels)
	table.clear(scrolls)
	resize[1]()
	expect(panels[1].h == Panel.maxH(432, false) and scrolls[1].long and naviHits() == keyRows(Panel.MAX, 432), "작은 창: 판은 그 창의 가장 큰 높이까지 · 모두 스크롤 칸 안에")
	-- 스마트폰: 손가락 단추 위의 낮은 칸 — 그 안에서 스크롤한다
	QuestHud.touch = true
	draw()
	expect(panels[1].h == Panel.H_TOUCH and scrolls[1].long and naviHits() >= total, "스마트폰: 판은 손가락 단추 위까지만 · 받은 것은 모두 스크롤 칸 안에")
	QuestHud.touch = false
	StageMock.uiH = 540
	-- 부탁만 받아 두고 중간으로 보는 중: 머리줄과 단추는 남는다(다시 늘릴 수 있어야 한다)
	do
		local onlySide = {}
		for _, def in Quests.list do
			if def.kind == "main" or def.kind == "job" then
				onlySide[def.id] = { done = true, c = {} }
			end
		end
		for _, def in Quests.list do
			if def.playable and def.kind == "side" then
				onlySide[def.id] = { done = false, c = {} }
				break
			end
		end
		QuestHud.size = Panel.MID
		table.clear(boxes)
		table.clear(hits)
		table.clear(panels)
		table.clear(scrolls)
		QuestHud.set(onlySide, names, 200, nil)
		expect(QuestHud.box.Visible == true and hitOf("PlusHit") ~= nil and #scrolls == 0 and panels[1].h == Panel.HEAD + 2, "부탁만 받았고 중간으로 보는 중: 머리줄과 단추만")
	end
	-- 받은 것도 받을 것도 없으면 판이 없다(어느 크기에서든)
	local doneAll = {}
	for _, def in Quests.list do
		doneAll[def.id] = { done = true, c = {} }
	end
	for _, size in { Panel.MIN, Panel.MID, Panel.MAX } do
		QuestHud.size = size
		QuestHud.set(doneAll, names, 200, nil)
		expect(QuestHud.box.Visible == false, "적을 것이 없으면 판이 없다")
	end
	QuestHud.size = Panel.SIZE_FIRST
end

-- ---- 6) 최종 점검(2026-10-13)에서 넣은 것: 나루가 열렸을 때의 알림 · 큰 알림이 겹칠 때 차례로 · 길을 알려 주는 말 ----
do
	-- 「불타는 마을」을 끝내면 열리는 문 = 초승달 마을의 나루
	local opened = Quests.opens("r1m9")
	expect(#opened == 1 and opened[1].scene == "town" and opened[1].place == "초승달 마을" and string.find(opened[1].label, "은달 항구", 1, true) ~= nil, "「불타는 마을」을 끝내면 초승달 마을에 은달 항구로 가는 문이 열린다")
	eq(#Quests.opens("r1m1"), 0, "문을 여는 퀘스트가 아니면 없다")
	local line = Quests.OPENED.line:format(opened[1].place, opened[1].label)
	-- 촌장의 마지막 말이 그 나루를 가리킨다(전에는 "야영지 너머 은달 항구의 부두에서 배를 타게" — 길을 바꾸기 전의 말이었다)
	local last = Quests.def("r1m9").done
	local said = table.concat(last, " ")
	expect(string.find(said, "나루", 1, true) ~= nil and string.find(said, "은달 항구", 1, true) ~= nil and string.find(said, "야영지 너머", 1, true) == nil, "촌장의 마지막 말이 마을의 나루를 가리킨다: " .. said)
	-- 마을의 샛별: 왼쪽 문은 「마을 어귀」로 간다
	local gateTo, guideSays = nil, ""
	for _, p in SCENES.scenes.town.portals do
		if p.x < 100 then
			gateTo = p.to
		end
	end
	for _, n in SCENES.scenes.town.npcs do
		if n.id == "guide" then
			guideSays = table.concat(n.lines, " ")
		end
	end
	expect(gateTo ~= nil and string.find(guideSays, SCENES.scenes[gateTo].name, 1, true) ~= nil, ("마을의 샛별이 말하는 곳 = 그 문이 가는 곳(%s): %s"):format(tostring(gateTo and SCENES.scenes[gateTo].name), guideSays))

	-- 큰 알림: 앞의 것이 떠 있는 동안 온 것은 덮어쓰지 않고 차례로 뜬다
	local shownTitle, shownSub = "", ""
	local function frame(name)
		return { Name = name, Visible = false }
	end
	MOCK("Client/lune/ui/ui", {
		COLOR = setmetatable({}, { __index = function(_, k) return k end }),
		M = { small = 10, body = 12 },
		text = function(parent, text, x, y, width, opts)
			local isTitle = opts and opts.font == "body"
			local isSub = opts and opts.font == nil and opts.lines == nil
			return { set = function(_, v)
				if isTitle then
					shownTitle = v
				elseif isSub then
					shownSub = v
				end
			end }
		end,
	})
	local bannerBox = nil
	MOCK("Client/lune/stage", { REF_W = 960, place = function(root, name)
		local f = frame(name)
		if name == "GuideBanner" then
			bannerBox = f
		end
		return f
	end })
	local Guide = req("Client/lune/guide")
	Guide.init(frame("Root"))
	expect(pixelText.Measure(Quests.OPENED.head, "body") <= Guide.BANNER_W and pixelText.Measure(line, "small") <= Guide.BANNER_W, "「새 길이 열렸다」의 글이 알림 칸에 들어간다: " .. line)
	Guide.banner(Quests.OPENED.head, line, 7)
	expect(bannerBox.Visible == true and shownTitle == Quests.OPENED.head and shownSub == line, "나루가 열렸다는 알림이 뜬다")
	-- 같은 순간에 「달이 부른다」가 온다(「불타는 마을」을 끝내며 Lv.30이 됐다): 덮어쓰지 않는다
	Guide.banner("달이 부른다", "그믐 사제에게 가서 「2차 전직」 퀘스트를 받는다", 6)
	eq(shownTitle, Quests.OPENED.head, "앞의 알림이 떠 있는 동안에는 덮어쓰지 않는다")
	Guide.banner("달이 부른다", "그믐 사제에게 가서 「2차 전직」 퀘스트를 받는다", 6) -- 같은 것이 또 와도 한 번만 기다린다
	for _ = 1, 60 * 6 do
		Guide.step(1 / 60)
	end
	eq(shownTitle, Quests.OPENED.head, "제 시간(7초)이 다 가기 전에는 그대로")
	for _ = 1, 60 * 1 + 5 do
		Guide.step(1 / 60)
	end
	expect(shownTitle == "달이 부른다" and bannerBox.Visible == true, "앞의 것이 사라지면 다음 알림이 뜬다")
	for _ = 1, 60 * 6 + 5 do
		Guide.step(1 / 60)
	end
	expect(bannerBox.Visible == false, "기다리던 것이 없으면 사라진다")
	Guide.step(1)
	expect(bannerBox.Visible == false, "한 번만 떴다(같은 알림을 두 번 넣어도)")
	-- 같은 알림이 다시 오면 글과 시간을 새로 한다 · 캐릭터를 바꾸면(clear) 기다리던 것도 지운다
	Guide.banner("가", "1", 4)
	Guide.banner("나", "2", 4)
	Guide.clear()
	Guide.step(10)
	expect(bannerBox.Visible == false, "지우면 기다리던 알림도 뜨지 않는다")
end
