-- 퀘스트 알리미 — 늘 보이는 화면의 오른쪽 위(공방 「기본 · UI」 탭의 화면 배치, data/ui.generated.luau의 hud.quest).
--  사용자 2026-10-11: "지금 우측 상단에 있는 퀘스트 퀘스트라는 인식이 되지가 않아요 ui 만들어서 퀘스트처럼 보이게하세요" — 전에는 판 없이 글만 오른쪽에 붙여 적었다.
--  이제는 창과 같은 어두운 판 위에(메이플스토리의 퀘스트 알리미처럼):
--   ① 머리줄: 「!」 그림 + 「퀘스트」 + 오른쪽에 「진행 N」
--   ② 하는 중인 퀘스트(전직 → 메인 → 부탁): 갈래의 표(「메인」 노랑 · 「전직」 민트 · 「부탁」 회색) + 이름 / 할 일마다 왼쪽에 글 · 오른쪽에 「3/8」 · 그 아래 진행 띠.
--      다 했으면 「?」 그림 + 「샛별에게 간다」(풀빛)
--   ③ 받을 수 있는 퀘스트(길잡이 — sim/quests.luau의 Q.guide): 가르는 줄 아래에 「받을 수 있는 퀘스트」, 「! 이름」과 「샛별에게 받는다 · 초승달 마을」(레벨이 모자라면 흐리게 「Lv.4부터 받는다」)
--  판의 높이는 적은 만큼만이다. 칸의 높이에 들어가는 데까지만 적는다(스마트폰은 손가락 단추에 닿지 않게 더 낮다). 글은 모두 판 안쪽 폭에 들어간다.
--  줄의 차례 · 높이 · 폭의 셈은 shared/lune/ui/questPanel.luau(자동 검사 27이 본다) — 여기서는 그리기만 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Quests = require(lune.sim.quests)
local Panel = require(lune.ui.questPanel) -- 줄의 차례 · 높이 · 폭의 셈
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)
local Kit = require(script.Parent.ui.kit)

local C = Ui.COLOR
local LINE = Panel.LINE

local QuestHud = {}
QuestHud.W = Panel.W
QuestHud.H = Panel.H
QuestHud.MARK = { new = UI.questMark.new, done = UI.questMark.done } -- 「!」 · 「?」 그림(주민 머리 위의 것과 같다)

QuestHud.touch, QuestHud.buffs = false, false -- 스마트폰 단추가 켜졌는가 · 버프가 떠 있는가
QuestHud.covered = false -- 오른쪽 창이 이 자리를 덮고 있는가(덮인 동안은 그리지 않는다)
QuestHud.shown, QuestHud.guided = 0, 0

-- 자리: 버프(바로 위의 칸)가 없으면 그 자리로 올라붙고, 버프가 뜨면 제자리로 내려간다(공방 「기본 · UI」 탭의 4번 칸: "버프가 없으면 그 자리로 올라붙는다").
--  스마트폰 단추가 켜지면 메뉴 단추(오른쪽 위) 아래(data/ui.generated.luau의 hudTouch) — 거기서는 버프가 메뉴 단추의 왼쪽에 떠서 겹치지 않는다
local function place()
	local r = UI.hud.quest
	local t = UI.hudTouch.quest
	if not QuestHud.box then
		return
	end
	if QuestHud.touch and t then
		QuestHud.box.Position = Stage.atPosition(t.at, t.x, t.y)
	else
		QuestHud.box.Position = Stage.atPosition(r.at, r.x, if QuestHud.buffs then r.y else UI.hud.buffs.y)
	end
end

function QuestHud.init(root: Frame)
	local r = UI.hud.quest
	local box = Stage.place(root, "Quests", r.at, r.x, UI.hud.buffs.y, r.w, r.h)
	box.Visible = false
	QuestHud.box = box
	place()
end

function QuestHud.setTouch(on: boolean)
	QuestHud.touch = on
	place()
end

-- 오른쪽 끝에 창이 떴다 · 닫혔다: 창의 바탕이 살짝 비쳐서(ui.js의 panelAlpha) 알리미의 글이 창의 글 뒤로 비쳐 보인다 — 덮인 동안은 감춘다
function QuestHud.setCovered(on: boolean)
	QuestHud.covered = on
	if QuestHud.box then
		QuestHud.box.Visible = not on and QuestHud.shown + QuestHud.guided > 0
	end
end

-- 버프가 뜨고 사라졌다(켜 둔 사출기 · 영혼 · 열기)
function QuestHud.setBuffs(on: boolean)
	if QuestHud.buffs ~= on then
		QuestHud.buffs = on
		place()
	end
end

-- book = 내 퀘스트의 상태 · names = 주민 id → 이름 · level = 내 레벨(길잡이를 셈한다 — 안 주면 길잡이를 적지 않는다)
function QuestHud.set(book, names, level: number?)
	local box = QuestHud.box
	for _, child in box:GetChildren() do
		child:Destroy()
	end
	local rows, height, shown, guided = Panel.layout(book or {}, names, level, if QuestHud.touch then Panel.H_TOUCH else Panel.H)
	QuestHud.shown = shown
	QuestHud.guided = guided
	box.Visible = shown + guided > 0 and not QuestHud.covered
	if shown + guided == 0 then
		return
	end
	local W, PAD, INNER = Panel.W, Panel.PAD, Panel.INNER
	local panel = Ui.panel(box, 0, 0, W, height)
	-- ① 머리줄
	local mark = Kit.part(panel, QuestHud.MARK.new, PAD, 0)
	mark.Position = UDim2.fromOffset(PAD, math.floor((Panel.HEAD - mark.Size.Y.Offset) / 2) + 1)
	local headX = PAD + mark.Size.X.Offset + 5
	Ui.text(panel, "퀘스트", headX, 5, INNER - (headX - PAD), { font = "body", color = C.gold })
	if shown > 0 then
		Ui.text(panel, ("진행 %d"):format(shown), PAD, 7, INNER, { align = "right", color = C.dim })
	end
	Ui.box(panel, PAD, Panel.HEAD, INNER, 1, C.lineHot).Name = "HeadLine"
	-- ② · ③
	for _, row in rows do
		if row.kind == "quest" then
			local tint = if row.tag == "main" then C.gold elseif row.tag == "job" then C.accent else C.lineHot
			local chip = Ui.box(panel, PAD, row.y + 1, Panel.TAG_W, 13, tint)
			chip.Name = "Tag"
			Ui.text(chip, Panel.TAGS[row.tag] or "부탁", 0, 1, Panel.TAG_W, { align = "center", color = if row.tag == "side" then C.text else C.ink })
			local nameX = PAD + Panel.TAG_W + Panel.TAG_GAP
			Ui.text(panel, row.name, nameX, row.y, INNER - Panel.TAG_W - Panel.TAG_GAP, { font = "body", color = if row.tag == "main" then C.gold elseif row.tag == "job" then C.accent else C.text })
		elseif row.kind == "step" then
			Ui.text(panel, row.text, PAD + 2, row.y, INNER - 2 - Panel.COUNT_W, { color = C.text })
			Ui.text(panel, row.count, PAD, row.y, INNER, { align = "right", color = C.accent })
			local bar = Ui.bar(panel, PAD + 2, row.y + LINE - 1, INNER - 2, Panel.BAR_H, C.accent, C.panel2)
			bar:set(row.have / math.max(1, row.n))
		elseif row.kind == "ready" then
			local done = Kit.part(panel, QuestHud.MARK.done, PAD + 2, row.y)
			done.Position = UDim2.fromOffset(PAD + 2, row.y + math.floor((LINE - done.Size.Y.Offset) / 2))
			local tx = PAD + 2 + done.Size.X.Offset + 4
			Ui.text(panel, row.text, tx, row.y, INNER - (tx - PAD), { color = C.green })
		elseif row.kind == "label" then
			if row.line then
				Ui.box(panel, PAD, row.y, INNER, 1, C.line).Name = "GuideLine"
			end
			Ui.text(panel, "받을 수 있는 퀘스트", PAD, row.y + (if row.line then 5 else 1), INNER, { color = C.dim })
		elseif row.kind == "guide" then
			-- 받을 수 있는 전직 퀘스트(job)는 민트(「전직」 표의 색) · 다음 메인(open)은 금빛 · 부탁(side)은 흰색 · 레벨이 모자란 것(level)은 흐리게
			Ui.text(panel, row.text, PAD, row.y, INNER, { font = "body", color = if row.tone == "job" then C.accent elseif row.tone == "open" then C.gold elseif row.tone == "side" then C.text else C.dim })
		elseif row.kind == "where" then
			Ui.text(panel, row.text, PAD + 2, row.y, INNER - 2, { color = if row.tone == "level" then C.dim else C.accent })
		end
	end
end

return QuestHud
