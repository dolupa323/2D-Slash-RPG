-- 능력치 창 — 남은 점수, 다섯 능력치와 + 단추, 「자동으로 찍기」, 아래에 전투력과 체력.
--  찍는 것은 서버에 부탁한다(StatAdd · StatAuto). 서버가 내 상태를 다시 보내면 고쳐 그린다. 화면 오른쪽의 옆 판(ui/windows.luau).
--  능력치에 마우스를 올리면(터치는 그 줄을 누르면) 창 옆에 설명 판이 뜬다 — 그 직업에게 무엇을 해 주는지와 지금 레벨에서 1점에 얼마가 오르는지.
--   사용자 2026-10-07: "능력치에 각각 스텟별로 마우스 올리면 호버로 스텟 효과를 보여줘야합니다. 뭔지알고 스텟을찍으라는건지"
--   글과 숫자는 shared/lune/ui/format.luau의 statTip(공방의 횡스크롤 시험 탭 — js/lune/ui/paint.js의 paintStat · tipPanel과 같은 그림). 이 직업이 안 쓰는 능력치는 이름이 흐리다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local N = require(ReplicatedStorage.shared.lune.config.numbers)
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Titles = require(ReplicatedStorage.shared.lune.sim.titles) -- 칭호(2026-10-26)
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)

local STATS = N.data.STATS
local C = Ui.COLOR
local S = Layout.STAT
local TIP = S.tip
local MARK = UI.statTip.marks
local TIPCOLOR = { main = C.gold, sub = C.accent, none = C.dim, hp = C.text }

local StatWindow = {}

function StatWindow.size(): (number, number)
	return Layout.statBody(#STATS.order)
end

function StatWindow.build(body: Frame, ctx, w: number, _h: number)
	local points = Ui.text(body, "", 0, 0, w, { color = C.gold })
	local rows = {}
	local last = nil -- 마지막으로 받은 내 상태
	local tip = nil -- 떠 있는 설명 판 { frame, id }

	local function hideTip()
		if tip then
			tip.frame:Destroy()
			rows[tip.id].back.Visible = false
			tip = nil
		end
	end

	-- 설명 판: 칸과 같은 판에 제목(주 노랑 · 부 민트 · 안 쓰는 것 흐림) · 그 옆의 꼬리표 · 글 줄들. 창의 왼쪽에 붙인다(창이 화면 왼쪽에 있으면 오른쪽에)
	local function showTip(id: string)
		if not last or (tip and tip.id == id) then
			return
		end
		hideTip()
		local sh = last.sheet
		local t = Format.statTip(last.class, id, last.level, if sh then sh.attack * (1 + sh.dmg / 100) * (1 + sh.final / 100) else nil) -- 1점의 값 = 스탯 공격력이 오르는 만큼(지금 낀 무기로 — 2026-10-15)
		local color = TIPCOLOR[t.kind]
		local inner = TIP.w - TIP.pad * 2
		local frame = Ui.group(body, 0, 0, TIP.w, 10, "Tip")
		frame.ZIndex = 20
		local back = Ui.part(frame, "uTip", 0, 0, TIP.w, 10)
		local title = Ui.text(frame, t.title, TIP.pad, TIP.pad, inner, { font = "body", color = color })
		if t.tag ~= "" then
			local tw = title:size()
			Ui.text(frame, t.tag, TIP.pad + tw + 8, TIP.pad + 2, inner - tw - 8, { color = color })
		end
		local y = TIP.pad + TIP.title
		for i, line in t.lines do
			local tint = if i > 1 then (if t.kind == "none" then C.dim else C.accent) elseif t.kind == "none" then C.red else C.text
			local label = Ui.text(frame, line, TIP.pad, y, inner, { lines = TIP.lines, line = TIP.line, color = tint })
			local _, lh = label:size()
			y += math.max(1, math.floor(lh / TIP.line + 0.5)) * TIP.line
		end
		local h = y - (TIP.line - Ui.M.small) + TIP.pad
		frame.Size = UDim2.fromOffset(TIP.w, h)
		back.Size = UDim2.fromOffset(TIP.w, h)
		local left = -Ui.WIN.pad - TIP.gap - TIP.w
		-- 기준 격자 안의 자리로 잰다(화면이 넓으면 기준 격자 양옆에 검은 띠가 있다 — 2026-10-18 검토: 띠의 폭까지 더해 설명이 띠 속으로 나가 안 보였다)
		if (body.AbsolutePosition.X - Stage.ui.AbsolutePosition.X) / Stage.uiScale + left < 4 then
			left = w + Ui.WIN.pad + TIP.gap -- 왼쪽에 자리가 없다(창이 화면 왼쪽에 있다)
		end
		frame.Position = UDim2.fromOffset(left, rows[id].y - 2)
		rows[id].back.Visible = true
		tip = { frame = frame, id = id }
	end

	local y = S.top
	for _, id in STATS.order do
		local ty = y + math.floor((Ui.M.button - Ui.M.body) / 2)
		local back = Ui.box(body, -6, y - 2, w - S.plusW, S.row, C.panel2)
		back.Name = "Hot"
		back.Visible = false
		local name = Ui.text(body, STATS.names[id], 0, ty, S.tagX - 4, { font = "body" })
		local tag = Ui.text(body, "", S.tagX, ty + 1, 30, { color = C.accent })
		local value = Ui.text(body, "", S.tagX + 32, ty, w - S.tagX - 32 - S.valueRight, { font = "body", align = "right" })
		local plus = Ui.button(body, "+", w - S.plusW, y, S.plusW, function()
			ctx.send("StatAdd", id, 1)
		end)
		-- 줄에 마우스를 올리면 설명이 뜨고, 벗어나면 사라진다. 터치는 줄을 누르면 뜨고 한 번 더 누르면 사라진다
		local over = Instance.new("TextButton")
		over.Name = "Over_" .. id
		over.Text = ""
		over.BackgroundTransparency = 1
		over.Position = UDim2.fromOffset(-6, y - 2)
		over.Size = UDim2.fromOffset(w - S.plusW, S.row)
		over.ZIndex = 8
		over.Parent = body
		over.MouseEnter:Connect(function()
			showTip(id)
		end)
		over.MouseLeave:Connect(function()
			if tip and tip.id == id then
				hideTip()
			end
		end)
		over.Activated:Connect(function(input)
			if input and input.UserInputType == Enum.UserInputType.Touch and tip and tip.id == id then
				hideTip()
			else
				showTip(id)
			end
		end)
		rows[id] = { name = name, tag = tag, value = value, plus = plus, back = back, y = y }
		y += S.row
	end
	y += 4
	-- 「자동으로 찍기」 옆에 「초기화」(공짜 · 몇 번이든 — 2026-10-21 사용자: "스텟, 스킬 초기화 완전무료로 풀겠습니다"). 잘못 누르지 않게 두 번 눌러야 한다(「정말 초기화?」 — 3초 안에 · 스킬 창과 같다)
	local resetW = S.resetW
	local auto = Ui.button(body, "자동으로 찍기", 0, y, w - resetW - 6, function()
		ctx.send("StatAuto")
	end, { main = true })
	StatWindow.autoFrame = auto.frame -- 튜토리얼(꿈)의 「능력치 찍기」 미션에서 반짝인다(2026-10-14)
	local resetArmed = 0
	local reset
	reset = Ui.button(body, "초기화", w - resetW, y, resetW, function()
		if os.clock() - resetArmed < 3 then
			resetArmed = 0
			reset:setText("초기화")
			ctx.send("StatReset")
		else
			resetArmed = os.clock()
			reset:setText("정말 초기화?")
			task.delay(3.1, function()
				if os.clock() - resetArmed >= 3 then
					reset:setText("초기화")
				end
			end)
		end
	end)
	reset.frame.Name = "Do_statReset"
	y += Ui.M.button + 10
	Ui.line(body, 0, y, w)
	-- 전투력(왼쪽)과 체력(오른쪽)을 한 줄에
	local power = Ui.text(body, "", 0, y + 10, math.floor(w / 2), { color = C.gold })
	local hp = Ui.text(body, "", math.floor(w / 2), y + 10, w - math.floor(w / 2), { align = "right" })
	-- 칭호(2026-10-26 — sim/titles.luau): 「칭호」 · 단 칭호의 이름(그 색 · 없으면 「없음」) · 「바꾸기」 = 없음 → 가진 칭호를 높은 차례로 → 없음. 가진 칭호가 없으면 단추가 꺼진다
	local TW = Titles.WORDS
	local ty = y + 10 + S.titleTop
	local titleLabel = Ui.text(body, TW.label, 0, ty + math.floor((Ui.M.button - Ui.M.body) / 2), S.tagX - 4, { font = "body", color = C.dim })
	local titleName = Ui.text(body, "", S.tagX, ty + math.floor((Ui.M.button - Ui.M.body) / 2), w - S.tagX - S.resetW - 6, { font = "body" })
	local change = Ui.button(body, TW.change, w - S.resetW, ty, S.resetW, function()
		if not last then
			return
		end
		local list = last.titles or {}
		local nextId = if not last.title then list[1] else list[(table.find(list, last.title) or 0) + 1]
		ctx.send("Title", nextId or "")
	end)
	change.frame.Name = "Do_title"
	titleLabel.label.Frame.Name = "TitleLabel" -- (글 칸은 frame이 없다 — label.Frame. 2026-10-26: titleLabel.frame으로 적어 창을 짓다 멈춰 능력치 창이 비었다)

	local view = {}
	function view.refresh(me)
		last = me
		local pair = STATS.classes[me.class]
		points:set(("남은 점수 %d"):format(me.ap))
		for _, id in STATS.order do
			local row = rows[id]
			local used = id == "hp" or id == pair[1] or id == pair[2]
			row.tag:set(if id == pair[1] then MARK.main elseif id == pair[2] then MARK.sub else "")
			row.value:set(tostring(if me.sheet and me.sheet.stats then me.sheet.stats[id] else STATS.base + me.stats[id])) -- 처음 4 + 찍은 점수 + 장비의 올스탯(2026-10-15)
			row.name:color(if used then C.text else C.off)
			row.value:color(if used then C.text else C.off)
			row.plus:setEnabled(me.ap > 0)
		end
		auto:setEnabled(me.ap > 0)
		local spent = false
		for _, n in me.stats do
			spent = spent or n > 0
		end
		reset:setEnabled(spent) -- 찍은 능력치가 있을 때만
		power:set(("전투력 %s"):format(Format.short(me.power)))
		hp:set(("최대 체력 %s"):format(Format.short(me.maxHp))) -- 「체력」은 능력치의 이름이라 「최대 체력」(2026-10-15)
		local worn = Titles.def(me.title)
		titleName:set(if worn then worn.name else TW.none)
		titleName:color(if worn then Titles.tint(worn, C) else C.off)
		change:setEnabled(me.titles ~= nil and #me.titles > 0)
		-- 떠 있는 설명은 새 값으로(레벨이 오르면 1점의 값이 달라진다)
		if tip then
			local id = tip.id
			hideTip()
			showTip(id)
		end
	end
	-- 설명 판을 띄운다 · 지운다(시험 · 화면 확인용)
	view.showTip, view.hideTip = showTip, hideTip
	return view
end

return StatWindow
