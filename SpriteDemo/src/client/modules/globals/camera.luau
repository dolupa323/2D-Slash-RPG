-- SpaceFighter 예제의 modules/globals/camera.luau 패턴을 재활용.
-- SpaceFighter는 고정 카메라(FollowSubject=false)지만, 저희는 탑다운 RPG라 캐릭터를
-- 따라가야 하므로 FollowSubject=true로 바꾸고 start()에서 Subject를 잡아준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local exports = {}

function exports.load(scene: Scene)
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
	scene.Camera.FollowSubject = false
end

return exports
