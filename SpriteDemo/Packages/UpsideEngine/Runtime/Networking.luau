local upsideEngine = script.Parent.Parent
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local request = require(script.Parent.Parent.Classes.Internal.Request)
local ToVector2 = require(script.Parent.Parent.Lib.Util.DataType.ToVector2)
local merge = require(script.Parent.Parent.Lib.Util.Generic.Merge)
local copyTable = require(script.Parent.Parent.Lib.Util.Internal.CopyTable)
local diff = require(script.Parent.Parent.Lib.Util.Internal.Diff)
local getDistance = require(script.Parent.Parent.Lib.Util.Math.GetDistance)
local authorityService = require(script.Parent.Parent.Services.AuthorityService)
local networkingService = require(upsideEngine.Services.NetworkingService)
local sceneManager = require(upsideEngine.Services.SceneManager)

local socket = game.ReplicatedStorage:WaitForChild("UpsideEngineSocket")
local isServer = runService:IsServer()
local isRunning = runService:IsRunning()

local requestsCache = networkingService.RequestsCache
local playersData = networkingService.PlayersData
local replicationTarget = networkingService.ReplicationTarget
local replicationTimer = 0

local event = isServer and "OnServerEvent" or "OnClientEvent"
local endpoints = {}

function endpoints.sync(client, pending)
	if typeof(pending) ~= "table" then
		return
	elseif not isServer then
		for _, requests in pending do
			buildRequests(requests)
		end

		return
	end

	-- This loop prevents the client from impersonating the server and therefore
	-- ensures that their requests are not automatically approved

	for _, request in pending do
		request.ClientId = client.UserId
	end

	buildRequests(pending)
end

-- (프로젝트 패치: 관심 영역/relevancy) networkingService.RelevancyFilter(player, request) -> boolean 이 설정돼 있으면,
-- 서버가 각 클라이언트에게 보내는 복제 데이터에서 "이 플레이어에게 필요 없는 오브젝트"를 뺀다(예: 다른 씬에 있는
-- 몬스터). 필터가 없으면(nil) 예전처럼 전부 보낸다. data는 { [clientId] = { [objectId] = request } } 형태다.
local function filterForPlayer(player, data)
	local filter = networkingService.RelevancyFilter
	if not filter then
		return data
	end

	local filtered = {}
	for clientId, objects in data do
		local kept = {}
		for objectId, request in objects do
			if filter(player, request) then
				kept[objectId] = request
			end
		end
		if next(kept) then
			filtered[clientId] = kept
		end
	end
	return filtered
end

function endpoints.requestServerData(client)
	for retries = 1, 4 do
		local data = table.clone(requestsCache)
		data[client.UserId] = nil

		socket:FireClient(client, "sync", filterForPlayer(client, data))
		task.wait(0.5)
	end
end

-- 서버가 이 플레이어의 관심 영역이 바뀌었을 때(예: 씬 이동) 호출한다 — 캐시된 전체 내용을 필터를 거쳐 다시 보내서, 새로
-- 관심 영역에 들어온 오브젝트가 완전한 내용(diff가 아닌 전체)으로 도착하게 한다.
function networkingService:ResyncClient(player)
	if not isServer then
		return
	end
	local data = table.clone(requestsCache)
	data[player.UserId] = nil
	socket:FireClient(player, "sync", filterForPlayer(player, data))
end

function buildRequests(requests)
	for _, data in requests do
		local content = data.Content :: RequestContent
		local clientId = data.ClientId

		if clientId == nil or content == nil then
			continue
		end

		local pendingRequest = request.new(clientId, content)
		playersData[clientId] = playersData[clientId] or {}

		local isNewObject = playersData[clientId][content.ObjectId] == nil
		local authorityType = authorityService:GetAuthority({
			Id = content.ObjectId,
		} :: any)

		if clientId == 0 then
			pendingRequest:Accept()
		elseif authorityType == "Client" or isNewObject then
			-- BUGFIX(local): "새 오브젝트는 통과시켜준다" 예외가 원래 `isServer and
			-- isNewObject`라 서버에서만 적용됐다. 그래서 클라이언트→서버 첫 홉은
			-- 통과(서버가 승인)했지만, 서버가 그걸 다른 클라이언트들에게 브로드캐스트할
			-- 때 각 클라이언트 입장에서는 isServer가 false라 이 예외를 못 받고,
			-- authorityType(아무도 설정 안 해서 항상 기본값 "Server")만 남아 조건이
			-- 항상 거짓이 됐다 — 결과적으로 플레이어 캐릭터 같은 클라이언트 소유
			-- 오브젝트가 다른 클라이언트 화면에 전혀 안 나타나는 버그였다. isServer
			-- 조건을 빼서 "처음 보는 오브젝트는 어느 realm이든 일단 통과"로 통일한다.
			networkingService:Fire("ReplicationRequest", pendingRequest)
		end
	end
end

local function onEvent(client, requestType, pending)
	local handle = endpoints[requestType] :: () -> nil
	handle(client, pending)
end

local function onPlayerAdded(player)
	playersData[player.UserId] = {}
	requestsCache[player.UserId] = {}
end

local function onPlayerLeave(player)
	local skip = not networkingService.DestroyObjectsOnLeave
	local data = playersData[player.UserId]
	playersData[player.UserId] = nil
	requestsCache[player.UserId] = nil

	if skip or isServer then
		return
	end

	for _, object in data do
		replicationTarget[object] = nil
		object:Destroy()
	end
end

local function sendClientRequests(pending)
	networkingService.Pending = {}
	socket:FireServer("sync", pending)
end

local function sendServerRequests(requests)
	local toSend = {}
	for index, data in requests do
		local content = data.Content
		local objectId = content.ObjectId
		local clientId = data.ClientId
		local clientRequests = requestsCache[clientId]

		if clientRequests == nil then
			requests[index] = nil
			continue
		end

		local cachedRequest = clientRequests[objectId] or { Content = {} }
		local cachedContent = cachedRequest.Content

		if toSend[clientId] == nil then
			toSend[clientId] = {}
		end

		requests[index] = nil
		clientRequests[objectId] = copyTable(clientRequests[objectId] or {}, data)
		toSend[clientId][objectId] = {
			ClientId = clientId,
			Content = merge(data.Content, {
				Instance = diff(content.Instance, cachedContent.Instance or {}),
				ObjectProperties = diff(content.ObjectProperties, cachedContent.ObjectProperties or {}),
			}),
		}
	end

	for _, player in players:GetPlayers() do
		local playerData = playersData[player.UserId] or {}
		local data = table.clone(toSend)
		local serverData = table.clone(data[0] or {})
		data[player.UserId] = nil
		data[0] = serverData

		for objectId, request in serverData do
			local object = playerData[objectId]
			if object == nil then
				continue
			end

			local authorityType = authorityService:GetAuthority({
				Id = objectId,
			} :: any)

			if authorityType == "Client" then
				serverData[objectId] = nil
			end
		end

		data = filterForPlayer(player, data)
		if next(data) then
			socket:FireClient(player, "sync", data)
		end
	end
end

local function replicateServer()
	for _, scene in sceneManager.Scenes do
		networkingService:Replicate(scene)
		for _, object in scene.Objects do
			networkingService:Replicate(object)
		end
	end
end

local function requestManager(deltaTime)
	local pending = networkingService.Pending
	local sendRequests = if isServer then sendServerRequests else sendClientRequests

	local serverReplication = networkingService.ServerReplication
	local replicationTicks = 1 / networkingService.ReplicationPerSecond
	replicationTimer += deltaTime

	while replicationTimer > replicationTicks do
		replicationTimer -= replicationTicks

		if isServer and isRunning and serverReplication then
			replicateServer()
		end

		if next(pending) then
			sendRequests(pending)
		end
	end
end

local function clientInterpolator(deltaTime)
	for object, goals in replicationTarget do
		local instance = object.Instance
		replicationTarget[object] = nil

		for property, value in goals do
			local currentValue = instance[property]
			local distance = getDistance(ToVector2(currentValue, "Offset"), ToVector2(value, "Offset"))

			if distance < 2 then
				instance[property] = value
				continue
			end

			local lerpSpeed = math.min(deltaTime * 8, 0.5)
			local iValue = currentValue:Lerp(value, lerpSpeed)
			instance[property] = iValue
		end
	end
end

for _, player in players:GetPlayers() do
	playersData[player.UserId] = {}
	requestsCache[player.UserId] = {}
end

if isServer then
	socket[event]:Connect(onEvent)
else
	socket[event]:Connect(function(...)
		onEvent(players.LocalPlayer, ...)
	end)
end

players.PlayerAdded:Connect(onPlayerAdded)
players.PlayerRemoving:Connect(onPlayerLeave)
runService.Heartbeat:Connect(requestManager)

if not isServer then
	runService.Heartbeat:Connect(clientInterpolator)
	socket:FireServer("requestServerData")
end

return {}
