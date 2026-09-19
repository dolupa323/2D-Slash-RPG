-- 설정 메뉴(ROADMAP Phase 4). 메뉴(mainMenu.luau)의 톱니바퀴 아이콘으로 연다. 지금은 오디오
-- 볼륨(전체/배경음악/효과음) 슬라이더뿐이다. 볼륨은 SoundService 아래 SoundGroup(Master >
-- Music/SFX)으로 걸어둔다 — Phase 8(오디오)에서 만들 배경음악/효과음은 각각 Music/SFX
-- 그룹에 넣기만 하면 이 슬라이더가 바로 먹는다. 값은 이번 접속 동안만 유지된다(저장은
-- 나중에 필요해지면 서버 데이터에 추가).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uiTheme = require(ReplicatedStorage.shared.util.uiTheme)
local popupManager = require(script.Parent.Parent.popupManager)

local PANEL_ASSET = "rbxassetid://118251374996221"
local PANEL_NATIVE = Vector2.new(482, 341)
local INNER = { x = 44, y = 47, w = 418, h = 261 }
local CLOSE_ASSET = "rbxassetid://86025600185150"
local CLOSE_NATIVE = Vector2.new(90, 83)

local TEXT_COLOR = Color3.fromRGB(70, 45, 20)
local TRACK_COLOR = Color3.fromRGB(190, 172, 138)
local FILL_COLOR = Color3.fromRGB(150, 60, 40)
local TRACK_WIDTH = 220
local TRACK_HEIGHT = 12

local CHANNELS = {
	{ Name = "Master", Label = "전체 음량" },
	{ Name = "Music", Label = "배경음악" },
	{ Name = "SFX", Label = "효과음" },
}

-- SoundService 아래에 그룹을 한 번만 만든다(Master가 부모, Music/SFX가 자식).
local function ensureSoundGroups()
	local master = SoundService:FindFirstChild("Master")
	if not master then
		master = Instance.new("SoundGroup")
		master.Name = "Master"
		master.Volume = 1
		master.Parent = SoundService
	end
	for _, name in { "Music", "SFX" } do
		if not master:FindFirstChild(name) then
			local group = Instance.new("SoundGroup")
			group.Name = name
			group.Volume = 1
			group.Parent = master
		end
	end
	return master
end

local function getGroup(name: string): SoundGroup
	local master = ensureSoundGroups()
	return if name == "Master" then master else master:FindFirstChild(name)
end

local function makeText(parent: Instance, text: string, size: number, position: UDim2, boxSize: UDim2)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = boxSize
	label.FontFace = uiTheme.Font
	label.TextSize = size
	label.TextColor3 = TEXT_COLOR
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

local exports = {}

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end
	ensureSoundGroups()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Settings"
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

	makeText(panel, "설정", 18, UDim2.fromOffset(INNER.x + 16, INNER.y + 10), UDim2.fromOffset(160, 22))

	local dragging = nil -- { group, fill, valueLabel, track }

	local function setFromX(entry, screenX: number)
		local left = entry.track.AbsolutePosition.X
		local width = math.max(entry.track.AbsoluteSize.X, 1)
		local value = math.clamp((screenX - left) / width, 0, 1)
		entry.group.Volume = value
		entry.fill.Size = UDim2.fromScale(value, 1)
		entry.valueLabel.Text = ("%d%%"):format(math.floor(value * 100 + 0.5))
	end

	for i, info in CHANNELS do
		local y = INNER.y + 60 + (i - 1) * 56
		makeText(panel, info.Label, 15, UDim2.fromOffset(INNER.x + 30, y), UDim2.fromOffset(120, 22))

		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(INNER.x + 30, y + 26)
		track.Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT)
		track.BackgroundColor3 = TRACK_COLOR
		track.BorderSizePixel = 0
		track.Active = true
		track.Parent = panel
		uiTheme.AddCorner(track, "full")

		local group = getGroup(info.Name)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(group.Volume, 1)
		fill.BackgroundColor3 = FILL_COLOR
		fill.BorderSizePixel = 0
		fill.Parent = track
		uiTheme.AddCorner(fill, "full")

		local valueLabel = makeText(
			panel, ("%d%%"):format(math.floor(group.Volume * 100 + 0.5)), 14,
			UDim2.fromOffset(INNER.x + 30 + TRACK_WIDTH + 12, y + 20), UDim2.fromOffset(50, 22)
		)

		local entry = { group = group, fill = fill, valueLabel = valueLabel, track = track }
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = entry
				setFromX(entry, input.Position.X)
			end
		end)
	end

	exports.moveConnection = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(dragging, input.Position.X)
		end
	end)
	exports.endConnection = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)

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
		popupManager.Close("Settings")
	end)

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
	exports.panel = panel
	popupManager.Register("Settings", screenGui, panel)
end

-- mainMenu.luau의 설정 버튼이 호출해서 패널을 열고/닫는다.
function exports.toggle()
	if not exports.panel then
		return
	end
	popupManager.Toggle("Settings")
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	popupManager.Unregister("Settings")
	for _, key in { "moveConnection", "endConnection" } do
		if exports[key] then
			exports[key]:Disconnect()
			exports[key] = nil
		end
	end
	if exports.screenGui then
		exports.screenGui:Destroy()
		exports.screenGui = nil
	end
	exports.panel = nil
end

return exports
