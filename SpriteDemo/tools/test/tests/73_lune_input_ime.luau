-- 「달의 계승자」 — 한글 입력 상태에서 키가 먹지 않거나 눌린 채로 남는 Roblox의 버그에 대비(client/lune/input.luau의 Input.poll · 2026-10-21).
--  사용자: "로블록스에서 한글쓴다음에 키가 안먹히는 버그가있거든? 로블록스에서 유명한 버그야 이거 확인해봐"
--  보는 것: ① 뗀 소식이 오지 않아도 키를 떼면 뗀다(스킬이 계속 나가지 않는다) ② 누른 소식이 오지 않아도 키가 눌리면 누른다 ③ 소식과 맞추기가 두 번 누르지 않는다
--   ④ 글을 치는 동안 · 그때부터 누르고 있던 키는 누르지 않는다 ⑤ 폰 단추로 누른 것은 떼지 않는다 ⑥ 무슨 키인지 모르는 글쇠가 3초 안에 두 번 → 「한글 입력 상태」 알림(1분에 한 번 · 묶인 키가 눌린 장면은 세지 않는다)
--   ⑦ 알림의 글이 큰 알림 칸(가로 480점)에 들어간다
local function signal()
	local sig = { fns = {} }
	function sig:Connect(fn)
		table.insert(self.fns, fn)
		return { Disconnect = function() end }
	end
	function sig:Fire(...)
		for _, f in self.fns do
			f(...)
		end
	end
	return sig
end
local began, ended, unfocus = signal(), signal(), signal()
local down = {} -- 지금 눌린 키(IsKeyDown이 보는 것)
local steps = {}
SERVICE("UserInputService", {
	InputBegan = began,
	InputEnded = ended,
	WindowFocusReleased = unfocus,
	IsKeyDown = function(_, key) return down[key] == true end,
	GetFocusedTextBox = function() return nil end,
})
SERVICE("RunService", { BindToRenderStep = function(_, name, _priority, fn) steps[name] = fn end })
SERVICE("GuiService", { MenuIsOpen = false })
local Input = req("Client/lune/input")
local typing = false
Input.typing = function() return typing end
Input.bind("slot:2", Enum.KeyCode.Q)
Input.init()
expect(steps.LuneInputPoll ~= nil, "장면마다 키의 지금 상태로 맞춘다(BindToRenderStep)")
local Q = Input.BIND["slot:2"]
local function key(k)
	return { UserInputType = Enum.UserInputType.Keyboard, KeyCode = k }
end
local now = 100
local function frame(dt: number?)
	now += dt or 1 / 60
	Input.poll(now)
end

-- ① 뗀 소식이 오지 않았다(한글 상태에서 키가 눌린 채로 남던 것)
down[Q] = true
began:Fire(key(Q))
frame()
expect(Input.held("slot:2") and Input.take("slot:2"), "누르면 누른다")
down[Q] = nil -- 키를 뗐다 — InputEnded는 오지 않는다
frame()
expect(not Input.held("slot:2"), "뗀 소식이 없어도 키를 떼면 뗀다(스킬이 계속 나가지 않는다)")

-- ② 누른 소식이 무슨 키인지 모르는 글쇠로 왔다(한글 상태에서 키가 먹지 않던 것)
local unknown = { Value = 0 }
down[Q] = true
frame()
expect(not Input.held("slot:2"), "누른 소식 없이 IsKeyDown만 바뀐 것은 누르지 않는다(2026-10-31 — 한글 채팅 뒤 저절로 움직이던 것)")
down[Q] = nil
frame()
down[Q] = true
began:Fire(key(unknown))
frame()
expect(Input.held("slot:2") and Input.take("slot:2"), "모르는 글쇠가 눌린 장면에 키가 눌렸으면 누른다")
frame()
expect(not Input.take("slot:2"), "누르고 있는 동안 다시 누른 것으로 치지 않는다")
down[Q] = nil
frame()
expect(not Input.held("slot:2"), "떼면 뗀다")

-- ③ 소식과 맞추기가 두 번 누르지 않는다
down[Q] = true
began:Fire(key(Q))
frame()
expect(Input.take("slot:2"), "한 번")
frame()
expect(not Input.take("slot:2"), "두 번은 아니다")
down[Q] = nil
ended:Fire(key(Q))
frame()
expect(not Input.held("slot:2"), "뗀 소식으로 뗀다")

-- ④ 글을 치는 동안
typing = true
down[Q] = true
began:Fire(key(Q))
frame()
expect(not Input.held("slot:2"), "채팅에 글을 치는 동안에는 누르지 않는다")
typing = false
frame()
expect(not Input.held("slot:2"), "글을 다 친 뒤에도 그때부터 누르고 있던 키는 누르지 않는다(친 글자가 스킬로 나가지 않게)")
down[Q] = nil
frame()
down[Q] = true
began:Fire(key(Q))
frame()
expect(Input.take("slot:2"), "떼고 다시 누르면 먹는다")
down[Q] = nil
ended:Fire(key(Q))
frame()

-- ⑤ 폰 단추로 누른 것은 떼지 않는다(키보드는 눌려 있지 않다)
Input.press("left")
frame()
frame()
expect(Input.held("left"), "폰 단추로 누른 걷기는 그대로")
Input.release("left")

-- ⑥ 한글 입력 상태 알림
local shown = 0
Input.onIme = function()
	shown += 1
end
began:Fire(key(unknown))
frame()
eq(shown, 0, "한 번은 알리지 않는다(한/영 키 하나일 수 있다)")
began:Fire(key(unknown))
frame(0.2)
eq(shown, 1, "3초 안에 두 번이면 알린다")
began:Fire(key(unknown))
frame(0.2)
began:Fire(key(unknown))
frame(0.2)
eq(shown, 1, "1분 안에는 다시 알리지 않는다")
frame(61)
began:Fire(key(unknown))
frame()
frame(4) -- 3초가 지났다
began:Fire(key(unknown))
frame()
eq(shown, 1, "3초가 지난 두 번째는 처음부터 센다")
began:Fire(key(unknown))
frame()
eq(shown, 2, "1분이 지나면 다시 알린다")
frame(61)
down[Q] = true
began:Fire(key(unknown))
frame()
began:Fire(key(unknown))
frame()
eq(shown, 2, "묶인 키가 눌린 장면의 모르는 글쇠는 세지 않는다(키가 먹고 있다)")
down[Q] = nil
frame()

-- ⑦ 알림의 글이 큰 알림 칸에 들어간다(guide.luau — 가로 480점 · 제목 body · 아랫줄 small 두 줄)
do
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	local pixelText = req("Client/ui/pixelText")
	pixelText.Register("small_o", KIT.font.small_o, {})
	pixelText.Register("body_o", KIT.font.body_o, {})
	local W = Input.IME_WORDS
	expect(pixelText.Measure(W.head, "body_o") <= 480, "제목 「" .. W.head .. "」이 한 줄에")
	local fit = pixelText.Fit(W.line, 480, 2, "small_o")
	expect(string.sub(fit, -3) ~= "…", "아랫줄이 두 줄 안에 — " .. W.line)
end

-- ⑧ 뗀 소식이 무슨 키인지 모르는 글쇠로 왔다 — IsKeyDown은 눌린 채로 남는다(2026-10-31 사용자: "한글 채팅 치고나서 방향이 무슨 입력이 있는것처럼 막 움직이는 버그가 있어
--  영문으로 채팅 다시 치면 잘 동작하고")
local LEFT = Input.BIND.left
Input.flush()
down[Q] = true
began:Fire(key(Q))
frame()
expect(Input.held("slot:2"), "글자 키를 눌렀다")
ended:Fire(key(unknown))
frame()
expect(not Input.held("slot:2"), "모르는 글쇠의 뗀 소식에 글자 키로 누른 것을 뗀다(스킬이 저절로 계속 나가지 않는다)")
frame()
frame()
expect(not Input.held("slot:2"), "IsKeyDown이 눌린 채여도 다시 누르지 않는다")
began:Fire(key(Q))
frame()
expect(Input.held("slot:2"), "영문으로 다시 누르면 먹는다")
down[Q] = nil
ended:Fire(key(Q))
frame()
expect(not Input.held("slot:2"), "떼면 뗀다")

-- ⑨ 방향키는 한글 입력기가 받아 가지 않는다 — 모르는 글쇠에 떼지 않는다
down[LEFT] = true
began:Fire(key(LEFT))
frame()
ended:Fire(key(unknown))
frame()
expect(Input.held("left"), "방향키로 누른 걷기는 모르는 글쇠의 뗀 소식에 떼지 않는다")

-- ⑩ 채팅을 열거나 닫으면 키보드로 누르고 있던 것을 모두 뗀다
typing = true
frame()
expect(not Input.held("left"), "채팅을 열면 누르고 있던 걷기를 뗀다")
typing = false
frame()
expect(not Input.held("left"), "채팅을 닫은 뒤에도 그때부터 누르고 있던 방향키는 누르지 않는다")
down[LEFT] = nil
ended:Fire(key(LEFT))
frame()
down[Q] = true
began:Fire(key(Q))
frame()
frame()
frame()
expect(Input.held("slot:2"), "뗀 소식이 아예 사라지면 아직 눌린 것으로 본다(IsKeyDown도 눌린 채)")
typing = true
frame()
typing = false
frame()
expect(not Input.held("slot:2"), "채팅을 한 번 열고 닫으면 눌린 채로 남은 키가 풀린다")

-- ⑪ 한글 단어의 첫 키는 영문 키로 들어오고 그 뗀 소식은 사라진다(DevForum 2025-09-30) → 이어서 친 글자(모르는 글쇠)에 뗀다
down[Q] = nil
frame()
down[Q] = true
began:Fire(key(Q))
frame()
expect(Input.held("slot:2"), "첫 키가 영문 키로 들어왔다")
began:Fire(key(unknown))
frame()
expect(not Input.held("slot:2"), "한글 상태에서 글자를 또 누르면 앞서 글자 키로 누른 것을 뗀다")
frame()
frame()
expect(not Input.held("slot:2"), "IsKeyDown이 눌린 채여도 다시 누르지 않는다")

-- ⑫ 누른 소식 없이 IsKeyDown만 깜빡인다 — 한 번도 누르지 않는다
down[Q] = nil
frame()
frame()
frame()
local phantom = false
for i = 1, 20 do
	down[Q] = if i % 2 == 1 then true else nil
	down[LEFT] = if i % 3 == 0 then true else nil
	frame()
	phantom = phantom or Input.held("slot:2") or Input.held("left")
end
expect(not phantom, "IsKeyDown이 혼자 깜빡여도 스킬 · 걷기를 누르지 않는다")
down[Q], down[LEFT] = nil, nil
frame()
