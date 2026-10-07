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
		local t = Format.statTip(last.class, id, last.level)
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
		if body.AbsolutePosition.X / Stage.uiScale + left < 4 then
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
	local auto = Ui.button(body, "자동으로 찍기", 0, y, w, function()
		ctx.send("StatAuto")
	end, { main = true })
	y += Ui.M.button + 10
	Ui.line(body, 0, y, w)
	-- 전투력(왼쪽)과 체력(오른쪽)을 한 줄에
	local power = Ui.text(body, "", 0, y + 10, math.floor(w / 2), { color = C.gold })
	local hp = Ui.text(body, "", math.floor(w / 2), y + 10, w - math.floor(w / 2), { align = "right" })

	local view = {}
	function view.refresh(me)
		last = me
		local pair = STATS.classes[me.class]
		points:set(("남은 점수 %d"):format(me.ap))
		for _, id in STATS.order do
			local row = rows[id]
			local used = id == "hp" or id == pair[1] or id == pair[2]
			row.tag:set(if id == pair[1] then MARK.main elseif id == pair[2] then MARK.sub else "")
			row.value:set(tostring(STATS.base + me.stats[id]))
			row.name:color(if used then C.text else C.off)
			row.value:color(if used then C.text else C.off)
			row.plus:setEnabled(me.ap > 0)
		end
		auto:setEnabled(me.ap > 0)
		power:set(("전투력 %s"):format(Format.short(me.power)))
		hp:set(("체력 %s"):format(Format.short(me.maxHp)))
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
