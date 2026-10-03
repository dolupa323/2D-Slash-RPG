-- NPC 가게 창(도트 UI) — 포션상 등 가게 NPC에게 말을 걸면 열린다(town/npcs.luau → exports.open(가게 id)).
--  패널 300x190, 위 가게 이름 제목판 + 닫기, 탭 [구매] [판매].
--  구매: 가게가 파는 물건(shared/config/shops.luau) 한 줄씩 — 칸 아이콘, 이름, 값(코인), [1개] [10개].
--  판매: 내 가방에서 팔 수 있는 물건(SellPrice가 있고 중요 물품이 아닌 것) 한 줄씩 — 이름 x개수, 개당 값, [1개] [전부].
--  한 쪽에 6줄, 넘치면 아래 ◀ ▶로 넘긴다. 왼쪽 아래 내 골드.
-- 사고팔기는 서버(server/modules/shops.luau)가 NPC 거리·골드·가방 자리를 확인해서 처리하고, 결과는 가방/골드 갱신으로 돌아온다.
-- NPC에게서 멀어지면 npcs.luau가 exports.close()로 닫는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local items = require(ReplicatedStorage.shared.data.items)
local shops = require(ReplicatedStorage.shared.config.shops)
local popupManager = require(script.Parent.Parent.popupManager)
local UI = require(script.Parent.Parent.ui.pixelUI)
local inventory = require(script.Parent.inventory)

local C = UI.colors
local PW, PH = 300, 190
local ROWS = 6
local ROW_H = 21
local LIST_Y = 30
local COIN_X = 170 -- 줄 안 엽전 아이콘 자리(그 오른쪽이 값, 맨 오른쪽이 버튼 둘)
local NAME_W = COIN_X - 36 - 4 -- 물건 이름 자리 폭
local SELL_TABS = { Equip = true, Use = true, Etc = true, Cash = true }

local exports = {}

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Shop"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(PW, PH)
	holder.Parent = screenGui
	UI.Scale(holder)
	local panel = UI.Panel(holder, 0, 0, PW, PH)
	local titleHolder = Instance.new("Frame")
	titleHolder.BackgroundTransparency = 1
	titleHolder.Size = UDim2.fromOffset(PW, 0)
	titleHolder.Parent = panel
	UI.Button(panel, PW - 26, 6, 20, 20, { Color = "plain", Icon = "close", OnClick = function()
		exports.close()
	end })

	local mode = "buy"
	local page = 1
	local refresh

	-- 탭 [구매] [판매]
	local tabParts = {}
	local tx = 12
	for _, t in { { "buy", "구매" }, { "sell", "판매" } } do
		local w = UI.Text.Measure(t[2], "body") + 16
		local part = UI.Part(panel, "tab_off", tx, 8, w, 18, "ImageButton")
		UI.Label(part, t[2], 8, 4, { Color = C.ink })
		part.Activated:Connect(function()
			mode = t[1]
			page = 1
			refresh()
		end)
		tabParts[t[1]] = part
		tx += w + 2
	end

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, LIST_Y)
	list.Size = UDim2.fromOffset(PW, ROWS * ROW_H)
	list.Parent = panel

	-- 아래: 골드 + 쪽 넘기기
	UI.Icon(panel, "coin", 14, PH - 26)
	local goldLabel = UI.Label(panel, "", 30, PH - 25, { Color = C.ink })
	local pageLabel = UI.Label(panel, "", PW - 60, PH - 25, { Color = C.ink })
	local prev = UI.Button(panel, PW - 92, PH - 30, 22, 20, { Color = "plain", Text = "<", OnClick = function()
		page -= 1
		refresh()
	end })
	local nextBtn = UI.Button(panel, PW - 34, PH - 30, 22, 20, { Color = "plain", Text = ">", OnClick = function()
		page += 1
		refresh()
	end })

	local function row(i: number, def, nameText: string, price: number, buttons)
		local y = (i - 1) * ROW_H
		local slot = UI.Part(list, "slot", 12, y, 18, 18)
		inventory.DrawItem(slot, def, 3, 3, 12)
		UI.Label(list, nameText, 36, y + 3, { Color = C.ink, MaxWidth = NAME_W, MaxLines = 1 }) -- 엽전 아이콘 앞까지
		UI.Icon(list, "coin", COIN_X, y + 3)
		local bx = PW - 12
		for k = #buttons, 1, -1 do
			local b = buttons[k]
			local w = UI.Text.Measure(b.text, "body") + 12
			bx -= w
			UI.Button(list, bx, y, w, 18, { Color = b.color, Text = b.text, OnClick = b.onClick })
			bx -= 3
		end
		UI.Label(list, tostring(price), COIN_X + 14, y + 3, { Color = C.ink, MaxWidth = math.max(12, bx - (COIN_X + 14)), MaxLines = 1 }) -- 값은 버튼 앞까지
	end

	refresh = function()
		for key, part in tabParts do
			part.ImageRectOffset = UI.RectOffset(if key == mode then "tab_on" else "tab_off")
		end
		list:ClearAllChildren()
		goldLabel:SetText(tostring(inventory.getGold()))
		local shop = shops[exports.shopId]
		if not shop then
			return
		end
		local entries = {}
		if mode == "buy" then
			for _, itemId in shop.goods do
				local def = items[itemId]
				if def and def.Price then
					table.insert(entries, function(i)
						row(i, def, def.Name, def.Price, {
							{ text = "1개", color = "primary", onClick = function() Net.FireServer("ShopBuy", exports.shopId, itemId, 1) end },
							{ text = "10개", color = "plain", onClick = function() Net.FireServer("ShopBuy", exports.shopId, itemId, 10) end },
						})
					end)
				end
			end
		else
			local inv = table.clone(inventory.getInventory())
			table.sort(inv, function(a, b)
				if a.Tab ~= b.Tab then
					return a.Tab < b.Tab
				end
				return a.Slot < b.Slot
			end)
			for _, e in inv do
				local def = items[e.ItemId]
				if def and def.SellPrice and not def.NoDrop and SELL_TABS[e.Tab] then
					table.insert(entries, function(i)
						row(i, def, ("%s x%d"):format(def.Name, e.Count), def.SellPrice, {
							{ text = "1개", color = "primary", onClick = function() Net.FireServer("ShopSell", e.Tab, e.Slot, 1) end },
							{ text = "전부", color = "plain", onClick = function() Net.FireServer("ShopSell", e.Tab, e.Slot, e.Count) end },
						})
					end)
				end
			end
			if #entries == 0 then
				UI.Label(list, "팔 수 있는 물건이 없어요.", 14, 4, { Color = C.ink })
			end
		end
		local pages = math.max(1, math.ceil(#entries / ROWS))
		page = math.clamp(page, 1, pages)
		for i = 1, ROWS do
			local draw = entries[(page - 1) * ROWS + i]
			if draw then
				draw(i)
			end
		end
		pageLabel:SetText(("%d/%d"):format(page, pages))
		pageLabel.Frame.Position = UDim2.fromOffset(PW - 52 - pageLabel.Width // 2, PH - 25)
		prev:SetEnabled(page > 1)
		nextBtn:SetEnabled(page < pages)
	end

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.screenGui = screenGui
	exports.panel = panel
	exports.titleHolder = titleHolder
	exports.refresh = refresh
	popupManager.Register("Shop", screenGui, panel)

	if not exports.listening then
		exports.listening = true
		inventory.onInventoryChanged(function()
			if exports.refresh and exports.isOpen() then
				exports.refresh()
			end
		end)
		inventory.onGoldChanged(function()
			if exports.refresh and exports.isOpen() then
				exports.refresh()
			end
		end)
	end
end

function exports.isOpen(): boolean
	return exports.panel ~= nil and popupManager.IsOpen("Shop")
end

function exports.open(shopId: string)
	local shop = shops[shopId]
	if not shop or not exports.panel then
		return
	end
	exports.shopId = shopId
	exports.titleHolder:ClearAllChildren()
	UI.TitleTag(exports.titleHolder, shop.title, PW / 2, -13)
	exports.refresh()
	if not popupManager.IsOpen("Shop") then
		popupManager.Open("Shop")
	end
end

function exports.close()
	if exports.panel and popupManager.IsOpen("Shop") then
		popupManager.Close("Shop")
	end
end

-- 이 NPC 역할이 여는 가게 id(없으면 nil)
function exports.ShopFor(npcType: string): string?
	for id, shop in shops do
		if shop.npc == npcType then
			return id
		end
	end
	return nil
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	popupManager.Unregister("Shop")
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
	exports.panel = nil
	exports.refresh = nil
end

return exports
