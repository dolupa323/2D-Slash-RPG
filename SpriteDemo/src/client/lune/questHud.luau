-- 퀘스트 알리미 — 늘 보이는 화면의 오른쪽 위(공방 「기본 · UI」 탭의 화면 배치, data/ui.generated.luau의 hud.quest).
--  하는 중인 퀘스트(메인이 맨 위): 이름 한 줄(본문 글씨 — 메인은 노랑)과 할 일(「수습 검병 3/5」 — 작은 글씨). 다 됐으면 「샛별에게 간다」가 풀빛으로.
--  판 없이, 어두운 테두리를 두른 글을 오른쪽 끝에 맞춰 적는다. 칸의 높이에 들어가는 데까지만 적는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Quests = require(lune.sim.quests)
local Layout = require(lune.ui.layout)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local TITLE, LINE, GAP = Layout.QUEST.title, Layout.QUEST.line, Layout.QUEST.gap -- 이름 한 줄 · 할 일 한 줄 · 퀘스트 사이

local QuestHud = {}
QuestHud.W = UI.hud.quest.w
QuestHud.TEXT_W = UI.hud.quest.w -- 글이 쓸 수 있는 폭(테스트 17이 본다)
QuestHud.H = UI.hud.quest.h
QuestHud.TITLE, QuestHud.LINE, QuestHud.GAP = TITLE, LINE, GAP

function QuestHud.init(root: Frame)
	local r = UI.hud.quest
	-- 버프 칸이 생기기 전에는 그 자리(위)로 올라붙는다
	local box = Stage.place(root, "Quests", r.at, r.x, UI.hud.buffs.y, r.w, r.h)
	box.Visible = false
	QuestHud.box = box
	QuestHud.rows = {}
end

-- 스마트폰 단추가 켜지면 메뉴 단추(오른쪽 위) 아래로 내려간다(data/ui.generated.luau의 hudTouch)
function QuestHud.setTouch(on: boolean)
	local r = UI.hud.quest
	local t = UI.hudTouch.quest
	if on and t then
		QuestHud.box.Position = Stage.atPosition(t.at, t.x, t.y)
	else
		QuestHud.box.Position = Stage.atPosition(r.at, r.x, UI.hud.buffs.y)
	end
end

-- book = 내 퀘스트의 상태 · names = 주민 id → 이름
function QuestHud.set(book, names)
	for _, row in QuestHud.rows do
		row:destroy()
	end
	table.clear(QuestHud.rows)
	local y, shown = 0, 0
	for _, id in Quests.active(book or {}) do
		local def = Quests.def(id)
		local todo = Quests.todo(book, id, names)
		local need = TITLE + #todo * LINE
		if y + need > QuestHud.H then
			break
		end
		shown += 1
		local ready = Quests.isReady(book, id)
		table.insert(QuestHud.rows, Ui.text(QuestHud.box, def.name, 0, y, QuestHud.TEXT_W, { font = "body", align = "right", outline = true, color = if def.kind == "main" then C.gold else C.text }))
		y += TITLE
		for _, line in todo do
			table.insert(QuestHud.rows, Ui.text(QuestHud.box, line, 0, y, QuestHud.TEXT_W, { align = "right", outline = true, color = if ready then C.green else C.text }))
			y += LINE
		end
		y += GAP
	end
	QuestHud.shown = shown
	QuestHud.box.Visible = shown > 0
end

return QuestHud
