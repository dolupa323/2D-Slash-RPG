-- 퀘스트 알리미의 셈 — 화면을 모르는 셈이다(그리는 것은 client/lune/questHud.luau · 자동 검사 27이 그대로 부른다).
--  판에 적을 줄들의 차례와 높이, 글이 쓸 수 있는 폭을 정한다. 설명은 questHud.luau의 머리말.
local UI = require(script.Parent.Parent.data["ui.generated"])
local Quests = require(script.Parent.Parent.sim.quests)
local Layout = require(script.Parent.layout)

local TITLE, LINE, GAP = Layout.QUEST.title, Layout.QUEST.line, Layout.QUEST.gap -- 이름 한 줄 · 할 일 한 줄 · 퀘스트 사이

local Panel = {}
Panel.W = UI.hud.quest.w
Panel.H = UI.hud.quest.h -- PC에서 판이 쓸 수 있는 높이
Panel.H_TOUCH = if UI.hudTouch.quest then UI.hudTouch.quest.h else UI.hud.quest.h -- 스마트폰에서
Panel.PAD = 8 -- 판의 가장자리에서 글까지
Panel.HEAD = 20 -- 머리줄의 높이(가르는 줄까지)
Panel.INNER = Panel.W - Panel.PAD * 2 -- 글이 쓸 수 있는 폭
Panel.TAG_W, Panel.TAG_GAP = 26, 5 -- 갈래의 표(두 글자)의 폭 · 표와 이름 사이
Panel.COUNT_W = 34 -- 오른쪽의 「12/15」가 쓰는 폭
Panel.BAR_H = 4 -- 진행 띠의 높이
Panel.TITLE, Panel.LINE, Panel.GAP = TITLE, LINE, GAP
Panel.STEP = LINE + Panel.BAR_H + 2 -- 할 일 한 줄(글 + 띠)
Panel.TAGS = { main = "메인", side = "부탁", job = "전직", daily = "일일" }
Panel.DAILY_BACK = "게시판에 낸다" -- 다 잡은 일일 의뢰의 줄

-- 할 일 한 줄을 글과 숫자로 가른다: 「검병 · 갑옷 조각 3/8」 → 「검병 · 갑옷 조각」, 「3/8」
function Panel.split(text: string): (string, string?)
	local label, count = string.match(text, "^(.-)%s+(%d+/%d+)$")
	if label then
		return label, count
	end
	return text, nil
end

-- 알리미에 적을 것을 차례대로 셈한다(화면을 모르는 셈 — 자동 검사가 그대로 부른다). 돌려주는 것: 줄들, 판의 높이, 하는 중인 수, 길잡이 수
--  줄: { kind = "quest"(갈래 · 이름) | "step"(글 · 숫자 · 한 수 · 할 수) | "ready"(돌려줄 사람) | "label"(「받을 수 있는 퀘스트」) | "guide"(이름) | "where"(받는 곳), y, … }
--  maxH = 판이 쓸 수 있는 높이(안 주면 PC의 칸 — 스마트폰은 손가락 단추에 닿지 않게 더 낮다)
--  daily = 받아 둔 일일 의뢰들 { { name(몬스터), place(맵), n, have } … }(sim/daily.luau의 tracked) — 하는 중인 퀘스트 다음, 길잡이 앞에 「일일」 표로 적는다
function Panel.layout(book, names, level: number?, maxH: number?, daily: any?)
	local rows = {}
	local y = Panel.HEAD + 4
	local shown, guided = 0, 0
	local limit = (maxH or Panel.H) - Panel.PAD
	for _, id in Quests.active(book or {}) do
		local def = Quests.def(id)
		local st = book[id]
		local ready = Quests.isReady(book, id)
		local lines = if ready then 1 else 0
		if not ready then
			for i, step in def.steps do
				if (st.c[i] or 0) < step.n then
					lines += 1
				end
			end
		end
		local need = TITLE + (if ready then LINE + 2 else lines * Panel.STEP)
		if y + need > limit then
			break
		end
		shown += 1
		table.insert(rows, { kind = "quest", y = y, tag = def.kind, name = def.name })
		y += TITLE
		if ready then
			table.insert(rows, { kind = "ready", y = y, text = Quests.todo(book, id, names)[1] or "" })
			y += LINE + 2
		else
			for i, step in def.steps do
				local have = st.c[i] or 0
				if have < step.n then
					local label, count = Panel.split(Quests.trackText(step, have))
					table.insert(rows, { kind = "step", y = y, text = label, count = count or ("%d/%d"):format(have, step.n), have = have, n = step.n })
					y += Panel.STEP
				end
			end
		end
		y += GAP
	end
	-- 일일 의뢰(받아 둔 것): 「일일」 표 + 맵의 이름 / 「포자 주머니 12/30」과 진행 띠 — 다 잡았으면 「? 게시판에 낸다」
	for _, d in daily or {} do
		local ready = d.have >= d.n
		local need = TITLE + (if ready then LINE + 2 else Panel.STEP)
		if y + need > limit then
			break
		end
		shown += 1
		table.insert(rows, { kind = "quest", y = y, tag = "daily", name = d.place })
		y += TITLE
		if ready then
			table.insert(rows, { kind = "ready", y = y, text = Panel.DAILY_BACK })
			y += LINE + 2
		else
			table.insert(rows, { kind = "step", y = y, text = d.name, count = ("%d/%d"):format(d.have, d.n), have = d.have, n = d.n })
			y += Panel.STEP
		end
		y += GAP
	end
	-- 길잡이: 남는 높이에만
	local guides = if level then Quests.guide(book or {}, level, names) else {}
	local labelAt = nil
	for _, g in guides do
		local need = TITLE + LINE + (if guided == 0 then LINE + 6 else GAP)
		if y + need > limit then
			break
		end
		if guided == 0 then
			labelAt = y
			table.insert(rows, { kind = "label", y = y, line = shown > 0 })
			y += LINE + 6
		else
			y += GAP - 2
		end
		guided += 1
		table.insert(rows, { kind = "guide", y = y, text = g.title, tone = g.kind })
		y += TITLE
		table.insert(rows, { kind = "where", y = y, text = g.line, tone = g.kind })
		y += LINE
	end
	if shown > 0 and guided == 0 then
		y -= GAP
	end
	return rows, y + Panel.PAD, shown, guided
end

return Panel
