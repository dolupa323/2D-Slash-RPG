-- 장비 창 — 13부위. 왼쪽에 무기와 방어구 넷(칸 옆에 「Lv.10 +2」), 오른쪽 위에 장신구 여덟(네 칸 x 두 줄). 오른쪽 아래에 능력치 표.
--  능력치 표(2026-10-14 — 사용자: "장비 탭에 지금 전투력, 방어력만 표기되는데 여기에 현재 스텟, 공격력 등 여러 수치가 다 출력되어야하고 크리티컬 확률, 크리티컬 데미지 이런것도 다 나와야합니다."):
--   공격력 · 전투력 · 최대 체력 · 다섯 능력치 · 방어 · 치명타(확률 · 피해) · 주는 피해 · 최종 피해 · 공격 속도 · 받는 피해 · 이동 속도 · 점프력. 줄과 값의 글은 shared/lune/ui/sheet.luau
--  부위를 누르면 그 장비의 상세가 창 옆의 작은 판에 뜬다(ui/itemDetail.luau) — 「해제」로 가방에 넣고, 대장장이 앞에서는 「강화」로 강화 창에 올린다.
--   사용자 2026-10-08: "장비 탭에서 각각의 장비를 선택하면 그 해당장비가 장비창 옆에 작은모달이 떠서 아이템 스펙이 나와야합니다."
--  같은 부위를 두 번 누르면 해제(가방에서 두 번 누르면 장착인 것과 짝). 화면 오른쪽 · 왼쪽의 옆 판(ui/windows.luau). 칸의 크기는 장비 그림의 크기(화면 틀의 배율)를 따른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local ItemInfo = require(lune.ui.itemInfo)
local Sheet = require(lune.ui.sheet) -- 능력치 표의 칸 · 값의 글
local Layout = require(lune.ui.layout) -- 치수(자동 검사가 같은 값을 본다)
local WORDS = require(lune.data["ui.generated"]).words
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local ItemDetail = require(script.Parent.itemDetail)
local Windows = require(script.Parent.windows)

local C = Ui.COLOR
local D = Items.data
local DOUBLE = 0.4 -- 이 안에 같은 칸을 다시 누르면 두 번 누른 것(초)

local EquipWindow = {}
EquipWindow.TEXT_W = Layout.EQUIP.textW -- 부위 이름이나 "Lv.140 +17"이 들어가는 폭
EquipWindow.ACC_COLS = Layout.EQUIP.accCols

-- 속의 짜임: 왼쪽 = 칸 하나 + 글, 오른쪽 = 장신구 네 칸
local function metrics()
	local w, _, rx = Layout.equipBody(Stage.ratio)
	return ItemCell.size(), rx, w
end

function EquipWindow.size(): (number, number)
	local w, h = Layout.equipBody(Stage.ratio)
	return w, h
end

function EquipWindow.build(body: Frame, ctx, w: number, _h: number)
	local ui = ctx.ui
	local S, RX = metrics()
	local nameW = w - RX
	local selected: string? = nil
	local lastClick = { slot = "", t = 0 }
	local view = {}
	local rows = {}
	local left, right = 0, 0
	local function redraw()
		Windows.refresh(ctx.me())
	end
	for _, slot in D.SLOTS do
		local isAcc = slot.kind == "장신구"
		local x, y
		if isAcc then
			x, y = RX + (right % EquipWindow.ACC_COLS) * S, math.floor(right / EquipWindow.ACC_COLS) * S
			right += 1
		else
			x, y = 0, left * (S + 2)
			left += 1
		end
		local cell = ItemCell.new(body, x, y, function(it)
			local now = os.clock()
			local twice = it ~= nil and lastClick.slot == slot.id and now - lastClick.t < DOUBLE
			lastClick = { slot = if twice then "" else slot.id, t = now }
			if twice then
				ctx.send("Item", "unequip", slot.id) -- 두 번 누르기: 해제
				selected = nil
			elseif it then
				selected = slot.id
				ui.detail = "equip"
			else
				selected = nil
			end
			redraw()
		end, S)
		-- 무기 · 방어구는 칸 옆에 한 줄(장신구는 고르면 상세 판에 이름이 뜬다)
		local text = if isAcc then nil else Ui.text(body, "", x + S + 8, y + math.floor((S - 10) / 2), EquipWindow.TEXT_W, { color = C.dim })
		rows[slot.id] = { cell = cell, text = text, slot = slot }
	end
	local ny = 2 * S + 12
	Ui.line(body, RX, ny, nameW)
	-- 능력치 표: 칸마다 이름(왼쪽 · 흐리게 — 능력치는 주 노랑 · 부 민트 · 안 쓰는 것 흐림)과 값(오른쪽)
	local sheet = {}
	for _, cell in Sheet.cells(nameW) do
		local label = Ui.text(body, Sheet.name(cell.id), RX + cell.x, ny + cell.y, cell.w, { color = C.dim })
		local value = Ui.text(body, "", RX + cell.x, ny + cell.y, cell.w, { color = if cell.id == "power" then C.gold else C.text, align = "right" })
		sheet[cell.id] = { label = label, value = value }
	end
	local TONE = { main = C.gold, sub = C.accent, none = C.dim, hp = C.text }

	-- 고른 부위의 상세 판(창 옆)
	local function detail(bag, me)
		if ui.detail ~= "equip" then
			selected = nil -- 다른 창에서 골랐다
		end
		local it = if selected then bag.equip[selected] else nil
		if not it then
			selected = nil
			ItemDetail.hide("equip")
			return
		end
		local slotId = selected
		local buttons = { { text = WORDS.unequip, main = true, onClick = function()
			ctx.send("Item", "unequip", slotId)
			selected = nil
			redraw()
		end } }
		if ui.service == "forge" then
			table.insert(buttons, { text = WORDS.toForge, onClick = function()
				ctx.toForge(it.id)
			end })
		end
		ItemDetail.show("equip", {
			key = table.concat({ "equip", it.id, it.q, it.star, tostring(it.broken), me.level, ui.service or "-" }, "|"),
			info = ItemInfo.gear(it, me, nil, true),
			item = it,
			buttons = buttons,
			onClose = function()
				selected = nil
				redraw()
			end,
		})
	end

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		detail(bag, me)
		for id, row in rows do
			local it = bag.equip[id]
			row.cell:set(it, { selected = id == selected })
			if row.text then
				if it then
					row.text:set(if it.star > 0 then ("Lv.%d +%d"):format(it.stage, it.star) else ("Lv.%d"):format(it.stage))
					row.text:color(ItemCell.color(it))
				else
					row.text:set(row.slot.name)
					row.text:color(C.dim)
				end
			end
		end
		local values = Sheet.values(me)
		for id, cell in sheet do
			cell.value:set(values[id] or "")
			local tone = Sheet.tone(me.class, id)
			if tone then
				cell.label:color(TONE[tone])
			end
		end
	end

	function view.destroy()
		ItemDetail.hide("equip")
		if ui.detail == "equip" then
			ui.detail = nil
		end
	end
	return view
end

return EquipWindow
