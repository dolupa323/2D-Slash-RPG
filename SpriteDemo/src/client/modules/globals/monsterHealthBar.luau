-- 서버 권위 몬스터(server/modules/sproutGrub.luau)는 서버에서 만들어지고 오브젝트
-- 필드(Position/Image/Health 등)만 복제되기 때문에, 화면에 보이는 체력바나 데미지
-- 숫자 같은 "순전히 각 클라이언트 로컬에만 있으면 되는" 장식 UI는 서버가 만들 수 없다
-- (서버가 Instance 자식을 붙여도 그 자식 트리는 복제 대상이 아니다 — 복제되는 건
-- object.Instance 자신의 화이트리스트 속성뿐). 그래서 이 클라이언트 모듈이 몬스터가
-- 새로 리플리케이트될 때마다(NetworkingService의 "Build" 이벤트 — Classes/Internal/
-- Request.luau의 Accept()가 새 오브젝트를 처음 만들 때만 쏜다) 각자 알아서 체력바를
-- 그 오브젝트의 Instance에 자식으로 붙인다. 부모(몬스터 스프라이트)에 직접 매달아두면
-- 좌표 계산 없이 카메라를 따라 저절로 같이 움직인다.
--
-- (실측 버그 이력) 원래는 sproutGrub.luau가 심어둔 커스텀 필드 MonsterKind로 몬스터인지
-- 구분하려 했는데, 실제로 리플리케이트된 클라이언트 사본에서 이 필드가 항상 nil로
-- 왔다(Position/Image/Health 등 표준 필드는 정상 복제되는데 커스텀 필드만 안 됨 —
-- 정확한 엔진 내부 원인은 더 조사 필요). 대신 "실제로 화면에 정상 복제되고 있는 걸
-- 이미 확인한" 이미지(스프라이트 시트 rbxassetid)로 식별한다 — 몬스터는 상태에 따라
-- SHEETS의 6개 이미지 중 하나를 쓰므로 그 6개 중 하나인지로 판정한다.
local MONSTER_SHEET_IMAGES = {
	["rbxassetid://92264999271413"] = true, -- walk_left
	["rbxassetid://100223635620373"] = true, -- walk_right
	["rbxassetid://98419651702250"] = true, -- attack_left
	["rbxassetid://93586067969223"] = true, -- attack_right
	["rbxassetid://107018587663153"] = true, -- hit_left
	["rbxassetid://121503629119574"] = true, -- hit_right
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)
local damageNumbers = require(script.Parent.Parent.damageNumbers)
local camera = require(script.Parent.camera)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local monsterDespawnedRemote = Remotes:WaitForChild("MonsterDespawned")

local BAR_WIDTH = 64
local BAR_HEIGHT = 5 -- 기존 8px는 너무 두꺼웠다.
local BAR_Y_OFFSET = -10 -- 스프라이트 상단에서 이만큼 더 위.

local exports = {}

-- object.Id -> { object, fill, lastHealth }
local tracked = {}

local function attach(object)
	if tracked[object.Id] then
		return
	end
	local instance = object.Instance
	if not instance or not MONSTER_SHEET_IMAGES[instance.Image] then
		return
	end

	-- TEMP DEBUG: 플레이어가 몬스터에 물리적으로 부딪히는 버그 진단 — 클라이언트에
	-- 복제된 몬스터의 CanCollide가 실제로 false인지 확인.
	instance:SetAttribute("DBG_CanCollide", tostring(object.CanCollide))
	instance:SetAttribute("DBG_Anchored", tostring(object.Anchored))

	local track = Instance.new("Frame")
	track.Name = "MonsterHealthBarTrack"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 0, BAR_Y_OFFSET)
	track.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	track.BackgroundColor3 = Color3.new(0, 0, 0)
	track.BackgroundTransparency = 0.35
	track.BorderSizePixel = 0
	track.ZIndex = 20
	track.Parent = instance
	uiTheme.AddCorner(track, "full")

	-- (Phase 1 전투 타격감, ROADMAP.md — Cheruton의 HealthBarMob.gd 이중 바 패턴)
	-- 뒤쪽(slowFill)은 맞은 직후에도 잠깐 그대로 있다가 천천히 줄어들고, 앞쪽
	-- (fastFill)은 즉시 반영된다 — 그 사이 간격이 "방금 깎여나간 만큼"을 잔상처럼
	-- 보여준다(WoW류 게임에서 흔한 연출).
	local slowFill = Instance.new("Frame")
	slowFill.Name = "SlowFill"
	slowFill.BackgroundColor3 = Color3.fromRGB(255, 210, 120)
	slowFill.BorderSizePixel = 0
	slowFill.Size = UDim2.fromScale(1, 1)
	slowFill.ZIndex = 21
	slowFill.Parent = track
	uiTheme.AddCorner(slowFill, "full")

	local fastFill = Instance.new("Frame")
	fastFill.Name = "FastFill"
	fastFill.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
	fastFill.BorderSizePixel = 0
	fastFill.Size = UDim2.fromScale(1, 1)
	fastFill.ZIndex = 22
	fastFill.Parent = track
	uiTheme.AddCorner(fastFill, "full")

	tracked[object.Id] = {
		object = object,
		fastFill = fastFill,
		slowFill = slowFill,
		slowFillScale = 1,
		lastHealth = object.Health or 0,
	}

	object:On("Destroy", function()
		tracked[object.Id] = nil
	end)
end

function exports.load()
	if exports.buildConnection then
		return
	end

	-- (씬을 넘나들 때마다 globals가 다시 load()되므로, 이 리스너는 씬과 무관하게
	-- 한 번만 걸면 된다 — client/modules/globals/replication.luau와 같은 패턴.)
	exports.buildConnection = NetworkingService:On("Build", function(object)
		attach(object)
	end)

	-- (실측 버그 이력) "Build"는 오브젝트가 "처음" 리플리케이트될 때 딱 한 번만 뜬다
	-- (Classes/Internal/Request.luau Accept()의 "isNewObject"일 때만). 서버가 게임
	-- 시작하자마자 만든 초기 몬스터들은 이 모듈이 Build 리스너를 걸기도 전에 이미
	-- 리플리케이트되어 버릴 수 있어서(씬 부트스트랩 과정과의 경쟁 상태), 그 몬스터들은
	-- Build를 영영 놓쳐 체력바도 안 붙고 tracked에도 없어서 나중에 죽어도 despawn 처리가
	-- 안 되고 시체가 남았다 — 체력바 없음/시체 안 사라짐 두 버그가 같은 원인이었다.
	-- 공식 문서(NetworkingService)에 PlayersData가 "클라이언트별로 리플리케이트된
	-- 오브젝트 딕셔너리"라고 명시되어 있다 — 서버가 만든 오브젝트는 UserId 0 밑에
	-- 들어간다(Services/NetworkingService.luau의 replicate() 참고: PlayersData[0][id]).
	-- 리스너를 건 시점에 이미 들어와 있는 것들을 한 번 훑어서 놓친 게 없는지 잡는다.
	for _, object in NetworkingService.PlayersData[0] do
		attach(object)
	end

	-- (실측 버그 이력) 서버가 죽은 몬스터를 Destroy()해도 그건 서버 쪽에만 일어나는
	-- 일이라, 이미 리플리케이트된 이 클라이언트의 로컬 사본(체력바 포함)은 아무 신호도
	-- 못 받고 유령처럼 그대로 남아있었다(간헐적으로 희미한 상태로 멈춰 보인 것도 이
	-- 원인 — 마지막으로 복제된 ImageTransparency 값에서 멈춘 것). 서버가 실제로
	-- Destroy()하기 직전에 쏴주는 이 신호를 받으면 로컬 사본을 통째로 Destroy()해서
	-- 스프라이트+체력바를 한 번에 없앤다(체력바는 Instance 자식이라 부모가 Destroy되면
	-- 같이 사라짐).
	exports.despawnConnection = monsterDespawnedRemote.OnClientEvent:Connect(function(monsterId)
		-- tracked에 없더라도(예: attach()가 어떤 이유로든 못 걸렸던 경우) PlayersData[0]에는
		-- 여전히 남아있을 수 있으니 그쪽도 확인한다 — 방어적으로 이중 확인.
		local data = tracked[monsterId]
		local object = if data then data.object else NetworkingService.PlayersData[0][monsterId]
		if not object then
			return
		end
		tracked[monsterId] = nil
		-- (실측 버그 이력) Destroy()만 부르면 "attempt to index nil with 'Position'"이
		-- Runtime/Networking.luau의 clientInterpolator에서 터졌다 — 리플리케이션으로
		-- 방금 들어온 좌표 갱신이 아직 처리 대기 중(NetworkingService.ReplicationTarget)일
		-- 때 그 오브젝트를 Destroy()하면 Instance가 nil로 비워지는데,
		-- clientInterpolator는 다음 틱에 그 대기열을 그대로 처리하려다 nil이 된
		-- Instance.Position에 접근해서 죽는다. 엔진 자신도 플레이어가 나갈 때 같은
		-- 문제를 피하려고 Destroy() 직전에 이 대기열을 먼저 지운다
		-- (Runtime/Networking.luau의 onPlayerLeave 참고) — 여기서도 똑같이 한다.
		NetworkingService.ReplicationTarget[object] = nil
		object:Destroy()
	end)

	-- 느린 바가 목표치까지 내려가는 데 걸리는 시간(Cheruton HealthBarMob.gd와 동일하게 1.5초).
	local SLOW_FILL_DURATION = 1.5

	exports.connection = RunService.Heartbeat:Connect(function(delta)
		for id, data in tracked do
			local object = data.object
			local health = object.Health or 0
			local maxHealth = math.max(object.MaxHealth or 1, 1)
			local targetScale = math.clamp(health / maxHealth, 0, 1)

			-- 앞쪽(빨강)은 새 값으로 즉시 스냅.
			data.fastFill.Size = UDim2.fromScale(targetScale, 1)

			if health < data.lastHealth then
				damageNumbers.Show(object.Instance, data.lastHealth - health, Color3.fromRGB(255, 255, 255))
				-- Phase 1 전투 타격감 — 몬스터가 맞으면 화면이 살짝 흔들린다(플레이어가
				-- 직접 맞았을 때보다 더 약하게).
				camera.Shake(0.12, 3)
			elseif health > data.lastHealth then
				-- 회복(향후 힐 등)은 뒤쪽 바도 즉시 따라 올려서 어색한 역방향 애니메이션을
				-- 피한다 — Cheruton도 회복 시엔 애니메이션 없이 바로 갱신한다.
				data.slowFillScale = targetScale
			end
			data.lastHealth = health

			-- 뒤쪽(주황, "방금 깎여나간 만큼"을 보여주는 잔상)은 목표치를 향해 천천히
			-- 줄어든다 — 절대 목표치보다 먼저 내려가지 않게 아래로만 보정.
			if data.slowFillScale > targetScale then
				local step = delta / SLOW_FILL_DURATION
				data.slowFillScale = math.max(data.slowFillScale - step, targetScale)
			else
				data.slowFillScale = targetScale
			end
			data.slowFill.Size = UDim2.fromScale(data.slowFillScale, 1)
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports
