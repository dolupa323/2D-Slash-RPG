-- SpaceFighter 예제의 부트스트랩 패턴(src/client/init.client.luau)을 재활용.
-- 우리는 React 기반 UI/도네이션 네트워킹이 필요 없으므로 sceneLoader만 로드한다ㄹ.

-- TouchGui(모바일 조이스틱) 생성을 위해 켜둔 기본 Roblox 캐릭터의 기본 체력 UI는 이
-- 2D 게임과 무관하므로 끈다. SetCoreGuiEnabled는 LocalScript 전용이라 여기서 처리.
local StarterGui = game:GetService("StarterGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- 어느 게임을 켤지는 shared/config/features.luau의 GAME이 정한다.
local features = require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("config"):WaitForChild("features"))
if features.GAME == "lune" then
	require(script:WaitForChild("lune"):WaitForChild("boot")).start()
else
	require(script.sceneLoader)
end
