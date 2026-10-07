-- 게임 세계의 부품 — 게임 화면(384x216)의 굵은 도트로 그리는 것: 장비 그림(땅에 떨어진 것 · 주민 머리 위의 표시) · 떨어진 돈과 달가루 · 피해 숫자.
--  화면의 글씨와 틀(판 · 칸 · 단추 · 창)은 여기 것이 아니다 — 화면 틀의 고운 격자에 그리는 ui/ui.luau를 쓴다.
--  부품 그림 한 장(ui_kit.png)과 그 자리 · 색은 shared/lune/data/kit.generated.luau — 공방의 tools/build_lune_ui.mjs가 짓는다. 여기서 모양을 따로 그리지 않는다.
--  좌표는 게임 화면의 도트.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local KIT = require(lune.data["kit.generated"])
local ASSETS = require(lune.data["assets.generated"])

local Kit = {}
Kit.DATA = KIT
Kit.IMAGE = ASSETS[KIT.image] or ""
Kit.ICON = KIT.icon -- 장비 그림의 한 변(18)
Kit.GROUND = KIT.ground -- 화면에서 땅의 윗면(발밑)의 y
local PARTS = KIT.parts

Kit.COLOR = {}
for name, c in KIT.colors do
	Kit.COLOR[name] = Color3.fromRGB(c[1], c[2], c[3])
end
local C = Kit.COLOR

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

-- 그림의 속을 다른 부품으로 바꾼다
function Kit.swap(label: ImageLabel, name: string)
	local p = PARTS[name]
	assert(p, "없는 부품 " .. tostring(name))
	label.ImageRectOffset = Vector2.new(p.x, p.y)
	label.ImageRectSize = Vector2.new(p.w, p.h)
end

-- 부품 하나(떨어진 돈 · 달가루 · 떨어진 장비의 귀퉁이 표시)
function Kit.part(parent: Instance, name: string, x: number, y: number): ImageLabel
	local p = PARTS[name]
	assert(p, "없는 부품 " .. tostring(name))
	local label = image(parent, name, x, y, p.w, p.h)
	Kit.swap(label, name)
	return label
end

-- 부품을 바꿔 끼우는 그림: 이름이 없으면 숨기고, 있으면 그 부품의 크기로 맞춘다(주민 머리 위의 퀘스트 표시 ! · ?)
function Kit.setPart(label: ImageLabel, name: string?)
	label.Visible = name ~= nil
	if name then
		local p = PARTS[name]
		assert(p, "없는 부품 " .. tostring(name))
		label.ImageRectOffset = Vector2.new(p.x, p.y)
		label.ImageRectSize = Vector2.new(p.w, p.h)
		label.Size = UDim2.fromOffset(p.w, p.h)
	end
end

function Kit.partSize(name: string): (number, number)
	local p = PARTS[name]
	return p.w, p.h
end

-- 장비 그림(18x18). 이름은 공방의 아이콘 이름(tools/build_lune_icons.mjs) — 없는 이름이면 빈 그림
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

-- 색 상자(화살 · 땅속을 메우는 바탕)
function Kit.box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3?, alpha: number?): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color or C.line
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- 틀만 있는 빈 자리(그 안에 부품을 놓는다)
function Kit.group(parent: Instance, x: number, y: number, w: number, h: number): Frame
	return Kit.box(parent, x, y, w, h, C.line, 1)
end

-- 피해 숫자: 공방 「횡스크롤 시험」 탭의 3x5 점 숫자 그대로(dino-workshop/js/lune/fx.js의 num — 사용자 2026-10-07:
--  "데미지 폰트는 이전 횡스크롤 시험 탭에서 실제 플레이할때의 데미지 출력이랑 동일해야합니다").
--  속에는 색을 입히고, 위 · 아래 · 옆 한 점의 테두리는 늘 같은 어두운 색이다. 틀의 왼쪽 위가 테두리의 왼쪽 위 — width = 글자 수 x 4 + 1.
function Kit.dmg(parent: Instance, text: string, color: Color3)
	local sheet = PARTS.dmg
	local frame = Kit.group(parent, 0, 0, 1, sheet.ch)
	frame.Name = "Dmg"
	local fills = {}
	local n = 0
	for i = 1, #text do
		local d = tonumber(text:sub(i, i))
		if d then
			local line = image(frame, "line", n * sheet.adv, 0, sheet.cw, sheet.ch)
			line.ImageRectOffset = Vector2.new(sheet.x + d * sheet.cw, sheet.y + sheet.ch)
			line.ImageRectSize = Vector2.new(sheet.cw, sheet.ch)
			local fill = image(frame, "fill", n * sheet.adv, 0, sheet.cw, sheet.ch)
			fill.ImageRectOffset = Vector2.new(sheet.x + d * sheet.cw, sheet.y)
			fill.ImageRectSize = Vector2.new(sheet.cw, sheet.ch)
			fill.ImageColor3 = color
			fill.ZIndex = 2
			table.insert(fills, fill)
			n += 1
		end
	end
	local width = n * sheet.adv + 1
	frame.Size = UDim2.fromOffset(width, sheet.ch)
	local item = { frame = frame, width = width, height = sheet.ch }
	function item.color(_, tint: Color3)
		for _, g in fills do
			g.ImageColor3 = tint
		end
	end
	return item
end

return Kit
