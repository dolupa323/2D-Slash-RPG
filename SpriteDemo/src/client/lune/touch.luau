-- 스마트폰(터치) 단추 — 공방 「기본 · UI」 탭의 스마트폰 화면 배치(data/ui.generated.luau의 touch)를 그대로 그린다.
--  사용자 결정(2026-10-06): 스마트폰 터치 조작을 지원한다. 터치 화면이면 저절로 켜진다(Studio에서는 화면 틀의 속성 Touch = true로 켜 볼 수 있다).
--  사용자 2026-10-08(폰에서 해 보고): "모바일버튼을 누르고 거기에 배치할수있는 선택지가 나오고 그걸선택하면 그버튼에 배치되는식 … 소비템이던, 스킬이던
--    현재 사냥,보스,대쉬이렇게 글씨로 적혀있는것도 드래그앤 드랍으로 바꿀수있어야 … 이동형 터치패드도 동그라미만 있는게 아니라 그 가운데 잡고 돌리는 동그라미가 하나 더
--    … ...말고 메뉴라고 적혀있는 탭 … 모바일에서는 위로가는 게 포탈을타거나 상호작용이 안되게하고, 상호작용키를 하나 두는걸로 … 버튼들 퀄리티도 높여야 … 쿨타임 표기도 … 항상 크로스플랫폼을 고려하여"
--
--  칸 단추(slot): PC의 퀵슬롯 열두 칸 바로 그것이다 — 누르면 Input의 "slot:<칸>"을 누른 것과 같다(게임은 키로 눌렀는지 손가락으로 눌렀는지 모른다).
--    칸에 놓인 것의 그림 · 남은 수(물약) · 다시 쓰기까지 남은 시간이 단추에 뜬다. 공격 스킬은 누르고 있으면 이어서 쓴다.
--    놓는 법: ① 빈 단추를 누르거나 메뉴의 「단추 배치」 → 놓을 것의 목록(배운 스킬 · 물약)이 뜨고, 고르면 고른 단추에 놓인다. 배치 중에는 단추를 끌어 서로 자리를 바꾼다.
--            ② 스킬 창 · 가방에서 스킬 · 물약을 누르고(또는 끌어) 단추를 누른다 — PC와 같은 법(ui/quickEdit.luau가 한다. 단추의 자리는 Hud.touchSlotAt으로 알려 준다).
--  조이스틱: 바깥 원 + 가운데 손잡이. 좌우 = 걷기, 아래 = 발판에서 내려오기. 위로 미는 것은 아무 일도 없다(문 · 주민 · 줍기는 상호작용 단추).
--  단추의 자리는 게임 화면(384x216)의 도트로 적혀 있다. 그리는 곳은 화면 틀의 층(고운 격자)이라, 그 자리에 Stage.ratio를 곱해 놓는다.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Quick = require(ReplicatedStorage.shared.lune.ui.quick)
local Stage = require(script.Parent.stage)
local Input = require(script.Parent.input)
local Hud = require(script.Parent.hud)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local PIC = 24 -- 그림 한 장(화면 틀의 점)
local HOLD_FIRST, HOLD_NEXT = 0.3, 0.12 -- 공격 스킬을 누르고 있을 때: 처음 다시 누르기까지 · 그 뒤의 간격(초)
local DRAG = Quick.DATA.drag -- 이만큼 움직이면 끌기로 본다(화면 틀의 점)
local ACT_WORDS = { pickup = "줍기", portal = "들어가기", npc = "말 걸기" }

local Touch = {}
Touch.on = false
Touch.arranging = false

local opts = nil
local root: Frame = nil
local buttons = {} -- 누르는 단추들 { t, frame, stroke, hit, … }
local slotButtons = {} -- [칸] = 단추
local actButton = nil
local pad = nil -- 조이스틱 { frame, knob, radius }
local chooser: Frame? = nil -- 놓을 것의 목록
local selected: number? = nil -- 배치 중에 고른 칸
local held = {} -- [칸] = { input, t, next } — 누르고 있는 칸 단추
local drag = nil -- 배치 중에 끄는 것 { from, input, start, moved, ghost }
local state = { slots = {}, cds = {}, potions = 0, act = nil :: string?, pick = false, hot = nil :: number? }

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function sameFinger(input: InputObject, began: InputObject): boolean
	return input == began or (began.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
end

local function moved(input: InputObject, began: InputObject): boolean
	return input == began or (began.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
end

local function corner(frame: Instance, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = frame
end

local function ring(frame: Instance, color: Color3, thickness: number, alpha: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = alpha or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = frame
	return s
end

-- ---------- 단추의 모습 ----------
--  어두운 판 + 바깥 테두리(강조색) + 안쪽의 가는 테두리. 누르고 있으면 밝아진다. 가운데에 그림이나 글.
local function paintButton(b)
	local t = b.t
	local slotOn = t.slot and state.slots[t.slot]
	local main = t.kind == "big" or t.kind == "pad"
	local edge = if main then C.accent else C.lineHot
	local alpha = if main then 0 else 0.15
	if t.slot then
		if Touch.arranging then
			edge, alpha = (if selected == t.slot then C.text else C.accent), 0
		elseif state.pick or state.hot == t.slot then
			edge, alpha = C.accent, 0
		elseif not slotOn then
			alpha = 0.55 -- 빈 칸은 흐리게
		end
	elseif t.act == "interact" then
		edge, alpha = (if state.act then C.accent else C.lineHot), (if state.act then 0 else 0.4)
	end
	b.stroke.Color = edge
	b.stroke.Transparency = alpha
	b.frame.BackgroundColor3 = if b.down then C.accent else C.ink
	b.frame.BackgroundTransparency = if b.down then 0.55 elseif t.slot and not slotOn and not Touch.arranging then 0.7 else 0.4
end

local function paintAll()
	for _, b in buttons do
		paintButton(b)
	end
end

-- 칸 단추에 놓인 것을 그린다: 그림 · 남은 수 · 다시 쓰기까지 남은 시간
local function paintSlot(b)
	local what = state.slots[b.t.slot]
	Ui.setPic(b.pic, if what then Quick.pic(what) else nil)
	b.plus:show(not what)
	if what == Quick.POTION then
		b.count:set(tostring(state.potions))
		b.count:show(true)
	else
		b.count:show(false)
	end
	local cd = if what and what ~= Quick.POTION then state.cds[what] else nil
	local remain = if cd then cd.remain else 0
	b.veil.Visible = remain > 0
	if remain > 0 then
		b.wait:set(if remain >= 10 then tostring(math.ceil(remain)) elseif remain >= 1 then tostring(math.ceil(remain)) else ("%.1f"):format(remain))
		b.wait:show(true)
	else
		b.wait:show(false)
	end
	paintButton(b)
end

local function paintSlots()
	for _, b in slotButtons do
		paintSlot(b)
	end
end

-- 상호작용 단추: 가까이에 있는 것에 따라 글이 바뀌고 밝아진다
local function paintAct()
	if actButton then
		actButton.label:set(if state.act then ACT_WORDS[state.act] else "상호작용")
		actButton.label:color(if state.act then C.text else C.dim)
		paintButton(actButton)
	end
end

-- ---------- 배치(놓을 것의 목록) ----------
local function closeChooser()
	if chooser then
		chooser:Destroy()
		chooser = nil
	end
end

local function apply(next)
	if next then
		opts.apply(next)
	end
end

-- 놓을 것의 목록을 그 칸에 맞춰 다시 그린다
local function openChooser()
	closeChooser()
	if not Touch.arranging then
		return
	end
	local list = opts.choices() -- { { what, name } … } — 물약과 배운(쓸 수 있는) 스킬
	local cols, cell, gap, pad0 = 5, 44, 6, 12
	local rows = math.max(1, math.ceil(#list / cols))
	local w = pad0 * 2 + cols * cell + (cols - 1) * gap
	local h = 34 + rows * (cell + 16) + 44
	local holder = Stage.place(Stage.ui, "TouchChooser", "tc", 480 - w / 2, 54, w, h)
	holder.ZIndex = 170
	local panel = Ui.panel(holder, 0, 0, w, h)
	local hold = Instance.new("TextButton") -- 판을 눌러도 뒤의 것이 눌리지 않게
	hold.Text = ""
	hold.BackgroundTransparency = 1
	hold.Size = UDim2.fromScale(1, 1)
	hold.ZIndex = 1
	hold.Parent = panel
	local title = if selected then "밝게 뜬 단추에 놓을 것을 고르세요" else "바꿀 단추를 누르세요 · 끌면 자리를 바꿉니다"
	Ui.text(panel, title, pad0, 10, w - pad0 * 2, { font = "body", color = if selected then C.accent else C.text })
	for i, item in list do
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		local x, y = pad0 + col * (cell + gap), 34 + row * (cell + 16)
		local slot = Ui.slot(panel, x, y, cell)
		slot.frame.ZIndex = 2
		local now = selected and state.slots[selected] == item.what
		slot:setOn(now == true)
		local pic = Ui.pic(slot.frame, Quick.pic(item.what), math.floor((cell - PIC) / 2), math.floor((cell - PIC) / 2))
		pic.ZIndex = 2
		local placed = Quick.find(state.slots, item.what) ~= nil
		Ui.text(panel, item.name, x - 3, y + cell + 2, cell + 6, { align = "center", color = if placed then C.accent else C.text, outline = true }) -- 이미 어느 단추에 놓여 있는 것은 민트
		local hit = Ui.hit(slot.frame)
		hit.Activated:Connect(function()
			if selected then
				apply(Quick.place(state.slots, item.what, selected))
			end
		end)
	end
	local by = h - 38
	local bw = math.floor((w - pad0 * 2 - 8) / 2)
	Ui.button(panel, "비우기", pad0, by, bw, function()
		if selected then
			apply(Quick.clear(state.slots, selected))
		end
	end, { h = 28 }).frame.ZIndex = 2
	Ui.button(panel, "완료", pad0 + bw + 8, by, bw, function()
		Touch.arrange(false)
	end, { h = 28, main = true }).frame.ZIndex = 2
	chooser = holder
end

-- 배치를 시작한다 · 끝낸다. slot = 처음부터 고른 칸(빈 단추를 눌렀을 때)
function Touch.arrange(on: boolean, slot: number?)
	if not Touch.on then
		on = false
	end
	Touch.arranging = on
	selected = if on then slot else nil
	for i in held do
		Input.release("tslot:" .. i)
	end
	table.clear(held)
	if drag and drag.ghost then
		drag.ghost:Destroy()
	end
	drag = nil
	if on then
		openChooser()
	else
		closeChooser()
	end
	paintAll()
end

-- 화면의 그 자리에 있는 칸 단추(없으면 nil)
function Touch.slotAt(at: Vector2): number?
	for i, b in slotButtons do
		local p, size = b.frame.AbsolutePosition, b.frame.AbsoluteSize
		local c = p + size / 2
		if (at - c).Magnitude <= size.X / 2 + 4 then
			return i
		end
	end
	return nil
end

-- ---------- 그리기 ----------
local function px(v: number): number
	return math.floor(v * Stage.ratio + 0.5)
end

local function makeButton(t)
	local size = px(t.w)
	local frame = Instance.new("Frame")
	frame.Name = "T" .. t.no
	frame.Position = UDim2.fromOffset(px(t.x), px(t.y))
	frame.Size = UDim2.fromOffset(px(t.w), px(t.h))
	frame.BackgroundColor3 = C.ink
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = root
	local round = t.w == t.h -- 동그란 단추 / 글이 적힌 길쭉한 단추(메뉴 · 채팅)
	corner(frame, if round then nil else UDim.new(0, 6))
	local stroke = ring(frame, C.accent, 2)
	-- 안쪽의 가는 테두리 한 줄(겹테)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.Parent = frame
	corner(inner, if round then nil else UDim.new(0, 4))
	ring(inner, C.text, 1, 0.82)
	-- 가운데 틀: 그림 · 글은 단추의 한가운데에
	local mid = Instance.new("Frame")
	mid.Name = "Mid"
	mid.BackgroundTransparency = 1
	mid.Position = UDim2.fromScale(0.5, 0.5)
	mid.Size = UDim2.fromOffset(0, 0)
	mid.ZIndex = 2
	mid.Parent = frame
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Position = UDim2.fromOffset(-4, -4) -- 손가락이 조금 벗어나도 눌리게
	hit.Size = UDim2.new(1, 8, 1, 8)
	hit.ZIndex = 9
	hit.Parent = frame
	local b = { t = t, frame = frame, stroke = stroke, hit = hit, mid = mid, size = size, down = false }
	table.insert(buttons, b)
	return b
end

-- 칸 단추: 그림(큰 단추는 두 배) · 빈 칸의 "+" · 남은 수 · 다시 쓰기 덮개와 남은 초
local function makeSlot(t)
	local b = makeButton(t)
	local k = if b.size >= 64 then 2 else 1
	local side = PIC * k
	b.pic = Ui.pic(b.mid, nil, -side / 2, -side / 2)
	b.pic.Size = UDim2.fromOffset(side, side)
	b.plus = Ui.text(b.mid, "+", -20, -7, 40, { font = "body", align = "center", color = C.dim })
	b.count = Ui.text(b.mid, "", -side / 2, side / 2 - 10, side + 4, { align = "right", outline = true, z = 6 })
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.BackgroundColor3 = C.ink
	veil.BackgroundTransparency = 0.3
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 4
	veil.Visible = false
	veil.Parent = b.frame
	corner(veil)
	b.veil = veil
	b.wait = Ui.text(b.mid, "", -30, -7, 60, { font = "body", align = "center", outline = true, z = 7 })
	b.wait.label.Frame.ZIndex = 7
	slotButtons[t.slot] = b

	local i = t.slot
	b.hit.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		local what = state.slots[i]
		if Touch.arranging then
			-- 배치 중: 누르면 그 칸을 고르고, 끌면 자리를 바꾼다
			selected = i
			drag = { from = i, input = input, start = Vector2.new(input.Position.X, input.Position.Y), moved = false, ghost = nil }
			openChooser()
			paintAll()
		elseif state.pick then
			-- 스킬 창 · 가방에서 놓을 것을 골라 둔 채다: 이 칸에 놓는다(ui/quickEdit.luau)
			if Hud.onSlotClick then
				Hud.onSlotClick(i)
			end
		elseif not what then
			Touch.arrange(true, i) -- 빈 단추: 놓을 것의 목록을 띄운다
		else
			b.down = true
			Input.press("tslot:" .. i)
			held[i] = { input = input, t = 0, next = HOLD_FIRST }
			paintButton(b)
		end
	end)
	return b
end

local function makeAct(t)
	local b = makeButton(t)
	if t.act == "jump" then
		b.label = Ui.text(b.mid, "점프", -40, -7, 80, { font = "body", align = "center", outline = true })
	elseif t.act == "interact" then
		b.label = Ui.text(b.mid, "상호작용", -40, -6, 80, { align = "center", outline = true })
		actButton = b
	elseif t.act == "menu" then
		b.label = Ui.text(b.mid, "메뉴", -40, -7, 80, { font = "body", align = "center", outline = true })
	elseif t.act == "chat" then
		b.label = Ui.text(b.mid, "채팅", -40, -6, 80, { align = "center", outline = true })
	end
	local finger: InputObject? = nil
	b.hit.InputBegan:Connect(function(input)
		if not isPress(input) or finger then
			return
		end
		if Touch.arranging then
			Touch.arrange(false) -- 다른 단추를 누르면 배치를 끝낸다
		end
		finger = input
		b.down = true
		paintButton(b)
		if t.act == "jump" then
			Input.press("jump")
		elseif t.act == "interact" then
			opts.onAct(true)
		elseif t.act == "menu" then
			opts.onMenu()
		elseif t.act == "chat" then
			opts.onChat()
		end
	end)
	b.release = function(input: InputObject)
		if finger and sameFinger(input, finger) then
			finger = nil
			b.down = false
			paintButton(b)
			if t.act == "jump" then
				Input.release("jump")
			elseif t.act == "interact" then
				opts.onAct(false)
			end
		end
	end
	return b
end

-- 조이스틱: 바깥 원(자리는 그대로) + 가운데 손잡이(손가락을 따라 원 안에서 움직인다)
local function makePad(t)
	local size = px(t.w)
	local base = Instance.new("Frame")
	base.Name = "Pad"
	base.Position = UDim2.fromOffset(px(t.x), px(t.y))
	base.Size = UDim2.fromOffset(size, size)
	base.BackgroundColor3 = C.ink
	base.BackgroundTransparency = 0.55
	base.BorderSizePixel = 0
	base.Parent = root
	corner(base)
	local stroke = ring(base, C.accent, 2, 0.15)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(5, 5)
	inner.Size = UDim2.new(1, -10, 1, -10)
	inner.Parent = base
	corner(inner)
	ring(inner, C.text, 1, 0.85)
	-- 좌우의 작은 세모(어느 쪽으로 미는지): 가는 막대 셋으로 그린다(글꼴에 화살표 글자가 없다)
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			local bar = Instance.new("Frame")
			bar.Name = "Arrow"
			bar.BackgroundColor3 = C.text
			bar.BackgroundTransparency = 0.6
			bar.BorderSizePixel = 0
			bar.Size = UDim2.fromOffset(2, 2 + k * 4)
			bar.Position = UDim2.fromOffset(math.floor(size / 2) + side * (math.floor(size * 0.4) - k * 2) - 1, math.floor(size / 2) - 1 - k * 2)
			bar.Parent = base
		end
	end
	local ks = math.floor(size * 0.44)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(ks, ks)
	knob.BackgroundColor3 = C.accent
	knob.BackgroundTransparency = 0.45
	knob.BorderSizePixel = 0
	knob.ZIndex = 3
	knob.Parent = base
	corner(knob)
	ring(knob, C.text, 1, 0.3)
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Position = UDim2.fromScale(-0.2, -0.2) -- 원보다 조금 넓게 받는다
	hit.Size = UDim2.fromScale(1.4, 1.4)
	hit.ZIndex = 9
	hit.Parent = base
	pad = { frame = base, knob = knob, stroke = stroke, finger = nil :: InputObject? }

	local function set(action: string, on: boolean)
		if on then
			Input.press(action)
		else
			Input.release(action)
		end
	end
	local function aim(pos: Vector3)
		local center = base.AbsolutePosition + base.AbsoluteSize / 2
		local radius = base.AbsoluteSize.X / 2
		local v = Vector2.new(pos.X - center.X, pos.Y - center.Y)
		local reach = radius * 0.62 -- 손잡이가 나갈 수 있는 끝
		if v.Magnitude > reach then
			v = v.Unit * reach
		end
		local s = Stage.uiScale
		knob.Position = UDim2.new(0.5, v.X / s, 0.5, v.Y / s)
		set("left", v.X < -radius * 0.2)
		set("right", v.X > radius * 0.2)
		set("down", v.Y > radius * 0.42) -- 아래로 밀면 발판에서 내려온다
		-- 위로 미는 것은 아무 일도 없다(문 · 주민은 상호작용 단추 — 사용자 2026-10-08)
	end
	pad.stop = function()
		pad.finger = nil
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.BackgroundTransparency = 0.45
		for _, a in { "left", "right", "down" } do
			Input.release(a)
		end
	end
	hit.InputBegan:Connect(function(input)
		if isPress(input) and not pad.finger then
			pad.finger = input
			knob.BackgroundTransparency = 0.2
			aim(input.Position)
		end
	end)
	pad.aim = aim
end

local function build()
	for _, c in root:GetChildren() do
		c:Destroy()
	end
	table.clear(buttons)
	table.clear(slotButtons)
	actButton, pad = nil, nil
	for _, t in UI.touch do
		if t.kind == "pad" then
			makePad(t)
		elseif t.slot then
			makeSlot(t)
		elseif t.act then
			makeAct(t)
		end
	end
	-- 스킬 창 · 가방에서 놓을 것을 골랐을 때의 안내(아래 가운데, 체력 덩어리 위)
	local hint = Stage.place(root, "PickHint", "tc", 480 - 150, 50, 300, 16)
	Touch.hint = Ui.text(hint, "놓을 단추를 누르세요", 0, 0, 300, { align = "center", color = C.accent, outline = true })
	Touch.hint:show(false)
	paintSlots()
	paintAct()
	paintAll()
end

-- ---------- 밖에서 알려 주는 것 ----------
-- 칸들에 놓인 것(PC의 퀵슬롯과 같은 열두 칸)
function Touch.setSlots(slots)
	state.slots = slots or {}
	if root then
		paintSlots()
		if Touch.arranging then
			openChooser()
		end
	end
end

-- 기술을 다시 쓰기까지 남은 시간(초). 화면마다 불러도 된다(보이는 글이 바뀔 때만 고쳐 그린다)
function Touch.setCooldown(id: string, remain: number, total: number)
	remain = math.max(0, remain)
	local cd = state.cds[id]
	if not cd then
		cd = { remain = 0, shown = "" }
		state.cds[id] = cd
	end
	cd.remain = remain
	local shown = if remain <= 0 then "" elseif remain >= 1 then tostring(math.ceil(remain)) else ("%.1f"):format(remain)
	if shown ~= cd.shown then
		cd.shown = shown
		local i = Quick.find(state.slots, id)
		if i and slotButtons[i] then
			paintSlot(slotButtons[i])
		end
	end
end

-- 남은 물약의 수
function Touch.setPotions(n: number)
	state.potions = n
	local i = Quick.find(state.slots, Quick.POTION)
	if i and slotButtons[i] then
		paintSlot(slotButtons[i])
	end
end

-- 상호작용 단추가 할 일: "pickup"(떨어진 물건) · "portal"(문) · "npc"(주민) · nil(가까이에 아무것도 없다)
function Touch.setAct(kind: string?)
	if state.act ~= kind then
		state.act = kind
		paintAct()
	end
end

function Touch.init(options)
	opts = options
	root = Stage.group(Stage.ui, "Touch", 120)
	root.Visible = false
	Touch.root = root
	build()
	Stage.onResize(function()
		Touch.arrange(false)
		build()
	end)

	-- 스킬 창 · 가방에서 고르거나 끌 때: 칸 단추가 PC의 칸 노릇을 한다(ui/quickEdit.luau · hud.luau)
	Hud.touchSlotAt = Touch.slotAt
	Hud.touchPick = function(on: boolean)
		state.pick = on
		if Touch.hint then
			Touch.hint:show(on and Touch.on)
		end
		paintAll()
	end
	Hud.touchHot = function(i: number?)
		state.hot = i
		paintAll()
	end

	UserInputService.InputChanged:Connect(function(input)
		if pad and pad.finger and moved(input, pad.finger) then
			pad.aim(input.Position)
		end
		local d = drag
		if d and moved(input, d.input) then
			local at = Vector2.new(input.Position.X, input.Position.Y)
			if not d.moved and (at - d.start).Magnitude > DRAG * Stage.uiScale and state.slots[d.from] then
				d.moved = true
				local ghost = Ui.group(Stage.ui, 0, 0, PIC + 8, PIC + 8, "TouchGhost")
				ghost.ZIndex = 400
				Ui.slot(ghost, 0, 0, PIC + 8):setOn(true)
				Ui.pic(ghost, Quick.pic(state.slots[d.from]), 4, 4).ZIndex = 2
				d.ghost = ghost
			end
			if d.moved and d.ghost then
				local origin = Stage.ui.AbsolutePosition
				local half = (PIC + 8) / 2
				d.ghost.Position = UDim2.fromOffset(math.floor((at.X - origin.X) / Stage.uiScale - half + 0.5), math.floor((at.Y - origin.Y) / Stage.uiScale - half + 0.5))
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not isPress(input) then
			return
		end
		if pad and pad.finger and sameFinger(input, pad.finger) then
			pad.stop()
		end
		for i, h in held do
			if sameFinger(input, h.input) then
				held[i] = nil
				Input.release("tslot:" .. i)
				local b = slotButtons[i]
				if b then
					b.down = false
					paintButton(b)
				end
			end
		end
		for _, b in buttons do
			if b.release then
				b.release(input)
			end
		end
		local d = drag
		if d and sameFinger(input, d.input) then
			drag = nil
			if d.ghost then
				d.ghost:Destroy()
			end
			if d.moved then
				-- 다른 칸 단추 위에 놓았다: 자리를 바꾼다
				local j = Touch.slotAt(Vector2.new(input.Position.X, input.Position.Y))
				local what = state.slots[d.from]
				if j and j ~= d.from and what then
					selected = j
					apply(Quick.place(state.slots, what, j))
				end
			end
		end
	end)
	-- 누르고 있는 공격 스킬은 이어서 쓴다(손가락으로 연타하지 않아도 되게 — 물약 · 그 밖의 스킬은 한 번만)
	RunService.Heartbeat:Connect(function(dt)
		for i, h in held do
			h.t += dt
			if h.t >= h.next then
				h.next = h.t + HOLD_NEXT
				local what = state.slots[i]
				if what and what ~= Quick.POTION and opts.repeats(what) then
					Input.release("tslot:" .. i)
					Input.press("tslot:" .. i)
				end
			end
		end
	end)

	local function decide()
		local forced = Stage.gui:GetAttribute("Touch")
		local on = forced == true or (forced == nil and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		Touch.on = on
		root.Visible = on
		if not on then
			Touch.arrange(false)
			if pad then
				pad.stop()
			end
		end
		if opts.onToggle then
			opts.onToggle(on)
		end
	end
	Stage.gui:GetAttributeChangedSignal("Touch"):Connect(decide)
	decide()
end

return Touch
