-- 스킬 창(넓은 창) — 위에 차수 탭(로마 숫자 I · II · III · IV — 사용자 2026-10-07: "1차 이렇게 적지말고 로마자로 적으세요 차 라는말 빼고"), 그 아래 그 차수의 스킬들(두 줄로 — 그림 · 이름 · 레벨 / 마스터 · + 단추)과 「추천대로 찍기」, 오른쪽에 고른 스킬의 설명.
--  사용자 2026-10-07: "스킬창에 차수 탭이 없습니다. 1,2,3,4 차 스킬 탭이있어야지 지금뭐가뭔지" · "패시브든 뭐든 다 아이콘이 있는거에요"(별 그림으로 때우던 것을 없앴다 — 스킬마다 제 그림이 있다)
--  공방의 횡스크롤 시험 탭(js/lune/ui/paint.js의 paintSkill)과 같은 그림이다. 치수는 Layout.SKILL · 글은 UI.skillWords · 스킬은 CLASSES.classes[직업].tiers(차수마다).
--  퀵슬롯에 놓기(사용자 2026-10-07: "스킬키를 단축키에 등록하기 쉬워야합니다"): 스킬을 끌어다 화면 아래의 칸에 놓거나, 스킬을 누른 뒤 반짝이는 칸을 누른다 — ctx.quick(ui/quickEdit.luau)이 맡는다.
--   설명 칸의 맨 아래 두 줄에 그 스킬이 놓인 칸(「퀵슬롯 Q」)과 놓는 법을 적는다.
--  올리는 것은 서버에 부탁한다(SkillUp · SkillAuto). 아직 전직하지 않은 차수는 볼 수만 있다(+ 단추가 꺼져 있고, 언제 배우는지를 적는다). 화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local CLASSES = require(lune.data["classes.generated"])
local UI = require(lune.data["ui.generated"])
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.SKILL
local WORDS = UI.skillWords
local QWORDS = UI.quick.words
local BONUS = require(lune.data["combat.generated"]).rules.targetBonus -- 사냥기 · 보스기가 맞는 상대에게 더 주는 피해(%)
local TYPES = CLASSES.types

local SkillWindow = { wide = true }

function SkillWindow.size(): (number, number)
	local w, h = Layout.skillBody()
	return w, h
end

-- 지금 레벨에서 열린 차수(전직이 생기면 내 상태의 차수를 쓴다)
function SkillWindow.jobOf(me): number
	if me.job then
		return me.job
	end
	local job = 1
	for _, j in CLASSES.jobs do
		if j.lv <= me.level then
			job = math.max(job, j.job)
		end
	end
	return job
end

-- 누르는 자리. onPress = 누르기 시작했을 때(끌기의 시작 — 없어도 된다)
local function picker(parent: Instance, x: number, y: number, w: number, h: number, name: string, onClick: () -> (), onPress: ((InputObject) -> ())?): TextButton
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
	return hit
end

function SkillWindow.build(body: Frame, ctx, _w: number, h: number)
	local _, _, listW = Layout.skillBody()
	local tiers = nil -- 내 직업의 차수들 { { job, lv, skills } … }
	local names = {} -- [스킬] = 이름(앞 차수의 기술을 잇는 스킬의 설명에 쓴다)
	local tab, selected = 1, 1
	local last = nil
	local tabs = {}
	local view = {}

	local points = Ui.text(body, "", listW - 160, 2, 160, { color = C.gold, align = "right" })
	local info = Ui.text(body, "", 0, S.infoY + 6, listW - S.autoW - 8, {})
	local auto = Ui.button(body, WORDS.auto, listW - S.autoW, S.infoY, S.autoW, function()
		ctx.send("SkillAuto")
	end, { main = true, h = 22, font = "small" })

	-- 스킬 칸들(cols x rows)을 미리 만들어 두고, 탭에 따라 채운다
	local cells = {}
	local nameW = S.colW - S.slot - 8 - S.plusW - 4
	for i = 1, S.cols * S.rows do
		local holder = Ui.group(body, ((i - 1) % S.cols) * (S.colW + S.colGap), S.top + math.floor((i - 1) / S.cols) * S.row, S.colW, S.row, "Skill" .. i)
		local cell = Ui.slot(holder, 0, 0, S.slot)
		local pic = Ui.pic(holder, nil, 3, 3)
		pic.ZIndex = 2
		local name = Ui.text(holder, "", S.slot + 8, 2, nameW, { font = "body" })
		local level = Ui.text(holder, "", S.slot + 8, 18, nameW, { color = C.dim })
		local plus = Ui.button(holder, "+", S.colW - S.plusW, 2, S.plusW, function()
			local sk = tiers and tiers[tab].skills[i]
			if sk then
				selected = i
				ctx.send("SkillUp", sk.id)
				view.paint()
			end
		end)
		-- 칸을 누르면 오른쪽에 설명이 나오고, 퀵슬롯에 놓을 수 있는 스킬이면 칸들이 반짝인다(한 번 더 누르면 그만둔다). 누른 채 움직이면 끌기
		picker(holder, 0, 0, S.colW - S.plusW - 4, S.slot, "Pick", function()
			local sk = tiers and tiers[tab].skills[i]
			if sk then
				selected = i
				ctx.quick.pick(sk.id)
				view.paint()
			end
		end, function(input: InputObject)
			local sk = tiers and tiers[tab].skills[i]
			if sk then
				ctx.quick.press(sk.id, nil, input)
			end
		end)
		cells[i] = { holder = holder, cell = cell, pic = pic, name = name, level = level, plus = plus }
	end

	-- 오른쪽: 고른 스킬의 그림 · 이름 · 갈래와 레벨 · 설명 · (앞 차수의 기술을 잇는 것이면) 그 기술의 이름
	local dx = listW + S.gap
	local detailW = S.detailW - S.slot - 10
	Ui.box(body, listW + math.floor(S.gap / 2), 0, 1, h, C.line)
	Ui.slot(body, dx, 0, S.slot)
	local detailPic = Ui.pic(body, nil, dx + 3, 3)
	local detailName = Ui.text(body, "", dx + S.slot + 10, 1, detailW, { font = "body", color = C.gold })
	local detailType = Ui.text(body, "", dx + S.slot + 10, 18, detailW, { color = C.dim })
	local detailBonus = Ui.text(body, "", dx, S.slot + 14, S.detailW, { color = C.accent }) -- 사냥기 · 보스기의 쓰임(일반 몬스터 · 보스에게 피해 +%)
	local detailText = Ui.text(body, "", dx, S.slot + 14, S.detailW, { lines = S.textLines, line = S.textLine })
	local detailNote = Ui.text(body, "", dx, S.slot + 14, S.detailW, { color = C.dim })
	-- 맨 아래 두 줄: 퀵슬롯의 어느 칸에 있는가 · 놓는 법
	local quickAt = Ui.text(body, "", dx, h - Ui.M.small - 16, S.detailW, { color = C.dim })
	local quickHint = Ui.text(body, "", dx, h - Ui.M.small, S.detailW, { color = C.dim })

	-- 차수 탭: 로마 숫자(본문 글씨)를 같은 폭의 칸에 가운데로 — 고른 것은 민트 글씨에 밑줄, 아직 못 배우는 차수는 더 흐리다
	local function buildTabs()
		for i, t in tiers do
			local holder = Ui.group(body, (i - 1) * (S.tabW + S.tabGap), 0, S.tabW, 18, "Tier" .. t.job)
			local label = Ui.text(holder, WORDS.tabs[t.job] or tostring(t.job), 0, 0, S.tabW, { font = "body", align = "center", color = C.dim })
			local under = Ui.box(holder, 0, 15, S.tabW, 2, C.accent)
			under.Visible = false
			picker(holder, 0, -4, S.tabW, 24, "Hit", function()
				if tab ~= i then
					tab, selected = i, 1
					ctx.quick.pick(nil)
					view.paint()
				end
			end)
			tabs[i] = { label = label, under = under, job = t.job }
		end
	end

	function view.paint()
		local me = last
		if not me or not tiers then
			return
		end
		local job = SkillWindow.jobOf(me)
		local tier = tiers[tab]
		local locked = tier.job > job
		for i, t in tabs do
			t.label:color(if i == tab then C.accent elseif t.job > job then C.off else C.dim)
			t.under.Visible = i == tab
		end
		points:set(Format.fill(WORDS.points, { n = me.sp }))
		info:set(Format.fill(if locked then WORDS.locked else WORDS.open, { job = tier.job, lv = tier.lv, n = #tier.skills }))
		info:color(if locked then C.red else C.dim)
		auto:setEnabled(not locked and me.sp > 0)
		for i, c in cells do
			local sk = tier.skills[i]
			c.holder.Visible = sk ~= nil
			if sk then
				local lv = me.skills[sk.id] or 0
				c.cell:setOn(i == selected)
				Ui.setPic(c.pic, "skill_" .. sk.id)
				c.name:set(sk.name)
				c.name:color(if i == selected then C.accent elseif lv > 0 then C.text else C.dim)
				c.level:set(("%d / %d"):format(lv, sk.max))
				c.level:color(if lv >= sk.max then C.accent else C.dim)
				c.plus:setEnabled(not locked and me.sp > 0 and lv < sk.max)
			end
		end
		local sk = tier.skills[selected]
		if sk then
			local lv = me.skills[sk.id] or 0
			Ui.setPic(detailPic, "skill_" .. sk.id)
			detailName:set(sk.name)
			detailType:set(("%s · Lv.%d / %d"):format(TYPES[sk.type] or sk.type, lv, sk.max))
			local bonus = WORDS.bonus[sk.type]
			local top = S.slot + 14 + (if bonus then S.textLine else 0)
			detailBonus:set(if bonus then Format.fill(bonus, { pct = BONUS }) else "")
			detailText:set(sk.text)
			detailText:move(dx, top)
			local _, th = detailText:size()
			local note = if sk.replaces and names[sk.replaces] then Format.fill(WORDS.replaces, { name = names[sk.replaces] }) else ""
			detailNote:set(note)
			detailNote:move(dx, top + math.max(1, math.floor(th / S.textLine + 0.5)) * S.textLine + 6)
			-- 퀵슬롯: 놓인 칸의 키 · 놓는 법(놓으려고 고른 중이면 민트)
			local q = ctx.quick.info(sk.id, sk.type)
			local armed = ctx.quick.picked() == sk.id
			quickAt:set(if q.state == "passive" then QWORDS.passive elseif q.state == "unlearned" then QWORDS.unlearned elseif q.state == "later" then QWORDS.later elseif q.key then Format.fill(QWORDS.at, { key = q.key }) else QWORDS.none)
			quickAt:color(if q.state == "ok" and q.key then C.gold else C.dim)
			quickHint:set(if q.state ~= "ok" then "" elseif armed then QWORDS.armed else QWORDS.hint)
			quickHint:color(if armed then C.accent else C.dim)
		end
	end

	function view.refresh(me)
		last = me
		if not tiers then
			-- 처음: 내 직업의 차수들로 탭을 만든다. 지금 배울 수 있는 가장 높은 차수의 탭부터 보여 준다
			tiers = CLASSES.classes[me.class].tiers
			for _, t in tiers do
				for _, sk in t.skills do
					names[sk.id] = sk.name
				end
			end
			buildTabs()
			tab = math.clamp(SkillWindow.jobOf(me), 1, #tiers)
		end
		view.paint()
	end
	-- 탭을 고른다(시험 · 화면 확인용)
	function view.setTab(i: number, pick: number?)
		if tiers and tiers[i] then
			tab, selected = i, pick or 1
			view.paint()
		end
	end
	return view
end

return SkillWindow
