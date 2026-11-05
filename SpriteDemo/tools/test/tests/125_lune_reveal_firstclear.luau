-- 「달의 계승자」 — 용암 거인 공개: 출현(1시간 · 떡밥 알림 · 왼쪽 아래 빨간 남은 시간) · 솔플 최초 격파 · 보상의 방의 심장핵 — 서버의 흐름 그대로(2026-11-05).
--  사용자: "퍼블리시 할거고 솔플로 잡아도 한 파티로 되서 퍼클적용되어야하고 이거진짜 연결 누락되거나 하면 절대안된다 … 내가 퍼블리시를 하면 보스가 바로 열리는게 아니라
--   1시간에 한번 랜덤 대사로 용암거인이 출현한다는 떡밥 메시지를 계속 전체서버 공지로 … 왼쪽 아래에 캐릭터 ui 닉네임 위에 빨간시간이 표시되고 그시간이 다되면 보스 출현이야 1시간정도로"
--  보는 것: ① 자료 — 용암 거인이 공개됐다(dev 아님) · reveal(3600초 · 알림의 때 · 말) · 보스 퀘스트에 reveal
--   ② 셈(sim/reveal.luau) — 모르면 닫힘 · 시각 전 닫힘 · 지나면 열림 · 남은 시간의 글 · 알림의 때를 지나는 것 · 말
--   ③ 출현 전에 닫혀 있는 것: 보스 퀘스트(locked) · 입장(「아직 깨어나지 않았다 — 출현까지 …」) · 스케줄러의 줄 · 서버의 문 앞 입장
--   ④ 서버(World.revealTick · server modules/reveal.luau): 켜질 때 저장소에 「지금 + 3600」을 적는다 · 화면에 출현 시각(Reveal) · 알림의 때마다 떡밥(RevealNews tease) · 0이 되면 출현(open)
--   ⑤ 출현한 뒤 혼자 들어가 격파 → 최초 격파 1/3(혼자 = 한 파티) · 그 자리에서 칭호 · 모두에게 FirstClear · 보상의 방에서 거인의 심장핵이 가방에
local TICK = 1 / 20
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local Reveal = req("ReplicatedStorage/shared/lune/sim/reveal")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Schedule = req("ReplicatedStorage/shared/lune/sim/schedule")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local FirstClear = req("ReplicatedStorage/shared/lune/sim/firstClear")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local B = Weekly.boss("lavagiant")
local W = Weekly.DATA.words

-- ---- ① 자료 ----
expect(B ~= nil and not B.dev, "용암 거인은 공개됐다(dev 아님 — release를 지웠다)")
expect(B.reveal ~= nil and B.reveal.wait == 300, "출현까지 300초(5분 — 2026-11-05 사용자 \"1시간 말고 5분으로 하자 바로 퍼클할수있게\")")
expect(#B.reveal.marks >= 5 and B.reveal.marks[1] == B.reveal.wait, "알림의 때 — 5분 전부터")
expect(#B.reveal.lines >= 6, "떡밥의 말이 여럿")
local wq = Quests.def(B.quest)
expect(wq ~= nil and wq.playable and wq.reveal == "lavagiant", "보스 퀘스트는 받을 수 있는 퀘스트 · 출현을 기다린다")
expect(B.first and B.first.parties == 3, "최초 격파 세 파티")

-- ---- ② 셈 ----
Reveal.at = {}
eq(Reveal.open("lavagiant", 1000), false, "출현 시각을 모르면 닫혀 있다")
eq(Reveal.open("shadowarcher", 1000), true, "출현을 기다리지 않는 보스는 늘 열려 있다")
Reveal.at.lavagiant = 5000
eq(Reveal.open("lavagiant", 4999), false, "시각 전에는 닫혀 있다")
eq(Reveal.open("lavagiant", 5000), true, "시각이 되면 열린다")
eq(Reveal.left("lavagiant", 2168), 2832, "남은 초")
eq(Reveal.clockText(2832), "47:12", "남은 시간의 글")
eq(Reveal.clockText(3725), "1:02:05", "한 시간이 넘으면 시:분:초")
eq(Reveal.markCrossed(B.reveal, B.reveal.marks[2] + 1, B.reveal.marks[2] - 1), 2, "둘째 알림의 때를 지나는 순간 = 둘째 알림")
eq(Reveal.markCrossed(B.reveal, 2999, 2998), nil, "그 밖에는 없다")
eq(Reveal.line(B.reveal, "lavagiant", #B.reveal.marks), B.reveal.lines[#B.reveal.lines], "마지막 알림 = 마지막 줄")
expect(Reveal.line(B.reveal, "lavagiant", 1) ~= "", "말이 있다")

-- ---- ③ 출현 전에 닫혀 있는 것 ----
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local now0 = Reveal.clock() -- (모듈의 시계 — 자동 검사의 가짜 시계)
Reveal.at.lavagiant = now0 + 1800
local hq = Hero.new(9, "riven")
Hero.setLevel(hq, 150, Hero.jobAt(150))
hq.quests[wq.after] = { done = true, c = {} }
eq(Quests.state(hq.quests, 150, B.quest), "locked", "출현 전: 보스 퀘스트를 받을 수 없다")
hq.quests[B.quest] = { done = true, c = {} }
local why = Weekly.canEnter(hq, B, "normal", now0)
expect(why ~= nil and string.find(why, "출현까지", 1, true) ~= nil, "출현 전: 들어가지 못한다 — " .. tostring(why))
local function schedHas(h, now)
	for _, r in Schedule.view(h, nil, now).weekly do
		if r.id == "weekly:lavagiant" or string.find(tostring(r.id), "lavagiant", 1, true) then
			return true
		end
	end
	return false
end
eq(schedHas(hq, now0), false, "출현 전: 스케줄러에 없다")
Reveal.at.lavagiant = now0 - 5
hq.quests[B.quest] = nil
eq(Quests.state(hq.quests, 150, B.quest), "open", "출현 뒤: 보스 퀘스트를 받는다")
hq.quests[B.quest] = { done = true, c = {} }
eq(Weekly.canEnter(hq, B, "normal", now0), nil, "출현 뒤: 들어간다")
eq(schedHas(hq, now0), true, "출현 뒤: 스케줄러에 생긴다")

-- ---- ④ 서버 ----
local fired, handlers = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
local published = {}
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal(), IsStudio = function() return false end })
SERVICE("MessagingService", { PublishAsync = function(_, topic, data) table.insert(published, { topic = topic, data = data }) end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names, world = {}, {}, {}
local claims = 0
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	revealClaim = function(boss, at)
		claims += 1
		local k = "reveal_" .. boss
		world[k] = world[k] or { at = at }
		return world[k].at
	end,
	firstClearGet = function(boss) return true, world["firstClear_" .. boss] or {} end,
	firstClearAdd = function(boss, entry, cap)
		local k = "firstClear_" .. boss
		local new, rank = FirstClear.add(world[k], entry, cap)
		if new then
			world[k] = new
		end
		return rank, world[k] or {}
	end,
})
Reveal.at = {}
local World = req("ServerScriptService/server/lune/modules/world")
local RS = req("ServerScriptService/server/lune/modules/reveal")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
expect(world.reveal_lavagiant ~= nil, "켜질 때 저장소에 출현 시각을 적었다")
local atRec = world.reveal_lavagiant and world.reveal_lavagiant.at or 0
expect(math.abs(atRec - (Reveal.clock() + B.reveal.wait)) <= 3, "출현 시각 = 켜진 때 + 300초")
eq(Reveal.at.lavagiant, atRec, "서버가 그 시각을 안다")
local uid = 12500
local function join(level)
	uid += 1
	local name = "용암" .. (uid % 100000)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "mooni")
	handlers.Chars(p, "enter", made.id)
	World.wake(p)
	local s = World.session(p)
	Hero.setLevel(s.hero, level, Hero.jobAt(level))
	s.hero.quests[B.quest] = { done = true, c = {} }
	World.jump(p, B.door.scene)
	s.trust, s.stale = true, nil
	s.hero.x = B.door.x
	return p, s
end
local function lastOf(p, name: string)
	local found = nil
	for _, f in fired do
		if f.player == p and f.name == name then
			found = f.args
		end
	end
	return found
end
local function countOf(p, name: string, kind: string?)
	local n = 0
	for _, f in fired do
		if f.player == p and f.name == name and (kind == nil or (typeof(f.args[1]) == "table" and f.args[1].kind == kind)) then
			n += 1
		end
	end
	return n
end
local p1, s1 = join(150)
run(1.2)
local rv = lastOf(p1, "Reveal")
expect(rv ~= nil and rv[1].at.lavagiant == atRec and typeof(rv[1].now) == "number", "화면에 출현 시각 · 서버의 지금을 보냈다(왼쪽 아래 빨간 남은 시간)")
local r0 = handlers.Week(p1, "enter", B.id, "normal", false)
expect(r0 and not r0.ok and string.find(tostring(r0.why), "출현까지", 1, true) ~= nil, "출현 전: 문 앞에서 들어가지 못한다 — " .. tostring(r0 and r0.why))
-- 떡밥: 알림의 때(4분 전)를 지나는 순간
Reveal.at.lavagiant = Reveal.clock() + B.reveal.marks[2] - 1 -- (둘째 알림의 때를 지나게)
run(2.2)
local tease = lastOf(p1, "RevealNews")
expect(tease ~= nil and tease[1].kind == "tease" and tease[1].name == "용암 거인" and typeof(tease[1].line) == "string" and tease[1].line ~= "", "4분 전 — 떡밥 알림(이 서버의 모두에게)")
local before = countOf(p1, "RevealNews", "tease")
run(3)
eq(countOf(p1, "RevealNews", "tease"), before, "알림은 그때 한 번")
-- 출현
Reveal.at.lavagiant = Reveal.clock() -- (자동 검사의 시계는 틱으로 흐르지 않는다 — 시각을 지금으로 당겨 0이 되는 순간을 본다)
run(2.5)
eq(countOf(p1, "RevealNews", "open"), 1, "0이 되면 「용암 거인 출현!」")
eq(Reveal.open("lavagiant"), true, "열렸다")
-- ⑤ 혼자 들어가 격파
local r1 = handlers.Week(p1, "enter", B.id, "normal", false)
expect(r1 and r1.ok, "출현 뒤: 혼자 들어간다 — " .. tostring(r1 and r1.why))
run(1)
local room = World.room(s1.scene)
expect(room and room.weekly ~= nil, "용암 거인의 방")
Weekly.cleared(room)
run(0.4)
local rec = world.firstClear_lavagiant
expect(rec ~= nil and #rec == 1 and #rec[1].members == 1, "혼자 격파해도 최초 격파 한 파티로 적혔다")
expect(s1.hero.titles and s1.hero.titles.fc_lavagiant, "격파한 그 자리에서 칭호 「거인을 잠재운 자」")
local fc = lastOf(p1, "FirstClear")
expect(fc ~= nil and fc[1].n == 1 and fc[1].max == 3 and fc[1].names == s1.name, "「최초 격파 1/3 — 용암 거인」 + 이름")
expect(#published >= 1 and published[#published].topic == "LuneFirstClear", "다른 서버로도 보냈다")
-- 보상의 방: 심장핵
run(Weekly.BOX.after + 0.4)
expect(Weekly.isBox(s1.scene), "보상의 방으로 옮겨졌다")
local c = SCENES.scenes[s1.scene].chest
s1.hero.x, s1.hero.y = c.x, c.y
local opened = handlers.Week(p1, "open")
expect(opened and opened.ok, "상자를 연다")
local broom = World.room(s1.scene)
local ids = {}
for id in broom.drops do
	table.insert(ids, id)
end
table.sort(ids)
for _, id in ids do
	local d = broom.drops[id]
	if d then
		s1.hero.x, s1.hero.y = d.x, d.y
		handlers.Pickup(p1, id)
	end
end
eq(Bag.count(s1.hero, "etc_fh_heart"), 1, "보상의 방에서 거인의 심장핵 하나가 가방에")
local _ = Items
local __ = RS
local ___ = claims
local ____ = W
