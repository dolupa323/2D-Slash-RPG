-- 2D 횡스크롤 캐릭터 공용 구현. village/hero.luau, Backfield/hero.luau 등 여러 씬에서
-- 그대로 재사용하려고 modules/ 루트(씬 폴더 밖)로 뺐다 — sceneLoader.luau는
-- modules/globals와 modules/<현재 씬 이름>만 자동 스캔하므로, 이 파일 자체는 자동으로
-- load/start/unload가 호출되지 않는다. 각 씬 폴더의 hero.luau가
-- `return require(script.Parent.Parent.heroController)`로 이 모듈을 그대로 반환해서
-- 씬 전환 때마다 sceneLoader가 이 파일의 exports.load/start/unload를 호출하게 만든다.
-- require는 Luau에서 캐싱되므로 여러 씬의 hero.luau가 전부 같은 exports 테이블(=같은
-- module-level 상태)을 공유하는데, 씬은 한 번에 하나만 활성화되고 전환 시 이전 씬
-- 모듈의 unload가 먼저 실행되니 상태 충돌은 없다.
--
-- Source: Assets/character/talchar/full-splite/{idle,jump,run}_{left,right}.png
-- 프레임마다 개별 이미지를 올리던 이전 방식(idle/jump/run 합쳐 약 230장)은, Roblox
-- 클라이언트가 이미지를 "화면에 실제로 표시되는 순간" 처음 다운로드하기 때문에 —
-- 애니메이션 전환마다 그 상태의 프레임을 처음 만날 때 다운로드가 끝날 때까지 빈
-- 화면으로 보이는 문제가 있었다(PreloadAsync를 걸어도 재생 속도가 다운로드를
-- 앞질러서 근본적으로 해결이 안 됨). 그래서 상태당 프레임 전체를 한 장의 시트로
-- 합쳐 올려 총 6개 에셋(idle/jump/run × left/right)만 다운로드하면 되게 했다 —
-- 애니메이션 재생 중에는 ImageRectOffset만 바뀌므로 추가 다운로드가 전혀 없다.
--
-- (실측 이력) 예전에 공유 아틀라스를 ImageRectOffset/ImageRectSize로 잘라 쓰는
-- 방식을 시도했다가 화면에 캐릭터가 2개로 겹쳐 보이는 렌더링 버그가 있었다(git
-- fb0095a 대비 diff로 확인) — 원인은 좌우반전에 쓴 "음수 ImageRectSize"였다. 이번엔
-- 애초에 좌우 방향별로 시트가 따로 있어서 좌우반전을 위한 음수 ImageRectSize가
-- 전혀 필요 없다(모든 ImageRectOffset/ImageRectSize가 항상 양수) — 그 버그의
-- 트리거 조건 자체가 없다.
--
-- (실측 이력 2) 원본 시트(idle 3840x2160, jump/run 4480x1800)를 그대로 업로드했더니
-- 캐릭터가 여러 개로 쪼개져 보였다 — 로블록스 이미지 업로드는 1024x1024가 사실상
-- 상한이라 그보다 큰 이미지는 업로드 시 자동으로 축소되는데, 우리가 계산한 크롭
-- 좌표(px)는 원본 해상도 기준이라 축소된 실제 서빙 이미지와 어긋나 있었다. 그래서
-- 6장 전부 1024 이하로(896x360, 1/5 배율) 리사이즈해서 다시 올렸다 — 셀 크기도
-- 128x72로 같이 줄었다.
--
-- 그리드는 셀 128x72(6장 모두 동일), 읽는 순서는 왼쪽→오른쪽, 그 줄 다 읽으면
-- 다음 줄(행 우선) — GIF 원본과 셀별로 대조해서 확인했다. idle/jump/run 전부
-- 7x5=35칸으로 통일되어 있다. 원본 애니메이션은 36프레임인데 첫 프레임(정지
-- 포즈로 추정)이 시트에서 빠져 있다 — 셀 1번이 원본 2번째 프레임부터 시작한다.
-- 이 프로젝트가 우리 자체 프레임 번호만 쓰므로(원본 번호를 참조할 일이 없음) 그냥
-- 35칸을 순서대로 재생하면 된다.
--
-- jump는 이 팩에 상승/하강이 분리된 별도 아트가 없어서(fall 시트 없음), 상승부터
-- 하강까지 35프레임 전체를 한 번에 잇는 애니메이션으로 재생한다 — LOOPING.jump=false
-- 라 재생이 끝나면 마지막(착지 직전 포즈) 프레임에서 멈춰 실제로 착지할 때까지
-- 유지된다.
--
-- 애니메이션은 엔진 기본 SetSpriteSheet/Play() 자동 시스템(idle_left/right, left/right
-- 4개 이름만 지원) 대신 직접 Heartbeat에서 Position 변화를 보고 idle/run/jump를
-- 고른다. 이동/점프/중력 물리 판정은 CrossPlatformService(SetPlayerCharacter)에
-- 그대로 맡긴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local SceneManager = UpsideEngine.GetService("SceneManager")
local scenes = require(ReplicatedStorage.shared.config.scenes)
local travelState = require(script.Parent.travelState)
local damageNumbers = require(script.Parent.damageNumbers)
local camera = require(script.Parent.globals.camera)

-- 서버 권위 몬스터(server/services/monsterAI.luau)가 어그로/피격 판정을 하려면 이
-- 히어로가 어디 있는지, 언제 공격했는지를 알아야 한다 — 서버는 히어로를 직접 안 만드니까
-- (client-authoritative) 기본적으로 좌표를 모른다. server/modules/heroTracking.luau가
-- 만들어둔 전용 RemoteEvent로 직접 알려준다.
local Net = require(ReplicatedStorage.shared.net.net)
-- 몬스터가 서버 권위(server/services/monsterAI.luau)라 "맞았다" 판정 자체는 서버가 하고,
-- 실제 Health 차감은 이 클라이언트가 자기 로컬 히어로에 대고 해야 한다(히어로는
-- client-authoritative 오브젝트라 서버가 직접 필드를 건드릴 수 없음).

-- 2026-09-15: 캐릭터를 talchar(가면 캐릭터)에서 "Warrior"(사무라이) 시트로 교체.
-- Source: Assets/character/talchar/three/Warrior/{idle,jump,run}_{left,right}.png
-- (원본 4480x1800, 7x5칸, 셀 640x360 — 로블록스 데칼 업로드가 1024x1024로 강제
-- 축소되는 걸 확인했으므로(위 이력 참고) 5x7칸, 셀 192x108, 전체 960x756로 다시
-- 패킹해서 1024 이하로 올렸다.)
local CELL = Vector2.new(192, 108)
local DISPLAY_SCALE = 105 / CELL.Y -- 캐릭터 크기 축소 요청: 130px -> 105px
local RUN_SPEED_THRESHOLD = 20
local AIR_SPEED_THRESHOLD = 90
-- 씬마다 바닥 높이가 다른데 이 좌표 하나를 모든 씬에 그대로 썼더니, 그 씬 바닥과 안
-- 맞으면 허공에서 스폰돼 뚝 떨어지는 문제가 있었다. "포탈은 통로다" 개념으로 재설계:
--
-- 1. 포탈로 이동한 경우(travelState.fromScene에 값이 있음, portalController.luau가
--    씬을 넘어가기 직전에 채워둠) — 도착한 씬에서 "Portal_<출발 씬 이름>"(되돌아가는
--    포탈)을 찾아 그 좌표에 스폰한다. 즉 되돌아가는 포탈 자체가 입구이자 출구가 된다.
-- 2. 그게 아니면(게임을 막 시작한 경우 등 "어디서 왔는지"가 없음) — "Spawn"이라는
--    이름의 안전 스폰 오브젝트를 찾아 그 좌표를 쓴다(마을 같은 안전지대 씬에 둔다).
-- 3. 둘 다 없으면 최종 기본값 (0, 0).
--
-- 플러그인에서 오브젝트 이름만 이렇게 지어주면 되고(씬 이름을 정하듯) 코드 수정은
-- 필요 없다. travelState.fromScene은 한 번 쓰고 나면 반드시 지운다 — 안 지우면
-- 다음번 씬 로드(포탈을 안 타고 들어가는 경우, 예: 재접속)에 엉뚱하게 남아있게 된다.
local DEFAULT_SPAWN_POSITION = UDim2.fromOffset(0, 0)
local SPAWN_NAME = "Spawn"
local PORTAL_PREFIX = "Portal_"
-- 죽었을 때 리스폰할 "가장 가까운 마을" — 지금은 마을이 하나뿐이라 고정값이지만,
-- 나중에 마을이 여러 개면 죽은 위치 기준으로 가장 가까운 마을을 찾도록 확장하면 된다.
local TOWN_SCENE_NAME = scenes.TOWN

local function findObjectByName(scene: Scene, name: string)
	for _, object in scene.Objects do
		if object.Name == name and object.Instance then
			return object
		end
	end
	return nil
end

local function findSpawnPosition(scene: Scene): UDim2
	local fromScene = travelState.fromScene
	travelState.fromScene = nil -- 한 번 쓰면 바로 소비(지움).

	if fromScene then
		local returnPortal = findObjectByName(scene, PORTAL_PREFIX .. fromScene)
		if returnPortal then
			return returnPortal.Instance.Position
		end
		warn(
			('heroController: "%s"에서 넘어왔는데 이 씬에 "%s%s"(되돌아가는 포탈)이 없어서 안전 스폰으로 대체합니다.'):format(
				fromScene,
				PORTAL_PREFIX,
				fromScene
			)
		)
	end

	local spawnObject = findObjectByName(scene, SPAWN_NAME)
	if spawnObject then
		return spawnObject.Instance.Position
	end

	return DEFAULT_SPAWN_POSITION
end

-- 상태+방향당 시트 이미지 하나. 프레임 전환은 ImageRectOffset만 바꾼다(재다운로드 없음).
local SHEETS = {
	idle_left = "rbxassetid://135408426447552",
	idle_right = "rbxassetid://91491363836712",
	jump_left = "rbxassetid://131553753197052",
	jump_right = "rbxassetid://71319291970754",
	run_left = "rbxassetid://134239558167604",
	run_right = "rbxassetid://95749792955818",
	attack_left = "rbxassetid://95787153802362",
	attack_right = "rbxassetid://115783148562938",
}

-- (실측 이력 3) 로블록스가 "4096 업로드 지원"이라고 홍보했지만, 실제 데칼 업로드
-- 경로는 2026년 중반 기준으로도 여전히 1024x1024로 강제 축소된다(개발자 포럼 다수
-- 보고 + 우리 자체 Play 테스트로 재확인: 4032x1620으로 올렸다가 예전과 똑같이
-- 여러 프레임이 겹쳐 보이는 버그 재현됨). 그래서 6장 전부 1024 이하 기준(5x7칸,
-- 셀 192x108)으로 통일한다.
--
-- 상태+방향별 그리드: cols(한 줄에 몇 칸), frames(총 프레임 수). 셀 크기는 6장 전부
-- CELL(192x108)로 통일. run의 loopStart/loopEnd는 Warrior 전용 참고 자료(22.gif —
-- run_left와 동일한 애니메이션, 36프레임)를 프레임간 픽셀 차이로 분석해서 찾았다.
-- run_left는 22.gif에서 15~22번째 프레임이 8프레임 주기로 가장 깨끗하게 반복되고
-- (우리 셀 번호=GIF 프레임-1이므로 14~21), run_right는 참고 GIF가 없어서 자체
-- run_right.png의 35프레임을 같은 방식으로 직접 분석했더니 동일하게 14~21에서
-- 반복됐다(두 방향이 서로 다른 방법으로 같은 결과가 나와 교차검증됨).
local GRID = {
	idle_left = { cols = 5, frames = 35 },
	idle_right = { cols = 5, frames = 35 },
	jump_left = { cols = 5, frames = 35 },
	jump_right = { cols = 5, frames = 35 },
	run_left = { cols = 5, frames = 35, loopStart = 14, loopEnd = 21 },
	run_right = { cols = 5, frames = 35, loopStart = 14, loopEnd = 21 },
	attack_left = { cols = 5, frames = 35 },
	attack_right = { cols = 5, frames = 35 },
}

-- idle: 35장 * 1/12s ≈ 2.9s/루프.
-- run: 도입부(1~13) 재생 후 반복 구간(14~21, 8장)만 계속 반복 — 1/14s(0.57s)는 너무
--      빨랐고 1/10s(0.8s)/1/8s(1s)는 너무 느렸다. 8장 * 1/12s ≈ 0.67s/사이클로 그
--      사이로 좁혔다.
-- jump: 상승+하강 35장을 한 번에 잇는 시퀀스라 전체 공중 체공을 커버해야 함 —
--       35장 * 1/30s ≈ 1.17s. LOOPING=false라 재생이 끝나면 마지막 프레임에서
--       멈춰 착지까지 유지된다.
-- attack: 35장 * 1/40s ≈ 0.88s/1회(1/24=1.46s는 느리고 1/60=0.58s는 너무 빠르다는
-- 피드백 반영해서 중간으로). LOOPING=false지만 F를 계속 누르고 있으면(heldActions.attack)
-- 한 번 다 재생된 직후 처음부터 다시 재생한다 — 아래 Heartbeat의 loopEnd 클램프 부분 참고.
local SECONDS_PER_FRAME = {
	idle = 1 / 12,
	jump = 1 / 30,
	run = 1 / 12,
	attack = 1 / 40,
}
-- (실측 버그 이력) OpenMMO(github.com/Julian-adv/OpenMMO) COMBAT.md 참고 — 판정은
-- "애니메이션이 끝나야" 나가는 게 아니라 스윙의 "임팩트 시점"(그 프로젝트 기준 전체
-- 길이의 약 40%)에 딱 맞춰 나가야 한다. 처음엔 사이클이 끝나는 시점(35프레임째)에
-- 판정을 신고했는데, 그러면 실제 캐릭터가 칼을 휘두르는 시점(애니메이션 중간)과 데미지
-- 표시 시점(애니메이션 끝)이 완전히 어긋나 보였다. 35장 중 약 40% 지점인 15번째
-- 프레임으로 옮긴다.
local ATTACK_IMPACT_FRAME = 15
-- (Phase 1 전투 타격감, ROADMAP.md) 임팩트 판정을 한 프레임(점)이 아니라 몇 프레임짜리
-- 구간으로 넓힌다 — 아래 ATTACK_IMPACT_WINDOW_FRAMES 프레임 동안 계속 신고.
local ATTACK_IMPACT_WINDOW_FRAMES = 3
local LOOPING = { idle = true, jump = false, run = true, attack = false }

local exports = {}

-- hero.IsGrounded와 hero.Velocity.Y 둘 다 신뢰할 수 없다(실측 확인: Position.Y가
-- 소수점까지 완전히 고정된 채 가만히 서 있는 동안에도 IsGrounded가 수백 ms 단위로
-- true/false를 오가고, 그때 Velocity.Y도 AIR_SPEED_THRESHOLD를 넘나든다). 그래서
-- 실제로 화면에 보이는 유일한 진실인 Position.Y 자체가 최근 POSITION_WINDOW 동안
-- 얼마나 움직였는지로 "진짜 속도"를 직접 계산해서 쓴다.
local POSITION_WINDOW = 0.12

local ContentProvider = game:GetService("ContentProvider")

local function preloadAllFrames()
	local ids = {}
	for _, id in SHEETS do
		table.insert(ids, id)
	end
	ContentProvider:PreloadAsync(ids)
end

function exports.load(scene: Scene)
	-- 방어적 정리: 씬 전환 시 이전 히어로가 어떤 이유로든(중복 로드, 정리 누락 등) 아직
	-- 남아있으면 새로 만들기 전에 확실히 지운다 — 포탈로 넘어갔더니 이전 씬 모습이
	-- 그대로 남아 "귀신처럼" 겹쳐 보이던 문제의 근본 원인이었다(참조만 nil로 지웠지
	-- 실제 Instance는 안 지웠음).
	if exports.replicationConnection then
		exports.replicationConnection:Disconnect()
		exports.replicationConnection = nil
	end
	if exports.hero then
		exports.hero:Destroy()
		exports.hero = nil
	end

	local spawnPosition = findSpawnPosition(scene)
	exports.spawnPosition = spawnPosition

	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)

	hero.Anchored = false
	-- 플레이어끼리는 물리적으로 부딪히지 않고 서로 지나쳐 다닌다(엔진 사본의 GetCollidingObjects.shouldSkip가 이 플래그를 본다).
	-- 이 필드는 복제되지 않아도 되도록 로컬 히어로에만 걸고, 판정은 "이 히어로 vs 다른 Character" 양방향으로 스킵한다.
	hero.SkipCharacterCollisions = true
	-- 캔버스(300x420)에 세이프 마진(28/39px)이 커서 실제 그림은 그보다 작다 — 실측 후 조정 예정.
	hero.HitboxScale = 0.28
	hero.WalkSpeed = 80
	hero.JumpPower = 150 -- 기본값
	-- 최대 체력은 레벨에 따라 playerStats.luau가 채워준다(테스트용 임시 1000 제거됨).

	local instance = hero.Instance
	instance.AnchorPoint = Vector2.new(0.5, 1) -- 발밑 중앙 기준(바닥에 닿는 지점 고정)
	-- ScaleType 기본값은 Tile이다 — 이전엔 ImageRectSize가 항상 Vector2.zero(크롭 없음)라
	-- 안 드러났지만, 지금처럼 실제로 640x360 하위 영역을 크롭해서 쓰면 그 조각을 작은
	-- Size 박스 안에 원본 픽셀 크기 그대로 반복 타일링해버린다(캐릭터가 여러 개로
	-- 겹쳐 보이는 원인). Stretch로 명시해서 크롭된 한 프레임을 Size 박스에 맞게 늘린다.
	instance.ScaleType = Enum.ScaleType.Stretch
	instance.Image = SHEETS.idle_right
	instance.Position = spawnPosition
	instance.Size = UDim2.fromOffset(CELL.X * DISPLAY_SCALE, CELL.Y * DISPLAY_SCALE)
	instance.ImageRectSize = CELL
	instance.ImageRectOffset = Vector2.zero
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	CrossPlatformService.SideView = true
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	-- 이 hero는 이 클라이언트 로컬에서만 만들어지는 오브젝트라, 이 호출이 없으면 서버도
	-- 다른 플레이어도 내 캐릭터의 존재 자체를 모른다(맵 타일은 ReplicatedStorage에 담긴
	-- 정적 데이터를 각자 독립적으로 읽어서 그리는 거라 별개 — 실시간으로 서로 위치/
	-- 애니메이션을 주고받는 건 NetworkingService를 거쳐야 한다). ReplicateOnChange는
	-- instance.Changed(Position/Image/ImageRectOffset 등)에 물려서, 매초
	-- ReplicationPerSecond(기본 15)회 한도로 서버 경유 브로드캐스트한다 — 서버·다른
	-- 클라이언트 쪽에서 이 요청을 승인/수신하는 리스너는
	-- server/modules/replication.luau, client/modules/globals/replication.luau에 있다.
	-- 반환된 연결을 저장해둔다 — 저장 안 하면 hero:Destroy() 후에도 이 .Changed 연결이
	-- 안 끊겨서, 필드가 다 지워진(table.clear) hero 테이블로 계속 복제를 시도하다가
	-- "attempt to index nil with 'match'" 에러가 반복해서 뜨는 원인이 된다.
	exports.replicationConnection = NetworkingService:ReplicateOnChange(hero)

	exports.hero = hero
end

function exports.start(scene: Scene)
	local RunService = game:GetService("RunService")
	local hero = exports.hero
	if not hero then
		return
	end

	-- (실측 버그 이력) 처음엔 여기에 히트스탑(맞는 순간 애니메이션 잠깐 정지) + 넉백
	-- (맞은 반대 방향으로 velocity 임펄스)을 같이 넣었는데, 넉백이 velocity.X를 바꿔서
	-- "키를 안 누르고 있을 때 velocity로 facing을 정하는" 로직(아래 stateFor 근처)이
	-- 넉백 방향으로 캐릭터를 휙 돌려버렸다 — 몬스터를 마주보고 공격 중에 맞으면 순간
	-- 반대로 돌아서서, 그 상태로 나가는 다음 공격 신고가 엉뚱한 방향(facing)으로 서버에
	-- 전달돼 사거리 판정을 통과 못 해 데미지 숫자도 안 뜨는 연쇄 버그였다. 이 구현에서는
	-- 히트스탑/넉백 둘 다 불필요하다고 판단해서 제거하고, 대신 맞았을 때 캐릭터가 아주
	-- 잠깐 회색으로 깜빡이는 것만 넣는다.
	local HIT_FLASH_COLOR = Color3.fromRGB(120, 120, 120)
	local HIT_FLASH_BLINK_INTERVAL = 0.06
	local HIT_FLASH_BLINK_COUNT = 3
	local hitFlashToken = 0

	local function playHitFlash()
		hitFlashToken += 1
		local token = hitFlashToken
		-- (실측 버그 이력) 깜빡이는 도중에 씬이 바뀌면 hero가 Destroy되어 hero.Instance가 nil이 돼서
		-- "attempt to index nil with 'ImageColor3'"이 났다 — 시작 시점의 Instance를 잡아두고
		-- 매번 아직 살아있는지 확인한다.
		local target = hero.Instance
		local function setColor(color: Color3): boolean
			if hitFlashToken ~= token or not target or not target.Parent then
				return false
			end
			target.ImageColor3 = color
			return true
		end
		task.spawn(function()
			for i = 1, HIT_FLASH_BLINK_COUNT do
				if not setColor(HIT_FLASH_COLOR) then
					return
				end
				task.wait(HIT_FLASH_BLINK_INTERVAL)
				if not setColor(Color3.new(1, 1, 1)) then
					return
				end
				if i < HIT_FLASH_BLINK_COUNT then
					task.wait(HIT_FLASH_BLINK_INTERVAL)
				end
			end
		end)
	end

	-- 몬스터(서버 권위)가 "너 맞았다"고 알려주면, 그 데미지를 내 로컬 히어로에 직접 적용한다.
	exports.monsterAttackedConnection = Net.OnClient("PlayerHealthChanged", function(health, maxHealth, damage, died)
		-- 체력의 진실은 서버다(피해/회복/사망 판정 전부). 서버가 계산한 결과를 그대로 반영하고, 맞았으면 연출만 재생한다.
		if typeof(health) ~= "number" or typeof(maxHealth) ~= "number" then
			return
		end
		hero.MaxHealth = maxHealth
		if typeof(damage) == "number" and damage > 0 then
			damageNumbers.Show(hero.Instance, damage, Color3.fromRGB(255, 70, 70))
			-- Phase 1 전투 타격감(ROADMAP.md) — 맞았을 때 화면이 살짝 흔들리는 피드백.
			camera.Shake(0.2, 6)
			playHitFlash()
		end
		if died then
			-- 서버가 사망을 판정했다 — 리스폰 연출(deathConnection 핸들러)을 실행한다.
			hero:UpdateHealth(0)
		end
		hero.Health = health
	end)

	-- (실측 버그 이력) 사망 시 "이 씬의 Spawn" 지점만 찾고, 없으면 그냥 (0,0)으로
	-- 텔레포트했다 — 그런데 사냥터(Backfield)엔 애초에 Spawn 오브젝트가 없어서(안전
	-- 지대가 아니니까), 몬스터한테 죽으면 사냥터 한복판의 임의 좌표(0,0)로 떨어지곤
	-- 했다. 그 자리가 지형과 안 맞으면 계속 낙하 리셋을 반복하며 "튀는" 것처럼 보였다.
	-- 원래 정한 규칙(세션 초반 설계)대로 되돌린다: 죽으면 "가장 가까운 마을"로
	-- 리스폰한다 — 지금 씬에 Spawn이 있으면(마을처럼 안전지대인 씬) 그대로 쓰고,
	-- 없으면(사냥터 등) 마을 씬으로 이동시켜서 그 씬의 Spawn을 쓰게 한다(포탈과 똑같은
	-- 방식 — scene:Enable()이 sceneLoader.luau의 씬 전환을 그대로 태운다).
	exports.deathConnection = hero:On("Died", function()
		hero.Health = hero.MaxHealth

		local spawnObject = findObjectByName(scene, SPAWN_NAME)
		if spawnObject then
			hero.Instance.Position = spawnObject.Instance.Position
			return
		end

		local townScene = SceneManager:FindByName(TOWN_SCENE_NAME)
		if townScene then
			townScene:Enable()
		else
			warn(('heroController: "%s" 마을 씬을 찾을 수 없어서 안전 좌표로 대체합니다.'):format(TOWN_SCENE_NAME))
			hero.Instance.Position = DEFAULT_SPAWN_POSITION
		end
	end)

	-- 모바일 방향 버튼(mobileControls.luau)은 실제 키보드를 누르는 게 아니라
	-- CrossPlatformService:Fire("InputBegin"/"InputEnd", {Action=...})를 직접 호출한다
	-- (PC 키보드도 엔진 내부적으로 Runtime/CrossPlatformTracker.luau의 inputDetector를
	-- 거쳐 결국 같은 이벤트로 들어옴 — Configs.Keyboard에서 A/D/Left/Right가 전부
	-- Action "Left"/"Right"로 매핑됨). 그런데 이 아래 run 애니메이션 판정은 지금까지
	-- UserInputService:IsKeyDown()으로 실제 물리 키보드만 봐서, 모바일 버튼으로는
	-- 이동은 되는데(엔진 자체 CrossPlatformTracker가 처리) run 애니메이션은 안 켜졌다.
	-- 키보드/모바일/게임패드가 전부 거치는 이 CrossPlatformService 이벤트 하나만 보고
	-- 누름 상태를 추적하면 세 입력 방식이 완전히 동일하게 동작한다.
	-- attack도 heldActions에 넣어서 "F를 누르고 있는 동안" 계속 다시 나가게 한다(연타 없이
	-- 꾹 누르면 연속 공격).
	local heldActions = { left = false, right = false, attack = false }
	-- attackState.active는 "지금 공격 애니메이션 재생 중인가"를 나타내는 별도 플래그다.
	-- 클로저 밖(task.spawn Heartbeat)에서도 읽어야 해서 테이블로 감싼다.
	local attackState = { active = false }
	-- 공격 사거리를 서버가 "정면 방향"으로 판정하려면 현재 바라보는 방향을 같이 신고해야
	-- 한다. facing 자체는 아래 애니메이션 루프(task.spawn) 안에서만 계산되는 로컬
	-- 변수라 이 바깥(onInputBegin)에서 못 읽는다 — 테이블로 감싸서 애니메이션 루프가
	-- 매 프레임 갱신하고 여기서는 그 최신값만 읽는다.
	local facingState = { value = "right" }
	local function onInputBegin(input)
		local action = input.Action and input.Action:lower()
		if action == "attack" then
			-- (실측 버그 이력) 예전엔 여기서 키를 누르는 "그 즉시" 서버에 공격 판정을
			-- 신고했다 — 그러면 F를 광속 연타할 때 애니메이션은 한 번만 재생되는데
			-- 판정(서버 데미지)은 누른 횟수만큼 들어가는 버그가 생겼다. 실제 판정
			-- 신고는 아래 애니메이션 루프에서 스윙 사이클의 "임팩트 프레임"(위
			-- ATTACK_IMPACT_FRAME 주석 참고 — OpenMMO 방식)에서 한 사이클당 딱 한 번만
			-- 하도록 옮겼다 — 여기서는 스윙을 "시작"만 시킨다.
			heldActions.attack = true
			attackState.active = true
			return
		end
		if action and heldActions[action] ~= nil then
			heldActions[action] = true
		end
	end
	local function onInputEnd(input)
		local action = input.Action and input.Action:lower()
		if action and heldActions[action] ~= nil then
			heldActions[action] = false
		end
	end
	exports.inputBeginConnection = CrossPlatformService:On("InputBegin", onInputBegin)
	exports.inputEndConnection = CrossPlatformService:On("InputEnd", onInputEnd)

	-- setup.run()은 모든 모듈의 load/start를 한 스레드에서 순차 호출한다(setup.luau
	-- 참고). preloadAllFrames()를 여기서 그냥 부르면 다 받을 때까지 exports.start()
	-- 자체가 안 끝나서, 뒤이어 호출될 다른 모듈(camera 등)의 start()까지 전부 밀린다.
	-- task.spawn으로 감싸서 exports.start()는 즉시 리턴하게 하고, 프리로드와
	-- Heartbeat 연결은 백그라운드에서 이어서 진행한다(이제 에셋이 6개뿐이라 거의
	-- 즉시 끝난다).
	task.spawn(function()
		preloadAllFrames()
		-- 로딩 화면(loadingScreen.luau/sceneLoader.luau)이 "히어로 애니메이션 시트가 전부
		-- 받아졌는가"를 확인하는 용도 — 안 받아진 상태로 재생하면 첫 동작이 깜빡인다.
		exports.animationReady = true

		local facing = "right"
		local currentState = "idle"
		local currentFrame = 1
		local frameClock = 0
		local elapsed = 0
		local yHistory = {} -- {t, y} 샘플들, 최근 POSITION_WINDOW초 분량만 유지
		local lastY = nil
		local lastElapsed = nil
		-- 이번 스윙 사이클에서 임팩트 프레임 판정을 이미 신고했는지(사이클당 한 번만).
		local impactFired = false

		-- 포물선 정점에서는 estimatedVelocityY가 순간적으로 0 근처를 지나간다. 매 프레임
		-- 속도만으로 상태를 다시 판단하면 정점에서 "착지했다"고 착각해 idle/run으로
		-- 빠졌다가 다시 jump로 튕겨 들어오면서 currentFrame이 1로 리셋되기를 반복한다.
		-- 그래서 "떴다/착지했다"는 순간 속도가 아니라 grounded라는 상태를 따로 든다.
		--
		-- (실측 버그 이력) 착지 판정을 "이륙 직전 높이로 정확히 돌아왔는지"로 했더니,
		-- 실제 물리 정착 위치가 그 높이와 몇 px만 달라도(반복 점프 중 흔함) grounded가
		-- 영원히 false로 남아 마지막 프레임에 고정되는 버그가 있었다. 착지는 절대
		-- 높이가 아니라 "수직으로 실제로 멈췄는지"로 판정한다 — 이미 신뢰성이 검증된
		-- Position 기반 estimatedVelocityY를 재사용: 하강 중(phaseFall) 속도가
		-- SETTLE_THRESHOLD 밑으로 떨어지면 착지. 정점을 막 지난 시점도 속도가 잠깐 0
		-- 근처를 지나가므로, 하강 시작 후 최소 MIN_FALL_DURATION이 지나기 전에는
		-- 착지 판정을 하지 않아 정점과 착지를 구분한다.
		--
		-- phaseFall 자체는 이제 화면에 보이는 프레임에는 영향을 주지 않는다(jump
		-- 시트 하나가 상승+하강을 전부 담당) — 착지 오판을 막는 내부 게이팅 용도로만
		-- 쓴다.
		local SETTLE_THRESHOLD = 10
		local MIN_FALL_DURATION = 0.15
		local grounded = true
		local phaseFall = false
		local fallStartTime = 0

		-- idle은 "동작 사이 중간 경유지"가 아니라 "일정 시간 입력이 없었을 때"만 들어가야
		-- 한다. moving이 단 한 프레임이라도 false면 바로 idle로 튀어버리면, 착지 직후
		-- run 키를 누르고 있어도 잠깐씩 idle이 끼어들거나(입력 폴링 타이밍), 원래
		-- 자연스러운 동작 흐름(jump→run 직행 등)이 전부 idle을 거쳐가는 것처럼 보인다.
		-- 그래서 idle 진입에만 디바운스를 걸고, run/jump로의 전환은 기존처럼 즉시
		-- 이루어지게 한다 — moving이 true가 되는 즉시 idleSince를 지워서 취소한다.
		local IDLE_DELAY = 0.5
		local idleSince = nil

		local function stateFor(moving: boolean, estimatedVelocityY: number, currentTime: number, instantVelocityY: number): string
			if grounded then
				if estimatedVelocityY < -AIR_SPEED_THRESHOLD then
					grounded = false
					phaseFall = false
				end
			else
				if not phaseFall and estimatedVelocityY > 0 then
					phaseFall = true
					fallStartTime = currentTime
				end
				-- 착지 판정은 평균(estimatedVelocityY, POSITION_WINDOW=0.12s 스무딩)이 아니라
				-- 직전 1프레임 변화량(instantVelocityY)으로 본다 — 평균은 정점 오판 방지엔
				-- 좋지만, 실제로 착지한 뒤에도 문턱 아래로 내려가기까지 최대 0.12s가 걸려서
				-- 착지→run 전환이 눈에 띄게 느려 보이는 원인이었다. Position 자체는 멈추면
				-- 완전히 고정된다는 게 이미 확인됐으니 1프레임 델타로도 신뢰할 수 있다.
				if
					phaseFall
					and currentTime - fallStartTime > MIN_FALL_DURATION
					and math.abs(instantVelocityY) < SETTLE_THRESHOLD
				then
					grounded = true
				end
			end

			if not grounded then
				idleSince = nil
				return "jump"
			end

			if moving then
				idleSince = nil
				return "run"
			end

			-- 정지 후보 상태: IDLE_DELAY가 지나기 전까지는 currentState를 그대로 유지해서
			-- (예: 착지 직후라면 jump 마지막 프레임, 달리다 멈췄다면 run) 애니메이션이
			-- 중간에 끊기지 않게 하고, 시간이 다 지나야 실제로 idle로 넘어간다.
			if not idleSince then
				idleSince = currentTime
			end
			if currentTime - idleSince < IDLE_DELAY then
				return currentState
			end

			return "idle"
		end

		exports.connection = RunService.Heartbeat:Connect(function(delta)
			local instance = hero.Instance
			elapsed += delta

			if instance.Position.Y.Offset >= 1000 then
				hero.Velocity = Vector2.zero
				instance.Position = exports.spawnPosition or DEFAULT_SPAWN_POSITION
				yHistory = {}
				grounded = true
				phaseFall = false
				lastY = nil
				lastElapsed = nil
				idleSince = nil
			end

			local currentY = instance.Position.Y.Offset
			table.insert(yHistory, { t = elapsed, y = currentY })
			while #yHistory > 1 and elapsed - yHistory[1].t > POSITION_WINDOW do
				table.remove(yHistory, 1)
			end

			local estimatedVelocityY = 0
			local oldest = yHistory[1]
			local span = elapsed - oldest.t
			if span > 0 then
				estimatedVelocityY = (currentY - oldest.y) / span
			end

			local instantVelocityY = 0
			if lastY and lastElapsed then
				local instantSpan = elapsed - lastElapsed
				if instantSpan > 0 then
					instantVelocityY = (currentY - lastY) / instantSpan
				end
			end
			lastY = currentY
			lastElapsed = elapsed

			local velocity = hero.Velocity or Vector2.zero
			local leftHeld = heldActions.left
			local rightHeld = heldActions.right
			-- moving은 오직 "지금 이동 키가 눌려있는가"로만 정해야 한다. 예전엔 키를 뗀
			-- 뒤에도 관성으로 velocity.X가 잠깐 안 죽으면 이 값이 moving=true로 되살아나서
			-- (아래 facing 분기에서), 키를 놓아도 run 애니메이션이 감속이 끝날 때까지
			-- 계속 재생되는 버그가 있었다(run이 "끝까지 재생되고 나서야" idle로 바뀌는
			-- 것처럼 보임). facing만 속도로 보정하고 moving 자체는 건드리지 않는다.
			local moving = leftHeld ~= rightHeld

			if leftHeld and not rightHeld then
				facing = "left"
			elseif rightHeld and not leftHeld then
				facing = "right"
			elseif velocity.X < -RUN_SPEED_THRESHOLD then
				facing = "left"
			elseif velocity.X > RUN_SPEED_THRESHOLD then
				facing = "right"
			end
			facingState.value = facing

			local nextStateName = stateFor(moving, estimatedVelocityY, elapsed, instantVelocityY)
			-- 공격은 이동/점프 판정과 별개로 "누른 순간 한 번" 우선 재생되는 오버레이
			-- 상태다 — stateFor가 뭘 고르든 attackState.active가 켜져 있으면 attack으로
			-- 덮어쓴다. 실제로 attack 재생이 끝나는 시점(아래 loopEnd 클램프 부분)에서
			-- attackState.active를 꺼야 다음 프레임에 stateFor 결과로 되돌아간다.
			if attackState.active then
				nextStateName = "attack"
			end
			-- 엔진 내부(CrossPlatformTracker.luau characterController)가 점프를 트리거할 때
			-- 보는 게 바로 이 character.IsGrounded 값이다 — 엔진 자체 계산은 신뢰할 수
			-- 없어서(위 POSITION_WINDOW 주석 참고, 가만히 있어도 수백 ms 단위로 깜빡임)
			-- 그 순간에 점프 키를 누르면 씹혔다. 우리가 Position 기반으로 계산한 훨씬
			-- 안정적인 grounded 값을 매 프레임 엔진에 되돌려줘서 점프 판정 자체를 안정화한다.
			--
			-- (실측 버그 이력) 이 override를 무조건 매 프레임 덮어썼더니 점프가 "엄청
			-- 높이" 뛰는 버그가 생겼다 — Character:Jump()는 호출되는 그 즉시
			-- self.IsGrounded=false를 정확하게(지연 없이) 세팅하는데, 우리 grounded는
			-- POSITION_WINDOW(0.12s)만큼의 Position 변화량을 누적해서 판단하므로 점프
			-- 시작 직후 몇 프레임 동안은 아직 "떴다"고 못 느끼고 true로 남아있었다. 그
			-- 몇 프레임 사이에 우리가 hero.IsGrounded를 다시 true로 덮어써버리면,
			-- CrossPlatformTracker.luau의 characterController가 "Up"이 눌려있는 한 매
			-- 프레임 재확인하다가 그 찰나에 또 IsGrounded=true를 보고 Jump()를 또
			-- 호출해버려서(Velocity가 매번 추가로 깎여나감) 임팩트가 여러 번 겹쳐
			-- 쌓였다. Character:Jump()가 점프 시작~착지까지 true로 켜두는
			-- hero.IsJumping을 같이 봐서, 점프가 진행 중일 때는 절대 true로 덮어쓰지
			-- 않는다 — 그래야 방금 막 시작된 점프의 IsGrounded=false를 다음 프레임에
			-- 우리가 다시 뒤집어버리는 일이 없다.
			hero.IsGrounded = grounded and not hero.IsJumping
			if nextStateName ~= currentState then
				currentState = nextStateName
				currentFrame = 1
				frameClock = 0
				if nextStateName == "attack" then
					impactFired = false
				end
			else
				frameClock += delta
				while frameClock >= SECONDS_PER_FRAME[currentState] do
					frameClock -= SECONDS_PER_FRAME[currentState]
					currentFrame += 1
				end
			end

			-- OpenMMO 방식(위 ATTACK_IMPACT_FRAME 주석 참고): 판정은 사이클이 끝날 때가
			-- 아니라 스윙 중간의 "임팩트 프레임"에서 이루어진다. Cheruton은 판정을 "점"이
			-- 아니라 "몇 프레임짜리 구간"으로 켜두는데(실제 히트박스가 여러 프레임 동안
			-- 켜져 있음), 우리도 임팩트 프레임 근처 ATTACK_IMPACT_WINDOW_FRAMES 프레임
			-- 구간 동안 매 프레임 신고해서 프레임 드롭/렉으로 정확히 그 한 프레임을
			-- 건너뛰어도 맞도록 관대하게 만든다 — 서버(monsterAI.luau)가 같은 스윙 안의
			-- 중복 신고를 쿨다운으로 걸러서 데미지가 중복 적용되지는 않는다.
			if
				currentState == "attack"
				and currentFrame >= ATTACK_IMPACT_FRAME
				and currentFrame < ATTACK_IMPACT_FRAME + ATTACK_IMPACT_WINDOW_FRAMES
			then
				impactFired = true
				Net.FireServer("ReportHeroAttack", facingState.value)
			end

			local grid = GRID[currentState .. "_" .. facing]
			local loopEnd = grid.loopEnd or grid.frames
			local loopStart = grid.loopStart or 1
			if currentFrame > loopEnd then
				if currentState == "attack" then
					if heldActions.attack then
						-- F를 계속 누르고 있으면 한 번 다 재생된 즉시 처음부터 다시(연속
						-- 공격) — 다음 사이클의 임팩트 판정을 다시 받을 수 있게 리셋.
						currentFrame = 1
						frameClock = 0
						impactFired = false
					else
						-- 뗐으면 오버레이 해제 — 다음 프레임의 stateFor 결과(idle/run/jump)로 복귀.
						attackState.active = false
						currentFrame = loopEnd
					end
				else
					currentFrame = if LOOPING[currentState] then loopStart else loopEnd
				end
			end

			local col = (currentFrame - 1) % grid.cols
			local row = (currentFrame - 1) // grid.cols

			instance.Image = SHEETS[currentState .. "_" .. facing]
			instance.ImageRectSize = CELL
			instance.ImageRectOffset = Vector2.new(col * CELL.X, row * CELL.Y)

			-- BUGFIX(local): CrossPlatformService:SetPlayerCharacter(hero)가 내부적으로
			-- CrossPlatformTracker의 자동 애니메이션 시스템(animationPlayer)을 매 프레임
			-- 돌리는데, 이게 우리가 부른 적도 없는 hero:Play(...)를 자기 마음대로 호출해서
			-- hero.IsPlaying을 계속 true로 만든다. 그런데 NetworkingService.luau의
			-- getInstanceData()는 "object:IsA(Sprite)이고 IsPlaying이면 ImageRectOffset을
			-- 복제 데이터에서 아예 뺀다"고 되어 있다(엔진 자체 SetSpriteSheet/Play 시스템을
			-- 쓸 때 프레임 진행을 각 클라이언트가 알아서 로컬로 재생하게 하려는 용도) —
			-- 우리는 그 시스템을 안 쓰고 직접 ImageRectOffset을 계산해서 넣는데 IsPlaying만
			-- 남의 손에 true로 켜져서, 다른 플레이어에게 위치는 복제되는데 애니메이션
			-- 프레임(ImageRectOffset)만 통째로 빠지는 원인이었다. CrossPlatformTracker가
			-- 우리보다 먼저 이 프레임에 Heartbeat를 도니, 우리 쪽에서 매 프레임 마지막에
			-- 다시 꺼서 무효화한다.
			hero.IsPlaying = false
		end)
	end)
end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	if exports.inputBeginConnection then
		exports.inputBeginConnection:Disconnect()
		exports.inputBeginConnection = nil
	end
	if exports.inputEndConnection then
		exports.inputEndConnection:Disconnect()
		exports.inputEndConnection = nil
	end
	if exports.replicationConnection then
		exports.replicationConnection:Disconnect()
		exports.replicationConnection = nil
	end
	if exports.monsterAttackedConnection then
		exports.monsterAttackedConnection:Disconnect()
		exports.monsterAttackedConnection = nil
	end
	if exports.deathConnection then
		exports.deathConnection:Disconnect()
		exports.deathConnection = nil
	end
	-- 참조만 지우면 Roblox Instance(스프라이트)는 이전 씬의 GameFrame 안에 그대로
	-- 남아있는다 — 명시적으로 Destroy해야 실제로 사라진다.
	if exports.hero then
		exports.hero:Destroy()
		exports.hero = nil
	end
	exports.spawnPosition = nil
	exports.animationReady = false
end

return exports
