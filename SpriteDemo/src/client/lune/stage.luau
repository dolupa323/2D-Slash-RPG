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
local UserInputService = game:GetService("UserInputService")
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
--  touch = 손가락으로 하는 화면(태블릿 — 2026-10-23 사용자 "아이패드로 플레이할때 불편하다고하네"): 정수 배율로는 화면을 6% 넘게 비우면(10.2인치 iPad 1080x810 → 2배 = 화면의 38%)
--   폰처럼 꽉 차게 키운다 · 화면 틀은 기준 격자(960x540). PC는 그대로 정수 배율(도트가 뭉개지지 않게). [제가 정한 것 — 6%]
function Stage.scalesFor(w: number, h: number, touch: boolean?): (number, number)
	local fitScale = math.min(w / G.VIEW_W, h / G.VIEW_H)
	if fitScale >= 2 then
		local s = math.floor(fitScale)
		if touch and s < fitScale * 0.94 then
			return fitScale, fitScale * G.VIEW_W / UI.grid.w
		end
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
	Stage.gui = gui -- (먼저 — 처음 맞출 때 Touch 속성을 본다: Stage.touchLike)

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
		-- 손가락 화면에서 글 칸을 쓰는 동안은 다시 맞추지 않는다(2026-11-11 밤 — 사용자: "모바일에서 경매장 액수라던지 뭐 다른 숫자를 입력해야하는 소요가 생기면 그냥 와다다 ui 가 꺼져버리는 버그"):
		--  글 칸을 누르면 화면 키보드가 올라오며 화면 틀의 크기 · Roblox 단추 띠의 높이가 바뀐다 → 배율 · 띠가 달라졌다고 보고 onResize를 불러 창을 모두 닫았다(ui/windows.luau).
		--  키보드가 떠 있는 동안은 그대로 두고, 칸에서 손을 떼면(TextBoxFocusReleased — 아래) 그때 한 번 맞춘다: 키보드가 내려가 크기가 돌아와 있으면 바뀐 것이 없어 창이 그대로다
		if Stage.touchLike() and UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		local real = gui.AbsoluteSize
		local size = real
		local fake = gui:GetAttribute("Screen")
		if typeof(fake) == "string" then
			local fw, fh = fake:match("^(%d+)x(%d+)$")
			if fw and fh then
				size = Vector2.new(math.min(real.X, tonumber(fw) :: number), math.min(real.Y, tonumber(fh) :: number))
			end
		end
		local s, us = Stage.scalesFor(size.X, size.Y, Stage.touchLike())
		local changed = s ~= Stage.scale or us ~= Stage.uiScale
		local scaled = changed -- (배율이 정말 바뀌었는가 — onResize의 fn에 넘긴다: 창은 이때만 닫는다 · 2026-11-11 밤)
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
		local insetWas = Stage.insetTop
		Stage.insetTop = if okInset then math.max(0, math.ceil((inset.Y - top) / us)) else 0
		changed = changed or Stage.insetTop ~= insetWas -- (배율이 같아도 창의 높이가 바뀌어 Roblox 단추 띠가 덮는 높이가 바뀌면 다시 놓는다 — 달빛 상점의 윗줄: 2026-11-10)
		if changed then
			for _, fn in resized do
				fn(scaled) -- scaled = 배율이 바뀌었다(false = Roblox 단추 띠만 — 다시 놓기만 하면 된다)
			end
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	gui:GetAttributeChangedSignal("Screen"):Connect(fit)
	-- 글 칸에서 손을 뗐다: 쓰는 동안 미뤄 둔 맞추기를 한 번(키보드가 내려가며 크기가 바뀌는 것보다 먼저 오면 그 크기 바뀜이 다시 부른다 — 2026-11-11 밤)
	UserInputService.TextBoxFocusReleased:Connect(function()
		task.defer(fit)
	end)
	Stage.refit = fit -- 터치인가가 바뀌면(touch.luau) 다시 맞춘다
	fit()

	Stage.gui = gui
	Stage.view = view
	Stage.ui = ui
	return Stage
end

-- 손가락으로 하는 화면인가(터치 단추를 켜는 판단 — touch.luau · countBox.luau가 같이 쓴다). 2026-10-23:
--  전에는 TouchEnabled and not KeyboardEnabled — iPad에 키보드 케이스를 끼우면 KeyboardEnabled가 켜져 터치 단추가 아예 나오지 않았을 수 있다.
--  → Roblox의 PreferredInput(마지막으로 쓴 입력 — 터치를 쓰면 Touch)이 있으면 그것으로. Studio에서는 화면 틀의 속성 Touch(true · false)가 앞선다
function Stage.touchLike(): boolean
	local forced = if Stage.gui then Stage.gui:GetAttribute("Touch") else nil
	if forced ~= nil then
		return forced == true
	end
	local ok, pref = pcall(function()
		return UserInputService.PreferredInput == Enum.PreferredInput.Touch
	end)
	if ok then
		return pref
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- 화면 틀의 격자가 바뀌면(창 크기가 바뀌어 배율이 달라지면) fn을 부른다
-- 돌려주는 것: 그 함수를 빼는 함수(화면을 닫을 때 — 2026-10-18 검토: 캐릭터 고르기를 열 때마다 하나씩 쌓여 닫힌 화면을 붙들고 있었다)
function Stage.onResize(fn: (scaled: boolean?) -> ()): () -> () -- (scaled = 배율이 바뀌었는가 — false면 Roblox 단추 띠만 바뀌었다: 2026-11-11 밤)
	table.insert(resized, fn)
	return function()
		local i = table.find(resized, fn)
		if i then
			table.remove(resized, i)
		end
	end
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

-- ---------- 옮긴 자리 · 화면 안으로(2026-11-12 사용자: "지금 채팅창처럼 모든 ui 가 끌어서 자리를 옮길수 있어야해 지금 모바일에서 잘려보이는경우 엄청많아") ----------
--  Stage.moved[판의 이름] = 처음 자리에서 옮긴 만큼 { x, y }(화면 틀의 점) — 「UI 배치」(ui/arrange.luau) · 창의 제목 줄 끌기(ui/windows.luau)가 고치고,
--   계정의 화면 설정에 기기 종류(pc · touch)마다 저장한다(viewOpts.luau ViewOpts.ui · sim/account.luau sound.ui).
--  Stage.fit = 판이 화면 밖으로 나가지 않게: 화면 틀보다 작은 판은 화면 안으로 민다(폰의 작은 격자 768x432에서 기준 격자 960x540으로 놓은 판의 끝이 잘려 보였다) ·
--   화면보다 큰 판(배경 · 덮개)은 그 쪽으로는 그대로 둔다
Stage.moved = {} :: { [string]: { x: number, y: number } }
Stage.placed = {} :: { [string]: any } -- [이름] = { frame, at, x, y, w, h } — 마지막으로 놓인 판(「UI 배치」가 끌 판을 찾는다)
local function anchorOf(at: string): (number, number, number)
	local fy = if at:sub(1, 1) == "b" then 1 else 0
	local side = at:sub(2, 2)
	local fx = if side == "r" then 1 elseif side == "c" then 0.5 else 0
	return fx, fy, if at == "tl" then Stage.insetTop else 0
end
function Stage.fit(at: string, x: number, y: number, w: number, h: number): (number, number)
	local fx, fy, down = anchorOf(at)
	local left = fx * Stage.uiW + x - Stage.REF_W * fx
	local top = fy * Stage.uiH + y - Stage.REF_H * fy + down
	if w <= Stage.uiW then
		x += math.clamp(left, 0, Stage.uiW - w) - left
	end
	if h <= Stage.uiH then
		y += math.clamp(top, 0, Stage.uiH - h) - top
	end
	return x, y
end
-- 느슨하게 화면 안으로(창을 끌 때 — 2026-11-12 사용자: "창 끌어다 자리 바꾸는거 모바일에서 어느정도 터치보정이 되어야해 영역밖으로 끌어다놓는다고하면 바로 제자리로 돌아가는게 너무판정이 빡세다"):
--  창 전체가 아니라 — 위의 제목 줄(keepH)은 늘 화면 안 · 오른쪽 끝(닫기 X가 있다)은 화면 안 · 왼쪽과 아래로는 keepW · keepH만 남으면 화면 밖으로 나가도 된다
function Stage.fitLoose(at: string, x: number, y: number, w: number, h: number, keepW: number, keepH: number): (number, number)
	local fx, fy, down = anchorOf(at)
	local left = fx * Stage.uiW + x - Stage.REF_W * fx
	local top = fy * Stage.uiH + y - Stage.REF_H * fy + down
	local lo, hi = -(w - keepW), Stage.uiW - w
	if hi >= lo then
		x += math.clamp(left, lo, hi) - left
	end
	local tlo, thi = 0, Stage.uiH - keepH
	if thi >= tlo then
		y += math.clamp(top, tlo, thi) - top
	end
	return x, y
end

-- 그 이름의 판을 (x, y)(처음 자리)에 놓을 때의 자리: 옮긴 만큼을 더하고 화면 안으로
function Stage.movedPosition(name: string, at: string, x: number, y: number, w: number, h: number): UDim2
	local off = Stage.moved[name]
	if off then
		x, y = x + off.x, y + off.y
	end
	x, y = Stage.fit(at, x, y, w, h)
	return Stage.atPosition(at, x, y)
end
-- 이미 놓인 판을 다시 놓는다(그 판이 제 자리를 바꿀 때 — 옮긴 만큼 · 화면 안을 지킨다). 판의 크기는 지금의 Size
function Stage.move(frame: GuiObject, at: string, x: number, y: number)
	local w, h = frame.Size.X.Offset, frame.Size.Y.Offset
	frame.Position = Stage.movedPosition(frame.Name, at, x, y, w, h)
	local rec = Stage.placed[frame.Name]
	if rec and rec.frame == frame then
		rec.at, rec.x, rec.y, rec.w, rec.h = at, x, y, w, h
	end
end

function Stage.place(parent: Instance, name: string, at: string, x: number, y: number, w: number, h: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = Stage.movedPosition(name, at, x, y, w, h)
	frame.Size = UDim2.fromOffset(w, h)
	frame.Parent = parent
	Stage.placed[name] = { frame = frame, at = at, x = x, y = y, w = w, h = h }
	return frame
end

-- 화면 칸(data/ui.generated.luau의 hud.*)의 자리에 놓는 틀
function Stage.placeRect(parent: Instance, name: string, r): Frame
	return Stage.place(parent, name, r.at, r.x, r.y, r.w, r.h)
end

return Stage
