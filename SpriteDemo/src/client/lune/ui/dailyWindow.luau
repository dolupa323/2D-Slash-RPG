-- 일일 의뢰 창 — 마을의 의뢰 게시판 앞에서 ↑를 누르면 뜬다.
--  사용자 2026-10-13: "일일 퀘스트 필요합니다. 게시판이랑 상호작용해서 일퀘받는거 좋습니다. 근데 좀더 간결하게 해도 될거 같습니다.  5분쯤 걸리게 / 일일 의뢰는 10부터 열죠"
--  머리글(「오늘의 의뢰」 · 「자정에 바뀐다」) 아래에 의뢰마다 한 칸: 맵의 이름(작게) · 「포자 주머니 30마리」 · 오른쪽에 「받는다」 → 「12/30」 → 「낸다」 → 「완료」 · 아래에 진행 띠.
--  그 아래 보상 두 줄: 의뢰 하나(경험치 · [달돈 그림]) · 둘을 다 내면([달가루 그림]) — 내 레벨의 것.
--  받기와 내기는 서버가 정한다(ctx.dailyDo → Daily). 셈은 shared/lune/sim/daily.luau, 모양은 공방 시험 탭의 js/lune/ui/paint.js(paintDaily)와 같다.
--  화면 오른쪽의 옆 판(ui/windows.luau). 게시판에서 멀어지면 닫힌다(boot.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Daily = require(lune.sim.daily)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.DAILY
local W = Daily.WORDS

local DailyWindow = {}
DailyWindow.ROWS = Daily.DATA.perDay
-- 그 게시판의 의뢰 수(기도 탑 = 셋 — 2026-10-25)
local function rowsOf(arg: any): number
	local board = if typeof(arg) == "string" then Daily.DATA.boards[arg] else nil
	return if board and board.perDay then board.perDay else Daily.DATA.perDay
end

function DailyWindow.size(arg: any): (number, number)
	return S.w, S.top + rowsOf(arg) * S.row + S.payY + 2 * S.payRow
end

-- 창의 제목: 기도 탑은 「기도 탑」(다른 게시판은 공방의 이름 「일일 의뢰」)
function DailyWindow.title(arg: any): string?
	local board = if typeof(arg) == "string" then Daily.DATA.boards[arg] else nil
	return if board then board.title else nil
end

-- 의뢰의 이름: 「포자 주머니 30마리」
function DailyWindow.taskName(t): string
	return Format.fill(W.kill, { name = t.name, n = t.n })
end

function DailyWindow.build(body: Frame, ctx, w: number, _h: number, arg: any)
	local view = {}
	local region = if typeof(arg) == "string" and Daily.DATA.boards[arg] then arg else Daily.REGION -- 연 게시판의 지역(은달 항구 = 수정 숲 — 2026-10-16)
	Ui.text(body, W.head, 0, 2, w, { color = C.gold })
	Ui.text(body, W.reset, 0, 2, w, { align = "right", color = C.dim })
	local rows = {}
	local textW = w - S.btnW - 8
	local nRows = rowsOf(region)
	for i = 1, nRows do
		local y = S.top + (i - 1) * S.row
		local by = y + 14
		local row = {}
		row.place = Ui.text(body, "", 0, y, textW, { color = C.dim })
		row.name = Ui.text(body, "", 0, y + 15, textW, { font = "body" })
		row.button = Ui.button(body, W.accept, w - S.btnW, by, S.btnW, function()
			local board = ctx.daily() and ctx.daily().boards[region]
			local t = board and board.tasks[i]
			-- 두 번 톡 하면 두 번째가 「아직 다 잡지 못했다 · 이미 받은 의뢰다」를 띄웠다(2026-10-18 검토) — 0.8초 안의 다시 누름은 받지 않는다
			local act = if t and t.st == Daily.OPEN then "accept" else "turn"
			if t and (act ~= row.act or os.clock() - (row.at or -9) > 0.8) then -- 같은 일만 막는다(수락한 뒤 바로 보상 받기는 된다)
				row.at, row.act = os.clock(), act
				ctx.dailyDo(act, region, i)
			end
		end, { main = true })
		row.count = Ui.text(body, "", w - S.btnW, by + math.floor((Ui.M.button - Ui.M.small) / 2), S.btnW, { align = "right", color = C.accent })
		row.bar = Ui.bar(body, 0, y + 34, textW, S.barH + 2, C.accent, C.panel2)
		rows[i] = row
	end
	local y = S.top + nRows * S.row
	Ui.line(body, 0, y, w)
	y += S.payY
	-- 보상: 의뢰 하나 = 경험치 · [달돈] / 둘을 다 내면 = [달가루]
	Ui.text(body, W.each, 0, y + 4, S.labelW - 4, { color = C.dim })
	local xp = Ui.text(body, "", S.labelW, y + 4, w - S.labelW, { color = C.gold })
	local coin = Ui.smallIcon(body, "coin", S.labelW, y)
	local money = Ui.text(body, "", S.labelW, y + 4, w - S.labelW, { color = C.gold })
	local allLabel = Ui.text(body, W.all, 0, y + S.payRow + 4, S.labelW - 4, { color = C.dim }) -- 기도 탑은 「의뢰마다」(달가루가 의뢰마다 — 2026-10-25)
	Ui.smallIcon(body, "dust", S.labelW, y + S.payRow)
	local dust = Ui.text(body, "", S.labelW + 21, y + S.payRow + 4, w - S.labelW - 21, { color = C.gold })

	function view.refresh()
		local got = ctx.daily()
		local board = got and got.boards[region]
		for i, row in rows do
			local t = board and board.tasks[i]
			local ready = t ~= nil and Daily.isReady(t)
			local act = t ~= nil and (t.st == Daily.OPEN or ready)
			row.place:set(if t then t.place else "")
			row.name:set(if t then DailyWindow.taskName(t) else "")
			row.name:color(if t and t.st == Daily.DONE then C.dim else C.text)
			row.button.frame.Visible = act
			if t and act then
				row.button:setText(if t.st == Daily.OPEN then W.accept else W.turn)
			end
			row.count:set(if not t or act then "" elseif t.st == Daily.DONE then W.done else ("%d/%d"):format(math.min(t.have, t.n), t.n))
			row.count:color(if t and t.st == Daily.DONE then C.green else C.accent)
			row.bar.frame.Visible = t ~= nil
			if t then
				row.bar:set(if t.st == Daily.DONE then 1 elseif t.st == Daily.OPEN then 0 else t.have / t.n)
				row.bar:setColor(if t.st == Daily.DONE then C.green else C.accent)
			end
		end
		local pay = board and board.pay
		local xpText = if pay then ("%s %s"):format(W.xp, Format.short(pay.xp)) else ""
		xp:set(xpText)
		local mx = S.labelW + Ui.measure(xpText) + 12
		local hasMoney = pay ~= nil and (pay.money or 0) > 0 -- 기도 탑은 달돈이 없다(2026-10-25)
		coin.Visible = hasMoney
		coin.Position = UDim2.fromOffset(mx, y)
		money:move(mx + 21, y + 4)
		money:set(if hasMoney then Format.short(pay.money) else "")
		allLabel:set(if pay and pay.each then W.eachDust or W.all else W.all)
		dust:set(if pay then Format.short(pay.dust) else "")
	end
	view.refresh()
	return view
end

return DailyWindow
