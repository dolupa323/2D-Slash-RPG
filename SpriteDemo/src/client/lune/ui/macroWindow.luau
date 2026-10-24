-- 매크로 확인 창 · 「사냥 보상 멈춤」 띠(2026-10-23 사용자: "현재 게임에서 매크로 유저들이 많아 어떻게 잡을지 해결해봐").
--  공방 js/lune/design/macro.js(글 · 치수 look)와 시험 탭 js/lune/ui/paint.js의 paintMacro와 같은 그림이다. 문제를 내고 채점하는 것은 서버(modules/macroGuard.luau).
--  창: 제목 「매크로 확인」 · 남은 시간 / 「위의 몬스터 셋을 아래에서 모두 눌러 주세요」 / 위의 셋(누르지 않는다) / 아래 아홉(누르면 고름 · 다시 누르면 풂) /
--      고른 수 「n / 3」 · 남은 기회 / 「확인」(셋을 골랐을 때) · 「처음부터」. 마우스 · 손가락 모두(글을 읽지 않아도 풀린다 — 그림 맞추기).
--  띠: 보상이 멈췄으면 화면 위 가운데에 「사냥 보상 멈춤」 + 「눌러서 다시 확인」(누르면 새 문제) 또는 「n분 뒤에 다시 확인」.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lune = ReplicatedStorage.shared.lune
local D = require(lune.data["macro.generated"])
local CHARS = require(lune.data["chars.generated"])
local Net = require(lune.net.net)
local Format = require(lune.ui.format)
local Stage = require(script.Parent.Parent.stage)
local Sprite = require(script.Parent.Parent.sprite)
local Ui = require(script.Parent.ui)

local W, L = D.words, D.look
local C = Ui.COLOR
local M = Ui.M

local MacroWindow = {}
MacroWindow.say = nil :: ((text: string, good: boolean) -> ())? -- 머리 위에 띄우는 글(boot.luau가 단다)
MacroWindow.onOpen = nil :: (() -> ())? -- 새 문제가 떴다: 열려 있는 창 · 상점 · 대화를 닫는다(boot.luau가 단다 — 2026-10-24)

local layer: Frame? = nil
local win = nil -- { holder, view, picks, deadline, cells, okBtn, left, tries, picked, note, conn, busy }
local stop = { holder = nil :: Frame?, text = nil, hint = nil, stopped = false, retryAt = 0, conn = nil :: RBXScriptConnection? }

local function root(): Frame
	if not layer then
		-- 모든 화면 부품 위(2026-10-24 사용자 "매크로 뭐 다른 ui 열면 안열린다고" — 전에는 175라 달빛 상점(500) · 창 닫기 단추(300) · 단추 고르기(200)에 가려졌다). 장면을 바꾸는 막(curtain — 따로 1000)만 위
		layer = Stage.group(Stage.ui, "Macro", 950)
	end
	return layer :: Frame
end

-- 칸 안에 몬스터 하나(가운데 · 보이는 몸의 가장 긴 변 = L.pic — 작은 몬스터도 알아보게 키운다)
local function monster(parent: Frame, kind: string, frameNo: number, flip: boolean)
	local char = CHARS.chars[kind]
	if not char or not char.clips.idle then
		return
	end
	local world = Ui.group(parent, 0, 0, L.cell, L.cell, "Mob")
	world.ClipsDescendants = true
	local sp = Sprite.new(world, kind, 3)
	local frames = char.clips.idle.frames
	local n = math.clamp(frameNo, 1, #frames)
	local f = frames[n]
	local k = if f then L.pic / math.max(f[4], f[5]) else 1
	local dir = if flip then -1 else 1
	sp:set("idle", n, 0, 0, dir, k)
	-- 그린 자리를 재서 그림의 가운데를 칸의 가운데로
	local lab = sp.label
	local cx = lab.Position.X.Offset + lab.Size.X.Offset / 2
	local cy = lab.Position.Y.Offset + lab.Size.Y.Offset / 2
	sp:set("idle", n, L.cell / 2 - cx, L.cell / 2 - cy, dir, k)
end

local function close()
	if win then
		if win.conn then
			win.conn:Disconnect()
		end
		win.holder:Destroy()
		if win.block then
			win.block:Destroy()
		end
		win = nil
	end
end

-- 창 밑에 화면 전체를 덮는 어두운 판: 문제가 떠 있는 동안 다른 부품을 누를 수 없다(2026-10-24)
local function blocker(): TextButton
	local b = Instance.new("TextButton")
	b.Name = "MacroBlock"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.new(0, 0, 0)
	b.BackgroundTransparency = 0.45
	b.BorderSizePixel = 0
	b.Size = UDim2.fromScale(1, 1)
	b.ZIndex = 0
	b.Parent = root()
	return b
end

local function paintPicks()
	if not win then
		return
	end
	for i, c in win.cells do
		c.slot:setOn(win.picks[i] == true)
	end
	local n = 0
	for _ in win.picks do
		n += 1
	end
	win.picked:set(Format.fill(W.picked, { n = n }))
	win.okBtn:setEnabled(n == D.pick and not win.busy)
end

local function answer()
	if not win or win.busy then
		return
	end
	local picks = {}
	for i in win.picks do
		table.insert(picks, i)
	end
	if #picks ~= D.pick then
		return
	end
	win.busy = true
	paintPicks()
	local token = win.view.token
	task.spawn(function()
		local ok, res = pcall(Net.Invoke, "Macro", "answer", token, picks)
		if not win or win.view.token ~= token then
			return
		end
		win.busy = false
		if not ok or type(res) ~= "table" then
			paintPicks()
			return
		end
		MacroWindow.update(res)
	end)
end

local function open(view)
	if win and win.view.token == view.token then
		-- 같은 문제(남은 기회 · 시간만 바뀌었다)
		win.view = view
		win.deadline = os.clock() + view.left
		win.tries:set(Format.fill(W.tries, { n = view.tries }))
		return
	end
	close()
	if MacroWindow.onOpen then
		MacroWindow.onOpen()
	end
	local block = blocker()
	local w = L.w
	local gridW = L.cell * 3 + L.gap * 2
	local h = L.pad + L.title + L.ask + L.cell + L.mid + gridW + L.mid + L.info + M.button + L.pad
	local holder = Stage.place(root(), "MacroCheck", "tc", Stage.REF_W / 2 - w / 2, L.top, w, h)
	Ui.panel(holder, 0, 0, w, h)
	Ui.hit(holder).ZIndex = 0 -- 판을 누른 것이 밑으로 새지 않게(칸 · 단추보다 아래 — 대화창에서 판이 단추를 가렸던 일, 2026-10-23)
	local inner = w - L.pad * 2
	local x0 = math.floor((w - gridW) / 2)
	local y = L.pad
	Ui.text(holder, W.title, L.pad, y, inner, { font = "body", color = C.accent })
	local left = Ui.text(holder, "", L.pad, y + 2, inner, { align = "right", color = C.dim })
	y += L.title
	Ui.text(holder, W.ask, L.pad, y, inner, { align = "center", color = C.text })
	y += L.ask
	-- 위의 셋(찾을 몬스터)
	local topW = L.cell * #view.top + L.gap * (#view.top - 1)
	for i, kind in view.top do
		local s = Ui.slot(holder, math.floor((w - topW) / 2) + (i - 1) * (L.cell + L.gap), y, L.cell)
		s:setOn(true)
		monster(s.frame, kind, 1, false)
	end
	y += L.cell + L.mid
	Ui.line(holder, L.pad, y - math.floor(L.mid / 2), inner)
	-- 아래 아홉(고른다)
	local cells = {}
	for i, c in view.cells do
		local col, row = (i - 1) % 3, (i - 1) // 3
		local s = Ui.slot(holder, x0 + col * (L.cell + L.gap), y + row * (L.cell + L.gap), L.cell)
		monster(s.frame, c.kind, math.random(1, 8), c.flip == true)
		local hit = Ui.hit(s.frame)
		hit.ZIndex = 9
		hit.Activated:Connect(function()
			if not win or win.busy then
				return
			end
			if win.picks[i] then
				win.picks[i] = nil
			else
				local n = 0
				for _ in win.picks do
					n += 1
				end
				if n < D.pick then
					win.picks[i] = true
				end
			end
			win.note:set("")
			paintPicks()
		end)
		cells[i] = { slot = s }
	end
	y += gridW + L.mid
	local picked = Ui.text(holder, "", L.pad, y, 60, { color = C.text })
	local note = Ui.text(holder, "", L.pad + 50, y, inner - 140, { align = "center", color = C.red })
	local tries = Ui.text(holder, "", L.pad, y, inner, { align = "right", color = C.dim })
	y += L.info
	local okBtn = Ui.button(holder, W.ok, math.floor(w / 2) - L.btnW - 4, y, L.btnW, answer, { main = true })
	Ui.button(holder, W.reset, math.floor(w / 2) + 4, y, L.btnW, function()
		if win and not win.busy then
			table.clear(win.picks)
			win.note:set("")
			paintPicks()
		end
	end)
	win = { holder = holder, block = block, view = view, picks = {}, deadline = os.clock() + view.left, cells = cells, okBtn = okBtn, left = left, tries = tries, picked = picked, note = note, busy = false, conn = nil :: RBXScriptConnection? }
	tries:set(Format.fill(W.tries, { n = view.tries }))
	paintPicks()
	local shown = -1
	win.conn = RunService.Heartbeat:Connect(function()
		if not win then
			return
		end
		local n = math.max(0, math.ceil(win.deadline - os.clock()))
		if n ~= shown then
			shown = n
			left:set(Format.fill(W.left, { n = n }))
			left:color(if n <= 10 then C.red else C.dim)
		end
	end)
end

-- 보상 멈춤 띠(누르면 다시 확인 — 기다릴 시간이 남았으면 그 분)
local function paintStop()
	if not stop.stopped then
		if stop.holder then
			stop.holder.Visible = false
		end
		return
	end
	if not stop.holder then
		local S = L.stop
		local holder = Stage.place(root(), "MacroStop", "tc", Stage.REF_W / 2 - S.w / 2, S.y, S.w, S.h)
		Ui.panel(holder, 0, 0, S.w, S.h)
		stop.text = Ui.text(holder, W.stop, 0, 4, S.w, { align = "center", color = C.red })
		stop.hint = Ui.text(holder, "", 0, 4 + M.smallLine, S.w, { align = "center", color = C.dim })
		local hit = Ui.hit(holder)
		hit.ZIndex = 9
		hit.Activated:Connect(function()
			if win or os.clock() < stop.retryAt then
				return
			end
			task.spawn(function()
				local ok, res = pcall(Net.Invoke, "Macro", "again")
				if ok and type(res) == "table" then
					MacroWindow.update(res)
				end
			end)
		end)
		stop.holder = holder
		stop.conn = RunService.Heartbeat:Connect(function()
			if stop.holder and stop.holder.Visible and stop.hint then
				local wait = stop.retryAt - os.clock()
				stop.hint:set(if wait > 0 then Format.fill(W.stopWait, { m = math.ceil(wait / 60) }) else W.stopHint)
			end
		end)
	end
	(stop.holder :: Frame).Visible = true
end

-- 서버가 알린 것 · 대답의 결과: { check?, stopped, retryIn, result? }
function MacroWindow.update(v)
	if type(v) ~= "table" then
		return
	end
	if v.check then
		open(v.check)
	else
		close()
	end
	if v.result == "wrong" and win then
		table.clear(win.picks)
		win.note:set(W.wrong)
		paintPicks()
	elseif v.result == "pass" and MacroWindow.say then
		MacroWindow.say(W.pass, true)
	elseif v.result == "fail" and MacroWindow.say then
		MacroWindow.say(W.fail, false)
	end
	if v.stopped ~= nil then
		stop.stopped = v.stopped == true
		stop.retryAt = os.clock() + (tonumber(v.retryIn) or 0)
		paintStop()
	end
end

function MacroWindow.isOpen(): boolean
	return win ~= nil
end

return MacroWindow
