-- 스마트폰(터치) 단추 — 공방 「기본 · UI」 탭의 스마트폰 화면 배치(data/ui.generated.luau의 touch)를 그대로 그린다.
--  「채팅」 단추는 없다(2026-10-13): 채팅은 Roblox의 기본 채팅이고, 폰에서는 화면 위의 Roblox 채팅 단추로 연다(chat.luau).
--  사용자 결정(2026-10-06): 스마트폰 터치 조작을 지원한다. 터치 화면이면 저절로 켜진다(Studio에서는 화면 틀의 속성 Touch = true로 켜 볼 수 있다).
--  사용자 2026-10-08(폰에서 해 보고): "모바일버튼을 누르고 거기에 배치할수있는 선택지가 나오고 그걸선택하면 그버튼에 배치되는식 … 소비템이던, 스킬이던
--    현재 사냥,보스,대쉬이렇게 글씨로 적혀있는것도 드래그앤 드랍으로 바꿀수있어야 … 이동형 터치패드도 동그라미만 있는게 아니라 그 가운데 잡고 돌리는 동그라미가 하나 더
--    … ...말고 메뉴라고 적혀있는 탭 … 모바일에서는 위로가는 게 포탈을타거나 상호작용이 안되게하고, 상호작용키를 하나 두는걸로 … 버튼들 퀄리티도 높여야 … 쿨타임 표기도 … 항상 크로스플랫폼을 고려하여"
--
--  칸 단추(slot): PC의 퀵슬롯 열두 칸 바로 그것이다 — 누르면 Input의 "slot:<칸>"을 누른 것과 같다(게임은 키로 눌렀는지 손가락으로 눌렀는지 모른다).
--    칸에 놓인 것의 그림 · 남은 수(물약) · 다시 쓰기까지 남은 시간이 단추에 뜬다. 공격 스킬은 누르고 있으면 이어서 쓴다.
--    놓는 법: ① 빈 단추를 누르거나 메뉴의 「단추 배치」 → 놓을 것의 목록(배운 스킬 · 물약)이 뜨고, 고르면 고른 단추에 놓인다. 배치 중에는 단추를 끌어 서로 자리를 바꾼다.
--            ② 스킬 창 · 가방에서 스킬 · 물약을 누르고(또는 끌어) 단추를 누른다 — PC와 같은 법(ui/quickEdit.luau가 한다. 단추의 자리는 Hud.touchSlotAt으로 알려 준다).
--  조이스틱: 바깥 원 + 가운데 손잡이. 좌우 = 걷기, 아래로 민 채 「점프」 = 발판에서 내려오기(하단 점프 — PC의 ↓ + 뛰기와 같다). 위로 미는 것은 아무 일도 없다(문 · 주민 · 줍기는 상호작용 단추).
--  단추의 자리는 게임 화면(384x216)의 도트로 적혀 있다. 그리는 곳은 화면 틀의 층(고운 격자)이라, 그 자리에 Stage.ratio를 곱해 놓는다.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Quick = require(ReplicatedStorage.shared.lune.ui.quick)
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Stage = require(script.Parent.stage)
local Input = require(script.Parent.input)
local Hud = require(script.Parent.hud)
local Ui = require(script.Parent.ui.ui)
local G = require(ReplicatedStorage.shared.lune.config.game)
local VIEW_W, VIEW_H = G.VIEW_W, G.VIEW_H -- 게임 화면(도트)

local C = Ui.COLOR
local PIC = 24 -- 그림 한 장(화면 틀의 점)
-- 조이스틱(2026-10-30 사용자 "모바일 이동시 아래로 내려가기 위해 컨트롤러를 내리면 캐릭터가 멈춘다는데 … 원래 판정으로 만들어야해"):
--  walk = 반지름의 몇 배를 밀어야 움직이는가(엄지를 얹거나 조금 흔들려도 걷지 않게 — 10-27 「민감도가 너무 높다」의 0.35는 그대로) ·
--  side = 수평에서 몇 도 안이면 좌우로 걷는가 · ud = 수평에서 몇 도 넘게 기울면 아래(하단 점프) · 위(사다리)인가 — 둘이 겹쳐 「걸으면서 아래」가 된다(10-27 전의 판정과 같은 각도)
--  10-27에는 좌우 · 위아래를 반지름의 0.35 · 0.55배의 거리로 따로 재서, 손잡이를 끝까지(반지름의 0.62) 민 채 대각선 아래(수평에서 약 56~62°)로 두면 좌우도 아래도 꺼져 멈췄다
local STICK = { walk = 0.35, side = 70, ud = 40 }
local HOLD_FIRST, HOLD_NEXT = 0.3, 0.12 -- 공격 스킬을 누르고 있을 때: 처음 다시 누르기까지 · 그 뒤의 간격(초)
local DRAG = Quick.DATA.drag -- 이만큼 움직이면 끌기로 본다(화면 틀의 점)
local ACT_WORDS = { pickup = "줍기", portal = "들어가기", npc = "말 걸기", spot = "살펴보기", vista = "둘러보기", chest = "상자 열기" } -- spot = 맵에 놓인 것 앞(퀘스트의 자리) · vista = 경관의 자리(성의 테라스 — 2026-10-18) · chest = 보상의 방의 상자(2026-10-28)

local Touch = {}
Touch.STICK = STICK -- (시험이 본다)

-- 조이스틱을 민 만큼(vx · vy — 아래가 +) · 반지름 → 왼쪽 · 오른쪽 · 아래 · 위
function Touch.dirs(vx: number, vy: number, radius: number): (boolean, boolean, boolean, boolean)
	local mag = math.sqrt(vx * vx + vy * vy)
	if mag < radius * STICK.walk then
		return false, false, false, false
	end
	local deg = math.deg(math.atan2(math.abs(vy), math.abs(vx))) -- 수평에서 기운 각도(0 ~ 90)
	local side = deg <= STICK.side
	local ud = deg >= STICK.ud
	return side and vx < 0, side and vx > 0, ud and vy > 0, ud and vy < 0
end
Touch.on = false
Touch.arranging = false

local opts = nil
local root: Frame = nil
local buttons = {} -- 누르는 단추들 { t, frame, stroke, hit, … }
local slotButtons = {} -- [칸] = 단추
local menuDot: Frame? = nil -- 「메뉴」 단추 오른쪽 위의 노란 점(받을 출석 · 업적이 있다 — 2026-10-15)
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

-- 그 손가락(마우스 단추)을 이미 뗐나 — 뗀 알림(InputEnded)을 놓쳐도 끄는 그림이 남지 않게(2026-10-23 사용자: "모바일 환경에서 드래그앤 드랍으로 키를 바꾸려고하면 이상하게 아이콘 잔상이 남는버그")
local function lifted(input: InputObject): boolean
	local st = input.UserInputState
	return st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel
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
	local active = slotOn and Hud.active[slotOn] == true -- 켜 둔 사출기: 테두리가 켜지고 판에 민트가 옅게 깔린다(큰 단추는 테두리가 늘 민트라 판으로 가린다)
	local main = t.kind == "big" or t.kind == "pad"
	local edge = if main then C.accent else C.lineHot
	local alpha = if main then 0 else 0.15
	if t.slot then
		if Touch.arranging then
			edge, alpha = (if selected == t.slot then C.text else C.accent), 0
		elseif state.pick or state.hot == t.slot or active then
			edge, alpha = C.accent, 0 -- 고르는 중 · 놓을 칸 · 켜 둔 사출기
		elseif not slotOn then
			alpha = 0.55 -- 빈 칸은 흐리게
		elseif Quick.act(slotOn) == "interact" then
			edge, alpha = (if state.act then C.accent else C.lineHot), (if state.act then 0 else 0.4) -- 상호작용: 가까이에 무엇이 있으면 밝아진다
		end
	end
	b.stroke.Color = edge
	b.stroke.Transparency = alpha
	b.frame.BackgroundColor3 = if b.down or active then C.accent else C.ink
	b.frame.BackgroundTransparency = if b.down then 0.55 elseif active then 0.72 elseif t.slot and not slotOn and not Touch.arranging then 0.7 else 0.4
end

-- 점프 · 상호작용이 놓인 칸 단추의 글(상호작용은 가까이에 있는 것에 따라 바뀐다 — 줍기 · 들어가기 · 말 걸기 …)
local function actWord(kind: string?): string
	if kind == "jump" then
		return Quick.ACTS.act_jump.name
	end
	return if state.act then ACT_WORDS[state.act] else Quick.ACTS.act_interact.name
end

local function paintAll()
	for _, b in buttons do
		paintButton(b)
	end
end

-- 칸 단추에 놓인 것을 그린다: 그림 · 남은 수 · 다시 쓰기까지 남은 시간
local function paintSlot(b)
	local what = state.slots[b.t.slot]
	-- 점프 · 상호작용(2026-10-21 — 칸 단추에 놓이는 「하는 일」): 그림 대신 글
	local act = Quick.act(what)
	b.act:show(act ~= nil)
	if act then
		b.act:set(actWord(act))
		b.act:color(if act == "interact" and not state.act then C.dim else C.text)
	end
	Ui.setPic(b.pic, if what and not act then Quick.pic(what) else nil)
	b.plus:show(not what)
	if what and Quick.item(what) then
		local n = if Hud.countOf then Hud.countOf(what) else 0
		b.count:set(tostring(n)) -- 소비 아이템: 가방에 든 수
		b.count:color(if n == 0 then Ui.COLOR.red else Ui.COLOR.text) -- 다 쓰면 붉은 0(2026-10-18)
		b.count:show(true)
	elseif Quick.seqMark(what) then
		b.count:set(Quick.seqMark(what) :: string) -- 시퀀스의 단추: 구석에 「S1」 · 「B1」(2026-10-30)
		b.count:color(Ui.COLOR.accent)
		b.count:show(true)
	else
		b.count:show(false)
	end
	local cd = if what and (not Quick.item(what) or Quick.isPotion(what)) then state.cds[what] else nil -- (물약도 다시 마시기까지 — 2026-10-27 3초)
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

-- 상호작용 단추: 가까이에 있는 것에 따라 글이 바뀌고 밝아진다(상호작용이 놓인 칸 단추 — 2026-10-21부터 어느 칸에든 놓인다)
local function paintAct()
	for _, b in slotButtons do
		if Quick.act(state.slots[b.t.slot]) == "interact" then
			paintSlot(b)
		end
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
	local list = opts.choices() -- { { what, name } … } — 물약 · 배운(쓸 수 있는) 스킬 · 가진 펫 · 탈것
	-- 판은 왼쪽 위 · 화면에 들어가는 만큼만 길어지고 넘치는 줄은 밀어서 본다(2026-10-21 점검 — Layout.touchChooser). 왼쪽 아래의 칸 단추(처음에는 상호작용)는 덮지 않는다(그 위에서 끝난다)
	local K = Layout.TOUCHCHOOSER
	local m = Layout.touchChooserFit(#list, Stage.uiH, Stage.insetTop, UI.touch, Stage.ratio) -- 칸 단추(왼쪽 아래의 상호작용 …)를 덮지 않게 그 위에서 끝난다(2026-10-21)
	local cols, cell, gap, pad0 = K.cols, K.cell, K.gap, K.pad
	local w, h = m.w, m.h
	local holder = Stage.place(Stage.ui, "TouchChooser", "tl", K.x, K.top, w, h)
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
	local scroll = Ui.scroll(panel, 0, K.titleH, w, m.viewH, m.contentH, K.bar)
	scroll.Name = "List"
	scroll.ZIndex = 2
	for i, item in list do
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		local x, y = pad0 + col * (cell + gap), row * m.rowH
		local slot = Ui.slot(scroll, x, y, cell)
		slot.frame.ZIndex = 2
		local now = selected and state.slots[selected] == item.what
		slot:setOn(now == true)
		if Quick.act(item.what) then
			-- 점프 · 상호작용(2026-10-21): 그림 대신 글 — 고르면 고른 단추와 자리를 바꾼다(빼거나 덮지는 못한다)
			Ui.text(slot.frame, item.name, 0, math.floor(cell / 2) - 6, cell, { align = "center", outline = true, z = 3 })
		else
			local pic = Ui.pic(slot.frame, Quick.pic(item.what), math.floor((cell - PIC) / 2), math.floor((cell - PIC) / 2))
			pic.ZIndex = 2
		end
		local placed = Quick.find(state.slots, item.what) ~= nil
		Ui.text(scroll, item.name, x - 3, y + cell + 2, cell + 6, { align = "center", color = if placed then C.accent else C.text, outline = true, lines = 2 }) -- 이미 어느 단추에 놓여 있는 것은 민트 · 긴 이름(「목도리 달토끼」)은 두 줄
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
	-- 점프 · 상호작용을 누르고 있었으면 놓는다(배치를 시작하는 순간 눌린 채 남지 않게)
	for _, b in slotButtons do
		local f = b.actFinger
		if f then
			b.actFinger, b.down = nil, false
			if f.kind == "jump" then
				Input.release("jump")
			else
				opts.onAct(false)
			end
		end
	end
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
-- 단추의 자리(게임 도트) — 큰 화면(태블릿)에서는 줄여 구석 쪽으로(Layout.touchRect · 2026-10-23). k는 build가 정한다
local K_NOW = 1
local function rectOf(t): (number, number, number, number)
	return Layout.touchRect(t, K_NOW, VIEW_W, VIEW_H)
end

local function makeButton(t)
	local rx, ry, rw, rh = rectOf(t)
	local size = px(rw)
	local frame = Instance.new("Frame")
	frame.Name = "T" .. t.no
	frame.Position = UDim2.fromOffset(px(rx), px(ry))
	frame.Size = UDim2.fromOffset(px(rw), px(rh))
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
	-- 점프 · 상호작용이 놓였을 때의 글(2026-10-21): 큰 단추는 본문 글씨(전의 「점프」 단추와 같다) · 작은 단추는 작은 글씨
	b.act = Ui.text(b.mid, "", -40, if k == 2 or t.kind == "big" then -7 else -6, 80, { font = if t.kind == "big" then "body" else nil, align = "center", outline = true, z = 6 })
	b.act:show(false)
	slotButtons[t.slot] = b

	local i = t.slot
	-- 점프 · 상호작용을 누른 손가락(떼면 놓는다 — 아래 b.release)
	b.release = function(input: InputObject)
		local f = b.actFinger
		if f and sameFinger(input, f.input) then
			b.actFinger = nil
			b.down = false
			paintButton(b)
			if f.kind == "jump" then
				Input.release("jump")
			else
				opts.onAct(false)
			end
		end
	end
	b.hit.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		local what = state.slots[i]
		local act = Quick.act(what)
		if act and not Touch.arranging and not state.pick then
			-- 점프 · 상호작용: 그 단추가 하던 일 그대로(누르고 있는 동안 — 점프는 2단 점프 · 하단 점프, 상호작용은 줍기를 이어서)
			if b.actFinger then
				return
			end
			b.actFinger = { input = input, kind = act }
			b.down = true
			paintButton(b)
			if act == "jump" then
				Input.press("jump")
			else
				opts.onAct(true)
			end
			return
		end
		if Touch.arranging then
			-- 배치 중: 누르면 그 칸을 고르고, 끌면 자리를 바꾼다
			selected = i
			if drag and drag.ghost then
				drag.ghost:Destroy() -- 끄는 중에 다른 단추를 또 눌렀다(다른 손가락): 앞의 끌기를 그만두고 그 그림을 거둔다 — 덮어쓰면 그림이 화면에 남았다(2026-10-23)
			end
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

-- 칸이 아닌 단추: 「메뉴」뿐이다(점프 · 상호작용은 2026-10-21부터 칸 단추에 놓이는 것 — 「단추 배치」에서 끌어 옮긴다)
local function makeAct(t)
	local b = makeButton(t)
	if t.act == "menu" then
		b.label = Ui.text(b.mid, "메뉴", -40, -7, 80, { font = "body", align = "center", outline = true })
		local dot = Ui.box(b.mid, math.floor(t.w / 2) - 8, -math.floor(t.h / 2) + 2, 6, 6, Ui.COLOR.ink)
		Ui.box(dot, 1, 1, 4, 4, Ui.COLOR.gold)
		dot.Name = "Dot"
		dot.ZIndex = 12
		dot.Visible = false
		menuDot = dot
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
		if t.act == "menu" then
			opts.onMenu()
		end
	end)
	b.release = function(input: InputObject)
		if finger and sameFinger(input, finger) then
			finger = nil
			b.down = false
			paintButton(b)
		end
	end
	return b
end

-- 조이스틱: 바깥 원(자리는 그대로) + 가운데 손잡이(손가락을 따라 원 안에서 움직인다)
local function makePad(t)
	local rx, ry, rw = rectOf(t)
	local size = px(rw)
	local base = Instance.new("Frame")
	base.Name = "Pad"
	base.Position = UDim2.fromOffset(px(rx), px(ry))
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
		-- 걷기 시작하는 만큼(2026-10-27 사용자 "모바일에서 버튼 민감도가 너무 높다는데" — 반지름의 20% → 35%: 엄지를 얹거나 조금 흔들려도 걷지 않게 · 아래 · 위 42% → 55%. 값은 제가 정한 것)
		local left, right, down, up = Touch.dirs(v.X, v.Y, radius)
		set("left", left)
		set("right", right)
		set("down", down) -- 아래로 민 채 「점프」를 누르면 발판에서 내려온다(하단 점프 — sim/physics.luau) · 걸으면서도 된다(대각선 아래)
		-- 위로 밀면 사다리만 오른다("climb" — 문 · 주민은 그대로 상호작용 단추: 사용자 2026-10-08 「위로 미는 것은 아무 일도 없다」).
		--  2026-10-17: 사다리를 넣으며 폰의 오르기를 빠뜨렸었다(조이스틱으로는 사다리를 탈 수 없었다)
		set("climb", up)
	end
	pad.stop = function()
		pad.finger = nil
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.BackgroundTransparency = 0.45
		for _, a in { "left", "right", "down", "climb" } do
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
	pad = nil
	K_NOW = Layout.touchK(Stage.scale, UI.touch) -- 폰 1 · 큰 화면은 1보다 작게
	-- 예전 배치(2026-10-28 — 게임 설정 창 「폰 단추 배치」 · data/ui.generated.luau의 touchOld): 그 칸들만 10-27 전의 자리로
	local old = {}
	if Touch.legacy and UI.touchOld then
		for _, o in UI.touchOld.slots do
			old[o.slot] = o
		end
	end
	for _, t0 in UI.touch do
		local t = t0
		local o = t0.slot and old[t0.slot]
		if o then
			t = table.clone(t0)
			t.x, t.y = o.x, o.y
		end
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
-- 폰 단추 배치(2026-10-28): true = 예전 배치(상호작용 단추가 조이스틱 바로 옆) — 바뀌면 단추를 다시 짓는다
Touch.legacy = false
function Touch.setLegacy(on: boolean)
	on = on == true
	if Touch.legacy == on then
		return
	end
	Touch.legacy = on
	if root then
		build()
	end
end
-- 칸들에 놓인 것(PC의 퀵슬롯과 같은 열두 칸)
-- 단추 하나의 틀(튜토리얼의 꿈이 그 단추를 반짝이게 한다 — 2026-10-14): name = "pad"(조이스틱) · "jump" · "interact" · "menu" · "slot"(arg = 칸 번호)
function Touch.frameOf(name: string, arg: number?): GuiObject?
	if name == "pad" then
		return if pad then pad.frame else nil
	end
	for _, b in buttons do
		-- 점프 · 상호작용은 그것이 놓인 칸 단추(2026-10-21 — 「단추 배치」에서 옮겼으면 옮긴 자리)
		local holds = b.t.slot and Quick.act(state.slots[b.t.slot])
		if (name == "slot" and b.t.slot == arg) or (name ~= "slot" and (b.t.act == name or holds == name)) then
			return b.frame
		end
	end
	return nil
end

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

-- 단추들의 모습을 다시 그린다(켜 둔 사출기가 바뀌었을 때 — Hud.active)
function Touch.refresh()
	paintAll()
end

-- 놓을 것의 목록이 바뀌었다(가진 펫 · 탈것을 서버에서 받았다 — 2026-10-21): 배치 중이면 고른 칸 그대로 목록만 다시
function Touch.rechoose()
	if Touch.arranging then
		openChooser()
	end
end

-- 가방이 바뀌었다: 소비 아이템이 놓인 단추의 숫자를 다시 적는다
function Touch.setCounts()
	for i, b in slotButtons do
		local what = state.slots[i]
		if what and Quick.item(what) then
			paintSlot(b)
		end
	end
end

-- 상호작용 단추가 할 일: "pickup"(떨어진 물건) · "portal"(문) · "npc"(주민) · nil(가까이에 아무것도 없다)
-- 「메뉴」 단추의 점(PC의 「메뉴」 단추와 같은 노란 점 — 받을 출석 칸 · 업적 보상이 있을 때)
function Touch.markMenu(on: boolean)
	if menuDot then
		menuDot.Visible = on
	end
end

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
		-- 단추를 새로 짓기 전에 누르고 있던 것을 놓는다(2026-10-18 검토: 화면을 돌리면 막대 · 뛰기 · 상호작용이 눌린 채 남아 캐릭터가 계속 걸었다)
		if pad and pad.stop then
			pad.stop()
		end
		Input.release("jump")
		opts.onAct(false)
		for i in held do
			Input.release("tslot:" .. i)
		end
		table.clear(held)
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
				local dragged = state.slots[d.from]
				if Quick.act(dragged) then
					Ui.text(ghost, Quick.ACTS[dragged].name, -16, math.floor((PIC + 8) / 2) - 6, PIC + 40, { align = "center", outline = true, z = 3 }) -- 점프 · 상호작용: 글(2026-10-21)
				else
					Ui.pic(ghost, Quick.pic(dragged), 4, 4).ZIndex = 2
				end
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
		-- 끄던 손가락을 이미 뗐는데(뗀 알림을 놓쳤다 — 스크롤 틀이 손가락을 가져가는 때 등) 끌기가 남아 있으면 놓지 않고 거둔다(2026-10-23 — 잔상)
		if drag and lifted(drag.input) then
			local d = drag
			drag = nil
			if d.ghost then
				d.ghost:Destroy()
			end
		end
		-- 같은 까닭으로 눌린 채 남은 것: 조이스틱 · 누르고 있는 칸 단추 · 점프 · 상호작용(뗀 알림을 놓치면 캐릭터가 계속 걷거나 스킬을 계속 썼다)
		if pad and pad.finger and lifted(pad.finger) then
			pad.stop()
		end
		for i, h in held do
			if lifted(h.input) then
				held[i] = nil
				Input.release("tslot:" .. i)
				local sb = slotButtons[i]
				if sb then
					sb.down = false
					paintButton(sb)
				end
			end
		end
		for _, b in buttons do
			if b.actFinger and b.release and lifted(b.actFinger.input) then
				b.release(b.actFinger.input)
			end
		end
		for i, h in held do
			h.t += dt
			if h.t >= h.next then
				h.next = h.t + HOLD_NEXT
				local what = state.slots[i]
				if what and not Quick.item(what) and opts.repeats(what) then
					Input.release("tslot:" .. i)
					Input.press("tslot:" .. i)
				end
			end
		end
	end)

	local function decide()
		local on = Stage.touchLike() -- (2026-10-23: 마지막으로 쓴 입력 — PreferredInput. 전에는 키보드가 붙은 태블릿에서 꺼졌다)
		local was = Touch.on
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
		if was ~= on and Stage.refit then
			Stage.refit() -- 터치 화면이면 게임 화면을 꽉 차게(Stage.scalesFor) — 배율이 바뀌면 단추를 새로 짓는다(onResize)
		end
	end
	Stage.gui:GetAttributeChangedSignal("Touch"):Connect(decide)
	pcall(function()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(decide) -- 터치 ↔ 키보드 · 마우스로 바꿔 쥐었다
	end)
	decide()
end

return Touch
