-- 퀘스트 알리미 — 늘 보이는 화면의 오른쪽 위(공방 「기본 · UI」 탭의 화면 배치 5번, data/ui.generated.luau의 hud.quest).
--  하는 중인 퀘스트(메인이 맨 위): 이름 한 줄(메인은 노랑)과 할 일(「수습 검병 3/5」). 다 됐으면 「샛별에게 간다」가 풀빛으로.
--  비치는 어두운 바탕 위에 작은 글씨로, 칸의 높이(네 줄)에 들어가는 데까지만 적는다. 아래로는 줄 수만큼 늘어난다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Quests = require(lune.sim.quests)
local Kit = require(script.Parent.ui.kit)

local C = Kit.COLOR
local LINE = Kit.LINE

local QuestHud = {}
QuestHud.W = UI.hud.quest.w
QuestHud.TEXT_W = UI.hud.quest.w - 8 -- 글이 쓸 수 있는 폭(테스트 17이 본다)
QuestHud.LINES = math.floor((UI.hud.quest.h - 3) / LINE) -- 칸에 들어가는 줄 수

function QuestHud.init(root: Frame)
	local r = UI.hud.quest
	local box = Kit.group(root, r.x, r.y, r.w, 1)
	box.Name = "Quests"
	box.Visible = false
	QuestHud.box = box
	QuestHud.back = Kit.part(box, "veil", 0, 0, r.w, 3)
	QuestHud.back.ImageTransparency = 0.3
	QuestHud.rows = {}
end

-- book = 내 퀘스트의 상태 · names = 주민 id → 이름
function QuestHud.set(book, names)
	for _, row in QuestHud.rows do
		row:destroy()
	end
	table.clear(QuestHud.rows)
	local lines, shown = 0, 0
	for _, id in Quests.active(book or {}) do
		local def = Quests.def(id)
		local todo = Quests.todo(book, id, names)
		if lines + 1 + #todo > QuestHud.LINES then
			break
		end
		shown += 1
		local ready = Quests.isReady(book, id)
		table.insert(QuestHud.rows, Kit.text(QuestHud.box, def.name, 4, 2 + lines * LINE, QuestHud.TEXT_W, { color = if def.kind == "main" then C.yellow else C.white }))
		lines += 1
		for _, line in todo do
			table.insert(QuestHud.rows, Kit.text(QuestHud.box, line, 4, 2 + lines * LINE, QuestHud.TEXT_W, { color = if ready then C.green else C.text }))
			lines += 1
		end
	end
	local h = 3 + lines * LINE
	QuestHud.shown = shown
	QuestHud.box.Visible = shown > 0 and not QuestHud.hidden
	QuestHud.box.Size = UDim2.fromOffset(QuestHud.W, h)
	QuestHud.back.Size = UDim2.fromOffset(QuestHud.W, h)
end

-- 주민과 말하는 동안에는 숨는다(말 상자가 같은 자리에 걸친다)
function QuestHud.hide(on: boolean)
	QuestHud.hidden = on
	QuestHud.box.Visible = (QuestHud.shown or 0) > 0 and not on
end

return QuestHud
