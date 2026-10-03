-- 인벤토리(가방) — 에셋 공방 UI 탭 "가방" 예시 화면 + 탭(2026-09-29).
--  위: "가방" 제목판, 탭 5개(장비·소비·기타·캐시·중요 — 누르면 그 탭 아이템만), 오른쪽 위 닫기.
--  왼쪽: 6x4 칸(탭마다 칸이 따로). 칸을 누르면 선택 → 오른쪽에 큰 아이콘·이름·설명 + [장착/사용] [버리기].
--  드래그 앤 드롭: 칸을 누른 채 끌어서 다른 칸에 놓으면 자리 바꾸기(같은 아이템이면 합치기) — 서버(MoveItem)가 처리.
--  버리기: 서버(DropItem)가 가방에서 빼서 발밑 땅에 떨어뜨린다(월드 드랍 — 같은 씬 누구나 주울 수 있고, 시간이 지나면 사라짐).
--  중요 물품은 버릴 수 없다. 왼쪽 아래 골드. 물약은 [사용]으로 먹는다(서버 UseItem — 체력 회복, 1개 줄임).
--  소비 아이템(방울·물약)은 [1][2][3]으로 소비 단축칸(globals/quickslots.luau)에 놓는다 — 전투 중 숫자키/터치로 바로 쓴다.
--  방울 상세 설명에는 그 방울의 "기본 포획률"만 나온다(종합 확률 = 기본 + 레벨 보정 + 체력 보정 — 서버만 계산, 화면엔 안 나옴).
-- HUD의 가방 버튼이 exports.toggle()을 부른다. 서버 데이터 캐시(인벤토리·골드·장비)는 UI와 별개로 유지된다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local popupManager = require(script.Parent.Parent.popupManager)
local items = require(ReplicatedStorage.shared.data.items)
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local UI = require(script.Parent.Parent.ui.pixelUI)
local capture = require(ReplicatedStorage.shared.config.capture)

local C = UI.colors
local COLUMNS = balance.INVENTORY_COLUMNS
local ROWS = balance.INVENTORY_ROWS
local SLOT_COUNT = balance.INVENTORY_SLOTS
local TABS = balance.INVENTORY_TABS
local TAB_NAMES = balance.INVENTORY_TAB_NAMES
local SLOT = 22 -- 칸 크기(도트)
local STEP = 24
local PANEL_W, PANEL_H = 300, 226 -- (방울 확률 설명·단축칸 버튼 자리 때문에 190 → 226)
local GRID_Y = 32
local INFO_X = 14 + COLUMNS * STEP + 8 -- 설명 영역 왼쪽
local INFO_W = PANEL_W - INFO_X - 10
local DRAG_START = 6 -- 이만큼(px) 끌면 드래그 시작

local exports = {}

-- 마지막으로 받은 인벤토리(UI 수명과 무관하게 세션 내내 유지).
local cachedInventory = nil
local cachedEquipment = {}
local cachedGold = 0
local goldListeners = {}
local equipmentListeners = {}

-- 글자 폭에 맞춰 줄바꿈(도트 글씨는 자동 줄바꿈이 없다).
local function wrap(text: string, maxWidth: number): string
	local lines, line = {}, ""
	for _, code in utf8.codes(text) do
		local ch = utf8.char(code)
		if UI.Text.Measure(line .. ch, "body") > maxWidth then
			table.insert(lines, line)
			line = if ch == " " then "" else ch
		else
			line ..= ch
		end
	end
	table.insert(lines, line)
	return table.concat(lines, "\n")
end

local function entryAt(tab: string, index: number)
	for _, e in cachedInventory or {} do
		if e.Tab == tab and e.Slot == index then
			return e
		end
	end
	return nil
end

-- 아이템 그림: 전용 이미지(Icon) > 키트 아이콘(KitIcon) > 이름 첫 글자. size = 칸 안 그림 크기(12 또는 24)
local function drawItem(parent: Instance, def, x: number, y: number, size: number)
	if def.Icon and def.Icon ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = def.Icon
		img.ResampleMode = Enum.ResamplerMode.Pixelated
		img.Position = UDim2.fromOffset(x, y)
		img.Size = UDim2.fromOffset(size, size)
		img.ZIndex = 6
		img.Parent = parent
	elseif def.KitIcon and def.KitIcon ~= "" then
		UI.Icon(parent, def.KitIcon, x, y, size).ZIndex = 6
	else
		UI.Label(parent, utf8.char(utf8.codepoint(def.Name, 1)), x, y, { Color = C.ink, ZIndex = 6 })
	end
end
exports.DrawItem = drawItem

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Inventory"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	-- 화면 가운데 고정 + 정수 배율
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	holder.Parent = screenGui
	UI.Scale(holder)

	local panel = UI.Panel(holder, 0, 0, PANEL_W, PANEL_H)
	UI.TitleTag(panel, "가방", PANEL_W / 2, -13)
	UI.Button(panel, PANEL_W - 26, 6, 20, 20, { Color = "white", Icon = "close", OnClick = function()
		popupManager.Close("Inventory")
	end })

	local tab = TABS[1]
	local selected = nil
	local slots = {}
	local refresh

	-- 탭
	local tabParts = {}
	local tx = 12
	for _, key in TABS do
		local label = TAB_NAMES[key]
		local w = UI.Text.Measure(label, "body") + 14
		local part = UI.Part(panel, "tab_off", tx, 8, w, 18, "ImageButton")
		UI.Label(part, label, 7, 4, { Color = C.ink })
		part.Activated:Connect(function()
			tab = key
			selected = nil
			refresh()
		end)
		tabParts[key] = part
		tx += w + 2
	end

	-- 설명 영역
	local bigSlot = UI.Part(panel, "slot", INFO_X, GRID_Y, 40, 40)
	local bigContent = Instance.new("Frame")
	bigContent.BackgroundTransparency = 1
	bigContent.Size = UDim2.fromScale(1, 1)
	bigContent.Parent = bigSlot
	local nameLabel = UI.Label(panel, "", INFO_X, GRID_Y + 44, { Font = "title", Color = C.pinkD })
	local descLabel = UI.Label(panel, "", INFO_X, GRID_Y + 64, { Color = C.ink })
	local actionButton = UI.Button(panel, INFO_X, PANEL_H - 36, 56, 24, { Color = "pink", Text = "장착" })
	-- 소비 단축칸에 놓기 [1][2][3]
	local quickLabel = UI.Label(panel, "단축칸", INFO_X, PANEL_H - 56, { Color = C.ink })
	local quickButtons = {}
	for i = 1, 3 do
		quickButtons[i] = UI.Button(panel, INFO_X + 44 + (i - 1) * 24, PANEL_H - 60, 20, 20, { Color = "white", Text = tostring(i), OnClick = function()
			local entry = selected and entryAt(tab, selected)
			local def = entry and items[entry.ItemId]
			if def and def.Tab == "Use" then
				require(script.Parent.quickslots).set(i, entry.ItemId)
			end
		end })
	end
	local dropButton = UI.Button(panel, INFO_X + 60, PANEL_H - 36, 60, 24, { Color = "white", Text = "버리기" })

	-- 착용 중인 장비(무기·방어구) — 누르면 해제되어 장비 탭 빈 칸으로 돌아간다
	local EQUIP_Y = GRID_Y + ROWS * STEP + 4
	UI.Label(panel, "착용", 14, EQUIP_Y + 5, { Color = C.ink })
	local equipSlots = {}
	for i, slotName in { "Weapon", "Armor" } do
		local ui = UI.Slot(panel, 40 + (i - 1) * STEP, EQUIP_Y, SLOT)
		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.fromScale(1, 1)
		content.Parent = ui.Instance
		ui.Instance.Activated:Connect(function()
			if cachedEquipment[slotName] then
				Net.FireServer("EquipAction", "Unequip", slotName)
			end
		end)
		equipSlots[slotName] = content
	end
	local function drawEquipment()
		for slotName, content in equipSlots do
			content:ClearAllChildren()
			local def = cachedEquipment[slotName] and items[cachedEquipment[slotName]]
			if def then
				drawItem(content, def, 5, 5, 12)
			end
		end
	end
	exports.drawEquipment = drawEquipment

	-- 골드
	UI.Icon(panel, "coin", 14, PANEL_H - 30)
	local goldLabel = UI.Label(panel, tostring(cachedGold), 30, PANEL_H - 29, { Color = C.ink })
	exports.goldLabel = goldLabel

	local function showInfo()
		local entry = selected and entryAt(tab, selected)
		local def = entry and items[entry.ItemId]
		for i, s in slots do
			s.ui:SetSelected(i == selected)
		end
		bigContent:ClearAllChildren()
		if not def then
			nameLabel:SetText("")
			descLabel:SetText(if selected then "빈 칸이에요." else "칸을 눌러 아이템을\n살펴보세요.\n끌어서 자리를\n바꿀 수 있어요.")
			actionButton:SetEnabled(false)
			dropButton:SetEnabled(false)
			for _, b in quickButtons do
				b:SetEnabled(false)
			end
			return
		end
		for _, b in quickButtons do
			b:SetEnabled(def.Tab == "Use")
		end
		quickLabel.Frame.Visible = def.Tab == "Use"
		drawItem(bigContent, def, 8, 8, 24)
		nameLabel:SetText(def.Name)
		local desc = def.Description or ""
		if def.Type == "Bell" and def.Tier then
			-- 방울: 그 방울이 가진 기본 포획률만(종합 확률은 레벨·체력 보정이 더해져 서버가 계산 — 보여 주지 않음)
			desc = wrap(desc, INFO_W) .. ("\n\n기본 포획률 %d%%"):format(math.floor(capture.BaseRate(def.Tier) * 100 + 0.5))
		else
			desc = wrap(desc, INFO_W)
		end
		descLabel:SetText(desc)
		actionButton:SetText(if def.EquipSlot then "장착" else "사용")
		actionButton:SetEnabled(def.EquipSlot ~= nil or def.Heal ~= nil) -- 장비는 장착, 물약(Heal)은 사용
		dropButton:SetEnabled(not def.NoDrop)
	end

	refresh = function()
		drawEquipment()
		for key, part in tabParts do
			part.ImageRectOffset = UI.RectOffset(if key == tab then "tab_on" else "tab_off")
		end
		for index, slot in slots do
			slot.content:ClearAllChildren()
			local entry = entryAt(tab, index)
			local def = entry and items[entry.ItemId]
			if def then
				drawItem(slot.content, def, 5, 5, 12)
				if entry.Count > 1 then
					local count = UI.Label(slot.content, tostring(entry.Count), 0, 11, { Color = C.ink, ZIndex = 7 })
					count.Frame.Position = UDim2.fromOffset(SLOT - 1 - count.Width, 11)
				end
			end
		end
		showInfo()
	end
	exports.refresh = refresh

	-- 칸 + 드래그 앤 드롭
	local drag = nil -- { from, startPos, ghost }
	-- 좌표는 입력 좌표(InputObject.Position) 그대로 쓴다. 상단바 보정을 직접 계산하면 엔진 버전에 따라 어긋나서(놓은 칸보다 한 칸
	-- 아래에 들어가던 버그), 놓은 칸은 PlayerGui:GetGuiObjectsAtPosition으로 "그 점 아래에 있는 칸"을 물어본다.
	-- 끌고 다니는 그림도 상단바를 비켜 앉는 별도 화면(IgnoreGuiInset = false)에 붙여 입력 좌표와 같은 기준으로 맞춘다.
	local function pointOf(input: InputObject): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local slotOf = {} -- 칸 ImageButton → 번호
	local function slotAt(point: Vector2): number?
		for _, obj in playerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
			local cur = obj
			while cur and cur ~= screenGui do
				if slotOf[cur] then
					return slotOf[cur]
				end
				cur = cur.Parent
			end
		end
		return nil
	end
	local dragGui = Instance.new("ScreenGui")
	dragGui.Name = "InventoryDrag"
	dragGui.ResetOnSpawn = false
	dragGui.IgnoreGuiInset = false
	dragGui.DisplayOrder = 200
	dragGui.Parent = playerGui
	exports.dragGui = dragGui
	for index = 1, SLOT_COUNT do
		local col = (index - 1) % COLUMNS
		local row = (index - 1) // COLUMNS
		local ui = UI.Slot(panel, 14 + col * STEP, GRID_Y + row * STEP, SLOT)
		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.fromScale(1, 1)
		content.Parent = ui.Instance
		slots[index] = { ui = ui, content = content }
		slotOf[ui.Instance] = index
		ui.Instance.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				drag = { from = index, startPos = pointOf(input), ghost = nil }
			end
		end)
	end

	exports.inputChanged = UserInputService.InputChanged:Connect(function(input)
		if not drag or not (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			return
		end
		local point = pointOf(input)
		if not drag.ghost then
			local entry = entryAt(tab, drag.from)
			if not entry or (point - drag.startPos).Magnitude < DRAG_START then
				return
			end
			-- 끌기 시작: 손가락/마우스를 따라다니는 아이템 그림
			local ghost = Instance.new("Frame")
			ghost.Name = "DragGhost"
			ghost.BackgroundTransparency = 1
			ghost.AnchorPoint = Vector2.new(0.5, 0.5)
			ghost.Size = UDim2.fromOffset(SLOT, SLOT)
			ghost.ZIndex = 50
			ghost.Parent = dragGui
			local scale = Instance.new("UIScale")
			scale.Scale = UI.CurrentScale()
			scale.Parent = ghost
			UI.Part(ghost, "slot_selected", 0, 0, SLOT, SLOT).ZIndex = 50
			drawItem(ghost, items[entry.ItemId], 5, 5, 12)
			drag.ghost = ghost
		end
		drag.ghost.Position = UDim2.fromOffset(point.X, point.Y)
	end)

	exports.inputEnded = UserInputService.InputEnded:Connect(function(input)
		if not drag or not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			return
		end
		local d = drag
		drag = nil
		if d.ghost then
			d.ghost:Destroy()
			local to = slotAt(pointOf(input))
			if to and to ~= d.from then
				Net.FireServer("MoveItem", tab, d.from, to)
				selected = to
			end
		else
			selected = d.from -- 끌지 않고 뗐으면 선택
			showInfo()
		end
	end)

	actionButton.Instance.Activated:Connect(function()
		local entry = selected and entryAt(tab, selected)
		local def = entry and items[entry.ItemId]
		if def and def.EquipSlot then
			Net.FireServer("EquipAction", "Equip", selected)
		elseif def and def.Heal then
			Net.FireServer("UseItem", tab, selected) -- 물약: 서버가 체력 회복 + 1개 줄임
		end
	end)
	dropButton.Instance.Activated:Connect(function()
		local entry = selected and entryAt(tab, selected)
		local def = entry and items[entry.ItemId]
		if def and not def.NoDrop then
			Net.FireServer("DropItem", tab, selected)
		end
	end)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
	popupManager.Register("Inventory", screenGui, panel)
	exports.panel = panel
	refresh()

	-- 리스너와 서버 조회는 세션 동안 한 번만 건다(UI가 씬마다 다시 만들어져도 갱신을 놓치지 않게).
	if not exports.listening then
		exports.listening = true
		task.spawn(function()
			Net.OnClient("InventoryUpdated", function(inventoryData)
				exports.applyInventory(inventoryData)
			end)
			Net.OnClient("GoldUpdated", function(gold)
				exports.applyGold(gold)
			end)
			Net.OnClient("EquipmentUpdated", function(equipment)
				exports.applyEquipment(equipment)
			end)
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

-- HUD의 가방 버튼이 호출해서 패널을 열고/닫는다.
function exports.toggle()
	if not exports.panel then
		return
	end
	popupManager.Toggle("Inventory")
end

-- inventoryData: 서버가 주는 촘촘한 배열 { { Tab, Slot, ItemId, Count }, ... }. 비어있는 칸은 목록에 없다.
local inventoryListeners = {}
function exports.applyInventory(inventoryData)
	cachedInventory = inventoryData
	if exports.refresh then
		exports.refresh()
	end
	for _, callback in inventoryListeners do
		callback(cachedInventory)
	end
end

-- 가게 창 등이 가방 내용을 읽고 바뀔 때 알림받는다
function exports.getInventory()
	return cachedInventory or {}
end
function exports.onInventoryChanged(callback)
	table.insert(inventoryListeners, callback)
end

function exports.getGold()
	return cachedGold
end

function exports.onGoldChanged(callback)
	table.insert(goldListeners, callback)
end

function exports.applyGold(gold)
	cachedGold = gold or 0
	if exports.goldLabel then
		exports.goldLabel:SetText(tostring(cachedGold))
	end
	for _, callback in goldListeners do
		callback(cachedGold)
	end
end

-- equipment: { Weapon = ItemId?, Armor = ItemId? } — 장비 UI(equipment.luau)에 알려주기만 한다.
function exports.getEquipment()
	return cachedEquipment
end

function exports.onEquipmentChanged(callback)
	table.insert(equipmentListeners, callback)
end

function exports.applyEquipment(equipment)
	cachedEquipment = equipment or {}
	if exports.drawEquipment then
		exports.drawEquipment()
	end
	for _, callback in equipmentListeners do
		callback(cachedEquipment)
	end
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	popupManager.Unregister("Inventory")
	for _, key in { "inputChanged", "inputEnded" } do
		if exports[key] then
			exports[key]:Disconnect()
			exports[key] = nil
		end
	end
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
	if exports.dragGui then
		exports.dragGui:Destroy()
		exports.dragGui = nil
	end
	exports.panel = nil
	exports.goldLabel = nil
	exports.refresh = nil
	exports.drawEquipment = nil
end

return exports
