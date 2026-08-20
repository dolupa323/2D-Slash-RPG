-- 확인된 버그: Tile Palette에서 "충돌 없음"으로 설정한 타일은 canCollide 값 자체를 저장하지
-- 않는다(ReplicatedStorage.UpsideEngineDB JSON 직접 확인: 나무/바위는 "canCollide":true가
-- 저장되지만 잔디/길은 키 자체가 없음). 문제는 이 값이 없을 때 PhysicalObject의 엔진 기본값이
-- CanCollide=true라서(Classes/Public/PhysicalObject.luau), rebuild() 시점에 이미 true로
-- 확정돼버려 스크립트에서 "저장 안 된 값"과 "명시적으로 true"를 구분할 방법이 없다
-- (LoadPluginContent()가 끝나면 원본 JSON도 지워짐). 그래서 get_tilemaps가 쓰는 것과 동일한
-- 신호(ImageRectOffset = 타일 종류)로 분류한다 — 이건 임의 추측이 아니라 타일셋 자체가
-- 이미 구분해둔 값을 그대로 읽는 것: Grass(0)/Path(48)=바닥, Tree(96)/Rock(144)=장애물.
-- ReplicatedStorage.UpsideEngineDB JSON을 직접 열어 실측 확인한 값: Grass는 항상
-- ImageRectOffset=(0,0)이다 (재확인 없이 다른 타일 종류의 오프셋을 추측해서 지우는 건
-- 절대 하지 않는다 — 실제로 그렇게 했다가 정상 배치된 바위 타일을 잘못 삭제한 적이 있다).
local GRASS_OFFSET_X = 0

-- 실측으로 확정된 원인: CanCollide=true 타일과 CanCollide=false 타일이 정확히 맞닿아 있으면
-- (예: 바위-잔디 경계), 그 경계를 스치기만 해도 캐릭터가 정지 상태(Velocity=0)에서도
-- 계속 튕긴다 — GJK/EPA 충돌 알고리즘이 "거의 겹침 0"인 경계에서 부동소수점 오차로
-- 판정이 매 프레임 흔들리는 것으로 보인다(사용자가 직접 grass-rock 경계를 없앤 배치로
-- 재현 자체가 안 되는 것까지 확인함). 모든 충돌 타일의 판정 크기를 줄여서 이 경계 자체를
-- 타일 시각적 경계보다 안쪽으로 당겨, 인접 타일과 딱 맞닿지 않게 한다.
local COLLIDER_HITBOX_SCALE = 0.7

local function shrinkAdjacentColliders(scene)
	local shrunk = 0
	for _, object in scene.Objects do
		if object:IsA("PhysicalObject") and not object:IsA("Character") and object.CanCollide then
			object.HitboxScale = COLLIDER_HITBOX_SCALE
			shrunk += 1
		end
	end
	if shrunk > 0 then
		warn(string.format("Shrunk %d collidable tile hitbox(es) to %.0f%% (seam-jitter fix)", shrunk, COLLIDER_HITBOX_SCALE * 100))
	end
end

local exports = {}

function exports.load(scene: Scene)
	local fixed = 0
	for _, object in scene.Objects do
		if object:IsA("PhysicalObject") and not object:IsA("Character") and object.Instance:IsA("ImageLabel") then
			local rectOffset = object.Instance.ImageRectOffset
			if rectOffset.X == GRASS_OFFSET_X and rectOffset.Y == 0 and object.CanCollide then
				object.CanCollide = false
				fixed += 1
			end
		end
	end
	if fixed > 0 then
		warn(string.format("Fixed %d grass tile(s) with wrongly-true CanCollide (plugin save omission bug)", fixed))
	end

	shrinkAdjacentColliders(scene)
end

function exports.start(scene: Scene) end
function exports.unload(scene: Scene) end

return exports
