-- 화면 부품 — 판 · 단추 · 탭 · 칸 · 아이콘 · 글 · 띠. 「달의 계승자」의 창과 화면 칸은 모두 이 부품으로 짓는다.
--  모양은 공방에서 지은 메이플풍 도트 부품이다(사용자 2026-10-06: "메이플에 가까워야합니다" · "1 느낌 + 도트 게임 느낌"):
--  어두운 남색 틀에 옅은 파란 줄, 밝은 칸, 주황 · 파란 단추, 한 점 테두리와 계단진 모서리.
--  부품 그림 한 장(ui_kit.png)과 그 자리 · 색은 shared/lune/data/kit.generated.luau — 공방의 tools/build_lune_ui.mjs가 짓는다. 여기서 모양을 따로 그리지 않는다.
--  좌표는 게임 화면(384x216)의 도트. 글씨는 갈무리(pixelText) — 화면의 글은 작은 글씨(small = 갈무리9), 제목은 본문 글씨(body).
--  글은 칸을 넘지 않게 MaxWidth · MaxLines를 꼭 준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local KIT = require(lune.data["kit.generated"])
local ASSETS = require(lune.data["assets.generated"])
local pixelText = require(script.Parent.Parent.Parent.modules.ui.pixelText)

local Kit = {}
Kit.DATA = KIT
Kit.IMAGE = ASSETS[KIT.image] or ""
Kit.ICON, Kit.CELL, Kit.PITCH, Kit.GROUND = KIT.icon, KIT.cell, KIT.pitch, KIT.ground
Kit.LINE = KIT.font.small.line -- 작은 글씨 한 줄의 높이(11)
local PARTS = KIT.parts

-- 작은 글씨(갈무리9)의 글자판을 글씨 모듈에 알린다
do
	local pages = {}
	for i, file in KIT.font.small.files do
		pages[i] = ASSETS[file] or ""
	end
	pixelText.Register("small", KIT.font.small, pages)
end

local function rgb(name: string): Color3
	local c = KIT.colors[name]
	return Color3.fromRGB(c[1], c[2], c[3])
end
Kit.COLOR = {}
for name in KIT.colors do
	Kit.COLOR[name] = rgb(name)
end
local C = Kit.COLOR
-- 창들이 쓰는 이름(뜻으로 부른다)
C.ink = C.line -- 가장 어두운 색(그림자 · 가르는 줄)
C.panel = C.navy -- 어두운 판의 속
C.slate = C.trough -- 움푹한 칸의 속
C.gray = C.dim -- 흐린 글
C.gold = C.yellow -- 눈에 띄는 글(돈 · 좋은 것)
C.mintD = Color3.fromRGB(20, 102, 95)
C.bad = C.red -- 안 되는 것 · 잃는 것
C.white = C.text

function Kit.measure(text: string, font: string?): number
	return (pixelText.Measure(text, font or "small"))
end

-- ---------- 그림 ----------
local function image(parent: Instance, name: string, x: number, y: number, w: number, h: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Image = Kit.IMAGE
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	label.Parent = parent
	return label
end

-- 그림의 속을 다른 부품으로 바꾼다(단추에 마우스를 올렸을 때 · 탭을 골랐을 때)
function Kit.swap(label: ImageLabel, name: string)
	local p = PARTS[name]
	assert(p, "없는 부품 " .. tostring(name))
	label.ImageRectOffset = Vector2.new(p.x, p.y)
	label.ImageRectSize = Vector2.new(p.w, p.h)
	if p.m then
		label.ScaleType = Enum.ScaleType.Slice
		label.SliceCenter = Rect.new(p.m, p.m, p.w - p.m, p.h - p.m)
	end
end

-- 부품 하나. w · h를 주면 그 크기로 늘인다(가장자리는 그대로 두고 가운데만 — 아홉 조각)
function Kit.part(parent: Instance, name: string, x: number, y: number, w: number?, h: number?): ImageLabel
	local p = PARTS[name]
	assert(p, "없는 부품 " .. tostring(name))
	local label = image(parent, name, x, y, w or p.w, h or p.h)
	Kit.swap(label, name)
	return label
end

-- 아이콘(18x18). 이름은 공방의 아이콘 이름(tools/build_lune_icons.mjs) — 없는 이름이면 빈 그림
function Kit.setIcon(label: ImageLabel, name: string?)
	local sheet = PARTS.icons
	local at = name and sheet.icons[name]
	label.Visible = at ~= nil
	if at then
		label.ImageRectOffset = Vector2.new(sheet.x + at[1], sheet.y + at[2])
		label.ImageRectSize = Vector2.new(sheet.size, sheet.size)
	end
end

function Kit.hasIcon(name: string): boolean
	return PARTS.icons.icons[name] ~= nil
end

function Kit.icon(parent: Instance, name: string?, x: number, y: number): ImageLabel
	local label = image(parent, "Icon", x, y, PARTS.icons.size, PARTS.icons.size)
	Kit.setIcon(label, name)
	return label
end

-- 빈 칸(색 상자) — 가르는 줄 · 덮개
function Kit.box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3?, alpha: number?): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color or C.panel
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- 틀만 있는 빈 자리(그 안에 부품을 놓는다)
function Kit.group(parent: Instance, x: number, y: number, w: number, h: number): Frame
	return Kit.box(parent, x, y, w, h, C.panel, 1)
end

-- 판. kind = panel(어두운 판) · frame(창틀) · paper(밝은 속) · veil(비치는 바탕) · field(어두운 홈) …
--  돌려주는 것은 그 자리의 빈 틀 — 속(Inner)에 내용을 넣는다. 속은 테두리 한 점 안쪽이다.
function Kit.plate(parent: Instance, kind: string, x: number, y: number, w: number, h: number, alpha: number?): Frame
	local outer = Kit.group(parent, x, y, w, h)
	local back = Kit.part(outer, kind, 0, 0, w, h)
	back.Name = "Back"
	back.ImageTransparency = alpha or 0
	local inner = Kit.group(outer, 1, 1, w - 2, h - 2)
	inner.Name = "Inner"
	return outer
end

-- 어두운 판(미니맵 · 설명 상자 · 알림)
function Kit.panel(parent: Instance, x: number, y: number, w: number, h: number): Frame
	return Kit.plate(parent, "panel", x, y, w, h)
end

-- ---------- 글 ----------
-- 글. width = 이 글이 쓸 수 있는 폭(넘으면 줄을 바꾸고, lines를 넘으면 …로 줄인다). align = "left" | "center" | "right"
--  opts.font = "small"(기본 — 한글 9x9, 한 줄 11) · "body"(한글 11x11, 한 줄 14 — 제목과 주민의 말)
function Kit.text(parent: Instance, text: string, x: number, y: number, width: number, opts)
	opts = opts or {}
	local label = pixelText.new(parent, {
		Text = text,
		Font = opts.font or "small",
		Color = opts.color or C.text,
		Shadow = opts.shadow,
		Align = "left",
		MaxWidth = width,
		MaxLines = opts.lines or 1,
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
	function item.destroy()
		label:Destroy()
	end
	place()
	return item
end

-- 아주 작은 글씨(3x5 — 키 이름 · 개수 · 남은 시간). 영문 대문자 · 숫자 · 몇 가지 기호만 있다. 테두리가 둘려 있어 그림 위에서도 읽힌다.
--  (x, y)는 글자의 왼쪽 위. 글자 하나의 폭은 4(3 + 사이 1).
function Kit.microWidth(text: string): number
	return math.max(0, #text * 4 - 1)
end

function Kit.micro(parent: Instance, text: string, x: number, y: number, color: Color3?)
	local sheet = PARTS.microLine
	local frame = Kit.group(parent, x - 1, y - 1, 1, sheet.ch)
	frame.Name = "Micro"
	frame.ZIndex = 6
	local item = { frame = frame, text = nil :: string?, tint = color or C.white, x = x, y = y, glyphs = {} :: { ImageLabel } }
	function item.set(_, value: string)
		value = string.upper(value)
		if value == item.text then
			return
		end
		item.text = value
		for _, g in item.glyphs do
			g:Destroy()
		end
		table.clear(item.glyphs)
		for i = 1, #value do
			local at = string.find(sheet.order, value:sub(i, i), 1, true)
			if at then
				local g = image(frame, "g", (i - 1) * 4, 0, sheet.cw, sheet.ch)
				g.ImageRectOffset = Vector2.new(sheet.x + (at - 1) * sheet.cw, sheet.y)
				g.ImageRectSize = Vector2.new(sheet.cw, sheet.ch)
				g.ImageColor3 = item.tint
				table.insert(item.glyphs, g)
			end
		end
		frame.Size = UDim2.fromOffset(#value * 4 + 1, sheet.ch)
	end
	function item.color(_, tint: Color3)
		item.tint = tint
		for _, g in item.glyphs do
			g.ImageColor3 = tint
		end
	end
	function item.move(_, nx: number, ny: number)
		item.x, item.y = nx, ny
		frame.Position = UDim2.fromOffset(nx - 1, ny - 1)
	end
	item:set(text)
	return item
end

-- 큰 숫자(피해 · 회복 — 숫자만). 가운데가 (0, 0)인 틀을 돌려준다: frame.Position으로 옮긴다. width = 글의 폭
function Kit.big(parent: Instance, text: string, color: Color3)
	local sheet = PARTS.big
	local frame = Kit.group(parent, 0, 0, 1, sheet.ch)
	frame.Name = "Big"
	local x = 0
	for i = 1, #text do
		local d = tonumber(text:sub(i, i))
		if d then
			local g = image(frame, "g", x - math.floor((sheet.cw - sheet.adv[d + 1] - 2) / 2), 0, sheet.cw, sheet.ch)
			g.ImageRectOffset = Vector2.new(sheet.x + d * sheet.cw, sheet.y)
			g.ImageRectSize = Vector2.new(sheet.cw, sheet.ch)
			g.ImageColor3 = color
			x += sheet.adv[d + 1]
		end
	end
	frame.Size = UDim2.fromOffset(x + 2, sheet.ch)
	return { frame = frame, width = x + 2, height = sheet.ch }
end

-- ---------- 누르는 것 ----------
local function hitArea(parent: Instance): TextButton
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 9
	hit.Parent = parent
	return hit
end
Kit.hit = hitArea

local BUTTON = {
	blue = { on = "btnBlue", hot = "btnBlueHot", text = "white" },
	orange = { on = "btnOrange", hot = "btnOrangeHot", text = "ink" },
}

-- 단추. onClick은 눌렀을 때(마우스 · 터치) 불린다. 글은 단추 폭 안에 한 줄.
--  opts.kind = "blue"(기본) · "orange"(가장 하고 싶은 일 — 창마다 하나쯤). 쓸 수 없을 때는 회색.
function Kit.button(parent: Instance, text: string, x: number, y: number, w: number, h: number, onClick: () -> (), opts)
	opts = opts or {}
	local outer = Kit.group(parent, x, y, w, h)
	outer.Name = "Button"
	local item = { frame = outer, enabled = true, kind = opts.kind or "blue", hot = false }
	local back = Kit.part(outer, BUTTON[item.kind].on, 0, 0, w, h)
	local label = Kit.text(outer, text, 2, math.floor((h - 9) / 2), w - 4, { align = "center", color = C[BUTTON[item.kind].text] })
	item.fill, item.label = back, label
	local function paint()
		local look = BUTTON[item.kind]
		Kit.swap(back, if not item.enabled then "btnOff" elseif item.hot then look.hot else look.on)
		label:color(if item.enabled then C[look.text] else C.paperLo)
	end
	local hit = hitArea(outer)
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
	-- 쓸 수 없을 때는 회색으로
	function item.setEnabled(_, on: boolean)
		if item.enabled ~= on then
			item.enabled = on
			paint()
		end
	end
	function item.setText(_, value: string)
		label:set(value)
	end
	-- 모양 바꾸기(고른 것은 주황으로)
	function item.setKind(_, kind: string)
		if item.kind ~= kind then
			item.kind = kind
			paint()
		end
	end
	return item
end

-- 탭(창의 위쪽에 줄지어 놓는다). setOn(true)인 것이 주황이다. 높이 13
function Kit.tab(parent: Instance, text: string, x: number, y: number, w: number, onClick: () -> ())
	local outer = Kit.group(parent, x, y, w, 13)
	outer.Name = "Tab"
	local back = Kit.part(outer, "tabOff", 0, 0, w, 13)
	local label = Kit.text(outer, text, 2, 2, w - 4, { align = "center", color = C.text })
	local item = { frame = outer, on = false }
	hitArea(outer).Activated:Connect(onClick)
	function item.setOn(_, on: boolean)
		if item.on ~= on then
			item.on = on
			Kit.swap(back, if on then "tabOn" else "tabOff")
			label:color(if on then C.ink else C.text)
		end
	end
	return item
end

-- 닫기 단추(11x11 — 붉은 판에 ×)
function Kit.closeButton(parent: Instance, x: number, y: number, onClick: () -> ())
	local back = Kit.part(parent, "close", x, y)
	local hit = hitArea(back)
	hit.Activated:Connect(onClick)
	hit.MouseEnter:Connect(function()
		Kit.swap(back, "closeHot")
	end)
	hit.MouseLeave:Connect(function()
		Kit.swap(back, "close")
	end)
	return back
end

-- ---------- 띠(게이지) ----------
-- 어두운 홈 + 채운 띠(윗줄 밝게 · 아랫줄 어둡게). kind = "hp" · "mp" · "exp"(색 이름). set(0~1)
function Kit.bar(parent: Instance, x: number, y: number, w: number, h: number, kind: string)
	local outer = Kit.group(parent, x, y, w, h)
	outer.Name = "Bar"
	Kit.part(outer, "gauge", 0, 0, w, h)
	local fill = Kit.group(outer, 1, 1, w - 2, h - 2)
	fill.ClipsDescendants = true
	local mid = Kit.box(fill, 0, 0, w - 2, h - 2, C[kind])
	local hi = Kit.box(fill, 0, 0, w - 2, 1, C[kind .. "Hi"])
	local lo = Kit.box(fill, 0, h - 3, w - 2, 1, C[kind .. "Lo"])
	lo.Visible = h > 4
	local item = { frame = outer, fill = fill }
	function item.set(_, ratio: number)
		fill.Size = UDim2.fromOffset(math.floor((w - 2) * math.clamp(ratio, 0, 1) + 0.5), h - 2)
	end
	function item.setKind(_, name: string)
		mid.BackgroundColor3, hi.BackgroundColor3, lo.BackgroundColor3 = C[name], C[name .. "Hi"], C[name .. "Lo"]
	end
	return item
end

-- ---------- 이름표 ----------
-- 발밑의 이름표: 비치는 어두운 알약 + 작은 글씨. 글씨 모듈의 글(Frame · Width · SetText · SetColor · Destroy)처럼 쓴다.
Kit.TAG_H = 11
function Kit.tag(parent: Instance, text: string, color: Color3?, maxWidth: number?)
	local frame = Kit.group(parent, 0, 0, 1, Kit.TAG_H)
	frame.Name = "Tag"
	frame.ZIndex = 5
	local back = Kit.part(frame, "veil", 0, 0, 6, Kit.TAG_H)
	back.ImageTransparency = 0.2
	local label = pixelText.new(frame, { Text = text, Font = "small", Color = color or C.text, MaxWidth = maxWidth or 150, MaxLines = 1 })
	label.Frame.Position = UDim2.fromOffset(3, 1)
	local tag = { Frame = frame, Width = 0 }
	local function fit()
		tag.Width = label.Width + 6
		frame.Size = UDim2.fromOffset(tag.Width, Kit.TAG_H)
		back.Size = UDim2.fromOffset(tag.Width, Kit.TAG_H)
	end
	function tag.SetText(_, value: string)
		label:SetText(value)
		fit()
	end
	function tag.SetColor(_, tint: Color3)
		label:SetColor(tint)
	end
	function tag.Destroy()
		frame:Destroy()
	end
	fit()
	return tag
end

-- ---------- 창 ----------
-- 창: 어두운 틀 + 제목 + 닫기(×) + 속. (x, y, w, h)는 속을 담는 자리이고 틀은 그 둘레로 조금 넓게 그린다.
--  돌려주는 것 { frame, body(속을 넣는 틀), w, h(속의 크기) }
function Kit.window(parent: Instance, title: string, x: number, y: number, w: number, h: number, onClose: () -> ())
	local fw, fh = w + 6, h + 4
	local outer = Kit.group(parent, x - 3, y - 1, fw, fh)
	outer.Name = "Window"
	Kit.part(outer, "frame", 0, 0, fw, fh)
	Kit.part(outer, "gem", 5, 5)
	Kit.text(outer, title, 15, 2, fw - 34, { font = "body", color = C.white })
	Kit.closeButton(outer, fw - 15, 3, onClose)
	local body = Kit.group(outer, 4, 18, w - 2, h - 18)
	body.Name = "Body"
	return { frame = outer, body = body, w = w - 2, h = h - 18 }
end

return Kit
