-- SpaceFighter 예제의 modules/globals/camera.luau 패턴을 재활용.
-- SpaceFighter는 고정 카메라ㅇ(FollowSubject=false)지만, 저희는 탑다운 RPG라 캐릭터를
-- 따라가야 하므로 FollowSubject=true로 바꾸고 start()에서 Subject를 잡아준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local exports = {}

function exports.load(scene: Scene)
	-- sceneLoader.luau(unloadModules)는 unload() 호출 시 scene을 안 넘겨준다(load/start만
	-- 넘김) — 이 프로젝트 다른 전역 모듈들(hud.luau, hero.luau 등)도 전부 load 시점에
	-- 필요한 값을 모듈에 캐싱해뒀다가 unload에서 그 캐시를 쓰는 방식이라 같은 패턴을 쓴다.
	exports.camera = scene.Camera

	local sceneInstance = scene.Instance :: Folder
	scene.Camera.FollowSubject = false
	scene.Camera:SetPosition(UDim2.fromScale(0.5, 0.5))
	sceneInstance.GameFrame.Position = UDim2.fromScale(0.5, 0.5)
end

function exports.start(scene: Scene)
	-- load() 시점엔 아직 캐릭터가 준비 안 됐으므로(글로벌 모듈이 씬 모듈보다 먼저 load됨),
	-- 씬 모듈 load()가 다 끝난 뒤(=CrossPlatformService.Character가 세팅된 뒤) 여기서 구독한다.
	local character = CrossPlatformService.Character
	if character then
		scene.Camera:SetSubject(character)
		scene.Camera.FollowSubject = true
	end
end

-- 카메라 흔들림 (Phase 1 전투 타격감, ROADMAP.md 참고 — Cheruton의 camera_shake.gd
-- 패턴). Camera 클래스 자체에 이 용도로 만들어둔 공개 필드 OffsetPosition이 있다
-- ("이 값만큼 카메라를 원하는 위치로 조정" — Camera.luau 문서 주석 참고) — SetPosition()이
-- `udim2 + self.OffsetPosition`을 최종 위치로 쓰지만 LocalPosition(추적 로직이 다음
-- 프레임 기준으로 삼는 값)은 OffsetPosition을 뺀 순수 udim2로만 갱신하므로, 여기다
-- 흔들림을 넣어도 CameraTracker.luau의 추적 계산에 누적되어 카메라가 점점 밀리는
-- 일이 없다.
function exports.Shake(duration: number, amplitude: number)
	local camera = exports.camera
	if not camera then
		return
	end

	if exports.shakeConnection then
		exports.shakeConnection:Disconnect()
		exports.shakeConnection = nil
	end

	local RunService = game:GetService("RunService")
	local elapsed = 0
	exports.shakeConnection = RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed >= duration then
			camera.OffsetPosition = UDim2.fromOffset(0, 0)
			if exports.shakeConnection then
				exports.shakeConnection:Disconnect()
				exports.shakeConnection = nil
			end
			return
		end

		-- 시간이 지날수록 흔들림 폭이 줄어들게(감쇠) 해서 "쿵" 하고 잦아드는 느낌을 낸다.
		local falloff = 1 - (elapsed / duration)
		local x = (math.random() * 2 - 1) * amplitude * falloff
		local y = (math.random() * 2 - 1) * amplitude * falloff
		camera.OffsetPosition = UDim2.fromOffset(x, y)
	end)
end

function exports.unload(scene: Scene)
	if exports.shakeConnection then
		exports.shakeConnection:Disconnect()
		exports.shakeConnection = nil
	end
	if exports.camera then
		exports.camera.OffsetPosition = UDim2.fromOffset(0, 0)
		exports.camera.FollowSubject = false
		exports.camera = nil
	end
end

return exports
