-- 몬스터 도감 — 에셋 공방 UI 탭 "몬스터 도감" 예시 화면 그대로(도트 UI).
--  패널 360x238, 위 "몬스터 도감" 제목판, 오른쪽 위 발견 수 알약 + 닫기, 속성 탭(전체·불·풀·물),
--  페이지당 8x4 칸: 한 번이라도 쓰러뜨린 몬스터는 그림, 아직이면 회색 그림자.
-- 발견 목록은 서버 저장 데이터(Dex)에서 받고, 처음 쓰러뜨리면 서버가 DexDiscovered로 알려준다.
-- HUD의 도감 버튼 / "새 친구!" 팝업의 [도감 보기]가 exports.toggle() / open()을 부른다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local monsterLevels = require(ReplicatedStorage.shared.config.monsterLevels)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local popupManager = require(script.Parent.Parent.popupManager)
local UI = require(script.Parent.Parent.ui.pixelUI)
local notify = require(script.Parent.notify)

local C = UI.colors
local PW, PH = 360, 238
local COLS, ROWS = 8, 4
local species = townWorld.data.species
local TABS = {
	{ key = nil, label = "전체" },
	{ key = "fire", label = "불", icon = "fire" },
	{ key = "grass", label = "풀", icon = "leaf" },
	{ key = "water", label = "물", icon = "water" },
}
local ELEMENT_NAME = { fire = "불", water = "물", grass = "풀" }

local exports = {}
local discovered = {} -- 종류 id -> true

local function discoveredCount(): number
	local n = 0
	for _ in discovered do
		n += 1
	end
	return n
end

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Dex"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(PW, PH + 30)
	holder.Parent = screenGui
	UI.Scale(holder)

	local panel = UI.Panel(holder, 0, 0, PW, PH)
	UI.TitleTag(panel, "몬스터 도감", PW / 2, -13)
	UI.Pill(panel, PW - 88, 8, 52, 15, true)
	local countLabel = UI.Label(panel, "", PW - 62, 9, { Color = C.white })
	UI.Button(panel, PW - 30, 6, 20, 20, { Color = "white", Icon = "close", OnClick = function()
		popupManager.Close("Dex")
	end })
	-- 아래 설명 줄
	local infoLabel = UI.Label(panel, "칸을 눌러 몬스터를 살펴보세요.", 12, PH - 16, { Color = C.ink })

	local tabKey = nil
	local page = 1
	local tabParts = {}
	local cells = {}
	local refresh
	local pageLabel = UI.Label(panel, "", 171, 205, { Color = C.ink })
	local prev = UI.Part(panel, "tab_off", 137, 202, 27, 18, "ImageButton")
	UI.Label(prev, "<", 10, 4, { Color = C.ink })
	prev.Activated:Connect(function()
		page = math.max(1, page - 1)
		refresh()
	end)
	local next = UI.Part(panel, "tab_off", 199, 202, 27, 18, "ImageButton")
	UI.Label(next, ">", 10, 4, { Color = C.ink })
	next.Activated:Connect(function()
		page += 1
		refresh()
	end)

	-- 속성 탭
	local tx = 10
	for _, t in TABS do
		local w = UI.Text.Measure(t.label, "body") + (if t.icon then 26 else 14)
		local part = UI.Part(panel, "tab_off", tx, 8, w, 18, "ImageButton")
		local lx = 7
		if t.icon then
			UI.Icon(part, t.icon, lx - 1, 3)
			lx += 13
		end
		UI.Label(part, t.label, lx, 4, { Color = C.ink })
		part.Activated:Connect(function()
			tabKey = t.key
			page = 1
			refresh()
		end)
		table.insert(tabParts, { part = part, key = t.key })
		tx += w + 2
	end

	-- 한 페이지의 칸 8x4
	for i = 1, COLS * ROWS do
		local c, r = (i - 1) % COLS, (i - 1) // COLS
		local slot = UI.Slot(panel, 12 + c * 42, 32 + r * 42, 40)
		local img = notify.MonsterImage(slot.Instance, 1, 4, 5, 1)
		local num = UI.Label(slot.Instance, "", 3, 28, { Color = C.ink })
		local cell = { slot = slot, img = img, num = num, row = nil }
		slot.Instance.Activated:Connect(function()
			if not cell.row then
				return
			end
			for _, other in cells do
				other.slot:SetSelected(other == cell)
			end
			local s = species[cell.row]
			local lo, hi = monsterLevels.LevelRange(cell.row)
			if discovered[s.id] then
				infoLabel:SetText(("%s · %s 속성 · Lv.%d~%d"):format(s.name, ELEMENT_NAME[s.element] or s.element, lo, hi))
			else
				infoLabel:SetText(("??? · Lv.%d~%d 지역에서 만날 수 있어요"):format(lo, hi))
			end
		end)
		cells[i] = cell
	end

	refresh = function()
		for _, t in tabParts do
			t.part.ImageRectOffset = UI.RectOffset(if t.key == tabKey then "tab_on" else "tab_off")
		end
		local rows = {}
		for row, s in species do
			if tabKey == nil or s.element == tabKey then
				table.insert(rows, row)
			end
		end
		local pageCount = math.max(1, math.ceil(#rows / (COLS * ROWS)))
		page = math.min(page, pageCount)
		pageLabel:SetText(("%d/%d"):format(page, pageCount))
		prev.Visible = page > 1
		next.Visible = page < pageCount
		for i, cell in cells do
			local row = rows[(page - 1) * COLS * ROWS + i]
			cell.row = row
			cell.slot:SetSelected(false)
			if row then
				local seen = discovered[species[row].id] == true
				cell.img.Visible = true
				cell.img.Image = townAssets.MONSTER_SHEETS[townWorld.MonsterSheet(row)]
				cell.img.ImageRectOffset = townWorld.MonsterFrameOffset(row, 0)
				-- 아직 못 만난 몬스터는 회색 그림자
				cell.img.ImageColor3 = if seen then Color3.new(1, 1, 1) else Color3.fromRGB(90, 78, 110)
				cell.img.ImageTransparency = if seen then 0 else 0.55
				cell.num:SetText(string.format("%02d", row))
				cell.num:SetColor(if seen then C.ink else C.grayD or C.ink)
			else
				cell.img.Visible = false
				cell.num:SetText("")
			end
		end
		countLabel:SetText(("%d/%d"):format(discoveredCount(), #species))
		countLabel.Frame.Position = UDim2.fromOffset(PW - 62 - countLabel.Width // 2, 9)
	end
	exports.refresh = refresh

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.screenGui = screenGui
	exports.panel = panel
	popupManager.Register("Dex", screenGui, panel)
	refresh()

	if not exports.listening then
		exports.listening = true
		Net.OnClient("DexDiscovered", function(row)
			local s = species[row]
			if s then
				discovered[s.id] = true
				if exports.refresh then
					exports.refresh()
				end
			end
		end)
		task.spawn(function()
			local ok, data = pcall(Net.Invoke, "GetPlayerData")
			if ok and typeof(data) == "table" and typeof(data.Dex) == "table" then
				for id, v in data.Dex do
					if v then
						discovered[id] = true
					end
				end
				if exports.refresh then
					exports.refresh()
				end
			end
		end)
	end
end

function exports.toggle()
	if exports.panel then
		if not popupManager.IsOpen("Dex") and exports.refresh then
			exports.refresh()
		end
		popupManager.Toggle("Dex")
	end
end

function exports.open()
	if exports.panel and not popupManager.IsOpen("Dex") then
		exports.toggle()
	end
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	popupManager.Unregister("Dex")
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
	exports.panel = nil
	exports.refresh = nil
end

return exports
