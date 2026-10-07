-- 게임 화면의 틀. 층이 둘이다(사용자 2026-10-07: 산나비 계열 도트 게임의 방식 — "훌룡합니다. 하지만 글씨비율은 좀더 작아야합니다"):
--   view = 게임 세계. 384x216도트를 화면에 들어가는 가장 큰 정수 배율로 키워 가운데에 놓는다(도트가 뭉개지지 않게).
--   ui   = 화면의 글씨와 틀. 게임의 도트보다 고운 격자에 따로 그린다 — 1080p에서 960x540(한 점이 화면 2픽셀. 게임의 도트는 5픽셀).
--          격자의 크기는 창 크기에 따라 768x432부터 1152x648까지 달라진다. 그래서 그 안의 것은 화면의 구석(위 · 아래 / 왼쪽 · 가운데 · 오른쪽)에 붙여 놓는다.
--  배율은 층마다 UIScale 하나로 건다 — 그 아래의 모든 것은 그 층의 좌표(1 = 한 점)를 그대로 쓴다.
--  작은 화면(스마트폰): 게임 세계를 정수 배율로만 키우면 화면 높이가 432보다 낮은 폰에서는 1배(384x216)가 되고, 화면 틀의 격자도 384x216이 되어
--   960x540을 기준으로 짠 화면의 칸들이 서로 겹쳐 화면을 다 덮는다(사용자 2026-10-08: "모바일에서 거의 플레이가 불가능한 수준 … ui가 전면을 다가리는").
--   그래서 2배가 안 되는 화면에서는 정수 배율을 버리고 화면에 꽉 차게 키운다 — 화면 틀의 격자는 가장 작은 격자(768x432) 그대로다(화면 틀의 한 점 = 게임 도트의 반).
--  Studio에서 스마트폰 화면을 흉내 내려면 화면 틀(LuneStage)의 속성 Screen = "844x390"처럼 준다(그 크기의 화면인 것처럼 가운데에 그린다). 손가락 단추는 속성 Touch = true.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage.shared.lune.config.game)
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])

local Stage = {}
Stage.scale = 1 -- 게임 세계의 배율(화면 픽셀 / 게임 도트)
Stage.uiScale = 1 -- 화면 틀의 배율(화면 픽셀 / 화면 틀의 한 점)
Stage.ratio = 1 -- 게임 도트 하나가 화면 틀의 몇 점인가(1080p에서 2.5)
Stage.uiW, Stage.uiH = UI.grid.w, UI.grid.h -- 지금 화면 틀의 격자
Stage.REF_W, Stage.REF_H = UI.grid.w, UI.grid.h -- 자리를 적을 때의 기준 격자(960x540)
Stage.insetTop = 0 -- 화면 왼쪽 위의 Roblox 기본 단추(메뉴 · 채팅)가 가리는 높이(화면 틀의 점) — 왼쪽 위에 붙는 것은 이만큼 내려 놓는다

local resized = {} -- 격자가 바뀌었을 때 부를 것들

-- 게임 세계의 배율 s에서 화면 틀의 배율: 격자의 높이가 540에 가장 가깝게(s 2 · 3 → 1, 4 · 5 · 6 → 2, 7 · 8 → 3 …)
function Stage.uiScaleFor(s: number): number
	return math.max(1, math.floor(0.4 * s + 0.5))
end

-- 화면 크기(w x h)에서의 두 배율: 게임 세계의 배율, 화면 틀의 배율.
--  2배 이상 들어가는 화면: 게임 세계는 들어가는 가장 큰 정수 배율(도트가 뭉개지지 않게), 화면 틀은 uiScaleFor.
--  그보다 작은 화면(스마트폰): 게임 세계를 화면에 꽉 차게(소수 배율), 화면 틀의 격자는 가장 작은 격자 그대로(게임 도트 하나 = 화면 틀의 두 점).
function Stage.scalesFor(w: number, h: number): (number, number)
	local fitScale = math.min(w / G.VIEW_W, h / G.VIEW_H)
	if fitScale >= 2 then
		local s = math.floor(fitScale)
		return s, Stage.uiScaleFor(s)
	end
	local s = math.max(0.5, fitScale)
	return s, s * G.VIEW_W / UI.grid.min.w
end

function Stage.init()
	-- Roblox가 기본으로 띄우는 것 가운데 이 게임이 쓰지 않는 것을 끈다.
	--  참가자 목록은 보이지 않을 때에도 화면 오른쪽 위를 덮어 그 자리의 단추(스마트폰 메뉴 · 창의 닫기)를 가로챈다.
	--  기본 조이스틱 · 뛰기 단추는 우리 터치 단추(touch.luau)와 겹친다. 채팅은 그대로 둔다.
	pcall(function()
		for _, kind in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
			StarterGui:SetCoreGuiEnabled(kind, false)
		end
		GuiService.TouchControlsEnabled = false
		-- 스마트폰은 가로 화면으로만 쓴다(세로로 세우면 게임 화면이 화면 폭에 맞춰 아주 작아진다)
		Players.LocalPlayer:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
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

	-- 틀(holder)은 화면의 정수 점 자리에 놓는다(가운데가 반 점에 걸리면 도트가 어긋난다). 그 안의 층에만 배율을 건다
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

	local viewScale = Instance.new("UIScale")
	viewScale.Parent = view

	local ui = Instance.new("Frame")
	ui.Name = "Ui"
	ui.BackgroundTransparency = 1
	ui.BorderSizePixel = 0
	ui.ZIndex = 10
	ui.Parent = holder

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = ui

	local function fit()
		local real = gui.AbsoluteSize
		local size = real
		local fake = gui:GetAttribute("Screen")
		if typeof(fake) == "string" then
			local fw, fh = fake:match("^(%d+)x(%d+)$")
			if fw and fh then
				size = Vector2.new(math.min(real.X, tonumber(fw) :: number), math.min(real.Y, tonumber(fh) :: number))
			end
		end
		local s, us = Stage.scalesFor(size.X, size.Y)
		local changed = s ~= Stage.scale or us ~= Stage.uiScale
		Stage.scale, Stage.uiScale, Stage.ratio = s, us, s / us
		Stage.uiW, Stage.uiH = G.VIEW_W * s / us, G.VIEW_H * s / us
		viewScale.Scale = s
		uiScale.Scale = us
		ui.Size = UDim2.fromOffset(Stage.uiW, Stage.uiH)
		local hw, hh = math.floor(G.VIEW_W * s + 0.5), math.floor(G.VIEW_H * s + 0.5)
		holder.Size = UDim2.fromOffset(hw, hh)
		local top = math.floor((real.Y - hh) / 2)
		holder.Position = UDim2.fromOffset(math.floor((real.X - hw) / 2), top)
		-- Roblox 기본 단추의 띠(화면 위 58픽셀쯤)가 게임 화면의 위쪽을 얼마나 덮는가
		local okInset, inset = pcall(function()
			return GuiService:GetGuiInset()
		end)
		Stage.insetTop = if okInset then math.max(0, math.ceil((inset.Y - top) / us)) else 0
		if changed then
			for _, fn in resized do
				fn()
			end
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	gui:GetAttributeChangedSignal("Screen"):Connect(fit)
	fit()

	Stage.gui = gui
	Stage.view = view
	Stage.ui = ui
	return Stage
end

-- 화면 틀의 격자가 바뀌면(창 크기가 바뀌어 배율이 달라지면) fn을 부른다
function Stage.onResize(fn: () -> ())
	table.insert(resized, fn)
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

-- 화면 틀의 층에 놓는 자리. at = 붙는 구석("tl" · "tc" · "tr" · "bl" · "bc" · "br"), (x, y) = 기준 격자(960x540)에서의 자리.
--  격자가 달라져도 그 구석에서의 거리가 같게 놓인다. 돌려주는 틀 안에서는 (0, 0)부터 그대로 쓴다.
function Stage.atPosition(at: string, x: number, y: number): UDim2
	local fy = if at:sub(1, 1) == "b" then 1 else 0
	local side = at:sub(2, 2)
	local fx = if side == "r" then 1 elseif side == "c" then 0.5 else 0
	-- 왼쪽 위에 붙는 것은 Roblox 기본 단추 아래로 내린다
	local down = if at == "tl" then Stage.insetTop else 0
	return UDim2.new(fx, x - Stage.REF_W * fx, fy, y - Stage.REF_H * fy + down)
end

function Stage.place(parent: Instance, name: string, at: string, x: number, y: number, w: number, h: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = Stage.atPosition(at, x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.Parent = parent
	return frame
end

-- 화면 칸(data/ui.generated.luau의 hud.*)의 자리에 놓는 틀
function Stage.placeRect(parent: Instance, name: string, r): Frame
	return Stage.place(parent, name, r.at, r.x, r.y, r.w, r.h)
end

return Stage
