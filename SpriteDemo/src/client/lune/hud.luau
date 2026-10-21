-- 늘 보이는 화면(HUD) — 왼쪽 아래의 한 덩어리(레벨 · 이름 · 체력 바 · 경험치 줄) · 가운데 아래의 스킬 칸(물약 + 기술) · 오른쪽 아래의 창을 여는 단추.
--  산나비 계열 도트 게임의 방식(사용자 2026-10-07 "훌룡합니다. 하지만 글씨비율은 좀더 작아야합니다. 그리고 미니맵은 없애세요"):
--   늘 보이는 것은 구석에 작게, 판 없이 — 글은 어두운 테두리를 두른 작은 글씨로 게임 화면 위에 바로 적는다. 미니맵은 없다.
--  아직 없는 칸: 보스 체력(L6) · 버프와 직업 게이지(L7) — 쓸 때가 되면 생긴다(공방의 화면 규칙).
--  자리는 공방 「기본 · UI」 탭의 화면 배치(data/ui.generated.luau — 기준 격자 960x540과 붙는 구석)를 그대로 쓰고, 모양은 화면 틀의 부품(ui/ui.luau)이다.
--  글씨는 제 칸을 넘지 않게 폭을 준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout) -- 치수는 한데 모아 둔 것을 쓴다(자동 검사가 같은 값을 본다)
local Quick = require(lune.ui.quick) -- 퀵슬롯의 셈(칸 수 · 놓는 법)
local RunService = game:GetService("RunService")
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local M = Ui.M
local V, K, MN = Layout.VITALS, Layout.SKILLS, Layout.MENU
local HpFx = require(lune.ui.hpFx) -- 체력이 닳고 찰 때의 효과(셈)
local SLOT = K.slot -- 스킬 칸 한 변
local KEY_UP = K.keyUp -- 칸 위의 키 딱지가 차지하는 높이
local COLS, ROWS = K.cols, K.rows -- 스킬 칸: 두 줄 x 여섯
local PIC = M.pic
-- 설명 판(버프 · 경험치 · 퀵슬롯의 설명 — 2026-10-18): 능력치의 설명과 같은 판의 치수 · 제목의 색. 판을 짓는 함수들보다 위에 둔다(퀵슬롯의 설명이 먼저 쓴다)
local TIP = Layout.STAT.tip
local TIPCOLOR = { main = C.gold, sub = C.accent, none = C.dim }
-- 손가락으로 누른 것인가(폰에서는 누를 때도 MouseEnter가 오고 MouseLeave는 오지 않는다 — 그때는 Activated로만 열고 닫는다)
local UIS = game:GetService("UserInputService")
local function touching(): boolean
	return UIS:GetLastInputType() == Enum.UserInputType.Touch
end
-- 메뉴 단추의 그림(창의 이름표 → 그림)
local MENU_PIC = { bag = "menu_bag", equip = "menu_equip", stat = "menu_stat", skill = "menu_skill", quest = "menu_quest", map = "menu_map", auction = "menu_auction", party = "menu_party", cash = "menu_shop", more = "menu_gear" } -- cash = 달빛 상점(2026-10-21 — 단추 줄에)

local Hud = {}
Hud.COLS, Hud.ROWS = COLS, ROWS
Hud.MENU_MAX = MN.max -- 메뉴 단추는 여덟까지 놓인다(나머지는 「메뉴」 단추 안에)

-- 왼쪽 아래 덩어리 안의 자리(shared/lune/ui/layout.luau의 VITALS): 윗줄에 레벨 · 이름, 그 아래 체력 바(숫자는 바 안), 가는 경험치 줄과 %
function Hud.layout()
	local v = UI.hud.vitals
	return { nameY = V.nameY, hpY = V.hpY, hpTextW = V.barW - V.hpPad * 2, xpY = V.xpY, xpTextX = V.barW + V.xpGap, xpTextW = v.w - V.barW - V.xpGap }
end

function Hud.init()
	local root = Stage.group(Stage.ui, "Hud", 100)
	Hud.root = root

	-- 왼쪽 아래 덩어리: 레벨(노랑) · 이름 / 체력 바 — 숫자는 바 안에 / 가는 경험치 줄과 그 옆의 %
	local v = UI.hud.vitals
	local L = Hud.layout()
	local box = Stage.placeRect(root, "Vitals", v)
	Hud.vitalsBox = box
	Hud.level = Ui.text(box, "Lv.1", 0, L.nameY, 60, { color = C.gold, outline = true })
	Hud.name = Ui.text(box, "", 40, L.nameY, v.w - 40, { outline = true })
	Hud.hp = Ui.bar(box, 0, L.hpY, V.barW, V.hpH, C.hp, C.hpDark)
	-- 체력이 닳고 찰 때의 효과(사용자 2026-10-13: "체력 다는거나  회복되는게 잘 보이지않습니다. 효과가 좀 들어가야해요"):
	--  띠 안에 닳은 자리(밝은 색) · 찬 자리(풀빛)를 빨간 띠 아래에 깔고, 번쩍임을 맨 위에 덮는다. 띠 오른쪽 위에 「-23 · +60」이 떠오른다. 셈은 shared/lune/ui/hpFx.luau, 장마다 Hud.step이 그린다
	do
		local F = HpFx.F
		local function hex(h: string): Color3
			return Color3.fromRGB(tonumber(h:sub(2, 3), 16) :: number, tonumber(h:sub(4, 5), 16) :: number, tonumber(h:sub(6, 7), 16) :: number)
		end
		Hud.hpIn = { w = V.barW - 2, h = V.hpH - 2 }
		Hud.hpLag = Ui.box(Hud.hp.frame, 1, 1, 0, Hud.hpIn.h, hex(F.lagColor))
		Hud.hpLag.Name = "Lag"
		Hud.hpGain = Ui.box(Hud.hp.frame, 1, 1, 0, Hud.hpIn.h, hex(F.gainColor))
		Hud.hpGain.Name = "Gain"
		Hud.hp.fill.ZIndex = 2 -- 빨간 띠는 그 둘 위에
		Hud.hpLag.ZIndex, Hud.hpGain.ZIndex = 1, 1
		Hud.hpFlash = Ui.box(Hud.hp.frame, 1, 1, Hud.hpIn.w, Hud.hpIn.h, Color3.new(1, 1, 1))
		Hud.hpFlash.Name = "Flash"
		Hud.hpFlash.ZIndex = 3
		Hud.hpFlash.BackgroundTransparency = 1
		Hud.hpFlashHeal = hex(F.gainColor)
		Hud.hpDelta = Ui.text(box, "", 0, L.hpY - M.small - 1, V.barW, { align = "right", outline = true })
		Hud.hpFx = HpFx.new()
	end
	Hud.hpText = Ui.text(box, "", V.hpPad, L.hpY + math.floor((V.hpH - M.small) / 2), L.hpTextW, { align = "center" })
	Hud.hpText.label.Frame.ZIndex = 6
	Hud.hpTextWidth = L.hpTextW
	Hud.xp = Ui.bar(box, 0, L.xpY, V.barW, V.xpH, C.accent)
	Hud.xp.frame.Name = "Xp"
	Hud.xpText = Ui.text(box, "0.00%", L.xpTextX, L.xpY - 3, L.xpTextW, { color = C.dim, outline = true })
	-- 경험치 줄의 설명(2026-10-18 — 공방 ui.js XPTIP): 줄(과 그 옆의 %)에 마우스를 올리면(폰은 톡 — 한 번 더 톡 하면 닫힘) 덩어리 위에 지금 · 필요한 경험치와 남은 것
	local xpOver = Instance.new("TextButton")
	xpOver.Name = "XpOver"
	xpOver.Text = ""
	xpOver.BackgroundTransparency = 1
	xpOver.Position = UDim2.fromOffset(0, L.xpY - 5)
	xpOver.Size = UDim2.fromOffset(UI.hud.vitals.w, V.xpH + 10)
	xpOver.ZIndex = 8
	xpOver.Parent = box
	xpOver.MouseEnter:Connect(function()
		if not touching() then -- 손가락은 Activated로만(누를 때도 MouseEnter가 온다)
			Hud.showXpTip(box)
		end
	end)
	xpOver.MouseLeave:Connect(function()
		if not touching() then
			Hud.hideXpTip()
		end
	end)
	xpOver.Activated:Connect(function(input)
		if input and input.UserInputType == Enum.UserInputType.Touch and Hud.xpTip then
			Hud.hideXpTip()
		else
			Hud.showXpTip(box)
		end
	end)

	-- 스킬 칸: 어두운 칸에 그림 · 개수(오른쪽 아래) · 다시 쓰기까지 남은 시간(어두운 덮개와 초). 키 이름은 칸 위의 딱지에 적는다(그림을 가리지 않게).
	--  퀵슬롯이다: 칸마다 키가 하나 붙어 있고, 물약 · 스킬을 칸에 놓아 쓴다(아래의 「퀵슬롯」)
	local s = UI.hud.skills
	Hud.skillRoot = Stage.placeRect(root, "Skills", s)
	Hud.slots = {}
	for i = 1, COLS * ROWS do
		local cell = Ui.slot(Hud.skillRoot, 0, 0, SLOT)
		cell.frame.Name = "Slot" .. i
		local pad = math.floor((SLOT - PIC) / 2)
		local pic = Ui.pic(cell.frame, nil, pad, pad)
		local veil = Ui.box(cell.frame, pad, pad, PIC, PIC, C.ink, 0.35)
		veil.Name = "Veil"
		veil.ZIndex = 3
		veil.Visible = false
		-- 다시 쓰기가 끝난 순간 그림이 한 번 하얗게 번쩍인다(2026-10-18 — 시험 탭의 sk.flash와 같다 · Hud.step이 흐리게 한다)
		local ready = Ui.box(cell.frame, pad, pad, PIC, PIC, Color3.new(1, 1, 1), 1)
		ready.Name = "Ready"
		ready.ZIndex = 4
		ready.Visible = false
		local slot = { frame = cell.frame, cell = cell, back = cell.frame:FindFirstChild("uSlot") :: ImageLabel, pic = pic, veil = veil, ready = ready, readyT = 0, pad = pad, what = false :: any, id = nil :: string?, shown = nil :: string?, keyName = "" }
		-- 퀵슬롯은 자리가 늘 같다(여섯 x 두 줄 — 칸마다 키 하나)
		local px, py = Layout.slotPlace(i, COLS * ROWS, Stage.uiW)
		cell.frame.Position = UDim2.fromOffset(px, py)
		-- 누르는 자리: 칸과 그 위의 키 딱지까지. 스킬 창이 열려 있을 때 칸을 누르거나 끌어 고친다(ui/quickEdit.luau가 받는다)
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.Position = UDim2.fromOffset(0, -KEY_UP)
		hit.Size = UDim2.fromOffset(SLOT, SLOT + KEY_UP)
		hit.ZIndex = 9
		hit.Parent = cell.frame
		hit.Activated:Connect(function()
			if Hud.onSlotClick then
				Hud.onSlotClick(i)
			end
		end)
		hit.InputBegan:Connect(function(input)
			if Hud.onSlotPress then
				Hud.onSlotPress(i, input)
			end
		end)
		-- 칸의 설명(2026-10-18 — 메이플처럼 · PC): 마우스를 올리면 칸 위에 그 스킬 · 물건의 이름 · 효과(스킬 창을 열어 고치는 중이거나 끄는 중에는 띄우지 않는다)
		hit.MouseEnter:Connect(function()
			if not touching() then
				Hud.showSlotTip(i)
			end
		end)
		hit.MouseLeave:Connect(function()
			if Hud.slotTipAt == i then
				Hud.hideSlotTip()
			end
		end)
		slot.key = Ui.keycap(cell.frame, "", math.floor(SLOT / 2), -KEY_UP)
		slot.count = Ui.text(cell.frame, "", 0, SLOT - 11, SLOT - 2, { align = "right", outline = true, z = 6 })
		slot.wait = Ui.text(cell.frame, "", 0, math.floor((SLOT - M.small) / 2), SLOT, { align = "center", outline = true, z = 7 })
		table.insert(Hud.slots, slot)
	end
	Hud.byId = {} -- [기술 id] = 칸
	-- 놓을 스킬을 골랐을 때 칸들 위에 뜨는 안내
	Hud.pickHint = Ui.text(Hud.skillRoot, Quick.DATA.words.pick, 0, -16, s.w, { align = "center", color = C.accent, outline = true })
	Hud.pickHint:show(false)

	-- 화면 틀의 격자가 바뀌면 퀵슬롯의 간격도 바뀐다(좁은 격자에서는 칸 사이가 4점 — 2026-10-21 일곱 x 두 줄)
	Stage.onResize(function()
		for i, slot in Hud.slots do
			local px, py = Layout.slotPlace(i, COLS * ROWS, Stage.uiW)
			slot.frame.Position = UDim2.fromOffset(px, py)
		end
	end)
	Hud.menuRoot = Stage.placeRect(root, "Menu", UI.hud.menu)
	-- 화면 틀의 격자가 바뀌면 단추의 간격도 바뀐다(가장 작은 격자에서는 스킬 칸에 닿지 않게 촘촘하다)
	Stage.onResize(Hud.placeMenu)
	-- 버프 자리(오른쪽 위): 켜 둔 사출기 · 직업의 장치(영혼 · 열기 · 수정)가 그림으로, 그 아래에 수(공방 「기본 · UI」 탭의 3번 칸)
	Hud.buffRoot = Stage.placeRect(root, "Buffs", UI.hud.buffs)
	Hud.buffs = {}
	return Hud
end

-- 쓰는 칸이 n개일 때 i째 칸의 자리(스킬 칸 틀 안): 여섯까지는 아랫줄에 가운데로 모으고, 일곱째부터는 윗줄에 같은 식으로.
--  줄마다 위에 키 딱지의 자리(KEY_UP)를 둔다
Hud.KEY_UP = KEY_UP
Hud.slotPlace = Layout.slotPlace

-- ---------- 퀵슬롯 ----------  사용자 2026-10-07: "스킬키를 단축키에 등록하기 쉬워야합니다 … 중앙에 있는 퀵슬롯이랑 스킬 배치랑 쉽게 되어야해요"
--  키는 칸에 붙는다(칸마다 하나). 열두 칸(두 줄)이 늘 보이고 빈 칸은 흐리다(사용자 2026-10-07: "키 위에 edrf12 이 라인도 평소에 보여야합니다").
--  공방의 횡스크롤 시험 탭(js/lune/ui/paint.js의 paintHud)과 같은 그림이다.
Hud.touchSlotAt = nil :: ((Vector2) -> number?)? -- 스마트폰의 칸 단추: 그 자리의 칸 · 고르는 중 · 끌어 올린 칸(touch.luau가 채운다)
Hud.touchPick = nil :: ((boolean) -> ())?
Hud.touchHot = nil :: ((number?) -> ())?
Hud.countOf = nil :: ((string) -> number)? -- 가방에 든 그 소비 아이템의 수(boot.luau가 넣는다 — 칸의 숫자)
Hud.onSlotClick = nil :: ((number) -> ())? -- 칸을 눌렀다
Hud.onSlotPress = nil :: ((number, InputObject) -> ())? -- 칸을 누르기 시작했다(끌기)
Hud.edit, Hud.pick, Hud.pulse, Hud.hot, Hud.top = false, false, false, nil :: number?, false
Hud.active = {} :: { [string]: boolean } -- 켜 둔 것(온오프 사출기): 그 칸에 민트 테두리가 켜진다

-- 칸들의 모습을 다시 그린다: 보이는 줄 · 빈 칸의 흐림 · 반짝임(놓을 스킬을 골랐을 때) · 마우스가 올라간 칸
function Hud.paintSlots()
	for i, slot in Hud.slots do
		slot.frame.Visible = true
		local on = (Hud.pick and Hud.pulse) or Hud.hot == i or (slot.what ~= false and Hud.active[slot.what] == true)
		slot.cell:setOn(on)
		slot.back.ImageTransparency = if slot.what or on then 0 else 1 - Quick.DATA.emptyAlpha
		slot.key:color(if slot.what then C.text else C.dim)
	end
	Hud.pickHint:show(Hud.pick)
end

-- 가방이 바뀌었다: 소비 아이템이 놓인 칸의 숫자를 다시 적는다(다 쓰면 0 — 칸에는 남는다)
function Hud.setCounts()
	for _, slot in Hud.slots do
		if slot.item then
			local n = if Hud.countOf then Hud.countOf(slot.item) else 0
			slot.count:set(tostring(n))
			slot.count:color(if n == 0 then C.red else C.text) -- 다 쓴 소비 아이템은 붉은 0(2026-10-18)
		end
	end
end

-- 칸마다 놓인 것을 그린다. list[i] = { what = 스킬 · 소비 아이템의 이름표 · false, key = 그 칸의 키 이름 }
function Hud.setSlots(list)
	table.clear(Hud.byId)
	Hud.top = false
	for i, slot in Hud.slots do
		local it = list[i]
		local what = if it then it.what or false else false
		slot.what = what
		local goods = if what then Quick.item(what) else nil
		slot.id = if what and not goods then what else nil -- 스킬(다시 쓰기까지의 시간이 덮인다)
		slot.item = if goods then what else nil -- 소비 아이템(가방에 든 수가 적힌다)
		slot.keyName = if it then Format.keyShort(it.key) else ""
		Ui.setPic(slot.pic, if what then Quick.pic(what) else nil)
		slot.key:set(slot.keyName)
		slot.veil.Visible = false
		slot.wait:set("")
		slot.shown = nil
		local n = if slot.item and Hud.countOf then Hud.countOf(slot.item) else 0
		slot.count:set(if slot.item then tostring(n) else "")
		slot.count:color(if slot.item and n == 0 then C.red else C.text)
		if slot.id then
			Hud.byId[slot.id] = slot
		end
		if what and Layout.slotCell(i) == 2 then
			Hud.top = true -- 윗줄에 놓인 것이 있다
		end
	end
	Hud.paintSlots()
end

-- ---------- 칸의 설명(2026-10-18) ----------  글은 boot가 짓는다(Hud.slotTipOf(what) → { kind, title, tag, lines } · 없으면 띄우지 않는다)
Hud.slotTipOf = nil :: ((string) -> any)?
Hud.slotTipAt = nil :: number?
local slotTip: Frame? = nil
function Hud.hideSlotTip()
	if slotTip then
		slotTip:Destroy()
		slotTip = nil
	end
	Hud.slotTipAt = nil
end
function Hud.showSlotTip(i: number)
	Hud.hideSlotTip()
	local slot = Hud.slots[i]
	if not slot or not slot.what or Hud.edit or Hud.pick or Hud.touch or not Hud.slotTipOf then
		return
	end
	local t = Hud.slotTipOf(slot.what)
	if not t then
		return
	end
	local frame, h = Hud.tipPanel(Hud.skillRoot, t, "SlotTip")
	local px = Layout.slotPlace(i, COLS * ROWS, Stage.uiW)
	local w = UI.hud.skills.w
	frame.Position = UDim2.fromOffset(math.clamp(px + math.floor(SLOT / 2) - math.floor(TIP.w / 2), math.min(0, w - TIP.w), math.max(0, w - TIP.w)), -h - 4) -- 퀵슬롯 덩어리 위에(위 칸을 가리지 않게)
	slotTip = frame
	Hud.slotTipAt = i
end

-- 그 칸의 키 이름(딱지에 적힌 것)
function Hud.slotKey(i: number): string
	return Hud.slots[i].keyName
end

-- 고치는 중인가(스킬 창이 열려 있다): 윗줄까지 다 보인다
function Hud.setEdit(on: boolean)
	Hud.edit = on
	Hud.paintSlots()
end

-- 놓을 스킬을 골랐다 · 끌고 있다: 칸들이 반짝인다
local pulseConn: RBXScriptConnection? = nil
function Hud.setPick(on: boolean)
	if Hud.pick == on then
		return
	end
	Hud.pick = on
	if Hud.touchPick then
		Hud.touchPick(on) -- 스마트폰: 칸 단추들이 밝아진다(touch.luau)
	end
	if pulseConn then
		pulseConn:Disconnect()
		pulseConn = nil
	end
	if on then
		local half = Quick.DATA.blink / 2
		Hud.pulse = true
		pulseConn = RunService.Heartbeat:Connect(function()
			local now = math.floor(os.clock() / half) % 2 == 0
			if now ~= Hud.pulse then
				Hud.pulse = now
				Hud.paintSlots()
			end
		end)
	end
	Hud.paintSlots()
end

-- 마우스가 올라간 칸(끌고 있을 때)
function Hud.setHot(i: number?)
	if Hud.hot ~= i then
		Hud.hot = i
		if Hud.touchHot then
			Hud.touchHot(i)
		end
		Hud.paintSlots()
	end
end

-- 화면의 그 자리(입력의 자리)에 있는 칸. 키 딱지까지 그 칸으로 친다
function Hud.slotAt(at: Vector2): number?
	if Hud.touch and Hud.touchSlotAt then
		return Hud.touchSlotAt(at) -- 스마트폰: 화면의 칸 단추가 PC의 칸과 같은 것이다(touch.luau)
	end
	for i, slot in Hud.slots do
		if slot.frame.Visible and Hud.skillRoot.Visible then
			local p, size = slot.frame.AbsolutePosition, slot.frame.AbsoluteSize
			local up = size.Y * KEY_UP / SLOT
			if at.X >= p.X and at.X < p.X + size.X and at.Y >= p.Y - up and at.Y < p.Y + size.Y then
				return i
			end
		end
	end
	return nil
end

-- 기술을 다시 쓰기까지 남은 시간(초). total = 그 기술의 다시 쓰기 시간. 화면마다 불러도 된다(바뀔 때만 고쳐 그린다)
function Hud.setCooldown(id: string, remain: number, total: number)
	local slot = Hud.byId[id]
	if not slot then
		return
	end
	local rows = if remain > 0 and total > 0 then math.clamp(math.ceil(PIC * remain / total), 1, PIC) else 0
	local text = if remain >= 1 then tostring(math.ceil(remain)) else ""
	local key = rows .. ":" .. text
	if slot.shown == key then
		return
	end
	if slot.veil.Visible and rows == 0 then
		slot.readyT = Hud.READY_T -- 다시 쓰기가 끝났다: 한 번 하얗게
	end
	slot.shown = key
	slot.veil.Visible = rows > 0
	slot.veil.Position = UDim2.fromOffset(slot.pad, slot.pad + (PIC - rows))
	slot.veil.Size = UDim2.fromOffset(PIC, rows)
	slot.wait:set(text)
end

-- 메뉴 단추: 창마다 그림 단추 하나, 그 아래에 이름(그림만으로는 무엇을 여는지 모른다 — 사용자 2026-10-07 "무슨기능인지 인지가 하나도안됩니다").
-- 메뉴 단추들을 지금의 격자에 맞는 간격으로 놓는다
function Hud.placeMenu()
	for _, item in Hud.menu or {} do
		item.frame.Position = UDim2.fromOffset(Layout.menuX(item.i, item.n, Stage.uiW), 0)
	end
end

--  누르면 그 창이 열린다. list = { { id, name, key } … } — 여덟까지, 오른쪽 끝에 붙여 놓는다
function Hud.setMenu(list, onClick: (string) -> ())
	for _, old in Hud.menu or {} do
		old.frame:Destroy()
	end
	Hud.menu = {}
	local r = UI.hud.menu
	local n = math.min(#list, Hud.MENU_MAX)
	local s = MN.slot
	for i, item in list do
		if i > Hud.MENU_MAX then
			break -- 칸을 넘는 것은 그리지 않는다
		end
		local frame = Ui.group(Hud.menuRoot, Layout.menuX(i, n, Stage.uiW), 0, s, r.h, "Menu_" .. item.id)
		local cell = Ui.slot(frame, 0, 0, s)
		Ui.pic(cell.frame, MENU_PIC[item.id] or "menu_gear", math.floor((s - PIC) / 2), math.floor((s - PIC) / 2))
		-- 이름은 칸보다 넓을 수 있다(「퀘스트」) — 칸의 가운데에 맞춰 옆 칸과의 사이까지 쓴다
		local label = Ui.text(frame, Layout.menuLabel(item.id, item.name), -math.floor((MN.labelW - s) / 2), MN.labelY, MN.labelW, { align = "center", outline = true })
		-- 눈에 띄게 하는 표시: 오른쪽 위의 노란 점(찍을 점수가 남았다) · 반짝임(새로 생겼다)
		local dot = Ui.box(frame, s - 5, -1, 6, 6, C.ink)
		Ui.box(dot, 1, 1, 4, 4, C.gold)
		dot.ZIndex = 7
		dot.Visible = false
		local flash = Ui.box(frame, 1, 1, s - 2, s - 2, C.text, 0.4)
		flash.ZIndex = 8
		flash.Visible = false
		local hit = Ui.hit(frame)
		hit.Activated:Connect(function()
			onClick(item.id)
		end)
		frame.Visible = not Hud.touch
		Hud.menu[item.id] = { frame = frame, cell = cell, label = label, dot = dot, flash = flash, mark = false, i = i, n = n }
	end
	Hud.setOpen(Hud.openSet or {})
	for id, on in Hud.marks do -- 단추를 다시 지어도 점은 그대로(가방이 가득 찼다 · 찍을 점수 … — 2026-10-18)
		Hud.markMenu(id, on)
	end
end

-- 열려 있는 창의 단추는 민트(테두리와 이름). set = { [창 id] = true }
function Hud.setOpen(set)
	Hud.openSet = set
	for id, item in Hud.menu or {} do
		local on = set[id] == true
		item.cell:setOn(on)
		item.label:color(if on then C.accent else C.text)
	end
end

-- 켜 둔 것(온오프 사출기)의 이름표들: 그 칸에 테두리가 켜진다
function Hud.setActive(ids: { [string]: boolean })
	Hud.active = ids
	Hud.paintSlots()
end

-- 버프 자리를 그린다. list = { { pic = 그림(화면의 24도트 그림 이름), text = 그림 아래의 글(수 · 없으면 ""), hot = 밝게(달아오름) } … } — 오른쪽 끝부터 왼쪽으로 놓는다
local BUFF_PITCH = PIC + 6
-- ---------- 버프 그림의 설명(2026-10-18 — 공방 ui.js BUFFTIP · 시험 탭의 buffTipOf) ----------
--  그림에 마우스를 올리면(폰은 톡 — 한 번 더 톡 하면 닫힌다) 버프 줄 아래에 능력치의 설명과 같은 판이 뜬다. 글은 boot의 paintBuffs가 칸마다 지어 준다(b.tip = { kind, title, tag, lines }).
--  1초마다 칸을 다시 지어도 보던 칸의 설명은 이어서 뜬다(남은 시간이 바뀐다) — 마우스가 그 칸을 벗어났으면 닫는다
local TIP_DOWN = 31 -- 판의 윗줄(버프 줄의 위에서 — 그림 밑의 남은 시간을 가리지 않게)
Hud.buffList = {}
Hud.tipAt = nil :: number? -- 설명이 떠 있는 칸의 차례
local tipFrame: Frame? = nil
local tipTouch = false -- 손가락으로 연 설명(마우스의 자리로 닫지 않는다)

function Hud.hideBuffTip()
	if tipFrame then
		tipFrame:Destroy()
		tipFrame = nil
	end
	Hud.tipAt = nil
end

-- 설명 판 하나를 parent에 짓는다(능력치의 설명과 같은 판): t = { kind, title, tag, lines }. 돌려주는 것 = 판 · 높이(자리는 부른 쪽이 놓는다)
function Hud.tipPanel(parent: Instance, t, name: string): (Frame, number)
	local color = TIPCOLOR[t.kind] or C.accent
	local inner = TIP.w - TIP.pad * 2
	local frame = Ui.group(parent, 0, 0, TIP.w, 10, name)
	frame.ZIndex = 20
	local back = Ui.part(frame, "uTip", 0, 0, TIP.w, 10)
	local title = Ui.text(frame, t.title, TIP.pad, TIP.pad, inner, { font = "body", color = color })
	if t.tag and t.tag ~= "" then
		local tw = title:size()
		Ui.text(frame, t.tag, TIP.pad + tw + 8, TIP.pad + 2, inner - tw - 8, { color = color })
	end
	local y = TIP.pad + TIP.title
	for k, line in t.lines do
		if line ~= "" then
			local tint = if k > 1 then (if t.kind == "none" then C.dim else C.accent) elseif t.kind == "none" then C.red else C.text
			local label = Ui.text(frame, line, TIP.pad, y, inner, { lines = TIP.lines, line = TIP.line, color = tint })
			local _, lh = label:size()
			y += math.max(1, math.floor(lh / TIP.line + 0.5)) * TIP.line
		end
	end
	local h = y - (TIP.line - M.small) + TIP.pad
	frame.Size = UDim2.fromOffset(TIP.w, h)
	back.Size = UDim2.fromOffset(TIP.w, h)
	return frame, h
end

function Hud.showBuffTip(i: number)
	if tipFrame then
		tipFrame:Destroy()
		tipFrame = nil
	end
	local b = Hud.buffList[i]
	if not b or not b.tip then
		Hud.tipAt = nil
		return
	end
	Hud.tipAt = i
	local frame = Hud.tipPanel(Hud.buffRoot, b.tip, "BuffTip")
	-- 그 그림의 오른쪽 끝에 맞춘다 — 화면 왼쪽 밖으로 나가면 민다
	local left = UI.hud.buffs.w - i * BUFF_PITCH + 6 + PIC - TIP.w
	local rootX = (Hud.buffRoot.AbsolutePosition.X - Stage.ui.AbsolutePosition.X) / Stage.uiScale -- (기준 격자 안의 자리 — 넓은 화면의 검은 띠를 빼고)
	if rootX + left < 4 then
		left = 4 - rootX
	end
	frame.Position = UDim2.fromOffset(left, TIP_DOWN)
	tipFrame = frame
end

-- 마우스가 아직 그 칸 위에 있나(칸을 다시 지은 뒤 — 새 칸에는 MouseEnter가 오지 않을 수 있다)
local function stillOver(frame: GuiObject): boolean
	local at = game:GetService("UserInputService"):GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
	local p, s = frame.AbsolutePosition, frame.AbsoluteSize
	return at.X >= p.X and at.X < p.X + s.X and at.Y >= p.Y and at.Y < p.Y + s.Y
end

function Hud.setBuffs(list)
	local key = {}
	for i, b in list do
		key[i] = b.pic .. ":" .. b.text .. ":" .. tostring(b.hot == true)
	end
	local sig = table.concat(key, "|")
	Hud.buffList = list
	if Hud.buffSig == sig then
		return
	end
	Hud.buffSig = sig
	-- 보던 칸의 설명을 새 글로(그 칸이 없어졌거나 마우스가 벗어났으면 닫는다)
	local function refreshTip()
		local at = Hud.tipAt
		if at then
			local item = Hud.buffs[at]
			if item and (tipTouch or stillOver(item.frame)) then
				Hud.showBuffTip(at)
			else
				Hud.hideBuffTip()
			end
		end
	end
	-- 그림 · 차례 · 강조가 그대로면(1초마다 남은 초만 바뀐다) 칸을 다시 짓지 않고 글만 바꾼다(2026-10-18 검토 — 1초마다 칸마다 7개를 만들고 지웠다)
	local shapeKey = {}
	for i, b in list do
		shapeKey[i] = b.pic .. ":" .. tostring(b.hot == true) .. ":" .. tostring(b.text ~= "")
	end
	local shape = table.concat(shapeKey, "|")
	if Hud.buffShape == shape and #Hud.buffs == #list then
		for i, b in list do
			local item = Hud.buffs[i]
			if item.label and item.text ~= b.text then
				item.label:set(b.text)
				item.text = b.text
			end
		end
		refreshTip()
		return
	end
	Hud.buffShape = shape
	for _, item in Hud.buffs do
		item.frame:Destroy()
	end
	table.clear(Hud.buffs)
	local w = UI.hud.buffs.w
	for i, b in list do
		local frame = Ui.group(Hud.buffRoot, w - i * BUFF_PITCH + 6, 0, PIC, PIC + 14, "Buff" .. i)
		Ui.pic(frame, b.pic, 0, 0)
		if b.hot then
			local edge = Instance.new("UIStroke")
			edge.Color = C.accent
			edge.Thickness = 1
			edge.Parent = frame:FindFirstChild("Pic") or frame
		end
		local label = nil
		if b.text ~= "" then
			label = Ui.text(frame, b.text, -8, PIC + 2, PIC + 16, { align = "center", outline = true, color = if b.hot then C.gold else C.text })
		end
		-- 설명(마우스를 올리면 · 손가락으로 톡)
		local over = Instance.new("TextButton")
		over.Name = "Over"
		over.Text = ""
		over.BackgroundTransparency = 1
		over.Size = UDim2.fromOffset(PIC, PIC + 14)
		over.ZIndex = 8
		over.Parent = frame
		over.MouseEnter:Connect(function()
			if touching() then
				return -- 손가락은 Activated로만
			end
			tipTouch = false
			Hud.showBuffTip(i)
		end)
		over.MouseLeave:Connect(function()
			if Hud.tipAt == i and not tipTouch and not touching() then
				Hud.hideBuffTip()
			end
		end)
		over.Activated:Connect(function(input)
			local touch = input and input.UserInputType == Enum.UserInputType.Touch
			if touch and Hud.tipAt == i then
				Hud.hideBuffTip()
			else
				tipTouch = touch == true
				Hud.showBuffTip(i)
			end
		end)
		Hud.buffs[i] = { frame = frame, label = label, text = b.text }
	end
	refreshTip()
end

-- 스마트폰 단추가 켜지면 키가 적힌 칸(스킬 칸 · 메뉴 단추)은 숨긴다 — 그 자리에 손가락 단추가 온다
--  체력 덩어리는 아래 가운데로 옮긴다(왼쪽 아래에는 이동 패드가 온다 — data/ui.generated.luau의 hudTouch)
function Hud.setTouch(on: boolean)
	Hud.touch = on
	local v = if on and UI.hudTouch.vitals then UI.hudTouch.vitals else UI.hud.vitals
	Hud.vitalsBox.Position = Stage.atPosition(v.at, v.x, v.y)
	-- 버프 자리: 스마트폰에서는 오른쪽 위의 「메뉴」 단추만큼 왼쪽으로
	local bf = if on and UI.hudTouch.buffs then UI.hudTouch.buffs else UI.hud.buffs
	Hud.buffRoot.Position = Stage.atPosition(bf.at, bf.x, bf.y)
	Hud.skillRoot.Visible = not on and not Hud.locked
	for _, item in Hud.menu or {} do
		item.frame.Visible = not on
	end
end

-- 메뉴 단추를 눈에 띄게(찍을 점수가 남았을 때 등)
Hud.marks = {} :: { [string]: boolean } -- 단추마다 점이 켜져 있어야 하는가(단추를 다시 지을 때 되살린다)
function Hud.markMenu(id: string, on: boolean)
	Hud.marks[id] = on
	local item = Hud.menu and Hud.menu[id]
	if item and item.mark ~= on then
		item.mark = on
		item.dot.Visible = on
	end
end

-- 새로 생긴 메뉴 단추는 한 번 반짝인다(공방의 화면 규칙: 쓸 때가 되면 하나씩 생기고, 생길 때 한 번 반짝인다)
function Hud.flashMenu(id: string)
	local item = Hud.menu and Hud.menu[id]
	if not item or item.flashing then
		return
	end
	item.flashing = true
	task.spawn(function()
		for i = 1, 8 do
			if not item.frame.Parent then
				return
			end
			item.flash.Visible = i % 2 == 1
			task.wait(0.14)
		end
		item.flashing = false
		if item.frame.Parent then
			item.flash.Visible = false
		end
	end)
end

-- 왼쪽 아래 덩어리에 적는 내 이름
function Hud.setName(name: string)
	Hud.name:set(name)
end

-- 경험치의 % 글(소수 둘째 자리까지 — 메이플처럼)
function Hud.xpLabel(xp: number, need: number): string
	return ("%.2f%%"):format(math.clamp(xp / math.max(1, need), 0, 1) * 100)
end

-- 내 상태(서버가 보낸 것)를 그린다
-- 스킬 칸을 잠근다: 새 캐릭터는 사제에게 첫 기술을 배운 뒤에 칸이 생긴다(공방 basics.js의 UNLOCK — "스킬 칸: 사당을 나서면")
Hud.locked = false
function Hud.setLocked(on: boolean)
	if Hud.locked ~= on then
		Hud.locked = on
		Hud.skillRoot.Visible = not Hud.touch and not on
	end
end

-- 체력 바를 효과의 상태대로 그린다
function Hud.drawHp()
	local st, I = Hud.hpFx, Hud.hpIn
	if st.fill == nil then
		return
	end
	local function px(v: number): number
		return math.floor(I.w * math.clamp(v, 0, 1) + 0.5)
	end
	Hud.hp:set(st.fill)
	Hud.hpLag.Size = UDim2.fromOffset(if st.lag > st.fill then px(st.lag) else 0, I.h)
	Hud.hpGain.Size = UDim2.fromOffset(if st.gain > st.fill then px(st.gain) else 0, I.h)
	Hud.hpFlash.BackgroundColor3 = if st.kind == "heal" then Hud.hpFlashHeal else Color3.new(1, 1, 1)
	Hud.hpFlash.BackgroundTransparency = 1 - HpFx.F.flashA * st.flash / HpFx.F.flash
	local text, up = HpFx.deltaText(st)
	Hud.hpDelta:set(text or "")
	if text then
		Hud.hpDelta:color(if st.delta > 0 then C.green else C.red)
		Hud.hpDelta:move(0, Hud.layout().hpY - M.small - 1 - up)
	end
end

-- 장마다(boot의 그리는 고리가 부른다): 체력 바의 효과를 흘려보낸다
Hud.READY_T = 0.3 -- 다시 쓰기가 끝난 칸이 하얗게 번쩍이는 시간(초)
function Hud.step(dt: number)
	local st = Hud.hpFx
	if st and not HpFx.idle(st) then
		HpFx.step(st, dt)
		Hud.drawHp()
	end
	for _, slot in Hud.slots or {} do
		if slot.readyT > 0 then
			slot.readyT = math.max(0, slot.readyT - dt)
			slot.ready.Visible = slot.readyT > 0
			slot.ready.BackgroundTransparency = 1 - 0.6 * slot.readyT / Hud.READY_T
		end
	end
end

-- 다른 캐릭터로 들어왔다: 앞 캐릭터의 체력과 견주어 효과가 뜨지 않게 처음으로 돌린다
function Hud.resetHp()
	Hud.hpFx = HpFx.new()
	if Hud.hpDelta then
		Hud.hpDelta:set("")
		Hud.hpFlash.BackgroundTransparency = 1
		Hud.hpLag.Size = UDim2.fromOffset(0, Hud.hpIn.h)
		Hud.hpGain.Size = UDim2.fromOffset(0, Hud.hpIn.h)
	end
end

-- 경험치 줄의 설명: 덩어리(box) 위에 — 지금 / 필요한 경험치(%) · 다음 레벨까지
Hud.xpTip = nil :: Frame?
Hud.lastXp = nil :: { xp: number, need: number, level: number }?
function Hud.hideXpTip()
	if Hud.xpTip then
		Hud.xpTip:Destroy()
		Hud.xpTip = nil
	end
end
function Hud.xpTipText(xp: number, need: number, level: number)
	local W = UI.xpTip
	local pct = ("%.2f"):format(math.clamp(xp / math.max(1, need), 0, 1) * 100)
	return { kind = "main", title = W.title, tag = "Lv." .. level, lines = { Format.fill(W.now, { xp = Format.comma(xp), need = Format.comma(need), pct = pct }), Format.fill(W.left, { n = Format.comma(math.max(0, need - xp)) }) } }
end
function Hud.showXpTip(box: Instance)
	Hud.hideXpTip()
	local x = Hud.lastXp
	if not x then
		return
	end
	local frame, h = Hud.tipPanel(box, Hud.xpTipText(x.xp, x.need, x.level), "XpTip")
	frame.Position = UDim2.fromOffset(0, -h - 6)
	Hud.xpTip = frame
end

function Hud.setSelf(me)
	Hud.lastXp = { xp = me.xp, need = me.need, level = me.level }
	if Hud.xpTip then
		Hud.showXpTip(Hud.xpTip.Parent :: Instance) -- 떠 있는 동안 경험치가 오르면 새 수로
	end
	local level = "Lv." .. me.level
	Hud.level:set(level)
	Hud.name:move(Ui.measure(level) + V.nameGap, V.nameY) -- 이름은 레벨 글 바로 뒤에
	Hud.name.label:SetMaxWidth(UI.hud.vitals.w - Ui.measure(level) - V.nameGap, 1)
	Hud.hpText:set(Format.hp(me.hp, me.maxHp, Hud.hpTextWidth, Ui.measure))
	HpFx.set(Hud.hpFx, math.clamp(me.hp / math.max(1, me.maxHp), 0, 1), me.hp) -- 띠는 Hud.step이 효과와 함께 그린다
	Hud.drawHp()
	Hud.xp:set(me.xp / math.max(1, me.need))
	Hud.xpText:set(Hud.xpLabel(me.xp, me.need))
	Hud.markMenu("stat", me.ap > 0)
	Hud.markMenu("skill", me.sp > 0)
end

return Hud
