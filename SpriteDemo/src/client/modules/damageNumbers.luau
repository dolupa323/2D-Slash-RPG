-- 데미지 숫자 팝업 공용 유틸 — heroController.luau(플레이어가 맞았을 때)와
-- globals/monsterHealthBar.luau(몬스터가 맞았을 때)가 둘 다 쓴다. modules/globals나
-- modules/<씬 이름> 밖(modules/ 루트)에 있어서 sceneLoader가 자동으로 load/start/unload를
-- 부르지 않는다 — travelState.luau와 같은 패턴.
--
-- 대상 오브젝트(히어로/몬스터)의 Instance에 직접 자식으로 매다는 방식을 쓴다 — 그러면
-- 화면 좌표를 우리가 직접 계산할 필요 없이, 부모(캐릭터 스프라이트)가 카메라를 따라
-- 움직이는 대로 자동으로 같이 따라간다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)

-- (Phase 1 전투 타격감, ROADMAP.md — Cheruton DamageVal.gd 패턴 참고) Cheruton은
-- 알파 페이드를 전혀 안 쓰고 "스케일"만으로 등장/소멸을 표현한다: 0.2초 동안 확
-- 커졌다가(팝업), 0.3초 대기 후 0.5초에 걸쳐 작게 쪼그라들며 사라진다. 좌우로는
-- 랜덤한 방향으로 등속 이동, 위로는 일정한 속도로 계속 떠오른다(포물선이 아니라
-- 직선). 이 느낌을 그대로 가져온다 — 이전엔 알파 페이드만 썼는데 훨씬 밋밋했다.
local UPWARD_SPEED = 90 -- px/s, 계속 위로.
local SIDEWAYS_SPEED_RANGE = 40 -- px/s, 좌우 랜덤(-이 값 ~ +이 값).
local POP_DURATION = 0.15 -- 작은 상태 -> 팝업 크기.
local HOLD_DURATION = 0.25 -- 팝업 크기 유지.
local SHRINK_DURATION = 0.4 -- 팝업 크기 -> 소멸 직전 크기.
local START_SCALE = 0.4
local POP_SCALE = 1.15
local END_SCALE = 0.2

local exports = {}

-- color: Color3, amount: number
function exports.Show(anchorInstance: GuiObject, amount: number, color: Color3)
	local label = Instance.new("TextLabel")
	label.Name = "DamageNumber"
	label.Text = "-" .. tostring(amount)
	label.FontFace = uiTheme.Font
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = false
	label.TextSize = 22
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, 0)
	label.Size = UDim2.fromOffset(100, 30)
	label.ZIndex = 50
	label.Parent = anchorInstance

	local scale = Instance.new("UIScale")
	scale.Scale = START_SCALE
	scale.Parent = label

	local sidewaysSpeed = (math.random() * 2 - 1) * SIDEWAYS_SPEED_RANGE

	task.spawn(function()
		local totalDuration = POP_DURATION + HOLD_DURATION + SHRINK_DURATION
		local elapsed = 0
		local x, y = 0, 0

		while elapsed < totalDuration do
			local delta = task.wait()
			elapsed += delta
			x += sidewaysSpeed * delta
			y -= UPWARD_SPEED * delta
			label.Position = UDim2.new(0.5, x, 0, y)

			if elapsed < POP_DURATION then
				scale.Scale = START_SCALE + (POP_SCALE - START_SCALE) * (elapsed / POP_DURATION)
			elseif elapsed < POP_DURATION + HOLD_DURATION then
				scale.Scale = POP_SCALE
			else
				local t = math.clamp((elapsed - POP_DURATION - HOLD_DURATION) / SHRINK_DURATION, 0, 1)
				scale.Scale = POP_SCALE + (END_SCALE - POP_SCALE) * t
			end
		end

		label:Destroy()
	end)
end

return exports
