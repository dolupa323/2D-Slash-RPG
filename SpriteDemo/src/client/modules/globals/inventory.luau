-- 인벤토리 슬롯 그리드. HUD와 마찬가지로 Scene 밖의 자체 ScreenGui로 화면에 고정한다.
--
-- 에셋(2번째로 받은 세트): Assets/character/talchar/three/ui/{big ui, x}.png.
-- big ui.png(482x341)는 인벤토리/장비/퀘스트 등 여러 패널이 공용으로 쓰는 나무 액자
-- 배경(안쪽은 빈 양피지) — 슬롯 그리드는 안쪽 빈 공간에 코드로 그린다(uiTheme.mkSlot).
-- 안쪽 양피지 영역은 PIL로 실측: x:[44,462] y:[47,308] (네이티브 해상도 기준, 패널을
-- 그대로 1:1로 쓰므로 배율 계산 없이 이 좌표를 그대로 쓴다). x.png(90x83)는 닫기 버튼.
--
-- 예전엔 이 모듈 안에 가방 아이콘 토글 버튼이 있었지만, 이제 mainMenu.luau의 확장형
-- 메뉴(가방/장비/퀘스트 등 버튼들이 메뉴 버튼에서 좌르륵 펼쳐지는 방식)가 그 역할을
-- 대신하므로 exports.toggle()만 노출하고 자체 토글 버튼은 만들지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)

local PANEL_ASSET = "rbxassetid://118251374996221"
local PANEL_NATIVE = Vector2.new(482, 341)
local INNER = { x = 44, y = 47, w = 418, h = 261 } -- 양피지 안쪽 영역(나무 액자 제외)

local CLOSE_ASSET = "rbxassetid://86025600185150"
local CLOSE_NATIVE = Vector2.new(90, 83)

local COLUMNS = 4
local ROWS = 4
local SLOT_COUNT = COLUMNS * ROWS
local SLOT_SIZE = 48
local SLOT_GAP = 8

-- 슬롯은 양피지 배경 위에 놓이므로 진한 어두운 옻칠색 대신 반투명 밝은 갈색 계열로.
local SLOT_BG = Color3.fromRGB(210, 195, 165)
local SLOT_BORDER = Color3.fromRGB(120, 95, 60)
local SLOT_HOVER_BORDER = Color3.fromRGB(170, 40, 30)

local exports = {}

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Inventory"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	-- 화면 전체 크기를 그대로 유지하는(스케일 안 걸린) 순수 기준 프레임 — 패널의
	-- Scale 기반 중앙 정렬(0.5, 0.5)이 이 프레임의 실제 화면 크기를 기준으로 계산돼야
	-- 하므로, 여기엔 UIScale을 걸지 않는다.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	local panel = Instance.new("ImageLabel")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_NATIVE.X, PANEL_NATIVE.Y)
	panel.BackgroundTransparency = 1
	panel.Image = PANEL_ASSET
	panel.Visible = false -- 기본은 닫힌 상태
	panel.Parent = root

	-- panel 자신에게 UIScale을 걸면 panel의 AnchorPoint(0.5, 0.5)를 중심으로 크기만
	-- 줄어들고(자식들도 같이) Position은 안 바뀌므로, 화면 중앙에 그대로 고정된 채
	-- 해상도에 맞게 커지고 작아진다.
	uiTheme.applyResponsiveScale(panel)

	local gridWidth = COLUMNS * SLOT_SIZE + (COLUMNS - 1) * SLOT_GAP
	local gridHeight = ROWS * SLOT_SIZE + (ROWS - 1) * SLOT_GAP

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(INNER.x + (INNER.w - gridWidth) / 2, INNER.y + (INNER.h - gridHeight) / 2)
	grid.Size = UDim2.fromOffset(gridWidth, gridHeight)
	grid.Parent = panel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	gridLayout.CellPadding = UDim2.fromOffset(SLOT_GAP, SLOT_GAP)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local slots = {}
	for index = 1, SLOT_COUNT do
		local slot = uiTheme.mkSlot({
			Name = "Slot" .. index,
			Parent = grid,
			LayoutOrder = index,
			BackgroundColor3 = SLOT_BG,
			BackgroundTransparency = 0.25,
			StrokeColor = SLOT_BORDER,
			HoverStrokeColor = SLOT_HOVER_BORDER,
		})
		slots[index] = slot
	end

	-- 나무 액자 테두리 위가 아니라 안쪽 양피지 영역 안에 완전히 들어오도록, INNER
	-- 사각형 기준으로 우상단에서 살짝 안쪽으로 띄워서 배치한다.
	local closeScale = 30 / CLOSE_NATIVE.Y
	local closeSize = Vector2.new(CLOSE_NATIVE.X * closeScale, CLOSE_NATIVE.Y * closeScale)
	local closeButton = Instance.new("ImageButton")
	closeButton.Name = "CloseButton"
	closeButton.Position = UDim2.fromOffset(INNER.x + INNER.w - closeSize.X - 6, INNER.y + 6)
	closeButton.Size = UDim2.fromOffset(closeSize.X, closeSize.Y)
	closeButton.BackgroundTransparency = 1
	closeButton.Image = CLOSE_ASSET
	closeButton.Parent = panel

	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
	exports.panel = panel
	exports.slots = slots

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local inventoryUpdated = remotes:WaitForChild("InventoryUpdated")

		exports.remoteConnection = inventoryUpdated.OnClientEvent:Connect(function(inventoryData)
			exports.applyInventory(inventoryData)
		end)
	end)
end

-- mainMenu.luau의 가방 버튼이 호출해서 패널을 열고/닫는다.
function exports.toggle()
	if not exports.panel then
		return
	end
	exports.panel.Visible = not exports.panel.Visible
end

-- inventoryData: { [slotIndex] = { ItemId = string, Count = number } }, 비어있는 칸은 nil.
function exports.applyInventory(inventoryData: { [number]: { ItemId: string, Count: number } }?)
	local slots = exports.slots
	if not slots then
		return
	end

	for index, slot in slots do
		local item = inventoryData and inventoryData[index]
		if item then
			slot.icon.Image = "" -- 아이템 이미지 에셋 오면 여기에 ItemId -> assetId 매핑해서 채움
			slot.count.Text = item.Count > 1 and tostring(item.Count) or ""
		else
			slot.icon.Image = ""
			slot.count.Text = ""
		end
	end
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.remoteConnection then
		exports.remoteConnection:Disconnect()
		exports.remoteConnection = nil
	end

	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end

	exports.panel = nil
	exports.slots = nil
end

return exports
