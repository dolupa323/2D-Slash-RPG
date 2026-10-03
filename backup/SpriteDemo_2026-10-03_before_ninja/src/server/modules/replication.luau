-- 플레이어 캐릭터(hero) 같이 클라이언트가 직접 만든 오브젝트를 다른 플레이어에게 보여주려면 NetworkingService를 거쳐야
-- 한다. 클라이언트가 새 오브젝트를 복제 요청하면(Runtime/Networking.luau의 buildRequests) 서버에서 "ReplicationRequest"가
-- 뜨는데, 요청을 승인(Approve)해야 다른 클라이언트에게 브로드캐스트된다 — 엔진이 자동으로 승인해주지 않는다.
--
-- 이 요청의 내용(request.Content)에는 히어로의 위치가 들어 있다. 서버 몬스터 AI/공격 판정이 그 위치를 알아야 하므로
-- 여기서 읽어 heroTracking에 넘긴다(별도 위치 보고 RemoteEvent 불필요). 위치를 검증해서 거절하지는 않는다 — 엔진 공식
-- 문서가 이동 검증을 비권장한다("aggressive validation can cause lag or false positives", "Rejection should be rare").
--
-- (참고: 공식 문서의 "Accept() + SetAuthority(Client) + characters[player] 추적" 패턴은 서버에 캐릭터 복사본을 만들고
-- 권위를 지정하는 방식이다. 우리는 아직 Approve() 릴레이를 유지한다 — 이 엔진 사본은 첫 요청 이후 권위가 "Server"인
-- 오브젝트의 요청을 걸러내기 때문에, Accept로 바꾸려면 SetAuthority까지 함께 검증해야 해서 다음 단계로 미뤘다.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local heroTracking = require(script.Parent.heroTracking)

local exports = {}

function exports.load()
	NetworkingService:On("ReplicationRequest", function(request)
		local content = request.Content
		if content and content.ClassName == "Character" and request.ClientId ~= 0 then
			local instanceData = content.Instance
			local position = instanceData and instanceData.Position
			if typeof(position) == "UDim2" then
				if not heroTracking.OnHeroReplicated(request.ClientId, position, content.ObjectId) then
					return -- 이미 교체된 옛 캐릭터의 늦은 갱신 — 전달하지 않는다.
				end
			end
		end
		request:Approve()
	end)
end

function exports.start() end

function exports.unload() end

return exports
