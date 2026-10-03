-- 도트 UI 부품 — 「오문 닌자전」 UI 키트(Ninja Adventure 팩 UI로 만든 아틀라스 assets/ninja/ui.png, 공방 tools/export_ninja_ui.mjs).
-- 나무 테마: 흰 패널 + 주황·갈색 테두리, 주황 입체 버튼, 회녹색 칸, 팩 아이콘(스킬 · 키 · 얼굴), 도트 글씨(pixelText — 한글 글꼴은 우리 것).
-- 패널·버튼·칸은 9분할(ScaleType.Slice)이라 어떤 크기로 늘려도 모서리가 안 깨진다.
-- 부품 이름은 shared/data/uiKit.generated.luau의 rects. 예전 분홍 키트(ui_parts)는 더 쓰지 않는다.
--
-- 좌표 단위는 "UI 도트". 화면 배율은 Scale(root)가 화면 높이에 맞춰 정수배(1·2·3·4…)로 건다 — 정수라야 도트가 고르다.
-- (예시 화면 480x270 = 1080p에서 4배 — 공방 「닌자 맵」 탭 「UI」)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = require(ReplicatedStorage.shared.data["uiKit.generated"])
-- 팩 아이템 아이콘(별도 시트 — 이름 icon_nj_<키>). 키트에 없는 이름은 여기서 찾는다.
local itemIcons = require(ReplicatedStorage.shared.data["itemIcons.generated"])
local townIds = require(ReplicatedStorage.shared.config["townAssets.generated"])
local function rectOf(name: string)
	return kit.rects[name] or itemIcons.rects[name]
end
local pixelText = require(script.Parent.pixelText)

local DESIGN_HEIGHT = 270 -- 화면 높이 / 이 값 = UI 배율(내림, 최소 1)

local exports = {}
exports.Text = pixelText
exports.colors = {}
for name, c in kit.colors do
	exports.colors[name] = Color3.fromRGB(c[1], c[2], c[3])
end
local C = exports.colors

function exports.CurrentScale(): number
	local camera = Workspace.CurrentCamera
	local h = camera and camera.ViewportSize.Y or 810
	return math.max(1, math.floor(h / DESIGN_HEIGHT))
end

-- root(GuiObject)에 정수 UIScale을 걸고 화면 크기가 바뀌면 따라간다.
function exports.Scale(root: GuiObject)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	local function update()
		uiScale.Scale = exports.CurrentScale()
	end
	update()
	local conn
	local function hook()
		if conn then
			conn:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	hook()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	return uiScale
end

-- 부품 하나(ImageLabel 또는 ImageButton). size = Vector2(도트). 9분할 부품은 크기에 맞춰 늘어난다.
function exports.Part(parent: Instance, name: string, x: number, y: number, w: number?, h: number?, class: string?)
	local r = rectOf(name)
	assert(r, "pixelUI: 부품이 없습니다 " .. tostring(name))
	local img = Instance.new(class or "ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = (if kit.rects[name] then townIds.UI else townIds.ITEMS) or ""
	img.ImageRectOffset = Vector2.new(r.x, r.y)
	img.ImageRectSize = Vector2.new(r.w, r.h)
	img.ResampleMode = Enum.ResamplerMode.Pixelated
	img.Position = UDim2.fromOffset(x, y)
	img.Size = UDim2.fromOffset(w or r.w, h or r.h)
	if r.slice then
		local s = r.slice
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = Rect.new(s[1], s[2], r.w - s[3], r.h - s[4])
	else
		img.ScaleType = Enum.ScaleType.Stretch
	end
	if img:IsA("GuiButton") then
		-- 로블록스 기본 "선택 표시"(누른 뒤 둘러지는 테두리)를 끈다 — 우리 버튼은 눌림 그림으로 표시한다.
		img.Selectable = false
		img.SelectionImageObject = nil
	end
	img.Parent = parent
	return img
end

-- 키트에 그 부품이 있는가(새 부품을 아직 업로드하기 전에도 안전하게 대체하려고)
function exports.Has(name: string): boolean
	return rectOf(name) ~= nil
end

-- 부품 원래 크기(도트)
function exports.Size(name: string): Vector2
	local r = rectOf(name)
	return Vector2.new(r.w, r.h)
end

-- 부품 그림 위치(같은 크기 부품끼리 그림만 바꿀 때 — 예: 탭 켜짐/꺼짐)
function exports.RectOffset(name: string): Vector2
	local r = kit.rects[name]
	return Vector2.new(r.x, r.y)
end

function exports.Panel(parent: Instance, x: number, y: number, w: number, h: number)
	return exports.Part(parent, "panel", x, y, w, h)
end

-- 아이콘: (x, y)에서 size x size 상자(기본 12) 가운데에 그림 자기 크기 그대로(정수배 — 상자 12 = 1배, 24 = 2배) 놓는다.
-- 팩 아이콘은 크기가 제각각(하트 14x12, 엽전 10x10, 아이템 16x16)이라 상자에 억지로 늘리지 않는다 — 도트가 뭉개진다.
function exports.Icon(parent: Instance, name: string, x: number, y: number, size: number?)
	local box = size or 12
	local r = rectOf("icon_" .. name)
	assert(r, "pixelUI: 아이콘이 없습니다 " .. tostring(name))
	local k = math.max(1, box // 12)
	local w, h = r.w * k, r.h * k
	local img = exports.Part(parent, "icon_" .. name, x + (box - w) // 2, y + (box - h) // 2, w, h)
	img.ZIndex = 4
	return img
end

-- 글씨. 글씨가 칸을 넘지 않게: 부모 칸의 크기가 도트로 정해져 있으면 그 안에 들어가도록 폭(MaxWidth) · 줄 수(MaxLines)를 저절로 잡는다
--  — 폭을 넘으면 줄을 바꾸고, 줄 수를 넘으면 "…"로 줄인다. 자리가 더 좁게 정해진 글씨(옆에 버튼이 있는 줄 등)는 props.MaxWidth ·
--  MaxLines를 직접 준다. 오른쪽·가운데 맞춤(Align)이거나 만든 뒤 자리를 다시 잡는 글씨는 저절로 잡지 않는다(Clamp = false로도 끔).
local PANEL_PAD = 10 -- 패널 테두리 안쪽 여백(패널 그림의 테두리가 6칸 + 숨 쉴 틈)
function exports.Label(parent: Instance, text: string, x: number, y: number, props)
	props = props or {}
	props.Text = text
	props.Position = UDim2.fromOffset(x, y)
	if props.MaxWidth == nil and props.Align == nil and props.Clamp ~= false and parent:IsA("GuiObject") then
		local size = (parent :: GuiObject).Size
		local isPanel = parent.Name == "panel"
		local room = size.X.Offset - x - (if isPanel then PANEL_PAD else 1)
		if size.X.Scale == 0 and room >= 12 then
			props.MaxWidth = room
			if props.MaxLines == nil and size.Y.Scale == 0 and size.Y.Offset > 0 then
				local _, lineHeight = pixelText.Measure("", props.Font)
				props.MaxLines = math.max(1, (size.Y.Offset - y - (if isPanel then 6 else 0)) // lineHeight)
			end
		end
	end
	return pixelText.new(parent, props)
end

-- 입체 버튼. Color = "primary"(주황 — 주된 행동) | "plain"(밝은 주황 — 그 밖). 누르는 동안 눌린 그림으로 바뀌고 내용이 1칸 내려간다.
-- 내용: Text(글씨) · Icon(icon_<이름>) · Image(부품 이름 그대로 — 스킬 아이콘처럼 큰 그림, 자기 크기로 가운데)
function exports.Button(parent: Instance, x: number, y: number, w: number, h: number, props)
	props = props or {}
	local color = props.Color or "primary"
	local btn = exports.Part(parent, "button_" .. color, x, y, w, h, "ImageButton")
	btn.AutoButtonColor = false
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = btn
	local textColor = if color == "primary" then C.white else C.ink
	local shadow = if color == "primary" then C.accentD else nil
	local label, icon
	local contentW = 0
	if props.Text then
		contentW += pixelText.Measure(props.Text, "body")
	end
	if props.Icon then
		contentW += if props.Text then 14 else 12
	end
	local cx = math.floor((w - contentW) / 2)
	local cy = math.floor((h - 2 - (if props.Text then 11 else 12)) / 2)
	if props.Image then
		local r = rectOf(props.Image)
		exports.Part(content, props.Image, (w - r.w) // 2, (h - 3 - r.h) // 2).ZIndex = 4
	end
	if props.Icon then
		icon = exports.Icon(content, props.Icon, cx, math.floor((h - 2 - 12) / 2))
		cx += 14
	end
	if props.Text then
		-- 버튼 글씨는 한 줄, 버튼 폭 안에서(넘으면 …)
		label = pixelText.new(content, { Text = props.Text, Color = textColor, Position = UDim2.fromOffset(math.max(cx, 2), cy), Shadow = shadow, MaxWidth = w - 4, MaxLines = 1 })
	end
	local obj = { Instance = btn, Label = label, enabled = true }
	local function look(pressed: boolean)
		if not obj.enabled then
			local r = kit.rects.button_disabled
			btn.ImageRectOffset = Vector2.new(r.x, r.y)
			content.Position = UDim2.fromOffset(0, 0)
			return
		end
		local r = kit.rects["button_" .. color .. (if pressed then "_pressed" else "")]
		btn.ImageRectOffset = Vector2.new(r.x, r.y)
		content.Position = UDim2.fromOffset(0, if pressed then 1 else 0)
	end
	btn.MouseButton1Down:Connect(function()
		look(true)
	end)
	btn.MouseButton1Up:Connect(function()
		look(false)
	end)
	btn.MouseLeave:Connect(function()
		look(false)
	end)
	btn.Activated:Connect(function()
		if obj.enabled and props.OnClick then
			props.OnClick()
		end
	end)
	function obj:SetEnabled(on: boolean)
		obj.enabled = on
		if label then
			-- 꺼진 버튼(어두운 갈색)은 밝은 글씨만(그림자 숨김)
			label:SetColor(if on then textColor else C.paper)
			label:SetShadow(if on then shadow else nil)
		end
		look(false)
	end
	function obj:SetText(text: string)
		if label then
			label:SetText(text)
		end
	end
	return obj
end

-- 게이지(체력 red·경험치 yellow·sky·mint). w = 전체 폭(도트), 높이 9.
function exports.Bar(parent: Instance, x: number, y: number, w: number, color: string)
	local frame = exports.Part(parent, "bar_frame", x, y, w, 9)
	local fill = exports.Part(frame, "bar_fill_" .. color, 1, 1, 0, 7)
	fill.ZIndex = frame.ZIndex + 1
	local obj = { Instance = frame }
	function obj:SetRatio(r: number)
		fill.Size = UDim2.fromOffset(math.floor((w - 2) * math.clamp(r, 0, 1) + 0.5), 7)
	end
	obj:SetRatio(0)
	return obj
end

-- 인벤토리 칸(누를 수 있음). 선택하면 주황 테두리.
function exports.Slot(parent: Instance, x: number, y: number, size: number)
	local btn = exports.Part(parent, "slot", x, y, size, size, "ImageButton")
	btn.AutoButtonColor = false
	local obj = { Instance = btn }
	function obj:SetSelected(on: boolean)
		local r = kit.rects[if on then "slot_selected" else "slot"]
		btn.ImageRectOffset = Vector2.new(r.x, r.y)
	end
	return obj
end

-- 개수·레벨 표시용 알약 모양(주황 또는 어두운 바탕)
function exports.Pill(parent: Instance, x: number, y: number, w: number, h: number, dark: boolean?)
	return exports.Part(parent, if dark then "pill_dark" else "pill", x, y, w, h)
end

-- 패널 위에 걸치는 제목판(제목 16px 글씨). cx = 가운데 x.
function exports.TitleTag(parent: Instance, text: string, cx: number, y: number)
	local w = pixelText.Measure(text, "title") + 16
	local plate = exports.Part(parent, "tag", cx - math.floor(w / 2), y, w, 26)
	plate.ZIndex = 6
	local label = pixelText.new(plate, { Text = text, Font = "title", Color = C.paper, Position = UDim2.fromOffset(8, 3), ZIndex = 7 })
	return plate, label
end

return exports
