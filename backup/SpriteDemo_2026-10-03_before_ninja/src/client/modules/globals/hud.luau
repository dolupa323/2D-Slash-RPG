-- 플레이어 상태 HUD — 에셋 공방 UI 탭 "HUD" 예시 화면 그대로(2026-09-29 도트 UI로 교체).
--  왼쪽 위: 패널 안에 레벨(분홍 알약) + 이름 + 체력(하트·빨강 게이지) + 경험치(별·노랑 게이지·%)
--  오른쪽 위: 코인(골드)
--  오른쪽 아래: 대화(흰색, E키와 같은 "Interact") · 공격(분홍, F키와 같은 "Attack") 버튼 — PC·모바일 공용
--             + 설정 · 도감 · 가방 버튼(모두 흰색)
-- 좌표는 UI 도트 단위, 화면 배율은 pixelUI.Scale(정수배). 예전 동양풍 틀 HUD는 git 기록에 있다.
-- 게이지는 값이 바뀔 때 부드럽게 따라간다.
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
local petBox = require(script.Parent.petBox)

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

	-- 왼쪽 위: 레벨·이름·체력·경험치
	local status = corner(screenGui, "Status", Vector2.new(0, 0), 156, 58)
	UI.Panel(status, 0, 0, 156, 58)
	UI.Pill(status, 7, 6, 36, 15)
	local lvLabel = UI.Label(status, "Lv.1", 11, 7, { Color = C.white })
	UI.Label(status, Players.LocalPlayer.DisplayName, 49, 7, { Color = C.ink })
	UI.Icon(status, "heart", 6, 23)
	local hpBar = UI.Bar(status, 21, 25, 96, "red")
	local hpLabel = UI.Label(status, "", 122, 23, { Color = C.ink })
	UI.Icon(status, "star", 6, 37)
	local expBar = UI.Bar(status, 21, 39, 96, "yellow")
	local expLabel = UI.Label(status, "", 122, 37, { Color = C.ink })

	-- 오른쪽 위: 코인
	local coins = corner(screenGui, "Coins", Vector2.new(1, 0), 76, 24)
	UI.Panel(coins, 0, 0, 76, 24)
	UI.Icon(coins, "coin", 6, 5)
	local goldLabel = UI.Label(coins, "0", 70, 5, { Color = C.ink, Align = "right" })
	local function setGold(gold: number)
		goldLabel:SetText(formatNumber(gold or 0))
		goldLabel.Frame.Position = UDim2.fromOffset(70 - goldLabel.Width, 5)
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

	-- 오른쪽 아래: 대화 · 공격 버튼(위) + 설정 · 도감 · 몬스터 상자(발바닥) · 가방(아래)
	local menu = corner(screenGui, "Menu", Vector2.new(1, 1), 132, 66)
	-- 누르는 동안 키를 누른 것과 같은 입력을 보낸다(PC 키와 같은 액션)
	local function actionButton(x: number, color: string, text: string, action: string)
		local button = UI.Button(menu, x, 0, 44, 32, { Color = color, Text = text })
		local function fire(kind: string)
			CrossPlatformService:Fire(kind, { Action = action, Position = Vector2.zero, KeyCode = { Name = action } })
		end
		button.Instance.MouseButton1Down:Connect(function()
			fire("InputBegin")
		end)
		button.Instance.MouseButton1Up:Connect(function()
			fire("InputEnd")
		end)
	end
	actionButton(40, "white", "대화", "Interact")
	actionButton(88, "pink", "공격", "Attack")
	UI.Button(menu, 0, 36, 30, 30, { Color = "white", Icon = "gear", OnClick = function()
		settings.toggle()
	end })
	UI.Button(menu, 34, 36, 30, 30, { Color = "white", Icon = "book", OnClick = function()
		dex.toggle()
	end })
	UI.Button(menu, 68, 36, 30, 30, { Color = "white", Icon = if UI.Has("icon_paw") then "paw" else "star", OnClick = function()
		petBox.toggle()
	end })
	UI.Button(menu, 102, 36, 30, 30, { Color = "white", Icon = "bag", OnClick = function()
		inventory.toggle()
	end })

	screenGui.Parent = playerGui
	exports.screenGui = screenGui

	local shown = { hp = nil, exp = nil }
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
