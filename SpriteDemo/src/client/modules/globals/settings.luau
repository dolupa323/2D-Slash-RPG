-- 설정 창 — 에셋 공방 UI 규칙(도트 패널·제목판·민트 게이지 슬라이더)으로 다시 만들었다(2026-09-29).
-- HUD 오른쪽 아래 톱니바퀴 버튼으로 연다. 지금은 오디오 볼륨(전체/배경음악/효과음)만 있다.
-- 볼륨은 SoundService 아래 SoundGroup(Master > Music/SFX)에 건다 — 배경음악/효과음을 각 그룹에 넣으면
-- 이 슬라이더가 바로 먹는다. 값은 이번 접속 동안만 유지된다.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local popupManager = require(script.Parent.Parent.popupManager)
local UI = require(script.Parent.Parent.ui.pixelUI)

local C = UI.colors
local PANEL_W, PANEL_H = 220, 136
local TRACK_X, TRACK_W = 16, 150
local CHANNELS = {
	{ Name = "Master", Label = "전체 음량" },
	{ Name = "Music", Label = "배경음악" },
	{ Name = "SFX", Label = "효과음" },
}

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

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	holder.Parent = screenGui
	UI.Scale(holder)

	local panel = UI.Panel(holder, 0, 0, PANEL_W, PANEL_H)
	UI.TitleTag(panel, "설정", PANEL_W / 2, -13)
	UI.Button(panel, PANEL_W - 26, 6, 20, 20, { Color = "plain", Icon = "close", OnClick = function()
		popupManager.Close("Settings")
	end })

	local dragging = nil
	local function setValue(entry, value: number)
		value = math.clamp(value, 0, 1)
		entry.group.Volume = value
		entry.bar:SetRatio(value)
		entry.knob.Position = UDim2.fromOffset(TRACK_X + math.floor((TRACK_W - 8) * value + 0.5), entry.y - 2)
		entry.value:SetText(("%d%%"):format(math.floor(value * 100 + 0.5)))
	end
	local function setFromX(entry, screenX: number)
		local track = entry.bar.Instance
		setValue(entry, (screenX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1))
	end

	for i, info in CHANNELS do
		local rowY = 30 + (i - 1) * 32
		UI.Label(panel, info.Label, TRACK_X, rowY, { Color = C.ink })
		local y = rowY + 15
		local bar = UI.Bar(panel, TRACK_X, y, TRACK_W, "mint")
		bar.Instance.Active = true
		local knob = UI.Part(panel, "button_plain", TRACK_X, y - 2, 8, 13)
		knob.ZIndex = bar.Instance.ZIndex + 3
		local value = UI.Label(panel, "", TRACK_X + TRACK_W + 8, y - 1, { Color = C.ink })
		local entry = { group = getGroup(info.Name), bar = bar, knob = knob, value = value, y = y }
		setValue(entry, entry.group.Volume)
		bar.Instance.InputBegan:Connect(function(input)
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

	screenGui.Parent = playerGui
	exports.screenGui = screenGui
	exports.panel = panel
	popupManager.Register("Settings", screenGui, panel)
end

-- HUD의 톱니바퀴 버튼이 호출해서 창을 열고/닫는다.
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
