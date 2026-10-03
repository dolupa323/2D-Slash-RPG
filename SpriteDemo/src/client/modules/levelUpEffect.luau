-- 레벨업 연출: 캐릭터 몸 위 팩 반짝이 이펙트 + "LEVEL UP!" 글자.
-- damageNumbers.luau처럼 대상 캐릭터의 Instance에 직접 자식으로 매달아서, 좌표 계산 없이
-- 캐릭터를 따라다니게 한다. modules/ 루트라 sceneLoader가 자동으로 load/unload를 부르지
-- 않는다 — playerStats.luau가 레벨업 신호를 받을 때 직접 Play()를 부른다.
local TweenService = game:GetService("TweenService")
local packFx = require(script.Parent.packFx)
local pixelText = require(script.Parent.ui.pixelText)

local GOLD = Color3.fromRGB(255, 173, 85) -- 팩 밝은 주황(uiKit colors.accentL)

local TEXT_DURATION = 1.4
local TEXT_RISE = 70

local exports = {}

-- 팩 반짝이 이펙트(FX/Magic/Spark · Boost)를 캐릭터 몸 위에. anchor(캐릭터 그림) 안 좌표라 캐릭터를 따라다닌다.
local function spawnSparkle(anchor: GuiObject)
	for i, name in { "spark", "boost" } do
		packFx.Play(anchor, name, function()
			return Vector2.new(anchor.AbsoluteSize.X / 2, anchor.AbsoluteSize.Y * 0.35)
		end, { delay = (i - 1) * 0.15, zIndex = 9400 })
	end
end

-- (2026-09-29) "LEVEL UP!" 글씨를 우리 도트 글꼴(제목 16px, 금색 + 갈색 그림자)로. 캐릭터 배율(2)보다 조금 크게.
local PIXEL_SCALE = 2
local function spawnText(anchor: GuiObject)
	local glyphs = pixelText.new(anchor, {
		Name = "LevelUpText", Text = "LEVEL UP!", Font = "title", Color = GOLD, Shadow = Color3.fromRGB(150, 83, 64),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -20), ZIndex = 9600, -- 씬 화면은 ZIndex 전역 정렬 — 모든 월드 그림 위로
	})
	local label = glyphs.Frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.3 * PIXEL_SCALE
	scale.Parent = label

	-- 팝업(커지며 등장) → 잠깐 유지하며 위로 떠오름 → 깜빡이며 사라짐(도트 글씨라 반투명 대신 깜빡임).
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 * PIXEL_SCALE }):Play()
	TweenService:Create(label, TweenInfo.new(TEXT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, -20 - TEXT_RISE),
	}):Play()

	task.delay(TEXT_DURATION * 0.6, function()
		for i = 1, 6 do
			if not label.Parent then
				return
			end
			label.Visible = i % 2 == 0
			task.wait(TEXT_DURATION * 0.4 / 6)
		end
		label:Destroy()
	end)
end

-- anchor: 캐릭터의 Instance(AnchorPoint가 발밑 중앙(0.5, 1)인 스프라이트).
function exports.Play(anchor: GuiObject)
	if not anchor or not anchor.Parent then
		return
	end

	spawnSparkle(anchor)
	spawnText(anchor)
end

return exports
