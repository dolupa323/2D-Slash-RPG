-- 「달의 계승자」 — 우리 게임의 채팅 창(client/lune/chat.luau — 2026-11-06 사용자: "이제 로블록스 채팅이 아닌 우리 게임 자체 채팅구현하자")을 화면 없이 짓고 써 본다.
--  가짜 부품은 진짜(client/lune/ui/ui.luau)와 같은 모양이다 — 없는 칸을 읽으면 바로 오류(2026-10-26 능력치 창: Ui.text에 없는 .frame을 적어 창이 짓다 멈췄다).
--  보는 것: PC 작게(글 세 줄 · 탭 없음 · 「+」) → 받은 글이 맨 아래 줄에(이름 · 글 따로) → 크게(탭 넷 · 여덟 줄 · 「−」) → 탭을 누르면 그 글만 →
--           보낼 곳 단추 · 적고 Enter = 보내기(칸이 비워진다) · 너무 긴 글은 칸에서 자른다 → 휠로 올려 보기 → 폰(「×」 · 닫힌 채 시작 · 열고 닫기) · 언어가 바뀌어도 다시 짓는다
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local CU = UI.chatUi

local function strict(t, what)
	return setmetatable(t, {
		__index = function(_, k)
			error(("%s에 없는 칸 「%s」을 읽었다"):format(what, tostring(k)), 2)
		end,
	})
end
local function sig()
	local s = { fns = {} }
	function s:Connect(fn)
		table.insert(self.fns, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, f in self.fns do
			f(...)
		end
	end
	return s
end
local frames = {}
local function frame(name)
	local f = { Name = name, Visible = true, ZIndex = 1, Size = UDim2.fromOffset(1, 1), Position = UDim2.fromOffset(0, 0), gone = false, InputBegan = sig(), InputChanged = sig(), InputEnded = sig() }
	function f:Destroy()
		f.gone = true
	end
	function f:IsA(class)
		return class == "GuiObject" or class == "Frame"
	end
	table.insert(frames, f)
	return f
end
local texts = {}
local function textItem(value, opts)
	local label = { Frame = frame("Text"), Width = 40, Height = 12 }
	local it = { label = label, value = value, opts = opts or {}, tint = (opts or {}).color, x = 0, y = 0, shown = true, parent = false, width = 0 }
	function it.set(_, v)
		it.value = v
	end
	function it.color(_, c)
		it.tint = c
	end
	function it.move(_, x, y)
		it.x, it.y = x, y
	end
	function it.show(_, on)
		it.shown = on
	end
	function it.size()
		return #it.value * 3, 12
	end
	function it.destroy() end
	table.insert(texts, it)
	return strict(it, "글 칸(Ui.text)")
end
local tabs, buttons, fields, closes, hits = {}, {}, {}, 0, {}
local COLOR = setmetatable({}, { __index = function(_, k) return k end })
MOCK("Client/lune/ui/ui", strict({
	COLOR = COLOR,
	group = function(_, x, y, w, h, name)
		local f = frame(name or "Group")
		f.x, f.y, f.w, f.h = x, y, w, h
		return f
	end,
	box = function(_, x, y, w, h)
		local f = frame("Box")
		f.x, f.y, f.w, f.h = x, y, w, h
		return f
	end,
	text = function(parent, value, x, y, width, opts)
		local it = textItem(value, opts)
		it.x, it.y, it.width, it.parent = x, y, width, parent
		return it
	end,
	tab = function(_, text, x, y, onClick)
		local it = { frame = frame("Tab"), width = #text * 3, text = text, on = false, click = onClick }
		function it.setOn(_, on)
			it.on = on
		end
		tabs[text] = it
		return strict(it, "탭(Ui.tab)")
	end,
	button = function(_, text, x, y, w, onClick, opts)
		local b = { frame = frame("Button"), click = onClick, text = text, main = (opts or {}).main == true, enabled = true, h = (opts or {}).h }
		function b.setText(_, v)
			b.text = v
		end
		function b.setEnabled(_, on)
			b.enabled = on
		end
		function b.setMain(_, on)
			b.main = on
		end
		buttons[text] = b
		return strict(b, "단추(Ui.button)")
	end,
	field = function(_, x, y, w, h, placeholder)
		local changed = sig()
		local tb = { Text = "", PlaceholderText = placeholder, FocusLost = sig(), focused = false, w = w, captured = 0 }
		function tb:GetPropertyChangedSignal(prop)
			assert(prop == "Text", "적는 칸에서 듣는 것은 Text뿐")
			return changed
		end
		function tb:IsFocused()
			return tb.focused
		end
		function tb:CaptureFocus()
			tb.focused = true
			tb.captured += 1
		end
		function tb:ReleaseFocus()
			tb.focused = false
		end
		tb.changed = changed
		table.insert(fields, tb)
		return tb
	end,
	closeButton = function(_, x, y, onClick)
		closes += 1
		local f = frame("Close")
		f.click = onClick
		return f
	end,
	hit = function()
		local h = { Activated = sig() }
		table.insert(hits, h)
		return h
	end,
}, "Ui"))
local resized = {}
MOCK("Client/lune/stage", strict({
	uiScale = 2,
	uiW = 960,
	uiH = 540,
	REF_W = 960, -- (채팅 창을 옮긴 자리를 화면 안으로 묶는 셈 — 2026-11-09)
	REF_H = 540,
	atPosition = function(_, x, y)
		return UDim2.fromOffset(x, y)
	end,
	move = function(frame, _, x, y) -- (진짜 Stage.move — 옮긴 만큼 · 화면 안 · 2026-11-12)
		frame.Position = UDim2.fromOffset(x, y)
	end,
	insetTop = 0,
	place = function(_, name, at, x, y, w, h)
		local f = frame(name)
		f.at, f.x, f.y, f.w, f.h = at, x, y, w, h
		return f
	end,
	onResize = function(fn)
		table.insert(resized, fn)
	end,
}, "Stage"))
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small_o", KIT.font.small_o, {})
MOCK("Client/modules/ui/pixelText", pixelText)
local sent = {}
local onMsg = nil
local function channel(name)
	return {
		Name = name,
		SendAsync = function(self, text)
			table.insert(sent, { self.Name, text })
			return { Status = Enum.TextChatMessageStatus.Success }
		end,
	}
end
local channels = { RBXGeneral = channel("RBXGeneral"), [CU.party.channel] = channel(CU.party.channel) }
local channelFolder = {
	FindFirstChild = function(_, k)
		return channels[k]
	end,
}
local tcsDescendants = {} -- 끝에서 Roblox의 입력줄 설정을 넣어 본다(맡기지 않는다)
local sendingMessage = sig()
SERVICE("TextChatService", {
	GetDescendants = function()
		return tcsDescendants
	end,
	DescendantAdded = sig(),
	SendingMessage = sendingMessage,
	MessageReceived = {
		Connect = function(_, fn)
			onMsg = fn
		end,
	},
	FindFirstChild = function(_, name)
		return if name == "TextChannels" then channelFolder else nil
	end,
	WaitForChild = function(_, name)
		return if name == "TextChannels" then channelFolder else nil
	end,
})
SERVICE("Players", {
	LocalPlayer = { UserId = 7 },
	GetPlayerByUserId = function(_, id)
		return {
			GetAttribute = function()
				return if id == 7 then "달토끼" else "별빛"
			end,
		}
	end,
})
local UIS = { InputBegan = sig(), InputChanged = sig(), InputEnded = sig(), focused = nil }
function UIS:GetFocusedTextBox()
	return UIS.focused
end
SERVICE("UserInputService", UIS)

local Chat = req("Client/lune/chat")
local root = frame("HudRoot")
local ok, err = pcall(Chat.init, root)
expect(ok, "채팅 창을 끝까지 짓는다 — " .. tostring(err))
if ok then
	local function holder()
		for i = #frames, 1, -1 do
			local f = frames[i]
			if f.Name == "Chat" and not f.gone then
				return f
			end
		end
		return nil
	end
	local function liveRows()
		local out = {}
		local now = holder()
		for _, t in texts do
			if t.opts.raw and t.parent == now then
				table.insert(out, t)
			end
		end
		return out
	end
	local small = UI.hud.chat
	local h = holder()
	expect(h ~= nil and h.at == small.at and h.x == small.x, "PC: HUD 「채팅」 칸의 자리에")
	eq(h and h.y, small.y + small.h - CU.layout.small.h, "작게: 판의 아래 끝 = 칸의 아래 끝(위로 자란다)")
	eq(#liveRows(), CU.layout.small.lines * 2, "작게: 글 세 줄(이름 · 글 칸 둘씩)")
	eq(next(tabs), nil, "작게: 탭이 없다")
	expect(buttons["일반"] and buttons["일반"].main and buttons["파티"] and not buttons["파티"].main, "보낼 곳 둘 — 처음은 「일반」")
	eq(buttons["일반"].h, CU.inputH, "보낼 곳 단추는 입력줄 높이")
	local field = fields[#fields]
	eq(field.PlaceholderText, CU.hint, "적는 칸의 안내 「Enter로 채팅」")
	-- 받은 글: 맨 아래 줄에 이름과 글이 따로(이름 = 캐릭터의 이름)
	onMsg({ TextSource = { UserId = 8 }, TextChannel = { Name = "RBXGeneral" }, Text = "안녕하세요", Status = Enum.TextChatMessageStatus.Success })
	local rows = liveRows()
	local lastHead, lastBody = rows[#rows - 1], rows[#rows]
	expect(lastHead.value == "별빛: " and lastBody.value == "안녕하세요", "맨 아래 줄 = 「별빛: 」 + 「안녕하세요」")
	expect(lastHead.tint ~= nil and lastHead.tint.hex == string.lower(CU.nameColor) and lastBody.tint.hex == string.lower(CU.textColor), "이름 · 글의 색")
	expect(lastBody.x > lastHead.x, "글은 이름 뒤에서 시작한다")
	-- 크게: 탭 넷 · 여덟 줄 · 판이 위로 자란다
	local toggles = #hits
	expect(toggles >= 2, "「+ / −」 · 「_」(최소화 — 2026-11-07) 단추가 있다")
	hits[#hits - 1].Activated:Fire() -- (입력줄 오른쪽 끝: 「_」가 맨 끝 · 그 왼쪽이 「+ / −」)
	h = holder()
	eq(h and h.y, small.y + small.h - CU.layout.big.h, "크게: 아래 끝은 그대로 · 위로 자란다")
	eq(#liveRows(), CU.layout.big.lines * 2, "크게: 글 여덟 줄")
	for _, t in CU.tabs do
		expect(tabs[t.name] ~= nil, "탭 " .. t.name)
	end
	expect(tabs["전체"].on and not tabs["파티"].on, "처음 탭 = 전체")
	-- 파티 글을 받고 파티 탭을 누르면 그 글만
	onMsg({ TextSource = { UserId = 8 }, TextChannel = { Name = CU.party.channel }, Text = "보스 가요", Status = Enum.TextChatMessageStatus.Success })
	tabs["파티"].click()
	eq(Chat.tab, "party", "파티 탭을 골랐다")
	local shown = {}
	for _, t in liveRows() do
		if t.value ~= "" then
			table.insert(shown, t.value)
		end
	end
	expect(table.concat(shown, "|") == "[파티] 별빛: |보스 가요", "파티 탭에는 파티 글만 — " .. table.concat(shown, "|"))
	tabs["전체"].click()
	-- 보낼 곳 · 적고 Enter = 보내기
	buttons["파티"].click()
	expect(buttons["파티"].main and not buttons["일반"].main, "「파티」를 고르면 민트")
	field = fields[#fields]
	eq(field.MultiLine, false, "Enter = 칸을 떠나며 보낸다(줄바꿈을 받지 않는다)")
	-- Enter = 보낸다(처음처럼 — 2026-11-07: 줄바꿈 · 기다리기 · 커서 옮기기 · Roblox에 맡기기 · 보이는 글 모두 한글의 마지막 글자를 되살리지 못했다)
	local count = #sent
	field.focused = true
	field.Text = "같이 가요"
	field.FocusLost:Fire(true)
	expect(sent[#sent] and sent[#sent][1] == CU.party.channel and sent[#sent][2] == "같이 가요", "Enter = 파티로 보낸다")
	eq(#sent, count + 1, "한 번만 보낸다")
	eq(field.Text, "", "보내면 칸이 비워진다")
	-- (11-07: 「보이는 글」(ContentText)을 지켜보는 길은 걷었다 — 조합 중인 글자는 ContentText에도 없었다. Roblox의 버그: 한글의 마지막 글자는 스페이스로 확정해야 간다)
	buttons["일반"].click()
	field.Text = "안 보낸다"
	local before = #sent
	field.FocusLost:Fire(false)
	eq(#sent, before, "Enter 없이 칸을 떠나면 보내지 않는다(적던 글은 남는다)")
	eq(field.Text, "안 보낸다", "적던 글이 남는다")
	field.Text = string.rep("가", CU.maxLen + 10)
	field.changed:Fire()
	eq(utf8.len(field.Text), CU.maxLen, "칸에서 maxLen자까지만")
	field.Text = ""
	-- Enter = 적는 칸으로(PC)
	clock.now += 1
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Return })
	eq(field.captured, 1, "Enter를 누르면 적는 칸으로")
	field.focused = false
	-- 휠로 올려 본다(글이 칸보다 많을 때)
	for i = 1, 20 do
		onMsg({ TextSource = { UserId = 8 }, TextChannel = { Name = "RBXGeneral" }, Text = "줄 " .. i, Status = Enum.TextChatMessageStatus.Success })
	end
	local area
	for i = #frames, 1, -1 do
		if frames[i].Name == "LogArea" and not frames[i].gone then
			area = frames[i]
			break
		end
	end
	expect(area ~= nil, "글 칸 위에 휠 · 끌기를 받는 자리")
	if area then
		area.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseWheel, Position = { Z = 1 } })
		expect(Chat.scroll > 0, "휠을 올리면 지난 글 쪽으로")
	end
	onMsg({ TextSource = { UserId = 8 }, TextChannel = { Name = "RBXGeneral" }, Text = "새 글", Status = Enum.TextChatMessageStatus.Success })
	expect(Chat.scroll > 0, "올려 보는 동안 새 글이 와도 그 자리 그대로")
	-- 최소화(2026-11-07 사용자 "채팅시스템 최소화도 가능해야한다 메이플 채팅이랑 똑같이"): 「_」 = 가장 최근 글 한 줄 + 입력줄(아래 끝 그대로) · 「□」 = 접기 전 크기로
	local bigH = holder()
	hits[#hits].Activated:Fire()
	h = holder()
	eq(Chat.min, true, "「_」를 누르면 최소화")
	eq(h and h.y, bigH.y + bigH.h - CU.layout.min.h, "최소화: 아래 끝은 그대로")
	eq(#liveRows(), CU.layout.min.lines * 2, "최소화: 글 한 줄")
	eq(Chat.scroll, 0, "최소화하면 맨 아래 글")
	hits[#hits].Activated:Fire()
	h = holder()
	eq(Chat.min, false, "「□」를 누르면 편다")
	eq(h and h.h, bigH.h, "펴면 접기 전 크기(크게) 그대로")
	-- 폰: 「×」 · 닫힌 채 시작 · 열고 닫기 · 단추를 숨기고 보인다
	local opened = {}
	Chat.onOpen = function(on)
		table.insert(opened, on)
	end
	local closesBefore = closes
	Chat.setTouch(true)
	h = holder()
	expect(h ~= nil and h.at == UI.hudTouch.chat.at and h.y == UI.hudTouch.chat.y, "폰: HUDTOUCH 「채팅」의 자리(위 끝 그대로)")
	eq(h and h.Visible, false, "폰: 닫힌 채 시작")
	eq(closes, closesBefore + 1, "폰: 판 안에 「×」")
	eq(fields[#fields].PlaceholderText, CU.hintTouch, "폰의 안내 「눌러서 채팅」")
	Chat.toggle()
	eq(h.Visible, true, "「채팅」 단추 = 연다")
	eq(opened[#opened], true, "열리면 boot가 단추를 숨긴다")
	Chat.setOpen(false)
	eq(h.Visible, false, "「×」 = 닫는다")
	-- 언어가 바뀌면 다시 짓는다(탭의 폭)
	local n = #frames
	local ok2, err2 = pcall(Chat.build)
	expect(ok2 and #frames > n, "다시 짓는다 — " .. tostring(err2))
	-- 화면 크기가 바뀌어도 그대로면 다시 짓지 않는다 · 바뀌면 다시
	for _, fn in resized do
		fn()
	end
	n = #frames
	for _, fn in resized do
		fn()
	end
	eq(#frames, n, "격자 · 띠가 그대로면 다시 짓지 않는다")
	-- Roblox 채팅에 칸을 맡기지 않는다(2026-11-07: 맡긴 칸은 스크립트로 잡을 수 없어 Enter로 열리지 않았고, 마지막 글자도 그대로 빠졌다)
	local barCfg = { ClassName = "ChatInputBarConfiguration", Enabled = true }
	table.insert(tcsDescendants, barCfg)
	local ok3, err3 = pcall(Chat.build)
	expect(ok3, "다시 짓는다 — " .. tostring(err3))
	eq(barCfg.TextBox, nil, "우리 칸을 Roblox 채팅에 넘기지 않는다")
	-- 옮긴 자리(2026-11-09 사용자 "채팅창 위치 웹처럼 자유롭게 배치할수있는기능"): 판 위 가운데의 손잡이 · 옮긴 만큼 · 화면 밖으로는 나가지 않는다 · 처음 자리로
	Chat.setTouch(false) -- (PC만 옮긴다 — 폰은 처음 자리 그대로)
	Chat.setPos(nil)
	local p0 = holder()
	local gripFound = false
	for _, f in frames do
		if f.Name == "Grip" and not f.gone then
			gripFound = true
		end
	end
	expect(gripFound, "PC: 판 위의 손잡이(Grip)")
	Chat.setPos({ x = 100, y = -50 })
	local p1 = holder()
	expect(p1.x == p0.x + 100 and p1.y == p0.y - 50, ("옮긴 만큼 놓인다(%d, %d → %d, %d)"):format(p0.x, p0.y, p1.x, p1.y))
	Chat.setPos({ x = 5000, y = -5000 })
	local p2 = holder()
	expect(p2.x + p2.w <= 960 and p2.y >= 6, ("화면 밖으로 나가지 않는다(손잡이까지 — %d, %d)"):format(p2.x, p2.y))
	Chat.setPos(nil)
	local p3 = holder()
	expect(p3.x == p0.x and p3.y == p0.y, "처음 자리로 돌아간다")
	-- 계정에 남는 꼴(sim/account.luau sound.chat): 정수 x · y만 · 틀리면 처음 자리
	local Account = req("ReplicatedStorage/shared/lune/sim/account")
	local good = Account.cleanSound({ music = 3, sfx = 3, on = true, chat = { x = 120, y = -40 } })
	expect(good and good.chat and good.chat.x == 120 and good.chat.y == -40, "옮긴 자리를 계정에 적는다")
	local bad = Account.cleanSound({ music = 3, sfx = 3, on = true, chat = { x = 1.5, y = "a" } })
	expect(bad and bad.chat == nil, "꼴이 틀린 자리는 버린다(처음 자리)")
end
