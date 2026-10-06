-- 「달의 계승자」 — 퀘스트(shared/lune/sim/quests.luau): 받기 · 잡은 것 세기 · 모으기 · 돌려주기 · 보상 · 주민 머리 위의 표시 · 저장 · 대사가 대화 상자에 들어가는지
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local D = req("ReplicatedStorage/shared/lune/data/quests.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local Q = req("ReplicatedStorage/shared/lune/sim/quests")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local F = req("ReplicatedStorage/shared/lune/ui/format")
local pixelText = req("Client/ui/pixelText")

local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {}) -- 알리미의 글은 작은 글씨(client/lune/questHud.luau — 폭 116)

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
	expect(def.kind == "main" or def.kind == "side", "갈래 " .. def.id)
	expect(def.lv >= 1 and def.reward.xp > 0, "레벨과 경험치 " .. def.id)
	if def.kind == "main" then
		mains += 1
	end
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
			expect(COMBAT.mobs[step.mob] ~= nil, ("할 일의 졸개가 있다 %s(%s)"):format(def.id, tostring(step.mob)))
			expect(step.n >= 1 and step.pct > 0 and step.pct <= 100, "수와 확률 " .. def.id)
			-- 그 맵에 그 졸개가 실제로 나온다
			local found = false
			for _, m in SCENES.scenes[def.scene].mobs do
				found = found or m.kind == step.mob
			end
			expect(found, ("그 맵에 그 졸개가 있다 %s(%s)"):format(def.id, step.mob))
			expect(measure(Q.stepText(step, step.n)) <= 116, ("할 일의 글이 알리미에 들어감 %s — 폭 %d"):format(def.id, measure(Q.stepText(step, step.n))))
		end
		-- 대사: 한 마디가 대화 상자 두 줄에 들어간다
		for _, group in { def.offer, def.wait, def.done } do
			for _, line in group do
				local lines = #string.split(pixelText.Wrap(line, F.TALK.textW, "body"), "\n")
				expect(lines <= F.TALK.lines, ("%s의 말이 %d줄에 들어감(지금 %d줄) — %s"):format(def.id, F.TALK.lines, lines, line))
			end
		end
		expect(measure(def.name) <= 116, ("퀘스트 이름이 알리미에 들어감 %s — 폭 %d"):format(def.name, measure(def.name)))
	end
end
expect(playable >= 5, "지금 할 수 있는 퀘스트가 다섯은 된다")
eq(mains, 9, "1지역의 메인 아홉")

-- ---- 2) 받기와 차례 ----
local book = {}
eq(Q.state(book, 1, "r1m1"), "open", "첫 메인은 받을 수 있다")
eq(Q.state(book, 1, "r1m2"), "locked", "앞 메인을 끝내야 다음이 열린다")
eq(Q.state(book, 1, "r1s1"), "locked", "레벨이 모자라면 못 받는다(등불 심지 Lv.2)")
eq(Q.state(book, 2, "r1s1"), "open", "레벨이 되면 받을 수 있다")
eq(Q.state(book, 30, "r1m4"), "locked", "맵이 없는 퀘스트는 받을 수 없다")
Q.start(book, 1)
eq(Q.state(book, 1, "r1m1"), "ready", "저절로 받은 첫 메인은 할 일이 없어 바로 돌려줄 수 있다")
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
local function kill(b, def, r)
	return Q.onKill(b, def.steps[1].mob, def.scene, r or rng)
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
Q.start(b2, 5)
Q.complete(b2, "r1m1")
Q.accept(b2, 5, "r1m2")
for _ = 1, 5 do
	kill(b2, M2)
end
Q.complete(b2, "r1m2")
expect(Q.accept(b2, 5, "r1m3"), "빛 없는 갑옷을 받는다")
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
Q.start(b4, 5)
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
eq(Q.state(h.quests, 1, "r1m1"), "ready", "새 캐릭터는 첫 메인을 받고 있다")
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
local pots = h.potions
local back = Hero.unpack(1, Hero.pack(h))
eq(Q.state(back.quests, back.level, "r1m1"), "done", "끝낸 것이 그대로")
eq(Q.state(back.quests, back.level, "r1m2"), "active", "하는 중인 것이 그대로")
eq(back.quests.r1m2.c[1], 2, "센 수가 그대로")
-- 물약 보상
h.quests.r1s1.c[1] = 5
local r2 = Hero.questDone(h, "r1s1")
expect(r2 ~= nil and h.potions == pots + r2.potions, "물약을 받는다")
-- 퀘스트가 생기기 전의 저장 · 깨진 저장
local old = Hero.pack(Hero.new(2, "riven"))
old.quests = nil
eq(Q.state(Hero.unpack(2, old).quests, 1, "r1m1"), "ready", "옛 저장에도 첫 메인을 준다")
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
