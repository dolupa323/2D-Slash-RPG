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
Panel.DAILY_BACK = require(script.Parent.Parent.data["daily.generated"]).words.back -- 다 잡은 일일 의뢰의 줄(「의뢰 게시판으로 간다」 — 공방 daily.js의 words)
Panel.NAV_W, Panel.NAV_H, Panel.NAV_GAP = 16, 13, 4 -- 길찾기 단추(이름 줄의 오른쪽 끝 — 사용자 2026-10-13: "각각 퀘스트마다  간단한 화살표 버튼") · 이름과의 사이
Panel.NAME_W = Panel.INNER - Panel.TAG_W - Panel.TAG_GAP - Panel.NAV_W - Panel.NAV_GAP -- 하는 중인 퀘스트의 이름이 쓰는 폭(표와 단추 사이)
Panel.GUIDE_W = Panel.INNER - Panel.NAV_W - Panel.NAV_GAP -- 받을 수 있는 퀘스트의 이름이 쓰는 폭
-- 알리미의 크기 세 단계(머리줄 오른쪽 끝의 「−」 · 「+」 단추로 한 단계씩 줄이고 늘린다):
--   최소(MIN) = 머리줄만(다 닫힌다) · 중간(MID — 처음) = 중요한 것만: 메인 · 전직 · 일일 의뢰(+ 다음 메인 · 전직의 길잡이) · 최대(MAX) = 받은 퀘스트와 일일 의뢰 모두 + 받을 수 있는 퀘스트
--  사용자 2026-10-13: "퀘스트 가 - 누르면 중요한거 메인 , 일퀘 이런거만 뜨고  + 누르면 다보이는 식이여야죠" → 같은 날
--   "최소화   중간   최대화  이렇게 해서   최소화는 다 닫히는거  중간은  현재 최소화  최대화는  지금 최대화 로 해서  +- 버튼을 몇번더 누르냐에 따라 늘리고 줄일수 있도록"
--  판은 정한 높이(Panel.maxH)까지만 자라고, 적을 것이 그보다 많으면 판 안에서 스크롤한다(같은 날: "스크롤을 넣어야죠 무식하게 아래로 계속확장하면 어쩌라는거에요")
Panel.MIN, Panel.MID, Panel.MAX = 0, 1, 2
Panel.SIZE_FIRST = Panel.MID -- 처음의 크기(사용자: "퀘스트는 중요한것만 보이는게 디폴트입니다")
Panel.FOLD_BETWEEN = 3 -- 「−」와 「+」 사이
Panel.KEY_TAGS = { main = true, job = true, daily = true } -- 중요한 것: 메인 · 전직 · 일일 의뢰
Panel.FOLD_W, Panel.FOLD_H, Panel.FOLD_GAP = 15, 13, 6 -- 단추(머리줄의 오른쪽 끝)
Panel.FOLD_HIT = { x = 5, y = 4 } -- 누르는 자리는 그림보다 이만큼씩 넓다
Panel.LIST_TOP = Panel.HEAD + 1 -- 스크롤하는 칸이 시작하는 자리(머리줄과 가르는 줄 아래)
Panel.LIST_BOTTOM = 2 -- 판의 아래 테두리
Panel.SCROLL_W = 3 -- 스크롤 막대의 폭(판의 오른쪽 여백 안에 든다)
-- 판의 가장 큰 높이: PC = 공방의 칸(hud.quest.h) — 창이 작아 메뉴 단추에 닿으면 그 위까지만 · 스마트폰 = 손가락 단추에 닿지 않는 칸
function Panel.maxH(gridH: number?, touch: boolean?): number
	if touch then
		return Panel.H_TOUCH
	end
	local below = UI.grid.h - UI.hud.menu.y + 8
	return math.min(Panel.H, (gridH or UI.grid.h) - UI.hud.quest.y - below)
end

-- 할 일 한 줄을 글과 숫자로 가른다: 「검병 · 갑옷 조각 3/8」 → 「검병 · 갑옷 조각」, 「3/8」
function Panel.split(text: string): (string, string?)
	local label, count = string.match(text, "^(.-)%s+(%d+/%d+)$")
	if label then
		return label, count
	end
	return text, nil
end

-- 알리미에 적을 것을 차례대로 셈한다(화면을 모르는 셈 — 자동 검사가 그대로 부른다). 돌려주는 것: 줄들, 적은 것 전체의 높이, 적은 퀘스트의 수, 길잡이 수, 그 밖의 것(info)
--  줄: { kind = "quest"(갈래 · 이름 · key) | "step"(글 · 숫자 · 한 수 · 할 수) | "ready"(돌려줄 사람) | "label"(「받을 수 있는 퀘스트」) | "guide"(이름) | "where"(받는 곳), y, … }
--   y = 판의 위에서부터(머리줄을 넣어). 적은 것 전체의 높이가 판의 가장 큰 높이(maxH)를 넘으면 판은 maxH까지만 그리고 그 안에서 스크롤한다
--  maxH = 판의 가장 큰 높이(안 주면 PC의 칸 — 게임은 Panel.maxH를 준다)
--  daily = 받아 둔 일일 의뢰들 { { name(몬스터), place(맵), n, have } … }(sim/daily.luau의 tracked) — 하는 중인 퀘스트 다음, 길잡이 앞에 「일일」 표로 적는다
--  size = 크기(Panel.MIN · MID · MAX — 안 주면 MAX. 예전의 꼴: true = MID · false = MAX)
--  info = { total = 받은 것 모두의 수, hidden = 중요한 것만일 때 안 적은 수, fold, view = 판의 높이, scroll = 스크롤하는가, any = 어느 모습에서든 적을 것이 있는가 }
function Panel.layout(book, names, level: number?, maxH: number?, daily: any?, sizeOrFold: any?)
	local size = if typeof(sizeOrFold) == "number" then sizeOrFold elseif sizeOrFold == true then Panel.MID else Panel.MAX
	local fold = size <= Panel.MID -- 중요한 것만
	local rows = {}
	local y = Panel.HEAD + 4
	local shown, guided = 0, 0
	-- 받은 것들: 하는 중인 퀘스트(전직 → 메인 → 부탁) → 일일 의뢰
	local entries = {}
	for _, id in Quests.active(book or {}) do
		local def = Quests.def(id)
		local st = book[id]
		local e = { tag = def.kind, name = def.name, key = id, ready = Quests.isReady(book, id), steps = {} }
		if e.ready then
			e.back = Quests.todo(book, id, names)[1] or ""
		else
			for i, step in def.steps do
				local have = st.c[i] or 0
				if have < step.n then
					local label, count = Panel.split(Quests.trackText(step, have))
					table.insert(e.steps, { text = label, count = count or ("%d/%d"):format(have, step.n), have = have, n = step.n })
				end
			end
		end
		table.insert(entries, e)
	end
	-- 일일 의뢰(받아 둔 것): 「일일」 표 + 맵의 이름 / 「포자 주머니 3/8」과 진행 띠 — 다 잡았으면 「? 게시판에 낸다」
	for _, d in daily or {} do
		local e = { tag = "daily", name = d.place, key = if d.region then ("daily:%s:%d"):format(d.region, d.i) else nil, ready = d.have >= d.n, steps = {} }
		if e.ready then
			e.back = Panel.DAILY_BACK
		else
			table.insert(e.steps, { text = d.name, count = ("%d/%d"):format(d.have, d.n), have = d.have, n = d.n })
		end
		table.insert(entries, e)
	end
	local info = { total = #entries, hidden = 0, fold = size == Panel.MID, size = size, view = 0, scroll = false, any = #entries > 0 }
	for _, e in entries do
		if fold and not Panel.KEY_TAGS[e.tag] then
			info.hidden += 1
			continue
		end
		shown += 1
		table.insert(rows, { kind = "quest", y = y, tag = e.tag, name = e.name, key = e.key }) -- key = 길찾기 단추가 가리키는 것
		y += TITLE
		if e.ready then
			table.insert(rows, { kind = "ready", y = y, text = e.back })
			y += LINE + 2
		else
			for _, st in e.steps do
				table.insert(rows, { kind = "step", y = y, text = st.text, count = st.count, have = st.have, n = st.n })
				y += Panel.STEP
			end
		end
		y += GAP
	end
	-- 길잡이(받을 수 있는 퀘스트): 중요한 것만일 때는 다음 메인 · 전직만(부탁은 뺀다)
	--  사용자 2026-10-13: "퀘스트 ui에 받을수있는 퀘스트 띄우지마세요  그건  퀘스트 버튼을 누르고 시작가능까지 들어가서 확인하는거지  왜 간편 ui에서 띄웁니까" → 알리미는 받은 것만 적는다(받을 수 있는 것은 퀘스트 창의 「시작 가능」)
	local guides = {}
	info.any = info.any or #guides > 0
	if size == Panel.MIN then
		-- 최소: 머리줄만(받은 것의 수는 머리줄의 「진행 N」에 남는다)
		info.hidden = #entries
		info.view = Panel.HEAD + 2
		return {}, Panel.HEAD + 2, 0, 0, info
	end
	for _, g in guides do
		if fold and g.kind == "side" then
			continue
		end
		if guided == 0 then
			table.insert(rows, { kind = "label", y = y, line = shown > 0 })
			y += LINE + 6
		else
			y += GAP - 2
		end
		guided += 1
		table.insert(rows, { kind = "guide", y = y, text = g.title, tone = g.kind, key = if g.kind ~= "level" then g.id else nil }) -- 레벨이 모자란 것은 아직 갈 데가 없다
		y += TITLE
		table.insert(rows, { kind = "where", y = y, text = g.line, tone = g.kind })
		y += LINE
	end
	if shown > 0 and guided == 0 then
		y -= GAP
	end
	local height = if shown + guided == 0 then Panel.HEAD + 2 else y + Panel.PAD
	local cap = maxH or Panel.H
	info.view = math.min(height, cap)
	info.scroll = height > cap
	return rows, height, shown, guided, info
end

return Panel
