-- 장비 탭. 메뉴(mainMenu.luau)의 칼 교차 아이콘을 누르면 열린다 — 인벤토리(가방) 패널과는
-- 별개의 패널이다. 착용 중인 장비 슬롯(무기/방어구)과 현재 능력치(레벨/체력/공격력/방어력)를
-- 보여주고, 장비 슬롯을 누르면 해제된다(착용은 가방에서 아이템을 누르면 됨 — inventory.luau).
-- 착용 장비 데이터는 inventory.luau가 서버에서 받아 캐시하므로 여기선 그걸 읽어서 그리기만 한다.
-- 패널 틀/닫기 버튼 에셋과 좌표는 inventory.luau와 같은 큰 나무 액자를 그대로 쓴다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)
local popupManager = require(script.Parent.Parent.popupManager)
local items = require(ReplicatedStorage.shared.data.items)
local inventory = require(script.Parent.inventory)
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)

local PANEL_ASSET = "rbxassetid://118251374996221"
local PANEL_NATIVE = Vector2.new(482, 341)
local INNER = { x = 44, y = 47, w = 418, h = 261 }

local CLOSE_ASSET = "rbxassetid://86025600185150"
local CLOSE_NATIVE = Vector2.new(90, 83)

local SLOT_SIZE = 64
local SLOT_BG = Color3.fromRGB(210, 195, 165)
local SLOT_BORDER = Color3.fromRGB(120, 95, 60)
local SLOT_HOVER_BORDER = Color3.fromRGB(170, 40, 30)
local TEXT_COLOR = Color3.fromRGB(70, 45, 20)


local EQUIP_SLOTS = {
	{ Name = "Weapon", Label = "무기" },
	{ Name = "Armor", Label = "방어구" },
}

local function makeText(parent: Instance, size: number, position: UDim2, boxSize: UDim2, xAlign: Enum.TextXAlignment)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = boxSize
	label.FontFace = uiTheme.Font
	label.TextSize = size
	label.TextColor3 = TEXT_COLOR
	label.TextXAlignment = xAlign
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = parent
	return label
end

local exports = {}

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Equipment"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true

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
	panel.Visible = false
	panel.Parent = root
	uiTheme.applyResponsiveScale(panel, PANEL_NATIVE)

	makeText(panel, 18, UDim2.fromOffset(INNER.x + 16, INNER.y + 10), UDim2.fromOffset(160, 22), Enum.TextXAlignment.Left).Text =
		"장비"

	-- 왼쪽: 장비 슬롯 두 개(라벨 + 슬롯).
	local equipSlots = {}
	for i, info in EQUIP_SLOTS do
		local x = INNER.x + 30 + (i - 1) * 96
		local y = INNER.y + 70
		makeText(panel, 15, UDim2.fromOffset(x - 16, y - 24), UDim2.fromOffset(SLOT_SIZE + 32, 18), Enum.TextXAlignment.Center).Text =
			info.Label

		local slot = uiTheme.mkSlot({
			Name = "Equip" .. info.Name,
			Parent = panel,
			BackgroundColor3 = SLOT_BG,
			BackgroundTransparency = 0.25,
			StrokeColor = SLOT_BORDER,
			HoverStrokeColor = SLOT_HOVER_BORDER,
		})
		slot.frame.Position = UDim2.fromOffset(x, y)
		slot.frame.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)

		local placeholder = Instance.new("TextLabel")
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.fromScale(1, 1)
		placeholder.FontFace = uiTheme.Font
		placeholder.TextSize = 22
		placeholder.TextColor3 = TEXT_COLOR
		placeholder.Text = ""
		placeholder.ZIndex = 2
		placeholder.Parent = slot.frame
		slot.placeholder = placeholder

		slot.button.Activated:Connect(function()
			if inventory.getEquipment()[info.Name] then
				Net.FireServer("EquipAction", "Unequip", info.Name)
			end
		end)
		equipSlots[info.Name] = slot
	end

	makeText(panel, 12, UDim2.fromOffset(INNER.x + 30, INNER.y + 150), UDim2.fromOffset(190, 34), Enum.TextXAlignment.Left).Text =
		"가방에서 장비를 누르면 착용,\n여기서 누르면 해제됩니다."

	-- 오른쪽: 능력치.
	makeText(panel, 15, UDim2.fromOffset(INNER.x + 236, INNER.y + 46), UDim2.fromOffset(150, 20), Enum.TextXAlignment.Left).Text =
		"능력치"
	local statsLabel = makeText(panel, 16, UDim2.fromOffset(INNER.x + 236, INNER.y + 76), UDim2.fromOffset(160, 110), Enum.TextXAlignment.Left)
	statsLabel.LineHeight = 1.35

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
		popupManager.Close("Equipment")
	end)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
	popupManager.Register("Equipment", screenGui, panel)
	exports.panel = panel

	local function refresh()
		local equipment = inventory.getEquipment()
		local attack, defense = balance.BASE_ATTACK, balance.BASE_DEFENSE
		for _, info in EQUIP_SLOTS do
			local slot = equipSlots[info.Name]
			local def = items[equipment[info.Name]]
			if def then
				slot.icon.Image = def.Icon
				slot.placeholder.Text = if def.Icon == "" then uiTheme.ShortName(def.Name) else ""
				attack += def.Attack or 0
				defense += def.Defense or 0
			else
				slot.icon.Image = ""
				slot.placeholder.Text = ""
			end
		end

		local character = CrossPlatformService.Character
		local level = character and character.Level or 1
		local health = character and character.Health or 0
		local maxHealth = character and character.MaxHealth or 0
		statsLabel.Text = ("경지  %d\n체력  %d / %d\n공격력  %d\n방어력  %d"):format(
			level, math.floor(health + 0.5), maxHealth, attack, defense
		)
	end

	refresh()
	-- 리스너는 세션 동안 한 번만 등록하고(inventory.luau 캐시가 UI보다 오래 산다), 씬을 옮겨
	-- UI가 새로 만들어지면 그 시점의 refresh만 가리키게 갈아끼운다.
	exports.refresh = refresh
	if not exports.listening then
		exports.listening = true
		inventory.onEquipmentChanged(function()
			if exports.refresh then
				exports.refresh()
			end
		end)
	end

	-- 체력/레벨은 전투 중에도 바뀌므로 패널이 열려 있는 동안만 주기적으로 갱신.
	local clock = 0
	exports.connection = RunService.Heartbeat:Connect(function(delta)
		clock += delta
		if clock >= 0.25 and panel.Visible then
			clock = 0
			refresh()
		end
	end)
end

-- mainMenu.luau의 장비 버튼이 호출해서 패널을 열고/닫는다.
function exports.toggle()
	if not exports.panel then
		return
	end
	popupManager.Toggle("Equipment")
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	exports.refresh = nil
	popupManager.Unregister("Equipment")
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
	exports.panel = nil
end

return exports
