-- 플레이어 데이터 영속성(DataStore) 서비스: 로드/저장/세션 락/오토세이브. 게임 규칙은 모른다 — 접속 중에는 메모리 세션
-- 테이블이 진실이고, 다른 서비스(progression/inventory/currency)가 그 테이블을 바꾼 뒤 MarkDirty만 부른다.
--
-- 참고: 사용자의 이전 프로젝트(Origin-W-I-L-D)와 OpenMMO의 Persistence 패턴 — (1) DataStore 호출을 재시도 + Studio에서
-- API 접근이 막혀 있으면 메모리 목업으로 폴백, (2) UpdateAsync 기반 세션 락으로 같은 계정이 다른 서버(JobId)에서
-- 동시에 저장 중일 때 덮어쓰지 않게 함, (3) 바뀐 사람만 표시해뒀다가 주기적으로 한 번에 저장하는 dirty-flag + 배치
-- 오토세이브(로그아웃 시엔 그와 별개로 항상 즉시 저장). 저장 형태와 버전 마이그레이션은 playerSchema.luau가 맡는다.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local playerSchema = require(script.Parent.playerSchema)

local store = DataStoreService:GetDataStore("PlayerData_v1")

local MAX_RETRIES = 3
local RETRY_DELAY = 1 -- seconds
local SESSION_STALE_SECONDS = 30 -- 이보다 오래된 락은 서버가 죽은 걸로 보고 새로 가져간다
local AUTOSAVE_INTERVAL = 30 -- seconds, dirty 표시된 플레이어만 이 주기로 배치 저장
local AUTOSAVE_STAGGER = 0.5 -- seconds, 배치 저장 중 플레이어 사이에 살짝 간격을 둬서 DataStore 쓰로틀링 방지

-- UserId -> 데이터 테이블(메모리 세션, 접속 중에는 이걸 기준으로 읽고 쓴다)
local sessions = {}
-- UserId -> true, Load()가 이미 진행 중임을 표시(같은 키로 DataStore 요청이 동시에 중복으로 나가는 걸 막는다).
local loading = {}
-- UserId -> true, 마지막 저장 이후 데이터가 바뀌어 다음 오토세이브 때 저장해야 함을 표시.
local dirty = {}
local autosaveRunning = false

local exports = {}

-- pcall + 재시도 공통 래퍼. 성공하면 (true, 결과), 재시도 다 실패하면 (false, 마지막 에러).
local function withRetry(fn)
	local lastErr
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY)
		end
	end
	return false, lastErr
end

local function loadUncached(player: Player)
	local key = "Player_" .. player.UserId
	local locked = false

	local ok, result = withRetry(function()
		return store:UpdateAsync(key, function(existing)
			existing = existing or playerSchema.default()
			local session = existing._session

			if session and session.JobId ~= game.JobId and (os.time() - (session.Timestamp or 0)) < SESSION_STALE_SECONDS then
				locked = true
				return nil -- 다른 서버가 아직 들고 있는 걸로 보임 — 덮어쓰지 않고 중단
			end

			locked = false
			existing._session = { JobId = game.JobId, Timestamp = os.time() }
			return existing
		end)
	end)

	local data
	if ok and result then
		data = result
	elseif locked then
		warn(("persistence: %s의 데이터가 다른 서버에서 사용 중이라 이번 세션은 임시(저장 안 됨) 데이터로 시작합니다."):format(player.Name))
		data = playerSchema.default()
		data._mock = true
	else
		-- Studio에서 API 접근이 막혀 있거나 DataStore 자체가 실패하는 경우 — 완전히 막히는 대신 메모리로만 굴러가는
		-- 목업으로 폴백해서 최소한 테스트는 가능하게 한다.
		warn(("persistence: %s의 DataStore 로드 실패, 메모리 임시 데이터로 대체합니다 - %s"):format(player.Name, tostring(result)))
		data = playerSchema.default()
		data._mock = true
	end

	playerSchema.migrate(data)
	sessions[player.UserId] = data
	return data
end

-- 세션 데이터를 불러온다(이미 있으면 그대로). DataStore 호출로 yield할 수 있다.
function exports.Load(player: Player)
	if sessions[player.UserId] then
		return sessions[player.UserId]
	end

	if loading[player.UserId] then
		repeat
			task.wait()
		until not loading[player.UserId]
		return sessions[player.UserId]
	end

	loading[player.UserId] = true
	local data = loadUncached(player)
	loading[player.UserId] = nil
	return data
end

-- 이미 불러온 세션 데이터(없으면 nil). 다른 서비스가 읽고 쓰는 유일한 진입점.
function exports.Get(player: Player)
	return sessions[player.UserId]
end

-- 데이터를 바꾼 서비스가 호출해서 "다음 오토세이브 때 저장 대상"으로 표시한다.
function exports.MarkDirty(player: Player)
	dirty[player.UserId] = true
end

function exports.Save(player: Player, isLogout: boolean)
	local data = sessions[player.UserId]
	if not data then
		return
	end

	if data._mock then
		-- 애초에 세션 락을 못 잡았거나 로드가 실패한 경우라 실제 저장소에 쓰면 안 된다(락을 진짜로 들고 있는 다른 서버
		-- 데이터를 덮어쓸 수 있음).
		return
	end

	local key = "Player_" .. player.UserId
	local payload = table.clone(data)
	payload._mock = nil
	payload._session = if isLogout then nil else { JobId = game.JobId, Timestamp = os.time() }

	local ok = withRetry(function()
		return store:UpdateAsync(key, function(existing)
			-- 저장 시점에도 다른 서버가 이미 락을 가져간 상태면(드물지만 가능) 덮어쓰지 않는다.
			if existing and existing._session and existing._session.JobId ~= game.JobId then
				return nil
			end
			return payload
		end)
	end)

	if ok then
		dirty[player.UserId] = nil
	else
		warn(("persistence: %s의 데이터 저장 실패(재시도 %d회 소진) - 다음 오토세이브 때 재시도됨"):format(player.Name, MAX_RETRIES))
	end
end

-- 플레이어가 나갈 때: 즉시 저장하고(세션 락 해제) 메모리에서 지운다.
function exports.Release(player: Player)
	exports.Save(player, true)
	sessions[player.UserId] = nil
	dirty[player.UserId] = nil
end

-- 서버가 닫힐 때(Studio Stop 포함): PlayerRemoving의 비동기 저장이 끝나기 전에 서버가 죽어 저장이 유실될 수 있으므로,
-- 모든 플레이어 저장이 끝날 때까지 기다린다(BindToClose 안에서 호출).
function exports.SaveAll()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			exports.Save(player, true)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end

-- 바뀐 사람만 모아뒀다가 AUTOSAVE_INTERVAL마다 한 번에 저장한다(서버 크래시로 인한 유실 범위를 이 주기 이내로 줄임).
local function runAutosaveLoop()
	while autosaveRunning do
		task.wait(AUTOSAVE_INTERVAL)

		for userId in dirty do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				exports.Save(player, false)
			else
				dirty[userId] = nil -- 이미 나간 플레이어면 표시만 지운다(로그아웃 시 이미 저장됐음)
			end
			task.wait(AUTOSAVE_STAGGER)
		end
	end
end

function exports.StartAutosave()
	if autosaveRunning then
		return
	end
	autosaveRunning = true
	task.spawn(runAutosaveLoop)
end

function exports.StopAutosave()
	autosaveRunning = false
end

return exports
