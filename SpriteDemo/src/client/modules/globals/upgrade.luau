-- 강화 창(클라, 「오문 닌자전」 N3) — 대장장이에게 말을 걸면 열린다(town/npcs.luau → open). 수치는 shared/config/weapons.luau.
--  윗줄: 강화할 무기 칸들 — 맨 앞은 지금 착용한 무기(칸 번호 0), 그 뒤는 가방 장비 탭의 무기(칸 번호 = 가방 칸).
--  아래: 고른 무기의 이름 +단계, 공격력(지금 > 다음), 드는 주괴(가진 개수) · 엽전, 성공 확률, [강화] 버튼, 결과 한 줄.
--  [강화] → 서버 UpgradeWeapon(칸). 판정·재료 소모는 서버(server/modules/upgradeService.luau)가 한다 — 대장간 곁이 아니면 서버가 거절.
--  실패해도 단계는 내려가지 않는다(재료·엽전만 든다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local items = require(ReplicatedStorage.shared.data.items)
local weapons = require(ReplicatedStorage.shared.config.weapons)
local popupManager = require(script.Parent.Parent.popupManager)
local UI = require(script.Parent.Parent.ui.pixelUI)
local inventory = require(script.Parent.inventory)

local C = UI.colors
local PANEL_W, PANEL_H = 250, 156
local SLOT = 22
local STEP = 24
local MAX_LIST = 9 -- 한 줄에 보여 주는 무기 수(착용 1 + 가방 8)

local exports = {}
local selected = nil -- 고른 무기의 칸 번호(0 = 착용)
local lastResult = ""

-- 강화할 수 있는 무기 목록: { slot, itemId, plus }
local function candidates()
	local list = {}
	local equipped = inventory.getEquipment().Weapon
	if equipped and items[equipped] and items[equipped].Type == "Weapon" then
		table.insert(list, { slot = 0, itemId = equipped, plus = inventory.getEquipmentPlus().Weapon or 0 })
	end
	local bag = {}
	for _, e in inventory.getInventory() do
		local def = items[e.ItemId]
		if e.Tab == "Equip" and def and def.Type == "Weapon" then
			table.insert(bag, e)
		end
	end
	table.sort(bag, function(a, b)
		return a.Slot < b.Slot
	end)
	for _, e in bag do
		if #list < MAX_LIST then
			table.insert(list, { slot = e.Slot, itemId = e.ItemId, plus = e.Plus or 0 })
		end
	end
	return list
end

local function countOf(itemId: string): number
	local n = 0
	for _, e in inventory.getInventory() do
		if e.ItemId == itemId then
			n += e.Count
		end
	end
	return n
end

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Upgrade"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	holder.Parent = screenGui
	UI.Scale(holder)

	local panel = UI.Panel(holder, 0, 0, PANEL_W, PANEL_H)
	UI.TitleTag(panel, "강화", PANEL_W / 2, -13)
	UI.Button(panel, PANEL_W - 26, 6, 20, 20, { Color = "plain", Icon = "close", OnClick = function()
		popupManager.Close("Upgrade")
	end })

	local cells = {}
	local refresh
	for i = 1, MAX_LIST do
		local ui = UI.Slot(panel, 14 + (i - 1) * STEP, 30, SLOT)
		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.fromScale(1, 1)
		content.Parent = ui.Instance
		cells[i] = { ui = ui, content = content, entry = nil }
		ui.Instance.Activated:Connect(function()
			local entry = cells[i].entry
			if entry then
				selected = entry.slot
				lastResult = ""
				refresh()
			end
		end)
	end
	local nameLabel = UI.Label(panel, "", 14, 56, { Color = C.ink, MaxWidth = PANEL_W - 28, MaxLines = 1 })
	local attackLabel = UI.Label(panel, "", 14, 69, { Color = C.ink, MaxWidth = PANEL_W - 28, MaxLines = 1 })
	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Position = UDim2.fromOffset(14, 82)
	barHolder.Size = UDim2.fromOffset(12, 12)
	barHolder.Parent = panel
	local barLabel = UI.Label(panel, "", 30, 82, { Color = C.ink, MaxWidth = PANEL_W - 44, MaxLines = 1 })
	UI.Icon(panel, "coin", 14, 95)
	local goldLabel = UI.Label(panel, "", 30, 95, { Color = C.ink, MaxWidth = PANEL_W - 44, MaxLines = 1 })
	local rateLabel = UI.Label(panel, "", 14, 108, { Color = C.ink, MaxWidth = PANEL_W - 28, MaxLines = 1 })
	-- 결과 한 줄: [강화] 버튼(오른쪽 70칸) 앞까지
	local resultLabel = UI.Label(panel, "", 14, 130, { Color = C.accentD, MaxWidth = PANEL_W - 14 - 70 - 14 - 6, MaxLines = 1 })
	local button = UI.Button(panel, PANEL_W - 14 - 70, 124, 70, 24, { Color = "primary", Text = "강화", OnClick = function()
		if selected then
			Net.FireServer("UpgradeWeapon", selected)
		end
	end })

	refresh = function()
		local list = candidates()
		local current = nil
		for _, e in list do
			if e.slot == selected then
				current = e
			end
		end
		if not current then
			current = list[1]
			selected = current and current.slot
		end
		for i, cell in cells do
			local e = list[i]
			cell.entry = e
			cell.content:ClearAllChildren()
			cell.ui:SetSelected(e ~= nil and e.slot == selected)
			if e then
				inventory.DrawItem(cell.content, items[e.itemId], 5, 5, 12)
				if e.slot == 0 then
					UI.Label(cell.content, "E", 2, 0, { Color = C.accentD, ZIndex = 7 }) -- 착용 중
				end
				if e.plus > 0 then
					local plus = UI.Label(cell.content, inventory.PlusText(e.plus), 0, 10, { Color = C.accentL, Shadow = C.ink, ZIndex = 7 })
					plus.Frame.Position = UDim2.fromOffset(SLOT - 2 - plus.Width, 10)
				end
			end
		end
		barHolder:ClearAllChildren()
		resultLabel:SetText(if lastResult ~= "" then lastResult else "실패해도 단계는 그대로")
		if not current then
			nameLabel:SetText("강화할 무기가 없어요.")
			attackLabel:SetText("")
			barLabel:SetText("")
			goldLabel:SetText("")
			rateLabel:SetText("")
			button:SetEnabled(false)
			return
		end
		local def = items[current.itemId]
		local class = weapons.ClassOf(def)
		nameLabel:SetText(("%s%s · %s"):format(def.Name, if current.plus > 0 then " +" .. current.plus else "", class.name))
		local now = def.Attack + weapons.Bonus(def, current.plus)
		local cost = weapons.Cost(def, current.plus + 1)
		if not cost then
			attackLabel:SetText(("공격력 %d · 최고 단계예요"):format(now))
			barLabel:SetText("")
			goldLabel:SetText("")
			rateLabel:SetText("")
			button:SetEnabled(false)
			return
		end
		attackLabel:SetText(("공격력 %d > %d"):format(now, def.Attack + weapons.Bonus(def, current.plus + 1)))
		local barDef = items[cost.bar]
		inventory.DrawItem(barHolder, barDef, 0, 0, 12)
		local have = countOf(cost.bar)
		barLabel:SetText(("%s %d개 (가진 것 %d)"):format(barDef.Name, cost.bars, have))
		barLabel:SetColor(if have >= cost.bars then C.ink else C.accentD)
		goldLabel:SetText(("엽전 %d"):format(cost.gold))
		goldLabel:SetColor(if inventory.getGold() >= cost.gold then C.ink else C.accentD)
		rateLabel:SetText(("성공 확률 %d%%"):format(math.floor(cost.rate * 100 + 0.5)))
		button:SetEnabled(have >= cost.bars and inventory.getGold() >= cost.gold)
	end
	exports.refresh = refresh

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
	popupManager.Register("Upgrade", screenGui, panel)

	if not exports.listening then
		exports.listening = true
		local function again()
			if exports.refresh and popupManager.IsOpen("Upgrade") then
				exports.refresh()
			end
		end
		inventory.onInventoryChanged(again)
		inventory.onEquipmentChanged(again)
		inventory.onGoldChanged(again)
		Net.OnClient("UpgradeResult", function(success, itemId, plus)
			local def = items[itemId]
			lastResult = if success then ("성공! %s +%d"):format(def and def.Name or "", plus) else "실패… 단계는 그대로"
			again()
		end)
	end
end

function exports.open()
	if not exports.refresh then
		return
	end
	lastResult = ""
	exports.refresh()
	popupManager.Open("Upgrade")
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	popupManager.Unregister("Upgrade")
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
	exports.refresh = nil
end

return exports
