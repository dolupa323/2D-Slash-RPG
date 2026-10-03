-- 소비 단축칸 1·2·3(HUD) — GAME_DESIGN §3. 화면 아래 가운데 작은 칸 3개: 놓아 둔 아이템 아이콘 + 개수 + 숫자.
--  PC: 숫자키 1·2·3(키패드 포함) / 모바일: 칸을 터치. 쓰면 서버(UseQuickSlot)가 처리 — 방울은 바라보는 방향으로 던지기(포획),
--  물약은 체력 회복. 칸에 놓기는 가방에서 소비 아이템을 눌러 [1][2][3] (inventory.luau → SetQuickSlot).
--  전투 화면이라 정보는 최소한만(확률·설명 없음 — 가방 상세 설명에서 본다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.shared.net.net)
local items = require(ReplicatedStorage.shared.data.items)
local UI = require(script.Parent.Parent.ui.pixelUI)
local inventory = require(script.Parent.inventory)

local C = UI.colors
local SLOT = 26
local GAP = 4
local KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
}

local exports = {}
exports.slots = { "", "", "" }
local cells = {}

local function countOf(itemId: string): number
	local n = 0
	for _, e in inventory.getInventory() do
		if e.ItemId == itemId then
			n += e.Count
		end
	end
	return n
end

local function redraw()
	for i, cell in cells do
		cell.content:ClearAllChildren()
		local id = exports.slots[i] or ""
		local def = items[id]
		if def then
			inventory.DrawItem(cell.content, def, 7, 6, 12)
			local n = countOf(id)
			local count = UI.Label(cell.content, tostring(n), 0, 15, { Color = if n > 0 then C.white else C.accentL, Shadow = C.ink, ZIndex = 7 })
			count.Frame.Position = UDim2.fromOffset(SLOT - 2 - count.Width, 15)
		end
	end
end

local function use(index: number)
	local hero = require(script.Parent.Parent.topDownHero).hero
	if not hero or (exports.slots[index] or "") == "" then
		return
	end
	Net.FireServer("UseQuickSlot", index, hero.Facing or "down")
end

function exports.set(index: number, itemId: string)
	Net.FireServer("SetQuickSlot", index, itemId)
end

function exports.load(scene: Scene)
	if not exports.screenGui then
		local g = Instance.new("ScreenGui")
		g.Name = "QuickSlots"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 20
		local W = SLOT * 3 + GAP * 2
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.Position = UDim2.new(0.5, 0, 1, -8)
		holder.Size = UDim2.fromOffset(W, SLOT)
		holder.Parent = g
		UI.Scale(holder)
		for i = 1, 3 do
			local slot = UI.Slot(holder, (i - 1) * (SLOT + GAP), 0, SLOT)
			local content = Instance.new("Frame")
			content.BackgroundTransparency = 1
			content.Size = UDim2.fromScale(1, 1)
			content.Parent = slot.Instance
			slot.Instance.Activated:Connect(function()
				use(i)
			end)
			UI.Part(holder, "key_" .. i, (i - 1) * (SLOT + GAP) - 3, -3).ZIndex = 10 -- 팩 키보드 키 그림
			cells[i] = { ui = slot, content = content }
		end
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		exports.screenGui = g
	end
	if not exports.listening then
		exports.listening = true
		Net.OnClient("QuickSlotsUpdated", function(slots)
			exports.slots = slots or { "", "", "" }
			redraw()
		end)
		inventory.onInventoryChanged(redraw)
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local index = KEYS[input.KeyCode]
			if index then
				use(index)
			end
		end)
		task.spawn(function()
			local ok, data = pcall(Net.Invoke, "GetPlayerData")
			if ok and typeof(data) == "table" and typeof(data.QuickSlots) == "table" then
				exports.slots = data.QuickSlots
			end
			redraw()
		end)
	end
	redraw()
end

function exports.start(scene: Scene) end
function exports.unload(scene: Scene) end

return exports
