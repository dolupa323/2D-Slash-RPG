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
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	firstMaxGet = function() return firstRec end,
	firstMaxClaim = function(rec) if firstRec then return false, firstRec end firstRec = rec return true, rec end,
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

eq(#Titles.LIST, 3, "칭호 셋(운영자 · 1위 · 열 사람)")
eq(Titles.LIST[1].id, "gm", "가장 높은 것 = 운영자(2026-10-26)")
eq(Titles.LIST[2].id, "max1", "그다음 = 1위")
eq(Titles.CAP, 10, "열 사람")

-- 지금 기록: 처음 만렙 = 9001의 1번 캐릭터 · 열 사람 = 셋(9001 · 9002 · 9003)
firstRec = { key = "c9001_1", name = "첫만렙", class = "mooni", at = 100 }
tenDisk = { { key = "c9001_1", name = "첫만렙", class = "mooni", at = 100 }, { key = "c9002_1", name = "둘째만렙", class = "riven", at = 200 }, { key = "c9003_1", name = "셋째만렙", class = "axion", at = 300 } }
TitleServer.reset(table.clone(tenDisk))
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
TitleServer.reset(table.clone(tenDisk))
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
