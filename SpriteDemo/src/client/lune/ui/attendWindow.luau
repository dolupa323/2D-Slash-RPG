-- 출석 창 — 메뉴 → 「출석」 · 그날 처음 들어오면 한 번 뜬다(2026-10-15 · 사용자: "출석보상, 업적 만들어야합니다" — 판 · 보상은 제 제안).
--  모양은 공방 시험 탭의 js/lune/ui/paint.js(paintAttend)와 같다: 머리글(「10월 출석 12/28」 · 「자정에 하루」) · 칸 7 x 4(날 · 보상 그림 · 수 · 큰 칸 ★ · 받은 칸 「받음」) ·
--   받을 것 한 줄(받을 칸들을 더한 것 — 칸을 누르면 그 칸의 것) · 안내와 「받기」.
--  받는 것은 서버가 한다(ctx.attendDo → Attend "claim"). 셈은 shared/lune/sim/attend.luau. 화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Attend = require(lune.sim.attend)
local Gift = require(lune.sim.gift)
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.ATTEND
local D = Attend.DATA
local W = Attend.WORDS

local AttendWindow = {}

function AttendWindow.size(): (number, number)
	return S.w, S.top + S.rows * S.cell + (S.rows - 1) * S.gap + S.lineY + S.rowH + Ui.M.button
end

-- 칸의 그림 · 수(물약은 그 캐릭터의 레벨의 것)
function AttendWindow.cell(r, level: number): (string, string)
	local icon, n = Gift.icon(r)
	if icon == "potion_s" then
		local g = Items.goods(Items.potionFor(level).id)
		icon = if g and g.icon then g.icon else icon
	end
	return icon, Format.short(n)
end

-- 받을 것 한 줄: 이름표 · 보여 줄 칸 · 받을 칸들을 말하는가(공방의 attendLabel과 같다)
function AttendWindow.label(v, sel: number?): (string, number, boolean)
	local ready = v.n - v.got
	local show = sel or (if ready > 0 then v.got + 1 else math.min(v.days, v.n + 1))
	local label = if sel then Format.fill(W.day, { n = show }) elseif ready > 0 then Format.fill(W.ready, { n = ready }) elseif v.n < v.days then W.next else W.none
	return label, show, ready > 0 and sel == nil
end

-- 받을 칸들을 더한 꾸러미
function AttendWindow.sum(v)
	local out = {}
	for k = v.got + 1, v.n do
		for key, n in D.rewards[k] do
			out[key] = (out[key] or 0) + n
		end
	end
	return out
end

function AttendWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local sel: number? = nil
	local note, noteTone = nil, nil
	local head = Ui.text(body, "", 0, 2, w, { color = C.gold })
	Ui.text(body, W.reset, 0, 2, w, { align = "right", color = C.dim })
	local cells = {}
	for k = 1, D.days do
		local col, row = (k - 1) % S.cols, math.floor((k - 1) / S.cols)
		local c = {}
		c.slot = Ui.slot(body, col * (S.cell + S.gap), S.top + row * (S.cell + S.gap), S.cell)
		c.slot.frame.Name = "Day" .. k
		c.day = Ui.text(c.slot.frame, tostring(k), 3, 2, S.cell - 6, { color = C.dim })
		if table.find(D.big, k) then
			Ui.smallIcon(c.slot.frame, "star", S.cell - 14, 1)
		end
		c.pic = Ui.pic(c.slot.frame, nil, math.floor((S.cell - 24) / 2), 11)
		c.num = Ui.text(c.slot.frame, "", 3, S.cell - 12, S.cell - 6, { align = "right", outline = true })
		c.taken = Ui.text(c.slot.frame, W.taken, 0, math.floor((S.cell - Ui.M.small) / 2) + 3, S.cell, { align = "center", color = C.green })
		Ui.hit(c.slot.frame).Activated:Connect(function()
			sel = if sel == k then nil else k -- 칸을 누르면 그 칸의 보상이 아래에(한 번 더 누르면 받을 것으로)
			view.refresh()
		end)
		cells[k] = c
	end
	local y = S.top + S.rows * S.cell + (S.rows - 1) * S.gap + S.lineY
	Ui.line(body, 0, y - 4, w)
	local label = Ui.text(body, "", 0, y + 2, w, { color = C.dim })
	local gift = Ui.text(body, "", 0, y + 2, w, { color = C.gold })
	local by = y + S.rowH
	local noteText = Ui.text(body, W.note, 0, by + math.floor((Ui.M.button - Ui.M.small) / 2), w - S.btnW - 8, { color = C.dim })
	local take = Ui.button(body, W.take, w - S.btnW, by, S.btnW, function()
		local res = ctx.attendDo("claim")
		if res and res.view then
			if res.why then
				note, noteTone = Format.fill(W.full, { n = res.view.n - res.view.got }), C.red
			elseif (res.got or 0) > 0 then
				note, noteTone = W.got, C.green
			end
			sel = nil
		end
		view.refresh()
	end, { main = true })
	take.frame.Name = "Take"

	function view.refresh()
		local v = ctx.attend()
		local me = ctx.me and ctx.me()
		local level = if me then me.level else 1
		if not v then
			head:set("")
			take:setEnabled(false)
			return
		end
		head:set(Format.fill(W.head, { month = v.month, n = v.n, days = v.days }))
		for k, c in cells do
			local taken, ready = k <= v.got, k > v.got and k <= v.n
			c.slot:setOn(ready or sel == k)
			c.day:color(if ready then C.accent else C.dim)
			c.taken:show(taken)
			c.pic.Visible = not taken
			c.num:show(not taken)
			if not taken then
				local icon, num = AttendWindow.cell(D.rewards[k], level)
				Ui.setPic(c.pic, icon)
				c.num:set(num)
			end
		end
		local text, show, hot = AttendWindow.label(v, sel)
		label:set(text)
		label:color(if hot then C.accent else C.dim)
		local lw = Ui.measure(text)
		gift.label:SetMaxWidth(math.max(10, w - lw - 8))
		gift:move(lw + 8, y + 2)
		gift:set(if hot then Gift.text(AttendWindow.sum(v), W) else Gift.text(D.rewards[show] or {}, W))
		noteText:set(note or W.note)
		noteText:color(noteTone or C.dim)
		local ready = v.n - v.got
		take:setEnabled(ready > 0)
	end
	if ctx.attendFetch then
		ctx.attendFetch() -- 열 때 서버의 지금 판을 받아 온다(받으면 다시 그린다)
	end
	view.refresh()
	return view
end

return AttendWindow
