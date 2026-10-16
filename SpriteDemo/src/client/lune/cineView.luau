-- 퀘스트 연출(장면)의 그리기(2026-10-15) — 공방 「횡스크롤 시험」 탭의 장면(js/lune/luneTab.js의 drawCineActors · drawCineOver · paintCine)과 같은 자리 · 모양.
--  사용자 2026-10-15: "현재 메인 퀘스트 라인 너무스토리 몰입이 안됩니다 … 몰입되는 중간에 연출이 있는것도아니고 다른게임들 어떻게 스토리 진행하는지 좀 파악하고 만들어야합니다."
--  셈은 shared/lune/cine.luau(무엇이 언제 끝나나 · 누가 어디에). 여기서는 그 상태를 화면에 옮긴다:
--   세계(게임 도트): 장면이 세운 졸개 · 주민 · 쓰러질 때 흩어지는 재 / 화면 틀(고운 격자): 색 덮개 · 큰 그림 · 위아래 검은 띠 · 암전 · 장의 이름 · 보스의 이름 · 종이 · 머리 위 표시 · 「건너뛰기」
--   말은 아래의 대화창(ui/talk.luau의 Talk.cine)에 뜬다. 카메라 · 주민의 자리는 sceneView.luau가 장면의 값(camOverride · npcOver)을 읽는다.
--  boot.luau가 부른다: CineView.init(부모) · CineView.play(def, 세계) · CineView.update(dt, 세계의 층) · CineView.input("next" | "skip") · CineView.active()
--  퀘스트 동안의 맵 모습(불타는 마을의 붉은 하늘 — 장면 밖에서도): CineView.setLook(색, 비침)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local lune = ReplicatedStorage.shared.lune
local Cine = require(lune.cine)
local SCENES = require(lune.data["scenes.generated"])
local ASSETS = require(lune.data["assets.generated"])
local CHARS = require(lune.data["chars.generated"])
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Overlay = require(script.Parent.overlay)
local Sprite = require(script.Parent.sprite)
local Ui = require(script.Parent.ui.ui)
local Talk = require(script.Parent.ui.talk)
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)

local C = Ui.COLOR
local M = Ui.M
local CL = Layout.CINE
local LK = Cine.DATA.ui
local CPS = Format.DIALOG.cps
local INK = Color3.fromRGB(5, 7, 11)
local PINK = Color3.fromRGB(255, 126, 162)
local MINT = Color3.fromRGB(62, 255, 215)
local ASH = { Color3.fromRGB(201, 204, 209), Color3.fromRGB(139, 144, 152), Color3.fromRGB(74, 79, 87) }

local View = {}
View.onEnd = nil :: ((any) -> ())? -- 장면이 끝났다(def) — boot가 서버에 「봤다」를 알리고 다음 장면을 튼다

local low: Frame, high: Frame
local lookTint: Frame, tint: Frame, backdrop: Frame, picture: ImageLabel, glow: Frame, glowStroke: UIStroke
local cardBand: Frame, titleBand: Frame, barTop: Frame, barBottom: Frame, shade: Frame
local cardBox: Frame, cardText, cardSub, cardLines: { Frame }
local titleBox: Frame, titleText, titleSub, titleLine: Frame
local noteBox: Frame, notePaper: ImageLabel, noteShadow: ImageLabel, noteTitle, noteRows: { any }, noteHint, noteKey
local skipBtn, skipEsc, catcher: TextButton
local marks: { any } = {}
local session: any = nil

local function bigLabel(parent: Instance, color: Color3)
	-- 두 배 글: 틀에 UIScale 2를 걸고 그 안에 본문 글씨(테두리)를 놓는다
	local box = Ui.group(parent, 0, 0, 10, 10, "Big")
	local scale = Instance.new("UIScale")
	scale.Scale = 2
	scale.Parent = box
	local t = Ui.text(box, "", 0, 0, 400, { font = "body", outline = true, color = color })
	return box, t
end

-- 글씨(글자 그림들)의 비침 — 장의 이름 · 보스의 이름이 서서히 나타나고 사라진다
local function fadeText(root: Instance, a: number)
	for _, d in root:GetDescendants() do
		if d:IsA("ImageLabel") then
			d.ImageTransparency = 1 - a
		end
	end
end

function View.init(parent: Instance)
	low = Stage.group(parent, "CineLow", 55) -- 대화창(60) 아래: 세계를 덮는 것
	high = Stage.group(parent, "CineHigh", 70) -- 대화창 위: 글 · 단추
	low.Visible, high.Visible = false, false
	local function full(name: string, color: Color3, z: number): Frame
		local f = Ui.box(low, 0, 0, 1, 1, color, 1)
		f.Name, f.Size, f.ZIndex = name, UDim2.fromScale(1, 1), z
		return f
	end
	lookTint = Stage.group(parent, "CineLook", 54) -- 퀘스트 동안의 맵 모습(장면 밖에서도 보인다)
	lookTint.BackgroundTransparency = 1
	lookTint.BackgroundColor3 = Color3.new(1, 0, 0)
	tint = full("Tint", C.ink, 1)
	backdrop = full("Backdrop", INK, 2)
	picture = Stage.image(low, "Picture", "", 1, 1)
	picture.ZIndex = 3
	glow = Ui.box(low, 0, 0, 1, 1, MINT, 1)
	glow.ZIndex = 4
	glowStroke = Instance.new("UIStroke")
	glowStroke.Color = MINT
	glowStroke.Thickness = 2
	glowStroke.Parent = glow
	cardBand = full("CardBand", INK, 5)
	cardBand.Size = UDim2.new(1, 0, 0, 1)
	titleBand = full("TitleBand", INK, 5)
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new(0, 1)
	grad.Parent = titleBand
	barTop = full("BarTop", Color3.new(0, 0, 0), 6)
	barBottom = full("BarBottom", Color3.new(0, 0, 0), 6)
	shade = full("Fade", Color3.new(0, 0, 0), 7)
	-- 위: 장의 이름(가운데) · 보스의 이름(왼쪽 아래) · 종이 · 머리 위 표시 · 「건너뛰기」
	catcher = Ui.hit(high) -- 화면 아무 데나 누르면 넘긴다(스마트폰 · 마우스) — 단추는 이 위에
	catcher.Name = "CineNext"
	catcher.ZIndex = 1 -- 「건너뛰기」 단추가 이 위에 온다
	catcher.Activated:Connect(function()
		View.input("next")
	end)
	cardBox = Ui.group(high, 0, 0, 10, 10, "Card")
	local cb
	cb, cardText = bigLabel(cardBox, C.text)
	cardSub = Ui.text(cardBox, "", 0, 0, 400, { color = C.dim, align = "center" })
	cardLines = { Ui.box(cardBox, 0, 0, 1, 1, C.accent), Ui.box(cardBox, 0, 0, 1, 1, C.accent) }
	cardBox:SetAttribute("big", cb.Name)
	titleBox = Ui.group(high, 0, 0, 10, 10, "BossTitle")
	local tb
	tb, titleText = bigLabel(titleBox, C.gold)
	titleSub = Ui.text(titleBox, "", 0, 0, 400, { color = PINK, outline = true })
	titleLine = Ui.box(titleBox, 0, 0, 1, 1, C.accent)
	noteBox = Ui.group(high, 0, 0, 10, 10, "Note")
	noteShadow = Ui.part(noteBox, "uBubble", 0, 3, 10, 10)
	noteShadow.ImageColor3 = Color3.fromRGB(150, 160, 170)
	notePaper = Ui.part(noteBox, "uBubble", 0, 0, 10, 10)
	noteTitle = Ui.text(noteBox, "", CL.notePad, CL.notePad, CL.noteW - CL.notePad * 2, { color = C.dim })
	noteRows = {}
	for i = 1, 8 do
		noteRows[i] = Ui.text(noteBox, "", CL.notePad, 0, CL.noteW - CL.notePad * 2, { font = "body", color = C.bubbleInk })
	end
	noteHint = Ui.text(noteBox, "닫기", 0, 0, 60, { outline = true })
	noteKey = Ui.keycap(noteBox, "↑", 0, 0)
	for i = 1, 4 do
		marks[i] = Ui.text(high, "", 0, 0, 40, { font = "body", outline = true, align = "center", color = C.text })
		marks[i]:show(false)
	end
	skipBtn = Ui.button(high, CL.skip, 0, 0, CL.skipW, function()
		View.input("skip")
	end, { h = CL.skipH })
	skipBtn.frame.ZIndex = 20
	skipEsc = Ui.text(high, "Esc", 0, 0, 30, { color = C.dim, outline = true, align = "right" })
	-- Esc: 건너뛰기(장면이 도는 동안만)
	UserInputService.InputBegan:Connect(function(input, processed)
		if session and not processed and input.KeyCode == Enum.KeyCode.Escape then
			View.input("skip")
		end
	end)
end

function View.active(): boolean
	return session ~= nil
end
function View.state(): any
	return session and session.st
end

-- 퀘스트 동안의 맵 모습: 색(nil이면 걷는다) · 비침
function View.setLook(color: Color3?, a: number)
	lookTint.BackgroundColor3 = color or Color3.new(0, 0, 0)
	lookTint.BackgroundTransparency = if color then 1 - a else 1
end

-- 이 맵에 없는 주민을 장면에 세울 때: 그 주민이 서 있는 장면의 주민 그림판 · 칸
local function npcArt(id: string)
	for _, sc in SCENES.scenes do
		if sc.npcs and sc.npcSheet then
			for _, n in sc.npcs do
				if n.id == id then
					return { image = ASSETS[sc.npcSheet] or "", cell = n.cell, nw = sc.npcCell[1], nh = sc.npcCell[2], name = n.name, cols = sc.npcCols or 999 }
				end
			end
		end
	end
	return nil
end
View.npcArt = npcArt

-- 장면을 튼다. w = 세계를 묻는 창구(shared/lune/cine.luau의 머리말) · world = 세계의 층(장면이 세운 것을 그 위에 놓는다)
function View.play(def, w, world: Frame)
	if session then
		View.stop()
	end
	session = { def = def, st = Cine.new(def, w), w = w, world = world, actors = {}, ash = {}, sayObj = nil, cardObj = nil, titleObj = nil, noteObj = nil, picShown = nil, clock = 0 }
	low.Visible, high.Visible = true, true
	return session.st
end

local function clearActors(s)
	for _, a in s.actors do
		if a.sprite then
			a.sprite:destroy()
		end
		if a.label then
			a.label:Destroy()
		end
	end
	s.actors = {}
	for _, p in s.ash do
		p.f:Destroy()
	end
	s.ash = {}
end

function View.stop()
	local s = session
	if not s then
		return
	end
	session = nil
	clearActors(s)
	Talk.cine(nil)
	low.Visible, high.Visible = false, false
	for _, m in marks do
		m:show(false)
	end
	if View.onEnd then
		View.onEnd(s.def)
	end
end

-- 누름: "next"(↑ · 스페이스 · 누르기) · "skip"(Esc · 「건너뛰기」)
function View.input(kind: string)
	local s = session
	if not s then
		return
	end
	local st = s.st
	if kind == "next" and st.wait and st.wait.input == "say" then
		if not Talk.cineFull() then
			Talk.cineReveal() -- 나오는 중이면 한 번에 다 보이고
			return
		end
		st.say.t = 1e9
	end
	Cine.input(st, kind, CPS)
end

-- 장면이 세운 것 하나를 그린다(졸개 = 그 졸개의 그림 · 주민 = 주민 그림판의 칸)
local function drawActor(s, key: string, a)
	local v = s.actors[key]
	if not v then
		v = {}
		if a.mob and CHARS.chars[a.mob] then
			v.sprite = Sprite.new(s.world, a.mob, 4)
		elseif a.npc then
			local art = npcArt(a.npc)
			if art then
				v.art = art
				v.label = Stage.image(s.world, "Cine_" .. key, art.image, art.nw, art.nh)
				v.label.ZIndex = 4
			end
		end
		s.actors[key] = v
	end
	if v.sprite then
		local char = CHARS.chars[a.mob]
		local clip = if a.clip == "death" and char.clips.death then "death" elseif a.walk and char.clips.run then "run" else "idle"
		v.sprite:set(clip, Sprite.frameAt(char, clip, a.t or 0, clip == "death"), a.x, a.y, a.dir)
		v.sprite.label.ImageTransparency = 1 - (a.alpha or 1)
		v.sprite.label.Visible = not a.hidden and v.sprite.label.Visible
		-- 쓰러지기 시작했다: 재가 흩어진다(한 번)
		if a.dying and not v.ashed then
			v.ashed = true
			for i = 1, 18 do
				local f = Ui.box(s.world, math.floor(a.x), math.floor(a.y - 12), 1, 1, ASH[(i % 3) + 1])
				f.ZIndex = 5
				local ang = math.rad(-160 + (i / 18) * 140)
				table.insert(s.ash, { f = f, x = a.x, y = a.y - 12, vx = math.cos(ang) * (14 + (i % 5) * 4), vy = math.sin(ang) * (16 + (i % 4) * 6), t = 0 })
			end
		end
	elseif v.label then
		local art = v.art
		local frame = math.floor(s.clock * (if a.walk then 8 else 1.6)) % 2
		local cols = art.cols or 999 -- 그림판을 cols칸마다 접었다(2026-10-16)
		local x, y = (art.cell % cols) * art.nw, (art.cell // cols * 2 + frame) * art.nh
		if (a.dir or 1) >= 0 then
			v.label.ImageRectOffset, v.label.ImageRectSize = Vector2.new(x, y), Vector2.new(art.nw, art.nh)
		else
			v.label.ImageRectOffset, v.label.ImageRectSize = Vector2.new(x + art.nw, y), Vector2.new(-art.nw, art.nh)
		end
		v.label.Position = UDim2.fromOffset(math.floor(a.x - art.nw / 2 + 0.5), a.y - art.nh)
		v.label.ImageTransparency = 1 - (a.alpha or 1)
		v.label.Visible = not a.hidden
	end
end

-- 매 화면: 셈을 흘리고 그린다. 장면이 끝나면 거두고 onEnd를 부른다
function View.update(dt: number)
	local s = session
	if not s then
		return
	end
	local st = s.st
	s.clock += dt
	Cine.step(st, dt)
	if st.done then
		View.stop()
		return
	end
	local W, H = Stage.uiW, Stage.uiH
	-- 세계: 장면이 세운 것 · 재
	for key, a in st.actors do
		drawActor(s, key, a)
	end
	for i = #s.ash, 1, -1 do
		local p = s.ash[i]
		p.t += dt
		p.vy += 30 * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.f.Position = UDim2.fromOffset(math.floor(p.x + 0.5), math.floor(p.y + 0.5))
		p.f.BackgroundTransparency = math.min(1, p.t / 1.1)
		if p.t >= 1.1 then
			p.f:Destroy()
			table.remove(s.ash, i)
		end
	end
	-- 색 덮개
	tint.BackgroundColor3 = if st.tint then Color3.fromHex(st.tint) else C.ink
	tint.BackgroundTransparency = if st.tint then 1 - st.tintA else 1
	-- 큰 그림(가운데 · 게임 도트의 크기 그대로 키운다) · 내 직업의 사람에게 빛
	local pd = st.picture and Cine.DATA.pictures[st.picture]
	backdrop.BackgroundTransparency = if pd then 0.18 else 1
	picture.Visible = pd ~= nil
	glow.Visible = false
	if pd then
		local r = Stage.ratio
		local pw, ph = math.floor(pd.w * r + 0.5), math.floor(pd.h * r + 0.5)
		local px, py = math.floor((W - pw) / 2), math.floor((H - ph) / 2 - 12 * r)
		picture.Image = ASSETS[pd.files[s.w.cls]] or ""
		picture.Position, picture.Size = UDim2.fromOffset(px, py), UDim2.fromOffset(pw, ph)
		local col = st.glow and pd.cols[s.w.cls]
		if col then
			local pulse = 0.5 + 0.5 * math.sin(st.clock * 4)
			glow.Visible = true
			glow.Position = UDim2.fromOffset(px + math.floor(col[1] * r), py + math.floor(pd.rows[1] * r))
			glow.Size = UDim2.fromOffset(math.floor((col[2] - col[1]) * r), math.floor((pd.rows[2] - pd.rows[1]) * r))
			glow.BackgroundTransparency = 1 - (0.1 + 0.1 * pulse)
			glowStroke.Transparency = 1 - (0.55 + 0.45 * pulse)
		end
	end
	-- 장의 이름의 띠 · 보스의 이름의 띠
	local cardA = if st.card then Cine.cardAlpha(st.card, LK.card) else 0
	local cy = math.floor(H * CL.cardY)
	cardBand.Position, cardBand.Size = UDim2.fromOffset(0, cy - 75), UDim2.new(1, 0, 0, 150)
	cardBand.BackgroundTransparency = 1 - 0.78 * cardA
	local titleA = if st.title then Cine.cardAlpha(st.title, LK.title) else 0
	local ty = math.floor(H * CL.titleY)
	titleBand.Position, titleBand.Size = UDim2.fromOffset(0, ty - 25), UDim2.fromOffset(math.floor(W * 0.7), 115)
	titleBand.BackgroundTransparency = 1 - 0.7 * titleA
	-- 위아래 검은 띠 · 암전
	local bh = math.floor(LK.bars * Stage.ratio * st.bars + 0.5)
	barTop.Size, barBottom.Size = UDim2.new(1, 0, 0, bh), UDim2.new(1, 0, 0, bh)
	barTop.Position, barBottom.Position = UDim2.fromOffset(0, 0), UDim2.new(0, 0, 1, -bh)
	barTop.BackgroundTransparency, barBottom.BackgroundTransparency = if bh > 0 then 0 else 1, if bh > 0 then 0 else 1
	shade.BackgroundTransparency = 1 - st.fade
	-- 장의 이름(가운데 · 두 배 글)
	cardBox.Visible = st.card ~= nil
	if st.card then
		if s.cardObj ~= st.card then
			s.cardObj = st.card
			cardText:set(st.card.text)
			cardSub:set(st.card.sub)
		end
		local tw = select(1, cardText:size()) * 2
		local lw = tw + 40
		cardBox.Position, cardBox.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(W, H)
		local big = cardBox:FindFirstChild("Big") :: Frame
		big.Position = UDim2.fromOffset(math.floor((W - tw) / 2), cy - M.body)
		cardLines[1].Position, cardLines[1].Size = UDim2.fromOffset(math.floor((W - lw) / 2), cy - M.body - 12), UDim2.fromOffset(lw, 1)
		cardLines[2].Position, cardLines[2].Size = UDim2.fromOffset(math.floor((W - lw) / 2), cy + M.body + 10), UDim2.fromOffset(lw, 1)
		cardSub:move(math.floor(W / 2) - 200, cy + M.body + 18)
		fadeText(cardBox, cardA)
		cardLines[1].BackgroundTransparency, cardLines[2].BackgroundTransparency = 1 - cardA, 1 - cardA
	end
	-- 보스의 이름(왼쪽 아래)
	titleBox.Visible = st.title ~= nil
	if st.title then
		if s.titleObj ~= st.title then
			s.titleObj = st.title
			titleText:set(st.title.text)
			titleSub:set(st.title.sub)
		end
		local tw = select(1, titleText:size()) * 2
		local big = titleBox:FindFirstChild("Big") :: Frame
		titleBox.Position, titleBox.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(W, H)
		big.Position = UDim2.fromOffset(CL.titleX, ty)
		titleLine.Position, titleLine.Size = UDim2.fromOffset(CL.titleX, ty + M.body * 2 + 8), UDim2.fromOffset(math.max(tw, Ui.measure(st.title.sub)) + 16, 1)
		titleSub:move(CL.titleX, ty + M.body * 2 + 14)
		fadeText(titleBox, titleA)
		titleLine.BackgroundTransparency = 1 - titleA
	end
	-- 종이(명령서)
	noteBox.Visible = st.note ~= nil
	if st.note and s.noteObj ~= st.note then
		s.noteObj = st.note
		local tw = CL.noteW - CL.notePad * 2
		noteTitle:set(st.note.title)
		local y = CL.notePad + M.smallLine + 10
		local row = 1
		for _, text in st.note.text do
			for _, ln in string.split(pixelText.Fit(text, tw, 2, "body"), "\n") do
				if noteRows[row] then
					noteRows[row]:set(ln)
					noteRows[row]:move(CL.notePad, y)
					noteRows[row]:show(true)
					row += 1
					y += M.bodyLine
				end
			end
			y += 4
		end
		for i = row, #noteRows do
			noteRows[i]:show(false)
		end
		local h = y - 4 + CL.notePad + 14
		local x0, y0 = math.floor((W - CL.noteW) / 2), math.floor((H - h) / 2) - 20
		noteBox.Position, noteBox.Size = UDim2.fromOffset(x0, y0), UDim2.fromOffset(CL.noteW, h + 30)
		notePaper.Size, noteShadow.Size = UDim2.fromOffset(CL.noteW, h), UDim2.fromOffset(CL.noteW, h)
		local hw = Ui.measure("닫기")
		noteHint:move(CL.noteW - CL.notePad - hw, h + 8)
		noteKey:move(CL.noteW - CL.notePad - hw - 12, h + 6)
	end
	-- 말(아래의 대화창)
	if st.say ~= s.sayObj then
		s.sayObj = st.say
		if st.say then
			Talk.cine(st.say.name, st.say.text)
		else
			Talk.cine(nil)
		end
	end
	-- 머리 위의 작은 표시(! ? …)
	for i, m in marks do
		local q = st.marks[i]
		local p = q and Cine.posOf(st, q.who)
		if q and p then
			local up = if q.who == "hero" then 26 elseif q.who == "boss" then 90 else 28
			m:set(q.kind)
			m:color(if q.kind == "!" then C.gold else C.text)
			m:move(Overlay.x(p.x) - 20, Overlay.y(p.y - up) - 16)
			m:show(true)
		else
			m:show(false)
		end
	end
	-- 「건너뛰기」(오른쪽 위)
	local sx = W - CL.skipW - CL.edge
	skipBtn.frame.Position = UDim2.fromOffset(sx, CL.edge)
	skipEsc:move(sx - 36, CL.edge + math.floor((CL.skipH - M.small) / 2))
	skipEsc:show(not UserInputService.TouchEnabled)
end

-- 이름표를 숨길 때인가(암전 · 큰 그림 — 이름표가 덮개 위로 비치지 않게)
function View.hideTags(): boolean
	local st = session and session.st
	return st ~= nil and (st.fade > 0.3 or st.picture ~= nil)
end

return View
