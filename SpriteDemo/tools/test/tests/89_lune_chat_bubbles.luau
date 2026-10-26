-- 「달의 계승자」 — 채팅 말풍선(client/lune/chatBubbles.luau)을 화면 없이 돌려 본다(2026-10-26).
--  사용자: "로블록스 채팅 연동해서 내가 채팅치면 내 캐릭터위에 말풍선모양으로 나와서 내가 무슨말하는지 다른사람한테 보이게 해줘"
--  보는 것: Roblox 채팅에서 받은 글이 보낸 사람의 머리 위에 · 따라감 · 이 맵에 없는 사람은 숨김 · 새 말로 바꿈 · 꾸밈 글자 되돌림 · 빈 말 · 긴 말 · 맵을 바꾸면 거둠
NumberSequence = { new = function(a, b) return { a, b } end }
local received = nil
SERVICE("TextChatService", { MessageReceived = { Connect = function(_, fn) received = fn end } })

local function frame(name)
	local f = { Name = name, Visible = true, ZIndex = 1, Size = UDim2.fromOffset(1, 1), Position = UDim2.fromOffset(0, 0) }
	function f:Destroy() end
	return f
end
local function textItem()
	local it = { text = "" }
	function it.set(_, v)
		it.text = v
	end
	return it
end
MOCK("Client/lune/stage", { uiW = 960, uiH = 540, group = function(_, name) return frame(name) end })
MOCK("Client/lune/overlay", { root = frame("Overlay"), x = function(v) return v end, y = function(v) return v end })
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end }),
	M = { body = 12, small = 9, bodyLine = 16 },
	group = function(_, x, y, w, h, name) return frame(name or "Group") end,
	part = function(_, name) return frame(name) end,
	text = function() return textItem() end,
})
MOCK("Client/modules/ui/pixelText", { Fit = function(t) return t end, Measure = function(t) return #t * 4 end, Clean = function(t) return t end })

local Bubbles = req("Client/lune/chatBubbles")
Bubbles.init()
expect(received ~= nil, "Roblox 채팅의 받은 글(MessageReceived)에 걸었다")

local where = { [1] = { 100, 200 }, [2] = { 300, 200 } } -- 이 맵에 있는 사람(1 = 나 · 2 = 다른 사람)
Bubbles.where = function(id)
	local p = where[id]
	if p then
		return p[1], p[2]
	end
	return nil, nil
end

received({ TextSource = { UserId = 2 }, Text = "안녕하세요 &lt;3" })
eq(Bubbles.shown(2), "안녕하세요 <3", "보낸 사람의 머리 위에 · Roblox가 바꿔 보낸 꾸밈 글자는 되돌린다")
eq(Bubbles.shown(1), nil, "말하지 않은 사람에게는 없다")
received({ TextSource = { UserId = 1 }, Text = "나도" })
eq(Bubbles.shown(1), "나도", "내 말도 내 머리 위에")
received({ TextSource = nil, Text = "시스템 알림" })
eq(Bubbles.shown(1), "나도", "보낸 사람이 없는 알림 글은 말풍선이 아니다")

-- 따라간다: 그 사람이 움직이면 말풍선도 머리 위로
where[2] = { 500, 180 }
Bubbles.place()
received({ TextSource = { UserId = 2 }, Text = "따라가" })
eq(Bubbles.shown(2), "따라가", "새 말로 바뀐다")

-- 이 맵에 없는 사람(다른 맵으로 갔다)은 숨긴다
where[2] = nil
Bubbles.place()
eq(Bubbles.shown(2), nil, "이 맵에 없으면 숨긴다")
where[2] = { 300, 200 }
Bubbles.place()
eq(Bubbles.shown(2), "따라가", "다시 보이면 남은 시간 동안 뜬다")
-- 화면 밖
where[2] = { 2000, 200 }
Bubbles.place()
eq(Bubbles.shown(2), nil, "화면 밖이면 숨긴다")
where[2] = { 300, 200 }
Bubbles.place()

-- 빈 말 · 긴 말
received({ TextSource = { UserId = 2 }, Text = "   " })
eq(Bubbles.shown(2), "따라가", "빈칸뿐인 말은 띄우지 않는다(앞의 말 그대로)")
received({ TextSource = { UserId = 2 }, Text = string.rep("가", 200) })
local long = Bubbles.shown(2)
expect(long ~= nil and utf8.len(long) == 121, "긴 말은 120글자에서 자른다(…를 붙인다) — " .. tostring(long and utf8.len(long)))

-- 맵을 바꾸면 모두 거둔다
Bubbles.hush()
eq(Bubbles.shown(1), nil, "맵을 바꾸면 내 말풍선도 거둔다")
eq(Bubbles.shown(2), nil, "다른 사람 것도")
