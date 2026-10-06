-- 강화 창 — 대장장이에게 말을 걸면 가방과 나란히 뜬다(공방 「기본 · UI」 탭의 「강화의 흐름」).
--  가방이나 장비 창에서 「올리기」로 장비를 올리면: 지금 별과 다음 별 · 성공 / 실패 / 파괴 % · 실패하면 그대로인지 떨어지는지 · 드는 달가루와 정수.
--  둘째로 올린 장비는 「재료」다: 같은 부위면 별 옮기기(재료의 별을 하나 낮춰 옮기고 재료는 사라진다), 올린 것이 부서졌고 같은 장비면 되살리기.
--  확률과 값은 shared/lune/sim/items.luau의 enhanceInfo(공방의 강화 표). 결과는 서버가 정한다(Item → ItemDone).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Kit = require(script.Parent.kit)
local ItemCell = require(script.Parent.itemCell)

local C = Kit.COLOR

local ForgeWindow = { height = 152 }
ForgeWindow.RESULT = { ok = { "붙었다!", C.green }, fail = { "실패 — 별은 그대로다", C.dim }, drop = { "실패 — 한 단계 떨어졌다", C.red }, boom = { "부서졌다 — 흔적이 남았다", C.red } }

local function pct(v: number): string
	return if v == math.floor(v) then ("%d%%"):format(v) else ("%.1f%%"):format(v)
end
ForgeWindow.pct = pct

-- 강화 창에 적는 줄들(화면 없이도 셈할 수 있게 따로 뺐다): { 별, 확률, 실패하면, 달가루, 정수 }
function ForgeWindow.lines(it, info, bag): { string }
	if not info.can then
		return { if info.why == "상한" then ("별 %d — 이 장비는 여기까지다"):format(it.star) else "부서졌다 — 같은 장비를 재료로 올린다", "", "", "", "" }
	end
	local odds = if info.sure then "반드시 성공" else ("성공 %s · 실패 %s"):format(pct(info.ok), pct(info.fail))
	if info.boom > 0 then
		odds ..= (" · 파괴 %s"):format(pct(info.boom))
	end
	return {
		("별 %d → %d"):format(it.star, it.star + 1),
		odds,
		if info.sure then "두 번 떨어졌다 — 이번은 반드시 붙는다" elseif info.drops then "실패하면 한 단계 떨어진다" else "실패해도 별은 그대로다",
		("달가루 %s (가진 것 %s)"):format(Format.short(info.dust), Format.short(bag.dust)),
		if info.essence > 0 then ("정수 %d (가진 것 %s)"):format(info.essence, Format.short(bag.essence)) else "",
	}
end

function ForgeWindow.build(body: Frame, ctx, w: number, _h: number)
	local ui = ctx.ui
	local guard = false
	local view = {}
	local function find(id: number?)
		local bag = ctx.bag()
		if not bag or not id then
			return nil
		end
		for _, it in bag.gear do
			if it.id == id then
				return it
			end
		end
		for _, it in bag.equip do
			if it.id == id then
				return it
			end
		end
		return nil
	end

	local cell = ItemCell.new(body, 2, 0, function()
		ui.forgeTarget, ui.forgeMat, ui.forgeResult = nil, nil, nil
		view.refresh()
	end)
	local name = Kit.text(body, "", 26, 0, w - 30, { lines = 2 })
	local lines = {}
	for i = 1, 5 do
		lines[i] = Kit.text(body, "", 4, 24 + (i - 1) * 11, w - 8, { color = if i == 1 then C.yellow else C.white })
	end
	local go = Kit.button(body, "강화", 2, 81, 82, 14, function()
		if ui.forgeTarget then
			ctx.send("Item", "enhance", ui.forgeTarget, guard)
		end
	end, { kind = "orange" })
	local shield = Kit.button(body, "", 88, 81, 84, 14, function()
		guard = not guard
		view.refresh()
	end)
	local result = Kit.text(body, "", 4, 98, w - 8)
	Kit.box(body, 2, 110, w - 4, 1, C.edgeDim)
	local matCell = ItemCell.new(body, 2, 112, function()
		ui.forgeMat = nil
		view.refresh()
	end)
	local matName = Kit.text(body, "", 26, 110, w - 30, { color = C.dim })
	local move = Kit.button(body, "", 26, 120, 70, 13, function()
		local it, mat = find(ui.forgeTarget), find(ui.forgeMat)
		if it and mat then
			ctx.send("Item", if it.broken then "restore" else "transfer", if it.broken then it.id else mat.id, if it.broken then mat.id else it.id)
			ui.forgeMat = nil
		end
	end)
	Kit.button(body, "상점", w - 46, 120, 44, 13, function()
		ctx.openService("smithShop")
	end)

	function view.refresh()
		local bag = ctx.bag()
		if not bag then
			return
		end
		local it, mat = find(ui.forgeTarget), find(ui.forgeMat)
		if not it then
			ui.forgeTarget = nil
		end
		if not mat then
			ui.forgeMat = nil
		end
		cell:set(it)
		matCell:set(mat)
		if not it then
			name:set("가방이나 장비 창에서 장비를 고르고 올리기")
			name:color(C.dim)
			for _, line in lines do
				line:set("")
			end
			go:setEnabled(false)
			shield.frame.Visible = false
			result:set("")
			matName:set("")
			move.frame.Visible = false
			return
		end
		name:set(ItemCell.label(it))
		name:color(ItemCell.color(it))
		local info = Items.enhanceInfo(it, guard)
		for i, text in ForgeWindow.lines(it, info, bag) do
			lines[i]:set(text)
		end
		go:setEnabled(info.can and bag.dust >= info.dust and bag.essence >= info.essence)
		shield.frame.Visible = info.can and info.guard == true
		shield:setText(if guard then "파괴 막기 켬" else "파괴 막기 끔")
		shield:setKind(if guard then "orange" else "blue")
		local last = ui.forgeResult
		local show = last and ForgeWindow.RESULT[last]
		result:set(if show then show[1] else "")
		if show then
			result:color(show[2])
		end
		-- 재료
		if mat then
			matName:set(ItemCell.label(mat))
			local canRestore = it.broken and not mat.broken and Items.same(it, mat)
			local canMove = not it.broken and not mat.broken and mat.slot == it.slot and Items.transfer(mat, it) > it.star
			move.frame.Visible = true
			move:setText(if it.broken then "되살리기" else "별 옮기기")
			move:setEnabled(canRestore or canMove)
		else
			matName:set(if it.broken then "같은 장비를 하나 더 올린다" else "재료: 별을 옮겨 올 장비")
			move.frame.Visible = false
		end
	end
	return view
end

-- 장비를 올린다: 처음 것은 강화할 장비, 그다음 것은 재료
function ForgeWindow.put(ui, id: number)
	if not ui.forgeTarget or ui.forgeTarget == id then
		ui.forgeTarget = id
	else
		ui.forgeMat = id
	end
	ui.forgeResult = nil
end

return ForgeWindow
