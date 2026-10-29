-- 「달의 계승자」 — 만렙 최초 달성(서버의 흐름 그대로 — 2026-10-24).
--  사용자: "150만렙 맨 처음 찍는 유저 나타나면 바로 전서버에 축하알림뜨면서 레벨 랭킹 1위 실시간 박제되게 이벤트 만들고"
--  보는 것: ① 처음 만렙이 된 캐릭터가 세계 기록에 적히고 이 서버의 모두가 「FirstMax」 알림을 받는다 · 다른 서버로도 보낸다(MessagingService)
--   ② 레벨 순위판 1위가 그 캐릭터로 바로 바뀐다(점수가 더 높은 줄이 있어도) ③ 두 번째로 만렙이 된 캐릭터는 적히지 않고 알림도 없다
--   ④ 다른 서버에서 먼저 적힌 것은 그 서버의 소식(구독)으로 받아 1위에 고정된다(새로 켜진 서버 — 모듈을 다시 불러 본다)
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local TICK = 1 / 20

-- ⓪ 만렙끼리는 먼저 오른 사람이 위(2026-10-24 사용자: "만렙이면 찍은 순서대로 제일먼저찍은사람이 1위 여야하는데" — 전에는 만렙이면 경험치가 0이라 모두 같은 점수였다)
do
	local Rank = req("ReplicatedStorage/shared/lune/sim/rank")
	local HeroM = req("ReplicatedStorage/shared/lune/sim/hero")
	local M = N.MAX_LEVEL
	local t0 = os.time({ year = 2026, month = 10, day = 24, hour = 0 })
	local first = Rank.levelScore(M, 0, 1, t0)
	local second = Rank.levelScore(M, 0, 1, t0 + 60)
	local later = Rank.levelScore(M, 0, 1, t0 + 86400 * 30)
	expect(first > second and second > later, "만렙: 먼저 오른 사람의 점수가 더 크다")
	eq(Rank.levelOf(first), M, "만렙의 점수도 레벨은 만렙으로 읽힌다")
	eq(Rank.levelOf(later), M, "한 달 뒤에 오른 사람도 만렙")
	eq(Rank.valueText("level", later), "Lv." .. M, "판의 글은 그대로 Lv." .. M)
	expect(later > Rank.levelScore(M - 1, N.xpNeed(M - 1) - 1, N.xpNeed(M - 1)), "아무리 늦게 오른 만렙도 Lv." .. (M - 1) .. "보다 위")
	-- 오른 때는 캐릭터에 적히고 저장된다
	local h = HeroM.new(8801, "riven")
	HeroM.setLevel(h, M - 1)
	h.xp = 0
	HeroM.gainXp(h, N.xpNeed(M - 1) + 5)
	eq(h.level, M, "만렙에 올랐다")
	expect(typeof(h.maxAt) == "number", "오른 때가 적혔다")
	local at = h.maxAt
	HeroM.gainXp(h, 1000)
	eq(h.maxAt, at, "만렙에서 더 벌어도 오른 때는 그대로")
	local back = HeroM.unpack(8801, HeroM.pack(h))
	eq(back.maxAt, at, "저장되고 읽힌다")
	-- 저장본에서 찾은 오른 때(Rank.MAX_FIX — 2026-10-24): 강타 → 0NJ4 → 여왕
	local F = Rank.MAX_FIX
	local a1, a2, a3 = Rank.levelScore(M, 0, 1, F.c7932577222_1), Rank.levelScore(M, 0, 1, F.c9233200460_1), Rank.levelScore(M, 0, 1, F.c2995182643_1)
	expect(a1 > a2 and a2 > a3, "찾은 차례: 강타 > 0NJ4 > 여왕")
	eq(a1, 150965886, "강타의 점수(실제 순위판에 적은 값)")
	-- 2026-10-29 사용자: "여왕 캐릭터 랭킹 계속 내려가는거 작업해 원래 랭킹으로 보이게" — 옛 서버가 덮은 옛 점수(만렙 = 150,000,000)를 판을 읽을 때 올린다(Rank.fixMax)
	local raised = {}
	local function raise(key, score)
		table.insert(raised, { key, score })
	end
	local QUEEN = "c2995182643_1"
	local rows = {
		{ key = "c111_1", score = Rank.levelScore(M, 0, 1, F[QUEEN] + 86400) }, -- 하루 뒤에 만렙
		{ key = "c222_1", score = Rank.levelScore(M, 0, 1, F[QUEEN] + 3600) }, -- 한 시간 뒤에 만렙
		{ key = QUEEN, score = M * 1000000 }, -- 옛 점수
	}
	table.sort(rows, function(x, y) return x.score > y.score end)
	eq(rows[3].key, QUEEN, "고치기 전: 여왕이 뒤에 오른 두 사람보다 아래")
	Rank.fixMax(rows, raise, false)
	eq(rows[1].key, QUEEN, "고친 뒤: 먼저 오른 여왕이 위")
	eq(rows[1].score, a3, "여왕의 점수 = 찾아 둔 오른 때의 점수")
	eq(#raised, 1, "저장소에는 낮았던 그 줄만 올린다")
	eq(raised[1] and raised[1][1], QUEEN, "올린 열쇠")
	raised = {}
	Rank.fixMax(rows, raise, false)
	eq(#raised, 0, "이미 맞으면 다시 쓰지 않는다")
	Rank.fixMax({}, raise, true)
	eq(#raised, 3, "서버가 처음 읽을 때는 판에 안 보이는 셋도 올려 본다(저장소는 있는 줄만 · 낮을 때만 올린다)")
end

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
local published, listeners = {}, {}
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("MessagingService", {
	PublishAsync = function(_, topic, data)
		table.insert(published, { topic = topic, data = data })
	end,
	SubscribeAsync = function(_, topic, fn)
		listeners[topic] = fn
	end,
})
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names, world, ranks = {}, {}, {}, { level = {}, power = {}, robux = {} }
local info = {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function(board, key, score) ranks[board][key] = score end,
	rankRaise = function(board, key, score) if ranks[board][key] and ranks[board][key] < score then ranks[board][key] = score end end,
	rankRemove = function(board, key) ranks[board][key] = nil end,
	rankTop = function(board, n)
		local rows = {}
		for key, score in ranks[board] do
			table.insert(rows, { key = key, score = score })
		end
		table.sort(rows, function(a, b) return a.score > b.score end)
		while #rows > n do
			table.remove(rows)
		end
		return rows
	end,
	rankInfoSet = function(key, i) info[key] = i end,
	rankInfoGet = function(key) return info[key] end,
	rankInfoRemove = function(key) info[key] = nil end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	firstMaxGet = function() return world.firstMax end,
	firstMaxClaim = function(rec)
		if world.firstMax then
			return false, world.firstMax
		end
		world.firstMax = rec
		return true, rec
	end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local function join(uid, name, cls)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, cls)
	handlers.Chars(p, "enter", made.id)
	World.jump(p, "town")
	return p, World.session(p)
end
local function got(p, what)
	local list = {}
	for _, e in sent do
		if e.name == what and e.player == p then
			table.insert(list, e.args[1])
		end
	end
	return list
end
local function levelTop(p)
	local boards = handlers.Rank(p)
	return boards and boards.level or {}
end

local pa, a = join(8801, "첫만렙", "axion")
local pb, b = join(8802, "구경꾼", "mooni")
local pc, c = join(8803, "높은점수", "riven")
run(1)
-- 높은점수: 레벨 판에 만렙의 경험치까지 찬 점수로 먼저 올라가 있다(그래도 박제가 1위)
ranks.level["c8803_1"] = N.MAX_LEVEL * 1000000 + 999999
info["c8803_1"] = { name = "높은점수", class = "riven" }

-- ⓪-2 이미 만렙이던 캐릭터가 들어오기만 한 것은 적지 않는다(2026-10-24 사용자: "만렙 달성 알림같은거 이상한사람으로 뜨면 안된다")
c.hero.level = N.MAX_LEVEL
run(1.5)
run(0.2)
expect(world.firstMax == nil, "이미 만렙이던 캐릭터(이 접속에서 오른 것이 아니다)는 처음으로 적히지 않는다")
eq(#got(pb, "FirstMax"), 0, "그때는 알림도 없다")
c.hero.level = N.MAX_LEVEL - 1
-- ① 처음 만렙(이 접속에서 경험치로 올랐다)
local HeroS = req("ReplicatedStorage/shared/lune/sim/hero")
HeroS.setLevel(a.hero, N.MAX_LEVEL - 1)
a.hero.xp = 0
HeroS.gainXp(a.hero, N.xpNeed(N.MAX_LEVEL - 1) + 1)
eq(a.hero.level, N.MAX_LEVEL, "경험치로 만렙이 됐다")
run(1.5)
run(0.2)
expect(world.firstMax ~= nil and world.firstMax.name == "첫만렙", "세계 기록에 첫만렙이 적혔다")
local na, nb = got(pa, "FirstMax"), got(pb, "FirstMax")
eq(#na, 1, "만렙이 된 사람도 축하 알림을 받는다")
eq(#nb, 1, "같은 서버의 다른 사람도 축하 알림을 받는다")
eq(nb[1] and nb[1].name, "첫만렙", "알림의 이름")
eq(nb[1] and nb[1].level, N.MAX_LEVEL, "알림의 레벨")
local pub = nil
for _, m in published do
	if m.topic == "LuneFirstMax" then
		pub = m.data
	end
end
expect(pub ~= nil and pub.name == "첫만렙", "다른 서버로도 보냈다(MessagingService)")
-- ② 레벨 판 1위 박제
local top = levelTop(pb)
eq(top[1] and top[1].name, "첫만렙", "레벨 판 1위 = 첫만렙(점수가 더 높은 줄이 있어도)")
eq(top[1] and top[1].value, ("Lv.%d"):format(N.MAX_LEVEL), "1위의 값")
expect(top[1] and top[1].first == true, "박제된 줄이라는 표시")
local seen = 0
for _, row in top do
	if row.name == "첫만렙" then
		seen += 1
	end
end
eq(seen, 1, "첫만렙은 판에 한 번만")
eq(top[2] and top[2].name, "높은점수", "그다음은 점수 차례")

-- ③ 두 번째 만렙
c.hero.level = N.MAX_LEVEL
run(1.5)
run(0.2)
eq(world.firstMax.name, "첫만렙", "두 번째 만렙은 적히지 않는다")
eq(#got(pb, "FirstMax"), 1, "두 번째 만렙에는 알림이 없다")
eq(levelTop(pb)[1].name, "첫만렙", "1위는 그대로")

-- ③-2 레벨 순위 1위 선물 「백금 사슴」(2026-10-25 사용자: "랭킹 1등으로 한사람만주는거야 백금사슴"): 처음 만렙(1위)의 계정만 받는다 — 두 번째 만렙 · 만렙 아닌 사람은 받지 않는다
run(1.2)
expect(a.acct.bm.mounts.mount_deer_gold == true, "1위(첫만렙)의 계정에 백금 사슴이 들어왔다")
expect(table.find(got(pa, "CashGot"), "mount_deer_gold") ~= nil, "1위의 화면에 알렸다")
expect(a.acct.bm.mounts.mount_deer_silver and a.acct.bm.mounts.mount_deer_bronze, "1위는 실버 · 동색 사슴도 받는다(2026-10-26 사용자 \"1위는 금은동 다주고\")")
eq(a.acct.bm.mount, "mount_deer_gold", "고른 탈것이 없었으면 가장 높은 백금 사슴을 고른다")
expect(not c.acct.bm.mounts.mount_deer_gold, "두 번째 만렙(높은점수)은 받지 않는다")
expect(not b.acct.bm.mounts.mount_deer_gold, "만렙이 아닌 사람(구경꾼)은 받지 않는다")
run(1.2)
local giftTold = 0
for _, k in got(pa, "CashGot") do
	if k == "mount_deer_gold" then
		giftTold += 1
	end
end
eq(giftTold, 1, "한 번만 준다")
-- ③-3 레벨 순위 2위 · 3위 선물(2026-10-26 사용자: "만렙 두번째, 세번째로 찍은 사람들한테 … 2등 실버사슴 3등 동색사슴"): 만렙에 오른 차례(세계 기록 maxTen)의 둘째 · 셋째의 계정만
do
	local TitleServer = req("ServerScriptService/server/lune/modules/titles")
	local Rank = req("ReplicatedStorage/shared/lune/sim/rank")
	TitleServer.reset({ { key = Rank.charKey(pa.UserId, a.cid), at = 1 }, { key = Rank.charKey(pc.UserId, c.cid), at = 2 }, { key = Rank.charKey(pb.UserId, b.cid), at = 3 } })
	run(1.2)
	local m = function(s0) return s0.acct.bm.mounts end
	-- (2026-10-26 사용자: "1위는 금은동 다주고 2위는 은 동 주고 3위는 동 주고")
	expect(m(c).mount_deer_silver == true and m(c).mount_deer_bronze == true and not m(c).mount_deer_gold, "2위(둘째로 만렙)는 실버 · 동색 사슴(백금은 아니다)")
	expect(m(b).mount_deer_bronze == true and not m(b).mount_deer_silver and not m(b).mount_deer_gold, "3위(셋째로 만렙)는 동색 사슴만")
	expect(m(a).mount_deer_gold and m(a).mount_deer_silver and m(a).mount_deer_bronze, "1위는 셋 다")
	local told = got(pc, "CashGot")
	expect(table.find(told, "mount_deer_silver") ~= nil and table.find(told, "mount_deer_bronze") ~= nil, "2위의 화면에 받은 둘을 알렸다")
	run(1.2)
	local again = 0
	for _, k in got(pc, "CashGot") do
		if k == "mount_deer_silver" then
			again += 1
		end
	end
	eq(again, 1, "2위 선물도 한 번만")
end

-- ④ 다른 서버에서 먼저 적힌 것(새로 켜진 서버): 소식을 받으면 1위에 고정 · 이 서버의 모두에게 알림
local FirstMax = req("ServerScriptService/server/lune/modules/firstMax")
expect(FirstMax.get() ~= nil, "이 서버도 기록을 안다")
expect(listeners.LuneFirstMax ~= nil, "다른 서버의 소식을 듣고 있다")
World.removePlayer(pa)
World.removePlayer(pb)
World.removePlayer(pc)
