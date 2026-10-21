-- 「달의 계승자」 — 플레이어 데이터 기록(server/lune/modules/analytics.luau · 로블록스 분석 AnalyticsService — 2026-10-15)
--  사용자: "플레이어 데이터 수집 로블록스에서 어떻게 진행되는지 알아보고 조치합시다"
--  보는 것: 퀘스트 줄의 차례 · 레벨 구간 · 달돈의 갈래 · 들어옴 → 캐릭터 → 꿈 → 미션 · 레벨 · 퀘스트 줄 · 쓰러짐 · 달돈을 모아 보내기 ·
--   요청이 바꾼 달돈의 갈래 · 확인용 캐릭터는 적지 않는다 · 보내는 곳(가짜 AnalyticsService)에 로블록스의 꼴로 간다 · 필드에 이름이 없다
local QUESTS = req("ReplicatedStorage/shared/lune/data/quests.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local N = req("ReplicatedStorage/shared/lune/config/numbers")

-- ---- 서버를 띄운다(test 48과 같은 가짜들) ----
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
local Analytics = req("ServerScriptService/server/lune/modules/analytics")
local World = req("ServerScriptService/server/lune/modules/world")

-- ---- 1) 자료: 퀘스트 줄의 차례 ----
local line = Analytics.LINE
local count = 0
for _, def in QUESTS.list do
	if def.line and def.region == "r1" and def.playable then
		count += 1
	end
end
eq(#line, count, "퀘스트 줄의 퀘스트가 모두 차례에 들어갔다")
expect(#line >= 10, "1지역 줄은 열 개가 넘는다 — " .. #line)
eq(line[1].after, false, "줄의 첫 퀘스트는 앞이 없다")
for i = 2, #line do
	eq(line[i].after, line[i - 1].id, ("줄의 %d째는 %d째 다음에 열린다"):format(i, i - 1))
end
eq(#line + 1 <= 100, true, "MainQuest 퍼널은 100단계 안")

-- ---- 2) 레벨 구간 · 달돈의 갈래 ----
eq(Analytics.band(1), "Lv01-05", "구간 1")
eq(Analytics.band(5), "Lv01-05", "구간 5")
eq(Analytics.band(6), "Lv06-10", "구간 6")
eq(Analytics.band(30), "Lv26-30", "구간 30")
eq(Analytics.band(31), "Lv31-40", "30 뒤는 열씩")
local seen = {}
for _, lv in { 1, 7, 13, 22, 30, 31, 55, 99, 140, 200 } do
	seen[Analytics.band(lv)] = true
end
local bands = 0
for _ in seen do
	bands += 1
end
expect(bands <= 20, "구간이 많지 않다(필드 조합 8,000 안)")
local function kind(name, action, gain)
	local tx, sku = Analytics.moneyKind(name, action, gain)
	return tx .. "/" .. sku
end
eq(kind("Item", "buy", false), "Shop/ShopBuy", "상점에서 산다")
eq(kind("Item", "sell", true), "Shop/NpcSell", "상점에 판다")
eq(kind("Item", "grow", false), "Shop/BagExpand", "가방을 늘린다")
eq(kind("Item", "craft", false), "Gameplay/Craft", "제작")
eq(kind("Quest", "complete", true), "Gameplay/QuestReward", "퀘스트 보상")
eq(kind("Daily", "turnIn", true), "Gameplay/DailyQuest", "일일 의뢰")
eq(kind("tick", nil, true), "Gameplay/MonsterDrop", "요청 밖에서 들어온 달돈 = 몬스터")
eq(kind("Market", "list", false), "Auction/AuctionDeposit", "경매 보증금")
eq(kind("Market", "buy", false), "Auction/AuctionBuy", "경매로 산다")
eq(kind("Market", "all", true), "Auction/AuctionCollect", "경매 대금 · 돌려받음")

-- ---- 3) 서버에서: 들어옴 → 캐릭터 → 꿈 ----
local calls = {}
local fake = setmetatable({}, {
	__index = function(_, method)
		return function(_, ...)
			table.insert(calls, { method = method, args = { ... } })
		end
	end,
})
Analytics.setService(fake)
World.start()
table.clear(Analytics.log)
local p = { UserId = 5001, Name = "길손5001", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
handlers.Ready(p)
World.addPlayer(p)
local made = handlers.Chars(p, "create", "기록시험", "riven")
expect(made and made.ok, "캐릭터를 만든다")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
local h = s.hero
local function find(kind, a1, a2)
	for _, row in Analytics.log do
		if row.kind == kind and (a1 == nil or row.args[1] == a1) and (a2 == nil or row.args[2] == a2) then
			return row
		end
	end
	return nil
end
local function onboardStep(n)
	return find("onboard", n)
end
expect(onboardStep(1) ~= nil, "온보딩 1 = 접속")
expect(onboardStep(2) ~= nil, "온보딩 2 = 캐릭터 만듦")
expect(onboardStep(3) ~= nil, "온보딩 3 = 달빛 꿈(새 캐릭터는 꿈에서 시작)")
eq(string.match(s.scene, "^(.-)#%d+$"), "dream", "새 캐릭터는 꿈에 있다(사람마다 따로 된 꿈의 방 — 2026-10-21)")

-- 꿈의 첫 미션(걷기 — 화면이 알리는 일)을 마치면 온보딩 4
handlers.Tut(p, "done", 1)
expect(onboardStep(4) ~= nil, "꿈의 첫 미션을 마치면 온보딩 4")
expect(string.find(onboardStep(4).args[2], "04", 1, true) == 1, "단계의 이름은 번호부터 — " .. tostring(onboardStep(4).args[2]))

-- ---- 4) 레벨 · 퀘스트 줄 · 쓰러짐 — 1초 시계가 본다 ----
local lv0 = h.level
h.played = 600 -- 이 캐릭터로 10분 놀았다
Hero.gainXp(h, N.xpNeed(h.level) - h.xp)
World.tick(1.1)
local levelRow = find("funnel", "Level")
expect(levelRow ~= nil and levelRow.args[3] == lv0 + 1, "레벨이 오르면 Level 퍼널의 그 레벨 단계")
expect(levelRow and levelRow.args[2] == "5001-" .. tostring(s.cid), "Level 퍼널의 세션 = 그 캐릭터")
local up = find("custom", "LevelUp")
expect(up ~= nil and up.args[2] >= 10 and up.args[2] < 10.2, "LevelUp의 값 = 그 캐릭터로 논 분(10분) — " .. tostring(up and up.args[2]))
eq(up and up.fields[1], "riven", "필드 1 = 직업")
eq(up and up.fields[2], Analytics.band(lv0 + 1), "필드 2 = 레벨 구간")

local q1 = line[1]
h.quests[q1.id] = { done = false, c = {} }
World.tick(1.1)
local mq = find("funnel", "MainQuest")
expect(mq ~= nil and mq.args[3] == 1, "줄의 첫 퀘스트를 받으면 MainQuest 1")
h.quests[q1.id].done = true
World.tick(1.1)
local mq2
for _, row in Analytics.log do
	if row.kind == "funnel" and row.args[1] == "MainQuest" and row.args[3] == 2 then
		mq2 = row
	end
end
expect(mq2 ~= nil, "줄의 첫 퀘스트를 끝내면 MainQuest 2")
expect(mq2 and string.find(mq2.args[4], q1.name, 1, true) ~= nil, "단계 이름에 퀘스트 이름")
expect(find("onboard", Analytics.ONBOARD_LAST - 3) ~= nil, "온보딩: 첫 퀘스트 받음")
expect(find("onboard", Analytics.ONBOARD_LAST - 2) ~= nil, "온보딩: 첫 퀘스트 끝")
-- 2편의 길(Part2Quest — 2026-10-16): 「큰 항구로」를 받으면 1 · 끝내면 2 · 「항구의 첫날」을 끝내면 3
eq(#Analytics.LINE2, 12, "2편의 길 = 큰 항구로 · 항구의 첫날 · 메인 아홉 · 3차 전직")
h.quests.cq01 = { done = false, c = {} }
World.tick(1.1)
local p1 = find("funnel", "Part2Quest")
expect(p1 ~= nil and p1.args[3] == 1, "「큰 항구로」를 받으면 Part2Quest 1")
h.quests.cq01.done = true
h.quests.cq02 = { done = true, c = {} }
World.tick(1.1)
local steps2 = {}
for _, row in Analytics.log do
	if row.kind == "funnel" and row.args[1] == "Part2Quest" then
		steps2[row.args[3]] = true
	end
end
expect(steps2[2] and steps2[3], "「큰 항구로」 · 「항구의 첫날」을 끝내면 Part2Quest 2 · 3")

h.alive = false
World.tick(1.1)
local death = find("custom", "Death")
expect(death ~= nil and death.fields[3] == (string.match(s.scene, "^(.-)#%d+$") or s.scene), "쓰러지면 Death — 필드 3 = 그 맵(따로 된 방이면 그 장면의 이름 — 방 번호는 빼서 값이 늘지 않게)")
h.alive = true
World.tick(1.1)

-- ---- 5) 달돈: 요청 밖에서 들어온 것은 몬스터 · 가방 늘리기는 상점 — 60초에 한 번 모아 보낸다 ----
h.money += 50
World.tick(1.1)
h.money += 25
World.tick(1.1)
eq(find("economy"), nil, "달돈은 바로 보내지 않는다(모은다)")
h.money += 100000
s.an.money = h.money -- (시험이 준 돈 — 기록하지 않는다)
handlers.Item(p, "grow")
expect(h.bagGrow == 1, "가방을 늘렸다")
for _ = 1, 60 do
	World.tick(1)
end
local drop, grow
for _, row in Analytics.log do
	if row.kind == "economy" and row.args[5] == "MonsterDrop" then
		drop = row
	elseif row.kind == "economy" and row.args[5] == "BagExpand" then
		grow = row
	end
end
expect(drop ~= nil and drop.args[1] == "Source" and drop.args[2] == 75, "몬스터 달돈 75를 한 번에(Source)")
expect(grow ~= nil and grow.args[1] == "Sink" and grow.args[4] == "Shop", "가방 늘리기 = 상점(Sink)")
expect(grow and grow.args[3] == h.money, "잔고 = 보내는 때의 달돈")

-- ---- 6) 보내는 곳에 로블록스의 꼴로 갔다 · 이름은 없다 ----
local methods = {}
for _, c in calls do
	methods[c.method] = (methods[c.method] or 0) + 1
	for i, v in c.args do
		if i > 1 and typeof(v) == "table" then -- (첫째는 그 사람 — 로블록스가 잇는다)
			for _, fv in v do
				expect(fv ~= "기록시험" and fv ~= "길손5001", "필드에 이름을 넣지 않는다")
			end
		end
		expect(i == 1 or (v ~= "기록시험" and v ~= "길손5001"), "값에 이름을 넣지 않는다")
	end
end
expect((methods.LogOnboardingFunnelStepEvent or 0) >= 4, "온보딩은 LogOnboardingFunnelStepEvent로")
expect((methods.LogFunnelStepEvent or 0) >= 3, "퍼널은 LogFunnelStepEvent로")
expect((methods.LogCustomEvent or 0) >= 2, "커스텀은 LogCustomEvent로")
expect((methods.LogEconomyEvent or 0) >= 2, "달돈은 LogEconomyEvent로")
for _, c in calls do
	if c.method == "LogEconomyEvent" then
		eq(c.args[3], "Money", "통화 = Money")
		expect(c.args[4] > 0 and c.args[5] >= 0, "양은 양수 · 잔고는 0 이상")
	end
end

-- ---- 7) 나가면 남은 달돈을 보낸다 ----
h.money += 7
handlers.Chars(p, "leave")
local last = Analytics.log[#Analytics.log]
expect(last.kind == "economy" and last.args[2] == 7, "캐릭터 고르기로 나갈 때 모은 달돈을 보낸다")
eq(s.an, nil, "나가면 기록을 그친다")

-- ---- 8) 확인용 캐릭터(LuneGuest)는 적지 않는다 ----
table.clear(Analytics.log)
local g = { UserId = 5002, Name = "길손5002", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
local sg = { player = g, guest = true, hero = Hero.new(5002, "axion") }
Analytics.begin(sg)
eq(sg.an, nil, "확인용 캐릭터는 기록을 시작하지 않는다")
Analytics.joined(sg)
eq(#Analytics.log, 0, "확인용 캐릭터는 아무것도 적지 않는다")

-- ---- 9) 저장: 논 시간 ----
local h2 = Hero.new(1, "axion")
h2.played = 1234
eq(Hero.unpack(1, Hero.pack(h2)).played, 1234, "논 시간을 저장한다")
local old = Hero.pack(h2)
old.played = nil
eq(Hero.unpack(1, old).played, 0, "옛 저장은 0부터")
Analytics.setService(nil)
