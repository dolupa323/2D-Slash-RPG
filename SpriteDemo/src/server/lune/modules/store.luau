-- 캐릭터 저장소(DataStore). 게임 규칙은 모른다 — 숫자와 글로 된 표를 사람마다 읽고 쓸 뿐이다(저장 꼴은 sim/hero.luau의 pack · unpack).
--  DataStore 호출은 몇 번 다시 해 본다. Studio에서 API 접근이 꺼져 있으면 메모리에만 담아 둔다(Play를 끄면 사라진다 — 그때는 경고를 한 번 낸다).
--  아직 하지 않은 것: 같은 계정이 두 서버에 동시에 들어왔을 때의 잠금(여럿이 하는 단계에서 넣는다).
local DataStoreService = game:GetService("DataStoreService")

local NAME = "LuneHero_v1"
local RETRIES = 3
local WAIT = 1

local Store = {}

local store = nil
local memory = {} -- DataStore를 못 쓸 때의 임시 저장
local offline = false

local function getStore()
	if store or offline then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(NAME)
	end)
	if ok then
		store = result
	else
		offline = true
		warn("[lune] 저장소를 열지 못해 메모리에만 저장한다: " .. tostring(result))
	end
	return store
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

local function key(userId: number): string
	return "hero_" .. userId
end

-- 저장된 것을 읽는다. 없으면 nil.
function Store.load(userId: number)
	local ds = getStore()
	if ds and not offline then
		local ok, result = try(function()
			return ds:GetAsync(key(userId))
		end)
		if ok then
			return result
		end
		-- Studio에서 API 접근이 꺼져 있으면 여기로 온다 — 그 뒤로는 메모리만 쓴다
		offline = true
		warn("[lune] 저장소를 읽지 못해 메모리에만 저장한다: " .. tostring(result))
	end
	return memory[userId]
end

-- 저장한다. 됐으면 true.
function Store.save(userId: number, data): boolean
	memory[userId] = data
	local ds = getStore()
	if not ds or offline then
		return false
	end
	local ok, err = try(function()
		ds:SetAsync(key(userId), data)
	end)
	if not ok then
		warn(("[lune] %d의 저장에 실패했다: %s"):format(userId, tostring(err)))
	end
	return ok
end

-- 지운다(확인용 — 직업 고르기부터 다시 해 볼 때)
function Store.erase(userId: number)
	memory[userId] = nil
	local ds = getStore()
	if ds and not offline then
		try(function()
			ds:RemoveAsync(key(userId))
		end)
	end
end

function Store.isOffline(): boolean
	return offline
end

return Store
