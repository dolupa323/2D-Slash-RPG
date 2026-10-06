-- 게임 화면의 틀. 게임 화면은 384x216도트이고, 화면에 들어가는 가장 큰 정수 배율로 키워 가운데에 놓는다(도트가 뭉개지지 않게).
--  배율은 UIScale 하나로 건다 — 그 아래의 모든 것은 도트 좌표(1 = 1도트)를 그대로 쓴다.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage.shared.lune.config.game)

local Stage = {}
Stage.scale = 1

function Stage.init()
	-- Roblox가 기본으로 띄우는 것 가운데 이 게임이 쓰지 않는 것을 끈다.
	--  참가자 목록은 보이지 않을 때에도 화면 오른쪽 위를 덮어 그 자리의 단추(스마트폰 메뉴 · 창의 닫기)를 가로챈다.
	--  기본 조이스틱 · 뛰기 단추는 우리 터치 단추(touch.luau)와 겹친다. 채팅은 그대로 둔다.
	pcall(function()
		for _, kind in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
			StarterGui:SetCoreGuiEnabled(kind, false)
		end
		GuiService.TouchControlsEnabled = false
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "LuneStage"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- 게임 화면 밖(배율이 딱 맞지 않을 때의 가장자리)은 검게 덮는다
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	back.BorderSizePixel = 0
	back.Parent = gui

	-- 틀(holder)은 화면의 정수 점 자리에 놓는다(가운데가 반 점에 걸리면 도트가 어긋난다). 그 안의 view에만 배율을 건다
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Parent = gui

	local view = Instance.new("Frame")
	view.Name = "View"
	view.Size = UDim2.fromOffset(G.VIEW_W, G.VIEW_H)
	view.BorderSizePixel = 0
	view.Parent = holder

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = view

	local function fit()
		local size = gui.AbsoluteSize
		local s = math.max(1, math.floor(math.min(size.X / G.VIEW_W, size.Y / G.VIEW_H)))
		Stage.scale = s
		uiScale.Scale = s
		holder.Size = UDim2.fromOffset(G.VIEW_W * s, G.VIEW_H * s)
		holder.Position = UDim2.fromOffset(math.floor((size.X - G.VIEW_W * s) / 2), math.floor((size.Y - G.VIEW_H * s) / 2))
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	Stage.gui = gui
	Stage.view = view
	return Stage
end

-- 도트 좌표에 놓는 그림 한 장(도트 그림용 설정)
function Stage.image(parent: Instance, name: string, image: string, w: number, h: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.ScaleType = Enum.ScaleType.Stretch
	label.Size = UDim2.fromOffset(w, h)
	label.Image = image
	label.Parent = parent
	return label
end

-- 그림을 담는 빈 틀(겹치는 차례를 틀 단위로 정한다)
function Stage.group(parent: Instance, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z
	frame.Parent = parent
	return frame
end

return Stage
