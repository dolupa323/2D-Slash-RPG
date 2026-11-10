-- 윤슬 조각의 큐브 창(2026-11-10 사용자 "윤슬조각 돌리는거 왜 비포, 에프터 선택이 없는데? 메이플 큐브 ui 처럼 되어야하는거야").
--  메이플(넥슨 공지 — 잠재능력 재설정: 재설정한 뒤 기존 옵션과 재설정된 옵션 가운데 골라 적용)을 따른다. 장비 상세의 「옵션 재설정」이 연다(arg = 장비 번호).
--  위: 장비 칸 · 이름 · 가진 윤슬 조각 / 가운데: BEFORE(지금 옵션) | AFTER(굴린 옵션 — 없으면 「—」) / 안내 한 줄 /
--  아래 단추: 굴린 것이 없으면 「재설정」(조각 하나) · 굴린 것이 있으면 「BEFORE 유지」 「AFTER 적용」 「한 번 더」(조각 하나 더 — AFTER만 새로).
--  굴린 것은 서버가 쥐고 있다(world.luau의 s.reroll — 고르기 전에는 장비가 바뀌지 않는다 · 닫거나 나가면 BEFORE 그대로). 치수 = 공방 design/ui.js UILAYOUT.cube · 글 = items.js EXTRA.words
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Items = require(lune.sim.items)
local Bag = require(lune.sim.bag)
local ItemInfo = require(lune.ui.itemInfo)
local Format = require(lune.ui.format)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)

local C = Ui.COLOR
local S = UI.layout.cube or { w = 330, h = 214, headH = 40, rowH = 16, colGap = 12, btnW = 96, btnH = 22 }
local EW = Items.EXTRA.words or {}

local CubeWindow = {}

function CubeWindow.size(): (number, number)
	return S.w, S.h
end

function CubeWindow.title(_arg: any): string?
	return EW.cubeTitle
end

-- 가방 · 낀 장비에서 그 번호의 장비
function CubeWindow.find(bag, id: any)
	if not bag or typeof(id) ~= "number" then
		return nil
	end
	for _, it in bag.gear or {} do
		if it and it.id == id then
			return it
		end
	end
	for _, it in bag.equip or {} do
		if it and it.id == id then
			return it
		end
	end
	return nil
end

-- ctx: bag() · send(…) · reroll()(굴려 둔 것 { id, before, after } | nil — boot의 state.reroll)
function CubeWindow.build(body: Frame, ctx, w: number, h: number, arg: any)
	local view = {}
	local holder: Frame? = nil
	view.buttons = {} -- (자동 검사가 본다)
	function view.refresh()
		if holder then
			holder:Destroy()
		end
		holder = Ui.group(body, 0, 0, w, h, "Cube")
		local root = holder :: Frame
		view.buttons = {}
		local bag = ctx.bag and ctx.bag()
		local it = CubeWindow.find(bag, arg)
		if not it then
			Ui.text(root, EW.noTool or "", 0, 0, w, { color = C.dim }) -- (장비가 사라졌다 — 판 · 분해)
			return
		end
		local pend = ctx.reroll and ctx.reroll()
		if pend and pend.id ~= it.id then
			pend = nil -- (다른 장비를 굴려 둔 것 — 이 장비는 새로)
		end
		local have = if bag then Bag.countIn(bag, Items.EXTRA.reroll.id) else 0
		-- 위: 장비 칸 · 이름 · 가진 조각
		local cs = ItemCell.size()
		local cell = ItemCell.new(root, 0, 0, function() end, cs)
		cell:set(it, {})
		Ui.text(root, ItemCell.label(it), cs + 8, 2, w - cs - 8, { color = ItemCell.color(it) })
		Ui.text(root, Format.fill(EW.have or "", { n = have }), cs + 8, 20, w - cs - 8, { color = C.dim })
		-- 가운데: BEFORE | AFTER
		local colW = math.floor((w - S.colGap) / 2)
		local y0 = math.max(S.headH, cs + 6) -- (칸이 크면 그만큼 아래로)
		local function column(x: number, head: string, rows, hot: boolean)
			Ui.text(root, head, x, y0, colW, { font = "body", color = if hot then C.accent else C.text })
			Ui.line(root, x, y0 + 18, colW)
			if #rows == 0 then
				Ui.text(root, EW.none or "—", x, y0 + 24, colW, { color = C.dim })
			end
			for i, r in rows do
				local ry = y0 + 24 + (i - 1) * S.rowH
				Ui.text(root, r[1], x, ry, colW - 50, { color = C.extra or C.text })
				Ui.text(root, r[2], x + colW - 50, ry, 50, { align = "right", color = C.extra or C.text })
			end
		end
		column(0, EW.before or "BEFORE", ItemInfo.exRows(if pend then pend.before else it.ex), false)
		column(colW + S.colGap, EW.after or "AFTER", if pend then ItemInfo.exRows(pend.after) else {}, pend ~= nil)
		-- 안내
		local hintY = y0 + 24 + 3 * S.rowH + 6
		Ui.text(root, EW.cubeHint or "", 0, hintY, w, { lines = 2, color = C.dim })
		-- 단추
		local by = h - S.btnH
		local function button(text: string, x: number, bw: number, fn, on: boolean, main: boolean?)
			local b = Ui.button(root, text, x, by, bw, fn, { h = S.btnH, main = main })
			b:setEnabled(on)
			table.insert(view.buttons, { text = text, b = b, fn = fn, on = on })
			return b
		end
		local canRoll = have > 0 and not it.broken
		if pend then
			local bw = math.floor((w - 12) / 3)
			button(EW.keepBefore or "BEFORE", 0, bw, function()
				ctx.send("Item", "rerollPick", it.id, "before")
			end, true)
			button(EW.useAfter or "AFTER", bw + 6, bw, function()
				ctx.send("Item", "rerollPick", it.id, "after")
			end, true, true)
			button(EW.again or "", (bw + 6) * 2, bw, function()
				ctx.send("Item", "reroll", it.id)
			end, canRoll)
		else
			button(EW.roll or "", math.floor((w - S.btnW) / 2), S.btnW, function()
				ctx.send("Item", "reroll", it.id)
			end, canRoll, true)
		end
	end
	view.refresh()
	return view
end

return CubeWindow
