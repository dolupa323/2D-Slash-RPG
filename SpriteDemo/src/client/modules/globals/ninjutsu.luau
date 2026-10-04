-- 유파 · 전직 · 인술(클라, 「오문 닌자전」 NINJA_DESIGN §0-1) — 수치는 shared/config/ninjutsu.luau, 판정은 서버(server/modules/ninjutsuService.luau).
--  1) 전직 창(스승에게 말을 걸면 열린다 — town/npcs.luau → OpenSchoolWindow):
--     견습(전직 0): 유파 다섯 가운데 하나를 골라 1차 전직(Lv.10부터) → 서버 ChooseSchool.
--     전직한 뒤: 내 유파 줄의 버튼이 다음 전직 레벨이 되면 "N차 전직"(서버 JobAdvance), 다른 유파 줄은 "바꾸기"(엽전).
--  2) HUD(화면 아래 가운데, 소비 단축칸 왼쪽): 기력 게이지 + 인술 단축칸 4개(Q · R · T · G 키 또는 터치) — 배운 쓰는 인술을 스킬 창에서 골라 넣는다.
--     게이지 위: 내게 쌓이는 핵심 장치(생기 · 견고 · 전하)의 값. 스킬 창(K 키 · HUD 버튼): SP로 스킬을 배우고 올린다.
--     칸: 팩 스킬 아이콘(못 쓸 때는 꺼진 그림) · 키 그림 · 쿨타임(어둡게 덮이며 남은 초) · 아직 안 열린 칸은 그 전직 레벨("Lv / 30").
--     쓰기: 서버 UseNinjutsu(칸, 바라보는 방향). 쿨타임은 내가 쓴 NinjutsuCast를 받으면 시작한다.
--  3) 기력: 서버 EnergyUpdated(값, 최대, 초당 회복)를 받은 시각부터 클라가 이어서 센다.
--  4) 내 캐릭터 그림 줄: 유파 번호 → topDownHero.school(시트에서 유파마다 4줄. 견습은 0번 줄).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local Net = require(ReplicatedStorage.shared.net.net)
local config = require(ReplicatedStorage.shared.config.ninjutsu)
local popupManager = require(script.Parent.Parent.popupManager)
local UI = require(script.Parent.Parent.ui.pixelUI)

local C = UI.colors
local SLOT = 26
local GAP = 4
local SLOTS = config.SLOTS -- 인술 단축칸 수(배운 쓰는 인술을 골라 넣는다 — 스킬 창)
local QUICK_W = SLOT * 3 + GAP * 2 -- 소비 단축칸 폭(globals/quickslots.luau와 같아야 나란히 선다)
local BLOCK_W = SLOT * SLOTS + GAP * (SLOTS - 1) -- 인술 칸 전체 폭
local SIDE = BLOCK_W + 8 -- 단축칸 옆 한쪽에 차지하는 폭
local KEYS = { [Enum.KeyCode.Q] = 1, [Enum.KeyCode.R] = 2, [Enum.KeyCode.T] = 3, [Enum.KeyCode.G] = 4 }
local KEY_PARTS = { "key_q", "key_r", "key_t", "key_g" } -- 팩 키보드 키 그림
local PANEL_W, PANEL_H = 444, 246
local ROW_H = 42 -- 유파 한 줄 높이(창) — 얼굴 그림 38
local BUTTON_W, BUTTON_H = 70, 22

local exports = {}
exports.school = "" -- 내 유파("" = 견습)
exports.job = 0 -- 전직 단계(0~4)
exports.levels = {} -- { [스킬 id] = 레벨 }
exports.sp = { 0, 0, 0, 0 } -- 전직별 안 쓴 스킬 포인트
exports.slots = { "", "", "", "" } -- 단축칸의 스킬 id("" = 빈 칸)
exports.core = { id = nil, value = 0, max = 0, untilT = nil } -- 내게 쌓이는 핵심 장치(생기 · 견고 · 전하)
local energy = { value = config.ENERGY_MAX, at = os.clock(), max = config.ENERGY_MAX, regen = config.ENERGY_REGEN }
local readyAt = {} -- [인술 id] = 다시 쓸 수 있는 시각(os.clock)
local cells = {}
local window = nil

function exports.Energy(): number
	return math.min(energy.max, energy.value + (os.clock() - energy.at) * energy.regen)
end

local function myLevel(): number
	local character = CrossPlatformService.Character
	return (character and character.Level) or 1
end

local function redrawSlots()
	for slot, cell in cells do
		cell.content:ClearAllChildren()
		local id = exports.slots[slot]
		if id == "" then
			id = nil
		end
		local skill = id and config.SKILLS[id]
		cell.skillId = id
		cell.skill = skill
		cell.icon = nil
		cell.shown = nil
		if skill and UI.Has("skill_" .. id) then
			-- 팩 스킬 아이콘(24x24) — 못 쓸 때는 꺼진 그림(skill_<id>_off)으로 바꿔 끼운다
			cell.icon = UI.Part(cell.content, "skill_" .. id, 1, 1)
			cell.icon.ZIndex = 5
			local level = config.LevelOf(exports.levels, id)
			if level > 1 then
				local lv = UI.Label(cell.content, tostring(level), 0, 14, { Color = C.white, Shadow = C.ink, ZIndex = 7 })
				lv.Frame.Position = UDim2.fromOffset(SLOT - 3 - lv.Width, 14)
			end
		end
	end
end

local function use(slot: number)
	local cell = cells[slot]
	local hero = require(script.Parent.Parent.topDownHero).hero
	if not cell or not cell.skill or not hero then
		return
	end
	if os.clock() < (readyAt[cell.skillId] or 0) then
		return -- 쿨타임(서버도 다시 확인한다)
	end
	Net.FireServer("UseNinjutsu", slot, hero.Facing or "down")
end

local function applySchool(school: string, levels, job: number?, sp, slots)
	local changed = exports.school ~= (school or "") or exports.job ~= (job or 0)
	exports.school = school or ""
	exports.levels = levels or {}
	exports.job = job or 0
	exports.sp = if typeof(sp) == "table" then sp else { 0, 0, 0, 0 }
	exports.slots = if typeof(slots) == "table" then slots else { "", "", "", "" }
	if changed then
		exports.core = { id = nil, value = 0, max = 0, untilT = nil }
	end
	if exports.onSkillsChanged then
		exports.onSkillsChanged()
	end
	require(script.Parent.Parent.topDownHero).school = config.SchoolIndex(exports.school)
	redrawSlots()
	if window then
		window.refresh()
		if changed and exports.school ~= "" then
			popupManager.Close("SchoolSelect") -- 전직했으면(유파를 바꿨으면) 창을 닫는다
		end
	end
end


-- ---- 스킬 창(K 키 · HUD 스킬 버튼) ----
--  왼쪽: 전직 탭(1~4차) + 그 전직의 스킬 목록(아이콘 · 이름 · 레벨/마스터). 오른쪽: 고른 스킬의 설명 · [배우기](그 전직 SP 1) · 단축칸에 넣기.
--  배우기 · 넣기는 서버(LearnSkill · SetSkillSlot)가 정하고 SchoolUpdated로 돌아오면 다시 그린다.
local SW, SH = 372, 214
local LIST_X, LIST_W = 12, 168
local INFO_X = 190
local INFO_W = SW - INFO_X - 14
local SKILL_ROW = 26
local skillWindow = nil

local function kindText(id: string): string
	local s = config.SKILLS[id]
	return if s.core then "핵심 장치" elseif s.kind == "passive" then "패시브" else "쓰는 인술"
end

local function buildSkillWindow(playerGui: Instance)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkillWindow"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 40
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(SW, SH)
	holder.Parent = screenGui
	UI.Scale(holder)
	local panel = UI.Panel(holder, 0, 0, SW, SH)
	UI.TitleTag(panel, "스킬", SW / 2, -13)
	UI.Button(panel, SW - 30, 9, 20, 18, { Color = "plain", Icon = "close", OnClick = function()
		popupManager.Close("SkillWindow")
	end })
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = panel

	local w = { gui = screenGui, job = 1, selected = nil }
	function w.refresh()
		body:ClearAllChildren()
		if exports.job < 1 then
			UI.Label(body, ("Lv.%d이 되면 스승에게서 유파를 골라 1차 전직을 합니다."):format(config.JOB_LEVELS[1]), 14, 40, { Color = C.ink, MaxWidth = SW - 28, MaxLines = 2 })
			UI.Label(body, "전직하면 스킬을 배울 수 있어요.", 14, 72, { Color = C.accentD, MaxWidth = SW - 28, MaxLines = 1 })
			return
		end
		w.job = math.clamp(w.job, 1, exports.job)
		-- 전직 탭
		for job = 1, #config.JOB_LEVELS do
			local tab = UI.Button(body, LIST_X + (job - 1) * 42, 14, 40, 18, { Color = if job == w.job then "primary" else "plain", Text = ("%d차"):format(job), OnClick = function()
				w.job, w.selected = job, nil
				w.refresh()
			end })
			tab:SetEnabled(job <= exports.job)
		end
		UI.Label(body, ("SP %d"):format(exports.sp[w.job] or 0), INFO_X, 17, { Color = C.accentD, MaxWidth = 60, MaxLines = 1 })
		-- 목록
		local list = config.TreeFor(exports.school, w.job)
		if not w.selected or not table.find(list, w.selected) then
			w.selected = list[1]
		end
		if #list == 0 then
			UI.Label(body, "이 전직의 스킬은 준비 중이에요.", LIST_X + 2, 44, { Color = C.ink, MaxWidth = LIST_W, MaxLines = 2 })
		end
		for i, id in list do
			local y = 36 + (i - 1) * SKILL_ROW
			local level = config.LevelOf(exports.levels, id)
			local cell = UI.Slot(body, LIST_X, y, 26)
			cell:SetSelected(id == w.selected)
			if UI.Has("skill_" .. id) then
				UI.Part(cell.Instance, "skill_" .. id .. (if level < 1 then "_off" else ""), 1, 1).ZIndex = 5
			end
			cell.Instance.Activated:Connect(function()
				w.selected = id
				w.refresh()
			end)
			UI.Label(body, config.SKILLS[id].name, LIST_X + 30, y + 1, { Color = if level >= 1 then C.ink else C.gray, MaxWidth = LIST_W - 30, MaxLines = 1 })
			UI.Label(body, ("Lv %d/%d"):format(level, config.MaxOf(id)), LIST_X + 30, y + 13, { Color = C.accentD, MaxWidth = LIST_W - 30, MaxLines = 1 })
		end
		-- 고른 스킬
		local id = w.selected
		if not id then
			return
		end
		local s = config.SKILLS[id]
		local level = config.LevelOf(exports.levels, id)
		local max = config.MaxOf(id)
		UI.Label(body, s.name, INFO_X, 38, { Color = C.accentD, MaxWidth = INFO_W, MaxLines = 1 })
		UI.Label(body, ("%s · Lv %d/%d"):format(kindText(id), level, max), INFO_X, 52, { Color = C.ink, MaxWidth = INFO_W, MaxLines = 1 })
		UI.Label(body, s.desc, INFO_X, 68, { Color = C.ink, MaxWidth = INFO_W, MaxLines = 4 })
		if config.IsActive(id) then
			local cost = if s.vigorCost then ("생기 %d"):format(s.vigorCost) else ("기력 %d"):format(s.cost)
			UI.Label(body, ("%s · 쿨타임 %s초"):format(cost, tostring(s.cooldown)), INFO_X, 126, { Color = C.grayD, MaxWidth = INFO_W, MaxLines = 1 })
		end
		local learn = UI.Button(body, INFO_X, 142, 76, 22, { Color = "primary", Text = if level < 1 then "배우기" elseif level >= max then "마스터" else "올리기", OnClick = function()
			Net.FireServer("LearnSkill", id)
		end })
		learn:SetEnabled(level < max and (exports.sp[w.job] or 0) >= 1)
		-- 단축칸에 넣기(쓰는 인술을 배웠을 때): 칸을 누르면 그 칸에 넣고, 이미 들어 있는 칸을 누르면 뺀다
		if config.IsActive(id) and level >= 1 then
			UI.Label(body, "칸", INFO_X, 177, { Color = C.ink, MaxWidth = 14, MaxLines = 1 })
			for slot = 1, config.SLOTS do
				local x = INFO_X + 18 + (slot - 1) * 34
				local cell = UI.Slot(body, x, 170, 26)
				local held = exports.slots[slot] or ""
				cell:SetSelected(held == id)
				if held ~= "" and UI.Has("skill_" .. held) then
					UI.Part(cell.Instance, "skill_" .. held, 1, 1).ZIndex = 5
				end
				UI.Part(body, KEY_PARTS[slot], x - 3, 167).ZIndex = 10
				cell.Instance.Activated:Connect(function()
					Net.FireServer("SetSkillSlot", slot, if held == id then "" else id)
				end)
			end
		end
	end
	screenGui.Parent = playerGui
	popupManager.Register("SkillWindow", screenGui, panel)
	return w
end

function exports.ToggleSkillWindow()
	if not skillWindow then
		return
	end
	if not popupManager.IsOpen("SkillWindow") then
		skillWindow.refresh()
	end
	popupManager.Toggle("SkillWindow")
end

-- 전하(번개 유파의 핵심 장치): 기본 공격 간격 · 동작 시간에 곱하는 배율(서버 ninjutsuService와 같은 셈)
function exports.AttackSpeedMult(): number
	local mult = 1 / (1 + exports.Haste())
	local core = exports.core
	if core.id == "t_charge" and (not core.untilT or os.clock() < core.untilT) then
		local def = config.SKILLS.t_charge
		mult /= 1 + (def.speedPer + def.perLevel * config.LevelOf(exports.levels, "t_charge")) * core.value
	end
	return mult
end

-- 질풍(걸음 · 공격 속도 버프): 지금 값(없으면 0) — 서버 BuffUpdated("haste", 값, 초)
exports.haste = { value = 0, untilT = 0 }
function exports.Haste(): number
	return if os.clock() < exports.haste.untilT then exports.haste.value else 0
end

-- 내게 쌓이는 핵심 장치의 지금 값(시간이 지나 사라졌으면 0)
function exports.Core(): number
	local core = exports.core
	return if core.untilT and os.clock() >= core.untilT then 0 else core.value
end

-- ---- 전직 창 ----
local function buildWindow(playerGui: Instance)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SchoolSelect"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 40

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	holder.Parent = screenGui
	UI.Scale(holder)

	local panel = UI.Panel(holder, 0, 0, PANEL_W, PANEL_H)
	UI.TitleTag(panel, "전직", PANEL_W / 2, -13)
	UI.Button(panel, PANEL_W - 30, 9, 20, 18, { Color = "plain", Icon = "close", OnClick = function()
		popupManager.Close("SchoolSelect")
	end })
	local note = UI.Label(panel, "", 14, 13, { Color = C.ink, MaxWidth = PANEL_W - 14 - 34, MaxLines = 1 }) -- 닫기 버튼 앞까지

	local buttons = {}
	for i, id in config.SCHOOLS do
		local info = config.SCHOOL_INFO[id]
		local y = 30 + (i - 1) * ROW_H
		UI.Part(panel, "face_school_" .. id, 12, y - 2).ZIndex = 4 -- 팩 얼굴 그림(38x38)
		-- 윗줄: 유파 이름 + 설명 / 아랫줄: 전직마다 배우는 인술 넷
		local name = UI.Label(panel, ("%s · %s"):format(info.name, info.title), 58, y + 4, { Color = C.accentD })
		UI.Label(panel, info.desc, 58 + name.Width + 10, y + 4, { Color = C.ink, MaxWidth = PANEL_W - 14 - BUTTON_W - 6 - (58 + name.Width + 10), MaxLines = 1 })
		local skills = {}
		for _, sid in config.TREE[id][1] do -- 1차 전직 때 열리는 스킬
			table.insert(skills, config.SKILLS[sid].name)
		end
		UI.Label(panel, table.concat(skills, " · "), 58, y + 18, { Color = C.ink, MaxWidth = PANEL_W - 14 - BUTTON_W - 6 - 58, MaxLines = 1 })
		buttons[id] = UI.Button(panel, PANEL_W - 14 - BUTTON_W, y + 6, BUTTON_W, BUTTON_H, { Color = "primary", Text = "입문", OnClick = function()
			if id == exports.school then
				Net.FireServer("JobAdvance") -- 내 유파 줄 = 다음 전직
			else
				Net.FireServer("ChooseSchool", id) -- 1차 전직(유파 고르기) 또는 유파 바꾸기
			end
		end })
	end

	screenGui.Parent = playerGui
	popupManager.Register("SchoolSelect", screenGui, panel)

	local w = { gui = screenGui }
	function w.refresh()
		local level, job = myLevel(), exports.job
		local nextLevel = config.JOB_LEVELS[job + 1]
		if job == 0 then
			note:SetText(if level >= config.JOB_LEVELS[1]
				then ("유파를 고르세요. 1차 전직 · %s이 됩니다."):format(config.JOB_NAMES[1])
				else ("Lv.%d이 되면 스승에게서 유파를 골라 1차 전직을 합니다."):format(config.JOB_LEVELS[1]))
		elseif nextLevel then
			note:SetText(("%s · 다음 전직 Lv.%d · 유파 바꾸기 엽전 %d"):format(config.JOB_NAMES[job], nextLevel, config.CHANGE_COST))
		else
			note:SetText(("%s · 전직을 모두 마쳤어요 · 유파 바꾸기 엽전 %d"):format(config.JOB_NAMES[job], config.CHANGE_COST))
		end
		for id, button in buttons do
			local mine = id == exports.school
			local text, enabled
			if job == 0 then
				text, enabled = "입문", level >= config.JOB_LEVELS[1]
			elseif mine then
				local canAdvance = nextLevel ~= nil and level >= nextLevel
				text, enabled = if canAdvance then ("%d차 전직"):format(job + 1) else "지금 유파", canAdvance
			else
				text, enabled = "바꾸기", true
			end
			button:SetText(text)
			button:SetEnabled(enabled)
			-- 글씨 길이가 바뀌었으니 다시 가운데로
			button.Label.Frame.Position = UDim2.fromOffset((BUTTON_W - button.Label.Width) // 2, (BUTTON_H - 2 - 11) // 2)
		end
	end
	return w
end

-- 스승에게 말을 걸었을 때 전직 창을 열 것인가: 전직했거나, 1차 전직 레벨이 됐을 때(그 전에는 스승의 말을 듣는다)
function exports.ShouldOpenWindow(): boolean
	return exports.job >= 1 or myLevel() >= config.JOB_LEVELS[1]
end

function exports.OpenSchoolWindow()
	if not window then
		return
	end
	window.refresh()
	popupManager.Open("SchoolSelect")
end

function exports.load(scene: Scene)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if not exports.screenGui then
		local g = Instance.new("ScreenGui")
		g.Name = "Ninjutsu"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 20
		-- 소비 단축칸(가운데)과 나란히: 단축칸 폭 + 양쪽 SIDE짜리 틀을 가운데 아래에 두고, 왼쪽 끝에 인술 칸을 놓는다
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.Position = UDim2.new(0.5, 0, 1, -8)
		holder.Size = UDim2.fromOffset(QUICK_W + SIDE * 2, SLOT + 11)
		holder.Parent = g
		UI.Scale(holder)
		UI.Part(holder, "icon_energy", -13, -1)
		local bar = UI.Bar(holder, 0, 0, BLOCK_W - 26, "sky")
		local energyLabel = UI.Label(holder, "", BLOCK_W - 23, -2, { Color = C.white, Shadow = C.ink, MaxWidth = 24, MaxLines = 1 })
		exports.coreLabel = UI.Label(holder, "", 0, -15, { Color = C.white, Shadow = C.ink, MaxWidth = BLOCK_W, MaxLines = 1, Clamp = false })
		for slot = 1, SLOTS do
			local ui = UI.Slot(holder, (slot - 1) * (SLOT + GAP), 11, SLOT)
			local content = Instance.new("Frame")
			content.BackgroundTransparency = 1
			content.Size = UDim2.fromScale(1, 1)
			content.Parent = ui.Instance
			-- 쿨타임: 아래에서부터 덮는 어두운 막 + 남은 초
			local shade = Instance.new("Frame")
			shade.Name = "Cooldown"
			shade.BackgroundColor3 = C.ink
			shade.BackgroundTransparency = 0.45
			shade.BorderSizePixel = 0
			shade.AnchorPoint = Vector2.new(0, 1)
			shade.Position = UDim2.new(0, 2, 1, -3)
			shade.Size = UDim2.fromOffset(SLOT - 4, 0)
			shade.ZIndex = 8
			shade.Parent = ui.Instance
			local overlay = Instance.new("Frame")
			overlay.BackgroundTransparency = 1
			overlay.Size = UDim2.fromScale(1, 1)
			overlay.ZIndex = 9
			overlay.Parent = ui.Instance
			local text = UI.Label(overlay, "", 0, 8, { Color = C.white, Shadow = C.ink, ZIndex = 9, Align = "center" })
			ui.Instance.Activated:Connect(function()
				use(slot)
			end)
			UI.Part(holder, KEY_PARTS[slot], (slot - 1) * (SLOT + GAP) - 3, 8).ZIndex = 10 -- 키 그림
			cells[slot] = { ui = ui, content = content, shade = shade, text = text, shown = nil }
		end
		g.Parent = playerGui
		exports.screenGui = g
		exports.bar = bar
		exports.energyLabel = energyLabel
	end
	if not window then
		window = buildWindow(playerGui)
	end
	if not skillWindow then
		skillWindow = buildSkillWindow(playerGui)
		exports.onSkillsChanged = function()
			if popupManager.IsOpen("SkillWindow") then
				skillWindow.refresh()
			end
		end
	end
	if not exports.listening then
		exports.listening = true
		Net.OnClient("SchoolUpdated", applySchool)
		-- 내게 쌓이는 핵심 장치(생기 · 견고 · 전하): 기력 게이지 위에 "전하 7/10"처럼 적는다
		Net.OnClient("CoreUpdated", function(id, value, max, seconds)
			exports.core = { id = id, value = value, max = max, untilT = if seconds and value > 0 then os.clock() + seconds else nil }
		end)
		Net.OnClient("BuffUpdated", function(kind, value, seconds)
			if kind == "haste" then
				exports.haste = { value = value, untilT = os.clock() + seconds }
			end
		end)
		Net.OnClient("EnergyUpdated", function(value, max, regen)
			energy.value, energy.max, energy.regen, energy.at = value, max, regen, os.clock()
		end)
		-- 내가 쓴 인술이면 쿨타임 시작(연출은 town/ninjutsuFx.luau)
		Net.OnClient("NinjutsuCast", function(_sceneKey, userId, skillId)
			local skill = config.SKILLS[skillId]
			if userId == Players.LocalPlayer.UserId and skill then
				readyAt[skillId] = os.clock() + skill.cooldown
			end
		end)
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local slot = KEYS[input.KeyCode]
			if slot then
				use(slot)
			elseif input.KeyCode == Enum.KeyCode.K then
				exports.ToggleSkillWindow()
			end
		end)
		RunService.Heartbeat:Connect(function()
			if not exports.bar then
				return
			end
			local now = os.clock()
			local e = exports.Energy()
			exports.bar:SetRatio(e / energy.max)
			exports.energyLabel:SetText(tostring(math.floor(e)))
			local core = exports.core
			local coreText = if core.id and config.SKILLS[core.id] and exports.school == config.SKILLS[core.id].school
				then ("%s %d/%d"):format(config.SKILLS[core.id].name, math.floor(exports.Core()), core.max)
				else ""
			if exports.coreShown ~= coreText then
				exports.coreShown = coreText
				exports.coreLabel:SetText(coreText)
			end
			for slot, cell in cells do
				local text, ratio = "", 0
				local skill = cell.skill
				local locked = false
				if skill then
					local left = (readyAt[cell.skillId] or 0) - now
					if left > 0 then
						text, ratio = tostring(math.ceil(left)), left / skill.cooldown
					end
				end
				local off = skill ~= nil and (e < skill.cost or (skill.vigorCost ~= nil and exports.Core() < skill.vigorCost)) -- 못 쓰는 동안 꺼진 그림
				local key = text .. "|" .. math.floor(ratio * (SLOT - 5)) .. (if off then "x" else "")
				if cell.shown ~= key then
					cell.shown = key
					if cell.icon then
						cell.icon.ImageRectOffset = UI.RectOffset("skill_" .. cell.skillId .. (if off then "_off" else ""))
					end
					cell.shade.Size = UDim2.fromOffset(SLOT - 4, math.floor(ratio * (SLOT - 5)))
					cell.text:SetText(text)
					cell.text.Frame.Position = UDim2.fromOffset((SLOT - cell.text.Width) // 2, if cell.text.Height > 14 then 1 else 7)
				end
			end
		end)
		task.spawn(function()
			local ok, data = pcall(Net.Invoke, "GetPlayerData")
			if ok and typeof(data) == "table" then
				applySchool(data.School or "", data.Ninjutsu, data.Job or 0, data.SP, data.SkillSlots)
			end
		end)
	end
	redrawSlots()
end

function exports.start(scene: Scene) end
function exports.unload(scene: Scene) end

return exports
