-- 퀘스트 알리미 — 늘 보이는 화면의 오른쪽 위(공방 「기본 · UI」 탭의 화면 배치, data/ui.generated.luau의 hud.quest).
--  사용자 2026-10-11: "지금 우측 상단에 있는 퀘스트 퀘스트라는 인식이 되지가 않아요 ui 만들어서 퀘스트처럼 보이게하세요" — 전에는 판 없이 글만 오른쪽에 붙여 적었다.
--  이제는 창과 같은 어두운 판 위에(메이플스토리의 퀘스트 알리미처럼):
--   ① 머리줄: 「!」 그림 + 「퀘스트」 + 오른쪽에 「진행 N」
--   ② 하는 중인 퀘스트(전직 → 메인 → 부탁): 갈래의 표(「메인」 노랑 · 「전직」 민트 · 「부탁」 회색) + 이름 / 할 일마다 왼쪽에 글 · 오른쪽에 「3/8」 · 그 아래 진행 띠.
--      다 했으면 「?」 그림 + 「샛별에게 간다」(풀빛)
--   ③ 받을 수 있는 퀘스트(길잡이 — sim/quests.luau의 Q.guide): 가르는 줄 아래에 「받을 수 있는 퀘스트」, 「! 이름」과 「샛별에게 받는다 · 초승달 마을」(레벨이 모자라면 흐리게 「Lv.4부터 받는다」)
--  ④ 길찾기 단추(사용자 2026-10-13: "각각 퀘스트마다  간단한 화살표 버튼 생기게해서  그 버튼 누르면  길찾기"): 퀘스트마다 이름 줄의 오른쪽 끝에 작은 화살표 단추.
--      누르면 그 퀘스트의 길찾기가 켜지고(민트 — 다시 누르면 꺼진다 · 한 번에 하나) 캐릭터 머리 위에 가야 할 쪽의 화살표가 뜬다(셈 shared/lune/ui/navi.luau · 그림 naviArrow.luau)
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
QuestHud.any = false -- 적을 것이 있는가(어느 모습에서든 — 없으면 판이 없다)
QuestHud.navi = nil :: string? -- 길찾기를 켠 줄(퀘스트의 이름표 · 일일 의뢰의 이름표)
QuestHud.onNavi = nil :: any -- 길찾기 단추를 눌렀을 때 (이름표)
QuestHud.NAV_ARROW = { { 0, 2, 5, 3 }, { 5, 0, 1, 7 }, { 6, 1, 1, 5 }, { 7, 2, 1, 3 }, { 8, 3, 1, 1 } } -- 단추 안의 오른쪽 화살표(9x7 — 네모들 { x, y, w, h })
QuestHud.size = Panel.SIZE_FIRST -- 알리미의 크기: 최소(머리줄만) · 중간(중요한 것만 — 처음) · 최대(모두). 머리줄의 「−」 · 「+」로 한 단계씩. 이번 접속 동안 이어진다
QuestHud.list = nil :: any -- 스크롤하는 칸
QuestHud.scrollY = 0 -- 스크롤한 자리(다시 그려도 — 몬스터를 잡아 숫자가 오를 때마다 다시 그린다 — 그 자리에 머문다)
QuestHud.total = 0 -- 받은 것의 수(퀘스트 + 일일 의뢰)
QuestHud.glow = nil :: Frame? -- 켠 길찾기 단추의 빛(QuestHud.step이 밝기를 오르내린다)
QuestHud.GLOW = { speed = 5, min = 0.15, max = 0.75 } -- 빛의 빠르기 · 가장 진할 때와 옅을 때의 비침
local last = nil :: any -- 마지막으로 그린 것(접기 단추 · 격자가 바뀌었을 때 다시 그린다)

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
	-- 창 크기가 바뀌어 격자가 달라지면 판이 쓸 수 있는 높이도 달라진다
	if Stage.onResize then
		Stage.onResize(function()
			QuestHud.redraw()
		end)
	end
end

-- 마지막에 그린 것을 다시 그린다(접기 · 펴기 · 격자가 바뀜)
function QuestHud.redraw()
	if last then
		QuestHud.set(last[1], last[2], last[3], last[4])
	end
end

-- 켠 길찾기 단추가 빛난다(그리는 고리가 장마다 부른다 — clock = 흐른 시간)
function QuestHud.step(clock: number)
	local glow = QuestHud.glow
	if glow and glow.Parent then
		local g = QuestHud.GLOW
		glow.BackgroundTransparency = g.min + (g.max - g.min) * (math.sin(clock * g.speed) + 1) / 2
	end
end

function QuestHud.setTouch(on: boolean)
	QuestHud.touch = on
	place()
end

-- 오른쪽 끝에 창이 떴다 · 닫혔다: 창의 바탕이 살짝 비쳐서(ui.js의 panelAlpha) 알리미의 글이 창의 글 뒤로 비쳐 보인다 — 덮인 동안은 감춘다
function QuestHud.setCovered(on: boolean)
	QuestHud.covered = on
	if QuestHud.box then
		QuestHud.box.Visible = not on and QuestHud.any == true
	end
end

-- 버프가 뜨고 사라졌다(켜 둔 사출기 · 영혼 · 열기)
function QuestHud.setBuffs(on: boolean)
	if QuestHud.buffs ~= on then
		QuestHud.buffs = on
		place()
	end
end

-- 길찾기 단추: 줄(y)의 오른쪽 끝에. 꺼져 있으면 어두운 바탕에 밝은 화살표(원래 색).
--  켜면 빛난다(사용자 2026-10-13: "길찾기 활성화되면  빛나고   다시눌러서 비활성화하면 원래색으로 되는형식"): 민트 바탕 + 위쪽의 밝은 줄 + 어두운 화살표, 둘레에 밝은 빛이 번지고 그 빛이 밝아졌다 옅어졌다 한다.
--  누르는 자리는 그림보다 넓다(손가락)
local function naviButton(panel: Instance, y: number, key: string)
	local on = QuestHud.navi == key
	local x = Panel.PAD + Panel.INNER - Panel.NAV_W
	if on then
		local glow = Ui.box(panel, x - 2, y - 2, Panel.NAV_W + 4, Panel.NAV_H + 4, C.accentHot, QuestHud.GLOW.min)
		glow.Name = "NaviGlow"
		QuestHud.glow = glow
	end
	local btn = Ui.box(panel, x, y, Panel.NAV_W, Panel.NAV_H, if on then C.accent else C.panel2)
	btn.Name = "Navi_" .. key
	if on then
		Ui.box(btn, 0, 0, Panel.NAV_W, 2, C.accentHot).Name = "Shine"
	end
	local ox, oy = math.floor((Panel.NAV_W - 9) / 2), math.floor((Panel.NAV_H - 7) / 2)
	for _, r in QuestHud.NAV_ARROW do
		Ui.box(btn, ox + r[1], oy + r[2], r[3], r[4], if on then C.ink else C.text).Name = "Arrow"
	end
	local hit = Ui.group(panel, x - 4, y - 3, Panel.NAV_W + 8, Panel.NAV_H + 6, "NaviHit")
	hit.ZIndex = 8
	Ui.hit(hit).Activated:Connect(function()
		if QuestHud.onNavi then
			QuestHud.onNavi(key)
		end
	end)
end

-- 크기를 바꾸는 단추 둘: 머리줄의 오른쪽 끝에 「−」 · 「+」. 「−」 = 한 단계 줄인다(최대 → 중간 → 최소), 「+」 = 한 단계 늘린다(최소 → 중간 → 최대).
--  더 줄일 · 늘릴 수 없는 쪽의 단추는 흐리게 남는다(자리가 바뀌지 않게 — 잇달아 누르기 쉽다)
local function sizeButton(panel: Instance, plus: boolean)
	local x = Panel.PAD + Panel.INNER - Panel.FOLD_W - (if plus then 0 else Panel.FOLD_W + Panel.FOLD_BETWEEN)
	local y = math.floor((Panel.HEAD - Panel.FOLD_H) / 2) + 1
	local can = if plus then QuestHud.size < Panel.MAX else QuestHud.size > Panel.MIN
	local btn = Ui.box(panel, x, y, Panel.FOLD_W, Panel.FOLD_H, C.panel2)
	btn.Name = if plus then "FoldPlus" else "FoldMinus"
	local ink = if can then C.text else C.line
	local cx, cy = math.floor(Panel.FOLD_W / 2), math.floor(Panel.FOLD_H / 2)
	Ui.box(btn, cx - 3, cy, 7, 1, ink).Name = if can then "Bar" else "BarOff"
	if plus then
		Ui.box(btn, cx, cy - 3, 1, 7, ink).Name = if can then "Bar" else "BarOff"
	end
	if not can then
		return
	end
	-- 누르는 자리: 위아래로는 넉넉히, 옆으로는 두 단추가 겹치지 않게 사이의 절반까지만
	local side = math.floor(Panel.FOLD_BETWEEN / 2)
	local hit = Ui.group(panel, x - (if plus then side else Panel.FOLD_HIT.x), y - Panel.FOLD_HIT.y, Panel.FOLD_W + side + Panel.FOLD_HIT.x, Panel.FOLD_H + Panel.FOLD_HIT.y * 2, if plus then "PlusHit" else "MinusHit")
	hit.ZIndex = 8
	Ui.hit(hit).Activated:Connect(function()
		QuestHud.size = math.clamp(QuestHud.size + (if plus then 1 else -1), Panel.MIN, Panel.MAX)
		QuestHud.scrollY = 0 -- 크기를 바꾸면 맨 위부터
		if QuestHud.list then
			QuestHud.list.CanvasPosition = Vector2.new(0, 0)
		end
		QuestHud.redraw()
	end)
end

-- book = 내 퀘스트의 상태 · names = 주민 id → 이름 · level = 내 레벨(길잡이를 셈한다 — 안 주면 길잡이를 적지 않는다) · daily = 받아 둔 일일 의뢰들(sim/daily.luau의 tracked)
function QuestHud.set(book, names, level: number?, daily: any?)
	local box = QuestHud.box
	-- 스크롤한 자리를 기억해 둔다(아래에서 다시 그린 뒤 그 자리로)
	if QuestHud.list and QuestHud.list.Parent then
		QuestHud.scrollY = QuestHud.list.CanvasPosition.Y
	end
	QuestHud.list = nil
	for _, child in box:GetChildren() do
		child:Destroy()
	end
	last = { book, names, level, daily }
	QuestHud.glow = nil
	local maxH = Panel.maxH(Stage.uiH, QuestHud.touch)
	local rows, height, shown, guided, info = Panel.layout(book or {}, names, level, maxH, daily, QuestHud.size)
	QuestHud.shown = shown
	QuestHud.guided = guided
	QuestHud.total = info.total
	-- 적을 것이 하나도 없으면(어느 크기에서든) 판도 없다. 최소이거나, 중간인데 부탁만 받아 두었으면 머리줄(「진행 N」 · 단추)만 남는다
	QuestHud.any = info.any
	box.Visible = info.any and not QuestHud.covered
	if not info.any then
		return
	end
	local W, PAD, INNER = Panel.W, Panel.PAD, Panel.INNER
	local panel = Ui.panel(box, 0, 0, W, info.view)
	-- ① 머리줄
	local mark = Kit.part(panel, QuestHud.MARK.new, PAD, 0)
	mark.Position = UDim2.fromOffset(PAD, math.floor((Panel.HEAD - mark.Size.Y.Offset) / 2) + 1)
	local headX = PAD + mark.Size.X.Offset + 5
	Ui.text(panel, "퀘스트", headX, 5, INNER - (headX - PAD), { font = "body", color = C.gold })
	if info.total > 0 then
		Ui.text(panel, ("진행 %d"):format(info.total), PAD, 7, INNER - Panel.FOLD_W * 2 - Panel.FOLD_BETWEEN - Panel.FOLD_GAP, { align = "right", color = C.dim })
	end
	sizeButton(panel, false)
	sizeButton(panel, true)
	if shown + guided == 0 then
		return
	end
	Ui.box(panel, PAD, Panel.HEAD, INNER, 1, C.lineHot).Name = "HeadLine"
	-- ② · ③ 스크롤하는 칸 안에(적은 것이 판보다 길 때만 스크롤한다 — 오른쪽 끝에 가는 막대)
	local top = Panel.LIST_TOP
	local winH, allH = info.view - top - Panel.LIST_BOTTOM, height - top - Panel.LIST_BOTTOM
	local list = Ui.scroll(panel, 0, top, W, winH, allH, Panel.SCROLL_W)
	QuestHud.list = list
	QuestHud.scrollY = math.clamp(QuestHud.scrollY, 0, math.max(0, allH - winH))
	list.CanvasPosition = Vector2.new(0, QuestHud.scrollY)
	for _, row in rows do
		local ry = row.y - top
		if row.kind == "quest" then
			local tint = if row.tag == "main" then C.gold elseif row.tag == "job" then C.accent else C.lineHot
			local chip = Ui.box(list, PAD, ry + 1, Panel.TAG_W, 13, tint)
			chip.Name = "Tag"
			Ui.text(chip, Panel.TAGS[row.tag] or "부탁", 0, 1, Panel.TAG_W, { align = "center", color = if row.tag == "side" then C.text else C.ink })
			local nameX = PAD + Panel.TAG_W + Panel.TAG_GAP
			Ui.text(list, row.name, nameX, ry, if row.key then Panel.NAME_W else INNER - Panel.TAG_W - Panel.TAG_GAP, { font = "body", color = if row.tag == "main" then C.gold elseif row.tag == "job" then C.accent else C.text })
			if row.key then
				naviButton(list, ry, row.key)
			end
		elseif row.kind == "step" then
			Ui.text(list, row.text, PAD + 2, ry, INNER - 2 - Panel.COUNT_W, { color = C.text })
			Ui.text(list, row.count, PAD, ry, INNER, { align = "right", color = C.accent })
			local bar = Ui.bar(list, PAD + 2, ry + LINE - 1, INNER - 2, Panel.BAR_H, C.accent, C.panel2)
			bar:set(row.have / math.max(1, row.n))
		elseif row.kind == "ready" then
			local done = Kit.part(list, QuestHud.MARK.done, PAD + 2, ry)
			done.Position = UDim2.fromOffset(PAD + 2, ry + math.floor((LINE - done.Size.Y.Offset) / 2))
			local tx = PAD + 2 + done.Size.X.Offset + 4
			Ui.text(list, row.text, tx, ry, INNER - (tx - PAD), { color = C.green })
		elseif row.kind == "label" then
			if row.line then
				Ui.box(list, PAD, ry, INNER, 1, C.line).Name = "GuideLine"
			end
			Ui.text(list, "받을 수 있는 퀘스트", PAD, ry + (if row.line then 5 else 1), INNER, { color = C.dim })
		elseif row.kind == "guide" then
			-- 받을 수 있는 전직 퀘스트(job)는 민트(「전직」 표의 색) · 다음 메인(open)은 금빛 · 부탁(side)은 흰색 · 레벨이 모자란 것(level)은 흐리게
			Ui.text(list, row.text, PAD, ry, if row.key then Panel.GUIDE_W else INNER, { font = "body", color = if row.tone == "job" then C.accent elseif row.tone == "open" then C.gold elseif row.tone == "side" then C.text else C.dim })
			if row.key then
				naviButton(list, ry, row.key)
			end
		elseif row.kind == "where" then
			Ui.text(list, row.text, PAD + 2, ry, INNER - 2, { color = if row.tone == "level" then C.dim else C.accent })
		end
	end
end

return QuestHud
