-- 몬스터 상자(펫) — GAME_DESIGN §5. HUD 발바닥 버튼이 exports.toggle()을 부른다.
--  위: "함께 다니기" 4칸(1번 = 대표 펫, 다른 사람에게 보이는 한 마리). 잠긴 칸은 X 아이콘. 오른쪽 위에 맺은 수.
--  왼쪽: 박스 칸 6x5(박스 하나 30칸) + 아래 [<] 박스 n/N [>](가운데 정렬).
--   함께 다니기 칸과 박스 칸은 따로다: 함께 다니는 펫은 박스에 안 보이고(장착 칸으로 옮겨 간 것처럼), 상자로 돌리면 박스 앞쪽부터 다시 채워진다.
--   (저장은 그대로 Box 배열 하나 + Party 번호 — 박스 화면은 Party에 없는 펫만 차례로 보여 준다)
--  오른쪽: 고른 펫 그림 · 이름 · "Lv.n · 방울" 한 줄 · 상태 한 줄 · [함께 다니기]/[상자로] · [대표로] [놓아주기].
--  놓아주기는 확인 창(모달)에서 한 번 더 — 놓아준 펫은 사라진다(보상 없음).
--  데이터: 서버 PetsUpdated({ Box, Party, Paid, Boxes }) + 처음 GetPlayerData. 칸 수 = pets.SlotCount(레벨, 유료 칸).
--  town/pets.luau(따라다니기)도 여기 데이터를 읽는다(exports.data / exports.onChanged).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Net = require(ReplicatedStorage.shared.net.net)
local pets = require(ReplicatedStorage.shared.config.pets)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local popupManager = require(script.Parent.Parent.popupManager)
local UI = require(script.Parent.Parent.ui.pixelUI)
local notify = require(script.Parent.notify)

local C = UI.colors
local PW, PH = 300, 246
local COLS, ROWS = 6, 5
local SLOT, STEP = 22, 24
local GRID_X, GRID_Y = 12, 70
local GRID_W = COLS * STEP - 2
local INFO_X = GRID_X + COLS * STEP + 10
local INFO_W = PW - INFO_X - 10
local BELL_NAMES = { "흐린 방울", "맑은 방울", "빛나는 방울", "별빛 방울", "무지개 방울" }

local exports = {}
exports.data = { Box = {}, Party = {}, Paid = 0 }
exports.level = 1
local listeners = {}

local speciesRow = {}
for row, s in townWorld.data.species do
	speciesRow[s.id] = row
end
exports.SpeciesRow = function(id: string): number?
	return speciesRow[id]
end

function exports.onChanged(callback)
	table.insert(listeners, callback)
end

local function changed()
	if exports.refresh then
		exports.refresh()
	end
	for _, cb in listeners do
		task.spawn(cb, exports.data)
	end
end

local function slotCount(): number
	return pets.SlotCount(exports.level, exports.data.Paid)
end

local function speciesOf(pet)
	local row = pet and speciesRow[pet.S]
	return row and townWorld.data.species[row], row
end

-- 몬스터 그림(칸 안)
local function petImage(parent: Instance, pet, x: number, y: number, scale: number)
	local _, row = speciesOf(pet)
	if not row then
		return nil
	end
	local img = notify.MonsterImage(parent, row, x, y, scale)
	img.ZIndex = 6
	return img
end

local function content(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = parent
	return f
end

-- 놓아주기 확인 창(모달)
local function confirmRelease(pet, onYes: () -> ())
	if exports.confirmGui then
		exports.confirmGui:Destroy()
	end
	local species = speciesOf(pet)
	local g = Instance.new("ScreenGui")
	g.Name = "PetReleaseConfirm"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 60
	local dim = Instance.new("Frame") -- 뒤 화면 어둡게 + 눌러도 뒤가 안 눌리게
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.Size = UDim2.fromScale(1, 1)
	dim.Active = true
	dim.Parent = g
	local W, H = 200, 118
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(W, H)
	holder.Parent = g
	UI.Scale(holder)
	local panel = UI.Panel(holder, 0, 0, W, H)
	UI.TitleTag(panel, "놓아주기", W / 2, -13)
	local name = ("%s(Lv.%d)"):format(species and species.name or pet.S, pet.L)
	local line1 = UI.Label(panel, name .. "를", 0, 22, { Color = C.accentD })
	line1.Frame.Position = UDim2.fromOffset(W / 2 - line1.Width // 2, 22)
	local line2 = UI.Label(panel, "정말 놓아줄까요?", 0, 40, { Color = C.ink })
	line2.Frame.Position = UDim2.fromOffset(W / 2 - line2.Width // 2, 40)
	local line3 = UI.Label(panel, "다시 돌아오지 않아요", 0, 56, { Color = C.ink })
	line3.Frame.Position = UDim2.fromOffset(W / 2 - line3.Width // 2, 56)
	local function close()
		g:Destroy()
		if exports.confirmGui == g then
			exports.confirmGui = nil
		end
	end
	UI.Button(panel, 14, H - 36, 80, 24, { Color = "plain", Text = "취소", OnClick = close })
	UI.Button(panel, W - 94, H - 36, 80, 24, { Color = "primary", Text = "놓아주기", OnClick = function()
		close()
		onYes()
	end })
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.confirmGui = g
end

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PetBox"
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
	UI.TitleTag(panel, "몬스터 상자", PW / 2, -13)
	UI.Button(panel, PW - 26, 6, 20, 20, { Color = "plain", Icon = "close", OnClick = function()
		popupManager.Close("PetBox")
	end })

	local box = 1
	local selected = nil -- 상자 번호(전체 기준)

	-- 함께 다니기 4칸 + 맺은 수
	UI.Label(panel, "함께 다니기", 12, 12, { Color = C.ink })
	local countLabel = UI.Label(panel, "", 0, 12, { Color = C.ink })
	local partyCells = {}
	for i = 1, pets.SLOTS_MAX do
		local ui = UI.Slot(panel, 12 + (i - 1) * 30, 30, 28)
		local c = content(ui.Instance)
		ui.Instance.Activated:Connect(function()
			local index = exports.data.Party[i]
			if index then
				selected = index
				exports.refresh()
			end
		end)
		partyCells[i] = { ui = ui, content = c }
	end

	-- 박스 칸
	local cells = {}
	for i = 1, COLS * ROWS do
		local col, row = (i - 1) % COLS, (i - 1) // COLS
		local ui = UI.Slot(panel, GRID_X + col * STEP, GRID_Y + row * STEP, SLOT)
		local c = content(ui.Instance)
		local cell = { ui = ui, content = c, index = nil }
		ui.Instance.Activated:Connect(function()
			if cell.index and exports.data.Box[cell.index] then
				selected = cell.index
				exports.refresh()
			end
		end)
		cells[i] = cell
	end
	local navY = GRID_Y + ROWS * STEP + 4
	local boxLabel = UI.Label(panel, "", 0, navY + 4, { Color = C.ink })
	UI.Button(panel, GRID_X, navY, 24, 20, { Color = "plain", Text = "<", OnClick = function()
		box = math.max(1, box - 1)
		exports.refresh()
	end })
	UI.Button(panel, GRID_X + GRID_W - 24, navY, 24, 20, { Color = "plain", Text = ">", OnClick = function()
		box = math.min(exports.data.Boxes or pets.BOXES_START, box + 1)
		exports.refresh()
	end })

	-- 오른쪽 정보
	local bigSlot = UI.Part(panel, "slot", INFO_X, GRID_Y, 44, 44)
	local bigContent = content(bigSlot)
	local nameLabel = UI.Label(panel, "", INFO_X, GRID_Y + 50, { Font = "title", Color = C.accentD })
	local infoLabel = UI.Label(panel, "", INFO_X, GRID_Y + 74, { Color = C.ink })
	local stateLabel = UI.Label(panel, "", INFO_X, GRID_Y + 90, { Color = C.goodD or C.ink })
	local partyButton = UI.Button(panel, INFO_X, PH - 62, INFO_W, 24, { Color = "primary", Text = "함께 다니기" })
	local HALF = (INFO_W - 4) // 2
	local leadButton = UI.Button(panel, INFO_X, PH - 34, HALF, 24, { Color = "plain", Text = "대표로" })
	local releaseButton = UI.Button(panel, INFO_X + HALF + 4, PH - 34, HALF, 24, { Color = "plain", Text = "놓아주기" })

	partyButton.Instance.Activated:Connect(function()
		if not selected then
			return
		end
		local inParty = table.find(exports.data.Party, selected) ~= nil
		if not inParty and #exports.data.Party >= slotCount() then
			notify.Toast(("함께 다닐 칸이 가득 찼어요(%d칸)"):format(slotCount()))
			return
		end
		Net.FireServer("PetAction", if inParty then "Remove" else "Add", selected)
	end)
	leadButton.Instance.Activated:Connect(function()
		if selected then
			Net.FireServer("PetAction", "Lead", selected)
		end
	end)
	releaseButton.Instance.Activated:Connect(function()
		local index = selected
		local pet = index and exports.data.Box[index]
		if not pet then
			return
		end
		confirmRelease(pet, function()
			Net.FireServer("PetAction", "Release", index)
			if selected == index then
				selected = nil
			end
		end)
	end)

	exports.refresh = function()
		local data = exports.data
		local n = slotCount()
		countLabel:SetText(("맺은 친구 %d"):format(#data.Box))
		countLabel.Frame.Position = UDim2.fromOffset(PW - 34 - countLabel.Width, 12)
		for i, cell in partyCells do
			cell.content:ClearAllChildren()
			local index = data.Party[i]
			local pet = index and data.Box[index]
			if pet then
				petImage(cell.content, pet, 1, 2, 0.8)
			elseif i > n then
				UI.Icon(cell.content, "close", 8, 7).ZIndex = 7 -- 잠긴 칸
			end
			cell.ui:SetSelected(index ~= nil and index == selected)
		end
		-- 박스에는 함께 다니지 않는 펫만, 차례로
		local stored = {}
		for index in data.Box do
			if not table.find(data.Party, index) then
				table.insert(stored, index)
			end
		end
		for i, cell in cells do
			cell.content:ClearAllChildren()
			local index = stored[(box - 1) * COLS * ROWS + i]
			cell.index = index
			if index then
				petImage(cell.content, data.Box[index], -2, -1, 0.75)
			end
			cell.ui:SetSelected(index ~= nil and index == selected)
		end
		boxLabel:SetText(("박스 %d/%d"):format(box, data.Boxes or pets.BOXES_START))
		boxLabel.Frame.Position = UDim2.fromOffset(GRID_X + GRID_W // 2 - boxLabel.Width // 2, navY + 4)
		bigContent:ClearAllChildren()
		local pet = selected and data.Box[selected]
		if not pet then
			selected = nil
			nameLabel:SetText("")
			infoLabel:SetText(if #data.Box == 0 then "맺은 몬스터가 없어요" else "칸을 눌러 보세요")
			stateLabel:SetText("")
			partyButton:SetEnabled(false)
			leadButton:SetEnabled(false)
			releaseButton:SetEnabled(false)
			return
		end
		local species = speciesOf(pet)
		petImage(bigContent, pet, 6, 7, 1)
		nameLabel:SetText((species and species.name or pet.S) .. (if pet.C == 1 then " ★" else ""))
		infoLabel:SetText(("Lv.%d · %s"):format(pet.L, BELL_NAMES[pet.B] or "방울"))
		local inParty = table.find(data.Party, selected)
		stateLabel:SetText(if inParty == 1 then "대표 펫" elseif inParty then "함께 다니는 중" else "")
		partyButton:SetText(if inParty then "상자로" else "함께 다니기")
		partyButton:SetEnabled(true)
		leadButton:SetEnabled(inParty ~= 1)
		releaseButton:SetEnabled(true)
	end

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.screenGui = screenGui
	popupManager.Register("PetBox", screenGui, panel)
	exports.refresh()

	if not exports.listening then
		exports.listening = true
		Net.OnClient("PetsUpdated", function(data)
			if typeof(data) == "table" then
				exports.data = data
				exports.data.Paid = data.Paid or 0
				changed()
			end
		end)
		Net.OnClient("StatsUpdated", function(level)
			if typeof(level) == "number" and level ~= exports.level then
				exports.level = level
				changed()
			end
		end)
		task.spawn(function()
			local ok, data = pcall(Net.Invoke, "GetPlayerData")
			if ok and typeof(data) == "table" then
				exports.level = data.Level or 1
				if typeof(data.Pets) == "table" then
					exports.data = data.Pets
					exports.data.Paid = data.Pets.Paid or 0
				end
				changed()
			end
		end)
	end
end

function exports.toggle()
	if exports.screenGui then
		if not popupManager.IsOpen("PetBox") and exports.refresh then
			exports.refresh()
		end
		popupManager.Toggle("PetBox")
	end
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	popupManager.Unregister("PetBox")
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
	if exports.confirmGui then
		exports.confirmGui:Destroy()
		exports.confirmGui = nil
	end
	exports.refresh = nil
end

return exports
