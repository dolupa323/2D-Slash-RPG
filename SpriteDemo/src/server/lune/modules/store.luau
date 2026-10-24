-- 저장소(DataStore). 게임 규칙은 모른다 — 숫자와 글로 된 표를 읽고 쓸 뿐이다(저장 꼴은 sim/account.luau · sim/hero.luau의 pack · unpack).
--  셋을 다룬다:
--   계정(LuneAccount_v1, 열쇠 acct_<사람 번호>) = 그 사람의 캐릭터들과 같이 쓰는 창고. 한 열쇠에 통째로 적는다 — 캐릭터와 창고가 어긋나지 않게.
--   이름 장부(LuneNames_v1, 열쇠 = 이름) = 그 이름을 가진 사람. 캐릭터의 이름은 겹치지 않는다(사용자 2026-10-10: "중복확인을하고") — UpdateAsync로 먼저 적은 사람이 갖는다.
--   예전 저장(LuneHero_v1, 열쇠 hero_<사람 번호>) = 계정이 생기기 전의 캐릭터 하나. 읽기만 한다(계정으로 옮긴 뒤에도 지우지 않고 그대로 둔다).
--  DataStore 호출은 몇 번 다시 해 본다. Studio에서 API 접근이 꺼져 있으면 메모리에만 담아 둔다(Play를 끄면 사라진다 — 그때는 경고를 한 번 낸다).
--  아직 하지 않은 것: 같은 계정이 두 서버에 동시에 들어왔을 때의 잠금(여럿이 하는 단계에서 넣는다).
local DataStoreService = game:GetService("DataStoreService")
-- 메모리 모드(offline)는 Studio에서만(2026-10-18 검토): 라이브 서버에서 한 번 읽기에 실패했다고 서버 전체가 메모리에만 저장하면 모두의 진행을 잃고 ·
--  새로 들어온 사람은 빈 계정을 보고 · 이름 장부가 서버마다 따로 놀았다. 라이브에서는 그때그때 실패를 알리고(부른 쪽이 들여보내지 않는다) 다음에 다시 해 본다
local function studio(): boolean
	local ok, yes = pcall(function()
		return game:GetService("RunService"):IsStudio()
	end)
	return ok and yes == true
end

local NAME = { account = "LuneAccount_v1", names = "LuneNames_v1", old = "LuneHero_v1", rankInfo = "LuneRankInfo_v1", market = "LuneMarket_v2", world = "LuneWorld_v1" } -- world = 세계의 기록(만렙 최초 달성 — 2026-10-24)
local RANK = { level = "LuneRankLevel_v1", power = "LuneRankPower_v1", robux = "LuneRankRobux_v1" } -- 순위판(OrderedDataStore): 열쇠 → 점수
local RETRIES = 3
local WAIT = 1

local Store = {}

local stores = {}
local memory = { account = {}, names = {}, market = {}, world = {} } -- DataStore를 못 쓸 때의 임시 저장
local offline = false

local function getStore(which: string)
	if stores[which] or offline then
		return stores[which]
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(NAME[which])
	end)
	if ok then
		stores[which] = result
	elseif studio() then
		offline = true
		warn("[lune] 저장소를 열지 못해 메모리에만 저장한다: " .. tostring(result))
	else
		warn("[lune] 저장소를 열지 못했다(다음에 다시 해 본다): " .. tostring(result))
	end
	return stores[which]
end

local function try(fn)
	local last
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		last = result
		if attempt < RETRIES then
			task.wait(WAIT)
		end
	end
	return false, last
end

-- 읽는다. 돌려주는 것: 읽었는가, 읽은 값(없으면 nil), 읽기에 실패했는가(라이브 — 부른 쪽이 「없음」으로 다루면 안 된다).
--  Studio에서 읽지 못했으면(API 접근이 꺼져 있을 때) 그 뒤로는 메모리만 쓴다(실패가 아니라 메모리 모드)
local function read(which: string, key: string): (boolean, any, boolean)
	local ds = getStore(which)
	if ds and not offline then
		local ok, result = try(function()
			return ds:GetAsync(key)
		end)
		if ok then
			return true, result, false
		end
		if studio() then
			offline = true
			warn("[lune] 저장소를 읽지 못해 메모리에만 저장한다: " .. tostring(result))
			return false, nil, false
		end
		warn(("[lune] 저장소에서 %s를 읽지 못했다: %s"):format(key, tostring(result)))
		return false, nil, true
	end
	return false, nil, not offline -- 저장소를 열지 못했다(라이브면 실패 · Studio의 메모리 모드면 실패가 아니다)
end

-- ---------- 계정 ----------
-- 저장된 계정을 읽는다. 없으면 nil.
-- 저장된 계정을 읽는다 → 계정(없으면 nil), 읽기에 실패했는가(true면 nil을 「새 계정」으로 다루면 안 된다 — 저장된 것을 빈 계정으로 덮어쓴다)
function Store.loadAccount(userId: number): (any, boolean)
	local ok, result, failed = read("account", "acct_" .. userId)
	if ok then
		return result, false
	end
	if failed then
		return nil, true
	end
	return memory.account[userId], false
end

-- 계정을 저장한다. 됐으면 true.
-- 저장의 차례(계정마다): 다시 해 보는 사이에 더 새로운 저장이 나왔으면 옛 것은 그만 쓴다 — 늦게 다시 쓴 옛 것이 새 것을 덮지 않게(2026-10-18 검토)
local saveSeq: { [number]: number } = {}
function Store.saveAccount(userId: number, data): boolean
	memory.account[userId] = data
	local ds = getStore("account")
	if not ds or offline then
		return false
	end
	saveSeq[userId] = (saveSeq[userId] or 0) + 1
	local mine = saveSeq[userId]
	local stale = false
	local ok, err = try(function()
		if saveSeq[userId] ~= mine then
			stale = true -- 더 새로운 저장이 이미 나갔다: 이것은 쓰지 않는다
			return
		end
		ds:SetAsync("acct_" .. userId, data)
	end)
	if not ok then
		warn(("[lune] %d의 저장에 실패했다: %s"):format(userId, tostring(err)))
	end
	-- 그만 쓴 옛 저장은 「저장했다」가 아니다(더 새로운 저장도 실패할 수 있다) — 경매장은 저장을 확인하고서야 장부를 바꾼다(2026-10-18 검토)
	return ok and not stale
end

-- ---------- 계정의 잠금 ----------
-- 같은 계정이 두 서버에 동시에 들어오면, 두 서버가 제가 아는 가방을 번갈아 저장해 물건이 복사되거나 사라진다(한쪽에서 창고에 넣고 다른 쪽에서 그 전의 가방을 저장한다).
--  그래서 계정을 읽기 전에 이 서버가 그 계정을 잡는다(같은 저장소의 "lock_<번호>" = { job = 서버의 번호, at = 잡은 때 }). 다른 서버가 잡고 있으면 읽지 않는다.
--  서버는 틈틈이(저장할 때마다 — 60초) 잠금을 새로 고치고, 나갈 때 푼다. LOCK_TTL초가 지나도록 새로 고쳐지지 않은 잠금은 죽은 서버의 것으로 보고 넘겨받는다.
--  저장소를 쓸 수 없으면(Studio — 메모리에만 저장한다) 잠그지 않는다. 저장소가 잠깐 말을 듣지 않을 때에도 막지 않는다(들어오지 못하는 것보다 낫다).
local LOCK_TTL = 150
Store.LOCK_TTL = LOCK_TTL
Store.JOB = nil :: string? -- (자동 검사가 다른 서버인 척할 때 적는다)
local function jobId(): string
	if Store.JOB then
		return Store.JOB
	end
	local ok, id = pcall(function()
		return game.JobId
	end)
	return if ok and typeof(id) == "string" and id ~= "" then id else "studio"
end

-- 이 서버가 그 계정을 잡는다(이미 잡고 있으면 시간을 새로 고친다). 다른 서버가 잡고 있으면 false
function Store.lock(userId: number): boolean
	local ds = getStore("account")
	if offline then
		return true
	end
	if not ds then
		return false -- 저장소를 열지 못했다(라이브): 잡지 못한 것으로(들여보내지 않는다)
	end
	local mine, job = true, jobId()
	local ok, err = try(function()
		ds:UpdateAsync("lock_" .. userId, function(old)
			local now = os.time()
			if typeof(old) == "table" and old.job ~= job and typeof(old.at) == "number" and now - old.at < LOCK_TTL then
				mine = false
				return nil -- 다른 서버의 것이다: 그대로 둔다
			end
			mine = true
			return { job = job, at = now }
		end)
	end)
	if not ok then
		warn(("[lune] %d의 잠금을 확인하지 못했다(막지 않는다): %s"):format(userId, tostring(err)))
		return true
	end
	return mine
end

-- 잠금을 푼다(이 서버가 잡고 있을 때만). 계정을 저장한 뒤에 부른다
function Store.unlock(userId: number)
	local ds = getStore("account")
	if not ds or offline then
		return
	end
	local job = jobId()
	try(function()
		ds:UpdateAsync("lock_" .. userId, function(old)
			if typeof(old) == "table" and old.job == job then
				return { job = job, at = 0 } -- 지난 잠금으로 적는다(다른 서버가 바로 잡을 수 있다)
			end
			return nil
		end)
	end)
end

-- 계정이 생기기 전의 저장(캐릭터 하나)을 읽는다. 없으면 nil. 쓰지도 지우지도 않는다.
function Store.loadOld(userId: number): (any, boolean)
	local ok, result, failed = read("old", "hero_" .. userId)
	if ok then
		return result, false
	end
	return nil, failed
end

-- ---------- 이름 장부 ----------
-- 그 이름을 가진 사람의 번호. 아무도 없으면 nil. 읽지 못했으면 false(그때는 이름을 지을 수 없다고 답한다)
function Store.nameOwner(key: string): any
	if offline then
		return memory.names[key]
	end
	if not getStore("names") then
		return false -- 장부를 열지 못했다(라이브): 이름을 지을 수 없다고 답한다
	end
	local ok, result = read("names", key)
	if ok then
		return if typeof(result) == "table" and result.u then result.u else nil
	end
	return if offline then memory.names[key] else false
end

-- 그 이름을 내 것으로 적는다. 비어 있거나 이미 내 것이면 true, 남의 것이면 false. 적지 못했으면 nil.
function Store.claimName(key: string, userId: number, at: number?): boolean?
	local ds = getStore("names")
	if offline then
		if memory.names[key] ~= nil and memory.names[key] ~= userId then
			return false
		end
		memory.names[key] = userId
		return true
	end
	if not ds then
		return nil -- 장부를 열지 못했다(라이브): 적지 못했다
	end
	local mine = false
	local ok, err = try(function()
		mine = false
		ds:UpdateAsync(key, function(old)
			if typeof(old) == "table" and old.u and old.u ~= userId then
				return nil -- 남의 것: 그대로 둔다
			end
			mine = true
			return { u = userId, at = at or 0 }
		end)
	end)
	if not ok then
		warn(("[lune] 이름 장부에 적지 못했다: %s"):format(tostring(err)))
		return nil
	end
	return mine
end

-- 내 이름을 장부에서 지운다(캐릭터를 지웠을 때 — 그 이름을 다른 사람이 쓸 수 있게 된다). 남의 것은 건드리지 않는다.
function Store.freeName(key: string, userId: number)
	local ds = getStore("names")
	if offline then
		if memory.names[key] == userId then
			memory.names[key] = nil
		end
		return
	end
	if not ds then
		return
	end
	try(function()
		ds:UpdateAsync(key, function(old)
			if typeof(old) == "table" and old.u == userId then
				return { u = false, at = old.at } -- 빈 이름(u = false): 누구든 다시 가질 수 있다
			end
			return nil
		end)
	end)
end

-- ---------- 명예의 전당의 순위판 ----------
--  판마다 OrderedDataStore 하나(열쇠 → 점수). 이름 · 직업은 따로(rankInfo — 열쇠 → { name, class }).
--  memoryOnly = 저장소에 쓰지 않고 이 서버의 메모리에만 둔다(확인용 임시 계정 — Studio에서 판을 볼 때만 쓰인다). 읽을 때는 저장소의 것과 메모리의 것을 합친다.
local ranks = {} -- [판] = OrderedDataStore
local rankMemory = { level = {}, power = {}, robux = {} } -- [판][열쇠] = 점수(메모리에만 있는 것 · 저장소를 못 쓸 때의 것)
local infoMemory = {} -- [열쇠] = { name, class }

local function getRank(board: string)
	if ranks[board] or offline then
		return ranks[board]
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(RANK[board])
	end)
	if ok then
		ranks[board] = result
	elseif studio() then
		offline = true
		warn("[lune] 순위판을 열지 못해 메모리에만 둔다: " .. tostring(result))
	else
		warn("[lune] 순위판을 열지 못했다(다음에 다시 해 본다): " .. tostring(result)) -- 라이브: 순위판 하나 때문에 서버 전체를 메모리 모드로 돌리지 않는다(2026-10-18 검토)
	end
	return ranks[board]
end

-- 그 판에 점수를 적는다(같은 열쇠는 덮어쓴다)
function Store.rankSet(board: string, key: string, score: number, memoryOnly: boolean?)
	if not RANK[board] then
		return
	end
	local ds = if memoryOnly then nil else getRank(board)
	if not ds or offline then
		rankMemory[board][key] = score
		return
	end
	rankMemory[board][key] = nil
	local ok, err = try(function()
		ds:SetAsync(key, score)
	end)
	if not ok then
		warn(("[lune] 순위판 %s에 적지 못했다: %s"):format(board, tostring(err)))
	end
end

function Store.rankRemove(board: string, key: string)
	if not RANK[board] then
		return
	end
	rankMemory[board][key] = nil
	local ds = getRank(board)
	if ds and not offline then
		try(function()
			ds:RemoveAsync(key)
		end)
	end
end

-- 그 판의 위에서부터 n줄: { { key, score } … }(높은 차례)
function Store.rankTop(board: string, n: number)
	local rows = {}
	if not RANK[board] then
		return rows
	end
	local ds = getRank(board)
	if ds and not offline then
		local ok, pages = try(function()
			return ds:GetSortedAsync(false, n)
		end)
		if ok and pages then
			for _, entry in pages:GetCurrentPage() do
				table.insert(rows, { key = entry.key, score = entry.value })
			end
		end
	end
	for key, score in rankMemory[board] do
		table.insert(rows, { key = key, score = score })
	end
	table.sort(rows, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.key < b.key
	end)
	while #rows > n do
		table.remove(rows)
	end
	return rows
end

-- 순위판에 적힌 열쇠의 이름 · 직업
function Store.rankInfoSet(key: string, info, memoryOnly: boolean?)
	infoMemory[key] = info
	local ds = if memoryOnly then nil else getStore("rankInfo")
	if ds and not offline then
		try(function()
			ds:SetAsync(key, info)
		end)
	end
end

function Store.rankInfoGet(key: string)
	if infoMemory[key] then
		return infoMemory[key]
	end
	local ok, result = read("rankInfo", key)
	if ok and typeof(result) == "table" then
		infoMemory[key] = result
		return result
	end
	return nil
end

function Store.rankInfoRemove(key: string)
	infoMemory[key] = nil
	local ds = getStore("rankInfo")
	if ds and not offline then
		try(function()
			ds:RemoveAsync(key)
		end)
	end
end

-- ---------- 경매장의 장부 ----------
--  분류마다 문서 하나(LuneMarket_v2의 열쇠 b_<분류> — v1은 2026-10-13의 첫 꼴: 메이플 옥션 방식으로 바꾸며 버렸다). 문서를 바꾸는 것은 UpdateAsync 하나로만 한다 — 두 서버가 같은 줄을 같이 바꾸려 해도 한쪽만 된다(셈은 shared/lune/sim/market.luau의 tx…).
--  저장소를 못 쓰면(Studio에서 API 접근이 꺼져 있을 때) 이 서버의 메모리에 둔다 — 그 판 안에서는 올리고 살 수 있다(끄면 사라진다).
--  잠깐 말을 듣지 않는다고 메모리로 넘어가지는 않는다(장부는 여러 서버가 같이 본다 — 이 서버만의 장부가 생기면 안 된다): 못 읽고 못 썼다고 알릴 뿐이다.
-- 장부를 읽는다 → 읽었는가, 문서(없으면 nil)
function Store.marketRead(key: string): (boolean, any)
	local ds = getStore("market")
	if offline then
		return true, memory.market[key]
	end
	if not ds then
		return false, nil -- (라이브) 이 서버만의 장부를 만들지 않는다
	end
	local ok, result = try(function()
		return ds:GetAsync("b_" .. key)
	end)
	if not ok then
		warn(("[lune] 경매장의 장부 %s를 읽지 못했다: %s"):format(key, tostring(result)))
		return false, nil
	end
	return true, result
end

-- 장부를 바꾼다. fn(지금의 문서) → 새 문서(nil이면 그대로 둔다), 결과 둘. 돌려주는 것: 저장소가 답했는가, 그 결과 둘, 바꾼 뒤의 문서.
--  fn은 여러 번 불릴 수 있다(다른 서버가 먼저 쓰면 저장소가 다시 부른다 · 답이 늦으면 우리가 다시 해 본다) — 받은 문서만 보고, 다시 불려도 같은 답을 내야 한다.
--  false가 돌아오면 적혔는지 알 수 없다(부른 쪽이 그렇게 다룬다)
function Store.marketUpdate(key: string, fn: (any) -> (any, any, any)): (boolean, any, any, any)
	local ds = getStore("market")
	if not ds and not offline then
		return false, nil, nil, nil -- (라이브) 저장소를 열지 못했다
	end
	if offline then
		local new, a, b = fn(memory.market[key])
		if new ~= nil then
			memory.market[key] = new
		end
		return true, a, b, memory.market[key]
	end
	local a, b, doc
	local ok, err = try(function()
		ds:UpdateAsync("b_" .. key, function(old)
			local new
			new, a, b = fn(old)
			doc = if new ~= nil then new else old
			return new
		end)
	end)
	if not ok then
		warn(("[lune] 경매장의 장부 %s에 쓰지 못했다: %s"):format(key, tostring(err)))
		return false, nil, nil, nil
	end
	return true, a, b, doc
end

-- ---------- 세계의 기록(LuneWorld_v1 — 2026-10-24) ----------
--  사용자: "150만렙 맨 처음 찍는 유저 나타나면 바로 전서버에 축하알림뜨면서 레벨 랭킹 1위 실시간 박제되게 이벤트 만들고"
--  열쇠 firstMax = 처음 만렙에 오른 캐릭터 { key, name, class, at }. 비어 있을 때만 적는다(UpdateAsync — 여러 서버에서 같은 때 올라도 한 사람만 적힌다).
function Store.firstMaxGet(): any
	if offline then
		return memory.world.firstMax
	end
	local ok, result = read("world", "firstMax")
	if ok then
		return result
	end
	return if offline then memory.world.firstMax else nil
end
-- 적어 본다: 돌려주는 것 = 내가 처음인가(true · 이미 남이 있으면 false · 적지 못했으면 nil), 저장소에 있는 기록
function Store.firstMaxClaim(rec): (boolean?, any)
	if offline then
		if memory.world.firstMax then
			return false, memory.world.firstMax
		end
		memory.world.firstMax = rec
		return true, rec
	end
	local ds = getStore("world")
	if not ds then
		return nil, nil
	end
	local mine, have = false, nil
	local ok, err = try(function()
		mine, have = false, nil
		ds:UpdateAsync("firstMax", function(old)
			if typeof(old) == "table" and old.key then
				have = old
				return nil -- 이미 있다: 그대로 둔다
			end
			mine, have = true, rec
			return rec
		end)
	end)
	if not ok then
		warn(("[lune] 만렙 최초 기록을 적지 못했다: %s"):format(tostring(err)))
		if studio() then
			offline = true
			return Store.firstMaxClaim(rec)
		end
		return nil, nil
	end
	return mine, have
end

function Store.isOffline(): boolean
	return offline
end

return Store
