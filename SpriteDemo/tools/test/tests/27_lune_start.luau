-- 「달의 계승자」 — 시작과 길잡이(2026-10-10 · 공방 js/lune/design/startplan.js의 차례 ② ③ ⑥):
--  알리미의 길잡이(다음 메인 · 받을 수 있는 부탁 · 주는 주민이 선 곳) · 조작 안내의 글(칸에 들어가는가 · 때에 맞게 뜨는가) · 1지역의 퀘스트가 Lv.30 전직까지 끊기지 않는가
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local QD = req("ReplicatedStorage/shared/lune/data/quests.generated")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Guide = req("ReplicatedStorage/shared/lune/ui/guideText")
local F = req("ReplicatedStorage/shared/lune/ui/format")
pixelText.Register("small", KIT.font.small, {})

local NAMES = {}
for _, sc in SCENES.scenes do
	for _, n in sc.npcs or {} do
		NAMES[n.id] = n.name
	end
end
local function done(book, id)
	book[id] = { done = true, c = {} }
end

-- ---- 1) 시작하는 곳 ----
eq(QD.first.quest, "r1m1", "첫 퀘스트")
expect(SCENES.scenes[QD.first.scene] ~= nil, "시작하는 방이 있다")
do
	local def = Quests.def(QD.first.quest)
	local has = false
	for _, n in SCENES.scenes[QD.first.scene].npcs or {} do
		has = has or n.id == def.endNpc
	end
	expect(has, "시작하는 방에 첫 퀘스트를 돌려받는 주민이 있다")
	local book = {}
	eq(Quests.firstScene(book, 1), QD.first.scene, "첫 퀘스트를 받기 전에도 그 방에서 시작한다")
	expect(Quests.isNew(book, 1), "받기 전에도 새 캐릭터다(스킬 칸이 아직 없다)")
	expect(not def.auto and def.giver == def.endNpc and #def.offer >= 1, "첫 퀘스트는 그 방의 사제에게 말을 걸어 받고 그대로 돌려준다")
	expect(Quests.accept(book, 1, QD.first.quest), "받는다")
	eq(Quests.firstScene(book, 1), QD.first.scene, "첫 퀘스트를 끝내기 전에는 그 방에서 시작한다")
	expect(Quests.isNew(book, 1), "새 캐릭터다(스킬 칸이 아직 없다)")
	eq(Quests.firstScene(book, 15), nil, "첫 퀘스트를 건너뛰고 자란 예전 캐릭터는 마을에서 시작한다")
	eq(Quests.isNew(book, 15), false, "그런 캐릭터의 기술은 잠기지 않는다")
	done(book, QD.first.quest)
	eq(Quests.firstScene(book, 1), nil, "끝낸 뒤에는 마을의 시작 자리")
end

-- ---- 2) 알리미의 길잡이 ----
do
	local book = {}
	local g0 = Quests.guide(book, 1, NAMES)
	expect(#g0 == 1 and g0[1].kind == "open" and g0[1].title == "! 첫 기술" and g0[1].line == "그믐 사제에게 받는다 · 달의 사당", "새 캐릭터: 길잡이가 첫 퀘스트를 받을 곳을 적는다 — " .. tostring(g0[1] and g0[1].line))
	Quests.accept(book, 1, "r1m1")
	eq(#Quests.guide(book, 1, NAMES), 0, "첫 퀘스트를 하는 중에는 길잡이가 없다(하는 일이 알리미에 있다)")
	done(book, "r1m1")
	-- (2026-10-13: 퀘스트는 한 줄이다 — 첫 기술 → 마을 밖의 그림자 → 빈 갑옷 …(2026-10-15 간소화로 「등불 심지」를 뺐다). 길잡이는 줄의 다음 것 하나만 적는다)
	local g = Quests.guide(book, 3, NAMES)
	eq(g[1].kind, "open", "첫 기술을 끝내면 줄의 다음 것을 받을 수 있다고 적는다")
	eq(g[1].title, "! 마을 밖의 그림자", "줄의 다음 것의 이름")
	eq(g[1].line, "샛별에게 받는다 · 초승달 마을", "누구에게 · 어디서")
	eq(#g, 1, "하나만 적는다(한 번에 받을 수 있는 것은 하나다)")
	-- 레벨이 모자라면 그 레벨을 적는다
	g = Quests.guide(book, 2, NAMES)
	eq(g[1].kind, "level", "줄의 다음 것(마을 밖의 그림자)이 레벨 때문에 잠겨 있다")
	eq(g[1].line, "Lv.3부터 받는다", "몇 레벨부터인지 적는다")
	Quests.accept(book, 3, "r1m2")
	eq(#Quests.guide(book, 3, NAMES), 0, "하는 중에는 다음 것을 적지 않는다")
	done(book, "r1m2")
	eq(#Quests.guide(book, 4, NAMES), 1, "받을 부탁이 따로 쌓이지 않는다")
	-- 주는 주민이 선 곳: 그 퀘스트의 지역 안에서, 몬스터가 없는 맵을 먼저
	eq(Quests.giverPlace(Quests.def("r1m3")), "촌장의 집", "촌장은 제 집 안에 있다")
	eq(Quests.giverPlace(Quests.def("r1m6")), "수비대 야영지", "차돌은 야영지에 있다")
	-- 길잡이의 글은 알리미의 폭에 들어간다(모든 메인 · 부탁)
	local w = UI.hud.quest.w
	for _, def in Quests.list do
		if def.playable and not def.auto then
			local place = Quests.giverPlace(def)
			expect(place ~= nil, "주는 주민이 선 곳을 안다 " .. def.id)
			local line = ("%s에게 받는다 · %s"):format(NAMES[def.giver] or "주민", place or "")
			expect(pixelText.Measure(line, "small") <= w, ("길잡이의 글이 알리미에 들어간다 %s — %s"):format(def.id, line))
			expect(pixelText.Measure("! " .. def.name, "body") <= w, "길잡이의 이름이 알리미에 들어간다 " .. def.id)
		end
	end
end

-- ---- 3) 1지역의 메인은 Lv.30 전직까지 끊기지 않는다 ----
do
	local book, level = {}, 1
	local order = {}
	local line = {}
	for _, def in Quests.list do
		if def.region == "r1" and def.kind == "main" and not def.city then -- (2편의 「큰 항구로」는 줄 밖 — 2026-10-16)
			table.insert(line, def.id) -- 줄의 차례(자료의 차례)
		end
	end
	eq(#line, 14, "1지역의 줄 열넷(2026-10-15 간소화 — 같은 몬스터를 두 번 잡는 것을 뺐다)")
	for _, id in line do
		local def = Quests.def(id)
		expect(def ~= nil and def.playable, "1지역의 메인을 할 수 있다 " .. id)
		level = math.max(level, def.lv)
		if not book[id] then
			expect(Quests.accept(book, level, id) == true, "앞의 메인을 끝내면 받는다 " .. id)
		end
		for k, st in def.steps do
			book[id].c[k] = st.n
		end
		expect(Quests.complete(book, id) ~= nil, "돌려준다 " .. id)
		table.insert(order, def.lv)
	end
	expect(level <= 29, "1지역의 메인은 Lv.29 안에 끝난다 " .. level)
	for i = 2, #order do
		expect(order[i] >= order[i - 1], "메인의 레벨은 뒤로 갈수록 높다")
		expect(order[i] - order[i - 1] <= 8, ("메인 사이가 여덟 레벨을 넘지 않는다(%d → %d)"):format(order[i - 1], order[i]))
	end
	eq(Quests.def("r1m9").endNpc, "elder", "1지역의 마지막 메인은 마을의 촌장에게 돌려준다(전직하는 사당이 있는 마을로 돌아온다)")
	-- 역할이 있는 주민(상인 · 대장장이 · 창고지기 · 전직관 · 뱃사공 …)은 퀘스트를 주지도 돌려받지도 않는다 — 전직관의 것은 전직 퀘스트와 「첫 기술」뿐(사용자 2026-10-11)
	do
		local ITEMS = req("ReplicatedStorage/shared/lune/data/items.generated")
		local role = { master = true, ferryman = true, firesmith = true, innkeeper = true }
		for id in ITEMS.NPCDO do
			if string.sub(id, 1, 5) ~= "hall_" then
				role[id] = true
			end
		end
		for _, def in Quests.list do
			for _, who in { def.giver, def.endNpc } do
				local ok = not role[who] or (who == "master" and (def.kind == "job" or def.id == QD.first.quest))
				expect(ok, ("역할 주민은 퀘스트를 주고받지 않는다 %s(%s)"):format(def.id, tostring(who)))
			end
		end
	end
	-- Lv.30: 전직 퀘스트를 받을 수 있게 되고(저절로 받지 않는다 — 사제에게 가서 받는다), 2지역의 첫 메인이 열린다
	eq(#Quests.start(book, 30), 0, "Lv.30이 되어도 저절로 받는 것은 없다")
	eq(Quests.state(book, 29, "job2"), "locked", "Lv.29에는 전직 퀘스트를 받을 수 없다")
	eq(Quests.state(book, 30, "job2"), "open", "Lv.30에 전직 퀘스트를 받을 수 있다")
	local gj = Quests.guide(book, 30, NAMES)
	expect(gj[1].kind == "job" and gj[1].title == "! 2차 전직" and gj[1].line == "그믐 사제에게 받는다 · 달의 사당", "길잡이의 맨 위에 전직 퀘스트를 받을 곳")
	expect(pixelText.Measure(gj[1].line, "small") <= UI.hud.quest.w, "그 글이 알리미에 들어간다")
	local goalJ = Quests.goal(book, 30)
	expect(goalJ ~= nil and goalJ.def.id == "job2" and goalJ.kind == "take" and goalJ.scene == "in_shrine", "월드맵의 가는 길도 사제에게(전직 퀘스트를 받으러)")
	expect(table.find(Quests.atNpc(book, 30, "master", "r1").offer, "job2") ~= nil and table.find(Quests.atNpc(book, 30, "master", "r3").offer, "job2") ~= nil, "사제는 전직 퀘스트를 어디서든 준다")
	local job = Quests.jobQuest(2)
	expect(job ~= nil and job.lv == 30 and job.endNpc == "master", "2차 전직 퀘스트는 Lv.30 · 사제에게")
	local job3 = Quests.jobQuest(3) -- 3차 전직(2026-10-16 — 2편의 끝): Lv.60 · 사제에게 · 종탑의 종지기
	expect(job3 ~= nil and job3.lv == 60 and job3.endNpc == "master" and job3.scene == "r2c3" and job3.reward.job == 3, "3차 전직 퀘스트는 Lv.60 · 사제에게 · 수정 성당 종탑")
	eq(Quests.jobQuest(4), nil, "4차 전직 퀘스트는 아직 없다(레벨만 되면 오른다)")
	local main, why = Quests.nextMain(book, 30)
	expect(main ~= nil and main.id == "cq01" and why == "open", "Lv.30이면 은달 항구로 가는 메인(「큰 항구로」 — 2026-10-16)을 받을 수 있다")
	-- 부탁: 1지역의 열을 모두 할 수 있다(2026-10-13 — 사용자: "부탁퀘스트 필요합니다." 남아 있던 하나 「묵은 도토리」는 굴의 주인을 불러내는 퀘스트였는데, 고갯마루 노인의 사냥 부탁(굴 두더지 스물)으로 고쳤다)
	local sides = 0
	for _, def in Quests.list do
		if def.region == "r1" and string.match(def.id, "^r1s%d+$") and def.playable then
			sides += 1
		end
	end
	eq(sides, 5, "1지역의 옛 부탁 가운데 다섯이 줄의 걸음이다(2026-10-15 간소화 — 여섯은 뺐다)")
end

-- ---- 4) 조작 안내의 글 ----
do
	local keys = { up = "↑", left = "←", right = "→", down = "↓", jump = "Alt", pickup = "Z", ["win:stat"] = "P", ["win:skill"] = "K" }
	local function base()
		local book = {}
		return {
			level = 1, quests = book, scene = "in_shrine", touch = false, nearNpc = nil, drop = false, hpShare = 1, potions = 10, ap = 0, sp = 0,
			key = function(a)
				return keys[a] or "?"
			end,
			slotOf = function(kind)
				local t = { mob = { "Ctrl", "대지 강타" }, boss = { "Q", "삼단 베기" }, move = { "Shift", "돌진" }, potion = { "A", "물약" } }
				return t[kind][1], t[kind][2]
			end,
		}
	end
	local seen = {}
	local function check(s, want: string, why: string)
		for _, touch in { false, true } do
			s.touch = touch
			local text = Guide.pick(s)
			expect(text ~= nil and string.find(text, want, 1, true) ~= nil, ("%s(%s) — %s"):format(why, if touch then "스마트폰" else "PC", tostring(text)))
			if text then
				seen[text] = true
			end
		end
	end
	local s = base()
	check(s, "걷는다", "처음: 걷는 법")
	s.nearNpc = "master"
	check(s, "말을 걸어 「첫 기술」을 받는다", "사제 앞: 말을 걸어 받는 법")
	Quests.accept(s.quests, 1, "r1m1")
	check(s, "한 번 더 말을 걸어 「첫 기술」을 끝낸다", "받은 뒤: 한 번 더 말을 걸어 끝내는 법")
	s = base()
	s.scene = "town"
	check(s, "달의 사당", "사당 밖에 있으면 사당으로")
	-- 첫 기술을 끝냈다
	s = base()
	done(s.quests, "r1m1")
	check(s, "사당 밖으로", "사당 안: 나가는 법")
	s.scene = "town"
	check(s, "샛별", "마을: 뛰는 법 · 내려가는 법 · 샛별이 있는 곳")
	expect(Quests.accept(s.quests, 3, "r1m2"), "줄의 다음 것(마을 밖의 그림자 — 첫 사냥)을 받는다")
	check(s, "마을 어귀", "퀘스트를 받았다: 나가는 문")
	s.scene = "r1a1"
	check(s, "수습 검병", "사냥터: 기술")
	s.touch = false
	expect(string.find(Guide.pick(s), "Ctrl 키: 대지 강타", 1, true) ~= nil, "PC에서는 사냥기가 놓인 칸의 키와 이름을 적는다")
	s.drop = true
	check(s, "줍는다", "떨어진 것이 있으면 줍는 법이 먼저")
	s.drop = false
	s.hpShare = 0.4
	check(s, "물약", "체력이 절반 아래면 물약")
	s.potions = 0
	check(s, "수습 검병", "물약이 없으면 물약 안내를 하지 않는다")
	-- 받은 점수가 있으면 길 안내보다 먼저 찍는 법을 알려 준다
	s = base()
	done(s.quests, "r1m1")
	s.level, s.ap, s.sp = 2, 5, 3
	check(s, "능력치", "첫 퀘스트로 Lv.2가 되면 능력치부터")
	s.ap = 0
	check(s, "스킬", "그다음 스킬")
	-- 맨 처음에만 가르친다(사용자 2026-10-11: "레벨업 했을때 능력치, 스킬 찍으라고 계속 글씨뜨는거 이거 빼세요 맨처음 튜토리얼때 가르쳐주는거지 계속적인 알림을 보내는게 아닙니다.")
	--  ① 처음 점수를 받은 Lv.2가 지나면 능력치 · 스킬을 찍으라는 글은 뜨지 않는다
	s = base()
	done(s.quests, "r1m1")
	s.quests.r1m2 = { done = false, c = { 0 } }
	s.level, s.ap, s.sp, s.scene = 3, 5, 3, "r1a1"
	for _, touch in { false, true } do
		s.touch = touch
		local text = Guide.pick(s)
		expect(text == nil or (string.find(text, "능력치", 1, true) == nil and string.find(text, "스킬 포인트", 1, true) == nil), "Lv.3부터는 점수를 찍으라고 하지 않는다 — " .. tostring(text))
	end
	--  ② 첫 사냥 퀘스트를 돌려준 뒤로는 어떤 안내도 뜨지 않는다(점수가 남아도 · 주울 것이 있어도 · 체력이 낮아도)
	s = base()
	done(s.quests, "r1m1")
	done(s.quests, "r1m2")
	for _, level in { 2, 3, 4, 5 } do
		s.level, s.ap, s.sp, s.scene, s.drop, s.hpShare, s.potions = level, 5, 3, "r1a1", true, 0.2, 10
		for _, touch in { false, true } do
			s.touch = touch
			eq(Guide.pick(s), nil, ("튜토리얼이 끝나면 안내가 없다(Lv.%d)"):format(level))
		end
	end
	s.touch = false
	s.level, s.ap = Guide.UNTIL + 1, 5
	eq(Guide.pick(s), nil, "레벨이 오르면 조작 안내는 뜨지 않는다")
	-- 모든 안내 글이 칸(두 줄)에 들어간다 — 줄여 적히지(…) 않는다
	local count = 0
	for text in seen do
		count += 1
		local fitted = pixelText.Fit(text, Guide.W, Guide.LINES, "small")
		expect(string.find(fitted, "…", 1, true) == nil, "안내 글이 칸에 다 들어간다 — " .. text)
		for _, line in string.split(fitted, "\n") do
			expect(pixelText.Measure(line, "small") <= Guide.W, "안내 글의 한 줄이 폭 안이다 — " .. line)
		end
	end
	expect(count >= 18, "안내 글을 열여덟 가지 넘게 봤다 " .. count)
	expect(F.key("Up") == "↑", "키 이름")
end

-- ---- 퀘스트 알리미의 판(2026-10-11 — 사용자: "퀘스트라는 인식이 되지가 않아요 ui 만들어서 퀘스트처럼 보이게하세요"): 줄의 셈과 글의 폭 ----
do
	local QuestHud = req("ReplicatedStorage/shared/lune/ui/questPanel") -- 알리미의 셈(그리는 것은 client/lune/questHud.luau)
	pixelText.Register("body", KIT.font.body, {})
	local INNER = QuestHud.INNER
	eq(INNER, UI.hud.quest.w - 16, "판 안쪽의 폭")
	local names = {}
	for _, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			names[n.id] = n.name
		end
	end
	-- 새 캐릭터: 「첫 기술」을 돌려줄 차례
	local book = {}
	local rows, height, shown, guided = QuestHud.layout(book, names, 1)
	expect(shown == 0 and guided == 0, "새 캐릭터: 받은 퀘스트가 없다 — 받을 수 있는 퀘스트는 알리미에 적지 않는다(사용자 2026-10-13: \"퀘스트 ui에 받을수있는 퀘스트 띄우지마세요\")")
	Quests.accept(book, 1, "r1m1")
	rows, height, shown, guided = QuestHud.layout(book, names, 1)
	expect(shown == 1 and rows[1].kind == "quest" and rows[1].tag == "main" and rows[1].name == "첫 기술" and rows[2].kind == "ready", "받은 뒤: 메인 「첫 기술」과 돌려줄 사람")
	expect(height > QuestHud.HEAD and height <= QuestHud.H, "판의 높이는 칸 안")
	-- 메인 하나를 하는 중 + 받을 수 있는 부탁
	book.r1m1.done = true
	expect(Quests.accept(book, 3, "r1m2"), "줄의 다음 것을 받는다")
	rows, height, shown, guided = QuestHud.layout(book, names, 3)
	local step = nil
	for _, r in rows do
		if r.kind == "step" then
			step = r
		end
	end
	expect(shown == 1 and step ~= nil and step.text == "수습 검병" and step.count == "0/5" and step.have == 0 and step.n == 5, "할 일은 글과 숫자로 갈라 적는다")
	eq(guided, 0, "하는 중에도 받을 수 있는 퀘스트는 적지 않는다")
	book.r1m2.c[1] = 3
	rows = QuestHud.layout(book, names, 2)
	for _, r in rows do
		if r.kind == "step" then
			expect(r.count == "3/5" and r.have == 3, "잡으면 숫자와 띠가 오른다")
		end
	end
	local a, b = QuestHud.split("검병 · 갑옷 조각 3/8")
	expect(a == "검병 · 갑옷 조각" and b == "3/8", "글과 숫자를 가른다")
	a, b = QuestHud.split("샛별에게 간다")
	expect(a == "샛별에게 간다" and b == nil, "숫자가 없는 줄은 그대로")
	-- 모든 퀘스트의 글이 판 안에 들어간다: 이름(갈래의 표 옆) · 할 일(숫자의 왼쪽) · 돌려줄 사람 · 길잡이
	local nameW = INNER - QuestHud.TAG_W - QuestHud.TAG_GAP
	local stepW = INNER - 2 - QuestHud.COUNT_W
	for _, def in Quests.list do
		if def.playable then
			expect(pixelText.Measure(def.name, "body") <= nameW, ("퀘스트 이름이 판에 들어간다 %s(%d)"):format(def.name, pixelText.Measure(def.name, "body")))
			for _, st in def.steps do
				local label, count = QuestHud.split(Quests.trackText(st, st.n))
				expect(count ~= nil or st.type == "visit" or st.type == "meet", "할 일의 글 끝에 숫자가 있다 " .. def.name) -- 「들르기」 · 「만나기」는 숫자 대신 ✓(2026-10-16)
				expect(pixelText.Measure(label, "small") <= stepW, ("할 일의 글이 판에 들어간다 %s — %s(%d)"):format(def.name, label, pixelText.Measure(label, "small")))
				expect(pixelText.Measure(count or "", "small") <= QuestHud.COUNT_W, "숫자가 제 칸에 들어간다 " .. def.name)
			end
			local done = { [def.id] = { done = false, c = {} } }
			for i, st in def.steps do
				done[def.id].c[i] = st.n
			end
			local back = Quests.todo(done, def.id, names)[1]
			expect(back ~= nil and pixelText.Measure(back, "small") <= INNER - 16, ("돌려줄 사람의 글이 판에 들어간다 %s — %s"):format(def.name, tostring(back)))
		end
	end
	for level = 1, 60 do
		for _, g in Quests.guide({ r1m1 = { done = true, c = {} } }, level, names) do
			expect(pixelText.Measure(g.title, "body") <= INNER and pixelText.Measure(g.line, "small") <= INNER - 2, ("길잡이의 글이 판에 들어간다 — %s / %s"):format(g.title, g.line))
		end
	end
	-- 여럿을 하는 중이어도 판은 칸의 높이를 넘지 않는다: 적은 것은 모두 적되(높이는 길어진다) 판은 칸까지만이고 그 안에서 스크롤한다(2026-10-13 — 사용자: "스크롤을 넣어야죠")
	local many = {}
	for _, def in Quests.list do
		if def.playable and def.region == "r1" then
			many[def.id] = { done = false, c = {} }
		end
	end
	local info
	rows, height, shown, guided, info = QuestHud.layout(many, names, 30)
	expect(info.view <= QuestHud.H and info.scroll == (height > QuestHud.H) and shown == #Quests.active(many), ("여럿을 받아도 판은 칸 안이다(판 %d · 적은 것의 높이 %d · 적은 것 %d)"):format(info.view, height, shown))
	-- 스마트폰: 손가락 단추에 닿지 않게 더 낮은 칸 — 판은 그 높이까지만
	expect(QuestHud.H_TOUCH <= QuestHud.H, "스마트폰의 칸은 PC보다 높지 않다")
	rows, height, shown, guided, info = QuestHud.layout(many, names, 30, QuestHud.H_TOUCH)
	expect(info.view <= QuestHud.H_TOUCH and info.scroll and shown == #Quests.active(many), ("스마트폰의 칸 안이다(판 %d · 적은 것 %d)"):format(info.view, shown))
end
