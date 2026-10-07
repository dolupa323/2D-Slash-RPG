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
local SLOT = K.slot -- 스킬 칸 한 변
local KEY_UP = K.keyUp -- 칸 위의 키 딱지가 차지하는 높이
local COLS, ROWS = K.cols, K.rows -- 스킬 칸: 두 줄 x 여섯
local PIC = M.pic
-- 메뉴 단추의 그림(창의 이름표 → 그림)
local MENU_PIC = { bag = "menu_bag", equip = "menu_equip", stat = "menu_stat", skill = "menu_skill", quest = "menu_quest", party = "menu_party", more = "menu_gear" }

local Hud = {}
Hud.COLS, Hud.ROWS = COLS, ROWS
Hud.MENU_MAX = MN.max -- 메뉴 단추는 여섯까지 놓인다(나머지는 「메뉴」 단추 안에)

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
	Hud.hpText = Ui.text(box, "", V.hpPad, L.hpY + math.floor((V.hpH - M.small) / 2), L.hpTextW, { align = "center" })
	Hud.hpText.label.Frame.ZIndex = 6
	Hud.hpTextWidth = L.hpTextW
	Hud.xp = Ui.bar(box, 0, L.xpY, V.barW, V.xpH, C.accent)
	Hud.xp.frame.Name = "Xp"
	Hud.xpText = Ui.text(box, "0.00%", L.xpTextX, L.xpY - 3, L.xpTextW, { color = C.dim, outline = true })

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
		local slot = { frame = cell.frame, cell = cell, back = cell.frame:FindFirstChild("uSlot") :: ImageLabel, pic = pic, veil = veil, pad = pad, what = false :: any, id = nil :: string?, shown = nil :: string?, keyName = "" }
		-- 퀵슬롯은 자리가 늘 같다(여섯 x 두 줄 — 칸마다 키 하나)
		local px, py = Layout.slotPlace(i, COLS * ROWS)
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
		slot.key = Ui.keycap(cell.frame, "", math.floor(SLOT / 2), -KEY_UP)
		slot.count = Ui.text(cell.frame, "", 0, SLOT - 11, SLOT - 2, { align = "right", outline = true, z = 6 })
		slot.wait = Ui.text(cell.frame, "", 0, math.floor((SLOT - M.small) / 2), SLOT, { align = "center", outline = true, z = 7 })
		table.insert(Hud.slots, slot)
	end
	Hud.byId = {} -- [기술 id] = 칸
	Hud.potionSlot = nil -- 물약이 놓인 칸
	-- 놓을 스킬을 골랐을 때 칸들 위에 뜨는 안내
	Hud.pickHint = Ui.text(Hud.skillRoot, Quick.DATA.words.pick, 0, -16, s.w, { align = "center", color = C.accent, outline = true })
	Hud.pickHint:show(false)

	Hud.menuRoot = Stage.placeRect(root, "Menu", UI.hud.menu)
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
Hud.onSlotClick = nil :: ((number) -> ())? -- 칸을 눌렀다
Hud.onSlotPress = nil :: ((number, InputObject) -> ())? -- 칸을 누르기 시작했다(끌기)
Hud.edit, Hud.pick, Hud.pulse, Hud.hot, Hud.top = false, false, false, nil :: number?, false

-- 칸들의 모습을 다시 그린다: 보이는 줄 · 빈 칸의 흐림 · 반짝임(놓을 스킬을 골랐을 때) · 마우스가 올라간 칸
function Hud.paintSlots()
	for i, slot in Hud.slots do
		slot.frame.Visible = true
		local on = (Hud.pick and Hud.pulse) or Hud.hot == i
		slot.cell:setOn(on)
		slot.back.ImageTransparency = if slot.what or on then 0 else 1 - Quick.DATA.emptyAlpha
		slot.key:color(if slot.what then C.text else C.dim)
	end
	Hud.pickHint:show(Hud.pick)
end

-- 칸마다 놓인 것을 그린다. list[i] = { what = "potion" · 스킬의 이름표 · false, key = 그 칸의 키 이름 }
function Hud.setSlots(list)
	table.clear(Hud.byId)
	Hud.potionSlot = nil
	Hud.top = false
	for i, slot in Hud.slots do
		local it = list[i]
		local what = if it then it.what or false else false
		slot.what = what
		slot.id = if what and what ~= Quick.POTION then what else nil
		slot.keyName = if it then Format.keyShort(it.key) else ""
		Ui.setPic(slot.pic, if what then Quick.pic(what) else nil)
		slot.key:set(slot.keyName)
		slot.veil.Visible = false
		slot.wait:set("")
		slot.shown = nil
		slot.count:set(if what == Quick.POTION and Hud.potions then tostring(Hud.potions) else "")
		if slot.id then
			Hud.byId[slot.id] = slot
		end
		if what == Quick.POTION then
			Hud.potionSlot = slot
		end
		if i > COLS and what then
			Hud.top = true
		end
	end
	Hud.paintSlots()
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
	slot.shown = key
	slot.veil.Visible = rows > 0
	slot.veil.Position = UDim2.fromOffset(slot.pad, slot.pad + (PIC - rows))
	slot.veil.Size = UDim2.fromOffset(PIC, rows)
	slot.wait:set(text)
end

-- 메뉴 단추: 창마다 그림 단추 하나, 그 아래에 이름(그림만으로는 무엇을 여는지 모른다 — 사용자 2026-10-07 "무슨기능인지 인지가 하나도안됩니다").
--  누르면 그 창이 열린다. list = { { id, name, key } … } — 여섯까지, 오른쪽 끝에 붙여 놓는다
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
		local frame = Ui.group(Hud.menuRoot, Layout.menuX(i, n), 0, s, r.h, "Menu_" .. item.id)
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
		Hud.menu[item.id] = { frame = frame, cell = cell, label = label, dot = dot, flash = flash, mark = false }
	end
	Hud.setOpen(Hud.openSet or {})
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

-- 스마트폰 단추가 켜지면 키가 적힌 칸(스킬 칸 · 메뉴 단추)은 숨긴다 — 그 자리에 손가락 단추가 온다
--  체력 덩어리는 아래 가운데로 옮긴다(왼쪽 아래에는 이동 패드가 온다 — data/ui.generated.luau의 hudTouch)
function Hud.setTouch(on: boolean)
	Hud.touch = on
	local v = if on and UI.hudTouch.vitals then UI.hudTouch.vitals else UI.hud.vitals
	Hud.vitalsBox.Position = Stage.atPosition(v.at, v.x, v.y)
	Hud.skillRoot.Visible = not on
	for _, item in Hud.menu or {} do
		item.frame.Visible = not on
	end
end

-- 메뉴 단추를 눈에 띄게(찍을 점수가 남았을 때 등)
function Hud.markMenu(id: string, on: boolean)
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
function Hud.setSelf(me)
	local level = "Lv." .. me.level
	Hud.level:set(level)
	Hud.name:move(Ui.measure(level) + V.nameGap, V.nameY) -- 이름은 레벨 글 바로 뒤에
	Hud.name.label:SetMaxWidth(UI.hud.vitals.w - Ui.measure(level) - V.nameGap, 1)
	Hud.hpText:set(Format.hp(me.hp, me.maxHp, Hud.hpTextWidth, Ui.measure))
	Hud.hp:set(me.hp / math.max(1, me.maxHp))
	Hud.xp:set(me.xp / math.max(1, me.need))
	Hud.xpText:set(Hud.xpLabel(me.xp, me.need))
	Hud.potions = me.potions
	if Hud.potionSlot then
		Hud.potionSlot.count:set(tostring(me.potions))
	end
	Hud.markMenu("stat", me.ap > 0)
	Hud.markMenu("skill", me.sp > 0)
end

return Hud
