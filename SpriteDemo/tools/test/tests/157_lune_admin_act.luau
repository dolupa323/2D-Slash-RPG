-- 「달의 계승자」 — 관리자의 즉시 조치 · 모든 서버의 접속자(2026-11-12 사용자: "매크로 점수 내가 같은서버인유저밖에 못봐 모든유저를 확인하고 즉시 경고메시지보내고 이렇게 할수있어야해
--  경험치 쿠폰도 지급할수있어야하고 제재도 즉시할수있어야하고 깜빵에 바로 넣을수도있어야하고 날파리를 날릴수도 있어야해" · "룬의 저주 걸려있는사람 내가 풀어줄수있는기능도 있어야하고").
--  server adminCmd.luau(MemoryStore 접속자 목록 · 조치 상자 · MessagingService) · world.luau onAdmin "macroAll" · "macroAct" · World.adminApply · adminDrain
--  보는 것: ① 서버가 제 사람들을 접속자 목록에 적는다 · 「모든 서버」가 점수 높은 차례로 ② 이 서버의 사람: 경고 · 감옥 10분 · 풀기 · 룬의 저주 풀기 · 날파리 · 경험치 쿠폰 — 바로
--   ③ 접속하지 않은 사람: 조치 상자에 적고 모든 서버에 알린다 → 들어오면 바로(경고 · 감옥) · 오래된 날파리는 버린다 ④ 관리자가 아니면 듣지 않는다
local handlers = {}
local fired = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
	end,
	FireAllClients = function() end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
local published, subs = {}, {}
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
SERVICE("MessagingService", {
	PublishAsync = function(_, topic, data) table.insert(published, { topic = topic, data = data }) end,
	SubscribeAsync = function(_, topic, fn) subs[topic] = fn end,
})
local online = {} -- 가짜 정렬 지도(열쇠 → { value, sort })
SERVICE("MemoryStoreService", {
	GetSortedMap = function(_, _name)
		return {
			SetAsync = function(_, key, value, _exp, sort) online[key] = { value = value, sort = sort or 0 } end,
			RemoveAsync = function(_, key) online[key] = nil end,
			GetRangeAsync = function(_, _dir, n)
				local list = {}
				for k, v in online do
					table.insert(list, { key = k, value = v.value, sortKey = v.sort })
				end
				table.sort(list, function(a, b) return a.sortKey > b.sortKey end)
				while #list > n do
					table.remove(list)
				end
				return list
			end,
		}
	end,
})
local disk, book, gifts, admq = {}, {}, {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function() end, rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	giftAdd = function(uid, g) gifts[uid] = gifts[uid] or {}; table.insert(gifts[uid], g); return true end,
	giftTake = function(uid, name) local mine, keep = {}, {}; for _, g in gifts[uid] or {} do if g.name == name then table.insert(mine, g) else table.insert(keep, g) end end; gifts[uid] = keep; return true, mine end,
	adminQAdd = function(uid, e) admq[uid] = admq[uid] or {}; table.insert(admq[uid], e); return true end,
	adminQTake = function(uid) local all = admq[uid] or {}; admq[uid] = {}; return true, all end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local AdminCmd = req("ServerScriptService/server/lune/modules/adminCmd")
World.start()
local OWNER = 10311679477 -- 게임의 주인(관리자 — server admin.luau)
local function person(uid, name)
	return { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
end
local function enter(uid, name)
	local p = person(uid, name)
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "axion")
	handlers.Chars(p, "enter", made.id)
	local s = World.session(p)
	s.hero.tut.done = true
	return p, s, made.id
end
local pA, sA = enter(OWNER, "관리해본다")
local pT, sT = enter(8571, "조치받는이")
World.jump(pT, "hunt")
for _ = 1, 3 do
	World.tick(1.1)
end
local function act(name, kind, arg)
	return handlers.Admin(pA, "macroAct", name, kind, arg)
end

-- ① 접속자 목록
expect(online[tostring(8571)] ~= nil, "서버가 제 사람을 모든 서버의 접속자 목록에 적었다")
local all = handlers.Admin(pA, "macroAll")
expect(all and all.ok and all.live == true, "「모든 서버」를 읽었다 — " .. tostring(all and all.msg))
local found = nil
for _, r in (all and all.all) or {} do
	if r.uid == 8571 then
		found = r
	end
end
expect(found and found.n == "조치받는이" and found.here == true and found.m == "hunt", "접속자 줄: 이름 · 맵 · 이 서버")
expect(handlers.Admin(pT, "macroAll") == nil or not handlers.Admin(pT, "macroAll").ok, "관리자가 아니면 듣지 않는다")

-- ② 이 서버의 사람: 바로
local w0 = #sT.macro.saved.warns
local r = act("조치받는이", "warn")
expect(r and r.ok, "경고 — " .. tostring(r and r.msg))
eq(#sT.macro.saved.warns, w0 + 1, "경고가 계정에 남았다")
local warned = false
for _, f in fired do
	if f.name == "MacroWarn" and f.player == pT then
		warned = true
	end
end
expect(warned, "그 사람의 화면에 「운영 경고」")
r = act("조치받는이", "jail", 10)
expect(r and r.ok, "감옥 10분 — " .. tostring(r and r.msg))
local left = Macro.jailLeft(sT.macro, 1700000000 + math.floor(clock.now))
expect(left >= 590 and left <= 600, "10분 동안 갇힌다(" .. left .. "초)")
sT.loading = nil
World.tick(1.1)
eq(req("ReplicatedStorage/shared/lune/data/scenes.generated").base(sT.scene), "jail", "검정 방으로 옮겨졌다")
r = act("조치받는이", "unjail")
expect(r and r.ok, "풀기")
sT.loading = nil
World.tick(1.1)
eq(sT.scene, "hunt", "잡혀 온 사냥터로 돌아왔다")
sT.hero.runeCurse = { s = 2, n = 900, map = "hunt" }
r = act("조치받는이", "uncurse")
expect(r and r.ok and sT.hero.runeCurse == nil and sT.hero.curse == nil, "룬의 저주를 풀었다 — " .. tostring(r and r.msg))
r = act("조치받는이", "fly")
expect(r and r.ok and sT.adminFlyUntil ~= nil, "날파리 — " .. tostring(r and r.msg))
expect(World.room(sT.scene):flyOf(sT.hero.id) ~= nil, "사냥터의 그 사람에게 날파리가 붙었다")
-- 날파리 거두기(2026-11-12 사용자: "관리자로 한명 지정해서 날파리 보내면 날파리 보내는거 못멈추는데?")
r = act("조치받는이", "unfly")
expect(r and r.ok and sT.adminFlyUntil == nil, "날파리를 거뒀다 — " .. tostring(r and r.msg))
for _ = 1, 40 do
	World.tick(0.1)
end
local fly = World.room(sT.scene):flyOf(sT.hero.id)
expect(fly == nil or fly.state == "dead", "붙어 있던 날파리가 떠났다(" .. tostring(fly and fly.state) .. ")")
for _ = 1, 20 do
	World.tick(1)
end
fly = World.room(sT.scene):flyOf(sT.hero.id)
expect(fly == nil or fly.state == "dead", "다시 오지 않는다")
act("조치받는이", "fly")
r = act("조치받는이", "unjail")
expect(r and r.ok and sT.adminFlyUntil == nil, "「풀기」도 날파리를 거둔다")
local c0 = Bag.count(sT.hero, "bm_exp")
r = act("조치받는이", "coupon", 3)
expect(r and r.ok, "경험치 쿠폰 — " .. tostring(r and r.msg))
eq(Bag.count(sT.hero, "bm_exp"), c0 + 3, "바로 가방에 경험치 쿠폰 3장")
expect(not act("없는사람이름", "warn").ok, "없는 닉네임은 안 된다")
expect(not act("조치받는이", "nuke").ok, "모르는 조치는 안 된다")

-- ③ 접속하지 않은 사람: 조치 상자 → 들어오면 바로
local pO, sO, oCid = enter(8572, "나가있는이")
World.removePlayer(pO)
table.clear(published)
r = act("나가있는이", "warn")
expect(r and r.ok and #(admq[8572] or {}) == 1, "접속하지 않은 사람: 조치 상자에 적었다 — " .. tostring(r and r.msg))
expect(#published >= 1 and published[1].topic == AdminCmd.TOPIC and published[1].data.uid == 8572, "모든 서버에 알렸다")
act("나가있는이", "jail", 60)
act("나가있는이", "fly")
admq[8572][3].t -= 1000 -- (날파리는 오래돼서 버린다)
eq(#admq[8572], 3, "조치 셋이 상자에")
handlers.Ready(pO)
handlers.Chars(pO, "enter", oCid)
local sO2 = World.session(pO)
World.tick(1.1)
World.tick(1.1)
eq(#(admq[8572] or {}), 0, "들어오자 상자를 꺼냈다")
eq(#sO2.macro.saved.warns, 1, "들어오자 경고")
expect(Macro.jailed(sO2.macro, 1700000000 + math.floor(clock.now)), "들어오자 감옥(60분)")
expect(sO2.adminFlyUntil == nil, "오래된 날파리는 버렸다")
-- 다른 서버에서 「적었다」는 소식이 오면 바로 꺼낸다
act("나가있는이", "unjail") -- (이 서버에 있다 — 바로)
expect(not Macro.jailed(sO2.macro, 1700000000 + math.floor(clock.now)), "이 서버에 있으면 바로 풀린다")
local _ = sA
World.removePlayer(pT)
World.removePlayer(pO)
World.removePlayer(pA)
