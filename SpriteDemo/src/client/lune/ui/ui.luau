-- 화면 틀의 부품 — 판 · 칸 · 단추 · 키 딱지 · 띠 · 글 · 그림. 화면의 고운 격자(client/lune/stage.luau의 ui 층 — 1080p에서 960x540)에 놓는다.
--  방식은 산나비 계열 도트 게임(사용자 2026-10-07: "제가말하는건 산나비같은 도트게임을말하는거에요" → 실제 크기 시안을 보고 "훌룡합니다"):
--   판은 무채색에 강조색 하나(민트), 고른 것의 표시는 민트 테두리 한 가지. 늘 보이는 글은 판 없이 어두운 테두리를 두른 글씨로 게임 화면 위에 바로 적는다.
--   글씨는 둘뿐: 작은 글씨(small = 갈무리9 — 화면에서 20픽셀)와 본문 글씨(body = 갈무리11 — 24픽셀, 이름 · 말 · 제목).
--   그림은 둘: 화면의 것(창을 여는 단추 · 기술 칸 · 버프)은 24x24(pic), 게임 세계의 것(장비 — 땅에 떨어진 것과 같은 그림)은 게임의 굵은 도트 그대로(worldIcon).
--  부품 그림 한 장(ui_kit.png)과 그 자리 · 색 · 치수는 shared/lune/data/kit.generated.luau — 공방의 tools/build_lune_ui.mjs가 짓는다(시안 tools/preview_lune_ui_hd.mjs와 같은 그리기).
--  글은 칸을 넘지 않게 폭(width)을 꼭 준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local KIT = require(lune.data["kit.generated"])
local ASSETS = require(lune.data["assets.generated"])
local Layout = require(lune.ui.layout) -- 창과 칸의 치수(자동 검사가 같은 값을 본다)
local pixelText = require(script.Parent.Parent.Parent.modules.ui.pixelText)
local Stage = require(script.Parent.Parent.stage)

local Ui = {}
Ui.IMAGE = ASSETS[KIT.image] or ""
Ui.M = KIT.ui.metric
local M = Ui.M
local PARTS = KIT.parts

-- 글자판을 글씨 모듈에 알린다: 작은 글씨 · 테두리를 두른 작은 글씨와 본문 글씨(본문 글씨의 맨 글자판은 글씨 모듈이 이미 갖고 있다)
for _, key in { "small", "small_o", "body_o" } do
	local meta = KIT.font[key]
	local pages = {}
	for i, file in meta.files do
		pages[i] = ASSETS[file] or ""
	end
	pixelText.Register(key, meta, pages)
end

Ui.COLOR = {}
for name, c in KIT.ui.colors do
	Ui.COLOR[name] = Color3.fromRGB(c[1], c[2], c[3])
end
local C = Ui.COLOR
Ui.PANEL_ALPHA = 1 - M.panelAlpha / 255 -- 판은 조금 비친다(그림에 이미 들어 있다 — 빈 틀로 같은 판을 만들 때 쓴다)
Ui.TIER = { [0] = C.tier0, C.tier1, C.tier2, C.tier3, C.tier4 } -- 등급의 이름 색(낡은 · 허름한 · 보통 · 좋은 · 빼어난)

-- 글씨의 이름: font = "small" | "body", outline = 테두리를 두른 것
local function fontOf(font: string?, outline: boolean?): string
	local base = font or "small"
	return if outline then base .. "_o" else base
end

function Ui.measure(text: string, font: string?): number
	return (pixelText.Measure(text, font or "small"))
end

-- ---------- 빈 틀 · 색 상자 ----------
function Ui.box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3?, alpha: number?): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color or C.panel
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Ui.group(parent: Instance, x: number, y: number, w: number, h: number, name: string?): Frame
	local f = Ui.box(parent, x, y, w, h, C.panel, 1)
	if name then
		f.Name = name
	end
	return f
end

-- ---------- 그림 ----------
local function image(parent: Instance, name: string, x: number, y: number, w: number, h: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Image = Ui.IMAGE
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	label.Parent = parent
	return label
end

-- 그림의 속을 다른 부품으로 바꾼다(단추에 마우스를 올렸을 때 · 칸을 골랐을 때)
function Ui.swap(label: ImageLabel, name: string)
	local p = PARTS[name]
	assert(p, "없는 부품 " .. tostring(name))
	label.ImageRectOffset = Vector2.new(p.x, p.y)
	label.ImageRectSize = Vector2.new(p.w, p.h)
	if p.m then
		label.ScaleType = Enum.ScaleType.Slice
		label.SliceCenter = Rect.new(p.m, p.m, p.w - p.m, p.h - (p.mb or p.m))
	end
end

-- 부품 하나. w · h를 주면 그 크기로 늘인다(가장자리는 그대로 두고 가운데만 — 아홉 조각)
function Ui.part(parent: Instance, name: string, x: number, y: number, w: number?, h: number?): ImageLabel
	local p = PARTS[name]
	assert(p, "없는 부품 " .. tostring(name))
	local label = image(parent, name, x, y, w or p.w, h or p.h)
	Ui.swap(label, name)
	return label
end

-- 화면의 그림(24x24): 창을 여는 단추 · 기술 칸 · 버프. 이름은 공방의 아이콘 이름 — 없는 이름이면 빈 그림
function Ui.setPic(label: ImageLabel, name: string?)
	local sheet = PARTS.pics
	local at = name and sheet.icons[name]
	label.Visible = at ~= nil
	if at then
		label.ImageRectOffset = Vector2.new(sheet.x + at[1], sheet.y + at[2])
		label.ImageRectSize = Vector2.new(sheet.size, sheet.size)
	end
end

function Ui.hasPic(name: string): boolean
	return PARTS.pics.icons[name] ~= nil
end

function Ui.pic(parent: Instance, name: string?, x: number, y: number): ImageLabel
	local label = image(parent, "Pic", x, y, PARTS.pics.size, PARTS.pics.size)
	Ui.setPic(label, name)
	return label
end

-- 게임 세계의 그림(18x18 — 장비 · 돈 · 달가루)을 게임과 같은 굵은 도트로, 칸(x, y, 한 변 s)의 한가운데에 놓는다.
--  화면 틀의 배율이 바뀌면(창 크기가 달라지면) 크기를 다시 맞춘다
local worldIcons = setmetatable({}, { __mode = "k" }) -- [그림] = { x, y, s }
local function fitWorldIcon(label: ImageLabel, at)
	local side = PARTS.icons.size * Stage.ratio
	label.Size = UDim2.fromOffset(side, side)
	label.Position = UDim2.fromOffset(at.x + math.floor((at.s - side) / 2), at.y + math.floor((at.s - side) / 2))
end
function Ui.setWorldIcon(label: ImageLabel, name: string?)
	local sheet = PARTS.icons
	local at = name and sheet.icons[name]
	label.Visible = at ~= nil
	if at then
		label.ImageRectOffset = Vector2.new(sheet.x + at[1], sheet.y + at[2])
		label.ImageRectSize = Vector2.new(sheet.size, sheet.size)
	end
end
function Ui.worldIcon(parent: Instance, name: string?, x: number, y: number, s: number): ImageLabel
	local label = image(parent, "Icon", x, y, 1, 1)
	local at = { x = x, y = y, s = s }
	worldIcons[label] = at
	fitWorldIcon(label, at)
	Ui.setWorldIcon(label, name)
	return label
end
-- 글 옆에 붙이는 작은 그림(돈 · 달가루): 같은 그림을 화면 틀의 격자에 그대로(18x18점)
function Ui.smallIcon(parent: Instance, name: string, x: number, y: number): ImageLabel
	local label = image(parent, "Icon", x, y, PARTS.icons.size, PARTS.icons.size)
	Ui.setWorldIcon(label, name)
	return label
end
Stage.onResize(function()
	for label, at in worldIcons do
		if label.Parent then
			fitWorldIcon(label, at)
		end
	end
end)

-- ---------- 판 ----------
-- 어두운 판(창 · 알림 · 채팅을 쓸 때의 바탕). 돌려주는 것은 그 자리의 빈 틀 — 그 안에 내용을 놓는다
function Ui.panel(parent: Instance, x: number, y: number, w: number, h: number): Frame
	local outer = Ui.group(parent, x, y, w, h, "Panel")
	Ui.part(outer, "uPanel", 0, 0, w, h).Name = "Back"
	return outer
end

-- ---------- 글 ----------
-- 글. width = 이 글이 쓸 수 있는 폭(넘으면 줄을 바꾸고, lines를 넘으면 …로 줄인다). opts.align = "left" | "center" | "right"(그 폭 안에서)
--  opts.font = "small"(기본) · "body" / opts.outline = 어두운 테두리(판 없이 게임 화면 위에 적는 글) / opts.color / opts.lines / opts.line(줄 간격) / opts.z
function Ui.text(parent: Instance, text: string, x: number, y: number, width: number, opts)
	opts = opts or {}
	local label = pixelText.new(parent, {
		Text = text,
		Font = fontOf(opts.font, opts.outline),
		Color = opts.color or C.text,
		Align = opts.align or "left",
		MaxWidth = width,
		MaxLines = opts.lines or 1,
		Line = opts.line,
		ZIndex = opts.z,
	})
	local item = { label = label, x = x, y = y, width = width, align = opts.align or "left" }
	local function place()
		local px = item.x
		if item.align == "center" then
			px = item.x + math.floor((item.width - label.Width) / 2)
		elseif item.align == "right" then
			px = item.x + item.width - label.Width
		end
		label.Frame.Position = UDim2.fromOffset(px, item.y)
	end
	function item.set(_, value: string)
		label:SetText(value)
		place()
	end
	function item.color(_, color: Color3)
		label:SetColor(color)
	end
	function item.move(_, nx: number, ny: number)
		item.x, item.y = nx, ny
		place()
	end
	function item.show(_, on: boolean)
		label.Frame.Visible = on
	end
	-- 지금 그려진 글의 폭 · 높이
	function item.size(_): (number, number)
		return label.Width, label.Height
	end
	function item.destroy()
		label:Destroy()
	end
	place()
	return item
end

-- 이름표: 판 없이 테두리를 두른 작은 글(발밑의 이름 · 문 위의 글). 글씨 모듈의 글(Frame · Width · SetText · SetColor · Destroy)처럼 쓴다
Ui.TAG_H = M.small + 3 -- 이름표 한 줄이 차지하는 높이(쌓을 때 쓴다)
--  plate = true: 플레이어(나 · 다른 사람)의 이름표 — 어두운 판에 민트의 가는 테두리를 두른다(data/ui.generated.luau의 layout.tag.plate).
--   사용자 2026-10-08: "닉네임 표시되는게 그냥 닉네임하얀글씨로 표시되는게 아니라 얇은 우리게임 민트색 테두리같은게 있으면 좋을거같네요". 주민(노랑 글) · 졸개의 이름표는 판이 없다.
function Ui.tag(parent: Instance, text: string, color: Color3?, maxWidth: number?, plate: boolean?)
	local label = pixelText.new(parent, { Text = text, Font = "small_o", Color = color or C.text, MaxWidth = maxWidth or 220, MaxLines = 1 })
	label.Frame.Name = "Tag"
	if plate then
		local P = Layout.TAG.plate
		local box = Instance.new("Frame")
		box.Name = "Plate"
		box.BackgroundColor3 = C.ink
		box.BorderSizePixel = 0
		box.ZIndex = 1 -- 글씨(틀 안에서 5부터) 아래
		box.Parent = label.Frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = C.accent
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Parent = box
		-- 글이 바뀌면 판도 그 폭에 맞춘다(빈 글이면 숨긴다)
		local function fit()
			local w = label.Frame.Size.X.Offset
			box.Visible = w > 0
			box.Position = UDim2.fromOffset(-P.padX, -P.padY)
			box.Size = UDim2.fromOffset(w + P.padX * 2, M.small + P.padY * 2)
		end
		label.Frame:GetPropertyChangedSignal("Size"):Connect(fit)
		fit()
	end
	return label
end

-- ---------- 누르는 것 ----------
function Ui.hit(parent: Instance): TextButton
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 9
	hit.Parent = parent
	return hit
end

-- 단추(높이 26 — 글 12와 위아래 여백 7). opts.main = 그 창에서 가장 하고 싶은 일(민트로 칠한다 — 창마다 하나쯤) · opts.h = 다른 높이 · opts.font
--  onClick은 눌렀을 때(마우스 · 터치). 글은 단추 폭 안에 한 줄. 쓸 수 없을 때는 흐리게.
function Ui.button(parent: Instance, text: string, x: number, y: number, w: number, onClick: () -> (), opts)
	opts = opts or {}
	local h = opts.h or M.button
	local font = opts.font or (if h >= M.button then "body" else "small")
	local fh = if font == "body" then M.body else M.small
	local outer = Ui.group(parent, x, y, w, h, "Button")
	local item = { frame = outer, enabled = true, main = opts.main == true, hot = false }
	local back = Ui.part(outer, if item.main then "uBtnMain" else "uBtn", 0, 0, w, h)
	local label = Ui.text(outer, text, 3, math.floor((h - fh) / 2), w - 6, { align = "center", font = font, color = if item.main then C.ink else C.text })
	local function paint()
		if not item.enabled then
			Ui.swap(back, "uBtnOff")
			label:color(C.off)
		elseif item.main then
			Ui.swap(back, if item.hot then "uBtnMainHot" else "uBtnMain")
			label:color(C.ink)
		else
			Ui.swap(back, if item.hot then "uBtnHot" else "uBtn")
			label:color(C.text)
		end
	end
	local hit = Ui.hit(outer)
	hit.Activated:Connect(function()
		if item.enabled then
			onClick()
		end
	end)
	hit.MouseEnter:Connect(function()
		item.hot = true
		paint()
	end)
	hit.MouseLeave:Connect(function()
		item.hot = false
		paint()
	end)
	function item.setEnabled(_, on: boolean)
		if item.enabled ~= on then
			item.enabled = on
			paint()
		end
	end
	function item.setText(_, value: string)
		label:set(value)
	end
	function item.setMain(_, on: boolean)
		if item.main ~= on then
			item.main = on
			paint()
		end
	end
	return item
end

-- 닫기(×)
function Ui.closeButton(parent: Instance, x: number, y: number, onClick: () -> ()): ImageLabel
	local back = Ui.part(parent, "uClose", x, y)
	back.Name = "Close"
	local hit = Ui.hit(back)
	hit.Activated:Connect(onClick)
	hit.MouseEnter:Connect(function()
		Ui.swap(back, "uCloseHot")
	end)
	hit.MouseLeave:Connect(function()
		Ui.swap(back, "uClose")
	end)
	return back
end

-- 키 이름의 딱지(어두운 작은 딱지에 글자 — 칸 위 · 말풍선 아래). (cx, y) = 가운데 · 윗줄. 폭은 글에 맞춘다
Ui.KEY_H = M.key
function Ui.keycap(parent: Instance, text: string, cx: number, y: number)
	local outer = Ui.group(parent, cx, y, 1, M.key, "Key")
	local back = Ui.part(outer, "uKey", 0, 0, 8, M.key)
	local label = pixelText.new(outer, { Text = text, Font = "small", Color = C.text })
	label.Frame.Position = UDim2.fromOffset(4, 2)
	local item = { frame = outer, width = 0, cx = cx, y = y }
	local function fit()
		item.width = label.Width + 8
		outer.Size = UDim2.fromOffset(item.width, M.key)
		back.Size = UDim2.fromOffset(item.width, M.key)
		outer.Position = UDim2.fromOffset(item.cx - math.floor(item.width / 2), item.y)
		outer.Visible = label.Width > 0
	end
	function item.set(_, value: string)
		label:SetText(value)
		fit()
	end
	function item.move(_, ncx: number, ny: number)
		item.cx, item.y = ncx, ny
		fit()
	end
	function item.color(_, tint: Color3)
		label:SetColor(tint)
	end
	fit()
	return item
end

-- 칸(한 변 s). setOn(true) = 고른 것(민트 테두리)
function Ui.slot(parent: Instance, x: number, y: number, s: number)
	local outer = Ui.group(parent, x, y, s, s, "Slot")
	local back = Ui.part(outer, "uSlot", 0, 0, s, s)
	local item = { frame = outer, on = false }
	function item.setOn(_, on: boolean)
		if item.on ~= on then
			item.on = on
			Ui.swap(back, if on then "uSlotOn" else "uSlot")
		end
	end
	return item
end

-- ---------- 띠(게이지) ----------
-- 어두운 테두리 한 점 + 바탕(back — 빈 데의 색) + 채운 띠. set(0~1)
function Ui.bar(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, back: Color3?)
	local outer = Ui.box(parent, x, y, w, h, C.ink)
	outer.Name = "Bar"
	Ui.box(outer, 1, 1, w - 2, h - 2, back or C.ink).Name = "Empty"
	local fill = Ui.box(outer, 1, 1, w - 2, h - 2, color)
	fill.Name = "Fill"
	local item = { frame = outer, fill = fill }
	function item.set(_, ratio: number)
		fill.Size = UDim2.fromOffset(math.floor((w - 2) * math.clamp(ratio, 0, 1) + 0.5), h - 2)
	end
	function item.setColor(_, tint: Color3)
		fill.BackgroundColor3 = tint
	end
	return item
end

-- 가르는 줄(한 점)
function Ui.line(parent: Instance, x: number, y: number, w: number): Frame
	local f = Ui.box(parent, x, y, w, 1, C.line)
	f.Name = "Line"
	return f
end

-- ---------- 창 ----------
-- 장비 칸의 한 변: 장비 그림(게임의 굵은 도트 18개)에 사방으로 여백을 둔 크기 — 화면 틀의 배율에 따라 달라진다(1080p에서 50)
function Ui.cellSize(): number
	return Layout.cellFor(Stage.ratio)
end

-- 탭(글자만 — 고른 것은 민트 글씨에 밑줄). 돌려주는 것 { frame, width, setOn }
function Ui.tab(parent: Instance, text: string, x: number, y: number, onClick: () -> ())
	local w = Ui.measure(text)
	local outer = Ui.group(parent, x, y, w, 16, "Tab")
	local label = Ui.text(outer, text, 0, 0, w, { color = C.dim })
	local under = Ui.box(outer, 0, 13, w, 2, C.accent)
	under.Visible = false
	local item = { frame = outer, width = w, on = false }
	Ui.hit(outer).Activated:Connect(onClick)
	function item.setOn(_, on: boolean)
		if item.on ~= on then
			item.on = on
			label:color(if on then C.accent else C.dim)
			under.Visible = on
		end
	end
	return item
end

-- 창: 어두운 판 + 제목(본문 글씨) + 닫기(×) + 가르는 줄 + 속. (x, y, w, h)는 판의 자리.
--  속은 판에서 옆으로 pad(18), 위로 head(44) 안쪽이다. 돌려주는 것 { frame, body(속을 넣는 틀), w, h(속의 크기), setTitle }
Ui.WIN = { pad = Layout.WIN.pad, head = Layout.WIN.head, foot = Layout.WIN.foot, w = Layout.WIN.bodyW + Layout.WIN.pad * 2, gap = 8 }
function Ui.windowSize(bodyW: number, bodyH: number): (number, number)
	return bodyW + Ui.WIN.pad * 2, bodyH + Ui.WIN.head + Ui.WIN.foot
end
function Ui.window(parent: Instance, title: string, x: number, y: number, w: number, h: number, onClose: () -> ())
	local W = Ui.WIN
	local outer = Ui.panel(parent, x, y, w, h)
	outer.Name = "Window"
	local name = Ui.text(outer, title, W.pad, 13, w - W.pad * 2 - 20, { font = "body" })
	Ui.closeButton(outer, w - W.pad - 10, 13, onClose)
	Ui.line(outer, W.pad, 34, w - W.pad * 2)
	local body = Ui.group(outer, W.pad, W.head, w - W.pad * 2, h - W.head - W.foot, "Body")
	return { frame = outer, body = body, w = w - W.pad * 2, h = h - W.head - W.foot, setTitle = function(_, value: string)
		name:set(value)
	end }
end

return Ui
