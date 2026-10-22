-- 처음 화면 — 「달의 계승자」 로딩 화면 → START → 캐릭터 고르기(만들기 · 삭제 · 들어가기).
--  사용자 2026-10-10: "맨처음에 게임을 접속할때 로딩화면을 멋있게 구현해야하고, 그 로딩화면에서 스타트 누르면 캐릭터 선택창 나오고 거기에 캐릭터 만들기도 있고,
--   캐릭터 삭제도 있고, 내가 만든 캐릭터 중 하나를 선택해서 접속하는 방식", "캐릭터 이름은 처음에 생성할때 캐릭터 이름을 짓습니다. 중복확인을하고".
--  바탕(큰 달의 하늘 · 흘러가는 구름 · 떠오르는 달가루 · 언덕 · 제목)은 처음부터 끝까지 그대로 있고, 그 위의 것만 단계마다 바뀐다:
--   로딩   = 달 앞에 다섯 영웅의 실루엣. 그림을 다 불러오면 START 단추가 뜬다(Enter · Space · 화면을 눌러도 된다).
--   고르기 = 내 캐릭터들이 언덕에 서 있다. ← → 로 고르고 Enter(또는 「게임 시작」)로 들어간다. 「캐릭터 만들기」 · 「캐릭터 삭제」.
--   만들기 = 다섯 직업 가운데 하나를 고르고(외형은 정해져 있다), 이름을 적어 「중복 확인」을 받은 뒤 「만들기」.
--   삭제   = 캐릭터의 이름을 그대로 적어야 지워진다. 이름 짓기 = 이름이 없는 캐릭터(계정이 생기기 전의 캐릭터)에 이름을 지어 준다.
--  그림 · 자리 · 글은 shared/lune/data/title.generated.luau(공방의 js/lune/design/title.js · tools/build_lune_title.mjs).
--  하늘 · 언덕 · 캐릭터는 게임 세계의 층에, 글 · 단추 · 판은 화면 틀의 층(고운 격자)에 그린다. 이름을 적는 칸은 Roblox의 글자 입력 칸이다(채팅과 같다).
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lune = ReplicatedStorage.shared.lune
local G = require(lune.config.game)
local T = require(lune.data["title.generated"])
local CLASSES = require(lune.data["classes.generated"])
local COMBAT = require(lune.data["combat.generated"])
local ASSETS = require(lune.data["assets.generated"])
local Account = require(lune.sim.account)
local Stage = require(script.Parent.stage)
local Sprite = require(script.Parent.sprite)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local TXT = T.text
local WHITE, GRAY, OFF, MINT, PINK = C.text, C.dim, C.off, C.accent, C.pink
local GROUND = T.ground
local CLOUD_SPEED = 2.2 -- 구름이 흘러가는 빠르기(도트/초)
local DUST = 18 -- 떠오르는 달가루의 수
local FADE = 0.22 -- 단계를 바꿀 때 어두워졌다 밝아지는 시간(초)
local NAME_MAX = 12 -- 이름 칸에 적을 수 있는 글자 수(한글은 여섯 자까지 — 셈은 sim/account.luau)

local Title = {}

local function hexColor(hex: string): Color3
	return Color3.fromRGB(tonumber(hex:sub(2, 3), 16) :: number, tonumber(hex:sub(4, 5), 16) :: number, tonumber(hex:sub(6, 7), 16) :: number)
end

-- 이름을 적는 칸(틀 + Roblox의 글자 입력 칸). 돌려주는 것: 입력 칸
local function nameField(parent: Instance, x: number, y: number, w: number, h: number, placeholder: string): TextBox
	local field = Ui.group(parent, x, y, w, h, "Field")
	Ui.part(field, "uField", 0, 0, w, h)
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(6, 0)
	box.Size = UDim2.new(1, -12, 1, 0)
	box.Font = Enum.Font.SourceSans
	box.TextSize = 12
	box.TextColor3 = C.text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = C.off
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Text = ""
	box.ZIndex = 6
	box.Parent = field
	-- 띄어쓰기는 적히지 않는다(이름에 쓸 수 없다 — 끝에 딸려 들어온 빈칸 때문에 중복 확인이 안 되는 일이 없게). 너무 길게도 적히지 않는다(자세한 규칙은 중복 확인이 알려 준다)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local bare = string.gsub(box.Text, "[ \t\r\n]", "") -- (%s는 한글의 가운데 바이트를 빈칸으로 볼 수 있다 — 반쪽 글자가 생겼다 · 2026-10-21 오류 보고)
		if bare ~= box.Text then
			box.Text = bare
			return
		end
		local n = utf8.len(box.Text)
		if n and n > NAME_MAX then
			box.Text = string.sub(box.Text, 1, (utf8.offset(box.Text, NAME_MAX + 1) :: number) - 1)
		end
	end)
	return box
end

-- 처음 화면을 띄우고, 캐릭터로 들어갈 때까지 기다린다. 돌려주는 것 = 서버가 준 내 상태와 방(Ready가 주던 것과 같다).
--  select = 서버가 준 고르기 화면의 표({ chars, max, last }) · io.invoke(하는 일, a, b) = 서버에 묻는다(Chars 패킷) · io.preload(알림) = 그림을 불러온다(알림(끝난 수, 모두))
--  io.skipLoading = 로딩 화면 없이 고르기 화면부터(게임 안에서 메뉴 → 캐릭터 선택으로 돌아왔을 때)
function Title.run(select, io)
	local view = select
	-- ---------- 바탕(게임 세계의 층) ----------
	local root = Stage.group(Stage.view, "Title", 200)
	root.BackgroundTransparency = 0
	root.BackgroundColor3 = Color3.fromRGB(90, 106, 130)
	root.ClipsDescendants = true
	Stage.image(root, "Sky", ASSETS[T.img.sky] or "", G.VIEW_W, G.VIEW_H).ZIndex = 1
	local clouds = {}
	for i = 1, 2 do
		local c = Stage.image(root, "Clouds" .. i, ASSETS[T.img.clouds] or "", T.clouds.w, T.clouds.h)
		c.ZIndex = 2
		clouds[i] = c
	end
	local dust = {}
	local rng = Random.new(20261010)
	for i = 1, DUST do
		local f = Instance.new("Frame")
		f.Name = "Dust"
		f.Size = UDim2.fromOffset(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = if i % 3 == 0 then Color3.fromRGB(62, 255, 215) else Color3.fromRGB(207, 221, 230)
		f.ZIndex = 3
		f.Parent = root
		dust[i] = { frame = f, x = rng:NextNumber(0, G.VIEW_W), y = rng:NextNumber(20, GROUND), speed = rng:NextNumber(3, 8), sway = rng:NextNumber(0, 6.28), life = rng:NextNumber(0, 1) }
	end
	local ridge = Stage.image(root, "Ridge", ASSETS[T.img.ridge] or "", G.VIEW_W, T.ridge.h)
	ridge.Position = UDim2.fromOffset(0, T.ridge.y)
	ridge.ZIndex = 5
	local actors = Stage.group(root, "Actors", 6)
	local logo = Stage.image(root, "Logo", ASSETS[T.img.logo] or "", T.logo.w, T.logo.h)
	logo.Position = UDim2.fromOffset(math.floor((G.VIEW_W - T.logo.w) / 2), T.logo.y)
	logo.ZIndex = 7
	logo.ImageTransparency = 1

	-- ---------- 글의 층(화면 틀) ----------
	local over = Stage.group(Stage.ui, "Title", 200)
	local shade = Instance.new("Frame") -- 단계를 바꿀 때 잠깐 덮는 어둠
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = C.ink
	shade.BorderSizePixel = 0
	shade.ZIndex = 90
	shade.Parent = over

	local clock = 0
	local result = nil
	local busy = false
	local sv: Frame? = nil -- 지금 단계의 것(게임 세계의 층)
	local su: Frame? = nil -- 지금 단계의 것(화면 틀의 층)
	local stageStep: ((number) -> ())? = nil
	local stageKey: ((Enum.KeyCode) -> ())? = nil
	local stagePlace: (() -> ())? = nil -- 화면 틀의 배율이 바뀌면 다시 놓을 것
	local shadeFrom, shadeTo, shadeT = 1, 0, 0 -- 처음에는 어둠에서 밝아진다

	local function open(): (Frame, Frame)
		if sv then
			sv:Destroy()
		end
		if su then
			su:Destroy()
		end
		stageStep, stageKey, stagePlace = nil, nil, nil
		local a, b = Stage.group(actors, "Stage", 1), Stage.group(over, "Stage", 1)
		sv, su = a, b
		return a, b
	end

	-- 어두워졌다가(그 사이에 화면을 바꾸고) 밝아진다
	local function switch(build: () -> ())
		shadeFrom, shadeTo, shadeT = shade.BackgroundTransparency, 0, 0
		task.delay(FADE, function()
			if root.Parent then
				build()
				shadeFrom, shadeTo, shadeT = 0, 1, 0
			end
		end)
	end

	-- 서버에 묻는다(답을 기다리는 동안에는 다른 것을 누를 수 없다). 답이 없으면 nil
	local function ask(action: string, a: any, b: any): any
		if busy then
			return nil
		end
		busy = true
		local ok, res = pcall(io.invoke, action, a, b)
		busy = false
		return if ok then res else nil
	end

	local showSelect, showCreate

	-- 게임 세계의 도트 자리(x, y)를 화면 틀의 자리로
	local function toUi(x: number, y: number): (number, number)
		return math.floor(x * Stage.ratio + 0.5), math.floor(y * Stage.ratio + 0.5)
	end

	-- 캐릭터 만들기에서 고른 직업이 써 보이는 기술(공방의 title.js의 show — 몸 동작만으로도 무엇을 하는지 보이는 것).
	--  돌려주는 것: 그 기술, 이 화면에서 한 번 트는 데 걸리는 시간(초 — 게임 안보다 조금 느리게 보여 준다)
	local SHOW = T.show
	local function showOf(id: string)
		local sk = COMBAT.skills[SHOW.skill[id]]
		local total = 0
		if sk then
			for _, seg in sk.segs do
				total += seg.time / SHOW.speed
			end
		end
		return sk, total
	end

	-- ---------- 로딩 ----------
	local function showLoading()
		local a, b = open()
		local order = CLASSES.order
		local n = #order
		local tint = hexColor(T.heroes.tint)
		local sil = {}
		for i, id in order do
			local sp = Sprite.new(a, id, 1, true) -- 흰 그림(mask)에 색을 입히면 실루엣이 된다
			sp.label.ImageColor3 = tint
			sil[i] = { sprite = sp, x = T.moon.x + (i - (n + 1) / 2) * T.heroes.gap }
		end
		local holder = Stage.place(b, "Load", "bc", Stage.REF_W / 2 - 160, Stage.REF_H - 96, 320, 80)
		local label = Ui.text(holder, TXT.loading, 0, 6, 320, { align = "center", outline = true })
		local bar = Ui.bar(holder, 60, 24, 200, 6, MINT, C.panel)
		bar:set(0)
		local loaded = false
		local done, total, shown = 0, 1, -1
		local start = nil
		local hint = nil
		local function go()
			if loaded and not result then
				loaded = false -- 한 번만
				switch(function()
					showSelect(nil)
				end)
			end
		end
		-- 화면 어디를 눌러도 시작한다(START 단추 아래에 깔린 누르는 자리)
		local anywhere = Instance.new("TextButton")
		anywhere.Name = "Anywhere"
		anywhere.Text = ""
		anywhere.BackgroundTransparency = 1
		anywhere.Size = UDim2.fromScale(1, 1)
		anywhere.ZIndex = 1
		anywhere.Parent = b
		anywhere.Activated:Connect(go)
		task.spawn(function()
			io.preload(function(d: number, t: number)
				done, total = d, t
			end)
			if not root.Parent then
				return
			end
			label:show(false)
			bar.frame.Visible = false
			start = Ui.button(holder, TXT.start, 80, 8, 160, go, { main = true, h = 30 })
			start.frame.Name = "Start"
			if UserInputService.KeyboardEnabled then
				hint = Ui.text(holder, TXT.startHint, 0, 48, 320, { align = "center", outline = true, color = GRAY })
			end
			loaded = true
		end)
		stageStep = function(_dt)
			for i, s in sil do
				local frame = Sprite.frameAt(s.sprite.char, "idle", clock + i * 0.23, false)
				s.sprite:set("idle", frame, s.x, GROUND, 1)
			end
			if start == nil and done ~= shown then
				shown = done
				bar:set(done / math.max(1, total))
				label:set(("%s  %d / %d"):format(TXT.loading, done, total))
			end
			if hint then
				hint:show(clock % 1.6 < 1.1) -- 천천히 깜빡인다
			end
		end
		stageKey = function(key)
			if key == Enum.KeyCode.Return or key == Enum.KeyCode.Space or key == Enum.KeyCode.KeypadEnter then
				go()
			end
		end
	end

	-- ---------- 이름을 적는 상자(삭제 · 이름 짓기가 같이 쓴다): 가운데의 판과 그 뒤의 어둠 ----------
	local function modal(parent: Instance, w: number, h: number): (Frame, TextButton)
		local dim = Instance.new("TextButton") -- 뒤의 것을 누르지 못하게 덮는다
		dim.Name = "Dim"
		dim.Text = ""
		dim.AutoButtonColor = false
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = C.ink
		dim.BackgroundTransparency = 0.45
		dim.BorderSizePixel = 0
		dim.ZIndex = 40
		dim.Parent = parent
		local holder = Stage.place(dim, "Box", "tc", Stage.REF_W / 2 - w / 2, 150, w, h)
		holder.ZIndex = 41
		return Ui.panel(holder, 0, 0, w, h), dim
	end

	-- ---------- 캐릭터 고르기 ----------
	local picked = 1
	for i, c in view.chars do
		if c.id == view.last then
			picked = i -- 마지막으로 하던 캐릭터가 골라져 있다
		end
	end
	-- 화면의 머리글(왼쪽 위): 지금 무엇을 하는 화면인지
	local function header(parent: Instance, title: string, hint: string?)
		local box = Stage.place(parent, "Header", "tl", 22, 18, 300, 40)
		Ui.text(box, title, 0, 0, 300, { font = "body", outline = true, color = MINT })
		if hint and UserInputService.KeyboardEnabled then
			Ui.text(box, hint, 0, 20, 300, { outline = true, color = GRAY })
		end
	end
	showSelect = function(note: string?)
		local a, b = open()
		local chars, max = view.chars, view.max
		if #chars == 0 then
			showCreate() -- 캐릭터가 없으면 만들기부터
			return
		end
		picked = math.clamp(picked, 1, #chars)
		header(b, TXT.select, TXT.selectHint)
		local slots = {}
		for i = 1, max do
			local c = chars[i]
			local x = G.VIEW_W / 2 + (i - (max + 1) / 2) * T.slots.gap
			local slot = { x = x, char = c }
			if c then
				slot.sprite = Sprite.new(a, c.class, 2)
				slot.sprite:setLook(c.look) -- 그 캐릭터의 무기 · 로브 색(염색 — 2026-10-22)
				slot.name = Ui.tag(b, if c.name ~= "" then c.name else "이름 없음", WHITE, 130, true)
				slot.sub = Ui.tag(b, ("Lv.%d %s"):format(c.level, CLASSES.classes[c.class].name), GRAY, 130)
				local hit = Instance.new("TextButton")
				hit.Name = "Pick" .. i
				hit.Text = ""
				hit.BackgroundTransparency = 1
				hit.ZIndex = 8
				hit.Parent = b
				slot.hit = hit
			else
				slot.name = Ui.tag(b, TXT.empty, OFF, 130)
			end
			slots[i] = slot
		end
		-- 고른 캐릭터의 머리 위에 민트 세모
		local mark = Stage.group(a, "Mark", 5)
		for row = 0, 2 do
			local f = Instance.new("Frame")
			f.Size = UDim2.fromOffset(5 - row * 2, 1)
			f.Position = UDim2.fromOffset(row, row)
			f.BackgroundColor3 = MINT
			f.BorderSizePixel = 0
			f.Parent = mark
		end
		mark.Size = UDim2.fromOffset(5, 3)

		local bottom = Stage.place(b, "Bottom", "bc", Stage.REF_W / 2 - 220, Stage.REF_H - 76, 440, 76)
		local status = Ui.text(bottom, note or "", 0, 0, 440, { align = "center", outline = true, color = PINK })
		local enterButton, createButton, removeButton
		local function refresh()
			local c = chars[picked]
			for i, s in slots do
				if s.char then
					s.name:SetColor(if i == picked then WHITE else GRAY)
					s.sprite.label.ImageColor3 = if i == picked then Color3.new(1, 1, 1) else Color3.fromRGB(150, 160, 178)
				end
			end
			enterButton:setText(if c.name == "" then TXT.giveName else TXT.enter)
			createButton:setEnabled(#chars < max)
		end
		local function place()
			for _, s in slots do
				local cx, gy = toUi(s.x, GROUND)
				s.name.Frame.Position = UDim2.fromOffset(cx - math.floor(s.name.Width / 2), gy + 7)
				if s.sub then
					s.sub.Frame.Position = UDim2.fromOffset(cx - math.floor(s.sub.Width / 2), gy + 7 + Ui.TAG_H + 3)
				end
				if s.hit then
					local w, h = toUi(T.slots.gap, 44)
					s.hit.Position = UDim2.fromOffset(cx - math.floor(w / 2), gy - h)
					s.hit.Size = UDim2.fromOffset(w, h + 34)
				end
			end
		end
		stagePlace = place

		-- 이름 짓기(이름이 없는 캐릭터)
		local function openName(c)
			local panel, dim = modal(b, 360, 150)
			Ui.text(panel, TXT.nameTitle, 16, 14, 328, { font = "body", color = MINT })
			Ui.text(panel, TXT.nameRule, 16, 38, 328, { color = GRAY })
			local box = nameField(panel, 16, 56, 228, 24, TXT.namePlaceholder)
			local say = Ui.text(panel, TXT.needCheck, 16, 86, 328, { lines = 2, line = 12, color = GRAY })
			local okName: string? = nil
			local setButton
			local function check()
				if busy then
					return
				end
				local name = box.Text
				okName = nil
				setButton:setEnabled(false)
				say:color(GRAY)
				say:set(TXT.checking)
				local res = ask("check", name, nil)
				if not dim.Parent then
					return
				end
				if res and res.ok then
					okName = name
					say:color(MINT)
					say:set(TXT.nameFree)
					setButton:setEnabled(true)
				else
					say:color(PINK)
					say:set(if res then res.why or TXT.failed else TXT.failed)
				end
			end
			Ui.button(panel, TXT.check, 250, 56, 94, check, { h = 24 })
			setButton = Ui.button(panel, TXT.setName, 16, 114, 200, function()
				if busy or not okName or okName ~= box.Text then
					return
				end
				local res = ask("name", c.id, okName)
				if res and res.ok then
					view = res.select
					showSelect(nil)
				elseif dim.Parent then
					say:color(PINK)
					say:set(if res then res.why or TXT.failed else TXT.failed)
					setButton:setEnabled(false)
				end
			end, { main = true })
			setButton:setEnabled(false)
			Ui.button(panel, TXT.cancel, 224, 114, 120, function()
				dim:Destroy()
			end)
			box:GetPropertyChangedSignal("Text"):Connect(function()
				if okName and box.Text ~= okName then
					okName = nil
					setButton:setEnabled(false)
					say:color(GRAY)
					say:set(TXT.needCheck)
				end
			end)
			box.FocusLost:Connect(function(enter: boolean)
				if enter and box.Text ~= "" then
					check()
				end
			end)
			box:CaptureFocus()
		end

		local function enter()
			local c = chars[picked]
			if not c or result or busy then
				return
			end
			if c.name == "" then
				openName(c)
				return
			end
			status:color(GRAY)
			status:set(TXT.wait)
			local res = ask("enter", c.id, nil)
			if res and res.self then
				result = res
			elseif res and res.select then
				view = res.select -- 이름을 더 쓸 수 없게 된 캐릭터: 서버가 이름을 비웠다 — 다시 지어야 들어간다
				showSelect(res.why)
			elseif status.label.Frame.Parent then
				status:color(PINK)
				status:set(if res then res.why or TXT.failed else TXT.failed)
			end
		end

		-- 삭제: 이름을 그대로 적어야 지워진다(이름이 없는 캐릭터는 적을 것이 없다)
		local function openRemove()
			local c = chars[picked]
			if not c then
				return
			end
			local named = c.name ~= ""
			local panel, dim = modal(b, 380, if named then 186 else 132)
			Ui.text(panel, TXT.removeTitle, 16, 14, 348, { font = "body", color = PINK })
			Ui.text(panel, ("%s  ·  Lv.%d %s"):format(if named then c.name else "이름 없음", c.level, CLASSES.classes[c.class].name), 16, 38, 348, { color = WHITE })
			Ui.text(panel, TXT.removeWarn, 16, 56, 348, { lines = 2, line = 12, color = GRAY })
			local y = 86
			local box: TextBox? = nil
			local doButton
			if named then
				Ui.text(panel, TXT.removeAsk, 16, y, 348, { color = GRAY })
				box = nameField(panel, 16, y + 16, 348, 24, c.name)
				y += 50
			end
			local say = Ui.text(panel, "", 16, y - 8, 348, { color = PINK })
			doButton = Ui.button(panel, TXT.removeDo, 16, y + 8, 170, function()
				if busy or (named and (not box or box.Text ~= c.name)) then
					return
				end
				local res = ask("delete", c.id, if named then c.name else nil)
				if res and res.ok then
					view = res.select
					picked = math.max(1, picked - 1)
					showSelect(nil)
				elseif dim.Parent then
					say:set(if res then res.why or TXT.failed else TXT.failed)
				end
			end)
			Ui.button(panel, TXT.cancel, 194, y + 8, 170, function()
				dim:Destroy()
			end, { main = true })
			if box then
				local field = box
				doButton:setEnabled(false)
				field:GetPropertyChangedSignal("Text"):Connect(function()
					doButton:setEnabled(field.Text == c.name)
				end)
				field:CaptureFocus()
			end
		end

		enterButton = Ui.button(bottom, TXT.enter, 0, 16, 160, enter, { main = true })
		enterButton.frame.Name = "Enter"
		createButton = Ui.button(bottom, TXT.create, 168, 16, 132, function()
			if #chars < max and not busy then
				switch(showCreate)
			end
		end)
		createButton.frame.Name = "Create"
		removeButton = Ui.button(bottom, TXT.remove, 308, 16, 132, openRemove)
		removeButton.frame.Name = "Remove"
		for i, s in slots do
			if s.hit then
				s.hit.Activated:Connect(function()
					if i == picked then
						enter() -- 고른 캐릭터를 한 번 더 누르면 들어간다
					else
						picked = i
						refresh()
					end
				end)
			end
		end
		refresh()
		place()
		stageStep = function(_dt)
			for i, s in slots do
				if s.sprite then
					local frame = if i == picked then Sprite.frameAt(s.sprite.char, "idle", clock, false) else 1
					s.sprite:set("idle", frame, s.x, GROUND, 1)
				end
			end
			local s = slots[picked]
			mark.Position = UDim2.fromOffset(math.floor(s.x) - 2, GROUND - 30 + math.floor(math.sin(clock * 3) + 0.5))
		end
		stageKey = function(key)
			if b:FindFirstChild("Dim") then
				return -- 상자가 떠 있다
			end
			if key == Enum.KeyCode.Left then
				picked = (picked - 2) % #chars + 1
				refresh()
			elseif key == Enum.KeyCode.Right then
				picked = picked % #chars + 1
				refresh()
			elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
				enter()
			end
		end
	end

	-- ---------- 캐릭터 만들기 ----------
	showCreate = function()
		local a, b = open()
		local order = CLASSES.order
		local n = #order
		local slots = {}
		for i, id in order do
			local slot = { id = id, class = CLASSES.classes[id], x = G.VIEW_W / 2 + (i - (n + 1) / 2) * T.create.gap }
			slot.sprite = Sprite.new(a, id, 2)
			slot.show, slot.showTime = showOf(id)
			slot.name = Ui.tag(b, slot.class.name, WHITE, 140)
			local hit = Instance.new("TextButton")
			hit.Name = "Class_" .. id
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.ZIndex = 8
			hit.Parent = b
			slot.hit = hit
			slots[i] = slot
		end
		header(b, TXT.createTitle, TXT.createHint)
		local W, H = 600, 100
		local holder = Stage.place(b, "Panel", "bc", Stage.REF_W / 2 - W / 2, Stage.REF_H - H - 8, W, H)
		local panel = Ui.panel(holder, 0, 0, W, H)
		-- 왼쪽: 고른 직업
		local head = Ui.text(panel, "", 14, 11, 272, { font = "body", color = MINT })
		local weapon = Ui.text(panel, "", 14, 13, 272, { align = "right", color = GRAY })
		local role = Ui.text(panel, "", 14, 32, 272, { lines = 2, line = 14 })
		Ui.box(panel, 300, 12, 1, H - 24, C.line)
		-- 오른쪽: 이름
		Ui.text(panel, TXT.nameLabel, 314, 11, 60, { color = WHITE })
		Ui.text(panel, TXT.nameRule, 314, 11, 272, { align = "right", color = OFF })
		local box = nameField(panel, 314, 28, 176, 24, TXT.namePlaceholder)
		local say = Ui.text(panel, TXT.needCheck, 314, 58, 272, { lines = 2, line = 12, color = GRAY })
		local chosen = math.ceil(n / 2)
		local chosenAt = 0
		local okName: string? = nil
		local makeButton
		-- 적고 있는 이름을 고른 직업의 머리 위에 이름표로 보여 준다(게임 안에서 보일 글씨 그대로 — 글꼴에 없는 글자는 "?"로 보인다)
		local preview = Ui.tag(b, "", WHITE, 140, true)
		local function placePreview()
			local cx, top = toUi(slots[chosen].x, GROUND - 27)
			preview.Frame.Position = UDim2.fromOffset(cx - math.floor(preview.Width / 2), top - Ui.TAG_H)
		end
		local function show()
			local slot = slots[chosen]
			local c = slot.class
			head:color(if c.tone == "pink" then PINK else MINT)
			head:set(c.name)
			weapon:set(c.weapon)
			role:set(c.role)
			for i, s in slots do
				s.name:SetColor(if i == chosen then WHITE else GRAY)
				s.sprite.label.ImageColor3 = if i == chosen then Color3.new(1, 1, 1) else Color3.fromRGB(150, 160, 178)
			end
			chosenAt = clock
			placePreview()
		end
		local function place()
			for _, s in slots do
				local cx, gy = toUi(s.x, GROUND)
				s.name.Frame.Position = UDim2.fromOffset(cx - math.floor(s.name.Width / 2), gy + 7)
				local w, h = toUi(T.create.gap, 44)
				s.hit.Position = UDim2.fromOffset(cx - math.floor(w / 2), gy - h)
				s.hit.Size = UDim2.fromOffset(w, h + 22)
			end
			placePreview()
		end
		stagePlace = place
		local function fail(res)
			say:color(PINK)
			say:set(if res then res.why or TXT.failed else TXT.failed)
		end
		local function check()
			if busy then
				return
			end
			local name = box.Text
			okName = nil
			makeButton:setEnabled(false)
			say:color(GRAY)
			say:set(TXT.checking)
			local res = ask("check", name, nil)
			if not panel.Parent then
				return
			end
			if res and res.ok then
				okName = name
				say:color(MINT)
				say:set(TXT.nameFree)
				makeButton:setEnabled(true)
			else
				fail(res)
			end
		end
		Ui.button(panel, TXT.check, 496, 28, 90, check, { h = 24 }).frame.Name = "Check"
		local backButton = Ui.button(panel, TXT.back, 14, 66, 100, function()
			if #view.chars > 0 and not busy then
				switch(function()
					showSelect(nil)
				end)
			end
		end)
		backButton.frame.Name = "BackButton"
		backButton.frame.Visible = #view.chars > 0 -- 첫 캐릭터를 만들 때는 돌아갈 고르기 화면이 없다
		makeButton = Ui.button(panel, TXT.make, 122, 66, 164, function()
			if busy or not okName or okName ~= box.Text or result then
				return
			end
			say:color(GRAY)
			say:set(TXT.wait)
			local res = ask("create", okName, slots[chosen].id)
			if not (res and res.ok) then
				if panel.Parent then
					fail(res)
					makeButton:setEnabled(false)
					okName = nil
				end
				return
			end
			-- 만든 캐릭터로 바로 들어간다
			view = res.select
			local entered = ask("enter", res.id, nil)
			if entered and entered.self then
				result = entered
			else
				view = if entered and entered.select then entered.select else view -- 서버가 준 목록으로(그 사이 이름이 비워졌으면 그것이 보이게 — 2026-10-18 검토)
				picked = #view.chars
				showSelect(if entered then entered.why else TXT.failed)
			end
		end, { main = true })
		makeButton.frame.Name = "Make"
		makeButton:setEnabled(false)
		box:GetPropertyChangedSignal("Text"):Connect(function()
			preview:SetText(box.Text)
			placePreview()
			if okName and box.Text ~= okName then
				okName = nil
				makeButton:setEnabled(false)
				say:color(GRAY)
				say:set(TXT.needCheck)
			end
		end)
		box.FocusLost:Connect(function(enter: boolean)
			if enter and box.Text ~= "" then
				check()
			end
		end)
		for i, s in slots do
			s.hit.Activated:Connect(function()
				if chosen ~= i then
					chosen = i
					show()
				end
			end)
		end
		show()
		place()
		-- 고른 직업은 기술을 써 보이고, 나머지는 서 있다.
		--  고른 직업: 서 있다가(lead초) 기술을 한 번 쓰고, 다시 서 있다가(rest초) 또 쓴다. 서 있는 동작은 그때마다 첫 장부터 튼다 —
		--   고른 순간과 기술이 끝난 순간에 서 있는 동작의 중간 장으로 건너뛰지 않게(사용자 2026-10-10: "자연스럽지가 않고")
		stageStep = function(_dt)
			for i, s in slots do
				local char = s.sprite.char
				local clip, frame = "idle", Sprite.frameAt(char, "idle", clock + i * 0.2, false)
				if i == chosen then
					local t = clock - chosenAt
					local sk, total = s.show, s.showTime
					if sk and total > 0 and t >= SHOW.lead then
						t = (t - SHOW.lead) % (total + SHOW.rest)
						if t < total then
							local at = t * SHOW.speed -- 게임 안의 시간으로
							for _, seg in sk.segs do
								if at < seg.time then
									clip, frame = seg.clip, seg.from + math.min(seg.to - seg.from, math.floor(at * seg.fps)) + 1
									break
								end
								at -= seg.time
							end
						else
							frame = Sprite.frameAt(char, "idle", t - total, false)
						end
					else
						frame = Sprite.frameAt(char, "idle", t, false)
					end
				end
				s.sprite:set(clip, frame, s.x, GROUND, 1)
			end
		end
		stageKey = function(key)
			if key == Enum.KeyCode.Left then
				chosen = (chosen - 2) % n + 1
				show()
			elseif key == Enum.KeyCode.Right then
				chosen = chosen % n + 1
				show()
			end
		end
	end

	-- ---------- 돌리기 ----------
	-- 화면은 BindToRenderStep으로 고친다(게임 화면 boot.luau와 같은 때). RunService.RenderStepped 이벤트에서 고치면 안 된다:
	--  그 이벤트는 Roblox가 그 장의 틀 크기를 이미 셈한 뒤에 불려서, 캐릭터 그림의 자리(ImageRect)는 이번 장에 · 틀의 크기(Size)는 다음 장에 적용된다.
	--  그러면 동작의 장이 바뀔 때마다 한 장씩 「새 그림이 앞 장의 크기로 늘어나거나 눌린 채」 그려진다 — 크기가 크게 다른 장 사이(기술이 끝나 서는 자세로 돌아올 때)에서 크게 튄다.
	--  (사용자 2026-10-10의 영상 bug.mp4: "애니메이션 종료시점이랑 돌아오는게 연결이 안되서 엄청나게 이상하게 튕기는 현상". 시험으로 확인: 같은 값을 RenderStepped에서 넣으면 어긋나고 BindToRenderStep에서 넣으면 맞는다.)
	local connections = {}
	local STEP_NAME = "LuneTitle"
	pcall(function()
		RunService:UnbindFromRenderStep(STEP_NAME)
	end)
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value - 1, function(dt)
		clock += dt
		-- 구름: 왼쪽으로 흘러가고, 한 장이 지나가면 뒤에 이어 붙는다
		local off = (clock * CLOUD_SPEED) % T.clouds.w
		clouds[1].Position = UDim2.fromOffset(-math.floor(off), 0)
		clouds[2].Position = UDim2.fromOffset(T.clouds.w - math.floor(off), 0)
		-- 달가루: 천천히 떠오르며 흔들리고, 위에서 사라졌다가 땅에서 다시 생긴다
		for _, d in dust do
			d.y -= d.speed * dt
			d.life += dt * 0.25
			if d.y < 8 then
				d.y = GROUND - 2
				d.x = rng:NextNumber(0, G.VIEW_W)
				d.life = 0
			end
			d.frame.Position = UDim2.fromOffset(math.floor(d.x + math.sin(clock * 0.8 + d.sway) * 3), math.floor(d.y))
			d.frame.BackgroundTransparency = 0.25 + 0.5 * math.abs(math.sin(clock * 1.3 + d.sway))
		end
		-- 제목은 처음에 천천히 나타난다
		logo.ImageTransparency = math.clamp(1 - (clock - 0.3) / 1.2, 0, 1)
		-- 단계를 바꿀 때의 어둠
		if shadeT < 1 then
			shadeT = math.min(1, shadeT + dt / (if shadeTo == 1 then FADE * 1.6 else FADE))
			shade.BackgroundTransparency = shadeFrom + (shadeTo - shadeFrom) * shadeT
		end
		if stageStep then
			stageStep(dt)
		end
	end)
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() or busy then
			return
		end
		if stageKey then
			stageKey(input.KeyCode)
		end
	end))
	local unResize = Stage.onResize(function()
		if over.Parent and stagePlace then
			stagePlace()
		end
	end)
	table.insert(connections, { Disconnect = function() unResize() end }) -- (닫을 때 함께 뺀다)

	shadeFrom, shadeTo, shadeT = 0, 1, 0
	shade.BackgroundTransparency = 0
	if io.skipLoading then
		showSelect(nil) -- 게임 안에서 돌아온 것: 불러올 것이 없다
	else
		showLoading()
	end
	while not result do
		task.wait()
	end
	for _, c in connections do
		c:Disconnect()
	end
	RunService:UnbindFromRenderStep(STEP_NAME)
	Title.root, Title.over = root, over -- 게임 화면이 그려질 때까지 그대로 둔다 — 부른 쪽이 close()로 닫는다
	return result
end

function Title.close()
	if Title.root then
		Title.root:Destroy()
		Title.root = nil
	end
	if Title.over then
		Title.over:Destroy()
		Title.over = nil
	end
end

return Title
