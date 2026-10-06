-- 장비 창 — 13부위. 왼쪽에 무기와 방어구 넷(칸 옆에 「Lv.10 +2」), 오른쪽 위에 장신구 여덟(네 칸 x 두 줄). 오른쪽 아래에 고른 부위의 이름과 단추, 전투력과 방어.
--  부위를 고르면 이름이 뜨고 「벗기」로 가방에 넣는다. 대장장이 앞에서는 「올리기」로 강화 창에 올린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Kit = require(script.Parent.kit)
local ItemCell = require(script.Parent.itemCell)

local C = Kit.COLOR
local D = Items.data
local S = ItemCell.SIZE
local STEP = S + 1

local EquipWindow = { height = 152 }
EquipWindow.TEXT_W = 58 -- 부위 이름이나 "Lv.140 +17"이 들어가는 폭(테스트 15가 본다)
EquipWindow.NAME_W = 84 -- 고른 장비의 이름(세 줄까지)

function EquipWindow.build(body: Frame, ctx, _w: number, _h: number)
	local ui = ctx.ui
	local selected: string? = nil
	local view = {}
	local rows = {}
	local left, right = 0, 0
	local RX = 88 -- 오른쪽 덩이의 왼쪽 끝
	for _, slot in D.SLOTS do
		local isAcc = slot.kind == "장신구"
		local x, y
		if isAcc then
			x, y = RX + (right % 4) * STEP, 2 + math.floor(right / 4) * STEP
			right += 1
		else
			x, y = 2, 2 + left * STEP
			left += 1
		end
		local cell = ItemCell.new(body, x, y, function()
			selected = slot.id
			view.refresh()
		end)
		-- 무기 · 방어구는 칸 옆에 한 줄(장신구는 고르면 아래에 이름이 뜬다)
		local text = if isAcc then nil else Kit.text(body, "", x + S + 4, y + 5, EquipWindow.TEXT_W, { color = C.dim })
		rows[slot.id] = { cell = cell, text = text, slot = slot }
	end
	local name = Kit.text(body, "", RX, 47, EquipWindow.NAME_W, { lines = 3 })
	local off = Kit.button(body, "벗기", RX, 83, 40, 14, function()
		if selected then
			ctx.send("Item", "unequip", selected)
		end
	end)
	local up = Kit.button(body, "올리기", RX + 43, 83, 41, 14, function()
		local bag = ctx.bag()
		local it = bag and selected and bag.equip[selected]
		if it then
			ctx.toForge(it.id)
		end
	end)
	Kit.box(body, RX, 101, EquipWindow.NAME_W, 1, C.edgeDim)
	local power = Kit.text(body, "", RX, 105, EquipWindow.NAME_W, { color = C.yellow })
	local guard = Kit.text(body, "", RX, 117, EquipWindow.NAME_W)

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
