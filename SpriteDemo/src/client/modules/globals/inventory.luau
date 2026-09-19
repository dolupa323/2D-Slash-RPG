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
local popupManager = require(script.Parent.Parent.popupManager)
local items = require(ReplicatedStorage.shared.data.items)
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local TweenService = game:GetService("TweenService")

local PANEL_ASSET = "rbxassetid://118251374996221"
local PANEL_NATIVE = Vector2.new(482, 341)
local INNER = { x = 44, y = 47, w = 418, h = 261 } -- 양피지 안쪽 영역(나무 액자 제외)

local CLOSE_ASSET = "rbxassetid://86025600185150"
local CLOSE_NATIVE = Vector2.new(90, 83)

local COLUMNS = balance.INVENTORY_COLUMNS
local ROWS = balance.INVENTORY_ROWS
local SLOT_COUNT = COLUMNS * ROWS
local SLOT_SIZE = 48
local SLOT_GAP = 8

-- 슬롯은 양피지 배경 위에 놓이므로 진한 어두운 옻칠색 대신 반투명 밝은 갈색 계열로.
local SLOT_BG = Color3.fromRGB(210, 195, 165)
local SLOT_BORDER = Color3.fromRGB(120, 95, 60)
local SLOT_HOVER_BORDER = Color3.fromRGB(170, 40, 30)

local exports = {}

-- 마지막으로 받은 인벤토리(UI 수명과 무관하게 세션 내내 유지).
local cachedInventory = nil
local cachedEquipment = {}
local cachedGold = 0
local goldListeners = {}


local function fireEquipAction(action, arg)
	Net.FireServer("EquipAction", action, arg)
end

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
	uiTheme.applyResponsiveScale(panel, PANEL_NATIVE)

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
		-- 아이콘 이미지가 없는 아이템을 위한 글자 자리표시자.
		local placeholder = Instance.new("TextLabel")
		placeholder.Name = "Placeholder"
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.fromScale(1, 1)
		placeholder.FontFace = uiTheme.Font
		placeholder.TextSize = 20
		placeholder.TextColor3 = Color3.fromRGB(70, 45, 20)
		placeholder.Text = ""
		placeholder.ZIndex = 2
		placeholder.Parent = slot.frame
		slot.placeholder = placeholder
		slots[index] = slot
	end

	-- 인벤토리 칸을 누르면 장비면 착용(서버가 검증하고 교체/이동까지 처리).
	for index, slot in slots do
		slot.button.Activated:Connect(function()
			local entry = nil
			for _, e in cachedInventory or {} do
				if e.Slot == index then
					entry = e
				end
			end
			local def = entry and items[entry.ItemId]
			if def and def.EquipSlot then
				fireEquipAction("Equip", index)
			end
		end)
	end

	local goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.BackgroundTransparency = 1
	goldLabel.Position = UDim2.fromOffset(INNER.x + 16, INNER.y + 8)
	goldLabel.Size = UDim2.fromOffset(160, 22)
	goldLabel.FontFace = uiTheme.Font
	goldLabel.TextSize = 16
	goldLabel.TextColor3 = Color3.fromRGB(120, 80, 10)
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Text = ("골드  %d"):format(cachedGold)
	goldLabel.Parent = panel
	exports.goldLabel = goldLabel

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
	uiTheme.AddPressFeedback(closeButton)

	closeButton.Activated:Connect(function()
		popupManager.Close("Inventory")
	end)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
	popupManager.Register("Inventory", screenGui, panel)
	exports.panel = panel
	exports.slots = slots

	-- 방금 만든 UI에 캐시된 인벤토리를 즉시 채운다(씬을 옮기면 UI는 새로 만들어지지만 캐시는
	-- 모듈에 남아있다).
	exports.applyInventory(cachedInventory)
	-- 리스너와 서버 조회는 세션 동안 한 번만 건다 — UI가 씬마다 다시 만들어져도 서버가 보낸
	-- 갱신을 놓치지 않게, 이벤트는 UI가 아니라 이 모듈이 항상 받아서 캐시에 반영한다
	-- (Punch-RPG의 InventoryController처럼 "클라이언트 캐시"와 "UI"를 분리하는 구조).
	if not exports.listening then
		exports.listening = true
		task.spawn(function()
			exports.remoteConnection = Net.OnClient("InventoryUpdated", function(inventoryData)
				exports.applyInventory(inventoryData)
			end)

			exports.goldConnection = Net.OnClient("GoldUpdated", function(gold)
				exports.applyGold(gold)
			end)

			exports.equipmentConnection = Net.OnClient("EquipmentUpdated", function(equipment)
				exports.applyEquipment(equipment)
			end)

			-- 아이템 획득 알림(왼쪽 아래에 "+ 새싹 조각 x1"이 잠깐 떴다 사라짐).
			exports.acquiredConnection = Net.OnClient("ItemAcquired", function(itemId, count)
				exports.showAcquired(itemId, count)
			end)

			-- 접속 직후 서버가 쏜 InventoryUpdated는 이 리스너가 붙기 전에 지나갔을 수 있어서,
			-- 현재 값을 서버에서 직접 받아 캐시를 채운다.
			local ok, data = pcall(function()
				return Net.Invoke("GetPlayerData")
			end)
			if ok and typeof(data) == "table" then
				exports.applyInventory(data.Inventory)
				exports.applyEquipment(data.Equipment)
				exports.applyGold(data.Gold)
			end
		end)
	end
end

-- mainMenu.luau의 가방 버튼이 호출해서 패널을 열고/닫는다.
function exports.toggle()
	if not exports.panel then
		return
	end
	popupManager.Toggle("Inventory")
end

-- inventoryData: 서버가 주는 촘촘한 배열 { { Slot = number, ItemId = string, Count = number }, ... }.
-- 비어있는 칸은 목록에 없다.
function exports.applyInventory(inventoryData: { { Slot: number, ItemId: string, Count: number } }?)
	cachedInventory = inventoryData
	local slots = exports.slots
	if not slots then
		return
	end

	local bySlot = {}
	if inventoryData then
		for _, entry in inventoryData do
			bySlot[entry.Slot] = entry
		end
	end

	for index, slot in slots do
		local entry = bySlot[index]
		local def = entry and items[entry.ItemId]
		if entry and def then
			slot.icon.Image = def.Icon
			slot.count.Text = entry.Count > 1 and tostring(entry.Count) or ""
			-- 아이콘 이미지가 아직 없으면(Icon = "") 이름 앞 두 글자로 대신 표시한다.
			slot.placeholder.Text = if def.Icon == "" then uiTheme.ShortName(def.Name) else ""
		else
			slot.icon.Image = ""
			slot.count.Text = ""
			slot.placeholder.Text = ""
		end
	end
end

-- equipment: { Weapon = ItemId?, Armor = ItemId? }. 장비 UI는 equipment.luau(장비 탭)가 그리고,
-- 이 모듈은 서버가 보낸 값을 캐시해서 그쪽에 알려주기만 한다.
local equipmentListeners = {}

function exports.getGold()
	return cachedGold
end

function exports.onGoldChanged(callback)
	table.insert(goldListeners, callback)
end

function exports.applyGold(gold)
	cachedGold = gold or 0
	if exports.goldLabel then
		exports.goldLabel.Text = ("골드  %d"):format(cachedGold)
	end
	for _, callback in goldListeners do
		callback(cachedGold)
	end
end

function exports.getEquipment()
	return cachedEquipment
end

function exports.onEquipmentChanged(callback)
	table.insert(equipmentListeners, callback)
end

function exports.applyEquipment(equipment)
	cachedEquipment = equipment or {}
	for _, callback in equipmentListeners do
		callback(cachedEquipment)
	end
end

-- 획득 알림 토스트 — 화면 왼쪽 아래에 쌓였다가 2초 뒤 사라진다.
function exports.showAcquired(itemId: string, count: number)
	local gui = exports.screenGui
	local def = if itemId == "Gold" then { Name = "골드" } else items[itemId]
	if not gui or not def then
		return
	end

	exports.toastCount = (exports.toastCount or 0) + 1
	local label = Instance.new("TextLabel")
	label.Name = "AcquiredToast"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 24, 1, -140 - ((exports.toastCount - 1) % 4) * 26)
	label.Size = UDim2.fromOffset(260, 24)
	label.BackgroundTransparency = 1
	label.FontFace = uiTheme.Font
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 244, 190)
	label.TextStrokeTransparency = 0.3
	label.Text = ("+ %s x%d"):format(def.Name, count)
	label.Parent = gui

	task.delay(1.6, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	popupManager.Unregister("Inventory")

	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end

	exports.panel = nil
	exports.goldLabel = nil
	exports.slots = nil

end

return exports
