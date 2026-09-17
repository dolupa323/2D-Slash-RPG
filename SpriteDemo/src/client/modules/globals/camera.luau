-- SpaceFighter r예제의 modules/globals/camera.luau 패턴을 재활용.
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

function exports.unload(scene: Scene)
	if exports.camera then
		exports.camera.FollowSubject = false
		exports.camera = nil
	end
end

return exports
