-- 늘 보이는 화면(HUD) — 상태바(레벨 · 이름 · 체력) · 경험치 바 · 스킬 칸(물약 + 기술) · 메뉴 단추. 미니맵은 minimap.luau.
--  아직 없는 칸: 보스 체력(L6) · 버프와 직업 게이지(L7) — 쓸 때가 되면 생긴다(공방의 화면 규칙).
--  자리는 공방 「기본 · UI」 탭의 화면 배치(data/ui.generated.luau)를 그대로 쓰고, 모양은 메이플풍 부품(ui/kit.luau)이다.
--  좌표는 게임 화면(384x216)의 도트. 글씨는 제 칸을 넘지 않게 폭을 준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Kit = require(script.Parent.ui.kit)

local C = Kit.COLOR
local CELL, PITCH = Kit.CELL, Kit.PITCH
local COLS, ROWS = 6, 2 -- 스킬 칸: 두 줄 x 여섯
-- 메뉴 단추의 그림(창의 이름표 → 아이콘)
local MENU_ICON = { bag = "menu_bag", equip = "menu_equip", stat = "menu_stat", skill = "menu_skill", quest = "menu_quest", party = "menu_party", more = "menu_gear" }

local Hud = {}
Hud.COLS, Hud.ROWS = COLS, ROWS
Hud.MENU_MAX = 6 -- 메뉴 단추는 여섯까지 놓인다(나머지는 「메뉴」 단추 안에)
Hud.LEVEL_W = Kit.measure("Lv.150") -- 레벨 글의 폭(만렙까지 들어가게)

-- 상태바 안의 자리(테스트 14가 같은 값으로 글이 들어가는지 본다)
function Hud.layout()
	local v = UI.hud.vitals
	local nameX = 5 + Hud.LEVEL_W + 4
	return { nameX = nameX, nameW = v.w - 5 - nameX, hpX = 4, hpY = 13, hpW = v.w - 8, hpH = 11, hpLabelW = Kit.measure("HP") + 6, hpTextW = v.w - 8 - 2 * (Kit.measure("HP") + 6) }
end

function Hud.init()
	local root = Stage.group(Stage.view, "Hud", 100)
	Hud.root = root

	-- 상태바: 윗줄에 레벨과 이름, 아랫줄에 체력 바와 숫자
	local v = UI.hud.vitals
	local L = Hud.layout()
	local bar = Kit.group(root, v.x, v.y, v.w, v.h)
	bar.Name = "Vitals"
	Kit.part(bar, "frame", 0, 0, v.w, v.h)
	Hud.level = Kit.text(bar, "Lv.1", 5, 3, Hud.LEVEL_W, { color = C.yellow })
	Hud.name = Kit.text(bar, "", L.nameX, 3, L.nameW)
	Hud.hp = Kit.bar(bar, L.hpX, L.hpY, L.hpW, L.hpH, "hp")
	Kit.text(Hud.hp.frame, "HP", 4, 1, L.hpLabelW, { shadow = C.hpLo })
	Hud.hpText = Kit.text(Hud.hp.frame, "", L.hpLabelW, 1, L.hpTextW, { align = "center", shadow = C.hpLo })
	Hud.hpTextWidth = L.hpTextW

	-- 경험치 바: 화면 폭. 열 칸으로 나눈 눈금(한 칸이 10%)과 가운데의 % 숫자
	local x = UI.hud.xp
	Hud.xp = Kit.bar(root, x.x, x.y, x.w, x.h, "exp")
	Hud.xp.frame.Name = "Xp"
	for i = 1, 9 do
		local tick = Kit.box(Hud.xp.frame, math.floor(x.w * i / 10), 1, 1, x.h - 2, C.line)
		tick.ZIndex = 2
	end
	Hud.xpText = Kit.micro(Hud.xp.frame, "EXP 0.00%", 0, 1, C.white)
	Hud.xpWidth = x.w

	-- 스킬 칸: 움푹한 칸에 그림 · 키 이름(왼쪽 위) · 개수(오른쪽 아래) · 다시 쓰기까지 남은 시간(어두운 덮개와 초)
	local s = UI.hud.skills
	Hud.skillRoot = Kit.group(root, s.x, s.y, s.w, s.h)
	Hud.skillRoot.Name = "Skills"
	Hud.slots = {}
	for r = 0, ROWS - 1 do
		for c = 0, COLS - 1 do
			local frame = Kit.group(Hud.skillRoot, c * PITCH, r * PITCH, CELL, CELL)
			frame.Name = "Slot" .. (r * COLS + c + 1)
			Kit.part(frame, "socketCell", 0, 0)
			local icon = Kit.icon(frame, nil, 1, 1)
			local veil = Kit.box(frame, 1, 1, CELL - 2, CELL - 2, C.line, 0.35)
			veil.Name = "Veil"
			veil.ZIndex = 3
			veil.Visible = false
			local slot = { frame = frame, icon = icon, veil = veil, id = nil :: string?, shown = nil :: string? }
			slot.key = Kit.micro(frame, "", 2, 2, C.white)
			slot.count = Kit.micro(frame, "", 2, CELL - 7, C.white)
			slot.wait = Kit.micro(frame, "", 2, 8, C.yellow)
			slot.wait.frame.ZIndex = 7
			table.insert(Hud.slots, slot)
		end
	end
	Hud.byId = {} -- [기술 id] = 칸
	Hud.potionSlot = Hud.slots[1]
	Kit.setIcon(Hud.potionSlot.icon, "slot_potion")

	Hud.menuRoot = Kit.group(root, UI.hud.menu.x, UI.hud.menu.y, UI.hud.menu.w, UI.hud.menu.h)
	Hud.menuRoot.Name = "Menu"
	return Hud
end

-- 칸의 오른쪽 아래에 적는 수
local function setCount(slot, text: string)
	slot.count:set(text)
	slot.count:move(CELL - 2 - Kit.microWidth(text), CELL - 7)
end

-- 스킬 칸: 첫 칸은 물약, 그 옆으로 기술(차례대로). list = { { id = "ax_slam", key = "Q", name = "대지 강타" }, … }
function Hud.setSkills(list)
	table.clear(Hud.byId)
	for i = 2, #Hud.slots do
		local slot, sk = Hud.slots[i], list[i - 1]
		slot.id = if sk then sk.id else nil
		Kit.setIcon(slot.icon, if sk then "skill_" .. sk.id else nil)
		slot.key:set(if sk then Format.keyMicro(sk.key) else "")
		slot.veil.Visible = false
		slot.wait:set("")
		slot.shown = nil
		if sk then
			Hud.byId[sk.id] = slot
		end
	end
end

-- 기술을 다시 쓰기까지 남은 시간(초). total = 그 기술의 다시 쓰기 시간. 화면마다 불러도 된다(바뀔 때만 고쳐 그린다)
function Hud.setCooldown(id: string, remain: number, total: number)
	local slot = Hud.byId[id]
	if not slot then
		return
	end
	local rows = if remain > 0 and total > 0 then math.clamp(math.ceil((CELL - 2) * remain / total), 1, CELL - 2) else 0
	local text = if remain >= 1 then tostring(math.ceil(remain)) else ""
	local key = rows .. ":" .. text
	if slot.shown == key then
		return
	end
	slot.shown = key
	slot.veil.Visible = rows > 0
	slot.veil.Position = UDim2.fromOffset(1, 1 + (CELL - 2 - rows))
	slot.veil.Size = UDim2.fromOffset(CELL - 2, rows)
	slot.wait:set(text)
	slot.wait:move(math.floor((CELL - Kit.microWidth(text)) / 2), 8)
end

-- 메뉴 단추: 창마다 그림 단추 하나(여는 키가 귀퉁이에). 누르면 그 창이 열린다. list = { { id, name, key } … } — 여섯까지
function Hud.setMenu(list, onClick: (string) -> ())
	for _, old in Hud.menu or {} do
		old.frame:Destroy()
	end
	Hud.menu = {}
	for i, item in list do
		if i > Hud.MENU_MAX then
			break -- 칸을 넘는 것은 그리지 않는다
		end
		local frame = Kit.group(Hud.menuRoot, (i - 1) * PITCH, 0, CELL, CELL)
		frame.Name = "Menu_" .. item.id
		Kit.part(frame, "socketCell", 0, 0)
		Kit.icon(frame, MENU_ICON[item.id] or "menu_gear", 1, 1)
		local key = Format.keyMicro(item.key or "")
		if key ~= "" then
			Kit.micro(frame, key, CELL - 2 - Kit.microWidth(key), CELL - 7, C.yellow)
		end
		-- 눈에 띄게 하는 표시: 오른쪽 위의 노란 점(찍을 점수가 남았다) · 반짝임(새로 생겼다)
		local dot = Kit.box(frame, CELL - 6, 1, 5, 5, C.line)
		Kit.box(dot, 1, 1, 3, 3, C.yellow)
		dot.ZIndex = 7
		dot.Visible = false
		local flash = Kit.box(frame, 1, 1, CELL - 2, CELL - 2, C.white, 0.35)
		flash.ZIndex = 8
		flash.Visible = false
		Kit.hit(frame).Activated:Connect(function()
			onClick(item.id)
		end)
		frame.Visible = not Hud.touch
		Hud.menu[item.id] = { frame = frame, dot = dot, flash = flash, mark = false }
	end
end

-- 물약 칸에 적는 키 이름(키를 바꾸면 따라 바뀐다)
function Hud.setPotionKey(name: string)
	Hud.potionSlot.key:set(Format.keyMicro(name))
end

-- 스마트폰 단추가 켜지면 키가 적힌 칸(스킬 칸 · 메뉴 단추)은 숨긴다 — 그 자리에 손가락 단추가 온다
function Hud.setTouch(on: boolean)
	Hud.touch = on
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

-- 상태바에 적는 내 이름
function Hud.setName(name: string)
	Hud.name:set(name)
end

-- 경험치의 % 글(소수 둘째 자리까지 — 메이플처럼)
function Hud.xpLabel(xp: number, need: number): string
	return ("EXP %.2f%%"):format(math.clamp(xp / math.max(1, need), 0, 1) * 100)
end

-- 내 상태(서버가 보낸 것)를 그린다
function Hud.setSelf(me)
	local level = "Lv." .. me.level
	Hud.level:set(level)
	Hud.name:move(5 + Kit.measure(level) + 5, 3) -- 이름은 레벨 글 바로 뒤에
	Hud.hpText:set(Format.hp(me.hp, me.maxHp, Hud.hpTextWidth, Kit.measure))
	Hud.hp:set(me.hp / math.max(1, me.maxHp))
	Hud.xp:set(me.xp / math.max(1, me.need))
	local label = Hud.xpLabel(me.xp, me.need)
	Hud.xpText:set(label)
	Hud.xpText:move(math.floor((Hud.xpWidth - Kit.microWidth(label)) / 2), 1)
	setCount(Hud.potionSlot, tostring(me.potions))
	Hud.markMenu("stat", me.ap > 0)
	Hud.markMenu("skill", me.sp > 0)
end

return Hud
