-- 「달의 계승자」 — 계정의 잠금: 같은 계정이 두 서버에 동시에 들어와 저장을 서로 덮어쓰지 못하게(아이템 복사를 막는다).
--  server/lune/modules/store.luau의 Store.lock · unlock, world.luau의 addPlayer · saveAll · removePlayer · stop.

-- ---- 1) 저장소의 잠금(가짜 DataStore 위에서 — 두 서버인 척한다: Store.JOB) ----
local data = {}
local fake = {
	GetAsync = function(_, key)
		return data[key]
	end,
	SetAsync = function(_, key, value)
		data[key] = value
	end,
	UpdateAsync = function(_, key, fn)
		local value = fn(data[key])
		if value ~= nil then
			data[key] = value
		end
	end,
}
SERVICE("DataStoreService", {
	GetDataStore = function()
		return fake
	end,
	GetOrderedDataStore = function()
		return fake
	end,
})
local Store = req("ServerScriptService/server/lune/modules/store")
expect(Store.LOCK_TTL >= 120 and Store.LOCK_TTL <= 300, "잠금은 새로 고치는 간격(60초)의 두 배를 넘겨야 죽은 것으로 본다 " .. Store.LOCK_TTL)
Store.JOB = "서버A"
expect(Store.lock(7) == true, "아무도 잡지 않은 계정은 잡는다")
local t0 = data.lock_7 and data.lock_7.at -- 서버의 시계(검사에서는 가짜 시계)로 잡은 때
expect(data.lock_7 ~= nil and data.lock_7.job == "서버A" and typeof(t0) == "number" and t0 > 0, "누가 언제 잡았는지 적힌다")
expect(Store.lock(7) == true, "제가 잡은 것은 다시 잡는다(새로 고친다)")
Store.JOB = "서버B"
expect(Store.lock(7) == false, "다른 서버가 잡고 있으면 못 잡는다")
eq(data.lock_7.job, "서버A", "잠금은 그대로 A의 것이다")
Store.unlock(7)
eq(data.lock_7.job, "서버A", "남의 잠금은 풀지 못한다")
expect(data.lock_7.at == t0, "남의 잠금의 시간도 건드리지 않는다")
-- A가 죽었다(새로 고치지 않은 지 오래다): B가 넘겨받는다
data.lock_7.at = t0 - Store.LOCK_TTL - 1
expect(Store.lock(7) == true, "오래 새로 고쳐지지 않은 잠금은 넘겨받는다")
eq(data.lock_7.job, "서버B", "이제 B의 것이다")
Store.JOB = "서버A"
expect(Store.lock(7) == false, "되살아난 A는 못 잡는다(저장하면 안 된다)")
-- B가 나간다: 풀고 나면 A가 바로 잡는다
Store.JOB = "서버B"
Store.unlock(7)
expect(data.lock_7.at == 0, "푼 잠금은 지난 것으로 적힌다")
Store.JOB = "서버A"
expect(Store.lock(7) == true, "풀린 계정은 바로 잡는다")
-- 계정마다 따로다
Store.JOB = "서버B"
expect(Store.lock(8) == true and Store.lock(7) == false, "다른 계정의 잠금은 서로 상관없다")
Store.JOB = nil

-- ---- 2) 서버: 잠긴 계정은 읽지 않고 내보낸다 · 저장하기 전에 다시 본다 · 나갈 때 푼다 ----
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function() end,
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
local free = {} -- [계정] = 이 서버가 잡을 수 있는가(false = 다른 서버의 것)
local asked, saved, unlocked = {}, {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function(id)
		asked[id] = (asked[id] or 0) + 1
		return free[id] ~= false
	end,
	unlock = function(id)
		unlocked[id] = (unlocked[id] or 0) + 1
	end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, value) disk[id] = value; saved[id] = (saved[id] or 0) + 1; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function person(id: number)
	local p = { UserId = id, Name = "잠금" .. id, attrs = {}, kicked = nil }
	p.SetAttribute = function(self, k, v) self.attrs[k] = v end
	p.Kick = function(self, text) self.kicked = text end
	return p
end
-- (가) 다른 서버가 잡고 있는 계정: 여러 번 물어 보고 내보낸다. 읽지도 저장하지도 않는다
local pa = person(5001)
free[5001] = false
-- 들어오는 것은 잠금이 풀리기를 기다린다(검사에서는 가짜 시계를 흘려보낸다)
local done, got = false, "?"
task.spawn(function()
	got = handlers.Ready(pa)
	done = true
end)
advance(40)
expect(done, "기다리다가 끝난다")
eq(got, nil, "잠긴 계정은 들어오지 못한다")
expect(asked[5001] ~= nil and asked[5001] >= 3, "앞 서버가 잠금을 풀기를 여러 번 기다려 본다 " .. tostring(asked[5001]))
expect(typeof(pa.kicked) == "string" and string.find(pa.kicked, "다른 서버", 1, true) ~= nil, "까닭을 알리고 내보낸다")
eq(World.session(pa).acct, nil, "계정을 읽지 않았다")
eq(handlers.Chars(pa, "create", "잠금5001", "axion"), nil, "캐릭터도 만들지 못한다")
World.saveAll(false)
World.removePlayer(pa)
eq(saved[5001], nil, "잠긴 계정은 저장하지 않는다(다른 서버의 저장을 덮어쓰지 않는다)")
eq(unlocked[5001], nil, "남의 잠금을 풀지도 않는다")
-- (나) 보통: 잡고 들어온다 → 저장할 때마다 새로 고친다 → 나갈 때 저장하고 푼다
local pb = person(5002)
local sel = handlers.Ready(pb)
expect(sel ~= nil and sel.select ~= nil and pb.kicked == nil, "잠기지 않은 계정은 들어온다")
local made = handlers.Chars(pb, "create", "잠금5002", "axion")
expect(handlers.Chars(pb, "enter", made.id) ~= nil, "캐릭터로 들어온다")
local before = asked[5002]
World.session(pb).dirty = true
World.saveAll(true)
expect(asked[5002] > before, "저장하기 전에 잠금을 새로 고친다")
expect((saved[5002] or 0) >= 1, "잠금이 있으면 저장한다")
-- (다) 잠금을 잃었다(이 서버가 오래 멈춰 있어 다른 서버가 넘겨받았다): 저장하지 않고 내보낸다
local was = saved[5002]
free[5002] = false
World.session(pb).dirty = true
World.saveAll(true)
eq(saved[5002], was, "잠금을 잃었으면 저장하지 않는다(더 새로운 저장을 덮어쓰지 않는다)")
expect(typeof(pb.kicked) == "string", "내보낸다")
World.removePlayer(pb)
eq(saved[5002], was, "나갈 때에도 저장하지 않는다")
eq(unlocked[5002], nil, "잃은 잠금을 풀지 않는다")
-- (라) 보통으로 나가기: 저장한 뒤에 푼다 · 서버가 닫힐 때에도
local pc = person(5003)
handlers.Ready(pc)
local m3 = handlers.Chars(pc, "create", "잠금5003", "riven")
handlers.Chars(pc, "enter", m3.id)
World.removePlayer(pc)
expect((saved[5003] or 0) >= 1 and unlocked[5003] == 1, "나갈 때 저장하고 잠금을 푼다")
local pd = person(5004)
handlers.Ready(pd)
local m4 = handlers.Chars(pd, "create", "잠금5004", "mooni")
handlers.Chars(pd, "enter", m4.id)
World.stop()
expect((saved[5004] or 0) >= 1 and unlocked[5004] == 1, "서버가 닫힐 때 저장하고 잠금을 푼다")
