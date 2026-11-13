-- 「달의 계승자」 — 만렙 최초 달성(서버의 흐름 그대로 — 2026-10-24).
--  사용자: "150만렙 맨 처음 찍는 유저 나타나면 바로 전서버에 축하알림뜨면서 레벨 랭킹 1위 실시간 박제되게 이벤트 만들고"
--  보는 것: ① 처음 만렙이 된 캐릭터가 세계 기록에 적히고 이 서버의 모두가 「FirstMax」 알림을 받는다 · 다른 서버로도 보낸다(MessagingService)
--   ② 레벨 순위판(2026-11-11 저녁부터 처음 150의 1위 고정이 없다 — 레벨 차례 · Lv.150끼리는 찍은 차례) ③ 두 번째로 만렙이 된 캐릭터는 적히지 않고 알림도 없다
--   ④ 다른 서버에서 먼저 적힌 것은 그 서버의 소식(구독)으로 받아 1위에 고정된다(새로 켜진 서버 — 모듈을 다시 불러 본다)
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local TICK = 1 / 20

-- ⓪ 만렙끼리는 먼저 오른 사람이 위(2026-10-24 사용자: "만렙이면 찍은 순서대로 제일먼저찍은사람이 1위 여야하는데" — 전에는 만렙이면 경험치가 0이라 모두 같은 점수였다)
do
	local Rank = req("ReplicatedStorage/shared/lune/sim/rank")
	local HeroM = req("ReplicatedStorage/shared/lune/sim/hero")
	local M = N.MAX_LEVEL
	local C = N.LEVEL_CAP
	local t0 = os.time({ year = 2026, month = 10, day = 24, hour = 0 })
	-- 2026-11-11 벽을 풀며: 「만렙끼리 먼저 오른 차례」는 이제 Lv.200(LEVEL_CAP)의 것(capAt) · 150 ~ 199는 다른 레벨처럼 레벨 + 경험치의 비율
	local first = Rank.levelScore(C, 0, 1, nil, t0)
	local second = Rank.levelScore(C, 0, 1, nil, t0 + 60)
	local later = Rank.levelScore(C, 0, 1, nil, t0 + 86400 * 30)
	expect(first > second and second > later, "Lv.200: 먼저 오른 사람의 점수가 더 크다")
	eq(Rank.levelOf(first), C, "Lv.200의 점수도 레벨은 200으로 읽힌다")
	eq(Rank.levelOf(later), C, "한 달 뒤에 오른 사람도 200")
	eq(Rank.valueText("level", later), "Lv." .. C, "판의 글은 그대로 Lv." .. C)
	expect(later > Rank.levelScore(C - 1, N.xpNeed(C - 1) - 1, N.xpNeed(C - 1)), "아무리 늦게 오른 200도 Lv." .. (C - 1) .. "보다 위")
	-- (2026-11-11 저녁 사용자: "151렙이 있는데 랭킹 1등이 안되는데? 만렙 풀리면 이제는 200기준으로 정렬되어야지 150동렙일때만 찍은순서로 되는거고")
	expect(Rank.levelScore(M + 1, 0, N.xpNeed(M + 1)) > Rank.levelScore(M, N.xpNeed(M) - 1, N.xpNeed(M), Rank.MAX_EPOCH), "Lv.151은 가장 먼저 찍은 Lv.150보다도 위")
	expect(Rank.levelScore(M, N.xpNeed(M) * 0.2, N.xpNeed(M), t0 - 86400) > Rank.levelScore(M, N.xpNeed(M) * 0.6, N.xpNeed(M), t0), "Lv.150끼리는 먼저 찍은 사람이 위(경험치의 비율이 아니다)")
	eq(Rank.levelOf(Rank.levelScore(M, 0, 1, t0)), M, "Lv.150의 점수도 레벨은 150으로 읽힌다")
	expect(Rank.levelScore(M + 2, N.xpNeed(M + 2) * 0.5, N.xpNeed(M + 2)) > Rank.levelScore(M + 2, N.xpNeed(M + 2) * 0.1, N.xpNeed(M + 2)), "Lv.151 ~ 199는 같은 레벨이면 경험치가 많은 쪽이 위")
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
	HeroM.setLevel(h, C - 1)
	h.xp = 0
	HeroM.gainXp(h, N.xpNeed(C - 1) + 5)
	eq(h.level, C, "Lv.200에 올랐다")
	expect(typeof(h.capAt) == "number", "Lv.200에 오른 때(capAt)가 적혔다(2026-11-11)")
	eq(HeroM.unpack(8801, HeroM.pack(h)).capAt, h.capAt, "capAt도 저장되고 읽힌다")
	-- Rank.fixMax(2026-10-29 — 옛 서버가 덮은 「150 + 오른 때」 점수를 올린다): 2026-11-11 낮에 멈췄다가 저녁에 다시 켰다(Lv.150끼리는 다시 오른 때의 차례) — 151 위로 오른 줄은 그대로
	local raised = {}
	Rank.fixMax({ { key = "c2995182643_1", score = M * 1000000 }, { key = "c7932577222_1", score = (M + 1) * 1000000 } }, function(key, score) table.insert(raised, { key, score }) end, true)
	local byKey = {}
	for _, r in raised do byKey[r[1]] = r[2] end
	eq(byKey.c2995182643_1, Rank.levelScore(M, 0, 1, Rank.MAX_FIX.c2995182643_1), "fixMax: 낮게 적힌 150을 찾아 둔 오른 때의 점수로 올린다")
	eq(byKey.c7932577222_1, nil, "이미 151로 올라간 줄은 건드리지 않는다")
	eq(byKey.c9233200460_1, Rank.levelScore(M, 0, 1, Rank.MAX_FIX.c9233200460_1), "판에 안 보이는 것도 올려 본다(all — 저장소는 있는 줄만 올린다)")
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
local disk, names, world, ranks = {}, {}, {}, { level = {}, power = {}, robux = {}, macro = {} } -- (macro = 매크로 기록의 순위 — 2026-11-09 macroGuard가 지운다)
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
-- 높은점수: 레벨 판에 Lv.151로 먼저 올라가 있다(2026-11-11 저녁부터 처음 150보다 위) · 늦은만렙: 첫만렙보다 하루 늦게 150을 찍은 줄
ranks.level["c8803_1"] = (N.MAX_LEVEL + 1) * 1000000
info["c8803_1"] = { name = "높은점수", class = "riven" }
ranks.level["c8899_1"] = req("ReplicatedStorage/shared/lune/sim/rank").levelScore(N.MAX_LEVEL, 0, 1, os.time() + 86400)
info["c8899_1"] = { name = "늦은만렙", class = "mooni" }

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
-- ② 레벨 판: 레벨 차례(처음 150의 1위 고정 없음 — 2026-11-11 저녁 사용자 "151렙이 있는데 랭킹 1등이 안되는데?") · Lv.150끼리는 먼저 찍은 차례
local top = levelTop(pa) -- (첫만렙이 순위를 열면 새 점수가 판에 올라간다 — 게임에서도 열 때 · 저장할 때 올린다)
eq(top[1] and top[1].name, "높은점수", "레벨 판 1위 = Lv.151(처음 150보다 위)")
eq(top[1] and top[1].value, ("Lv.%d"):format(N.MAX_LEVEL + 1), "1위의 값")
expect(top[1] and not top[1].first, "고정된 줄이 아니다")
eq(top[2] and top[2].name, "첫만렙", "2위 = 첫만렙(Lv.150 가운데 먼저 찍었다)")
eq(top[3] and top[3].name, "늦은만렙", "3위 = 늦게 찍은 Lv.150")
local seen = 0
for _, row in top do
	if row.name == "첫만렙" then
		seen += 1
	end
end
eq(seen, 1, "첫만렙은 판에 한 번만")
-- ②-2 접속하지 않은 사람의 줄도 저장본으로 다시 셈한다(2026-11-11 저녁 사용자: "그니까 랭킹 누가 접속을 안해도 갱신이 되어야하는거아니야?")
do
	local HeroO = req("ReplicatedStorage/shared/lune/sim/hero")
	local RankO = req("ReplicatedStorage/shared/lune/sim/rank")
	local off = HeroO.new(8850, "reaper")
	HeroO.setLevel(off, N.MAX_LEVEL + 1)
	off.xp = 0
	disk[8850] = { chars = { { id = 1, name = "쉬는사람", class = "reaper", made = 0, hero = HeroO.pack(off) } } }
	ranks.level["c8850_1"] = RankO.levelScore(N.MAX_LEVEL, 0, 1, os.time() + 86400 * 2) -- 옛 셈으로 적힌 줄(Lv.150 · 늦게 찍은 것) — 지금 저장본은 Lv.151
	info["c8850_1"] = { name = "쉬는사람", class = "reaper" }
	-- 판에 안 보이는 저장본 없는 줄(지운 캐릭터 등)은 그대로
	ranks.level["c8851_1"] = RankO.levelScore(N.MAX_LEVEL - 3, 0, 100)
	local keep8851 = ranks.level["c8851_1"]
	run(61) -- 판을 다시 읽을 때가 지났다(60초)
	levelTop(pb)
	run(0.2)
	eq(ranks.level["c8850_1"], RankO.levelScore(N.MAX_LEVEL + 1, 0, HeroO.xpNeed(off)), "들어오지 않은 쉬는사람의 줄이 저장본의 Lv.151로 고쳐 적혔다")
	eq(ranks.level["c8851_1"], keep8851, "저장본이 없는 줄은 건드리지 않는다")
	local t2 = levelTop(pb)
	local at = 0
	for i, row in t2 do
		if row.name == "쉬는사람" then
			at = i
		end
	end
	expect(at >= 1 and at <= 2 and t2[at].value == ("Lv.%d"):format(N.MAX_LEVEL + 1), "판에서도 Lv.151로 위에 보인다")
	local before = ranks.level["c8850_1"]
	ranks.level["c8850_1"] = 5 -- 다시 틀어져도 30분 안에는 다시 읽지 않는다(저장소 읽기의 몫)
	run(61)
	levelTop(pb)
	run(0.2)
	eq(ranks.level["c8850_1"], 5, "같은 줄은 30분 안에 다시 읽지 않는다")
	ranks.level["c8850_1"] = before
	-- 다른 서버에서 놀고 있는 사람: 판의 줄(그 서버가 방금 적은 Lv.152 · 경험치 90%)이 저장본(Lv.152 · 10% — 조금 늦은 것)보다 새것이면 덮지 않는다 · 레벨이 낮아지는 쪽으로도 고치지 않는다
	local busy = HeroO.new(8852, "axion")
	HeroO.setLevel(busy, N.MAX_LEVEL + 2)
	busy.xp = math.floor(HeroO.xpNeed(busy) * 0.1)
	disk[8852] = { chars = { { id = 1, name = "딴서버", class = "axion", made = 0, hero = HeroO.pack(busy) } } }
	local fresh = RankO.levelScore(N.MAX_LEVEL + 2, HeroO.xpNeed(busy) * 0.9, HeroO.xpNeed(busy))
	ranks.level["c8852_1"] = fresh
	info["c8852_1"] = { name = "딴서버", class = "axion" }
	local lowSaved = HeroO.new(8853, "mooni")
	HeroO.setLevel(lowSaved, N.MAX_LEVEL + 1)
	lowSaved.xp = 0
	disk[8853] = { chars = { { id = 1, name = "되돌림", class = "mooni", made = 0, hero = HeroO.pack(lowSaved) } } }
	local higher = RankO.levelScore(N.MAX_LEVEL + 3, 0, 100)
	ranks.level["c8853_1"] = higher
	info["c8853_1"] = { name = "되돌림", class = "mooni" }
	run(61)
	levelTop(pb)
	run(0.2)
	eq(ranks.level["c8852_1"], fresh, "같은 레벨(152)의 경험치는 늦은 저장본으로 덮지 않는다")
	eq(ranks.level["c8853_1"], higher, "저장본의 레벨이 더 낮으면 고치지 않는다")
end

-- ③ 두 번째 만렙
c.hero.level = N.MAX_LEVEL
run(1.5)
run(0.2)
eq(world.firstMax.name, "첫만렙", "두 번째 만렙은 적히지 않는다")
eq(#got(pb, "FirstMax"), 1, "두 번째 만렙에는 알림이 없다")

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
	-- ③-4 마을의 랭킹 석상(2026-11-12 사용자: "석상은 150레벨때 찍은 순서대로 랭킹 1,2,3등이 박제되는거야 200확장으로인해서 랭킹변동된다고 석상사람이 바뀌면 안되지"):
	--  World.statueRows = 1위 처음 만렙 · 2 · 3위 만렙 열 사람에서 1위를 뺀 차례 — 레벨 판의 차례와 상관없다
	local function keysOf(rows)
		local out = {}
		for i = 1, 3 do
			out[i] = if rows[i] then rows[i].key else "-"
		end
		return table.concat(out, ",")
	end
	local ka, kb, kc = Rank.charKey(pa.UserId, a.cid), Rank.charKey(pb.UserId, b.cid), Rank.charKey(pc.UserId, c.cid)
	TitleServer.reset({ { key = ka, name = "a", class = a.hero.class, at = 1 }, { key = kc, name = "c", class = c.hero.class, at = 2 }, { key = kb, name = "b", class = b.hero.class, at = 3 } }) -- (기록의 꼴 그대로 — 직업이 있다)
	eq(keysOf(World.statueRows()), table.concat({ ka, kc, kb }, ","), "석상 = Lv.150에 오른 차례(첫만렙 · 둘째 · 셋째)")
	ranks.level[kb] = 9e15 -- 셋째로 만렙이 된 사람이 레벨 판의 1위가 됐다(Lv.200)
	eq(keysOf(World.statueRows()), table.concat({ ka, kc, kb }, ","), "레벨 판이 바뀌어도 석상은 그대로")
	eq(World.statueRows()[1].class, a.hero.class, "석상의 직업 = 기록의 직업")
	-- 열 사람의 기록에 처음 만렙이 빠져 있어도(기록이 나중에 생겼다) 1위는 처음 만렙 · 그다음 차례로
	TitleServer.reset({ { key = kc, name = "c", class = c.hero.class, at = 2 }, { key = kb, name = "b", class = b.hero.class, at = 3 } })
	eq(keysOf(World.statueRows()), table.concat({ ka, kc, kb }, ","), "열 사람에 1위가 없어도 같은 차례")
	TitleServer.reset({ { key = ka, name = "a", class = a.hero.class, at = 1 } })
	eq(keysOf(World.statueRows()), table.concat({ ka, "-", "-" }, ","), "아직 셋이 안 됐으면 빈 자리는 받침대만(false)")
end

-- ④ 다른 서버에서 먼저 적힌 것(새로 켜진 서버): 소식을 받으면 1위에 고정 · 이 서버의 모두에게 알림
local FirstMax = req("ServerScriptService/server/lune/modules/firstMax")
expect(FirstMax.get() ~= nil, "이 서버도 기록을 안다")
expect(listeners.LuneFirstMax ~= nil, "다른 서버의 소식을 듣고 있다")
World.removePlayer(pa)
World.removePlayer(pb)
World.removePlayer(pc)
