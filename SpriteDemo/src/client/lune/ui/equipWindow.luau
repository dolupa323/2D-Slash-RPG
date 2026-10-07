-- 장비 창 — 13부위. 왼쪽에 무기와 방어구 넷(칸 옆에 「Lv.10 +2」), 오른쪽 위에 장신구 여덟(네 칸 x 두 줄). 오른쪽 아래에 고른 부위의 이름과 단추, 전투력과 방어.
--  부위를 고르면 이름이 뜨고 「벗기」로 가방에 넣는다. 대장장이 앞에서는 「올리기」로 강화 창에 올린다.
--  화면 오른쪽의 옆 판(ui/windows.luau). 칸의 크기는 장비 그림의 크기(화면 틀의 배율)를 따른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout) -- 치수(자동 검사가 같은 값을 본다)
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)

local C = Ui.COLOR
local D = Items.data

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
	local view = {}
	local rows = {}
	local left, right = 0, 0
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
		local cell = ItemCell.new(body, x, y, function()
			selected = slot.id
			view.refresh()
		end, S)
		-- 무기 · 방어구는 칸 옆에 한 줄(장신구는 고르면 아래에 이름이 뜬다)
		local text = if isAcc then nil else Ui.text(body, "", x + S + 8, y + math.floor((S - 10) / 2), EquipWindow.TEXT_W, { color = C.dim })
		rows[slot.id] = { cell = cell, text = text, slot = slot }
	end
	local ny = 2 * S + 12
	local name = Ui.text(body, "", RX, ny, nameW, { font = "body", lines = 2, line = 16 })
	local bw = math.floor((nameW - 8) / 2)
	local off = Ui.button(body, "벗기", RX, ny + 40, bw, function()
		if selected then
			ctx.send("Item", "unequip", selected)
		end
	end)
	local up = Ui.button(body, "올리기", RX + bw + 8, ny + 40, bw, function()
		local bag = ctx.bag()
		local it = bag and selected and bag.equip[selected]
		if it then
			ctx.toForge(it.id)
		end
	end)
	Ui.line(body, RX, ny + 76, nameW)
	local power = Ui.text(body, "", RX, ny + 86, nameW, { color = C.gold })
	local guard = Ui.text(body, "", RX, ny + 102, nameW)

	function view.refresh()
		local bag, me = ctx.bag(), ctx.me()
		if not bag or not me then
			return
		end
		local worn = {}
		for id, row in rows do
			local it = bag.equip[id]
			row.cell:set(it, { selected = id == selected })
			if it then
				table.insert(worn, it)
			end
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
		local it = selected and bag.equip[selected]
		if it then
			name:set(ItemCell.label(it))
			name:color(ItemCell.color(it))
		else
			name:set(if selected then rows[selected].slot.name .. " — 비었다" else "부위를 고른다")
			name:color(C.dim)
		end
		off:setEnabled(it ~= nil)
		up.frame.Visible = ui.service == "forge"
		up:setEnabled(it ~= nil)
		power:set(("전투력 %s"):format(Format.short(me.power)))
		guard:set(("방어 %d%%"):format(math.floor(Items.cut(worn, me.level) + 0.5)))
	end
	return view
end

return EquipWindow
