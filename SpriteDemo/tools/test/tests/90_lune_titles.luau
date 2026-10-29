-- 「달의 계승자」 — 칭호(2026-10-26) — 서버의 흐름 그대로.
--  사용자: "지금 레벨 선착순 150 만렙 달성자들 top 10 까지 칭호 만들어서 발급할거고, 강타는 top10 칭호도 주고, 1위 칭호도 줄거야 / 칭호이름 멋지게해서 만들고"
--  보는 것: ① 처음 만렙(firstMax)의 캐릭터 = 1위 칭호 + 열 사람 칭호 둘 다 · 높은 것을 단다 ② 열 사람의 기록에 있는 캐릭터 = 열 사람 칭호
--   ③ 만렙에 오른 캐릭터가 기록에 적힌다(오른 때의 차례) · 열이 차면 더 적지 않는다 · 만렙이 아니면 아무것도 없다
--   ④ 단 칭호를 바꾼다 · 뗀다 · 갖지 않은 것은 못 단다 ⑤ 저장 · 되살림 ⑥ 방 사람들의 이름표(Who)에 단 칭호
local TICK = 1 / 20
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local Titles = req("ReplicatedStorage/shared/lune/sim/titles")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")

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
SERVICE("RunService", { Heartbeat = signal(), IsStudio = function() return false end })
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
local firstRec = nil
local tenDisk = {}
local classDisk = {} -- [직업] = 그 직업의 첫 만렙 기록
local goldDisk = nil -- 황금왕의 세계 기록(2026-10-29)
local robuxRows = {} -- 후원 판(높은 차례)
-- ①~⑦은 직업의 첫 만렙 칭호가 섞이지 않게 모든 직업의 기록을 다른 캐릭터로 채워 둔다(⑧이 따로 본다)
local function othersTaken()
	local t = {}
	for _, c in { "axion", "riven", "reaper", "mooni", "salamander" } do
		t[c] = { key = "cOther_" .. c, name = "남", class = c, at = 1 }
	end
	return t
end
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end,
	rankTop = function(board) return if board == "robux" then table.clone(robuxRows) else {} end,
	goldKingGet = function() return true, goldDisk end,
	goldKingSettle = function(week, rec) if goldDisk and goldDisk.week == week then return goldDisk end goldDisk = rec return rec end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	firstMaxGet = function() return firstRec end,
	firstMaxClaim = function(rec) if firstRec then return false, firstRec end firstRec = rec return true, rec end,
	classFirstGet = function(class) return true, classDisk[class] end, -- 직업마다의 첫 만렙(2026-10-27)
	classFirstClaim = function(class, rec) classDisk[class] = classDisk[class] or rec return classDisk[class] end,
	maxTenGet = function() return table.clone(tenDisk) end,
	maxTenAdd = function(rec, cap)
		for _, r in tenDisk do
			if r.key == rec.key then return table.clone(tenDisk) end
		end
		if #tenDisk < cap then
			local at = 1
			while at <= #tenDisk and tenDisk[at].at <= rec.at do at += 1 end
			table.insert(tenDisk, at, rec)
		end
		return table.clone(tenDisk)
	end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local TitleServer = req("ServerScriptService/server/lune/modules/titles")
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local function join(uid, name, cls, level, maxAt)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, cls)
	handlers.Chars(p, "enter", made.id)
	World.jump(p, "town")
	local s = World.session(p)
	s.hero.level = level
	s.hero.maxAt = maxAt
	return p, s
end
local function gotOf(p)
	for i = #sent, 1, -1 do
		if sent[i].name == "TitleGot" and sent[i].player == p then
			return sent[i].args[1]
		end
	end
	return nil
end

eq(#Titles.LIST, 11, "칭호 열하나(운영자 · 1위 · 황금왕 · 직업마다의 첫 만렙 다섯 · 열 사람 · 앞설 뻔했던 자 · 할로윈의 호박 수확자 — 그림자 사수의 칭호 둘은 2026-10-28에 뺐다)")
eq(Titles.LIST[1].id, "gm", "가장 높은 것 = 운영자(2026-10-26)")
eq(Titles.LIST[2].id, "max1", "그다음 = 1위")
eq(Titles.CAP, 10, "열 사람")

-- 지금 기록: 처음 만렙 = 9001의 1번 캐릭터 · 열 사람 = 셋(9001 · 9002 · 9003)
firstRec = { key = "c9001_1", name = "첫만렙", class = "mooni", at = 100 }
tenDisk = { { key = "c9001_1", name = "첫만렙", class = "mooni", at = 100 }, { key = "c9002_1", name = "둘째만렙", class = "riven", at = 200 }, { key = "c9003_1", name = "셋째만렙", class = "axion", at = 300 } }
TitleServer.reset(table.clone(tenDisk), othersTaken())
-- FirstMax가 켜질 때 읽은 것으로
local FirstMax = req("ServerScriptService/server/lune/modules/firstMax")
FirstMax.start(function() end)
run(0.5)

-- ① 처음 만렙의 캐릭터: 둘 다 받고 1위 칭호를 단다
local p1, s1 = join(9001, "첫만렙", "mooni", N.MAX_LEVEL, 100)
run(1.2)
expect(s1.hero.titles.max1 and s1.hero.titles.max10, "1위 캐릭터는 1위 칭호와 열 사람 칭호를 둘 다 갖는다")
eq(s1.hero.title, "max1", "높은 것(1위 칭호)을 단다")
local got1 = gotOf(p1)
expect(got1 ~= nil and #got1 == 2, "받은 알림(TitleGot) 둘")
run(1.2)
local before = #sent
run(1.2)
local again = 0
for i = before + 1, #sent do
	if sent[i].name == "TitleGot" and sent[i].player == p1 then
		again += 1
	end
end
eq(again, 0, "한 번 받은 칭호는 다시 알리지 않는다")

-- ② 열 사람의 기록에 있는 캐릭터
local p2, s2 = join(9002, "둘째만렙", "riven", N.MAX_LEVEL, 200)
run(1.2)
expect(s2.hero.titles.max10 and not s2.hero.titles.max1, "열 사람 칭호만")
eq(s2.hero.title, "max10", "그것을 단다")

-- ③ 기록에 없는 만렙 캐릭터는 오른 때의 차례로 적히고 칭호를 받는다 · 만렙이 아니면 없다
local p4, s4 = join(9004, "넷째만렙", "reaper", N.MAX_LEVEL, 150)
run(1.2)
run(1.2)
local keys = {}
for _, r in tenDisk do
	table.insert(keys, r.key)
end
eq(table.concat(keys, ","), "c9001_1,c9004_1,c9002_1,c9003_1", "오른 때의 차례로 끼운다")
expect(s4.hero.titles.max10, "적힌 뒤 열 사람 칭호를 받는다")
local p5, s5 = join(9005, "아직149", "axion", N.MAX_LEVEL - 1, nil)
run(2.5)
expect(not s5.hero.titles.max10 and s5.hero.title == nil, "만렙이 아니면 칭호가 없다")
-- 열이 차면 더 적지 않는다
for i = 1, 6 do
	table.insert(tenDisk, { key = "cx" .. i, name = "x", class = "riven", at = 1000 + i })
end
TitleServer.reset(table.clone(tenDisk), othersTaken())
eq(#tenDisk, 10, "열이 찼다")
local p6, s6 = join(9006, "열하나째", "riven", N.MAX_LEVEL, 2000)
run(2.5)
eq(#tenDisk, 10, "열이 차면 더 적지 않는다")
expect(not s6.hero.titles.max10, "열한째는 받지 않는다")

-- ④ 단 칭호 바꾸기 · 떼기 · 갖지 않은 것
handlers.Title(p1, "max10")
eq(s1.hero.title, "max10", "열 사람 칭호로 바꾼다")
handlers.Title(p1, "")
eq(s1.hero.title, nil, "뗀다")
handlers.Title(p2, "max1")
eq(s2.hero.title, "max10", "갖지 않은 칭호는 못 단다")
handlers.Title(p1, "max1")
eq(Titles.nextOf(s1.hero), "max10", "「바꾸기」의 다음: 1위 → 열 사람")
s1.hero.title = "max10"
eq(Titles.nextOf(s1.hero), nil, "마지막 다음은 없음")

-- ⑤ 저장 · 되살림
s1.hero.title = "max1"
local packed = Hero.pack(s1.hero)
local back = Hero.unpack(9001, packed)
expect(back.titles.max1 and back.titles.max10 and back.title == "max1", "저장하고 되살려도 그대로")
local bad = Hero.unpack(9001, (function() local d = table.clone(packed) d.titles = { "max1", "없는칭호" } d.title = "max10" return d end)())
expect(bad.titles.max1 and not bad.titles["없는칭호"] and bad.title == nil, "모르는 칭호 · 갖지 않은 칭호를 단 저장은 버린다")
local old = table.clone(packed)
old.titles, old.title = nil, nil
local oldBack = Hero.unpack(9001, old)
expect(next(oldBack.titles) == nil and oldBack.title == nil, "칭호가 생기기 전의 저장 = 없음")

-- ⑥ 방 사람들의 이름표에 단 칭호
local who = nil
for i = #sent, 1, -1 do
	if sent[i].name == "Who" then
		who = sent[i].args[2]
		break
	end
end
local mine = nil
for _, w in who or {} do
	if w.id == s1.hero.id then
		mine = w
	end
end
expect(mine ~= nil and mine.title == "max1", "방의 이름표(Who)에 단 칭호가 실린다 — " .. tostring(mine and mine.title))

-- ⑦ 운영자 칭호(2026-10-26 사용자 "운영자 칭호도 만들어줘 나만낄수있는거"): 관리자 계정의 캐릭터에만 · 관리자가 아니면 빼고 뗀다
do
	local Admin = req("ServerScriptService/server/lune/modules/admin")
	local ADMIN_ID = next(Admin.IDS)
	expect(ADMIN_ID ~= nil, "관리자 계정 번호가 있다")
	local pg, sg = join(ADMIN_ID, "운영캐릭", "riven", 10, nil)
	run(1.2)
	expect(sg.hero.titles.gm and sg.hero.title == "gm", "관리자의 캐릭터는 운영자 칭호를 받고 단다")
	expect(not sg.hero.titles.max1 and not sg.hero.titles.max10, "관리자라고 1위 · 열 사람 칭호를 받지는 않는다")
	-- 관리 창 「모두 빼기」: 운영자 칭호는 갖고 있되 떼기만(다시 받아 달리지 않는다)
	local r = handlers.Admin(pg, "title", "")
	expect(r and r.ok, "관리 명령 「모두 빼기」")
	run(1.2)
	expect(sg.hero.titles.gm and sg.hero.title == nil, "「모두 빼기」 뒤: 운영자 칭호는 남고 떼어져 있다(다시 달리지 않는다)")
	handlers.Title(pg, "gm")
	eq(sg.hero.title, "gm", "능력치 창 「바꾸기」로 다시 단다")
	-- 관리자가 아닌 사람이 (어떻게든) 가지고 있으면 서버가 빼고 뗀다
	s2.hero.titles.gm = true
	s2.hero.title = "gm"
	run(1.2)
	expect(not s2.hero.titles.gm and s2.hero.title ~= "gm", "관리자가 아니면 운영자 칭호를 뺀다")
	handlers.Title(p2, "gm")
	expect(s2.hero.title ~= "gm", "관리자가 아니면 운영자 칭호를 달지 못한다")
	World.removePlayer(pg)
end

-- ⑧ 직업마다의 첫 만렙(2026-10-27 사용자: "직업별 첫 만렙 유저들 칭호 만들거야 … 직업별 칭호 색깔은 각자 그 직업에 맞게")
--  기록이 비었으면 「열 사람」 기록에서 그 직업의 가장 이른 사람으로 채운다(이 칭호가 생기기 전에 오른 사람) · 열 사람에 그 직업이 없으면 처음 만렙인 채로 보이는 그 직업의 캐릭터
do
	tenDisk = { { key = "c9101_1", name = "무니첫", class = "mooni", at = 10 }, { key = "c9102_1", name = "살라첫", class = "salamander", at = 20 }, { key = "c9104_1", name = "무니둘", class = "mooni", at = 40 } }
	table.clear(classDisk)
	local read = {}
	for _, c in { "axion", "riven", "reaper", "mooni", "salamander" } do
		read[c] = false -- 읽었는데 아직 없다
	end
	TitleServer.reset(table.clone(tenDisk), read)
	-- 늦게 오른 무니가 먼저 들어와도 첫 무니는 열 사람의 가장 이른 무니다
	local pB, sB = join(9104, "무니둘", "mooni", N.MAX_LEVEL, 40)
	run(1.2)
	eq(classDisk.mooni and classDisk.mooni.key, "c9101_1", "무니의 첫 만렙 = 열 사람 기록의 가장 이른 무니")
	expect(not sB.hero.titles.first_mooni, "늦게 오른 무니는 받지 않는다")
	local pA, sA = join(9101, "무니첫", "mooni", N.MAX_LEVEL, 10)
	run(1.2)
	expect(sA.hero.titles.first_mooni and sA.hero.titles.max10, "첫 무니는 「첫 대검의 계승자」(+ 열 사람)")
	eq(sA.hero.title, "first_mooni", "단 칭호가 없을 때 받은 것을 단다(목록의 차례로 처음 받은 것)")
	-- 칭호는 바꿔 다는 것(2026-10-27 사용자: "칭호는 그냥 바꿔끼는거야"): 이미 단 것이 있으면 새로 받아도 그대로
	local hx = { titles = { max10 = true }, title = "max10" }
	expect(Titles.give(hx, "first_riven") and hx.titles.first_riven and hx.title == "max10", "단 칭호가 있으면 새 칭호를 받아도 그대로 — 능력치 창에서 바꿔 단다")
	-- 이름은 다섯 모두 「가장 앞선 자」(직업은 색으로 가른다 — 사용자 "첫 을 왜붙여 그냥 가장 앞선 자 이렇게 하고 직업별로 색깔 입히면되는거야")
	for _, t in Titles.LIST do
		if t.rule == "classFirst" then
			eq(t.name, "가장 앞선 자", "직업의 첫 만렙 칭호의 이름 " .. t.id)
		end
	end
	-- 열 사람에 없는 직업(액시온): 처음 만렙인 채로 보이는 액시온이 받는다 · 만렙이 아니면 아무것도 적지 않는다
	local pC, sC = join(9105, "도끼아직", "axion", N.MAX_LEVEL - 1, nil)
	run(1.2)
	eq(classDisk.axion, nil, "만렙이 아니면 기록을 적지 않는다")
	local pD, sD = join(9106, "도끼첫", "axion", N.MAX_LEVEL, 50)
	run(1.2)
	expect(sD.hero.titles.first_axion and classDisk.axion and classDisk.axion.key == "c9106_1", "열 사람에 없는 직업은 처음 만렙인 채로 보인 캐릭터가 받는다")
	expect(not sC.hero.titles.first_axion, "만렙이 아닌 액시온은 받지 않는다")
	-- 직업마다 색이 다르다(#RRGGBB) · 색 이름도 그대로
	local seen = {}
	for _, t in Titles.LIST do
		if t.rule == "classFirst" then
			local c = Titles.tint(t, { gold = "GOLD" })
			expect(typeof(c) == "table" and c.R ~= nil, "색 " .. t.id)
			local k = ("%.3f/%.3f/%.3f"):format(c.R, c.G, c.B)
			expect(seen[k] == nil, "직업마다 다른 색 " .. t.id)
			seen[k] = true
		end
	end
	eq(Titles.tint(Titles.def("max1"), { gold = "GOLD" }), "GOLD", "색 이름은 화면의 색표에서")
	for _, p in { pA, pB, pC, pD } do
		World.removePlayer(p)
	end
end

-- ⑨ 황금왕(2026-10-29 사용자: "로벅스 지출 1위에게 황금왕 이라는 칭호를 지급해 근데 로벅스 순위가 뒤바뀌면 뺏기는 칭호야 매주 목요일마다 확인하고 그 주 1위에게 칭호 지급하고
--  다음주에 바뀌었다면 또 바뀐 1위한테 지급하고 2위한테서 뺏고"): 목요일 0시(한국 시간)에 주가 바뀐다 · 그 주의 1위 계정의 캐릭터가 받는다 · 주 안에서는 순위가 바뀌어도 그대로 ·
--  다음 주에 1위가 바뀌면 새 1위가 받고 옛 1위에게서 뺀다(달고 있었으면 뗀다 · 「칭호 이전」 알림) · 관리자 계정은 건너뛴다
do
	-- 주의 셈: 목요일 0시(한국 시간)에 바뀐다
	local t0 = os.time({ year = 2026, month = 10, day = 30, hour = 12 }) -- (어느 때든)
	local w = Titles.goldWeek(t0)
	local thu = Titles.goldWeekStart(w)
	local d = os.date("!*t", thu + Titles.KST)
	eq(d.wday, 5, "주가 시작하는 날 = 목요일(한국 시간)")
	eq(d.hour * 60 + d.min, 0, "목요일 0시")
	eq(Titles.goldWeek(thu), w, "목요일 0시부터 그 주")
	eq(Titles.goldWeek(thu - 1), w - 1, "수요일 23:59:59는 지난 주")
	eq(Titles.goldWeek(thu + 7 * 86400 - 1), w, "다음 수요일 끝까지 같은 주")
	eq(Titles.goldWeek(thu + 7 * 86400), w + 1, "다음 목요일 0시에 다음 주")

	local Admin = req("ServerScriptService/server/lune/modules/admin")
	local adminId = next(Admin.IDS)
	local now = thu + 3600 * 30 -- 그 주의 금요일 아침
	TitleServer.clock = function()
		return now
	end
	goldDisk = nil
	robuxRows = { { key = "u" .. adminId, score = 99999 }, { key = "u9201", score = 5000 }, { key = "u9202", score = 3000 } }
	TitleServer.reset(table.clone(tenDisk), othersTaken(), nil)
	local p1, s1 = join(9201, "황금하나", "riven", 30, nil)
	local p2, s2 = join(9202, "황금둘", "axion", 30, nil)
	run(2.2)
	eq(goldDisk and goldDisk.user, 9201, "처음 켜질 때 기록이 없으면 바로 정한다 — 관리자는 건너뛰고 후원 1위 계정")
	eq(goldDisk and goldDisk.week, w, "이번 주로 적는다")
	expect(s1.hero.titles.goldking == true, "1위 계정의 캐릭터가 황금왕을 받는다")
	expect(not s2.hero.titles.goldking, "2위는 받지 않는다")
	local got = gotOf(p1)
	expect(got and table.find(got, "goldking") ~= nil, "받았다는 알림(「칭호 획득」)")
	-- 같은 주 안에서 순위가 바뀌어도 그대로(목요일에만 본다)
	robuxRows = { { key = "u9202", score = 9000 }, { key = "u9201", score = 5000 } }
	now += 86400 * 2
	run(31)
	expect(s1.hero.titles.goldking and not s2.hero.titles.goldking, "주 안에서는 순위가 바뀌어도 그대로")
	-- 다음 목요일 0시: 새 1위가 받고 옛 1위에게서 뺀다
	Titles.wear(s1.hero, "goldking")
	now = thu + 7 * 86400 + 5
	run(31)
	eq(goldDisk and goldDisk.user, 9202, "다음 주의 1위로 바뀐다")
	eq(goldDisk and goldDisk.week, w + 1, "다음 주로 적는다")
	run(1.2)
	expect(s2.hero.titles.goldking == true, "새 1위가 받는다")
	expect(not s1.hero.titles.goldking, "옛 1위에게서 뺀다")
	eq(s1.hero.title, nil, "달고 있었으면 뗀다")
	local lostSent = false
	for _, e in sent do
		if e.name == "TitleGot" and e.player == p1 and e.args[2] == true and table.find(e.args[1], "goldking") then
			lostSent = true
		end
	end
	expect(lostSent, "옛 1위에게 「칭호 이전」 알림")
	-- 같은 계정의 다른 캐릭터도 받는다(계정의 칭호)
	World.removePlayer(p2)
	local p3 = { UserId = 9202, Name = "황금둘", DisplayName = "황금둘", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p3)
	local made = handlers.Chars(p3, "create", "황금셋", "mooni")
	handlers.Chars(p3, "enter", made.id)
	World.jump(p3, "town")
	run(1.2)
	expect(World.session(p3).hero.titles.goldking == true, "1위 계정의 다른 캐릭터도 받는다")
	TitleServer.clock = os.time
	World.removePlayer(p1)
	World.removePlayer(p3)
end

-- ⑩ 이름으로 주는 칭호 「앞설 뻔했던 자」(2026-10-29 사용자: "닉네임 리퍼 이사람이 랭커는 아니지만 100레벨 최초달성이라서 특별칭호 지급할거야 앞설뻔했던자 회색으로 불쌍해보이게"):
--  이름이 「리퍼」인 캐릭터가 처음 보일 때 그 캐릭터를 세계 기록(named_almost)에 묶는다 → 그 캐릭터만 받는다(이름을 바꿔도 그대로) · 다른 캐릭터는 받지 않는다
do
	local t = Titles.def("almost")
	expect(t ~= nil and t.name == "앞설 뻔했던 자" and t.rule == "named", "칭호 「앞설 뻔했던 자」(rule named)")
	expect(t and t.color == "#8E939B", "회색")
	local TN = req("ReplicatedStorage/shared/lune/data/names.generated").titleNames
	expect(t and t.rule == "named" and TN and TN.almost and TN.almost[1] == "리퍼", "이름 「리퍼」에게(닉네임은 번역하지 않는 names.generated에)")
	TitleServer.reset(table.clone(tenDisk), othersTaken(), nil)
	local pr, sr = join(9301, "리퍼", "reaper", 100, nil)
	local po, so = join(9302, "다른사람", "riven", 100, nil)
	run(2.2)
	expect(sr.hero.titles.almost == true, "「리퍼」가 받는다")
	expect(not so.hero.titles.almost, "다른 사람은 받지 않는다")
	eq(classDisk.named_almost and classDisk.named_almost.key, "c9301_1", "그 캐릭터를 세계 기록에 묶었다")
	-- 이름을 바꿔도 그 캐릭터의 것 · 다른 서버(새로 켜진 서버)도 기록을 읽어 그 캐릭터에게만
	sr.hero.titles.almost = nil
	sr.name = "새이름"
	TitleServer.reset(table.clone(tenDisk), othersTaken(), nil)
	run(2.2)
	expect(sr.hero.titles.almost == true, "이름을 바꿔도 묶인 캐릭터는 받는다")
	World.removePlayer(pr)
	World.removePlayer(po)
end
