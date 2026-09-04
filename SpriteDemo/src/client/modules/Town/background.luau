-- Parallax 배경 텍스처 연결 전용 모듈.
-- Parallax 오브젝트의 실제 이미지는 Instance(Frame)가 아니라 그 자식 Content(ImageLabel)에
-- 붙는데, UpsideEngine 플러그인의 저장/복원(PluginSupportService)은 오브젝트 자기 자신의
-- Instance 최상위 속성만 캡처하고 자식 Instance는 훑지 않는다. 그래서 Explorer에서 Content의
-- Image 속성을 직접 채워도 Studio Edit 화면에는 보이지만 Play 시 재조립되면서 사라진다.
-- 배치(Scene, CanvasSize, Offset, Track 등)는 플러그인으로 그대로 하고, 텍스처만 여기서
-- SetTexture()로 코드로 연결해서 이 문제를 우회한다.
local BACKGROUND_TEXTURE = "rbxassetid://82531951210340"

local exports = {}

function exports.load(scene: Scene)
	for _, object in scene.Objects do
		if not object:IsA("Parallax") then
			continue
		end

		object:SetTexture(BACKGROUND_TEXTURE)
	end
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene) end

return exports
