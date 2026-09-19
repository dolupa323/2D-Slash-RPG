-- 게임 시작/씬 전환 때 화면을 검게 가려두고, 그 씬에 필요한 것들(히어로 생성, 저장된
-- 레벨 적용 등)이 전부 준비된 뒤에 페이드로 걷어내는 블랙아웃. 이게 없으면 준비가
-- 덜 된 상태로 게임이 바로 시작돼서 "될 때도 있고 안 될 때도 있는" 타이밍 버그가 났다.
-- modules/ 루트에 있어서 sceneLoader가 자동으로 load/unload를 부르지 않는다(travelState와
-- 같은 패턴) — sceneLoader.luau와 portalController.luau가 직접 require해서 쓴다.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FADE_OUT_TIME = 0.35

local exports = {}

local screenGui = nil
local frame = nil
local fadeTween = nil

local function ensureGui()
	if screenGui and screenGui.Parent then
		return
	end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LoadingScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000

	frame = Instance.new("Frame")
	frame.Name = "Blackout"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Active = true -- 로딩 중 뒤쪽 UI 클릭 차단
	frame.Parent = screenGui

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- 즉시 완전히 검게 가린다(페이드 없음).
function exports.Show()
	ensureGui()
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
	frame.BackgroundTransparency = 0
	screenGui.Enabled = true
end

-- 서서히 걷어낸다.
function exports.Hide()
	if not screenGui or not screenGui.Enabled then
		return
	end
	if fadeTween then
		fadeTween:Cancel()
	end
	local tween = TweenService:Create(frame, TweenInfo.new(FADE_OUT_TIME), { BackgroundTransparency = 1 })
	fadeTween = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and fadeTween == tween then
			screenGui.Enabled = false
			fadeTween = nil
		end
	end)
	tween:Play()
end

return exports
