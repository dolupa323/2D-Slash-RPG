-- 퀘스트 창(J) — 메이플스토리의 퀘스트 창처럼 탭 셋: 「진행 중」 · 「시작 가능」 · 「완료」(2026-10-11 — 전에는 하는 중인 것 넷만 보였다).
--  위에 그 탭의 목록(메인 · 전직은 노랑), 고르면 아래에 줄거리와 그 탭에 맞는 것:
--   진행 중 = 할 일(다 됐으면 풀빛) · 무엇을 어디서 잡는지 · 보상 · 주민의 부탁은 「그만두기」
--   시작 가능 = 누구에게 · 어디서 받는지(「샛별 · 초승달 마을」) · 보상. 레벨이 모자란 다음 메인도 맨 끝에 흐리게 뜬다(「Lv.4가 되면 받는다」)
--   완료 = 줄거리와 받은 보상
--  받는 것과 돌려주는 것은 주민 앞에서 한다(머리 위의 ! · ?). 목록이 줄 수보다 길면 ▲ ▼로 넘긴다.
--  화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Quests = require(lune.sim.quests)
local Format = require(lune.ui.format)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local ROWS = 5
local ROW = 26 -- 목록의 한 줄
local W = 300
local TAB_H = 22
local TABS = { "진행 중", "시작 가능", "완료" }

local QuestWindow = {}
QuestWindow.ROWS = ROWS
QuestWindow.TABS = TABS
QuestWindow.TEXT_LINES = 5 -- 줄거리가 쓰는 줄 수
QuestWindow.W = W

function QuestWindow.size(): (number, number)
	return W, TAB_H + ROWS * ROW + 12 + QuestWindow.TEXT_LINES * 16 + 8 + 16 + 16 + 20 + Ui.M.button + 4
end

-- 보상을 한 줄로: 「경험치 441 · 달돈 73 · 물약 10」 · 전직 퀘스트는 「2차 전직 · Lv.30 무기」
function QuestWindow.rewardText(reward): string
	local parts = {}
	if reward.job then
		table.insert(parts, ("%d차 전직"):format(reward.job))
	end
	if reward.xp > 0 then
		table.insert(parts, ("경험치 %s"):format(Format.short(reward.xp)))
	end
	if reward.money > 0 then
		table.insert(parts, ("달돈 %s"):format(Format.short(reward.money)))
	end
	if reward.potions > 0 then
		table.insert(parts, ("물약 %d"):format(reward.potions))
	end
	if reward.gear then
		table.insert(parts, ("Lv.%d %s"):format(reward.gear.stage, if reward.gear.slot == "weapon" then "무기" else "방어구"))
	end
	return table.concat(parts, " · ")
end

-- 그 탭의 목록(퀘스트의 이름표들). tab = 1 진행 중 · 2 시작 가능 · 3 완료
function QuestWindow.listOf(tab: number, book, level: number): { string }
	if tab == 2 then
		return Quests.listOpen(book, level)
	elseif tab == 3 then
		return Quests.listDone(book)
	end
	return Quests.active(book)
end

-- 「시작 가능」에서 고른 퀘스트의 받는 곳: 「샛별 · 초승달 마을」
function QuestWindow.giverText(def, names): string
	local who = (names and names[def.giver]) or "주민"
	local place = Quests.giverPlace(def)
	return if place then ("받는 곳: %s · %s"):format(who, place) else ("받는 곳: %s"):format(who)
end

function QuestWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local tab = 1
	local selected: { string? } = { nil, nil, nil } -- 탭마다 고른 퀘스트
	local top = 0 -- 목록의 첫 줄(넘긴 수)
	local tabs = {}
	local tx = 0
	for i, name in TABS do
		tabs[i] = Ui.tab(body, name, tx, 0, function()
			if tab ~= i then
				tab = i
				top = 0
				view.refresh()
			end
		end)
		tx += tabs[i].width + 16
	end
	local up = Ui.button(body, "▲", w - 38, -3, 17, function()
		top = math.max(0, top - 1)
		view.refresh()
	end, { h = 17 })
	local down = Ui.button(body, "▼", w - 17, -3, 17, function()
		top += 1
		view.refresh()
	end, { h = 17 })
	local rows = {}
	-- 목록: 고른 줄은 왼쪽에 민트 줄, 이름은 본문 글씨(메인 · 전직은 노랑 · 아직 못 받는 것은 흐리게)
	for i = 1, ROWS do
		local y = TAB_H + (i - 1) * ROW
		local frame = Ui.group(body, 0, y, w, ROW - 2, "Row" .. i)
		local back = Ui.box(frame, 0, 0, w, ROW - 2, C.panel2, 1)
		local mark = Ui.box(frame, 0, 0, 2, ROW - 2, C.accent)
		local name = Ui.text(frame, "", 10, 6, w - 70, { font = "body" })
		local lv = Ui.text(frame, "", w - 56, 7, 50, { align = "right", color = C.dim })
		local row = { id = nil :: string?, frame = frame, back = back, mark = mark, name = name, lv = lv }
		Ui.hit(frame).Activated:Connect(function()
			selected[tab] = row.id
			view.refresh()
		end)
		rows[i] = row
	end
	local y = TAB_H + ROWS * ROW + 4
	Ui.line(body, 0, y, w)
	local text = Ui.text(body, "", 0, y + 8, w, { lines = QuestWindow.TEXT_LINES, line = 16, color = C.dim })
	y += 8 + QuestWindow.TEXT_LINES * 16 + 8
	local todo = Ui.text(body, "", 0, y, w)
	-- 할 일 아래에: 무엇을 어디서 잡아야 하는지(사용자 2026-10-07: "뭘잡아야 갑옷조각이 나오는지를 자연스럽게 적어둬야")
	local where = Ui.text(body, "", 0, y + 16, w, { color = C.accent })
	local reward = Ui.text(body, "", 0, y + 34, w, { color = C.gold })
	local drop = Ui.button(body, "그만두기", w - 100, y + 54, 100, function()
		if tab == 1 and selected[1] then
			ctx.send("Quest", "drop", selected[1])
			selected[1] = nil
		end
	end)
	function view.refresh()
		local book = ctx.quests() or {}
		local me = ctx.me()
		local level = if me then me.level else 1
		local list = QuestWindow.listOf(tab, book, level)
		for i, t in tabs do
			t:setOn(i == tab)
		end
		-- 고른 것이 목록에서 빠졌으면(돌려줬다 · 받았다) 첫 줄을 고른다
		if selected[tab] and not table.find(list, selected[tab] :: string) then
			selected[tab] = nil
		end
		selected[tab] = selected[tab] or list[1]
		top = math.clamp(top, 0, math.max(0, #list - ROWS))
		up.frame.Visible = #list > ROWS
		down.frame.Visible = #list > ROWS
		up:setEnabled(top > 0)
		down:setEnabled(top < #list - ROWS)
		for i, row in rows do
			local id = list[top + i]
			row.id = id
			row.frame.Visible = id ~= nil
			if id then
				local def = Quests.def(id)
				local on = id == selected[tab]
				local locked = tab == 2 and Quests.state(book, level, id) == "locked"
				row.name:set(def.name)
				row.name:color(if locked then C.off elseif def.kind == "side" then C.text else C.gold)
				row.lv:set("Lv." .. def.lv)
				row.lv:color(if locked then C.red else C.dim)
				row.back.BackgroundTransparency = if on then 0 else 1
				row.mark.Visible = on
			end
		end
		local id = selected[tab]
		local def = id and Quests.def(id)
		drop.frame.Visible = false
		if def and tab == 1 then
			text:set(def.text)
			todo:set(table.concat(Quests.todo(book, id, ctx.npcNames()), " · "))
			todo:color(if Quests.isReady(book, id) then C.green else C.text)
			where:set(table.concat(Quests.hints(book, id), " · "))
			where:color(C.accent)
			reward:set(QuestWindow.rewardText(def.reward))
			drop.frame.Visible = def.kind == "side"
		elseif def and tab == 2 then
			local locked = Quests.state(book, level, id) == "locked"
			text:set(def.text)
			todo:set(QuestWindow.giverText(def, ctx.npcNames()))
			todo:color(C.text)
			where:set(if locked then ("Lv.%d가 되면 받는다"):format(def.lv) else "그 주민 앞에서 ↑ 를 눌러 받는다")
			where:color(if locked then C.red else C.accent)
			reward:set(QuestWindow.rewardText(def.reward))
		elseif def then
			text:set(def.text)
			todo:set("끝낸 퀘스트")
			todo:color(C.dim)
			where:set("")
			reward:set(QuestWindow.rewardText(def.reward))
		else
			text:set(if tab == 1
				then "하는 중인 퀘스트가 없다. 머리 위에 ! 가 뜬 주민에게 말을 건다."
				elseif tab == 2 then "지금 받을 수 있는 퀘스트가 없다."
				else "아직 끝낸 퀘스트가 없다.")
			todo:set("")
			where:set("")
			reward:set("")
		end
	end
	return view
end

return QuestWindow
