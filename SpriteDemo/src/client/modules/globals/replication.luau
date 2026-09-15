-- 서버가 승인(Approve)해서 브로드캐스트한 다른 플레이어의 복제 데이터를 받아 로컬에
-- 실제로 만들어 붙이는(request:Accept()) 쪽. 서버 쪽 replication.luau와 짝이다 —
-- 저기서 승인만 해주고 여기서 안 받으면(또는 그 반대) 여전히 다른 플레이어가 안 보인다.
-- request:Accept()는 이 요청이 내 로컬 캐릭터 자신의 것이면 그냥 그 캐릭터를 반환하고
-- 아무 것도 덮어쓰지 않는다(Request.luau 92번째 줄 주석 참고) — 그래서 내 캐릭터 것도
-- 안전하게 그냥 다 Accept해도 된다.
-- 씬을 넘나들 때마다(sceneLoader가 매번 load/unload) globals도 다시 load()되는데, 이
-- 리스너는 씬과 무관하게 한 번만 걸면 되므로 중복 연결만 막고 끊지는 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local AuthorityService = UpsideEngine.GetService("AuthorityService")
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local exports = {}

function exports.load(scene: Scene)
	if exports.connection then
		return
	end

	exports.connection = NetworkingService:On("ReplicationRequest", function(request)
		local object = request:Accept()
		if not object then
			return
		end

		-- BUGFIX(local): Accept()는 처음 한 번만 오브젝트를 새로 만들고, 그 뒤로는
		-- Runtime/Networking.luau의 buildRequests가 "isNewObject=false"로 보고
		-- authorityType=="Client"일 때만 다시 ReplicationRequest를 쏴준다. 아무도
		-- authority를 "Client"로 설정한 적이 없어서, 이걸 안 해주면 다른 플레이어
		-- 캐릭터가 처음 한 번만 생성되고 그 뒤 위치/애니메이션 갱신이 전혀 반영되지
		-- 않는다(멈춰있는 것처럼 보임). 방금 로컬에 만든 이 오브젝트를 "Client" 권한으로
		-- 표시해서 앞으로도 계속 갱신을 받게 한다.
		AuthorityService:SetAuthority(object, "Client")

		-- BUGFIX(local): hero.luau는 로컬 플레이어 본인 캐릭터라 Anchored=false(물리 켜짐)
		-- 로 만든다 — 이 값도 그대로 복제돼서, 다른 플레이어의 원격 사본도 각
		-- 클라이언트에서 독립적으로 중력을 받아 "제대로 안 움직이고 계속 떨어지는"
		-- 문제가 있었다. 그렇다고 Anchored=true로 물리를 통째로 꺼버리면 충돌 처리까지
		-- 같이 꺼져서(PhysicalObject.luau: Anchored="물리를 쓸지 여부") 이번엔 반대로
		-- 벽 등 맵의 PhysicalObject에 전혀 안 걸리게 된다. 그래서 Anchored는 복제된 값
		-- (원본과 동일하게 false) 그대로 두고 GravityScale만 0으로 꺼서, 충돌 판정은
		-- 그대로 받으면서 중력만 안 받게 한다 — 단, 이 요청이 내 로컬 캐릭터 자신이면
		-- (Accept()가 그 캐릭터를 그대로 반환) 건드리면 안 된다.
		local myCharacter = CrossPlatformService.Character
		if not myCharacter or object.Id ~= myCharacter.Id then
			object.GravityScale = 0

			-- BUGFIX(local): AnchorPoint는 AppData/Properties.luau의 복제 대상 프로퍼티
			-- 화이트리스트에 없어서 전혀 복제되지 않는다. hero.luau는 로컬 캐릭터에
			-- AnchorPoint=(0.5,1)(발밑 중앙 기준)을 직접 설정하는데, 원격 사본은 이걸
			-- 못 받고 로블록스 기본값(0,0, 좌상단 기준)으로 남는다. 그러면 같은 Position
			-- 값이어도 기준점이 달라서 캐릭터 크기만큼 오른쪽 아래로 밀려 렌더링되고,
			-- 화면상 "땅에 파묻힌 것처럼" 보인다 — 낙하가 아니라 순수 렌더링 오프셋 버그.
			object.Instance.AnchorPoint = Vector2.new(0.5, 1)
		end
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene) end

return exports
