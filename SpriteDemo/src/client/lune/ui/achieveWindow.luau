-- 업적 창 — 메뉴 → 「업적」(2026-10-15 · 사용자: "출석보상, 업적 만들어야합니다" — 목록 · 점수 · 등급 · 보상은 제 제안).
--  모양은 공방 시험 탭의 js/lune/ui/paint.js(paintAchieve)와 같다: 「업적 점수 n」 · 등급 · 다음 등급까지의 띠 · 탭 여섯 ·
--   줄마다 이름과 등급의 꼬리표 / 할 일 / 진행 띠와 n/N · 오른쪽에 「받기」(해냈으면) · 「받음」 · 보상(작은 그림 + 수) · 아래 「모두 받기」.
--  줄의 차례: 받을 것 → 하는 중 → 받은 것. 앞 단계를 해내지 않은 단계는 보이지 않고, 숨김 업적은 해낼 때까지 「???」.
--  받는 것은 서버가 한다(ctx.achDo → Achieve "claim" · "all"). 셈은 shared/lune/sim/achieve.luau. 화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Achieve = require(lune.sim.achieve)
local Gift = require(lune.sim.gift)
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.ACHIEVE
local D = Achieve.DATA
local W = Achieve.WORDS

local AchieveWindow = {}
AchieveWindow.ORDER = { [2] = 0, [1] = 1, [3] = 2 } -- 받을 것 · 하는 중 · 받은 것
local TONE = { normal = "dim", rare = "accent", epic = "gold" }

-- 한 탭에 업적이 가장 많은 수(줄을 그만큼 만들어 둔다)
local MOST = 0
do
	local per = {}
	for _, def in D.list do
		per[def.tab] = (per[def.tab] or 0) + 1
		MOST = math.max(MOST, per[def.tab])
	end
end

function AchieveWindow.size(): (number, number)
	return S.w, S.listY + S.rows * S.row + S.footY + Ui.M.button
end

-- 그 탭의 줄들(보이는 것만 · 받을 것 → 하는 중 → 받은 것 · 같은 것끼리는 목록의 차례)
function AchieveWindow.rows(view, tab: string)
	local out = {}
	for _, def in D.list do
		local r = view and view.rows[def.id]
		if def.tab == tab and r and r.st > 0 then
			table.insert(out, { def = def, have = r.have, need = r.need, st = r.st })
		end
	end
	table.sort(out, function(a, b)
		local oa, ob = AchieveWindow.ORDER[a.st], AchieveWindow.ORDER[b.st]
		if oa ~= ob then
			return oa < ob
		end
		return a.def.order < b.def.order
	end)
	return out
end

-- 점수 → 등급의 이름 · 다음 등급까지(남은 점수) · 띠의 비율
function AchieveWindow.gradeOf(score: number): (string?, string?, number, number)
	local now, nextOne = Achieve.grade(score)
	local prev = 0
	for _, g in D.grades do
		if g.name == now then
			prev = g.from
		end
	end
	if not nextOne then
		return now, nil, 0, 1
	end
	return now, nextOne.name, nextOne.from - score, (score - prev) / (nextOne.from - prev)
end

-- 보상의 작은 그림들 { { icon, num } } (둘까지 · 물약은 그 캐릭터의 레벨의 것)
function AchieveWindow.rewards(r, level: number)
	local out = {}
	for _, k in { "dust", "money", "scroll", "potion" } do
		if (r[k] or 0) > 0 and #out < 2 then
			local icon = if k == "money" then "coin" elseif k == "potion" then "potion_s" else k
			if k == "potion" then
				local g = Items.goods(Items.potionFor(level).id)
				icon = if g and g.icon then g.icon else icon
			end
			table.insert(out, { icon = icon, num = Format.short(r[k]) })
		end
	end
	return out
end

function AchieveWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local tab = 1
	local note, noteTone = nil, nil
	local waiting = false -- 답을 기다리는 중(두 번 눌러 두 번 가지 않게 — 2026-10-18 검토: 둘째의 「이미 받았다」가 첫째의 성공 글을 덮었다)
	local score = Ui.text(body, "", 0, 0, w, { font = "body", color = C.gold })
	local grade = Ui.text(body, "", 0, 2, w, { align = "right", color = C.accent })
	local gradeBar = Ui.bar(body, 0, S.barY, w, S.barH, C.accent, C.panel2)
	local nextText = Ui.text(body, "", 0, S.barY + S.barH + 3, w, { align = "right", color = C.dim })
	local tabs = {}
	local tx = 0
	local list: ScrollingFrame
	for i, t in D.tabs do
		local item = Ui.tab(body, t[2], tx, S.tabY, function()
			if tab ~= i then
				tab = i
				note = nil
				list.CanvasPosition = Vector2.zero -- 다른 탭은 맨 위부터
				view.refresh()
			end
		end)
		item.frame.Name = "Tab_" .. t[1]
		tabs[i] = item
		tx += item.width + 14
	end
	Ui.line(body, 0, S.listY - 6, w)
	-- 줄들: 스크롤 틀(rows개가 보이고 나머지는 민다 — 마우스 휠 · 손가락으로 밀기). 막대는 판의 오른쪽 여백에
	list = Ui.scroll(body, 0, S.listY, w + 10, S.rows * S.row, MOST * S.row, S.scrollW)
	list.Name = "List"
	local textW = w - S.sideW - 8
	local rowsUi = {}
	for i = 1, MOST do
		local f = Ui.group(list, 0, (i - 1) * S.row, w, S.row, "Row" .. i)
		local r = { frame = f }
		r.name = Ui.text(f, "", 0, 2, textW - 40, { font = "body" })
		r.tag = Ui.text(f, "", 0, 4, 60, {})
		r.text = Ui.text(f, "", 0, 19, textW, { color = C.dim })
		r.bar = Ui.bar(f, 0, 34, S.barW, 4, C.accent, C.panel2)
		r.count = Ui.text(f, "", S.barW + 6, 31, 80, { color = C.dim })
		r.taken = Ui.text(f, W.taken, 0, 8, w, { align = "right", color = C.green })
		r.take = Ui.button(f, W.take, w - S.btnW, 2, S.btnW, function()
			if r.id and not waiting then
				waiting = true
				local res = ctx.achDo("claim", r.id)
				waiting = false
				note, noteTone = nil, nil
				if res and res.why then
					note, noteTone = res.why, C.red
				elseif res and (res.got or 0) > 0 then
					note, noteTone = W.got, C.green
				end
				view.refresh()
			end
		end, { main = true, h = 22 })
		r.take.frame.Name = "Take"
		r.gifts = {}
		for g = 1, 2 do
			r.gifts[g] = { icon = Ui.smallIcon(f, "coin", 0, 27), num = Ui.text(f, "", 0, 31, 60, { color = C.gold }) }
		end
		rowsUi[i] = r
	end
	local fy = S.listY + S.rows * S.row + S.footY
	Ui.line(body, 0, fy - 5, w)
	local all = Ui.button(body, W.takeAll, 0, fy, S.allW, function()
		if waiting then
			return
		end
		waiting = true
		local res = ctx.achDo("all")
		waiting = false
		note, noteTone = nil, nil
		if res and res.why then
			note, noteTone = W.full, C.red
		elseif res and (res.got or 0) > 0 then
			note, noteTone = W.got, C.green
		end
		view.refresh()
	end, { main = true })
	all.frame.Name = "TakeAll"
	local noteText = Ui.text(body, "", S.allW + 10, fy + math.floor((Ui.M.button - Ui.M.small) / 2), w - S.allW - 10, { color = C.dim })

	function view.refresh()
		local v = ctx.ach()
		local me = ctx.me and ctx.me()
		local level = if me then me.level else 1
		local points = if v then v.score else 0
		score:set(Format.fill(W.score, { n = points }))
		local now, nextName, left, ratio = AchieveWindow.gradeOf(points)
		grade:set(if now then Format.fill(W.grade, { name = now }) else W.noGrade)
		grade:color(if now then C.accent else C.dim)
		gradeBar:set(ratio)
		nextText:set(if nextName then Format.fill(W.next, { name = nextName, n = left }) else W.top)
		for i, t in tabs do
			t:setOn(i == tab)
		end
		local rows = AchieveWindow.rows(v, D.tabs[tab][1])
		local ready = 0
		if v then
			for _, r in v.rows do
				if r.st == 2 then
					ready += 1
				end
			end
		end
		for i, ru in rowsUi do
			local r = rows[i]
			ru.frame.Visible = r ~= nil
			ru.id = r and r.def.id
			if r then
				local hide = r.def.hidden and r.st < 2
				ru.name:set(if hide then W.hidden else r.def.name)
				ru.name:color(if r.st == 3 then C.dim else C.text)
				local nw = Ui.measure(if hide then W.hidden else r.def.name, "body")
				ru.tag:set(D.gradeName[r.def.grade])
				ru.tag:color(C[TONE[r.def.grade]] or C.dim)
				ru.tag:move(nw + 6, 4)
				ru.text:set(if hide then W.hiddenText else r.def.text)
				ru.bar:set(if r.need > 0 then r.have / r.need else 0)
				ru.bar:setColor(if r.st >= 2 then C.green else C.accent)
				ru.count:set(("%s/%s"):format(Format.comma(r.have), Format.comma(r.need)))
				ru.count:color(if r.st >= 2 then C.green else C.dim)
				ru.take.frame.Visible = r.st == 2
				ru.taken:show(r.st == 3)
				-- 보상: 오른쪽 끝에서부터(그림 + 수)
				local gifts = AchieveWindow.rewards(r.def.reward, level)
				local ix = w
				for g = 2, 1, -1 do
					local gu = ru.gifts[g]
					local it = gifts[g]
					gu.icon.Visible = it ~= nil
					gu.num:show(it ~= nil)
					if it then
						gu.num:set(it.num)
						gu.num:color(if r.st == 3 then C.dim else C.gold)
						local tw = Ui.measure(it.num)
						gu.num:move(ix - tw, 31)
						ix -= tw + 2
						Ui.setWorldIcon(gu.icon, it.icon)
						gu.icon.Position = UDim2.fromOffset(ix - 16, 27)
						ix -= 22
					end
				end
			end
		end
		list.CanvasSize = UDim2.fromOffset(0, math.max(S.rows, #rows) * S.row)
		list.ScrollingEnabled = #rows > S.rows
		list.ScrollBarThickness = if #rows > S.rows then S.scrollW else 0
		all:setEnabled(ready > 0)
		noteText:set(note or "")
		noteText:color(noteTone or C.dim)
	end
	if ctx.achFetch then
		ctx.achFetch() -- 열 때 서버의 지금 것을 받아 온다(받으면 다시 그린다)
	end
	view.refresh()
	return view
end

return AchieveWindow
