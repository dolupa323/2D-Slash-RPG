-- 명예의 전당 창 — 순위판 셋(후원 · 전투력 · 레벨)의 위 열 줄. 명예의 전당 건물 안의 비석 앞에서 ↑를 누르면 그 비석의 판이 뜬다(탭으로 다른 판을 본다).
--  사용자 2026-10-10: "대형 마을마다 명예의 전당 건물 을 만들어서 최대 로벅스 결제자, 전투력 랭킹, 레벨 랭킹 이렇게 캐릭터 닉네임 보여주는 명예의 전당을 만듭니다."
--  순위는 서버가 준다(ctx.rank() — 서버는 1분마다 한 번 읽어 둔 것을 준다). 이름은 캐릭터의 이름(만들 때 지은 것).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local CLASSES = require(lune.data["classes.generated"])
local Rank = require(lune.sim.rank)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local ROW = 20 -- 한 줄의 높이
local TOP = 30 -- 탭 아래 첫 줄의 자리
-- 판의 차례와 머리글(값의 이름)
local TABS = { { id = "robux", name = "후원", value = "쓴 로벅스" }, { id = "power", name = "전투력", value = "전투력" }, { id = "level", name = "레벨", value = "레벨" } }

local HallWindow = {}

function HallWindow.size(): (number, number)
	return 300, TOP + 16 + Rank.TOP * ROW + 8
end

function HallWindow.build(body: Frame, ctx, w: number, _h: number, arg: any)
	local board = if typeof(arg) == "string" then arg else "level"
	local boards = nil -- 서버가 준 판들(아직이면 nil)
	local failed = false -- 서버가 답하지 않았다(너무 자주 물음 · 잠깐의 오류) — 「기록이 없다」와 가른다(2026-10-18 검토)
	local alive = true
	local tabs = {}
	local x = 0
	for _, t in TABS do
		local tab
		tab = Ui.tab(body, t.name, x, 2, function()
			board = t.id
			HallWindow.redraw()
		end)
		tabs[t.id] = tab
		x += tab.width + 18
	end
	Ui.line(body, 0, 22, w)
	local headName = Ui.text(body, "이름", 34, TOP, 120, { color = C.dim })
	local headValue = Ui.text(body, "", 0, TOP, w, { color = C.dim, align = "right" })
	local note = Ui.text(body, "불러오는 중 …", 0, TOP + 16 + 40, w, { color = C.dim, align = "center" })
	local rows = {}
	for i = 1, Rank.TOP do
		local y = TOP + 16 + (i - 1) * ROW
		rows[i] = {
			no = Ui.text(body, tostring(i), 0, y, 26, { align = "right", color = if i <= 3 then C.gold else C.dim }),
			name = Ui.text(body, "", 34, y, 96, { font = "small" }),
			class = Ui.text(body, "", 134, y, 82, { color = C.dim }),
			value = Ui.text(body, "", 0, y, w, { align = "right", color = C.accent }),
		}
	end

	function HallWindow.redraw()
		if not alive then
			return
		end
		for _, t in TABS do
			tabs[t.id]:setOn(t.id == board)
			if t.id == board then
				headValue:set(t.value)
			end
		end
		local list = if boards then boards[board] or {} else nil
		note:show(list == nil or #list == 0)
		note:set(if list ~= nil then "아직 기록이 없습니다" elseif failed then "불러오지 못했습니다 · 다시 불러오는 중" else "불러오는 중 …")
		headName:show(list ~= nil and #list > 0)
		headValue:show(list ~= nil and #list > 0)
		for i, row in rows do
			local it = if list then list[i] else nil
			row.no:show(it ~= nil)
			row.name:set(if it then it.name else "")
			row.class:set(if it and it.class and CLASSES.classes[it.class] then CLASSES.classes[it.class].name else "")
			row.value:set(if it then it.value else "")
		end
	end
	HallWindow.redraw()
	task.spawn(function()
		-- 답이 없으면(빠르기의 한도 · 잠깐의 오류) 「기록이 없다」로 보이지 않게 몇 번 더 묻는다
		for _ = 1, 4 do
			local got = ctx.rank()
			if not alive then
				return
			end
			if got then
				boards, failed = got, false
				HallWindow.redraw()
				return
			end
			failed = true
			HallWindow.redraw()
			task.wait(1.5)
		end
	end)

	return {
		destroy = function()
			alive = false
		end,
	}
end

return HallWindow
