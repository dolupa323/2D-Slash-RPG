-- 플레이어 스탯(레벨/경험치)과 인벤토리를 서버가 권위를 갖고 관리 + DataStore에 저장.
-- 체력(Health/MaxHealth)은 새로 안 만든다 — Character.luau(Packages/UpsideEngine/
-- Classes/Public/Character.luau)에 이미 있다. 레벨/경험치는 그것처럼 hero(Character
-- 오브젝트)의 평범한 필드로 클라이언트 쪽(playerStats.luau)에서 채워 넣는다 — 이미 붙여둔
-- NetworkingService 리플리케이션이 평범한 필드는 자동으로 복제해주므로(Health/WalkSpeed
-- 처럼), 다른 플레이어 화면에도 별도 작업 없이 레벨이 보인다.
--
-- 인벤토리는 테이블이라 필드 하나로 표현하기 애매해서, 전용 RemoteEvent(InventoryUpdated)
-- 로 서버가 바뀔 때마다 밀어준다.
--
-- 참고: 사용자의 이전 프로젝트(Origin-W-I-L-D)와 OpenMMO의 Persistence 패턴을 이
-- 규모에 맞게 축약해서 반영함 — (1) DataStore 호출을 재시도 + Studio에서 API 접근이
-- 막혀 있으면 메모리 목업으로 폴백, (2) UpdateAsync 기반 세션 락으로 같은 계정이 다른
-- 서버(JobId)에서 동시에 저장 중일 때 덮어쓰지 않게 함, (3) OpenMMO처럼 "바뀐 사람만
-- 표시해뒀다가 주기적으로 한 번에 저장"하는 dirty-flag + 배치 오토세이브(로그아웃 시엔
-- 그와 별개로 항상 즉시 저장) — 매 변경마다 저장하거나 서버가 죽을 때만 저장하는 것보다
-- 데이터 유실 위험이 적다. 원본에 있던 스냅샷/버전 마이그레이션은 지금 뼈대 범위 밖이라
-- 넣지 않았다.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("PlayerData_v1")

local MAX_RETRIES = 3
local RETRY_DELAY = 1 -- seconds
local SESSION_STALE_SECONDS = 30 -- 이보다 오래된 락은 서버가 죽은 걸로 보고 새로 가져간다
local AUTOSAVE_INTERVAL = 30 -- seconds, dirty 표시된 플레이어만 이 주기로 배치 저장
local AUTOSAVE_STAGGER = 0.5 -- seconds, 배치 저장 중 플레이어 사이에 살짝 간격을 둬서 DataStore 쓰로틀링 방지

local function defaultData()
	return {
		Level = 1,
		Experience = 0,
		MaxExperience = 100, -- placeholder 공식: 레벨업 밸런싱은 이후 작업
		Inventory = {}, -- { [slotIndex] = { ItemId = string, Count = number } }
	}
end

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

-- UserId -> 데이터 테이블(메모리 세션 캐시, 접속 중에는 이걸 기준으로 읽고 쓴다)
local sessions = {}
-- UserId -> true, loadData()가 이미 진행 중임을 표시(같은 키로 DataStore 요청이
-- 동시에 중복으로 나가는 걸 막는다 — PlayerAdded와 GetPlayerData:InvokeServer가
-- 거의 동시에 들어올 때 흔히 발생함).
local loading = {}
-- UserId -> true, 마지막 저장 이후 데이터가 바뀌어서 다음 오토세이브 때 저장해야 함을 표시.
local dirty = {}
local autosaveRunning = false

local function loadData(player: Player)
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
	local data = loadDataUncached(player)
	loading[player.UserId] = nil
	return data
end

function loadDataUncached(player: Player)
	local key = "Player_" .. player.UserId
	local locked = false

	local ok, result = withRetry(function()
		return store:UpdateAsync(key, function(existing)
			existing = existing or defaultData()
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
		warn(("playerData: %s의 데이터가 다른 서버에서 사용 중이라 이번 세션은 임시(저장 안 됨) 데이터로 시작합니다."):format(player.Name))
		data = defaultData()
		data._mock = true
	else
		-- Studio에서 API 접근이 막혀 있거나 DataStore 자체가 실패하는 경우 — 완전히
		-- 막히는 대신 메모리로만 굴러가는 목업으로 폴백해서 최소한 테스트는 가능하게 한다.
		warn(("playerData: %s의 DataStore 로드 실패, 메모리 임시 데이터로 대체합니다 - %s"):format(player.Name, tostring(result)))
		data = defaultData()
		data._mock = true
	end

	sessions[player.UserId] = data
	return data
end

local function saveData(player: Player, isLogout: boolean)
	local data = sessions[player.UserId]
	if not data then
		return
	end

	if data._mock then
		-- 애초에 세션 락을 못 잡았거나 로드가 실패한 경우라 실제 저장소에 쓰면 안 된다
		-- (락을 진짜로 들고 있는 다른 서버 데이터를 덮어쓸 수 있음).
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
		warn(("playerData: %s의 데이터 저장 실패(재시도 %d회 소진) - 다음 오토세이브 때 재시도됨"):format(player.Name, MAX_RETRIES))
	end
end

-- 다른 서버 모듈이 세션 데이터를 직접 바꾼 뒤 호출해서 "다음 오토세이브 때 저장 대상"으로
-- 표시한다(레벨업/아이템 습득 등 실제 콘텐츠가 붙으면 여기서 호출하게 될 것).
local function markDirty(player: Player)
	dirty[player.UserId] = true
end

-- OpenMMO의 dirty-flag + 주기 배치 저장 패턴 — 매 변경마다 저장하지 않고, 바뀐 사람만
-- 모아뒀다가 AUTOSAVE_INTERVAL마다 한 번에 저장한다. 서버 크래시로 인한 데이터 유실
-- 범위를 이 주기 이내로 줄여준다. 로그아웃/서버 종료 시 즉시 저장은 이것과 별개로 그대로 유지.
local function runAutosaveLoop()
	while autosaveRunning do
		task.wait(AUTOSAVE_INTERVAL)

		for userId in dirty do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				saveData(player, false)
			else
				dirty[userId] = nil -- 이미 나간 플레이어면 표시만 지운다(로그아웃 시 이미 저장됐음)
			end
			task.wait(AUTOSAVE_STAGGER)
		end
	end
end

local function ensureRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	-- GetPlayerData: 클라이언트가 자기 캐릭터를 만들 때 한 번 InvokeServer로 초기값을 받아간다.
	local getPlayerData = remotes:FindFirstChild("GetPlayerData")
	if not getPlayerData then
		getPlayerData = Instance.new("RemoteFunction")
		getPlayerData.Name = "GetPlayerData"
		getPlayerData.Parent = remotes
	end

	-- InventoryUpdated: 서버 -> 클라 단방향. 인벤토리가 바뀔 때마다(지금은 접속 시 1회) 쏴준다.
	local inventoryUpdated = remotes:FindFirstChild("InventoryUpdated")
	if not inventoryUpdated then
		inventoryUpdated = Instance.new("RemoteEvent")
		inventoryUpdated.Name = "InventoryUpdated"
		inventoryUpdated.Parent = remotes
	end

	return getPlayerData, inventoryUpdated
end

local exports = {}

function exports.load()
	local getPlayerData, inventoryUpdated = ensureRemotes()

	getPlayerData.OnServerInvoke = function(player: Player)
		local data = sessions[player.UserId] or loadData(player)
		return data
	end

	local function onPlayerAdded(player: Player)
		local data = loadData(player)
		inventoryUpdated:FireClient(player, data.Inventory)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		saveData(player, true)
		sessions[player.UserId] = nil
		dirty[player.UserId] = nil
	end)

	-- main.server.luau가 모듈을 load()하는 시점과 PlayerAdded가 먼저 fire되는 시점이
	-- Studio 테스트 환경에 따라 어긋날 수 있어서, 이미 접속해 있는 플레이어도 처리한다.
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	autosaveRunning = true
	task.spawn(runAutosaveLoop)
end

function exports.start() end

-- 다른 서버 모듈이 세션 데이터를 읽고/바꿀 수 있게 노출 — 바꾼 뒤엔 MarkDirty 호출 필요.
function exports.GetSession(player: Player)
	return sessions[player.UserId]
end

exports.MarkDirty = markDirty

function exports.unload()
	autosaveRunning = false
	for _, player in Players:GetPlayers() do
		saveData(player, true)
	end
end

return exports
