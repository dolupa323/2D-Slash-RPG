-- 네트워크 계층. 모든 RemoteEvent/RemoteFunction은 shared/net/packets.luau의 정의로만 만들고 쓴다 — 모듈마다
-- 리모트를 제각각 만들고 이름 문자열로 찾던 구조를 대체한다.
--   서버: Net.OnServer(이름, 핸들러) — 인자 개수/타입과 요청 빈도를 검사해서 통과한 요청만 핸들러로 보낸다.
--         Net.FireClient / Net.FireAllClients
--   클라: Net.FireServer / Net.Invoke / Net.OnClient
-- 검증에 실패하거나 빈도를 넘긴 요청은 조용히 버리고(서버 로그에는 플레이어·패킷별로 몇 초에 한 번만 경고) 핸들러는
-- 호출하지 않는다. 이동 위치를 매번 거절하는 것은 엔진 공식 문서가 비권장하지만(오탐/지연), 이 계층은 "중요 행동
-- 요청이 형식에 맞는지, 폭주하지 않는지"만 본다 — 위치/내용의 타당성 검증은 각 서비스가 맡는다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packets = require(script.Parent.packets)

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local Net = {}

local folder: Folder
if IS_SERVER then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) or Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	for name, def in packets do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(if def.Kind == "Function" then "RemoteFunction" else "RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function getRemote(name: string)
	assert(packets[name], ("Net: 정의되지 않은 패킷 '%s' (shared/net/packets.luau에 먼저 추가)"):format(name))
	if IS_SERVER then
		return folder:FindFirstChild(name)
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name)
end

-- ===== 서버 =====

-- 플레이어별 패킷별 토큰 버킷: buckets[userId][name] = { tokens, last }
local buckets: { [number]: { [string]: { tokens: number, last: number } } } = {}
local lastWarn: { [string]: number } = {}

local function warnThrottled(key: string, message: string)
	local now = os.clock()
	if not lastWarn[key] or now - lastWarn[key] > 5 then
		lastWarn[key] = now
		warn(message)
	end
end

local function takeToken(player: Player, name: string, limit): boolean
	local perPlayer = buckets[player.UserId]
	if not perPlayer then
		perPlayer = {}
		buckets[player.UserId] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[name]
	if not bucket then
		bucket = { tokens = limit.Burst, last = now }
		perPlayer[name] = bucket
	end
	bucket.tokens = math.min(limit.Burst, bucket.tokens + (now - bucket.last) * limit.PerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function validArgs(def, ...): boolean
	if select("#", ...) > #def.Args then
		return false -- 정의보다 인자가 많으면 형식 위반
	end
	for i, check in def.Args do
		if not check((select(i, ...))) then
			return false
		end
	end
	return true
end

-- ClientToServer 패킷 핸들러 등록. Function 패킷이면 핸들러의 반환값이 클라이언트에 돌아간다.
function Net.OnServer(name: string, handler: (player: Player, ...any) -> ...any)
	assert(IS_SERVER, "Net.OnServer는 서버에서만 쓴다")
	local def = packets[name]
	assert(def and def.Direction == "ClientToServer", ("Net.OnServer: '%s'는 ClientToServer 패킷이 아니다"):format(name))
	local remote = getRemote(name)

	local function guarded(player: Player, ...)
		if not takeToken(player, name, def.RateLimit) then
			warnThrottled(player.UserId .. name .. "rate", ("Net: %s의 '%s' 요청이 빈도 제한을 넘어 버려졌다"):format(player.Name, name))
			return false
		end
		if not validArgs(def, ...) then
			warnThrottled(player.UserId .. name .. "arg", ("Net: %s의 '%s' 요청 인자가 형식에 맞지 않아 버려졌다"):format(player.Name, name))
			return false
		end
		return true
	end

	if def.Kind == "Function" then
		remote.OnServerInvoke = function(player: Player, ...)
			if not guarded(player, ...) then
				return nil
			end
			return handler(player, ...)
		end
	else
		remote.OnServerEvent:Connect(function(player: Player, ...)
			if guarded(player, ...) then
				handler(player, ...)
			end
		end)
	end
end

function Net.FireClient(name: string, player: Player, ...: any)
	assert(IS_SERVER)
	getRemote(name):FireClient(player, ...)
end

function Net.FireAllClients(name: string, ...: any)
	assert(IS_SERVER)
	getRemote(name):FireAllClients(...)
end

if IS_SERVER then
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		buckets[player.UserId] = nil
	end)
end

-- ===== 클라이언트 =====

function Net.FireServer(name: string, ...: any)
	assert(not IS_SERVER)
	getRemote(name):FireServer(...)
end

function Net.Invoke(name: string, ...: any): any
	assert(not IS_SERVER)
	return getRemote(name):InvokeServer(...)
end

function Net.OnClient(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(not IS_SERVER)
	return getRemote(name).OnClientEvent:Connect(handler)
end

return Net
