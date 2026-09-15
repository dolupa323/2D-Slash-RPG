-- 플레이어 캐릭터(hero) 같이 클라이언트가 직접 만든 오브젝트를 다른 플레이어에게
-- 보여주려면 NetworkingService를 거쳐야 한다. 클라이언트가 새 오브젝트를 처음 복제
-- 요청하면(Runtime/Networking.luau의 buildRequests, isNewObject 분기) 서버에서
-- "ReplicationRequest" 이벤트가 뜨는데, 이걸 받아서 request:Approve()를 불러줘야
-- 다른 클라이언트에게 브로드캐스트된다 — 엔진이 자동으로 승인해주지 않는다(SpriteDemo
-- 어디에도 이 리스너가 없었던 게 "다른 유저가 안 보이는" 버그의 원인이었다).
-- 지금은 별도 검증 없이 전부 승인한다 — 나중에 스팸/치트 방지가 필요해지면 여기서
-- request.Content를 검사해 거를 수 있다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

local exports = {}

function exports.load()
	NetworkingService:On("ReplicationRequest", function(request)
		request:Approve()
	end)
end

function exports.start() end

function exports.unload() end

return exports
