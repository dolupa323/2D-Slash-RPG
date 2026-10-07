-- 퀘스트 창(J) — 위에 하는 중인 퀘스트의 목록(메인이 먼저), 고르면 아래에 줄거리 · 할 일 · 보상. 주민의 부탁은 「그만두기」로 내려놓는다.
--  받는 것과 돌려주는 것은 주민 앞에서 한다(머리 위의 전구 · 책). 탭(메인 · 주민의 부탁 · 일일 · 끝낸 것)은 퀘스트가 늘어난 뒤에 나눈다.
--  화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Quests = require(lune.sim.quests)
local Format = require(lune.ui.format)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local ROWS = 4
local ROW = 26 -- 목록의 한 줄
local W = 300

local QuestWindow = {}
QuestWindow.ROWS = ROWS
QuestWindow.TEXT_LINES = 5 -- 줄거리가 쓰는 줄 수

function QuestWindow.size(): (number, number)
	return W, ROWS * ROW + 12 + QuestWindow.TEXT_LINES * 16 + 8 + 16 + 16 + 20 + Ui.M.button + 4
end

-- 보상을 한 줄로: 「경험치 441 · 달돈 73 · 물약 10」
function QuestWindow.rewardText(reward): string
	local parts = { ("경험치 %s"):format(Format.short(reward.xp)) }
	if reward.money > 0 then
		table.insert(parts, ("달돈 %s"):format(Format.short(reward.money)))
	end
	if reward.potions > 0 then
		table.insert(parts, ("물약 %d"):format(reward.potions))
	end
	return table.concat(parts, " · ")
end

function QuestWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local selected: string? = nil
	local rows = {}
	-- 목록: 고른 줄은 왼쪽에 민트 줄, 이름은 본문 글씨(메인은 노랑)
	for i = 1, ROWS do
		local y = (i - 1) * ROW
		local frame = Ui.group(body, 0, y, w, ROW - 2, "Row" .. i)
		local back = Ui.box(frame, 0, 0, w, ROW - 2, C.panel2, 1)
		local mark = Ui.box(frame, 0, 0, 2, ROW - 2, C.accent)
		local name = Ui.text(frame, "", 10, 6, w - 20, { font = "body" })
		local row = { id = nil :: string?, frame = frame, back = back, mark = mark, name = name }
		Ui.hit(frame).Activated:Connect(function()
			selected = row.id
			view.refresh()
		end)
		rows[i] = row
	end
	local y = ROWS * ROW + 4
	Ui.line(body, 0, y, w)
	local text = Ui.text(body, "", 0, y + 8, w, { lines = QuestWindow.TEXT_LINES, line = 16, color = C.dim })
	y += 8 + QuestWindow.TEXT_LINES * 16 + 8
	local todo = Ui.text(body, "", 0, y, w)
	-- 할 일 아래에: 무엇을 어디서 잡아야 하는지(사용자 2026-10-07: "뭘잡아야 갑옷조각이 나오는지를 자연스럽게 적어둬야")
	local where = Ui.text(body, "", 0, y + 16, w, { color = C.accent })
	local reward = Ui.text(body, "", 0, y + 34, w, { color = C.gold })
	local drop = Ui.button(body, "그만두기", w - 100, y + 54, 100, function()
		if selected then
			ctx.send("Quest", "drop", selected)
			selected = nil
		end
	end)
	function view.refresh()
		local book = ctx.quests() or {}
		local active = Quests.active(book)
		if selected and (not book[selected] or book[selected].done) then
			selected = nil
		end
		selected = selected or active[1]
		for i, row in rows do
			local id = active[i]
			row.id = id
			row.frame.Visible = id ~= nil
			if id then
				local def = Quests.def(id)
				local on = id == selected
				row.name:set(def.name)
				row.name:color(if def.kind == "main" then C.gold else C.text)
				row.back.BackgroundTransparency = if on then 0 else 1
				row.mark.Visible = on
			end
		end
		local def = selected and Quests.def(selected)
		if def then
			text:set(def.text)
			todo:set(table.concat(Quests.todo(book, selected, ctx.npcNames()), " · "))
			todo:color(if Quests.isReady(book, selected) then C.green else C.text)
			where:set(table.concat(Quests.hints(book, selected), " · "))
			reward:set(QuestWindow.rewardText(def.reward))
			drop.frame.Visible = def.kind ~= "main"
		else
			text:set("하는 중인 퀘스트가 없다. 머리 위에 ! 가 뜬 주민에게 말을 건다.")
			todo:set("")
			where:set("")
			reward:set("")
			drop.frame.Visible = false
		end
	end
	return view
end

return QuestWindow
