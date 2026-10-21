-- 「달의 계승자」 — 출석 보상 · 업적(2026-10-15 · 사용자: "출석보상, 업적 만들어야합니다")
--  셈: shared/lune/sim/attend.luau · achieve.luau · gift.luau / 서버: world.luau의 onAttend · onAchieve · achTick / 저장: account.luau의 att · ach
--  보는 것: 한국 시간의 자정 · 달이 바뀌는 때 · 하루 한 칸 · 28칸에서 멈춤 · 앞에서부터 받기 · 가방이 차면 남김 · 저장 /
--   업적의 지역(맵 · 몬스터 종류) · 단계(앞 단계 뒤에 보인다 · 한 번에 여러 단계) · 셈 · 받기 · 모두 받기 · 점수 · 등급 · 저장 · 서버의 흐름(띠 · 창 · 메뉴의 점)
local ATT = req("ReplicatedStorage/shared/lune/data/attend.generated")
local ACH = req("ReplicatedStorage/shared/lune/data/achieve.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Attend = req("ReplicatedStorage/shared/lune/sim/attend")
local Achieve = req("ReplicatedStorage/shared/lune/sim/achieve")
local Gift = req("ReplicatedStorage/shared/lune/sim/gift")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Account = req("ReplicatedStorage/shared/lune/sim/account")

-- ---- 1) 자료 ----
eq(#ATT.rewards, ATT.days, "칸마다 보상")
eq(ATT.days, 28, "한 달에 28칸")
for i, r in ATT.rewards do
	local any = false
	for k, v in r do
		expect(k == "money" or k == "dust" or k == "potion" or k == "scroll", "보상의 갈래 " .. i .. " " .. k)
		expect(typeof(v) == "number" and v > 0 and v == math.floor(v), "보상의 수 " .. i)
		any = true
	end
	expect(any, "빈 칸이 없다 " .. i)
	expect(not (r.potion and r.scroll), "한 칸에 물약과 주문서가 같이 있지 않다(소비 탭 한 칸 — 가방이 차면 둘 다 못 받는다) " .. i)
end
for _, d in ATT.big do
	local r = ATT.rewards[d]
	local n = 0
	for _ in r do
		n += 1
	end
	expect(n >= 2, "큰 칸(★)은 보상이 둘 " .. d)
end

-- ---- 2) 출석: 한국 시간의 자정 · 달 ----
local KST_1015_0000 = 1791990000 -- 2026-10-15 00:00 (한국 시간)
local KST_1015_2359 = 1792076399
local KST_1016_0000 = 1792076400
local KST_1031_2359 = 1793458799
local KST_1101_0000 = 1793458800
eq(Attend.dayOf(KST_1015_0000), Attend.dayOf(KST_1015_2359), "같은 날(00:00 ~ 23:59 한국 시간)")
eq(Attend.dayOf(KST_1016_0000), Attend.dayOf(KST_1015_2359) + 1, "자정에 하루가 바뀐다")
eq(Attend.monthOf(KST_1015_0000), 202610, "10월")
eq(Attend.monthOf(KST_1031_2359), 202610, "31일 23:59는 10월")
eq(Attend.monthOf(KST_1101_0000), 202611, "1일 00:00은 11월")

local t = Attend.new()
expect(Attend.checkIn(t, KST_1015_0000 + 100), "그날 처음 들어오면 칸이 찬다")
eq(t.n, 1, "한 칸")
expect(not Attend.checkIn(t, KST_1015_2359), "같은 날 다시는 안 찬다")
eq(t.n, 1, "그대로 한 칸")
expect(Attend.checkIn(t, KST_1016_0000), "다음 날 또 한 칸")
eq(t.n, 2, "두 칸 — 이어서 오지 않아도 쌓인다")
eq(Attend.ready(t), 2, "받을 칸 둘")
local v = Attend.view(t, KST_1016_0000)
expect(v.month == 10 and v.n == 2 and v.got == 0 and v.today == true and v.days == 28, "판의 모습")

-- 받기: 앞에서부터 · 보상은 누른 캐릭터에게
local h = Hero.new(1, "riven")
local money0, dust0 = h.money, h.dust
local got, why = Attend.claim(t, h)
eq(got, 2, "두 칸을 받는다")
eq(why, nil, "막힘 없음")
eq(h.money, money0 + (ATT.rewards[1].money or 0), "1일 = 달돈")
eq(t.got, 2, "받은 칸 둘")
eq(Attend.ready(t), 0, "받을 것 없음")

-- 28칸에서 멈춘다 · 달이 바뀌면 새 판(받지 않은 칸은 사라진다)
for d = 2, 40 do
	Attend.checkIn(t, KST_1015_0000 + d * 86400 - 3600 * 0)
end
expect(t.n <= ATT.days, "28칸을 넘지 않는다")
local t2 = Attend.new()
for d = 0, 16 do
	Attend.checkIn(t2, KST_1015_0000 + d * 86400)
end
eq(t2.m, 202610, "10월의 판")
eq(t2.n, 17, "10월 15일 ~ 31일 = 17칸")
expect(Attend.checkIn(t2, KST_1101_0000), "11월 1일")
eq(t2.m, 202611, "새 판")
eq(t2.n, 1, "새 판의 첫 칸")
eq(t2.got, 0, "받은 칸도 새로")
eq(t2.total, 18, "지금까지 출석한 날은 그대로 쌓인다")

-- 가방이 차면 거기서 멈추고 남겨 둔다
local h2 = Hero.new(2, "axion")
local t3 = Attend.new()
t3.m, t3.n, t3.got, t3.last = 202610, 3, 0, Attend.dayOf(KST_1015_0000)
for i = 1, Bag.size(h2) do
	h2.use[i] = { item = "potion4", n = 200 } -- 소비 탭을 다 채운다
end
got, why = Attend.claim(t3, h2)
eq(got, 1, "1일(달돈)은 받고 2일(물약)에서 멈춘다")
expect(why ~= nil, "가방이 찬 까닭")
eq(t3.got, 1, "남은 칸은 그대로(다시 받는다)")

-- 저장
local packed = Attend.pack(t2)
local back = Attend.unpack(packed)
expect(back.m == t2.m and back.n == t2.n and back.got == t2.got and back.last == t2.last and back.total == t2.total, "저장한 대로")
local junk = Attend.unpack({ m = "x", n = 99, got = -1 })
expect(junk.n == 0 and junk.got == 0 and junk.m == 0, "이상한 꼴은 새 판")
eq(Attend.unpack(nil).n, 0, "없으면 새 판")

-- 보상 글
eq(Gift.text({ dust = 30, scroll = 3 }, ATT.words), "달가루 30 · 귀환 주문서 3장", "보상 글")

-- ---- 3) 업적: 자료 · 지역 ----
local points = 0
local seenId = {}
for i, def in ACH.list do
	expect(not seenId[def.id], "업적 이름표가 겹치지 않는다 " .. def.id)
	seenId[def.id] = true
	expect(ACH.points[def.grade] ~= nil, "등급 " .. def.id)
	points += ACH.points[def.grade]
	if def.after then
		local prev = Achieve.BY[def.after]
		expect(prev ~= nil and prev.order < i, "앞 단계가 목록에서 먼저다 " .. def.id)
	end
	local tabOk = false
	for _, tb in ACH.tabs do
		tabOk = tabOk or tb[1] == def.tab
	end
	expect(tabOk, "탭 " .. def.id)
end
expect(#ACH.list >= 20, "업적 스물이 넘는다")
local r1 = Achieve.REGION.r1
expect(r1 ~= nil, "1지역")
expect(table.find(r1.maps, "r1a1") ~= nil and table.find(r1.maps, "town") ~= nil, "1지역의 맵에 마을 어귀 · 마을")
eq(table.find(r1.maps, "dream"), nil, "꿈은 들를 맵이 아니다")
for _, key in r1.maps do
	expect(not SCENES.scenes[key].indoor, "실내는 들를 맵이 아니다 " .. key)
end
expect(table.find(r1.kinds, "trainee") ~= nil and table.find(r1.kinds, "warrior") ~= nil, "1지역의 몬스터에 수습 검병 · 검병")
for _, m in SCENES.scenes.dream.mobs or {} do
	local elsewhere = false
	for key, sc in SCENES.scenes do
		if key ~= "dream" and sc.region == "r1" then
			for _, x in sc.mobs or {} do
				elsewhere = elsewhere or x.kind == m.kind
			end
		end
	end
	if not elsewhere then
		eq(table.find(r1.kinds, m.kind), nil, "꿈에만 있는 몬스터는 종류에 넣지 않는다 " .. m.kind)
	end
end
expect(#r1.kinds >= 9, "1지역의 몬스터 종류 " .. #r1.kinds)

-- ---- 4) 업적: 단계 · 셈 · 받기 ----
local a = Achieve.new()
local ctx = { level = 1, job = 1, classes = { riven = 1 }, quests = {}, star = 0, att = Attend.new() }
eq(#Achieve.check(a, ctx), 0, "처음에는 해낸 것이 없다")
expect(not Achieve.visible(a, Achieve.BY.lv20), "Lv.20은 Lv.10을 해낸 뒤에 보인다")
ctx.level = 30
local fresh = Achieve.check(a, ctx)
expect(table.find(fresh, "lv10") and table.find(fresh, "lv20") and table.find(fresh, "lv30"), "Lv.30이면 한 번에 세 단계")
expect(table.find(fresh, "lv10") < table.find(fresh, "lv20"), "앞 단계가 먼저 알린다")
for _ = 1, 99 do
	Achieve.killed(a, "trainee", "r1a1", false)
end
eq(#Achieve.check(a, ctx), 0, "99마리는 아직")
Achieve.killed(a, "warrior", "hunt", true)
fresh = Achieve.check(a, ctx)
expect(table.find(fresh, "kill100") ~= nil, "100마리")
eq(a.c.partyKill, 1, "함께 잡은 것은 파티로 처치")
expect(a.kinds.trainee and a.kinds.warrior, "쓰러뜨린 종류")
Achieve.killed(a, "nope", "dream", false)
eq(a.kinds.nope, nil, "꿈의 몬스터는 종류에 넣지 않는다")
Achieve.visited(a, "r1a1")
Achieve.visited(a, "in_shrine")
expect(a.seen.r1a1 and not a.seen.in_shrine, "들른 맵(실내는 빼고)")
local have, need = Achieve.progress(a, Achieve.BY.visit_r1, ctx)
eq(have, 1, "들른 맵 하나")
eq(need, #r1.maps, "들를 맵 모두")
-- 퀘스트 · 별 · 출석 · 직업
ctx.quests = { r1m7 = { done = true, c = {} } }
ctx.job = 2
ctx.star = 5
ctx.classes = { riven = 30, axion = 10, mooni = 12 }
fresh = Achieve.check(a, ctx)
for _, id in { "giant", "job2", "star5", "classes3" } do
	expect(table.find(fresh, id) ~= nil, "해냈다 " .. id)
end
eq(a.done.jailer, nil, "쇠사슬 간수는 아직")
Achieve.forged(a, 10)
expect(table.find(Achieve.check(a, ctx), "star10") ~= nil, "10성")
-- 숨김
local view = Achieve.view(a, ctx)
eq(view.rows.death1.st, 1, "숨김 업적은 하는 중(화면은 「???」)")
expect(ACH.list[Achieve.BY.death1.order].hidden == true, "숨김 표시")
Achieve.add(a, "death")
expect(table.find(Achieve.check(a, ctx), "death1") ~= nil, "처음 쓰러짐")
-- 점수 · 등급
local score = Achieve.score(a)
local expectScore = 0
for id in a.done do
	expectScore += ACH.points[Achieve.BY[id].grade]
end
eq(score, expectScore, "점수 = 해낸 업적의 점수")
local gname, nextG = Achieve.grade(score)
expect(gname ~= nil, "등급이 있다 — " .. tostring(gname))
eq(Achieve.grade(0), nil, "0점은 등급 없음")
local top = ACH.grades[#ACH.grades]
local gTop, nTop = Achieve.grade(points)
eq(gTop, top.name, "모두 해내면 가장 높은 등급")
eq(nTop, nil, "그 위는 없다")
-- 받기
local hh = Hero.new(3, "mooni")
local d0 = hh.dust
expect(Achieve.claim(a, hh, "star5"), "받는다")
eq(hh.dust, d0 + ACH.list[Achieve.BY.star5.order].reward.dust, "달가루를 받았다")
local ok2, why2 = Achieve.claim(a, hh, "star5")
expect(not ok2 and why2 ~= nil, "두 번은 못 받는다")
local ok3 = Achieve.claim(a, hh, "jailer")
expect(not ok3, "해내지 못한 것은 못 받는다")
local before = Achieve.ready(a)
expect(before > 0, "받을 것이 남았다")
local n, whyAll = Achieve.claimAll(a, hh)
eq(n, before, "모두 받기")
eq(whyAll, nil, "막힘 없음")
eq(Achieve.ready(a), 0, "다 받았다")
-- 저장
local pa = Achieve.pack(a)
local ua = Achieve.unpack(pa)
eq(Achieve.score(ua), Achieve.score(a), "저장한 대로(점수)")
eq(ua.c.kill, a.c.kill, "저장한 대로(처치)")
expect(ua.kinds.trainee and ua.seen.r1a1 and ua.got.star5, "저장한 대로(종류 · 맵 · 받음)")
local bad = Achieve.unpack({ c = { kill = -5, nope = 3 }, done = { "nope", "lv10" }, got = { "lv20" }, star = 500 })
expect(bad.c.kill == nil and bad.c.nope == nil, "이상한 셈은 버린다")
expect(bad.done.lv10 and not bad.done.nope, "모르는 업적은 버린다")
eq(bad.got.lv20, nil, "해내지 않은 것을 받았다고 적을 수 없다")
eq(bad.star, 0, "이상한 별")
-- 계정에 저장
local acct = Account.new()
acct.att.n, acct.att.m = 5, 202610
acct.ach.c.kill = 42
local ua2 = Account.unpack(Account.pack(acct))
eq(ua2.att.n, 5, "계정이 출석을 저장한다")
eq(ua2.ach.c.kill, 42, "계정이 업적을 저장한다")
local old = Account.pack(Account.new())
old.att, old.ach = nil, nil
local ua3 = Account.unpack(old)
expect(ua3.att.n == 0 and ua3.ach.c.kill == nil, "옛 저장 = 새 판 · 아무것도 안 함")

-- ---- 5) 서버의 흐름 ----
local handlers, sent = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
expect(handlers.Attend ~= nil and handlers.Achieve ~= nil, "서버가 출석 · 업적을 듣는다")
local p = { UserId = 5101, Name = "길손5101", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "출석시험", "riven")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
eq(s.acct.att.n, 1, "들어오면 오늘의 칸이 찬다")
local r = handlers.Attend(p, "view")
expect(r and r.fresh == true, "오늘 처음 — 창을 한 번 띄운다")
expect(r.view.n == 1 and r.view.got == 0, "판의 모습")
r = handlers.Attend(p, "view")
eq(r.fresh, false, "두 번째로 물을 때는 띄우지 않는다")
local m0 = s.hero.money
r = handlers.Attend(p, "claim")
eq(r.got, 1, "1일을 받는다")
eq(s.hero.money, m0 + (ATT.rewards[1].money or 0), "보상은 들어온 캐릭터에게")
-- 업적: 셈이 오르면 1초 시계가 알린다(띠)
table.clear(sent)
s.acct.ach.c.kill = 100
World.tick(1.1)
local done = nil
for _, m in sent do
	if m.name == "AchDone" then
		done = m.args[1]
	end
end
expect(done ~= nil and table.find(done, "kill100") ~= nil, "해낸 업적을 알린다(AchDone)")
local selfMsg = nil
for _, m in sent do
	if m.name == "Self" then
		selfMsg = m.args[1]
	end
end
expect(selfMsg and selfMsg.achReady >= 1, "메뉴의 점(받을 업적의 수)")
eq(selfMsg and selfMsg.attReady, 0, "출석은 다 받았다")
r = handlers.Achieve(p, "view")
eq(r.view.rows.kill100.st, 2, "창: 해냄(받을 것)")
local pot0 = Bag.room(s.hero, Items.potionFor(s.hero.level).id)
r = handlers.Achieve(p, "claim", "kill100")
eq(r.got, 1, "받았다")
eq(r.view.rows.kill100.st, 3, "받음")
expect(Bag.room(s.hero, Items.potionFor(s.hero.level).id) < pot0, "물약이 가방에 들어왔다")
-- 게임 중에 자정이 지나면 칸이 찬다
s.acct.att.last -= 1
table.clear(sent)
World.tick(1.1)
local newDay = false
for _, m in sent do
	newDay = newDay or m.name == "AttendNew"
end
expect(newDay, "자정이 지나면 출석 창을 띄우라고 알린다")
eq(s.acct.att.n, 2, "두 칸")
-- 들른 맵
expect(s.acct.ach.seen[s.scene] ~= nil or string.match(s.scene, "^dream#%d+$") ~= nil, "들어선 맵을 적는다") -- (꿈은 사람마다 따로 된 방 — dream#번호)
