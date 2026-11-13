-- 손의 기록(2026-11-13 사용자: "다른 매크로 탐지 상용게임에서 어떤 알고리즘을 사용하고 로그를 어떻게 수집하는지 더 자세하게 알아봐야할거같아" ·
--  "진짜 매크로는 잡지도못하고"). 공방 design/macro.js의 input · 서버 macroGuard.luau(Macro "input") · sim/macro.luau Macro.inputNote.
--  조사: Irdeto(2023 「Visualize evidence to catch bots with confidence」) — 봇은 같은 점을 되풀이해 누르고(가장 많이 누른 25%의 점이 사람 약 25% · 봇 53.8%),
--   누르는 시간의 흔들림이 너무 작다(사분위 범위 봇 3ms · 사람 36ms).
--  여기서 세는 것(every초마다 서버로 — 그 사이 누른 것이 없으면 보내지 않는다):
--   kt = 키보드 키 · 마우스 단추를 누른 수(뗄 때 센다) · kz = 그 가운데 누른 시간이 zeroHold초보다 짧은 수
--        (AutoHotkey의 Send 같은 프로그램은 누름과 뗌을 한꺼번에 보내 같은 프레임에 둘 다 온다 — 사람의 손가락은 한 프레임 안에 누르고 뗄 수 없다)
--   tt = 폰의 터치 수 · ts = 그 가운데 지난 ring번의 터치(바로 앞의 것은 빼고 — Irdeto: 사람도 같은 자리를 잇달아 누를 수 있다) 가운데 하나와 같은 점(픽셀)인 수
--        (오토 클리커 앱은 정해 둔 점을 누른다 — 손가락의 닿는 점은 몇 점씩 흔들린다)
--  글자를 쓰는 칸(채팅 · 닉네임)에 쓰는 키는 세지 않는다(gameProcessed). 어떤 키를 눌렀는지는 보내지 않는다 — 수만 보낸다.
--  [제가 정한 것] 모두(숫자는 공방 macro.js input)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local D = require(ReplicatedStorage.shared.lune.data["macro.generated"]).input

local InputStat = {}

local KEYS = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
}

-- 셈만(시험이 직접 부른다): 새 통
function InputStat.new()
	return { kt = 0, kz = 0, tt = 0, ts = 0, down = {}, ring = {}, prev = nil :: string? }
end
-- 키 · 단추를 눌렀다(id = 그 키 · 단추의 이름 · t = os.clock())
function InputStat.keyDown(c, id: string, t: number)
	c.down[id] = t
end
-- 뗐다: 누른 시간이 zeroHold초보다 짧으면 kz. slow = 화면이 느리다(한 프레임이 길면 사람이 누르고 뗀 것도 같은 프레임에 올 수 있다 — 세지 않는다)
function InputStat.keyUp(c, id: string, t: number, slow: boolean?)
	local t0 = c.down[id]
	c.down[id] = nil
	if not t0 or slow then
		return
	end
	c.kt += 1
	if t - t0 < D.zeroHold then
		c.kz += 1
	end
end
-- 터치가 닿았다(x, y = 화면의 점)
function InputStat.touch(c, x: number, y: number)
	local key = math.floor(x + 0.5) .. "," .. math.floor(y + 0.5)
	c.tt += 1
	if key ~= c.prev and table.find(c.ring, key) then
		c.ts += 1
	end
	if c.prev then
		table.insert(c.ring, c.prev) -- (바로 앞의 것은 다음 터치부터 견준다)
		while #c.ring > D.ring do
			table.remove(c.ring, 1)
		end
	end
	c.prev = key
end
-- 보낼 것을 꺼내고 수를 0으로(누르고 있는 키 · 지난 터치의 점은 둔다) → 없으면 nil
function InputStat.take(c)
	if c.kt + c.tt == 0 then
		return nil
	end
	local out = { kt = math.min(c.kt, D.max), kz = math.min(c.kz, D.max), tt = math.min(c.tt, D.max), ts = math.min(c.ts, D.max) }
	c.kt, c.kz, c.tt, c.ts = 0, 0, 0, 0
	return out
end

-- 게임에서: 입력을 듣고 every초마다 send(통)
function InputStat.start(send: (any) -> ())
	local c = InputStat.new()
	-- 화면이 느린 때(한 프레임이 1/30초 넘은 뒤 0.5초 동안)는 키를 세지 않는다
	local slowUntil = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		if dt > 1 / 30 then
			slowUntil = os.clock() + 0.5
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local ty = input.UserInputType
		if ty == Enum.UserInputType.Touch then
			InputStat.touch(c, input.Position.X, input.Position.Y)
		elseif KEYS[ty] and not (gameProcessed and ty == Enum.UserInputType.Keyboard and UserInputService:GetFocusedTextBox() ~= nil) then
			InputStat.keyDown(c, if ty == Enum.UserInputType.Keyboard then input.KeyCode.Name else ty.Name, os.clock())
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local ty = input.UserInputType
		if KEYS[ty] then
			local now = os.clock()
			InputStat.keyUp(c, if ty == Enum.UserInputType.Keyboard then input.KeyCode.Name else ty.Name, now, now < slowUntil)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(D.every)
			local out = InputStat.take(c)
			if out then
				send(out)
			end
		end
	end)
end

return InputStat
