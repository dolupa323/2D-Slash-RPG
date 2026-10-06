-- 도트 글씨 — 에셋 공방(js/font.js — 레트로 비트맵 글꼴 「갈무리」, SIL OFL)에서 만든 글자판 이미지에서 한 글자씩 잘라 붙여 문자열을 그린다.
-- 로블록스에는 글꼴 파일을 올릴 수 없어서 쓰는 방식(비트맵 글꼴). 한글 11,172자·영문·숫자·기호를 지원하고,
-- 글자판에 없는 글자는 "?"로 그린다. 입력칸(TextBox)에는 못 쓴다.
--
-- 좌표 단위는 "UI 도트"(글자판 픽셀 그대로). 화면 크기는 부모에 걸린 정수 UIScale(pixelUI.Scale)이 키운다.
--   local label = pixelText.new(parent, { Text = "안녕", Font = "body", Color = Color3, Shadow = Color3?, Align = "left"|"center"|"right",
--                                         MaxWidth = 폭?, MaxLines = 줄 수? })
--   label.Frame.Position = UDim2.fromOffset(x, y) / label:SetText("...") / label:SetColor(c) / label.Width, label.Height
-- 글씨가 칸을 넘지 않게: MaxWidth를 주면 그 폭에 맞춰 줄을 바꾸고(띄어쓰기에서 먼저, 낱말이 길면 글자에서), MaxLines를 주면
--  그 줄 수를 넘는 부분은 "…"로 줄인다. 칸이 정해진 자리의 글씨는 반드시 MaxWidth(와 MaxLines)를 줄 것.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local fontData = require(ReplicatedStorage.shared.data["pixelFont.generated"])
local townIds = require(ReplicatedStorage.shared.config["townAssets.generated"])

local JAMO_START = 0x3131
local JAMO_END = 0x3163
local HANGUL_START = 0xAC00
local HANGUL_END = 0xD7A3

local exports = {}

-- 글꼴: 기본 둘(body · title — pixelFont.generated.luau)에 더해, 게임이 제 글꼴을 등록할 수 있다(Register).
--  「달의 계승자」는 화면 글씨로 작은 글씨(small = 갈무리9)를 등록한다 — client/lune/ui/kit.luau.
local fonts = setmetatable({}, { __index = fontData })
local pagesOf = {} -- [글꼴 이름] = { 글자판 그림 id … }

-- meta = 글자판 규칙(pixelFont.generated.luau의 한 글꼴과 같은 꼴), pages = 글자판 그림의 id들
function exports.Register(key: string, meta, pages: { string })
	fonts[key] = meta
	pagesOf[key] = pages
end

-- 글자 → 글자판 번호(0부터)와 폭
local function glyphInfo(font, code: number): (number, number)
	local base = 95 + #font.extra
	if code >= 32 and code <= 126 then
		return code - 32, font.asciiAdv[code - 31]
	elseif code >= HANGUL_START and code <= HANGUL_END then
		return base + (JAMO_END - JAMO_START + 1) + (code - HANGUL_START), font.hangulAdv or font.cellW
	elseif code >= JAMO_START and code <= JAMO_END then
		return base + (code - JAMO_START), font.hangulAdv or font.cellW
	end
	for i, ch in font.extra do
		if utf8.codepoint(ch) == code then
			return 95 + i - 1, font.extraAdv[i]
		end
	end
	return 63 - 32, font.asciiAdv[63 - 31] -- "?"
end

local function lineWidth(font, line: string): number
	local w = 0
	for _, code in utf8.codes(line) do
		local _, adv = glyphInfo(font, code)
		w += adv
	end
	return w
end

function exports.Measure(text: string, fontKey: string?): (number, number)
	local font = fonts[fontKey or "body"]
	local w, n = 0, 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		w = math.max(w, lineWidth(font, line))
		n += 1
	end
	return w, n * font.line
end

-- 폭에 맞춰 줄바꿈: 띄어쓰기에서 먼저 끊고, 한 낱말이 폭보다 길면 글자에서 끊는다(공방 js/font.js wrap과 같은 규칙).
function exports.Wrap(text: string, maxWidth: number, fontKey: string?): string
	local font = fonts[fontKey or "body"]
	local out = {}
	for para in (text .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in (para .. " "):gmatch("(.-) ") do
			local try = if line == "" then word else line .. " " .. word
			if lineWidth(font, try) <= maxWidth then
				line = try
			else
				if line ~= "" then
					table.insert(out, line)
				end
				line = ""
				for _, code in utf8.codes(word) do
					local ch = utf8.char(code)
					if line ~= "" and lineWidth(font, line .. ch) > maxWidth then
						table.insert(out, line)
						line = ""
					end
					line ..= ch
				end
			end
		end
		table.insert(out, line)
	end
	return table.concat(out, "\n")
end

-- 한 줄이 폭을 넘으면 끝을 "…"로 줄인다
local function fitLine(font, line: string, maxWidth: number): string
	if lineWidth(font, line) <= maxWidth then
		return line
	end
	local kept = ""
	for _, code in utf8.codes(line) do
		local try = kept .. utf8.char(code)
		if lineWidth(font, try .. "…") > maxWidth then
			break
		end
		kept = try
	end
	return (kept:gsub("%s+$", "")) .. "…"
end

-- 칸에 맞추기: 폭(maxWidth)을 넘으면 줄을 바꾸고, 줄 수(maxLines)를 넘으면 마지막 줄 끝을 "…"로 줄인다.
-- maxLines = 1이면 줄을 바꾸지 않고 한 줄로 줄인다.
function exports.Fit(text: string, maxWidth: number, maxLines: number?, fontKey: string?): string
	local font = fonts[fontKey or "body"]
	if maxLines == 1 then
		return fitLine(font, (text:gsub("\n", " ")), maxWidth)
	end
	local lines = {}
	for line in (exports.Wrap(text, maxWidth, fontKey) .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	if maxLines and #lines > maxLines then
		local last = lines[maxLines] .. "…"
		while #lines > maxLines do
			table.remove(lines)
		end
		-- "…"를 붙여도 폭 안에 들어오게
		local kept = ""
		for _, code in utf8.codes(lines[maxLines]) do
			local try = kept .. utf8.char(code)
			if lineWidth(font, try .. "…") > maxWidth then
				break
			end
			kept = try
		end
		lines[maxLines] = if lineWidth(font, last) <= maxWidth then last else kept .. "…"
	end
	return table.concat(lines, "\n")
end

local Label = {}
Label.__index = Label

-- 칸 제한(MaxWidth · MaxLines)이 있으면 그 안에 들어가게 고친 글
function Label:_fitted(text: string): string
	if self._maxWidth then
		return exports.Fit(text, self._maxWidth, self._maxLines, self._fontKey)
	end
	return text
end

function Label:_render()
	for _, child in self._glyphs do
		child:Destroy()
	end
	table.clear(self._glyphs)
	local font = self._font
	local pages = pagesOf[self._fontKey] or (townIds.FONT and townIds.FONT[self._fontKey]) or {}
	local shown = self:_fitted(self._text)
	local width, height = exports.Measure(shown, self._fontKey)
	self.Width, self.Height = width, height
	self.Frame.Size = UDim2.fromOffset(width, height)

	local layers = {}
	if self._shadow then
		table.insert(layers, { color = self._shadow, dx = 1, dy = 1, z = 0 })
	end
	table.insert(layers, { color = self._color, dx = 0, dy = 0, z = 1 })

	local y = 0
	for line in (shown .. "\n"):gmatch("(.-)\n") do
		local lw = lineWidth(font, line)
		local x = if self._align == "center" then math.floor((width - lw) / 2) elseif self._align == "right" then width - lw else 0
		for _, code in utf8.codes(line) do
			local index, adv = glyphInfo(font, code)
			if code ~= 32 then
				local page = index // font.perPage
				local k = index % font.perPage
				for _, layer in layers do
					local img = Instance.new("ImageLabel")
					img.Name = "g"
					img.BackgroundTransparency = 1
					img.BorderSizePixel = 0
					img.Image = pages[page + 1] or ""
					img.ImageRectOffset = Vector2.new((k % font.cols) * font.cellW, (k // font.cols) * font.cellH)
					img.ImageRectSize = Vector2.new(font.cellW, font.cellH)
					img.Size = UDim2.fromOffset(font.cellW, font.cellH)
					img.Position = UDim2.fromOffset(x + layer.dx, y + layer.dy)
					img.ResampleMode = Enum.ResamplerMode.Pixelated
					img.ImageColor3 = layer.color
					img.ImageTransparency = if layer.z == 0 and self._shadowHidden then 1 else 0
					img.ZIndex = self._zIndex + layer.z
					img.Parent = self.Frame
					table.insert(self._glyphs, img)
				end
			end
			x += adv
		end
		y += font.line
	end
end

function Label:SetText(text: string)
	text = tostring(text)
	if text == self._text then
		return
	end
	self._text = text
	self:_render()
end

-- 칸 크기가 바뀌었을 때(같은 글씨를 다른 폭에 맞춰 다시 그린다)
function Label:SetMaxWidth(maxWidth: number?, maxLines: number?)
	self._maxWidth, self._maxLines = maxWidth, maxLines
	self:_render()
end

function Label:SetColor(color: Color3)
	self._color = color
	for _, g in self._glyphs do
		if g.ZIndex == self._zIndex + 1 then
			g.ImageColor3 = color
		end
	end
end

-- 그림자 색 바꾸기(nil이면 숨김)
function Label:SetShadow(color: Color3?)
	self._shadowHidden = color == nil
	if color then
		self._shadow = color
	end
	for _, g in self._glyphs do
		if g.ZIndex == self._zIndex then
			g.ImageTransparency = if color then 0 else 1
			if color then
				g.ImageColor3 = color
			end
		end
	end
end

function Label:Destroy()
	self.Frame:Destroy()
end

function exports.new(parent: Instance, props)
	local fontKey = props.Font or "body"
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "PixelText"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.Position = props.Position or UDim2.fromOffset(0, 0)
	frame.ZIndex = props.ZIndex or 5
	frame.Parent = parent
	local self = setmetatable({
		Frame = frame,
		_font = fonts[fontKey],
		_fontKey = fontKey,
		_text = tostring(props.Text or ""),
		_color = props.Color or Color3.fromRGB(20, 27, 27), -- 팩 외곽선 색(uiKit colors.ink)
		_shadow = props.Shadow,
		_align = props.Align or "left",
		_zIndex = props.ZIndex or 5,
		_maxWidth = props.MaxWidth, -- 이 폭을 넘으면 줄바꿈
		_maxLines = props.MaxLines, -- 이 줄 수를 넘으면 …로 줄임
		_glyphs = {},
	}, Label)
	self:_render()
	return self
end

return exports
