-- 도트 UI 부품 — 에셋 공방(js/ui.js)에서 만든 부품 아틀라스(ui_parts.png)를 잘라 쓴다.
-- 규칙(예시 영상 Dumpling Dell): 흰 패널 + 진보라 도트 테두리 + 아래 연보라 그림자, 분홍 입체 버튼, 도트 글씨(pixelText).
-- 패널·버튼·칸은 9분할(ScaleType.Slice)이라 어떤 크기로 늘려도 모서리가 안 깨진다.
--
-- 좌표 단위는 "UI 도트". 화면 배율은 Scale(root)가 화면 높이에 맞춰 정수배(1·2·3·4…)로 건다 — 정수라야 도트가 고르다.
-- (공방 UI 탭의 예시 화면 480x270 = 1080p에서 4배와 같은 비율)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = require(ReplicatedStorage.shared.data["uiKit.generated"])
local uiAssets = require(ReplicatedStorage.shared.config["uiAssets.generated"])
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
	local r = kit.rects[name]
	assert(r, "pixelUI: 부품이 없습니다 " .. tostring(name))
	local img = Instance.new(class or "ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = uiAssets.UI_PARTS
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
	return kit.rects[name] ~= nil
end

-- 부품 원래 크기(도트)
function exports.Size(name: string): Vector2
	local r = kit.rects[name]
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

function exports.Icon(parent: Instance, name: string, x: number, y: number, size: number?)
	local img = exports.Part(parent, "icon_" .. name, x, y, size or 12, size or 12)
	img.ZIndex = 4
	return img
end

-- 글씨
function exports.Label(parent: Instance, text: string, x: number, y: number, props)
	props = props or {}
	props.Text = text
	props.Position = UDim2.fromOffset(x, y)
	return pixelText.new(parent, props)
end

-- 분홍(또는 다른 색) 입체 버튼. 누르는 동안 눌린 그림으로 바뀌고 글씨가 1칸 내려간다.
function exports.Button(parent: Instance, x: number, y: number, w: number, h: number, props)
	props = props or {}
	local color = props.Color or "pink"
	local btn = exports.Part(parent, "button_" .. color, x, y, w, h, "ImageButton")
	btn.AutoButtonColor = false
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = btn
	local textColor = if color == "white" or color == "yellow" then C.ink else C.white
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
	if props.Icon then
		icon = exports.Icon(content, props.Icon, cx, math.floor((h - 2 - 12) / 2))
		cx += 14
	end
	if props.Text then
		label = pixelText.new(content, {
			Text = props.Text, Color = textColor, Position = UDim2.fromOffset(cx, cy),
			Shadow = if textColor == C.white then (if color == "mint" then C.mintD else C.pinkD) else nil,
		})
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
			-- 꺼진 버튼은 회색 바탕에 진보라 글씨만(그림자 숨김)
			label:SetColor(if on then textColor else C.ink)
			label:SetShadow(if on and textColor == C.white then (if color == "mint" then C.mintD else C.pinkD) else nil)
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

-- 인벤토리 칸(누를 수 있음). 선택하면 분홍 테두리.
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

-- 개수·레벨 표시용 알약 모양(분홍 또는 진보라)
function exports.Pill(parent: Instance, x: number, y: number, w: number, h: number, dark: boolean?)
	return exports.Part(parent, if dark then "pill_ink" else "pill_pink", x, y, w, h)
end

-- 패널 위에 걸치는 제목판(제목 16px 글씨). cx = 가운데 x.
function exports.TitleTag(parent: Instance, text: string, cx: number, y: number)
	local w = pixelText.Measure(text, "title") + 16
	local plate = exports.Part(parent, "tag", cx - math.floor(w / 2), y, w, 26)
	plate.ZIndex = 6
	local label = pixelText.new(plate, { Text = text, Font = "title", Color = C.ink, Position = UDim2.fromOffset(8, 3), ZIndex = 7 })
	return plate, label
end

return exports
