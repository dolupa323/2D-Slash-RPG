-- 우측 하단 확장형 메뉴 버튼. menu.png를 누르면 기능 버튼들(가방/장비/스킬/퀘스트/지도/
-- 친구/설정/상점)이 메뉴 버튼 위로 세로로 좌르륵 펼쳐지고, 다시 누르면 메뉴 버튼만 남고
-- 접힌다(확대/축소 개념). "I" 키 등 단축키에 바인딩하지 않는다 — 이 프로젝트는 항상
-- 버튼을 만들고 거기 연결해서 여는 방식을 쓴다(로블록스 기본 단축키와 겹치는 문제 방지).
--
-- 에셋: Assets/character/talchar/three/ui/{menu,inven,jangbi,skill,quest,map,friends,
-- setting,shop}.png. 지금 실제로 동작하는 기능은 인벤토리(inventory.luau의
-- exports.toggle())뿐이라 가방 버튼만 연결하고, 나머지는 해당 기능이 생기면 그때
-- 연결한다(지금은 버튼만 보이고 눌러도 아무 일 없음).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)
local inventory = require(script.Parent.inventory)

local BUTTON_HEIGHT = 48
local GAP = 8

local MENU_ASSET = "rbxassetid://104516279303102"
local MENU_NATIVE = Vector2.new(87, 80)

-- 순서대로 메뉴 버튼 바로 위부터 쌓인다.
local FEATURES = {
	{ name = "Inventory", asset = "rbxassetid://89646071035947", native = Vector2.new(124, 113), onClick = function()
		inventory.toggle()
	end },
	{ name = "Equipment", asset = "rbxassetid://102091863177348", native = Vector2.new(119, 111) },
	{ name = "Skill", asset = "rbxassetid://100133287894479", native = Vector2.new(113, 110) },
	{ name = "Quest", asset = "rbxassetid://84502147161347", native = Vector2.new(119, 107) },
	{ name = "Map", asset = "rbxassetid://119686382125867", native = Vector2.new(110, 109) },
	{ name = "Friends", asset = "rbxassetid://73979622489116", native = Vector2.new(121, 115) },
	{ name = "Setting", asset = "rbxassetid://122626414536642", native = Vector2.new(114, 111) },
	{ name = "Shop", asset = "rbxassetid://83427562032639", native = Vector2.new(117, 116) },
}

local exports = {}

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainMenu"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	-- 화면 전체 크기를 그대로 유지하는(스케일 안 걸린) 순수 기준 프레임 — 아래 두
	-- 요소가 여기 기준으로 우하단 코너에 Scale로 앵커링되므로, root 자체는 스케일하지
	-- 않는다(스케일하면 100% 기준점이 안으로 밀려서 코너에서 떨어져 보임).
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	local menuScale = BUTTON_HEIGHT / MENU_NATIVE.Y
	local menuButton = Instance.new("ImageButton")
	menuButton.Name = "MenuButton"
	menuButton.AnchorPoint = Vector2.new(1, 1)
	menuButton.Position = UDim2.new(1, -16, 1, -16)
	menuButton.Size = UDim2.fromOffset(MENU_NATIVE.X * menuScale, MENU_NATIVE.Y * menuScale)
	menuButton.BackgroundTransparency = 1
	menuButton.Image = MENU_ASSET
	menuButton.ZIndex = 2
	menuButton.Parent = root
	-- 버튼 자신에게 걸면 AnchorPoint(1, 1) = 우하단 코너를 중심으로 크기만 줄고
	-- Position은 안 바뀌어서, 화면 우하단 코너에 고정된 채 스케일된다.
	uiTheme.applyResponsiveScale(menuButton)

	local featuresList = Instance.new("Frame")
	featuresList.Name = "Features"
	featuresList.AnchorPoint = Vector2.new(1, 1)
	featuresList.Position = UDim2.new(1, -16, 1, -16 - menuButton.Size.Y.Offset - GAP)
	featuresList.AutomaticSize = Enum.AutomaticSize.Y
	featuresList.Size = UDim2.fromOffset(BUTTON_HEIGHT, 0)
	featuresList.BackgroundTransparency = 1
	featuresList.Visible = false
	featuresList.Parent = root
	uiTheme.applyResponsiveScale(featuresList)

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, GAP)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	listLayout.Parent = featuresList

	for index, feature in FEATURES do
		local scale = BUTTON_HEIGHT / feature.native.Y
		local button = Instance.new("ImageButton")
		button.Name = feature.name
		-- 아래에서 위로 쌓이므로, 목록의 첫 항목(가방)이 메뉴 버튼과 가장 가깝게 오도록
		-- LayoutOrder를 뒤집는다.
		button.LayoutOrder = #FEATURES - index
		button.Size = UDim2.fromOffset(feature.native.X * scale, feature.native.Y * scale)
		button.BackgroundTransparency = 1
		button.Image = feature.asset
		button.Parent = featuresList

		if feature.onClick then
			button.Activated:Connect(feature.onClick)
		end
	end

	menuButton.Activated:Connect(function()
		featuresList.Visible = not featuresList.Visible
	end)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
end

return exports
