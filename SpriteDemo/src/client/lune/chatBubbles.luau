-- 채팅 말풍선(2026-10-26 사용자: "로블록스 채팅 연동해서 내가 채팅치면 내 캐릭터위에 말풍선모양으로 나와서 내가 무슨말하는지 다른사람한테 보이게 해줘").
--  Roblox 채팅(TextChatService)에서 이 화면이 받은 글을 보낸 사람의 캐릭터 머리 위에 띄운다. 받은 글은 Roblox가 이 사람에게 맞게 이미 거른 것이다(MessageReceived — 문서 create.roblox.com/docs/chat/in-experience-text-chat).
--  누구에게 뜨는지는 채팅 그대로다(server/lune/modules/chat.luau): 둘레(General) = 같은 맵의 사람 · 「파티」 = 같은 파티 — 그 글을 받은 사람의 화면에만 뜬다.
--  모양은 주민의 혼잣말 말풍선(ui/talk.luau의 Talk.say — 흰 말풍선 · 꼬리 · BUBBLE의 폭과 줄 수)과 같다. 사람마다 하나 · 새 말이 오면 바꾼다 · SHOW초 뒤에 사라진다 · 그 사람이 화면 밖이면 숨긴다.
--  보이는 시간 · 머리 위 높이는 제가 정한 것. 확인하지 못한 것: 실제 화면(Play를 하지 않았다)
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)
local Stage = require(script.Parent.stage)
local Overlay = require(script.Parent.overlay)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local LINE = Ui.M.bodyLine
local B = Format.BUBBLE
local SHOW = 6 -- 말풍선이 떠 있는 시간(초)
local HEAD = 28 -- 캐릭터의 발에서 말풍선 꼬리 끝까지(도트)
local MAX = 120 -- 받는 글의 길이(글자) — 넘는 것은 자른다(말풍선은 BUBBLE.lines줄까지)

local Bubbles = {}
Bubbles.SHOW = SHOW
-- 그 사람(번호 = UserId)의 발 자리(도트) — 이 맵의 화면에 없으면 nil. boot가 넣어 준다
Bubbles.where = nil :: ((any) -> (number?, number?))?
-- 그 사람의 말풍선 꾸밈(이름 — 없으면 nil · 2026-11-07 달빛 상점의 말풍선 상자). boot가 넣어 준다
Bubbles.skinOf = nil :: ((any) -> string?)?
local SKIN = {} -- 말풍선 꾸밈의 이름표(bm.generated의 bubbles — 공방 design/bubble.js)
local BUBBLES = require(ReplicatedStorage.shared.lune.data["bm.generated"]).bubbles
for _, q in (BUBBLES and BUBBLES.list) or {} do
	SKIN[q.id] = q
end
local function hex(h: string): Color3
	return Color3.fromRGB(tonumber(string.sub(h, 2, 3), 16) or 255, tonumber(string.sub(h, 4, 5), 16) or 255, tonumber(string.sub(h, 6, 7), 16) or 255)
end

local root: Frame? = nil
local list = {} -- [번호] = { frame, back, tail, body, till, w, h, text }

-- Roblox가 글자 꾸밈 꼬리표로 읽히지 않게 바꿔 보낸 글자를 되돌린다(우리 말풍선은 꾸밈을 읽지 않는다)
local ENTITY = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
local function unescape(text: string): string
	return (string.gsub(text, "&(%a+);", ENTITY))
end

local function make(id: any, parent: Instance?)
	local f = Ui.group(parent or root, 0, 0, 1, 1, "Bubble" .. tostring(id))
	f.Visible = false
	local back = Ui.part(f, "uBubble", 0, 0, 12, 14)
	local tail = Ui.part(f, "uTail", 0, 0)
	tail.ZIndex = 2
	local body = Ui.text(f, "", B.padX, B.padY, B.textW, { font = "body", lines = B.lines, line = LINE, color = C.bubbleInk, z = 3, raw = true }) -- raw: 사람이 친 글은 영문으로 바꾸지 않는다(2026-11-06)
	local b = { frame = f, back = back, tail = tail, body = body, till = 0, w = 0, h = 0, text = "", skin = nil, motif = nil, spark = nil, edge = nil, edgeC = nil }
	if not parent then
		list[id] = b
	end
	return b
end

function Bubbles.init()
	root = Stage.group(Overlay.root, "ChatBubbles", 53) -- 대화창(60) 아래 · 장면이 세계를 덮는 층(CineLook 54 · CineLow 55)보다도 아래(2026-10-29 — 전에는 55로 장면의 덮개와 같아 어느 쪽이 위인지 정해지지 않았다)
	pcall(function()
		TextChatService.MessageReceived:Connect(function(message: TextChatMessage)
			local source = message.TextSource
			if source and typeof(message.Text) == "string" then
				Bubbles.say(source.UserId, message.Text)
			end
		end)
	end)
end

-- 꾸밈을 입힌다(2026-11-07): 말풍선 그림을 tint로 물들이고 글은 ink · 왼쪽 위 귀퉁이에 7x7 무늬 · 드문 것은 오른쪽 위에 반짝임(Bubbles.place가 깜빡인다). nil = 처음 모습
local function dress(b, id: string?)
	if b.skin == id then
		return
	end
	b.skin = id
	if b.motif then
		b.motif:Destroy()
		b.motif = nil
	end
	if b.spark then
		b.spark:Destroy()
		b.spark = nil
	end
	if b.edge then
		b.edge:Destroy()
		b.edge = nil
	end
	local q = if id then SKIN[id] else nil
	local white = Color3.new(1, 1, 1)
	b.back.ImageColor3 = if q then hex(q.tint) else white
	b.tail.ImageColor3 = if q then hex(q.tint) else white
	b.body:color(if q then hex(q.ink) else C.bubbleInk)
	if not q then
		return
	end
	-- 테두리 · 안쪽 윗줄의 빛(말풍선의 크기가 정해진 뒤 Bubbles.say가 자리를 맞춘다 — b.edge)
	local e = Ui.group(b.frame, 0, 0, 1, 1, "Edge")
	e.ZIndex = 3
	local c0, c1 = hex(q.mc[1]), hex(q.mc[2])
	b.edge = e
	b.edgeC = { c0, c1 }
	local rows = BUBBLES.motifs[q.motif]
	if rows then
		local g = Ui.group(b.frame, -6, -10, 14, 14, "Motif") -- (무늬 = 두 배 — 왼쪽 위 귀퉁이에 붙인 딱지)
		g.ZIndex = 4
		local c1, c2 = hex(q.mc[1]), hex(q.mc[2])
		for ry, row in rows do
			for rx = 1, #row do
				local ch = string.sub(row, rx, rx)
				if ch == "1" or ch == "2" then
					local px = Ui.box(g, (rx - 1) * 2, (ry - 1) * 2, 2, 2, if ch == "1" then c1 else c2)
					px.ZIndex = 4
				end
			end
		end
		b.motif = g
	end
	if q.twinkle then
		local sp = Ui.group(b.frame, 0, -3, 5, 5, "Spark")
		sp.ZIndex = 4
		local c = hex(q.mc[2])
		for _, d in { { 2, 0 }, { 2, 1 }, { 0, 2 }, { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 2 }, { 2, 3 }, { 2, 4 } } do
			local px = Ui.box(sp, d[1], d[2], 1, 1, c)
			px.ZIndex = 4
		end
		b.spark = sp
	end
end

-- 글을 넣고 말풍선의 크기 · 꾸밈 테두리를 맞춘다(머리 위 Bubbles.say · 뽑기 연출의 Bubbles.sample)
local function fill(b, text: string)
	b.text = text
	b.body:set(text)
	local fitted = pixelText.Fit(text, B.textW, B.lines, "body", true)
	local count = #string.split(fitted, "\n")
	b.w = math.max(pixelText.Measure(fitted, "body", true), 24) + B.padX * 2
	b.h = (count - 1) * LINE + 14 + B.padY * 2
	b.back.Size = UDim2.fromOffset(b.w, b.h + 2)
	if b.edge and b.edgeC then -- 꾸밈의 테두리(위 · 아래 · 왼쪽 · 오른쪽 한 점 — 둥근 모서리는 그대로) · 안쪽 윗줄의 빛
		b.edge:ClearAllChildren()
		local c0, c1 = b.edgeC[1], b.edgeC[2]
		for _, r in { { 2, 0, b.w - 4, 1, c0 }, { 2, b.h - 1, b.w - 4, 1, c0 }, { 0, 2, 1, b.h - 4, c0 }, { b.w - 1, 2, 1, b.h - 4, c0 }, { 3, 2, b.w - 6, 1, c1 } } do
			local px = Ui.box(b.edge, r[1], r[2], r[3], r[4], r[5])
			px.ZIndex = 3
		end
	end
	b.frame.Size = UDim2.fromOffset(b.w, b.h + B.tail)
end

-- 그 사람의 머리 위에 말을 띄운다(이미 떠 있으면 새 말로 바꾼다)
function Bubbles.say(id: any, text: string)
	if not root then
		return
	end
	text = string.gsub(pixelText.Clean(unescape(text), true), "[\r\n\t]", " ") -- (true = 사람이 친 글 — 영문으로 바꾸지 않는다: 2026-11-06)
	local n = utf8.len(text) or 0
	if n > MAX then
		text = string.sub(text, 1, (utf8.offset(text, MAX + 1) or (#text + 1)) - 1) .. "…"
	end
	if not string.find(text, "[^ \t\r\n]") then
		return -- 빈 말(빈칸만 — 한글을 빈칸으로 잘못 읽지 않게 ASCII 빈칸만 본다)
	end
	local b = list[id] or make(id)
	dress(b, if Bubbles.skinOf then Bubbles.skinOf(id) else nil) -- 그 사람의 말풍선 꾸밈(2026-11-07)
	fill(b, text)
	b.till = os.clock() + SHOW
	Bubbles.place()
end

-- 말풍선 꾸밈 하나를 그 자리에 놓는다(2026-11-10 뽑기 연출 ui/gachaView.luau — 말풍선 상자에서 나온 꾸밈을 머리 위가 아니라 판 위에 그대로):
--  parent 안의 (x, y)가 말풍선의 가운데 아래(꼬리 끝) · 반짝임은 Bubbles.twinkle(b, now)로. 돌려준 것의 frame을 지우면 사라진다
function Bubbles.sample(parent: Instance, skin: string?, text: string, x: number, y: number)
	local b = make("Sample", parent)
	dress(b, skin)
	fill(b, require(ReplicatedStorage.shared.lune.lang).t(text)) -- (말풍선의 글은 raw — 사람이 친 글이 아니라 꾸밈의 이름이니 영문으로 바꿔 넣는다)
	b.frame.Position = UDim2.fromOffset(x - math.floor(b.w / 2), y - b.h - B.tail)
	b.tail.Position = UDim2.fromOffset(math.floor(b.w / 2) - 4, b.h - 1)
	if b.spark then
		b.spark.Position = UDim2.fromOffset(b.w - 3, -3)
	end
	b.frame.Visible = true
	return b
end
function Bubbles.twinkle(b, now: number)
	if b and b.spark then
		b.spark.Visible = now % 1 < 0.4
	end
end

-- 매 화면: 말풍선이 그 사람을 따라간다(시간이 다 됐거나 그 사람이 이 맵 · 화면에 없으면 숨긴다)
function Bubbles.place()
	local now = os.clock()
	for id, b in list do
		if now > b.till then
			b.frame.Visible = false
			continue
		end
		local x, y = nil, nil
		if Bubbles.where then
			x, y = Bubbles.where(id)
		end
		if not x or not y then
			b.frame.Visible = false
			continue
		end
		local cx = Overlay.x(x)
		local bottom = Overlay.y(y - HEAD - B.up)
		b.frame.Position = UDim2.fromOffset(cx - math.floor(b.w / 2), bottom - b.h - B.tail)
		b.tail.Position = UDim2.fromOffset(math.floor(b.w / 2) - 4, b.h - 1)
		if b.spark then -- 드문 꾸밈의 반짝임: 오른쪽 위에서 0.4초 보이고 0.6초 숨는다
			b.spark.Position = UDim2.fromOffset(b.w - 3, -3)
			b.spark.Visible = (now * 1.0) % 1 < 0.4
		end
		b.frame.Visible = cx >= 0 and cx <= Stage.uiW
	end
end

-- 지금 그 사람의 머리 위에 떠 있는 말(없으면 nil — 자동 검사가 본다)
function Bubbles.shown(id: any): string?
	local b = list[id]
	return if b and b.frame.Visible and os.clock() <= b.till then b.text else nil
end

-- 맵을 바꿀 때 모두 거둔다(말풍선은 화면 틀의 층에 있어 맵을 지워도 남는다 — Talk.hush와 같은 까닭)
function Bubbles.hush()
	for _, b in list do
		b.till = 0
		b.frame.Visible = false
	end
end

return Bubbles
