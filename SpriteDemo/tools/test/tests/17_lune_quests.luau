-- 「달의 계승자」 — 퀘스트(shared/lune/sim/quests.luau): 받기 · 잡은 것 세기 · 모으기 · 돌려주기 · 보상 · 주민 머리 위의 표시 · 저장 · 대사가 대화 상자에 들어가는지
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local D = req("ReplicatedStorage/shared/lune/data/quests.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
local Q = req("ReplicatedStorage/shared/lune/sim/quests")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local F = req("ReplicatedStorage/shared/lune/ui/format")
local pixelText = req("Client/ui/pixelText")

local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {}) -- 알리미의 할 일은 작은 글씨, 퀘스트 이름과 말풍선의 말은 본문 글씨(client/lune/questHud.luau · ui/talk.luau)
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local QUEST_W = UI.hud.quest.w -- 알리미의 글이 쓸 수 있는 폭

local function measure(text)
	return (pixelText.Measure(text, "small"))
end

-- ---- 1) 자료의 짜임 ----
local npcs = {}
for _, scene in SCENES.scenes do
	for _, n in scene.npcs or {} do
		npcs[n.id] = n
	end
end
local playable, mains = 0, 0
for _, def in D.list do
	expect(def.kind == "main" or def.kind == "side" or def.kind == "job", "갈래 " .. def.id)
	expect(def.lv >= 1 and (def.reward.xp > 0 or def.kind == "job"), "레벨과 경험치 " .. def.id) -- 전직 퀘스트는 경험치가 아니라 다음 차수를 준다
	if def.kind == "main" and string.sub(def.id, 1, 2) == "r1" then
		mains += 1
	end
	-- 이름표 = 지역 + m(메인) / s(부탁) + 차례
	expect(string.match(def.id, "^r%d[ms]%d+$") ~= nil or (def.kind == "job" and def.id == "job" .. tostring(def.reward.job)), "이름표의 꼴 " .. def.id)
	if def.after then
		expect(Q.def(def.after) ~= nil, "앞 퀘스트가 있다 " .. def.id)
	end
	if def.playable then
		playable += 1
		expect(SCENES.scenes[def.scene] ~= nil, "할 수 있는 퀘스트의 맵이 있다 " .. def.id)
		expect(npcs[def.giver] ~= nil and npcs[def.endNpc] ~= nil, "주고받는 주민이 있다 " .. def.id)
		expect(#def.done > 0, "돌려줄 때의 말이 있다 " .. def.id)
		expect(def.auto or #def.offer > 0, "받을 때의 말이 있다 " .. def.id)
		for _, step in def.steps do
			expect(step.n >= 1 and step.pct > 0 and step.pct <= 100, "수와 확률 " .. def.id)
			if step.type == "use" then
				-- 맵에 놓인 것 앞에서 ↑를 누르는 일: 졸개가 없고 자리가 있다(자리의 검사는 28 · 닿을 수 있는지는 25)
				expect(step.mob == false and typeof(step.spot) == "string" and typeof(step.x) == "number" and typeof(step.y) == "number", "↑를 누르는 일의 자리 " .. def.id)
			else
				expect(COMBAT.mobs[step.mob] ~= nil, ("할 일의 졸개가 있다 %s(%s)"):format(def.id, tostring(step.mob)))
				-- 그 맵에 그 졸개가 실제로 나온다
				local found = false
				for _, m in SCENES.scenes[def.scene].mobs do
					found = found or m.kind == step.mob
				end
				for _, m in SCENES.scenes[def.scene].bosses or {} do -- 스토리 보스는 졸개의 목록이 아니라 장면의 bosses에 있다
					found = found or m.kind == step.mob
				end
				expect(found, ("그 맵에 그 졸개가 있다 %s(%s)"):format(def.id, tostring(step.mob)))
			end
			expect(measure(Q.stepText(step, step.n)) <= QUEST_W, ("할 일의 글이 알리미에 들어감 %s — 폭 %d"):format(def.id, measure(Q.stepText(step, step.n))))
		end
		-- 대사: 한 마디가 말풍선의 줄 수(세 줄)에 들어간다
		for _, group in { def.offer, def.wait, def.done } do
			for _, line in group do
				local lines = #string.split(pixelText.Wrap(line, F.BUBBLE.textW, "body"), "\n")
				expect(lines <= F.BUBBLE.lines, ("%s의 말이 %d줄에 들어감(지금 %d줄) — %s"):format(def.id, F.BUBBLE.lines, lines, line))
			end
		end
		expect((pixelText.Measure(def.name, "body")) <= QUEST_W, ("퀘스트 이름(본문 글씨)이 알리미에 들어감 %s — 폭 %d"):format(def.name, (pixelText.Measure(def.name, "body"))))
	end
end
expect(playable >= 5, "지금 할 수 있는 퀘스트가 다섯은 된다")
eq(mains, 9, "1지역의 메인 아홉")
-- 2지역(2026-10-10): 첫 메인은 앞 지역의 메인이 끝나지 않아도 레벨만 되면 받는다 · 그 뒤는 앞 메인을 끝내야 열린다
do
	local b = {}
	eq(Q.state(b, 29, "r2m1"), "locked", "2지역의 첫 메인은 Lv.30부터")
	eq(Q.state(b, 30, "r2m1"), "open", "Lv.30이면 1지역의 메인을 다 하지 않아도 받는다")
	eq(Q.state(b, 40, "r2m2"), "locked", "2지역도 앞 메인을 끝내야 다음이 열린다")
	expect(Q.accept(b, 30, "r2m1"), "반달 나루를 받는다")
	eq(Q.state(b, 30, "r2m1"), "ready", "할 일이 없는 메인은 받자마자 돌려줄 수 있다(하늬에게 말을 건다)")
	eq(Q.def("r2m1").giver, "squire", "하늬가 준다(뱃사공은 역할 주민이라 퀘스트를 주지 않는다 — 2026-10-11)")
	eq(Q.def("r2m1").endNpc, "squire", "하늬에게 돌려준다")
	expect(Q.complete(b, "r2m1") ~= nil, "돌려준다")
	eq(Q.state(b, 31, "r2m2"), "open", "다음 메인이 열린다")
	eq(Q.state(b, 60, "r2m7"), "locked", "보스가 없는 메인은 받을 수 없다")
end
-- 주민은 제가 선 지역의 퀘스트만 준다(2026-10-10): 여러 맵에 서는 샛별은 1지역에서는 「등불 심지」를, 3지역에서는 「땅속으로」를 준다 — 돌려받는 것은 어디서든
do
	local b = {}
	local function has(list, id)
		return table.find(list, id) ~= nil
	end
	for _, def in D.list do
		expect(def.region == string.sub(def.id, 1, 2) or def.kind == "job", "퀘스트의 지역 " .. def.id)
	end
	for key, scene in SCENES.scenes do
		expect(scene.region == false or scene.region == "r1" or scene.region == "r2" or scene.region == "r3" or scene.region == "r4", "장면의 지역 " .. key)
	end
	eq(SCENES.scenes.town.region, "r1", "마을은 1지역")
	eq(SCENES.scenes.port.region, "r3", "등불 포구는 3지역의 들머리")
	expect(has(Q.atNpc(b, 60, "guide", "r1").offer, "r1s1"), "1지역의 샛별은 등불 심지를 준다")
	expect(not has(Q.atNpc(b, 60, "guide", "r3").offer, "r1s1"), "3지역의 샛별은 1지역의 부탁을 주지 않는다")
	expect(has(Q.atNpc(b, 60, "guide", "r3").offer, "r3m1"), "3지역의 샛별은 땅속으로를 준다")
	expect(not has(Q.atNpc(b, 60, "guide", "r1").offer, "r3m1"), "1지역의 샛별은 3지역의 메인을 주지 않는다")
	eq(Q.mark(b, 60, "guide", "r2"), nil, "2지역의 샛별에게는 줄 것이 없다")
	eq(Q.mark(b, 60, "guide", "r3"), "!", "3지역의 샛별은 「!」")
	expect(Q.accept(b, 60, "r3m1"), "땅속으로를 받는다")
	b.r3m1.c[1] = 12
	expect(has(Q.atNpc(b, 60, "guide", "r1").ready, "r3m1"), "돌려주는 것은 어느 지역의 샛별에게나")
end

-- ---- 2) 받기와 차례 ----
local book = {}
eq(Q.state(book, 1, "r1m1"), "open", "첫 메인은 받을 수 있다")
eq(Q.state(book, 1, "r1m2"), "locked", "앞 메인을 끝내야 다음이 열린다")
eq(Q.state(book, 1, "r1s1"), "locked", "레벨이 모자라면 못 받는다(등불 심지 Lv.2)")
eq(Q.state(book, 2, "r1s1"), "open", "레벨이 되면 받을 수 있다")
eq(Q.state(book, 30, "r1m4"), "locked", "맵이 없는 퀘스트는 받을 수 없다")
-- 저절로 받는 퀘스트는 없다(사용자 2026-10-11: "퀘스트를 부여해주는 npc 랑 말을하고 퀘스트를 수락해야 퀘스트가 수락되고") — 첫 메인도 사제에게 말을 걸어 받는다
for _, def in Q.list do
	expect(not def.auto, "저절로 받는 퀘스트가 아니다 " .. def.id)
end
eq(#Q.start(book, 1), 0, "Q.start는 아무것도 받지 않는다")
eq(Q.state(book, 1, "r1m1"), "open", "받기 전이다")
eq(Q.mark(book, 1, "master"), "!", "사제의 머리 위에 !")
expect(Q.isNew(book, 1), "받기 전에도 새 캐릭터다(기술이 잠겨 있다)")
expect(Q.accept(book, 1, "r1m1"), "사제에게서 첫 메인을 받는다")
eq(Q.state(book, 1, "r1m1"), "ready", "첫 메인은 할 일이 없어 받자마자 돌려줄 수 있다")
expect(Q.isNew(book, 1), "받은 뒤에도 끝내기 전에는 새 캐릭터다")
local ok, why = Q.accept(book, 1, "r1m1")
expect(not ok and why == "이미 받은 퀘스트다", "두 번 받지 못한다")
ok, why = Q.accept(book, 1, "r1m2")
expect(not ok and why == "아직 받을 수 없다", "앞 것을 끝내기 전에는 못 받는다")
ok, why = Q.accept(book, 1, "r1s1")
expect(not ok and string.find(why, "Lv.2") ~= nil, "레벨이 모자라면 까닭을 알린다")
eq(Q.accept(book, 1, "nothing"), nil, "없는 퀘스트")
eq(Q.accept(book, 1, 42), nil, "id가 글이 아니다")
-- 주민 머리 위의 표시
eq(Q.mark(book, 1, "master"), "?", "돌려줄 것이 있으면 ?")
eq(Q.mark(book, 1, "guide"), nil, "아직 줄 것이 없다")
local reward = Q.complete(book, "r1m1")
expect(reward ~= nil and reward.xp > 0, "첫 메인을 돌려준다")
eq(Q.state(book, 1, "r1m1"), "done", "끝냈다")
eq(Q.complete(book, "r1m1"), nil, "두 번 돌려주지 못한다")
eq(Q.mark(book, 1, "master"), nil, "돌려준 뒤에는 표시가 없다")
eq(Q.mark(book, 1, "guide"), "!", "다음 메인을 주는 주민에게 !")
local at = Q.atNpc(book, 1, "guide")
eq(#at.offer, 1, "샛별이 줄 퀘스트 하나(Lv.1)")
at = Q.atNpc(book, 2, "guide")
eq(#at.offer, 2, "Lv.2면 등불 심지도")

-- ---- 3) 잡기 ----
expect(Q.accept(book, 1, "r1m2"), "마을 밖의 그림자를 받는다")
eq(Q.state(book, 1, "r1m2"), "active", "하는 중")
eq(Q.mark(book, 1, "guide"), nil, "하는 중에는 표시가 없다")
eq(#Q.atNpc(book, 1, "guide").wait, 1, "하는 중인 것을 안다")
local rng = Random.new(5)
-- 퀘스트마다의 맵과 졸개(자료가 바뀌어도 테스트가 따라가게 자료에서 읽는다)
local M2, M3, S1 = Q.def("r1m2"), Q.def("r1m3"), Q.def("r1s1")
-- 졸개 한 마리를 잡고, 떨어진 퀘스트의 물건을 모두 줍는다. 바뀐 퀘스트들의 id를 돌려준다.
--  잡는 일은 잡는 순간 오르고(Q.onKill), 모으는 물건은 땅에 떨어진 것(Q.drops)을 주우면 가방에 들어가며 가방에 든 수가 곧 숫자다(Q.sync) — 사용자 2026-10-07 · 10-08.
--  여기서는 가방 없이 책만 본다: 주운 수를 책마다 따로 세어 두고 그것으로 맞춘다
local looted = {} -- [책] = { [아이템] = 주운 수 }
local function kill(b, def, r)
	local mob, scene = def.steps[1].mob, def.scene
	local changed = Q.onKill(b, mob, scene)
	looted[b] = looted[b] or {}
	for _, d in Q.drops(b, mob, scene, r or rng) do
		looted[b][d.goods] = (looted[b][d.goods] or 0) + 1
		table.insert(changed, d.quest)
	end
	Q.sync(b, function(item)
		return looted[b][item] or 0
	end)
	return changed
end
eq(#Q.onKill(book, "archer", M2.scene, rng), 0, "다른 졸개는 세지 않는다")
eq(#Q.onKill(book, M2.steps[1].mob, "town", rng), 0, "다른 맵에서는 세지 않는다")
for i = 1, 4 do
	eq(#kill(book, M2), 1, "수습 검병을 잡으면 센다 " .. i)
end
eq(Q.todo(book, "r1m2", { guide = "샛별" })[1], "수습 검병 4/5", "알리미의 글")
eq(Q.state(book, 1, "r1m2"), "active", "넷으로는 모자라다")
eq(Q.complete(book, "r1m2"), nil, "다 하기 전에는 못 돌려준다")
kill(book, M2)
eq(Q.state(book, 1, "r1m2"), "ready", "다섯이면 다 됐다")
eq(#kill(book, M2), 0, "다 찬 뒤에는 더 세지 않는다")
eq(Q.todo(book, "r1m2", { guide = "샛별" })[1], "샛별에게 간다", "다 되면 돌아가라고 적는다")
eq(Q.mark(book, 1, "guide"), "?", "돌려줄 주민에게 ?")
expect(Q.complete(book, "r1m2") ~= nil, "돌려준다")

-- ---- 4) 모으기: 잡을 때마다 확률로 하나 ----
local b2 = {}
Q.accept(b2, 5, "r1m1")
Q.complete(b2, "r1m1")
Q.accept(b2, 5, "r1m2")
for _ = 1, 5 do
	kill(b2, M2)
end
Q.complete(b2, "r1m2")
expect(Q.accept(b2, 5, "r1m3"), "빈 갑옷을 받는다")
local def3 = Q.def("r1m3")
local kills = 0
while Q.state(b2, 5, "r1m3") ~= "ready" and kills < 500 do
	kill(b2, M3)
	kills += 1
end
eq(Q.state(b2, 5, "r1m3"), "ready", "모으다 보면 다 찬다")
expect(kills >= def3.steps[1].n and kills <= 60, ("여덟 개를 모으는 데 %d마리(평균 열여섯)"):format(kills))
-- 확률: 만 번 굴려 본다
local hits, tries = 0, 20000
for _ = 1, tries do
	local b = { r1m3 = { done = false, c = {} } }
	if #kill(b, M3) > 0 then
		hits += 1
	end
end
expect(math.abs(hits / tries * 100 - def3.steps[1].pct) < 2, ("모으는 물건이 %d%%로 나온다 — %.1f"):format(def3.steps[1].pct, hits / tries * 100))
-- 여러 퀘스트가 같은 졸개를 세면 모두 센다
eq(S1.scene, M2.scene, "등불 심지와 마을 밖의 그림자는 같은 맵이다")
eq(S1.steps[1].mob, M2.steps[1].mob, "둘 다 수습 검병이다")
local b3 = { r1m2 = { done = false, c = {} }, r1s1 = { done = false, c = {} } }
local both = 0
for _ = 1, 30 do
	both = math.max(both, #kill(b3, M2)) -- 두 퀘스트 모두 마을 어귀의 수습 검병이다
end
eq(both, 2, "한 마리로 두 퀘스트가 함께 나아간다")

-- ---- 5) 그만두기 · 하는 중인 것의 차례 ----
local b4 = {}
Q.accept(b4, 5, "r1m1")
Q.complete(b4, "r1m1")
Q.accept(b4, 5, "r1s2")
Q.accept(b4, 5, "r1s1")
Q.accept(b4, 5, "r1m2")
local active = Q.active(b4)
eq(active[1], "r1m2", "메인이 맨 위")
eq(active[2], "r1s1", "그다음은 자료의 차례")
eq(#active, 3, "하는 중 셋")
ok, why = Q.drop(b4, "r1m2")
expect(not ok and why == "메인 퀘스트는 그만둘 수 없다", "메인은 못 그만둔다")
kill(b4, M2, Random.new(1))
expect(Q.drop(b4, "r1s1"), "주민의 부탁은 그만둘 수 있다")
eq(Q.state(b4, 5, "r1s1"), "open", "그만두면 다시 받을 수 있다")
eq(Q.drop(b4, "r1s1"), nil, "받지 않은 것은 그만둘 수 없다")

-- ---- 6) 캐릭터: 보상 · 저장 ----
local h = Hero.new(1, "axion")
eq(Q.state(h.quests, 1, "r1m1"), "open", "새 캐릭터는 첫 메인을 아직 받지 않았다")
eq(Hero.questDone(h, "r1m1"), nil, "받지 않은 퀘스트는 돌려주지 못한다")
expect(Q.accept(h.quests, 1, "r1m1"), "사제에게서 받는다")
local money0, xpNeed = h.money, N.xpNeed(1)
local got, ups = Hero.questDone(h, "r1m1")
expect(got ~= nil, "돌려주고 보상을 받는다")
eq(h.money, money0 + got.money, "달돈")
expect(ups >= 1 and h.level >= 2, ("경험치 %d로 레벨이 오른다(Lv.1의 필요 %d)"):format(got.xp, xpNeed))
local none, whyNot = Hero.questDone(h, "r1m1")
expect(none == nil and whyNot == "이미 끝낸 퀘스트다", "두 번 받지 못한다")
Q.accept(h.quests, h.level, "r1m2")
kill(h.quests, M2)
kill(h.quests, M2)
Q.accept(h.quests, h.level, "r1s1")
local Bag17 = req("ReplicatedStorage/shared/lune/sim/bag")
local pots = Hero.potions(h)
local back = Hero.unpack(1, Hero.pack(h))
eq(Q.state(back.quests, back.level, "r1m1"), "done", "끝낸 것이 그대로")
eq(Q.state(back.quests, back.level, "r1m2"), "active", "하는 중인 것이 그대로")
eq(back.quests.r1m2.c[1], 2, "센 수가 그대로")
-- 물약 보상
-- 모으는 물건은 가방에 든다: 모자라면 돌려주지 못하고, 돌려주면 모은 만큼 빠지고 물약(내 레벨에 쓸 수 있는 것)이 가방에 들어온다
do
	local item, need = S1.steps[1].item, S1.steps[1].n
	Bag17.give(h, item, need - 1)
	expect(Hero.syncQuests(h) and h.quests.r1s1.c[1] == need - 1, "가방에 든 수가 숫자다")
	local no, whyNo = Hero.questDone(h, "r1s1")
	expect(no == nil and whyNo == "아직 다 하지 못했다", "하나 모자라면 돌려주지 못한다")
	Bag17.give(h, item, 3)
	Hero.syncQuests(h)
	eq(h.quests.r1s1.c[1], need, "모을 수까지만 센다")
	-- 보상의 물약이 들어갈 칸이 없으면 돌려주지 못한다(아무것도 잃지 않는다)
	local keep = table.clone(h.use)
	for i = 1, Bag17.size(h) do
		h.use[i] = { item = "potion4", n = 200 }
	end
	local full, whyFull = Hero.questDone(h, "r1s1")
	expect(full == nil and whyFull == "가방의 소비 칸이 모자란다" and Bag17.count(h, item) == need + 2 and not h.quests.r1s1.done, "소비 칸이 가득 차면 돌려주지 못한다")
	h.use = keep
	local r2 = Hero.questDone(h, "r1s1")
	expect(r2 ~= nil and Hero.potions(h) == pots + r2.potions, "물약을 받는다(가방의 소비 탭)")
	eq(Bag17.count(h, item), 2, "모은 만큼 가방에서 빠진다(남는 것은 그대로)")
end
-- 그만두면 모으던 물건도 사라진다
do
	local hd = Hero.new(7, "mooni")
	hd.level = 5
	hd.quests.r1s1 = { done = false, c = {} }
	local item = S1.steps[1].item
	Bag17.give(hd, item, 4)
	Hero.syncQuests(hd)
	eq(hd.quests.r1s1.c[1], 4, "넷을 모았다")
	expect(Hero.questDrop(hd, "r1s1"), "그만둔다")
	eq(Bag17.count(hd, item), 0, "그만두면 모으던 물건도 사라진다")
	eq(Hero.questDrop(hd, "r1s1"), nil, "하는 중이 아니면 그만둘 수 없다")
	eq(Hero.questDrop(hd, "r1m1"), nil, "메인은 그만둘 수 없다")
end
-- 퀘스트가 생기기 전의 저장 · 깨진 저장
local old = Hero.pack(Hero.new(2, "riven"))
old.quests = nil
eq(Q.state(Hero.unpack(2, old).quests, 1, "r1m1"), "open", "옛 저장의 캐릭터도 첫 메인을 사제에게 받을 수 있다")
local bad = Hero.pack(h)
bad.quests = { r1m2 = { d = 0, c = { 99, 5 } }, ghost = { d = 1, c = {} }, r1m3 = "x", r1m1 = { d = 1, c = "y" } }
local fixed = Hero.unpack(1, bad)
eq(fixed.quests.r1m2.c[1], 5, "넘치는 수는 필요한 만큼으로")
eq(fixed.quests.ghost, nil, "모르는 퀘스트는 버린다")
eq(fixed.quests.r1m3, nil, "꼴이 이상한 것은 버린다")
eq(Q.state(fixed.quests, 5, "r1m1"), "done", "끝낸 표시는 살린다")
-- 화면에 보내는 꼴: 수의 표에 빈 데가 없다
local v = Q.view({ r1m2 = { done = false, c = {} }, r1m1 = { done = true, c = {} } })
eq(v.r1m2.c[1], 0, "안 센 것은 0으로 채운다")
eq(#v.r1m1.c, 0, "할 일이 없는 퀘스트")

-- ---- 9) 모으는 물건은 땅에 떨어지고, 주워야 오른다 ----
--  사용자 2026-10-07: "퀘스트 아이템이나 , 기타아이템들은 왜 드롭도되지않고 그림도없고 그냥 텍스트로만 오르나요?"
do
	local KIT9 = req("ReplicatedStorage/shared/lune/data/kit.generated")
	local gathers = 0
	for _, def in D.list do
		for _, step in def.steps do
			if step.type == "gather" then
				gathers += 1
				expect(typeof(step.icon) == "string" and KIT9.parts.icons.icons[step.icon] ~= nil, ("모으는 물건마다 제 그림이 있다: %s(%s)"):format(step.name, tostring(step.icon)))
			else
				eq(step.icon, false, "잡는 일에는 물건의 그림이 없다 " .. def.id)
			end
		end
	end
	expect(gathers >= 3, "모으는 퀘스트가 있다")
	local def = Q.def("r1m3")
	local step = def.steps[1]
	local book = { r1m3 = { done = false, c = {} } }
	-- 잡기만 해서는 오르지 않는다
	for _ = 1, 200 do
		eq(#Q.onKill(book, step.mob, def.scene), 0, "모으는 퀘스트는 잡는 것만으로 오르지 않는다")
	end
	eq(book.r1m3.c[1] or 0, 0, "줍기 전에는 0개")
	-- 떨어진 것: 그 퀘스트 · 그 일 · 물건의 이름과 그림
	local r9 = Random.new(11)
	local seen = nil
	for _ = 1, 100 do
		for _, d in Q.drops(book, step.mob, def.scene, r9) do
			seen = d
		end
	end
	expect(seen ~= nil and seen.quest == "r1m3" and seen.step == 1 and seen.name == step.name and seen.icon == step.icon, "떨어진 물건이 그 퀘스트의 것이다")
	eq(#Q.drops(book, "archer", def.scene, r9), 0, "다른 졸개에게서는 떨어지지 않는다")
	eq(#Q.drops(book, step.mob, "town", r9), 0, "다른 맵에서는 떨어지지 않는다")
	eq(#Q.drops({}, step.mob, def.scene, r9), 0, "받지 않은 퀘스트의 물건은 떨어지지 않는다")
	expect(seen.goods == step.item and typeof(step.item) == "string", "떨어진 물건은 가방에 들어갈 아이템의 이름표를 갖고 있다")
	-- 가방에 든 수가 곧 숫자다(Q.sync): 하나씩 오르고, 모을 수를 넘지 않는다(다 모으면 더 떨어지지도 않는다)
	local have = 0
	local function count(item)
		return if item == step.item then have else 0
	end
	expect(not Q.sync(book, count), "가진 것이 없으면 바뀌는 것도 없다")
	for i = 1, step.n do
		have = i
		expect(Q.sync(book, count), "가방에 들어오면 오른다 " .. i)
		eq(book.r1m3.c[1], i, "하나씩 오른다")
	end
	have = step.n + 5
	expect(not Q.sync(book, count), "모을 수를 넘게 가져도 숫자는 그대로다")
	eq(book.r1m3.c[1], step.n, "모을 수를 넘지 않는다")
	for _ = 1, 50 do
		eq(#Q.drops(book, step.mob, def.scene, r9), 0, "다 모은 뒤에는 떨어지지 않는다")
	end
	-- 버려서 줄면 숫자도 준다(가방이 참이다) · 끝낸 퀘스트는 건드리지 않는다
	have = 2
	expect(Q.sync(book, count) and book.r1m3.c[1] == 2 and not Q.isReady(book, "r1m3"), "가진 수가 줄면 숫자도 준다")
	have = step.n
	Q.sync(book, count)
	expect(Q.isReady(book, "r1m3"), "다시 다 모았다")
	local doneBook = { r1m3 = { done = true, c = { step.n } } }
	have = 0
	expect(not Q.sync(doneBook, count) and doneBook.r1m3.c[1] == step.n, "끝낸 퀘스트의 숫자는 가방을 따라 줄지 않는다")
	-- 돌려줄 때 가져가는 것 · 그 물건을 모으는 퀘스트가 있는가
	local takes = Q.takes("r1m3")
	expect(#takes == 1 and takes[1].item == step.item and takes[1].n == step.n, "돌려줄 때 모은 만큼 가져간다")
	eq(#Q.takes("r1m2"), 0, "잡는 퀘스트는 가져가는 것이 없다")
	eq(#Q.takes("no_such"), 0, "없는 퀘스트")
	expect(Q.wants(book, step.item) and not Q.wants(book, step.item, "r1m3") and not Q.wants(doneBook, step.item) and not Q.wants({}, step.item), "그 물건을 모으는 중인 퀘스트가 있는가")
	-- 모으는 물건마다 아이템 목록(GOODS)에 있다: 기타 탭 · 같은 이름과 그림 · 그 퀘스트
	local ItemsQ = req("ReplicatedStorage/shared/lune/sim/items")
	for _, d in Q.list do
		for _, st in d.steps do
			if st.type == "gather" then
				local g = ItemsQ.goods(st.item)
				expect(g ~= nil and g.tab == "etc" and g.kind == "quest" and g.name == st.name and g.icon == st.icon, "모으는 물건 = 기타 아이템: " .. st.name)
			else
				eq(st.item, false, "잡는 일에는 아이템이 없다 " .. d.id)
			end
		end
	end
end
