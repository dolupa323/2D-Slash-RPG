-- 튜토리얼 「달빛 꿈」의 화면(2026-10-14) — 화면 위 가운데의 미션 판과, 화면만 아는 미션(걷기 · 뛰기 · 두 번 뛰기 · 내려가기 · 말 걸기 · 기술 · 창)이 끝났는지 보는 일.
--  사용자: "처음 게임을 시작하고 별도의 스타트맵을만들어서 거기서 조작을 알려주는 튜토리얼이 필요해 메이플스토리의 테라블링크를 예로들면 되겠다"
--  판: 첫 줄 = 「달빛 꿈 3/13 · 두 번 뛰기」(노랑) + 샛별의 말(흐린 글씨) · 둘째 줄 = 지금 누를 것(흰 글씨 — PC는 그 사람의 키 이름, 스마트폰은 단추 이름).
--  미션을 깨면 판의 오른쪽에 「완료!」(민트)가 잠깐 뜨고 다음 미션으로 바뀐다. 이 계정이 꿈을 한 번 끝냈으면 판 오른쪽에 「건너뛰기」 단추.
--  셈(무엇이 끝났나 · 글)은 shared/lune/sim/tutorial.luau, 진행의 진실은 서버가 갖는다(Net "Tut" — 화면은 "n째를 끝냈다"고만 알린다).
--  둘째 판(사용자: "인벤토리 열기이면 가방버튼이 반짝 반짝 빛나서 어디를 누르면 되는지 알려줘야하는거고 능력치,스킬도 마찬가지 모바일은 모바일 버튼 기준으로"):
--   미션마다 눌러야 할 단추 위에 민트 고리가 깜빡인다(point — design/tutorial.js). 창을 여는 미션은 창이 열리면 그 안의 「자동으로 찍기 · 추천대로 찍기」로 옮겨 가고,
--   스마트폰은 「메뉴」 단추 → 열린 메뉴의 그 줄 → 창 안의 단추 차례로 짚는다. 단추를 찾는 일은 boot.luau가 준다(c.find(이름) → 그 단추의 틀).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(ReplicatedStorage.shared.lune.sim.tutorial)
local Net = require(ReplicatedStorage.shared.lune.net.net)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)
local Music = require(script.Parent.music)

local C = Ui.COLOR
local M = Ui.M
local D = Tutorial.DATA
local P = D.panel

local View = {}
View.talked = nil :: string? -- 꿈에서 말을 끝낸 주민(Talk가 알려 준다)
View.dropped = false -- 얇은 발판을 내려왔다(↓ + 뛰기 — boot.luau가 알려 준다)
View.cast = false -- 첫 사냥기를 썼다(boot.luau의 trySkill)
View.startX = nil :: number? -- 꿈에 들어왔을 때 선 자리(걷기 미션)
View.onSkip = nil :: (() -> ())? -- 「건너뛰기」를 눌렀다(boot.luau가 서버에 묻고 장면을 바꾼다)

local root: Frame
local panel: Frame
local head, say, line, doneText
local skipBtn
local pending = false -- 서버에 "끝냈다"를 보내고 대답을 기다리는 중
local flash = 0 -- 「완료!」가 남은 시간
local shownStep = -1
local ring: Frame -- 반짝이는 고리(눌러야 할 단추 위)
local clock = 0

function View.init(parent: Instance)
	root = Stage.group(parent, "Tutorial", 90)
	root.Visible = false
	local h = 8 + M.bodyLine + M.smallLine + 8
	panel = Ui.panel(root, 0, 0, P.w, h)
	head = Ui.text(panel, "", 12, 8, 200, { font = "body", color = C.gold })
	say = Ui.text(panel, "", 0, 10, P.w - 24, { color = C.dim })
	line = Ui.text(panel, "", 12, 8 + M.bodyLine, P.w - 24, { color = C.text })
	doneText = Ui.text(panel, D.words.done, P.w - 60, 8, 48, { font = "body", color = C.accent, align = "right" })
	doneText:show(false)
	skipBtn = Ui.button(root, D.words.skip, 0, 0, 72, function()
		if View.onSkip then
			View.onSkip()
		end
	end, { h = 22 })
	skipBtn.frame.Visible = false
	ring = Instance.new("Frame")
	ring.Name = "TutRing"
	ring.BackgroundColor3 = C.accent
	ring.BackgroundTransparency = 0.82
	ring.BorderSizePixel = 0
	ring.ZIndex = 250
	ring.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.accent
	stroke.Thickness = 2
	stroke.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = ring
	ring.Parent = parent
end

-- 이 미션에서 반짝일 단추: c.find(이름) → 그 단추의 틀(보이는 것만)
local function targetOf(def, c): GuiObject?
	local point = def.point
	if not point or not c.find then
		return nil
	end
	local spec = if c.touch then point.touch else point.pc
	if not spec then
		return nil
	end
	local function shown(name: string): GuiObject?
		local f = c.find(name)
		if f and f.Parent and f.Visible and f.AbsoluteSize.X > 0 then
			return f
		end
		return nil
	end
	local win = string.match(spec, "^menu:(.+)$")
	if win then
		if c.windows and c.windows[win] then
			return if point.inside then shown("inside:" .. win) else nil -- 창이 열렸다: 그 안의 단추로
		end
		if c.touch then
			return shown("touchmenu:" .. win) or shown("touch:menu") -- 스마트폰: 「메뉴」 → 그 줄
		end
		return shown("menu:" .. win)
	end
	return shown((if c.touch then "touch:" else "pc:") .. spec)
end

-- 고리를 그 단추 위에 놓는다(화면 틀의 점으로 바꿔서 — 단추가 움직여도 따라간다)
local function drawRing(target: GuiObject?, dt: number)
	if not target then
		ring.Visible = false
		return
	end
	clock += dt
	local parent = ring.Parent :: GuiObject
	local scale = parent.AbsoluteSize.X / math.max(1, Stage.uiW)
	local pos = (target.AbsolutePosition - parent.AbsolutePosition) / scale
	local size = target.AbsoluteSize / scale
	local grow = 3 + math.floor((math.sin(clock * 7) + 1) * 1.5) -- 숨 쉬듯 커졌다 작아진다
	ring.Position = UDim2.fromOffset(pos.X - grow, pos.Y - grow)
	ring.Size = UDim2.fromOffset(size.X + grow * 2, size.Y + grow * 2)
	ring.Visible = math.floor(clock * 3) % 3 ~= 2 -- 깜빡인다
end

local function place()
	local x = math.floor((Stage.uiW - P.w) / 2)
	root.Position = UDim2.fromOffset(x, P.top)
	root.Size = UDim2.fromOffset(P.w + 80, 60)
	skipBtn.frame.Position = UDim2.fromOffset(P.w + 6, 4)
end

-- 다른 캐릭터로 들어왔다: 앞 캐릭터의 꿈에서 쌓인 것(내려옴 · 말을 끝냄 · 보낸 「끝냈다」)을 지운다(2026-10-18 검토 — 둘 다 꿈에 있으면 새 캐릭터의 미션이 바로 끝났다)
function View.reset()
	View.startX, View.talked, View.dropped, View.cast, pending, shownStep = nil, nil, false, false, false, -1
end

-- 매 화면. c = { tut(서버가 보낸 진행), skip(건너뛸 수 있나), scene(장면 이름표), zones(장면의 tut), body, touch, key(하는 일 → 키 이름), skill(첫 사냥기 「키 · 이름」), potion(물약 칸의 키), windows({ [id] = true }), dt, find(이름) → 반짝일 단추 }
function View.update(c)
	local t = c.tut
	local on = Tutorial.isDream(c.scene) and t ~= nil and not t.done
	root.Visible = on
	if not on then
		View.startX, View.talked, View.dropped, View.cast, pending, shownStep = nil, nil, false, false, false, -1
		ring.Visible = false
		return
	end
	place()
	if View.startX == nil and c.body then
		View.startX = c.body.x
	end
	local def = Tutorial.current(t)
	if not def then
		ring.Visible = false
		return
	end
	drawRing(targetOf(def, c), c.dt or 0)
	-- 미션이 바뀌었다: 「완료!」를 잠깐 띄운다(처음 들어왔을 때는 띄우지 않는다)
	if shownStep ~= t.step then
		if shownStep > 0 then
			flash = P.done
			Music.sfx("success") -- 미션을 깼다(퀘스트 완료와 같은 소리)
		end
		shownStep = t.step
		View.cast = false -- 「기술 쓰기」는 그 미션의 차례에 쓴 것만 센다
	end
	flash = math.max(0, flash - (c.dt or 0))
	doneText:show(flash > 0)
	-- 글
	local count = Tutorial.count(t)
	local headText = Tutorial.head(t) .. " · " .. def.title .. (if count then " " .. count else "")
	head:set(headText)
	local hw = Ui.measure(headText, "body")
	say:move(12 + hw + 10, 10)
	say:set(def.say)
	line:set(Tutorial.line(def, c.touch, c.key, c.skill, c.potion))
	skipBtn.frame.Visible = c.skip == true
	-- 화면만 아는 미션이 끝났는가 → 서버에 알린다(대답이 오면 서버가 보낸 내 상태로 판이 바뀐다)
	if pending or not Tutorial.CLIENT[Tutorial.kind(def)] or not c.body then
		return
	end
	local s = {
		walked = math.abs(c.body.x - (View.startX or c.body.x)),
		zone = Tutorial.zoneAt(c.zones, c.body.x, c.body.y, c.body.ground),
		drop = View.dropped,
		talked = View.talked,
		skill = View.cast,
		windows = c.windows,
	}
	if Tutorial.met(def, s) then
		pending = true
		local step = t.step
		task.spawn(function()
			pcall(Net.Invoke, "Tut", "done", step)
			pending = false
		end)
	end
end

return View
