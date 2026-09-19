-- 레벨업 연출: 캐릭터 발밑에서 퍼지는 위로 떠오르는 반짝이 + "LEVEL UP!" 글자.
-- damageNumbers.luau처럼 대상 캐릭터의 Instance에 직접 자식으로 매달아서, 좌표 계산 없이
-- 캐릭터를 따라다니게 한다. modules/ 루트라 sceneLoader가 자동으로 load/unload를 부르지
-- 않는다 — playerStats.luau가 레벨업 신호를 받을 때 직접 Play()를 부른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)

local GOLD = Color3.fromRGB(255, 214, 90)
local GOLD_LIGHT = Color3.fromRGB(255, 244, 190)

local SPARKLE_COUNT = 14
local SPARKLE_DURATION = 1.1
local TEXT_DURATION = 1.4
local TEXT_RISE = 70

local exports = {}

local function spawnSparkle(anchor: GuiObject)
	local size = math.random(5, 10)
	local sparkle = Instance.new("Frame")
	sparkle.Name = "LevelUpSparkle"
	sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
	sparkle.Position = UDim2.new(0.5, math.random(-70, 70), 0.9, math.random(-10, 10))
	sparkle.Size = UDim2.fromOffset(size, size)
	sparkle.BackgroundColor3 = if math.random() < 0.5 then GOLD else GOLD_LIGHT
	sparkle.BorderSizePixel = 0
	sparkle.Rotation = math.random(0, 45)
	sparkle.ZIndex = 46
	sparkle.Parent = anchor
	uiTheme.AddCorner(sparkle, 2)

	local rise = math.random(90, 170)
	local drift = math.random(-25, 25)
	local info = TweenInfo.new(SPARKLE_DURATION * (0.7 + math.random() * 0.5), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(sparkle, info, {
		Position = sparkle.Position + UDim2.fromOffset(drift, -rise),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(2, 2),
	}):Play()
	task.delay(info.Time + 0.05, function()
		sparkle:Destroy()
	end)
end

local function spawnText(anchor: GuiObject)
	local label = Instance.new("TextLabel")
	label.Name = "LevelUpText"
	label.Text = "LEVEL UP!"
	label.FontFace = uiTheme.Font
	label.TextColor3 = GOLD
	label.TextStrokeColor3 = Color3.fromRGB(120, 60, 0)
	label.TextStrokeTransparency = 0.2
	label.TextSize = 30
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -20)
	label.Size = UDim2.fromOffset(200, 40)
	label.ZIndex = 60
	label.Parent = anchor

	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label

	-- 팝업(커지며 등장) → 잠깐 유지하며 위로 떠오름 → 투명해지며 사라짐.
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
	TweenService:Create(label, TweenInfo.new(TEXT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, -20 - TEXT_RISE),
	}):Play()

	task.delay(TEXT_DURATION * 0.6, function()
		local fadeInfo = TweenInfo.new(TEXT_DURATION * 0.4)
		TweenService:Create(label, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(fadeInfo.Time + 0.05, function()
			label:Destroy()
		end)
	end)
end

-- anchor: 캐릭터의 Instance(AnchorPoint가 발밑 중앙(0.5, 1)인 스프라이트).
function exports.Play(anchor: GuiObject)
	if not anchor or not anchor.Parent then
		return
	end

	for _ = 1, SPARKLE_COUNT do
		task.delay(math.random() * 0.35, spawnSparkle, anchor)
	end
	spawnText(anchor)
end

return exports
