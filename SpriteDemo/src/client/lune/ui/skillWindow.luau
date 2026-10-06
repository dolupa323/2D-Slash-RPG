-- 스킬 창(넓은 창) — 왼쪽에 스킬 목록(이름 · 레벨 / 마스터 · + 단추)과 「추천대로 찍기」, 오른쪽에 고른 스킬의 설명.
--  올리는 것은 서버에 부탁한다(SkillUp · SkillAuto). 지금은 1차 스킬만 있다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local CLASSES = require(lune.data["classes.generated"])
local Kit = require(script.Parent.kit)

local C = Kit.COLOR
local TYPE = { mob = "사냥기", boss = "보스기", move = "이동기", core = "핵심 장치", passive = "패시브", toggle = "사출기", buff = "버프" }

local SkillWindow = { wide = true, height = 150 }

function SkillWindow.build(body: Frame, ctx, w: number, h: number)
	local half = math.floor(w / 2)
	local points = Kit.text(body, "", 6, 2, half - 12 - 76, { color = C.yellow })
	local rows = {}
	local list = {}
	local selected = 1
	-- 오른쪽: 고른 스킬의 그림 · 이름 · 갈래와 레벨 · 설명
	Kit.part(body, "socketCell", half + 6, 2)
	local detailIcon = Kit.icon(body, nil, half + 7, 3)
	local detailName = Kit.text(body, "", half + 30, 2, half - 36, { color = C.yellow })
	local detailType = Kit.text(body, "", half + 30, 13, half - 36, { color = C.dim })
	local detailText = Kit.text(body, "", half + 6, 28, half - 12, { lines = 8 })
	Kit.box(body, half, 0, 1, h, C.edgeDim)

	local view = {}
	local last = nil
	local function showDetail(me)
		local sk = list[selected]
		if not sk then
			return
		end
		local lv = me.skills[sk.id] or 0
		Kit.setIcon(detailIcon, if Kit.hasIcon("skill_" .. sk.id) then "skill_" .. sk.id else "star")
		detailName:set(sk.name)
		detailType:set(("%s · Lv.%d / %d"):format(TYPE[sk.type] or sk.type, lv, sk.max))
		detailText:set(sk.text)
		for i, row in rows do
			row.back.BackgroundTransparency = if i == selected then 0 else 1
		end
	end

	function view.refresh(me)
		last = me
		if #rows == 0 then
			-- 처음: 직업의 스킬 목록으로 줄을 만든다
			list = CLASSES.classes[me.class].skills
			local y = 15
			for i, sk in list do
				local back = Kit.box(body, 2, y, half - 4, 20, C.trough, 1)
				Kit.part(body, "socketCell", 4, y)
				-- 그림이 아직 없는 스킬(패시브 · 핵심 장치)은 별 그림으로
				Kit.icon(body, if Kit.hasIcon("skill_" .. sk.id) then "skill_" .. sk.id else "star", 5, y + 1)
				local name = Kit.text(body, sk.name, 28, y + 5, 70)
				local level = Kit.text(body, "", 100, y + 5, 40, { align = "right" })
				local plus = Kit.button(body, "+", half - 22, y + 3, 16, 13, function()
					selected = i
					ctx.send("SkillUp", sk.id)
				end)
				-- 줄을 누르면 설명을 본다
				local hit = Instance.new("TextButton")
				hit.Text = ""
				hit.BackgroundTransparency = 1
				hit.Position = UDim2.fromOffset(2, y)
				hit.Size = UDim2.fromOffset(half - 26, 20)
				hit.ZIndex = 4
				hit.Parent = body
				hit.Activated:Connect(function()
					selected = i
					if last then
						showDetail(last)
					end
				end)
				rows[i] = { back = back, name = name, level = level, plus = plus }
				y += Kit.PITCH
			end
			view.auto = Kit.button(body, "추천대로 찍기", half - 78, 0, 74, 13, function()
				ctx.send("SkillAuto")
			end, { kind = "orange" })
		end
		points:set(("스킬 포인트 %d"):format(me.sp))
		for i, sk in list do
			local lv = me.skills[sk.id] or 0
			rows[i].level:set(("%d/%d"):format(lv, sk.max))
			rows[i].name:color(if lv > 0 then C.white else C.dim)
			rows[i].plus:setEnabled(me.sp > 0 and lv < sk.max)
		end
		view.auto:setEnabled(me.sp > 0)
		showDetail(me)
	end
	return view
end

return SkillWindow
