-- 「달의 계승자」 — 월드맵(M)과 퀘스트 창의 탭(2026-10-11 · 메이플스토리의 월드맵 · 퀘스트 창을 본뜬 것): 화면을 모르는 셈만 본다
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local D = req("ReplicatedStorage/shared/lune/data/worldmap.generated")
local WM = req("ReplicatedStorage/shared/lune/ui/worldmap")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
pixelText.Register("small", KIT.font.small, {})

-- ---- 1) 자료의 꼴 ----
eq(#D.order, 6, "지역 넷과 은달 항구 · 물마루 바다")
eq(table.concat(D.order, " "), "r1 city r2 r3 r4 sea", "탭의 차례: 초승 고개 → 은달 항구 → 수정 숲 → 땅속 화롯골 → 만월성 → 물마루 바다")
for _, rid in D.order do
	local region = D.regions[rid]
	if rid == "city" then
		-- 은달 항구 = 한 장의 큰 맵(2026-10-16 — 사용자 「한 장의 큰 도시」): 마디 하나, 길 없음
		expect(region ~= nil and #region.nodes == 1 and region.nodes[1].id == "ct", "은달 항구는 마디 하나(한 장)")
	else
		expect(region ~= nil and #region.nodes >= 6 and #region.links >= #region.nodes - 1, "지역의 마디와 길 " .. rid)
	end
	local ids = {}
	for _, n in region.nodes do
		expect(ids[n.id] == nil, "마디의 이름표가 겹치지 않는다 " .. n.id)
		ids[n.id] = true
		expect(n.x >= 0 and n.x <= 1 and n.y >= 0 and n.y <= 1, "자리는 0~1 " .. n.id)
		expect(D.kinds[n.kind] ~= nil, "장소의 갈래 " .. n.id)
		expect(#n.scenes >= 1, "마디에 장면이 있다 " .. n.id)
		for _, key in n.scenes do
			expect(SCENES.scenes[key] ~= nil, "게임에 있는 장면 " .. key)
			expect(D.sceneNode[key] ~= nil and D.sceneNode[key].node == n.id and D.sceneNode[key].region == rid, "장면 → 마디 " .. key)
		end
		-- 그림에 적는 짧은 이름이 이름 칸(88점)에 들어간다
		expect(typeof(n.label) == "string" and n.label ~= "" and pixelText.Measure(n.label, "small") <= 88, ("마디의 이름이 칸에 들어간다 %s — %s(%d)"):format(n.id, tostring(n.label), pixelText.Measure(tostring(n.label), "small")))
	end
	for _, link in region.links do
		expect(ids[link[1]] and ids[link[2]] and link[1] ~= link[2], "길은 있는 마디 둘을 잇는다 " .. link[1] .. " - " .. link[2])
	end
	-- 모든 마디가 길로 이어져 있다(첫 마디에서 닿는다)
	local seen, queue, at = { [region.nodes[1].id] = true }, { region.nodes[1].id }, 1
	while queue[at] do
		local id = queue[at]
		at += 1
		for _, link in region.links do
			local other = if link[1] == id then link[2] elseif link[2] == id then link[1] else nil
			if other and not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	for _, n in region.nodes do
		expect(seen[n.id], "길로 이어진 마디 " .. n.id)
	end
end

-- ---- 2) 내가 있는 곳 ----
do
	local r, id = WM.nodeOf("town")
	expect(r == "r1" and id == "town", "마을")
	r, id = WM.nodeOf("in_elder")
	expect(r == "r1" and id == "town", "촌장의 집 안에 있어도 마을의 마디다")
	r, id = WM.nodeOf("in_shrine")
	expect(r == "r1" and id == "town", "사당 안도 마을의 마디다")
	r, id = WM.nodeOf("hunt")
	expect(r == "r1" and id == "r1a2", "달그림자 사냥터(장면 이름표 hunt)")
	for _, key in { "r1c1", "r1c2", "r1c3" } do
		r, id = WM.nodeOf(key)
		expect(r == "r1" and id == "r1c", "망루 1~3층은 한 마디다 " .. key)
	end
	r, id = WM.nodeOf("r2a1")
	expect(r == "r2" and id == "r2a1", "2지역의 첫 사냥터(성문 밖 숲길 — 2026-10-16 밤에 반달 나루를 뺐다)")
	eq(WM.nodeOf("r2t"), nil, "뺀 반달 나루는 월드맵에 없다")
	eq(WM.nodeOf("없는 맵"), nil, "없는 장면")
	eq(WM.nodeOf(nil), nil, "장면이 없다")
	-- 게임의 모든 장면이 문을 따라 어느 마디엔가 닿는다(지역의 맵 · 실내 · 숨은 방 · 도시와 바다는 이어진 지역의 마디로)
	local outside = 0
	for key in SCENES.scenes do
		if WM.nodeOf(key) == nil then
			outside += 1
		end
	end
	eq(outside, 0, "문으로 이어진 장면은 모두 어느 마디엔가 닿는다")
end

-- ---- 3) 맵의 레벨 · 몬스터 · 주민 ----
do
	local n = WM.node("r1", "r1a1")
	local lo, hi = WM.levels(n)
	expect(lo == 1 and hi >= 1 and hi <= 3, "마을 어귀의 레벨")
	expect(string.find(WM.levelText(n), "^Lv%.1") ~= nil, "레벨 글이 Lv.1로 시작한다")
	eq(WM.levelText(WM.node("r1", "town")), "", "마을에는 레벨이 없다")
	expect(#WM.mobNames(n) >= 1 and table.find(WM.mobNames(n), "수습 검병") ~= nil, "마을 어귀의 몬스터에 수습 검병")
	local tower = WM.node("r1", "r1c")
	lo, hi = WM.levels(tower)
	expect(lo >= 20 and hi <= 29 and hi > lo, "망루 세 층을 합친 레벨")
	local people = WM.npcNames("r1", "town")
	for _, name in { "샛별", "보름 영감", "그믐 사제", "초롱", "반달", "무쇠뿔" } do
		expect(table.find(people, name) ~= nil, "마을의 주민(실내의 주민까지) " .. name)
	end
	local head, more = WM.info("r1", "r1a1")
	expect(string.find(head, "마을 어귀", 1, true) ~= nil and string.find(head, "사냥터", 1, true) ~= nil and string.find(head, "Lv.1", 1, true) ~= nil, "고른 맵의 첫 줄 — " .. head)
	expect(string.find(more, "수습 검병", 1, true) ~= nil, "둘째 줄에 몬스터 — " .. more)
	-- 아래의 글이 창의 폭(620)에 들어간다 — 모든 마디
	for _, rid in D.order do
		for _, node in D.regions[rid].nodes do
			local a, b = WM.info(rid, node.id)
			expect(pixelText.Measure(a, "body") <= 620, "첫 줄이 창에 들어간다 " .. node.id)
			expect(pixelText.Measure(b, "small") <= 620, ("둘째 줄이 창에 들어간다 %s(%d)"):format(node.id, pixelText.Measure(b, "small")))
		end
	end
end

-- ---- 4) 내 레벨에 맞는 사냥터 ----
do
	eq(WM.recommend("r1", 1), "r1a1", "Lv.1 = 마을 어귀")
	eq(WM.recommend("r1", 4), "r1a2", "Lv.4 = 달그림자 사냥터")
	local at12 = WM.node("r1", WM.recommend("r1", 12) :: string)
	local lo = WM.levels(at12)
	expect(lo ~= nil and lo <= 12 and lo >= 9, "Lv.12에 맞는 사냥터는 Lv.9~12에서 시작하는 맵 — " .. at12.name)
	eq(WM.recommend("r1", 27), "r1c", "Lv.27 = 옛 망루")
	eq(WM.recommend("r1", 99), "r1c", "레벨이 넘쳐도 그 지역에서 가장 높은 사냥터")
	local first = WM.node("r2", WM.recommend("r2", 5) :: string)
	expect(first ~= nil and WM.levels(first) >= 30, "레벨이 모자라면 그 지역에서 가장 낮은 사냥터")
	eq(WM.recommend("없는 지역", 10), nil, "없는 지역")
	-- 레벨을 올려 가면 추천 사냥터의 레벨이 내려가지 않는다 · 내 레벨을 넘지 않는다
	local was = 0
	for level = 1, 29 do
		local id = WM.recommend("r1", level)
		local low = WM.levels(WM.node("r1", id :: string))
		expect(low >= was and low <= level, ("Lv.%d의 추천 사냥터 %s(Lv.%d~)"):format(level, tostring(id), low))
		was = low
	end
end

-- ---- 5) 퀘스트의 표시 ----
do
	local book = {}
	local marks = WM.marks("r1", book, 1)
	eq(marks.town, "!", "새 캐릭터: 첫 퀘스트를 주는 사제가 있는 마을에 !")
	Quests.accept(book, 1, "r1m1")
	marks = WM.marks("r1", book, 1)
	eq(marks.town, "?", "첫 퀘스트는 받자마자 돌려줄 수 있다 — 사제가 있는 마을에 ?")
	book.r1m1 = { done = true, c = {} }
	marks = WM.marks("r1", book, 3)
	eq(marks.town, "!", "첫 기술을 끝내면 샛별이 있는 마을에 !(줄의 다음 것 — 마을 밖의 그림자)")
	expect(Quests.accept(book, 3, "r1m2"), "마을 밖의 그림자를 받는다")
	marks = WM.marks("r1", book, 3)
	eq(marks.town, nil, "하는 중에는 표시가 없다(한 번에 하나만 받는다)")
	book.r1m2.c[1] = 5
	marks = WM.marks("r1", book, 3)
	eq(marks.town, "?", "다 하면 돌려줄 마을에 ?")
	-- Lv.20: 「옛 망루」는 수비대 야영지의 차돌이 준다
	local b2 = {}
	do -- 줄에서 「옛 망루」 앞의 것을 모두 끝냈다
		local def = Quests.def("r1m6")
		while def.after do
			b2[def.after] = { done = true, c = {} }
			def = Quests.def(def.after)
		end
	end
	marks = WM.marks("r1", b2, 20)
	eq(marks.r1cc, "!", "차돌이 있는 수비대 야영지에 !")
	eq(WM.marks("r2", b2, 20).r2af, nil, "다른 지역에는 아직 표시가 없다(Lv.30부터)")
	expect(WM.marks("city", b2, 30).ct == "!", "Lv.30이면 2지역의 마을(은달 항구 — 성문 앞의 하늬가 2편의 첫 메인을 준다)에 !")
end

-- ---- 6) 퀘스트 창의 세 목록(진행 중 · 시작 가능 · 완료) ----
do
	local book = {}
	eq(Quests.listOpen(book, 1)[1], "r1m1", "새 캐릭터: 시작 가능에 첫 기술")
	Quests.accept(book, 1, "r1m1")
	eq(#Quests.listOpen(book, 1), 0, "받은 뒤에는 받을 것이 없다(첫 기술을 하는 중)")
	eq(#Quests.listDone(book), 0, "끝낸 것도 없다")
	book.r1m1 = { done = true, c = {} }
	local open = Quests.listOpen(book, 3)
	eq(open[1], "r1m2", "시작 가능에는 줄의 다음 것(마을 밖의 그림자)")
	eq(#open, 1, "하나뿐이다(퀘스트는 한 줄이다)")
	eq(Quests.listDone(book)[1], "r1m1", "완료에 첫 기술")
	-- 다음 메인이 레벨 때문에 잠겨 있으면 맨 끝에 뜬다(잠긴 채로)
	open = Quests.listOpen(book, 2)
	eq(open[#open], "r1m2", "레벨이 모자란 줄의 다음 것(마을 밖의 그림자 — Lv.3)이 맨 끝에")
	eq(Quests.state(book, 2, "r1m2"), "locked", "그 줄은 잠겨 있다")
	for _, id in open do
		expect(not Quests.def(id).auto, "저절로 받는 것은 시작 가능에 없다 " .. id)
	end
	-- 받으면 시작 가능에서 빠지고 진행 중에 들어간다
	expect(Quests.accept(book, 3, "r1m2"), "레벨이 되어 받는다")
	expect(table.find(Quests.listOpen(book, 3), "r1m2") == nil and table.find(Quests.active(book), "r1m2") ~= nil, "받은 것은 진행 중으로")
end

-- ---- 7) 전직하면 그 레벨의 무기를 받는다(메이플스토리처럼) ----
do
	local def = Quests.def("job2")
	expect(def.reward.gear ~= false and def.reward.gear.slot == "weapon" and def.reward.gear.stage == 30, "2차 전직의 보상에 Lv.30 무기")
	local h = Hero.new(1, "mooni")
	while h.level < 30 do
		Hero.gainXp(h, N.xpNeed(h.level) - h.xp)
	end
	h.quests.r1m1 = { done = true, c = {} }
	eq(h.quests.job2, nil, "Lv.30이 되어도 전직 퀘스트는 저절로 받지 않는다")
	expect(Quests.accept(h.quests, h.level, "job2"), "사제에게서 받는다")
	Bag.give(h, def.steps[1].item, 10)
	Hero.syncQuests(h)
	-- 가방의 장비 칸이 가득 차 있으면 돌려주지 못한다(전직도 하지 않는다)
	local filler = {}
	for _ = 1, Bag.free(h) do
		local it = Items.make("hat", 1, 3)
		Bag.add(h, it)
		table.insert(filler, it)
	end
	local reward, why = Hero.questDone(h, "job2")
	expect(reward == nil and why == Bag.FULL, "가방이 가득 차면 전직 퀘스트를 돌려주지 못한다")
	eq(h.job, 1, "전직하지 않았다")
	eq(Bag.count(h, def.steps[1].item), 10, "조각도 그대로다")
	Bag.dismantle(h, filler[1].id)
	local gearWas = Bag.used(h, "gear")
	reward = Hero.questDone(h, "job2")
	expect(reward ~= nil, "빈 칸이 있으면 돌려준다")
	eq(h.job, 2, "2차")
	eq(Bag.used(h, "gear"), gearWas + 1, "무기가 가방에 들어온다")
	local found = false
	for i = 1, Bag.size(h) do
		local it = h.gear[i]
		if it and it.slot == "weapon" and it.stage == 30 and it.who == "mooni" and it.q == Items.NORMAL then
			found = true
		end
	end
	expect(found, "Lv.30 내 직업의 무기(보통)")
end

-- ---- 맵에 놓인 것 앞에서 ↑를 누르는 퀘스트(2026-10-11 — 「할아버지의 옛이야기」의 샘 · 「수비대의 깃발」의 상자) ----
do
	local QD = req("ReplicatedStorage/shared/lune/data/quests.generated")
	local uses = {}
	for _, def in QD.list do
		for i, step in def.steps do
			if step.type == "use" then
				table.insert(uses, { def = def, i = i, step = step })
			end
		end
	end
	expect(#uses >= 2, "↑를 누르는 퀘스트가 둘 이상 있다")
	for _, u in uses do
		local def, step = u.def, u.step
		local sc = SCENES.scenes[def.scene]
		expect(sc ~= nil, "자리의 맵이 게임에 있다 " .. def.name)
		expect(typeof(step.x) == "number" and typeof(step.y) == "number" and step.x > 16 and step.x < sc.w * 16 - 16 and step.y > 0 and step.y <= sc.h * 16, "자리가 맵 안이다 " .. def.name)
		expect(typeof(step.place) == "string" and step.place ~= "" and typeof(step.act) == "string" and step.act ~= "", "자리의 이름과 하는 일 " .. def.name)
		expect(typeof(step.up) == "number" and step.up >= 16 and step.up <= 60, "「!」가 떠 있는 높이 " .. def.name)
		-- 가까이 섰을 때 뜨는 글 「↑ 물을 뜬다」가 이름표의 폭(220점)에 들어간다
		expect(pixelText.Measure("↑ " .. step.act, "small") <= 220, "자리의 글이 이름표에 들어간다 " .. def.name)
		-- 문 바로 앞이면 ↑가 문으로 간다 — 자리는 문에서 떨어져 있어야 한다
		for _, p in sc.portals do
			expect(math.abs(p.x - step.x) > 60 or math.abs(p.y - step.y) > 48 or (p.dungeon ~= nil and p.done == def.id), ("자리가 문 「%s」과 겹치지 않는다 %s"):format(p.label, def.name)) -- 던전의 문 앞의 「문에 손 대기」는 그 문이 닫혀 있는 동안의 것(2026-10-21)
		end
		-- 주민 바로 앞이어도 안 된다(↑가 한 가지 일만 하게)
		for _, n in sc.npcs or {} do
			expect(math.abs(n.x - step.x) > 60 or math.abs(n.y - step.y) > 48, ("자리가 주민 %s과 겹치지 않는다 %s"):format(n.name, def.name))
		end
		local book = {}
		do -- (줄에서 그 앞의 것을 모두 끝냈다 — 퀘스트는 한 줄이다)
			local d = def
			while d.after do
				book[d.after] = { done = true, c = {} }
				d = Quests.def(d.after)
			end
		end
		eq(#Quests.spotsIn(book, def.scene), 0, "받기 전에는 자리가 없다 " .. def.name)
		expect(Quests.accept(book, def.lv, def.id) == true, "받는다 " .. def.name)
		local spots = Quests.spotsIn(book, def.scene)
		eq(#spots, 1, "받으면 그 맵에 자리가 하나 " .. def.name)
		expect(spots[1].quest == def.id and spots[1].x == step.x and spots[1].y == step.y and spots[1].up == step.up and spots[1].act == step.act, "자리의 값 " .. def.name)
		eq(#Quests.spotsIn(book, "town"), 0, "다른 맵에는 없다 " .. def.name)
		local ok, why = Quests.use(book, def.id, def.scene, step.x + Quests.USE_REACH.x + 1, step.y)
		expect(ok == nil and why == "그 자리 앞이 아니다", "한 걸음 멀면 못 한다 " .. def.name)
		ok, why = Quests.use(book, def.id, def.scene, step.x, step.y - Quests.USE_REACH.y - 1)
		expect(ok == nil and why == "그 자리 앞이 아니다", "위층에서는 못 한다 " .. def.name)
		ok, why = Quests.use(book, def.id, "town", step.x, step.y)
		expect(ok == nil and why == "여기가 아니다", "다른 맵에서는 못 한다 " .. def.name)
		eq(Quests.state(book, def.lv, def.id), "active", "아직 하는 중 " .. def.name)
		for n = 1, step.n do
			expect(Quests.use(book, def.id, def.scene, step.x - Quests.USE_REACH.x, step.y) == true, ("자리 앞에서 ↑ %d번째 %s"):format(n, def.name))
		end
		eq(book[def.id].c[u.i], step.n, "숫자가 오른다 " .. def.name)
		eq(#Quests.spotsIn(book, def.scene), 0, "다 하면 자리가 사라진다 " .. def.name)
		ok, why = Quests.use(book, def.id, def.scene, step.x, step.y)
		expect(ok == nil and why == "여기서 할 일이 없다" and book[def.id].c[u.i] == step.n, "다 한 일은 더 오르지 않는다 " .. def.name)
		if #def.steps == 1 then
			eq(Quests.state(book, def.lv, def.id), "ready", "돌려주러 간다 " .. def.name)
		end
		-- 길잡이의 글에 자리의 이름이 있다
		expect(Quests.stepHint(def, step):find(step.place, 1, true) ~= nil and Quests.stepHint(def, step):find(sc.name, 1, true) ~= nil, "길잡이에 맵과 자리의 이름 " .. def.name)
	end
	local ok, why = Quests.use({}, "r1m1", "town", 0, 0)
	expect(ok == nil and why == "하는 중인 퀘스트가 아니다", "받지 않은 퀘스트")
end

-- ---- 은달 항구 · 물마루 바다의 탭, 다른 지역으로 이어지는 곳, 가는 길(2026-10-11) ----
do
	local W, LABEL_W, TAB_GAP = 620, 88, 14 -- client/lune/ui/mapWindow.luau의 값
	pixelText.Register("body", KIT.font.body, {})
	-- 탭 여섯이 창의 폭에 들어간다
	local tabs = 0
	for _, rid in D.order do
		tabs += pixelText.Measure(D.regions[rid].name, "small") + TAB_GAP
	end
	expect(tabs - TAB_GAP <= W, ("탭 여섯이 창에 들어간다(%d)"):format(tabs - TAB_GAP))
	-- 도시 한 장과 그 건물 · 바다의 열 장이 제 지역의 마디다(전에는 가장 가까운 지역의 마디로 쳤다)
	for _, key in { "ct", "ct_store", "ct_smith", "ct_storage", "ct_auction", "ct_office", "ship_out" } do
		local r, n = WM.nodeOf(key)
		expect(r == "city" and n == "ct", "은달 항구의 마디 " .. key)
	end
	local rh, nh = WM.nodeOf("ship_home")
	expect(rh == "r1" and nh == "town", "돌아오는 배의 갑판은 초승달 마을 쪽")
	for _, key in { "seat", "sea1", "sea2", "sea3", "seaf", "sea4", "sea5", "sea6", "sea7", "sea8" } do
		local r, n = WM.nodeOf(key)
		expect(r == "sea" and n == key, "바다의 맵 " .. key)
	end
	-- 길(그림의 선)은 게임의 문과 같다: 도시 · 바다의 길마다 두 맵 사이에 문이 있다
	for _, rid in { "city", "sea" } do
		for _, link in D.regions[rid].links do
			local found = false
			for _, p in SCENES.scenes[link[1]].portals do
				found = found or p.to == link[2]
			end
			expect(found, ("그림의 길에 문이 있다 %s - %s"):format(link[1], link[2]))
		end
	end
	-- 다른 지역으로 이어지는 곳
	local function has(rid, node, to, toNode)
		for _, ex in WM.exits(rid) do
			if ex.node == node and ex.to == to and (toNode == nil or ex.toNode == toNode) then
				return true
			end
		end
		return false
	end
	-- 2026-10-13(사용자: "은달항구는  초승달 마을에서 갈수있게합니다") · 2026-10-16(「배 위에서 시간을 보낸다」): 초승달 마을의 포구 ↔ 은달 항구의 부두 = 배
	expect(has("r1", "town", "city", "ct"), "초승 고개: 초승달 마을(포구의 배) → 은달 항구")
	expect(has("city", "ct", "r1", "town"), "은달 항구: 부두의 배 → 초승 고개(초승달 마을)")
	expect(not has("r1", "r1cc", "city"), "수비대 야영지 → 도시의 길은 없다(「불타는 마을」을 건너뛸 수 없게)")
	expect(has("city", "ct", "r2", "r2a1") and has("city", "ct", "sea", "seat"), "은달 항구 → 수정 숲(큰 성문 → 성문 밖 숲길) · 물마루 바다")
	expect(has("city", "ct", "r3", "port"), "은달 항구: 비행선 → 등불 포구")
	expect(has("sea", "seat", "city", "ct"), "물마루 바다: 물마루 마을 → 은달 항구")
	local exits = 0
	for _, rid in D.order do
		for _, ex in WM.exits(rid) do
			exits += 1
			expect(WM.node(rid, ex.node) ~= nil and D.regions[ex.to] ~= nil and WM.node(ex.to, ex.toNode) ~= nil and ex.to ~= rid, "이어지는 곳의 값 " .. rid .. " " .. ex.node)
			expect(has(ex.to, ex.toNode, rid), ("돌아오는 길도 있다 %s %s → %s"):format(rid, ex.node, ex.to))
		end
		-- 마디 아래의 줄들: 세 줄까지 · 줄마다 이름 칸(88점)에 들어간다
		for _, n in D.regions[rid].nodes do
			local rows = WM.rows(rid, n)
			expect(#rows >= 1 and #rows <= WM.ROWS_MAX and rows[1].text == n.label, ("마디 아래의 줄 수 %s(%d)"):format(n.id, #rows))
			for _, row in rows do
				expect(pixelText.Measure(row.text, "small") <= LABEL_W, ("마디 아래의 줄이 칸에 들어간다 %s — %s(%d)"):format(n.id, row.text, pixelText.Measure(row.text, "small")))
				expect(row.kind ~= "exit" or (row.exit ~= nil and row.text:find(D.regions[row.exit.to].name, 1, true) ~= nil), "이어지는 줄에 지역의 이름 " .. n.id)
			end
		end
	end
	expect(exits >= 8, "이어지는 곳을 모두 봤다")

	-- 가는 길: 문을 가장 적게 지나는 길
	local path = WM.path("town", "r2a1")
	expect(path ~= nil and path[1] == "town" and path[#path] == "r2a1", "초승달 마을에서 성문 밖 숲길까지 길이 있다")
	local Voyage = req("ReplicatedStorage/shared/lune/sim/voyage")
	for i = 2, #path do
		local found = false
		for _, p in SCENES.scenes[path[i - 1]].portals do
			found = found or p.to == path[i]
		end
		for _, r in Voyage.routesFrom(path[i - 1]) do
			found = found or r.to == path[i]
		end
		expect(found, ("길의 걸음마다 문 · 배가 있다 %s → %s"):format(path[i - 1], path[i]))
	end
	local joined = table.concat(path, " ")
	eq(joined, "town ct r2a1", "초승달 마을(포구의 배) → 은달 항구 → 성문 밖 숲길(큰 성문)")
	eq(#WM.path("town", "town"), 1, "제자리의 길은 한 장")
	eq(WM.path("town", "없는맵"), nil, "없는 맵으로 가는 길은 없다")
	local route = WM.route("in_shrine", "r2a1")
	expect(route ~= nil and route[1].region == "r1" and route[1].node == "town" and route[#route].region == "r2" and route[#route].node == "r2a1", "사당 안에서 떠나면 길은 초승달 마을부터")
	for i = 2, #route do
		expect(route[i].region ~= route[i - 1].region or route[i].node ~= route[i - 1].node, "이어서 같은 마디는 한 번만")
	end
	local text = WM.routeText(WM.route("r1c3", "r2a2")) -- 긴 길: 옛 망루 3층에서 수정 오솔길까지
	expect(text:find("…", 1, true) ~= nil and text:sub(-#"수정 오솔길") == "수정 오솔길", "긴 길은 가운데를 줄인다: " .. text)
	expect(pixelText.Measure("…", "small") > 0, "줄임표가 글꼴에 있다")
	eq(WM.routeText(WM.route("town", "town")), "", "제자리면 빈 글")
	eq(WM.routeText(WM.route("town", "hunt")), "마을 어귀 → 세 갈래 길 → 달그림자 사냥터", "짧은 길은 그대로") -- 2026-10-13: 달그림자 사냥터는 세 갈래 길의 가지가 됐다
	eq(WM.routeText(nil), "", "길이 없으면 빈 글")

	-- 지금 가야 할 곳
	local book = {}
	local goal = Quests.goal(book, 1)
	expect(goal ~= nil and goal.def.id == "r1m1" and goal.kind == "take" and goal.scene == "in_shrine", "새 캐릭터: 「첫 기술」을 받으러 사당 안의 사제에게")
	eq((WM.goalLine(book, 1, "in_shrine")), "「첫 기술」 — 지금 있는 맵에서 받는다", "사당 안이면 「지금 있는 맵에서 받는다」")
	Quests.accept(book, 1, "r1m1")
	goal = Quests.goal(book, 1)
	expect(goal ~= nil and goal.def.id == "r1m1" and goal.kind == "back" and goal.scene == "in_shrine", "받은 뒤: 「첫 기술」을 돌려주러 사당 안의 사제에게")
	local line, r1, g1 = WM.goalLine(book, 1, "in_shrine")
	expect(line == "「첫 기술」 — 지금 있는 맵에서 돌려준다" and #r1 == 1 and g1.def.id == "r1m1", "사당 안이면 「지금 있는 맵에서 돌려준다」: " .. line)
	-- 내 레벨에 맞는 사냥터의 줄: 맞는 것이 있으면 권하고, 모두 높으면 어디부터인지만 적는다
	local recText, recNode = WM.recommendLine("r1", 12)
	expect(recNode == WM.recommend("r1", 12) and recText:find("Lv.12에 맞는 사냥터: ", 1, true) == 1, "1지역 Lv.12: " .. recText)
	recText, recNode = WM.recommendLine("sea", 30)
	expect(recNode == nil and recText:find("이 지역의 사냥터는 Lv.", 1, true) == 1 and recText:find("부터", 1, true) ~= nil, "바다 Lv.30: 권하지 않는다 — " .. recText)
	recText, recNode = WM.recommendLine("city", 30)
	expect(recText == "" and recNode == nil, "은달 항구에는 사냥터가 없다")
	for _, rid in D.order do
		for _, lv in { 1, 30, 60, 120 } do
			expect(pixelText.Measure((WM.recommendLine(rid, lv)), "small") <= W, "사냥터의 줄이 창에 들어간다 " .. rid)
		end
	end
	book.r1m1.done = true
	goal = Quests.goal(book, 3)
	local m2 = Quests.def("r1m2")
	expect(goal ~= nil and goal.def.id == "r1m2" and goal.kind == "take" and goal.scene == Quests.giverScene(m2), "첫 퀘스트를 끝내면: 줄의 다음 것(마을 밖의 그림자)을 받으러")
	expect(Quests.accept(book, 3, "r1m2") == true, "줄의 다음 것을 받는다")
	goal = Quests.goal(book, 3)
	expect(goal.def.id == "r1m2" and goal.kind == "do" and goal.scene == m2.scene, "받으면: 그 퀘스트의 맵으로 하러")
	line = WM.goalLine(book, 3, "town")
	expect(line:find("「" .. m2.name .. "」 하러 가는 길: ", 1, true) == 1 and line:find(SCENES.scenes[m2.scene].name, 1, true) ~= nil, "마을에서: " .. line)
	for i, step in m2.steps do
		book.r1m2.c[i] = step.n
	end
	goal = Quests.goal(book, 3)
	expect(goal.def.id == "r1m2" and goal.kind == "back" and goal.scene == Quests.endScene(m2), "다 하면: 돌려주러")
	-- 다음 메인은 레벨이 모자라면 갈 곳이 없다
	book.r1m2.done = true
	local next, why = Quests.nextMain(book, 3)
	if next and why == "level" then
		eq(Quests.goal(book, 3), nil, "레벨이 모자라 다음 메인을 못 받으면 갈 곳이 없다")
		eq((WM.goalLine(book, 3, "town")), "", "그때는 빈 글")
	end
	-- 2차 전직 뒤(Lv.30 · 1지역의 메인을 다 끝냄): 2지역의 첫 메인을 받으러 — 길이 도시를 지난다
	local done = {}
	for _, def in Quests.list do
		if (def.region == "r1" and not def.city) or def.kind == "job" then
			done[def.id] = { done = true, c = {} }
		end
	end
	goal = Quests.goal(done, 30)
	expect(goal ~= nil and goal.def.id == "cq01" and goal.kind == "take", "1지역을 끝낸 Lv.30: 촌장에게 「큰 항구로」를 받으러(2026-10-16 — 2편의 도착)")
	for _, id in { "cq01", "cq02" } do -- 도착 · 도시 둘러보기를 끝냈다
		done[id] = { done = true, c = {} }
	end
	goal = Quests.goal(done, 30)
	expect(goal ~= nil and goal.def.id == "r2m1" and goal.kind == "take", "도시를 둘러본 뒤: 2지역의 첫 메인을 받으러")
	local line2, route2 = WM.goalLine(done, 30, "in_shrine")
	local cityOn = false
	for _, at in route2 do
		cityOn = cityOn or at.region == "city"
	end
	expect(cityOn and route2[#route2].region == "city" and route2[#route2].node == "ct", "그 길은 은달 항구(큰 성문 앞의 하늬)에 닿는다 — 2026-10-16 밤에 반달 나루를 뺐다: " .. line2)

	-- 가는 길의 글이 창의 폭에 들어간다: 메인 · 전직 퀘스트마다, 받으러 · 하러 · 돌려주러, 지도의 모든 맵에서
	local longest, seen = 0, 0
	for _, def in Quests.list do
		if def.playable and (def.kind == "main" or def.kind == "job") then
			for kind, scene in { take = Quests.giverScene(def), ["do"] = def.scene, back = Quests.endScene(def) } do
				if scene then
					for from in D.sceneNode do
						local t = WM.goalText({ def = def, scene = scene, kind = kind }, from)
						local tw = pixelText.Measure(t, "small")
						seen += 1
						if tw > longest then
							longest = tw
						end
						if tw > W then
							expect(false, ("가는 길의 글이 창에 들어간다(%d) %s에서 — %s"):format(tw, from, t))
						end
					end
				end
			end
		end
	end
	expect(seen > 5000 and longest > 0 and longest <= W, ("가는 길의 글을 모두 쟀다(%d개 · 가장 긴 것 %d)"):format(seen, longest))
end

-- ---- 그림으로 된 지도(2026-10-11 — 사용자: "월드맵 똑바로 그리세요 … 없는게 나은수준인데"): 그림 · 자리 · 오른쪽 글 칸 ----
do
	local ASSETS = req("ReplicatedStorage/shared/lune/data/assets.generated")
	local SIDE_W = WM.SIDE_W
	eq(WM.ART_W, 384, "그림의 폭")
	eq(WM.ART_H, 256, "그림의 높이")
	local arted = WM.arted()
	expect(#arted >= 1 and arted[1] == "r1", "그림이 있는 지역: 초승 고개부터")
	for _, rid in D.order do
		local region = D.regions[rid]
		if region.art then
			expect(ASSETS[region.art.img] ~= nil, "그림이 올릴 그림 목록에 있다 " .. rid)
			local seen = {}
			for _, n in region.nodes do
				local at = region.art.at[n.id]
				expect(at ~= nil, ("장소마다 그림 위의 자리가 있다 %s"):format(n.id))
				if at then
					expect(at[1] >= 6 and at[1] <= WM.ART_W - 6 and at[2] >= 6 and at[2] <= WM.ART_H - 6, "자리가 그림 안이다 " .. n.id)
					for other, b in seen do
						local d = math.sqrt((at[1] - b[1]) ^ 2 + (at[2] - b[2]) ^ 2)
						expect(d >= 12, ("표시가 겹치지 않는다 %s · %s(%d점)"):format(n.id, other, d))
					end
					seen[n.id] = at
				end
				-- 이름표(그림 위)와 오른쪽 글 칸: 이름 · 갈래와 레벨은 한 줄, 몬스터 · 주민은 정해진 줄 수 안
				expect(pixelText.Measure(n.label, "small") + 8 <= 120, "이름표가 길지 않다 " .. n.label)
				local card = WM.card(rid, n.id)
				expect(card.name == n.name and pixelText.Measure(card.name, "body") <= SIDE_W, ("이름이 글 칸에 들어간다 %s(%d)"):format(card.name, pixelText.Measure(card.name, "body")))
				expect(pixelText.Measure(card.sub, "small") <= SIDE_W, "갈래와 레벨이 한 줄 " .. card.sub)
				local function lines(text: string): number
					return if text == "" then 0 else #string.split(pixelText.Wrap(text, SIDE_W, "small"), "\n")
				end
				expect(lines(card.mobs) <= WM.SIDE.mobLines, ("몬스터의 이름이 %d줄 안 — %s"):format(WM.SIDE.mobLines, card.mobs))
				expect(lines(card.npcs) <= WM.SIDE.npcLines, ("주민의 이름이 %d줄 안 — %s"):format(WM.SIDE.npcLines, card.npcs))
			end
			for to, at in region.art.out do
				expect(D.regions[to] ~= nil and at[1] > 0 and at[1] < WM.ART_W and at[2] > 0 and at[2] < WM.ART_H, "나가는 곳의 이름표 " .. to)
			end
			expect(pixelText.Measure(region.name, "body") + pixelText.Measure(WM.regionLevels(rid), "small") + 8 <= SIDE_W, "머리줄(지역 이름 · 레벨)이 글 칸에 들어간다 " .. rid)
			for _, lv in { 1, 12, 30, 60 } do
				expect(pixelText.Measure((WM.recommendShort(rid, lv)), "small") <= SIDE_W, "내 레벨의 사냥터가 한 줄 " .. rid)
			end
		end
	end
	eq(WM.regionLevels("city"), "", "몬스터가 없는 지역의 레벨은 빈 글")
	local t1, n1 = WM.recommendShort("r1", 12)
	expect(n1 == WM.recommend("r1", 12) and t1:find("Lv.", 1, true) ~= nil, "내 레벨의 사냥터(짧게): " .. t1)
	local t2, n2 = WM.recommendShort("sea", 30)
	expect(n2 == nil and t2:find("부터", 1, true) ~= nil, "높은 지역은 권하지 않는다: " .. t2)
	-- 가는 길의 두 토막: 제목은 한 줄, 길은 두 줄 안 — 메인 · 전직 퀘스트마다, 받으러 · 하러 · 돌려주러, 지도의 모든 맵에서
	local seen, worst = 0, 0
	for _, def in Quests.list do
		if def.playable and (def.kind == "main" or def.kind == "job") then
			for kind, scene in { take = Quests.giverScene(def), ["do"] = def.scene, back = Quests.endScene(def) } do
				if scene then
					for from in D.sceneNode do
						local card = WM.goalCardOf({ def = def, scene = scene, kind = kind }, from)
						if card then
							seen += 1
							local tw = pixelText.Measure(card.title, "small")
							local n = #string.split(pixelText.Wrap(card.text, SIDE_W, "small"), "\n")
							worst = math.max(worst, n)
							if tw > SIDE_W or n > WM.SIDE.routeLines then
								expect(false, ("가는 길이 글 칸에 들어간다(제목 %d점 · %d줄) %s에서 — %s / %s"):format(tw, n, from, card.title, card.text))
							end
						end
					end
				end
			end
		end
	end
	expect(seen > 5000 and worst >= 1 and worst <= WM.SIDE.routeLines, ("가는 길을 모두 쟀다(%d개 · 가장 긴 것 %d줄)"):format(seen, worst))
	local book = {}
	Quests.accept(book, 1, "r1m1")
	local card = WM.goalCard(book, 1, "in_shrine")
	expect(card ~= nil and card.title == "「첫 기술」 돌려주러" and card.text == "지금 있는 맵에서 돌려준다", "새 캐릭터의 가는 길")
	eq(WM.goalCard({ r1m1 = { done = true, c = {} }, r1m2 = { done = true, c = {} } }, 1, "town"), nil, "갈 곳이 없으면 nil")
end

-- ---- 곁맵 · 다른 지역의 표시 · 모든 장소의 이름표(2026-10-11 — 사용자: "바위틈 같은 사냥터 표시안되고, 은달항구의 경우 지금 수비대 야영지에서 포탈로 갈수있는데 맵에서는 그냥 좌측 은달항구라고 나와버리면 어떻게 하라는건지?") ----
do
	local art = D.regions.r1.art
	-- 굽잇길의 문 「바위 틈으로」로 들어가는 옛 은신처와 멧돼지 굴도 지도에 있다(그 안에 있으면 내가 있는 곳이 그 표시다)
	for _, key in { "r1bh", "r1bl" } do
		local r, n = WM.nodeOf(key)
		expect(r == "r1" and n == key and art.at[key] ~= nil, "곁맵이 지도에 있다 " .. key)
	end
	local door = false
	for _, p in SCENES.scenes.r1b2.portals do
		door = door or (p.to == "r1bh" and p.label == "바위 틈으로")
	end
	expect(door, "굽잇길의 문 「바위 틈으로」는 옛 은신처로 간다")
	eq(WM.card("r1", "r1bh").name, "옛 은신처", "옛 은신처의 글")
	-- 은달 항구: 그림 위에 표시가 있고, 수비대 야영지에서 이어진다
	expect(art.out.city ~= nil and #art.out.city >= 2, "은달 항구의 표시의 자리")
	local out = WM.outCard("r1", "city")
	expect(out.name == "은달 항구" and out.link == "초승달 마을의 포탈로 간다", "은달 항구를 고르면: " .. out.link)
	eq(WM.linkText("r1", "town"), "은달 항구로 가는 포탈이 있다", "초승달 마을을 고르면")
	eq(WM.linkText("r1", "r1cc"), "", "다른 지역으로 가는 문이 없는 곳은 빈 글")
	expect(pixelText.Measure(out.link, "small") <= WM.SIDE_W and pixelText.Measure(WM.linkText("r1", "town"), "small") <= WM.SIDE_W, "그 글이 글 칸에 들어간다")
	for _, ex in WM.exits("r1") do
		expect(art.out[ex.to] ~= nil, "나가는 곳마다 그림 위에 표시가 있다 " .. ex.to)
	end
	-- 이름표: 모든 장소와 은달 항구의 이름이 그림 안에, 서로도 표시와도 겹치지 않게 놓인다(어느 장소에 있든)
	local function items(first: string?)
		local list = {}
		for _, n in D.regions.r1.nodes do
			local at = art.at[n.id]
			local it = { id = n.id, x = at[1], y = at[2], r = WM.PIN[n.kind] or 4, w = pixelText.Measure(n.label, "small") }
			-- 게임의 차례(mapWindow의 rank): 내가 있는 곳 → 마을 · 쉼터 → 나머지
			it.rank = if n.id == first then 1 elseif n.kind == "town" or n.kind == "village" or n.kind == "rest" then 5 else 6
			it.at = #list
			table.insert(list, it)
		end
		for to, at in art.out do
			table.insert(list, { id = "out:" .. to, x = at[1], y = at[2], r = WM.PIN.out, w = pixelText.Measure(D.regions[to].name, "small"), rank = 5, at = #list })
		end
		table.sort(list, function(a, b)
			if a.rank ~= b.rank then
				return a.rank < b.rank
			end
			return a.at < b.at
		end)
		return list
	end
	local firsts = { false }
	for _, n in D.regions.r1.nodes do
		table.insert(firsts, n.id)
	end
	for _, first in firsts do
		local list = items(if first then first else nil)
		local lines = WM.lines("r1")
		local placed = WM.placeLabels(list, lines)
		if first == "r1cc" then
			for _, l in lines do
				print(("[LINE] %d %d %d %d"):format(l[1], l[2], l[3], l[4]))
			end
		end
		local rects = {}
		if first == "r1cc" then
			-- 눈으로 볼 때 쓰는 자리(수비대 야영지에 있을 때): 공방의 그림 위에 이 네모들을 얹어 미리 본다
			for _, it in list do
				local r = placed[it.id]
				if r then
					print(("[MAP] %s %d %d %d %d %d %d %d"):format(it.id, it.x, it.y, it.r, r.x, r.y, r.w, r.h))
				end
			end
		end
		for _, it in list do
			local r = placed[it.id]
			expect(r ~= nil, ("이름표가 놓인다 %s(먼저 놓은 것 %s)"):format(it.id, tostring(first)))
			if r then
				expect(r.x >= 1 and r.y >= 1 and r.x + r.w <= WM.ART_W - 1 and r.y + r.h <= WM.ART_H - 1, "이름표가 그림 안이다 " .. it.id)
				for other, b in rects do
					expect(not (r.x < b.x + b.w and r.x + r.w > b.x and r.y < b.y + b.h and r.y + r.h > b.y), ("이름표끼리 겹치지 않는다 %s · %s"):format(it.id, other))
				end
				for _, pin in list do
					expect(not (r.x < pin.x + pin.r + 1 and r.x + r.w > pin.x - pin.r - 1 and r.y < pin.y + pin.r + 1 and r.y + r.h > pin.y - pin.r - 1), ("이름표가 표시를 가리지 않는다 %s · %s"):format(it.id, pin.id))
				end
				rects[it.id] = r
			end
		end
		-- 이름표는 제 표시에 가장 가깝다(다른 곳의 표시 곁에 놓이면 그곳의 이름으로 읽힌다)
		local function gap(r, pin): number
			local dx = math.max(r.x - pin.x, 0, pin.x - (r.x + r.w))
			local dy = math.max(r.y - pin.y, 0, pin.y - (r.y + r.h))
			return math.sqrt(dx * dx + dy * dy) - pin.r
		end
		for _, it in list do
			local r = rects[it.id]
			if r then
				local own = gap(r, it)
				for _, pin in list do
					if pin.id ~= it.id then
						expect(gap(r, pin) > own, ("이름표가 제 표시에 가장 가깝다 %s(%.1f) · %s(%.1f) · 먼저 놓은 것 %s"):format(it.id, own, pin.id, gap(r, pin), tostring(first)))
					end
				end
			end
		end
		-- 이어진 줄이 보인다(사용자 2026-10-13: "월드맵이랑 실제 포탈이랑 안맞잖아요"): 줄마다 점의 절반 넘게, 적어도 둘은 이름표에 가리지 않는다
		for _, l in lines do
			local all, seen = WM.linkDots(l[1], l[2], l[3], l[4]), 0
			for _, d in all do
				local hid = false
				for _, r in rects do
					if d[1] + 2 > r.x and d[1] < r.x + r.w and d[2] + 2 > r.y and d[2] < r.y + r.h then
						hid = true
						break
					end
				end
				if not hid then
					seen += 1
				end
			end
			expect(seen >= 2 and seen * 2 > #all, ("이어진 줄이 이름표에 가리지 않는다 %s – %s(보이는 점 %d / %d · 먼저 놓은 것 %s)"):format(l[5], l[6], seen, #all, tostring(first)))
		end
	end
end

-- ---- 지도 창을 화면 없이 돌려 본다(client/lune/ui/mapWindow.luau — 가짜 UI 부품을 끼워: 어느 맵에 있든 · 어느 표시를 누르든 오류 없이 그려지는가) ----
do
	local texts = {} -- 만들어진 글들(이름 → 값)
	local hits = {} -- 누를 수 있는 것들: [틀의 이름] = 눌렀을 때 부르는 것
	local made = 0
	local partyDots = 0 -- 파티원의 금빛 점(2026-10-18)
	local function frame(name: string?, parent)
		made += 1
		if name == "Party" then
			partyDots += 1
		end
		local f = { Name = name or "Frame", ZIndex = 1, parent = parent, Size = { X = { Offset = 7 }, Y = { Offset = 9 } } }
		function f:Destroy()
			self.destroyed = true
		end
		return f
	end
	local any = setmetatable({}, { __index = function() return "c" end })
	MOCK("Client/lune/ui/ui", {
		COLOR = any,
		M = { small = 10, body = 12 },
		measure = function(text: string, font: string?) return (pixelText.Measure(text, font or "small")) end,
		box = function(parent, x, y, w, h) expect(w > 0 and h > 0, "네모의 크기가 0보다 크다") return frame("Box", parent) end,
		group = function(parent, x, y, w, h, name) return frame(name, parent) end,
		text = function(parent, text, x, y, width, opts)
			local item = { value = text, shown = true }
			function item.set(_, v) item.value = v end
			function item.color() end
			function item.show(_, on) item.shown = on end
			table.insert(texts, item)
			return item
		end,
		tab = function() local t = { width = 40 } function t.setOn() end return t end,
		hit = function(parent)
			return { Activated = { Connect = function(_, fn) hits[parent.Name] = fn end } }
		end,
	})
	MOCK("Client/lune/ui/kit", { part = function(parent, name) expect(typeof(name) == "string" and name ~= "", "퀘스트 표시의 부품 이름") return frame("Part", parent) end })
	local MapWindow = req("Client/lune/ui/mapWindow")
	local w, h = MapWindow.size()
	expect(w == WM.ART_W + 12 + WM.SIDE_W and h == WM.ART_H + (if #WM.arted() > 1 then MapWindow.TAB_H else 0), ("창의 속 크기(%d x %d — 그림이 있는 지역이 둘 넘으면 위에 탭 줄)"):format(w, h))
	expect(w + 36 <= 768 and h + 44 + 20 <= 432, "스마트폰의 화면 틀(768x432)에 들어간다")
	local state = { scene = "town", level = 1, quests = {} }
	local ctx = { scene = function() return state.scene end, me = function() return { level = state.level } end, quests = function() return state.quests end }
	local view = MapWindow.build(frame("Body"), ctx, w, h)
	-- 오른쪽 글 칸의 글들: 만든 차례(지역 이름 · 레벨 · 장소 이름 · 갈래 · 포탈 · 몬스터 머리 · 몬스터 · 주민 머리 · 주민 · … · 가는 길의 제목 · 길)
	local function sideName(): string
		return texts[3].value
	end
	local function sideLink(): string
		return texts[5].value
	end
	-- 어느 맵에 있든(실내 · 곁맵 · 다른 지역까지) · 레벨이 달라도 · 퀘스트가 달라도
	local books = { {}, {}, {} }
	Quests.accept(books[1], 1, "r1m1")
	books[2] = { r1m1 = { done = true, c = {} }, r1m2 = { done = false, c = { 2 } } }
	for _, def in Quests.list do
		if def.region == "r1" or def.kind == "job" then
			books[3][def.id] = { done = true, c = {} }
		end
	end
	local drawn = 0
	for key in SCENES.scenes do
		for i, book in books do
			state.scene, state.level, state.quests = key, ({ 1, 4, 30 })[i], book
			view.refresh()
			drawn += 1
		end
	end
	expect(drawn > 200 and made > 1000, ("모든 맵에서 그려 봤다(%d번 · 만든 틀 %d개)"):format(drawn, made))
	-- 굽잇길의 문 「바위 틈으로」 안(옛 은신처)에 있으면 오른쪽 글이 그 맵이다
	state.scene, state.level, state.quests = "r1bh", 14, books[2]
	view.refresh()
	eq(sideName(), "옛 은신처", "옛 은신처 안에서 연 지도")
	-- 표시를 누르면 그 장소의 글로 바뀐다 — 모든 장소와 은달 항구
	state.scene = "r1cc"
	view.refresh()
	eq(sideName(), "수비대 야영지", "수비대 야영지에서 연 지도")
	eq(sideLink(), "", "수비대 야영지에는 다른 지역으로 가는 문이 없다")
	hits["Hit_town"]()
	eq(sideLink(), "은달 항구로 가는 포탈이 있다", "초승달 마을의 글에 포탈이 적힌다")
	for _, n in D.regions.r1.nodes do
		expect(hits["Hit_" .. n.id] ~= nil, "누를 수 있는 표시 " .. n.id)
		hits["Hit_" .. n.id]()
		eq(sideName(), n.name, "표시를 누르면 그 장소의 이름 " .. n.id)
	end
	expect(hits["Hit_out:city"] ~= nil and hits["HitName_out:city"] ~= nil, "은달 항구의 표시와 이름표를 누를 수 있다")
	hits["Hit_out:city"]()
	eq(sideName(), "은달 항구", "은달 항구를 누르면")
	eq(sideLink(), "초승달 마을의 포탈로 간다", "어떻게 가는지 적힌다")
	hits["HitName_r1bh"]()
	eq(sideName(), "옛 은신처", "이름표를 눌러도 고른다")
	view.destroy()
	-- 파티원(2026-10-18): 이 지역에 있는 파티원마다 그 장소 곁에 금빛 점 — 다른 지역 · 장소가 없는 맵의 사람은 그리지 않는다
	local party = { { id = 1, name = "나", scene = "town" }, { id = 2, name = "둘", scene = "town" }, { id = 3, name = "셋", scene = "town" }, { id = 4, name = "넷", scene = "ct" } }
	ctx.party = function() return { members = party } end -- 서버의 PartyInfo 꼴(나도 들어 있다)
	ctx.myId = function() return 1 end
	state.scene, state.level, state.quests = "town", 10, {}
	local view2 = MapWindow.build(frame("Body"), ctx, w, h)
	partyDots = 0
	view2.draw()
	eq(partyDots, 2, "1지역을 보는 동안: 초승달 마을의 파티원 둘만(은달 항구의 사람은 그 지역에서)")
	party[2].scene = "hunt"
	partyDots = 0
	view2.refresh()
	eq(partyDots, 2, "파티원이 맵을 옮기면 다시 그린다")
	view2.destroy()
end
