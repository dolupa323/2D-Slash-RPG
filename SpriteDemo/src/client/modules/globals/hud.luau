-- 플레이어 상태 HUD — 「오문 닌자전」 팩 UI(공방 「닌자 맵」 탭 「UI」 예시 화면 그대로).
--  왼쪽 위: 패널 안에 레벨(주황 알약) + 이름 + 체력(하트·빨강 게이지) + 경험치(EXP·노랑 게이지·%)
--  오른쪽 위: 엽전
--  오른쪽 아래: 대화(E키와 같은 "Interact") · 공격(F키와 같은 "Attack") 버튼 — 팩 스킬 아이콘, PC·모바일 공용
--             + 설정 · 도감 · 가방 버튼
-- 좌표는 UI 도트 단위, 화면 배율은 pixelUI.Scale(정수배). 게이지는 값이 바뀔 때 부드럽게 따라간다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local UI = require(script.Parent.Parent.ui.pixelUI)
local inventory = require(script.Parent.inventory)
local settings = require(script.Parent.settings)
local dex = require(script.Parent.dex)

local C = UI.colors
local MARGIN = 6 -- 화면 가장자리 여백(도트)
local FILL_SPEED = 9

local exports = {}

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- 화면 모서리에 붙는 상자(정수 배율). anchor = (0,0) 왼쪽 위, (1,0) 오른쪽 위, (1,1) 오른쪽 아래.
local function corner(screenGui: ScreenGui, name: string, anchor: Vector2, w: number, h: number)
	local box = Instance.new("Frame")
	box.Name = name
	box.BackgroundTransparency = 1
	box.AnchorPoint = anchor
	box.Position = UDim2.new(anchor.X, 0, anchor.Y, 0)
	box.Size = UDim2.fromOffset(w + MARGIN * 2, h + MARGIN * 2)
	box.Parent = screenGui
	UI.Scale(box)
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(MARGIN, MARGIN)
	inner.Size = UDim2.fromOffset(w, h)
	inner.Parent = box
	return inner
end

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	screenGui.ResetOnSpawn = false
	-- IgnoreGuiInset 끔(기본) — 로블록스 기본 메뉴 버튼 영역과 안 겹치게.

	-- 왼쪽 위: 레벨·이름·체력·경험치(패널 테두리가 두꺼워 안쪽 여백 10)
	local status = corner(screenGui, "Status", Vector2.new(0, 0), 158, 54)
	UI.Panel(status, 0, 0, 158, 54)
	local pillW = UI.Text.Measure("Lv.100") + 8 -- 가장 긴 레벨 글씨가 들어가는 폭
	UI.Pill(status, 10, 8, pillW, 14)
	local lvLabel = UI.Label(status, "Lv.1", 14, 8, { Color = C.white, Shadow = C.accentD, MaxWidth = pillW - 6, MaxLines = 1 })
	UI.Label(status, Players.LocalPlayer.DisplayName, 10 + pillW + 5, 8, { Color = C.ink, MaxWidth = 158 - 10 - pillW - 5 - 10, MaxLines = 1 })
	UI.Icon(status, "heart", 11, 23)
	local hpBar = UI.Bar(status, 36, 25, 74, "red")
	local hpLabel = UI.Label(status, "", 114, 23, { Color = C.ink, MaxWidth = 34, MaxLines = 1 })
	UI.Label(status, "EXP", 10, 36, { Color = C.accentD, MaxWidth = 24, MaxLines = 1 })
	local expBar = UI.Bar(status, 36, 37, 74, "yellow")
	local expLabel = UI.Label(status, "", 114, 36, { Color = C.ink, MaxWidth = 34, MaxLines = 1 })

	-- 오른쪽 위: 엽전
	local coins = corner(screenGui, "Coins", Vector2.new(1, 0), 108, 28)
	UI.Panel(coins, 0, 0, 108, 28)
	UI.Icon(coins, "coin", 12, 8)
	local goldLabel = UI.Label(coins, "0", 94, 8, { Color = C.ink, Align = "right" })
	local function setGold(gold: number)
		goldLabel:SetText(formatNumber(gold or 0))
		goldLabel.Frame.Position = UDim2.fromOffset(94 - goldLabel.Width, 8)
	end
	setGold(inventory.getGold())
	if not exports.goldHooked then
		exports.goldHooked = true
		inventory.onGoldChanged(function(gold)
			if exports.setGold then
				exports.setGold(gold)
			end
		end)
	end
	exports.setGold = setGold

	-- 오른쪽 아래: 대화 · 공격 버튼(위, 팩 스킬 아이콘 + 키 그림) + 설정 · 도감 · 가방(아래)
	local menu = corner(screenGui, "Menu", Vector2.new(1, 1), 138, 72)
	-- 누르는 동안 키를 누른 것과 같은 입력을 보낸다(PC 키와 같은 액션)
	local function actionButton(x: number, color: string, image: string, key: string, action: string)
		local button = UI.Button(menu, x, 4, 36, 34, { Color = color, Image = image })
		UI.Part(menu, key, x + 40 - UI.Size(key).X, 0).ZIndex = 6 -- 그 행동의 키보드 키(오른쪽 위 모서리에 걸친다)
		local function fire(kind: string)
			CrossPlatformService:Fire(kind, { Action = action, Position = Vector2.zero, KeyCode = { Name = action } })
		end
		button.Instance.MouseButton1Down:Connect(function()
			fire("InputBegin")
		end)
		button.Instance.MouseButton1Up:Connect(function()
			fire("InputEnd")
		end)
		return button
	end
	local dashButton = actionButton(22, "plain", "act_dash", "key_shift", "Dash") -- 대쉬(견습 구르기 / 유파의 대쉬)
	local dashLabel = UI.Label(dashButton.Instance, "", 0, 9, { Color = C.white, Shadow = C.ink, ZIndex = 9, Align = "center", Clamp = false })
	actionButton(62, "plain", "act_talk", "key_e", "Interact")
	actionButton(102, "primary", "act_attack", "key_f", "Attack")
	UI.Button(menu, 6, 42, 30, 30, { Color = "plain", Image = "act_skill", OnClick = function()
		require(script.Parent.ninjutsu).ToggleSkillWindow() -- 스킬 창(K 키)
	end })
	UI.Part(menu, "key_k", 6 + 21, 38).ZIndex = 6
	UI.Button(menu, 40, 42, 30, 30, { Color = "plain", Icon = "gear", OnClick = function()
		settings.toggle()
	end })
	UI.Button(menu, 74, 42, 30, 30, { Color = "plain", Icon = "book", OnClick = function()
		dex.toggle()
	end })
	UI.Button(menu, 108, 42, 30, 30, { Color = "plain", Icon = "bag", OnClick = function()
		inventory.toggle()
	end })

	screenGui.Parent = playerGui
	exports.screenGui = screenGui

	local shown = { hp = nil, exp = nil, dash = "" }
	local function approach(current: number?, target: number, delta: number): number
		if current == nil then
			return target
		end
		local nextValue = current + (target - current) * (1 - math.exp(-FILL_SPEED * delta))
		return if math.abs(target - nextValue) < 0.002 then target else nextValue
	end

	exports.connection = RunService.Heartbeat:Connect(function(delta)
		local character = CrossPlatformService.Character
		if not character then
			return
		end
		lvLabel:SetText("Lv." .. tostring(character.Level or 1))
		-- 대쉬 쿨타임: 버튼 위에 남은 초
		local left = (require(script.Parent.Parent.topDownHero).dashReadyAt or 0) - os.clock()
		local text = if left > 0 then tostring(math.ceil(left)) else ""
		if shown.dash ~= text then
			shown.dash = text
			dashLabel:SetText(text)
			dashLabel.Frame.Position = UDim2.fromOffset((36 - dashLabel.Width) // 2, 9)
		end

		local health = character.Health or 0
		local maxHealth = math.max(character.MaxHealth or 1, 1)
		shown.hp = approach(shown.hp, math.clamp(health / maxHealth, 0, 1), delta)
		hpBar:SetRatio(shown.hp)
		hpLabel:SetText(tostring(math.floor(health + 0.5)))

		local experience = character.Experience or 0
		local maxExperience = math.max(character.MaxExperience or 100, 1)
		local ratio = math.clamp(experience / maxExperience, 0, 1)
		shown.exp = approach(shown.exp, ratio, delta)
		expBar:SetRatio(shown.exp)
		expLabel:SetText(("%d%%"):format(math.floor(ratio * 100)))
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	exports.setGold = nil
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
end

return exports
