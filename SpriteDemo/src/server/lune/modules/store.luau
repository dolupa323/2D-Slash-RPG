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
-- 읽어 둔 이름은 10~15분 뒤에 다시 읽는다(2026-10-26 사용자: "지금 랭킹 한국어 류빌로 나오잖아 닉네임은 Ryuville인데" — 전에는 서버가 닫힐 때까지 처음 읽은 이름을 썼다:
--  다른 서버에서 이름을 바꾸면(이름 바꾸기 주문서 · 운영자가 고친 이름) 이 서버의 순위판에는 옛 이름이 남았다). 다시 읽는 때를 열쇠마다 흩어 한꺼번에 읽지 않게
local INFO_KEEP, INFO_SPREAD = 600, 300
local infoUntil = {} -- [열쇠] = 다시 읽을 때(os.clock)
local function infoKept(key: string)
	infoUntil[key] = os.clock() + INFO_KEEP + math.random() * INFO_SPREAD
end

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

-- 그 판의 그 열쇠의 점수를 score로 올린다 — 이미 적혀 있고 그보다 낮을 때만(없는 줄은 만들지 않는다: 지운 캐릭터가 되살아나지 않게 · 2026-10-29 Rank.fixMax)
function Store.rankRaise(board: string, key: string, score: number)
	if not RANK[board] then
		return
	end
	local kept = rankMemory[board][key]
	if kept ~= nil then
		if kept < score then
			rankMemory[board][key] = score
		end
		return
	end
	local ds = getRank(board)
	if not ds or offline then
		return
	end
	local ok, err = try(function()
		ds:UpdateAsync(key, function(old)
			if typeof(old) == "number" and old < score then
				return score
			end
			return nil -- 없거나 이미 같거나 높다: 쓰지 않는다
		end)
	end)
	if not ok then
		warn(("[lune] 순위판 %s의 점수를 올리지 못했다: %s"):format(board, tostring(err)))
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
	infoKept(key)
	local ds = if memoryOnly then nil else getStore("rankInfo")
	if ds and not offline then
		try(function()
			ds:SetAsync(key, info)
		end)
	end
end

function Store.rankInfoGet(key: string)
	local kept = infoMemory[key]
	if kept and os.clock() < (infoUntil[key] or 0) then
		return kept
	end
	local ok, result = read("rankInfo", key)
	if ok then
		infoMemory[key] = if typeof(result) == "table" then result else nil
		infoKept(key)
		return infoMemory[key]
	end
	if kept then
		infoKept(key) -- 읽지 못했다(메모리 모드 · 저장소가 답하지 않는다): 읽어 둔 것을 그대로 쓴다
	end
	return kept
end

function Store.rankInfoRemove(key: string)
	infoMemory[key] = nil
	infoUntil[key] = nil
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
--  fresh = 지금의 값으로(UseCache = false). 그냥 읽으면 로블록스가 한 서버에서 4초 동안 같은 값(옛 값일 수 있다)을 준다(공식 문서 data-stores/versioning-listing-and-caching).
--   2026-10-27 사용자: "구매판정은 샀다고 보였는데 완료전에 다른사람이 구매하거나 하는거아니냐고" — 산 것이 장부에 적혔는지 다시 볼 때 옛 값을 읽어 「못 샀다」로 돈을 돌려주면, 물건은 아무에게도 가지 않고 판 사람은 대금을 받았다
function Store.marketRead(key: string, fresh: boolean?): (boolean, any)
	local ds = getStore("market")
	if offline then
		return true, memory.market[key]
	end
	if not ds then
		return false, nil -- (라이브) 이 서버만의 장부를 만들지 않는다
	end
	local ok, result = try(function()
		if fresh then
			local opts = Instance.new("DataStoreGetOptions")
			opts.UseCache = false
			return ds:GetAsync("b_" .. key, opts)
		end
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

-- 열쇠 maxTen = 만렙에 오른 차례대로 열 캐릭터 { { key, name, class, at } … }(오른 때의 차례 — 2026-10-26 칭호 「만월의 십인」).
--  열이 차기 전에만 더한다(이미 있는 캐릭터는 다시 넣지 않는다 · 열이 차면 그대로). 돌려주는 것: 저장소에 있는 목록(읽지 못했으면 nil)
function Store.maxTenGet(): any
	if offline then
		return memory.world.maxTen or {}
	end
	local ok, result = read("world", "maxTen")
	if ok then
		return if typeof(result) == "table" then result else {}
	end
	return if offline then memory.world.maxTen or {} else nil
end
function Store.maxTenAdd(rec, cap: number): any
	local function add(old)
		local list = if typeof(old) == "table" then old else {}
		for _, r in list do
			if typeof(r) == "table" and r.key == rec.key then
				return nil, list -- 이미 있다
			end
		end
		if #list >= cap then
			return nil, list -- 다 찼다
		end
		local new = table.clone(list)
		local at = 1
		while at <= #new and (new[at].at or 0) <= rec.at do
			at += 1
		end
		table.insert(new, at, rec)
		return new, new
	end
	if offline then
		local new, have = add(memory.world.maxTen)
		memory.world.maxTen = new or have
		return have
	end
	local ds = getStore("world")
	if not ds then
		return nil
	end
	local have = nil
	local ok, err = try(function()
		ds:UpdateAsync("maxTen", function(old)
			local new, now = add(old)
			have = now
			return new
		end)
	end)
	if not ok then
		warn(("[lune] 만렙 열 사람의 기록을 적지 못했다: %s"):format(tostring(err)))
		if studio() then
			offline = true
			return Store.maxTenAdd(rec, cap)
		end
		return nil
	end
	return have
end

-- 직업마다의 첫 만렙(2026-10-27 사용자: "직업별 첫 만렙 유저들 칭호 만들거야") — 열쇠 firstMax_<직업> = { key, name, class, at }. 비어 있을 때만 적는다(firstMax와 같다)
function Store.classFirstGet(class: string): (boolean, any)
	if offline then
		return true, memory.world["firstMax_" .. class]
	end
	local ok, result = read("world", "firstMax_" .. class)
	if ok then
		return true, result
	end
	return offline, if offline then memory.world["firstMax_" .. class] else nil
end
-- 적어 본다 → 저장소에 있는 기록(내 것이든 남의 것이든 · 적지 못했으면 nil)
function Store.classFirstClaim(class: string, rec): any
	local key = "firstMax_" .. class
	if offline then
		memory.world[key] = memory.world[key] or rec
		return memory.world[key]
	end
	local ds = getStore("world")
	if not ds then
		return nil
	end
	local have = nil
	local ok, err = try(function()
		ds:UpdateAsync(key, function(old)
			if typeof(old) == "table" and old.key then
				have = old
				return nil -- 이미 있다: 그대로 둔다
			end
			have = rec
			return rec
		end)
	end)
	if not ok then
		warn(("[lune] 직업의 첫 만렙 기록을 적지 못했다: %s"):format(tostring(err)))
		if studio() then
			offline = true
			return Store.classFirstClaim(class, rec)
		end
		return nil
	end
	return have
end

-- 황금왕(후원 순위 1위 — 2026-10-29 사용자: "매주 목요일마다 확인하고 그 주 1위에게 칭호 지급하고 다음주에 바뀌었다면 또 바뀐 1위한테 지급하고 2위한테서 뺏고"):
--  열쇠 goldKing = { user = 그 계정의 번호(없으면 0), week = 정한 주(Titles.goldWeek), spent = 그때의 후원, at = 정한 때 }. 한 주에 한 번만 적힌다(UpdateAsync — 여러 서버가 같은 때 정해도 먼저 적은 것)
--  goldKingGet → 읽었는가, 기록(없으면 nil) · goldKingSettle(week, rec) → 저장소에 있는 그 주의 기록(이미 그 주에 정해졌으면 그것 · 적지 못했으면 nil)
function Store.goldKingGet(): (boolean, any)
	if offline then
		return true, memory.world.goldKing
	end
	local ok, result = read("world", "goldKing")
	if ok then
		return true, if typeof(result) == "table" then result else nil
	end
	return offline, if offline then memory.world.goldKing else nil
end
function Store.goldKingSettle(week: number, rec): any
	local function pick(old)
		if typeof(old) == "table" and old.week == week then
			return nil, old -- 이 주는 이미 정해졌다
		end
		return rec, rec
	end
	if offline then
		local new, have = pick(memory.world.goldKing)
		memory.world.goldKing = new or have
		return have
	end
	local ds = getStore("world")
	if not ds then
		return nil
	end
	local have = nil
	local ok, err = try(function()
		ds:UpdateAsync("goldKing", function(old)
			local new, now = pick(old)
			have = now
			return new
		end)
	end)
	if not ok then
		warn(("[lune] 황금왕 기록을 적지 못했다: %s"):format(tostring(err)))
		if studio() then
			offline = true
			return Store.goldKingSettle(week, rec)
		end
		return nil
	end
	return have
end

-- 한정 판매(2026-10-29 사용자: "거인 라이딩 황금으로 해서 한정 20개 판매로 해서 판매하고 다팔리면 안파는식으로"): 열쇠 stock_<상품> = { sold = 판 수, holds = { [사람 번호(글)] = 끝나는 때 } }.
--  모든 서버가 같은 기록을 본다(UpdateAsync). 구매 창을 띄우기 전에 한 개를 잡아 두고(hold) — 결제가 오면 그것을 판 것으로 · 창을 닫으면 놓는다 · 시간이 지나면 저절로 풀린다.
--  돌려주는 것은 모두 (해냈는가, 기록) — 저장소에 닿지 못했으면 (nil, nil)
local function stockClean(old, now: number)
	local rec = { sold = 0, holds = {} }
	if typeof(old) == "table" then
		rec.sold = if typeof(old.sold) == "number" then math.max(0, math.floor(old.sold)) else 0
		if typeof(old.holds) == "table" then
			for uid, till in old.holds do
				if typeof(uid) == "string" and typeof(till) == "number" and till > now then
					rec.holds[uid] = till
				end
			end
		end
	end
	return rec
end
local function holdCount(rec, except: string?): number
	local n = 0
	for uid in rec.holds do
		if uid ~= except then
			n += 1
		end
	end
	return n
end
Store.stockHoldCount = holdCount
-- fn(rec) → 바꿀 것인가(true면 적는다), 해냈는가
local function stockUpdate(key: string, now: number, fn): (boolean?, any)
	local name = "stock_" .. key
	if offline then
		local rec = stockClean(memory.world[name], now)
		local write, done = fn(rec)
		if write then
			memory.world[name] = rec
		end
		return done, rec
	end
	local ds = getStore("world")
	if not ds then
		return nil, nil
	end
	local done, have = false, nil
	local ok, err = try(function()
		ds:UpdateAsync(name, function(old)
			local rec = stockClean(old, now)
			local write, d = fn(rec)
			done, have = d, rec
			return if write then rec else nil
		end)
	end)
	if not ok then
		warn(("[lune] 한정 판매 기록(%s)을 적지 못했다: %s"):format(key, tostring(err)))
		if studio() then
			offline = true
			return stockUpdate(key, now, fn)
		end
		return nil, nil
	end
	return done, have
end
function Store.stockGet(key: string, now: number): (boolean, any)
	if offline then
		return true, stockClean(memory.world["stock_" .. key], now)
	end
	local ok, result = read("world", "stock_" .. key)
	if ok then
		return true, stockClean(result, now)
	end
	return offline, if offline then stockClean(memory.world["stock_" .. key], now) else nil
end
-- 한 개를 잡는다(이미 잡아 둔 사람이면 시간만 늘린다): 판 수 + 남이 잡은 수가 limit 밑이어야 한다
function Store.stockHold(key: string, userId: number, limit: number, now: number, secs: number): (boolean?, any)
	local uid = tostring(userId)
	return stockUpdate(key, now, function(rec)
		if rec.holds[uid] == nil and rec.sold + holdCount(rec) >= limit then
			return false, false
		end
		rec.holds[uid] = now + secs
		return true, true
	end)
end
-- 결제가 왔다: 잡아 둔 것을 판 것으로(잡아 둔 것이 풀렸어도 판다 — 돈을 받고 주지 않는 일은 없게: limit을 넘으면 서버 출력에 남긴다)
function Store.stockTake(key: string, userId: number, limit: number, now: number): (boolean?, any)
	local uid = tostring(userId)
	return stockUpdate(key, now, function(rec)
		if rec.holds[uid] == nil and rec.sold + holdCount(rec) >= limit then
			warn(("[lune] 한정 판매 %s: 잡아 둔 것이 풀린 뒤에 결제가 왔다 — %d개를 넘겨 준다(%d)"):format(key, limit, userId))
		end
		rec.holds[uid] = nil
		rec.sold += 1
		return true, true
	end)
end
-- 판 것을 되돌린다(준 것을 저장하지 못했다 — 다시 올 결제가 다시 가져가게 잡아 둔다)
function Store.stockUntake(key: string, userId: number, now: number, secs: number): (boolean?, any)
	return stockUpdate(key, now, function(rec)
		rec.sold = math.max(0, rec.sold - 1)
		rec.holds[tostring(userId)] = now + secs
		return true, true
	end)
end
-- 놓는다(구매 창을 사지 않고 닫았다)
function Store.stockRelease(key: string, userId: number, now: number): (boolean?, any)
	local uid = tostring(userId)
	return stockUpdate(key, now, function(rec)
		if rec.holds[uid] == nil then
			return false, true
		end
		rec.holds[uid] = nil
		return true, true
	end)
end

-- 관리자의 선물 상자(2026-10-29 사용자: "나 어드민 호박사탕 지급 탭 만들어주고" — server/lune/modules/gifts.luau): 열쇠 gift_<계정 번호> = { { name = 받을 캐릭터의 이름, id = 아이템, n = 수, at = 보낸 때 } … }
--  모든 서버가 같은 기록을 본다(UpdateAsync). 그 캐릭터로 들어오면(또는 지금 그 캐릭터로 있는 서버가 소식을 받으면) 그 이름의 것만 꺼낸다 — 다른 캐릭터의 것은 남는다
Store.GIFT_MAX = 50 -- 한 계정에 쌓아 두는 선물의 수(넘으면 가장 오래된 것부터 버린다 — 잘못 누른 것이 끝없이 쌓이지 않게)
local function giftClean(old)
	local list = {}
	if typeof(old) == "table" then
		for _, g in old do
			if typeof(g) == "table" and typeof(g.name) == "string" and typeof(g.id) == "string" and typeof(g.n) == "number" and g.n >= 1 then
				table.insert(list, { name = g.name, id = g.id, n = math.floor(g.n), at = if typeof(g.at) == "number" then g.at else 0 })
			end
		end
	end
	return list
end
-- fn(list) → 바꿀 것인가, 돌려줄 것. 돌려주는 것: 해냈는가(저장소에 닿지 못했으면 nil), fn이 돌려준 것
local function giftUpdate(userId: number, fn): (boolean?, any)
	local name = "gift_" .. tostring(userId)
	if offline then
		local list = giftClean(memory.world[name])
		local write, out = fn(list)
		if write then
			memory.world[name] = list
		end
		return true, out
	end
	local ds = getStore("world")
	if not ds then
		return nil, nil
	end
	local out = nil
	local ok, err = try(function()
		ds:UpdateAsync(name, function(old)
			local list = giftClean(old)
			local write, o = fn(list)
			out = o
			return if write then list else nil
		end)
	end)
	if not ok then
		warn(("[lune] 선물 상자(%s)를 적지 못했다: %s"):format(tostring(userId), tostring(err)))
		if studio() then
			offline = true
			return giftUpdate(userId, fn)
		end
		return nil, nil
	end
	return true, out
end
function Store.giftAdd(userId: number, gift): boolean?
	local ok = giftUpdate(userId, function(list)
		table.insert(list, { name = gift.name, id = gift.id, n = gift.n, at = gift.at or os.time() })
		while #list > Store.GIFT_MAX do
			table.remove(list, 1)
		end
		return true, true
	end)
	return ok
end
-- 그 캐릭터(이름)의 선물을 모두 꺼낸다 → 해냈는가, { { id, n } … }
function Store.giftTake(userId: number, name: string): (boolean?, { any })
	local ok, got = giftUpdate(userId, function(list)
		local mine = {}
		for i = #list, 1, -1 do
			if list[i].name == name then
				table.insert(mine, 1, table.remove(list, i))
			end
		end
		return #mine > 0, mine
	end)
	return ok, got or {}
end

function Store.isOffline(): boolean
	return offline
end

return Store
