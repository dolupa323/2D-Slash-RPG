-- 시퀀스 창(2026-10-30 사용자: "버프를 한버튼에 배치해서 한 버튼만 눌러서 버프를 사용할수있는 시퀀스 기능 … 메이플에 이미 있는 기능" → "버프 매크로가 아니라고 내가 시퀀스라고 말했잖아").
--  메이플스토리 「시퀀스」처럼: 스킬 창의 「시퀀스」 단추로 연다 · 탭 「스킬」 · 「버프」 · 시퀀스 아이콘 줄(스킬 10 · 버프 5 — 누르면 고르고 퀵슬롯이 반짝인다 · 끌어서 퀵슬롯에) ·
--  고른 시퀀스의 칸(앞 칸부터 쓰는 차례 — 누르면 뺀다) · 「비우기」 · 넣을 것(누르면 끝에 더한다). 바꾸면 서버에 "Sequence"(가지, 번호, 목록) — 서버가 거르고 내 상태(Self)로 돌려준다.
--  설명 칸(2026-10-30 사용자: "넣을스킬에 누르거나 하면 무슨스킬인지 보여야해 아이콘만보면 무슨스킬인지 알수가 없어"): 넣을 것 · 칸 · 시퀀스 아이콘에 마우스를 올리면 그것의 이름 · 갈래 · 설명이
--   창 아래의 설명 칸에 뜬다(폰은 마우스가 없으니 마지막으로 누른 것 — 마우스를 떼면 그것으로 돌아간다).
--  공방의 횡스크롤 시험 탭(js/lune/ui/paint.js의 paintSeq)과 같은 그림이다. 글 · 수는 UI.skillWords.seq · 셈은 sim/sequence.luau · 쓰기는 boot.luau runSeq
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local CLASSES = require(lune.data["classes.generated"])
local Items = require(lune.sim.items)
local Format = require(lune.ui.format)
local Seq = require(lune.sim.sequence)
local Quick = require(lune.ui.quick)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local SQ = Seq.DATA
local QWORDS = UI.quick.words
local SLOT = SQ.chip -- 칸 하나(그림 24 + 둘레)
local STEP = SLOT + SQ.chipGap
local CELL_STEP = SLOT + SQ.cellGap
local Y = SQ.y -- 줄마다의 높이(공방 paintSeq와 같다 — design/ui.js SKILLWORDS.seq.y)
local H = SQ.h
local SKILL = {} -- [스킬] = 설계의 한 줄(이름 · 갈래 · 설명) — 다섯 직업의 차수마다의 스킬(공용 포함)
for _, c in CLASSES.classes do
	for _, tier in c.tiers or {} do
		for _, sk in tier.skills or {} do
			SKILL[sk.id] = sk
		end
	end
end

local SeqWindow = {}

function SeqWindow.size(): (number, number)
	return SQ.w, H
end

local function picker(parent: Instance, x: number, y: number, w: number, h: number, name: string, onClick: () -> (), onPress: ((InputObject) -> ())?, onHover: ((boolean) -> ())?): TextButton
	local hit = Instance.new("TextButton")
	hit.Name = name
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Position = UDim2.fromOffset(x, y)
	hit.Size = UDim2.fromOffset(w, h)
	hit.ZIndex = 4
	hit.Parent = parent
	hit.Activated:Connect(onClick)
	if onPress then
		hit.InputBegan:Connect(onPress)
	end
	if onHover then
		hit.MouseEnter:Connect(function()
			onHover(true)
		end)
		hit.MouseLeave:Connect(function()
			onHover(false)
		end)
	end
	return hit
end

-- 넣은 것의 그림(아이템이면 그 아이템의 그림 · 스킬이면 스킬의 그림)
local function picOf(id: string): string
	return Quick.pic(id) or ("skill_" .. id)
end

function SeqWindow.build(body: Frame, ctx, w: number, h: number)
	local kind = "skill"
	local sel = { skill = 1, buff = 1 }
	local last = nil
	local full = false
	local hover, tapped = nil, nil -- 설명 칸에 보일 것: 이름표(스킬 · 아이템) 또는 "chip:번호"(시퀀스) — 마우스가 올라간 것이 먼저, 없으면 마지막으로 누른 것
	local view = {}
	local function hoverOf(what: string): (boolean) -> ()
		return function(on: boolean)
			hover = if on then what else (if hover == what then nil else hover)
			view.paintInfo()
		end
	end

	local function listOf(me, kd: string, k: number): { string }
		return (me and me.seqs and me.seqs[kd] and me.seqs[kd][k]) or {}
	end
	local function send(k: number, list: { string })
		ctx.send("Sequence", kind, k, list)
	end

	-- 탭: 「스킬」 · 「버프」(고른 것은 민트 글씨에 밑줄 — 스킬 창의 차수 탭과 같다)
	local tabs = {}
	for i, kd in Seq.KINDS do
		local x = (i - 1) * (SQ.tabW + SQ.tabGap)
		local label = Ui.text(body, SQ.tabs[kd], x, 0, SQ.tabW, { font = "body", align = "center", color = C.dim })
		local under = Ui.box(body, x, 15, SQ.tabW, 2, C.accent)
		picker(body, x, -4, SQ.tabW, 24, "Tab_" .. kd, function()
			if kind ~= kd then
				kind, full, hover, tapped = kd, false, nil, nil
				ctx.quick.pick(nil)
				view.paint()
			end
		end)
		tabs[kd] = { label = label, under = under }
	end
	local head = Ui.text(body, "", 0, Y.head, w, { color = C.dim })

	-- 시퀀스 아이콘 줄: 누르면 고르고 퀵슬롯이 반짝인다(한 번 더 누르면 그만둔다) · 끌면 퀵슬롯에(스킬 창의 스킬과 같다)
	local chips = {}
	for k = 1, math.max(Seq.N.skill, Seq.N.buff) do
		local x = (k - 1) * STEP
		local slot = Ui.slot(body, x, Y.chips, SLOT)
		local pic = Ui.pic(body, nil, x + 3, Y.chips + 3)
		pic.ZIndex = 2
		local num = Ui.text(body, tostring(k), x, Y.num, SLOT, { align = "center", color = C.dim })
		local hit = picker(body, x, Y.chips, SLOT, SLOT, "Chip" .. k, function()
			local id = Seq.id(kind, k)
			sel[kind], full, tapped = k, false, "chip:" .. k
			ctx.quick.pick(if ctx.quick.picked() == id then nil else id)
			view.paint()
		end, function(input: InputObject)
			ctx.quick.press(Seq.id(kind, k), nil, input)
		end, hoverOf("chip:" .. k))
		chips[k] = { slot = slot, pic = pic, num = num, hit = hit }
	end

	-- 고른 시퀀스: 이름 · 넣은 수 · 「비우기」 · 칸(앞 칸부터 쓰는 차례 — 누르면 뺀다)
	local name = Ui.text(body, "", 0, Y.sel, w - 140, { font = "body", color = C.accent })
	local count = Ui.text(body, "", w - 140, Y.sel + 2, 70, { color = C.dim, align = "right" })
	local clear = Ui.button(body, SQ.clear, w - 60, Y.sel - 2, 60, function()
		if #listOf(last, kind, sel[kind]) > 0 then
			full = false
			send(sel[kind], {})
		end
	end, { h = 20, font = "small" })
	clear.frame.Name = "Clear"
	local cells = {}
	for j = 1, math.max(Seq.SIZE.skill, Seq.SIZE.buff) do
		local x = ((j - 1) % SQ.per) * CELL_STEP
		local y = Y.cells + math.floor((j - 1) / SQ.per) * CELL_STEP
		local slot = Ui.slot(body, x, y, SLOT)
		local pic = Ui.pic(body, nil, x + 3, y + 3)
		pic.ZIndex = 2
		local hit = picker(body, x, y, SLOT, SLOT, "Cell" .. j, function()
			local list = listOf(last, kind, sel[kind])
			if list[j] then
				local next = table.clone(list)
				table.remove(next, j)
				full, tapped = false, list[j]
				view.paintInfo()
				send(sel[kind], next)
			end
		end, nil, function(on: boolean)
			local id = listOf(last, kind, sel[kind])[j]
			hover = if on and id then id else nil
			view.paintInfo()
		end)
		cells[j] = { slot = slot, pic = pic, hit = hit }
	end

	-- 넣을 것: 누르면 끝에 더한다(이미 든 것은 그대로 · 다 찼으면 알린다)
	local pickLabel = Ui.text(body, "", 0, Y.pick, w, { color = C.dim })
	local note = Ui.text(body, "", 0, Y.cands, w, { color = C.off }) -- 넣을 것이 없을 때
	-- 설명 칸: 이름(금빛) · 갈래(오른쪽) · 설명 두 줄
	Ui.box(body, 0, Y.info - 6, w, 1, C.line)
	local infoName = Ui.text(body, "", 0, Y.info, w - 100, { font = "body", color = C.gold })
	local infoTag = Ui.text(body, "", w - 100, Y.info + 2, 100, { color = C.dim, align = "right" })
	local infoText = Ui.text(body, "", 0, Y.info + 18, w, { color = C.text, lines = 2, line = Ui.M.smallLine })
	local quickAt = Ui.text(body, "", 0, h - Ui.M.small - 18, w, { color = C.dim })
	Ui.text(body, SQ.hint, 0, h - Ui.M.small - 2, w, { color = C.dim })
	local cands, candIds = {}, {}
	local function candCell(i: number)
		if cands[i] then
			return cands[i]
		end
		local x = ((i - 1) % SQ.per) * CELL_STEP
		local y = Y.cands + math.floor((i - 1) / SQ.per) * CELL_STEP
		local slot = Ui.slot(body, x, y, SLOT)
		local pic = Ui.pic(body, nil, x + 3, y + 3)
		pic.ZIndex = 2
		picker(body, x, y, SLOT, SLOT, "Cand" .. i, function()
			local id = candIds[i]
			if not id or not last then
				return
			end
			tapped = id
			view.paintInfo() -- (설명은 바로 — 칸은 서버가 돌려준 내 상태로 다시 그린다)
			local list = listOf(last, kind, sel[kind])
			if table.find(list, id) then
				return
			end
			if #list >= Seq.SIZE[kind] then
				full = true
				view.paint()
				return
			end
			local next = table.clone(list)
			table.insert(next, id)
			send(sel[kind], next)
		end, nil, function(on: boolean)
			hover = if on and candIds[i] then candIds[i] else nil
			view.paintInfo()
		end)
		cands[i] = { slot = slot, pic = pic }
		return cands[i]
	end

	-- 설명 칸: 다 찼다는 알림(빨강) → 마우스가 올라간 것 → 마지막으로 누른 것 → 안내(흐림)
	function view.paintInfo()
		local me = last
		local what = hover or tapped
		local title, tag, text, tone = "", "", SQ.info, C.dim
		if full then
			text, tone = Format.fill(SQ.full, { max = Seq.SIZE[kind] }), C.red
		elseif what and string.sub(what, 1, 5) == "chip:" then
			local k = tonumber(string.sub(what, 6)) :: number
			local list = listOf(me, kind, k)
			local names = {}
			for _, id in list do
				local g = Items.goods(id)
				table.insert(names, if g then g.name elseif SKILL[id] then SKILL[id].name else id)
			end
			title, tag = Seq.name(kind, k), Format.fill(SQ.count, { n = #list, max = Seq.SIZE[kind] })
			text, tone = if #names > 0 then table.concat(names, " → ") else SQ.blank, if #names > 0 then C.text else C.dim
		elseif what then
			local g = Items.goods(what)
			local sk = SKILL[what]
			if g then
				title, tag, text, tone = g.name, SQ.item, g.text or "", C.text
			elseif sk then
				local lv = me and me.skills and me.skills[what] or 0
				local typeName = CLASSES.types and CLASSES.types[sk.type] or ""
				title, tag, text, tone = sk.name, if lv > 0 then ("%s · Lv.%d"):format(typeName, lv) else typeName, sk.text or "", C.text
			end
		end
		infoName:set(title)
		infoTag:set(tag)
		infoText:set(text)
		infoText:color(tone)
	end

	function view.paint()
		local me = last
		if not me then
			return
		end
		for kd, t in tabs do
			t.label:color(if kd == kind then C.accent else C.dim)
			t.under.Visible = kd == kind
		end
		head:set(SQ.head[kind])
		local n, size, k = Seq.N[kind], Seq.SIZE[kind], sel[kind]
		for i, c in chips do
			local on = i <= n
			c.slot.frame.Visible = on
			c.hit.Visible = on
			c.num:show(on)
			if on then
				local list = listOf(me, kind, i)
				Ui.setPic(c.pic, if list[1] then picOf(list[1]) else "menu_skill")
				c.slot:setOn(i == k)
				c.num:color(if i == k then C.accent else C.dim)
			else
				c.pic.Visible = false
			end
		end
		local list = listOf(me, kind, k)
		name:set(Seq.name(kind, k))
		count:set(Format.fill(SQ.count, { n = #list, max = size }))
		for j, c in cells do
			local on = j <= size
			c.slot.frame.Visible = on
			c.hit.Visible = on
			if on then
				Ui.setPic(c.pic, if list[j] then picOf(list[j]) else nil)
			else
				c.pic.Visible = false
			end
		end
		local ids = Seq.candidates({ class = me.class, skills = me.skills }, kind)
		pickLabel:set(SQ.pick[kind])
		for i = 1, math.max(#ids, #cands) do
			local id = ids[i]
			if id then
				local cc = candCell(i)
				candIds[i] = id
				cc.slot.frame.Visible = true
				Ui.setPic(cc.pic, picOf(id))
				cc.slot:setOn(table.find(list, id) ~= nil)
			elseif cands[i] then
				candIds[i] = nil
				cands[i].slot.frame.Visible = false
				cands[i].pic.Visible = false
			end
		end
		note:set(if #ids == 0 then SQ.none[kind] else "")
		view.paintInfo()
		local q = ctx.quick.info(Seq.id(kind, k))
		local armed = ctx.quick.picked() == Seq.id(kind, k)
		quickAt:set(if armed then QWORDS.armed elseif q.key then Format.fill(QWORDS.at, { key = q.key }) else QWORDS.none)
		quickAt:color(if armed then C.accent elseif q.key then C.gold else C.dim)
	end

	function view.refresh(me)
		last = me
		view.paint()
	end

	function view.destroy()
		ctx.quick.pick(nil)
	end

	view.refresh(ctx.me())
	return view
end

return SeqWindow
