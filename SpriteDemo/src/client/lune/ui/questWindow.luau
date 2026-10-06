-- 퀘스트 창(J) — 위에 하는 중인 퀘스트의 목록(메인이 먼저), 고르면 아래에 줄거리 · 할 일 · 보상. 주민의 부탁은 「그만두기」로 내려놓는다.
--  받는 것과 돌려주는 것은 주민 앞에서 한다(머리 위의 ! ?). 탭(메인 · 주민의 부탁 · 일일 · 끝낸 것)은 퀘스트가 늘어난 뒤에 나눈다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Quests = require(lune.sim.quests)
local Format = require(lune.ui.format)
local Kit = require(script.Parent.kit)

local C = Kit.COLOR
local ROWS = 4

local QuestWindow = { height = 152 }

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
	for i = 1, ROWS do
		local row = { id = nil :: string? }
		row.button = Kit.button(body, "", 2, 1 + (i - 1) * 15, w - 4, 14, function()
			selected = row.id
			view.refresh()
		end)
		rows[i] = row
	end
	Kit.box(body, 2, 62, w - 4, 1, C.edgeDim)
	local text = Kit.text(body, "", 4, 65, w - 8, { lines = 3, color = C.dim })
	local todo = Kit.text(body, "", 4, 99, w - 8, { color = C.white })
	local reward = Kit.text(body, "", 4, 110, w - 8, { color = C.yellow })
	local drop = Kit.button(body, "그만두기", w - 62, 121, 60, 13, function()
		if selected then
			ctx.send("Quest", "drop", selected)
			selected = nil
		end
	end)
	local count = Kit.text(body, "", 4, 123, 106, { color = C.dim })

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
			row.button.frame.Visible = id ~= nil
			if id then
				local def = Quests.def(id)
				row.button:setText(def.name)
				row.button:setKind(if id == selected then "orange" else "blue")
			end
		end
		local done = 0
		for _, st in book do
			if st.done then
				done += 1
			end
		end
		count:set(("하는 중 %d · 끝낸 것 %d"):format(#active, done))
		local def = selected and Quests.def(selected)
		if def then
			text:set(def.text)
			todo:set(table.concat(Quests.todo(book, selected, ctx.npcNames()), " · "))
			todo:color(if Quests.isReady(book, selected) then C.green else C.white)
			reward:set(QuestWindow.rewardText(def.reward))
			drop.frame.Visible = def.kind ~= "main"
		else
			text:set("하는 중인 퀘스트가 없다. 머리 위에 !가 뜬 주민에게 말을 건다.")
			todo:set("")
			reward:set("")
			drop.frame.Visible = false
		end
	end
	return view
end

return QuestWindow
