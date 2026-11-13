-- 채팅 — 우리 게임의 채팅 창(사용자 2026-11-06: "이제 로블록스 채팅이 아닌 우리 게임 자체 채팅구현하자").
--  2026-10-13 ~ 11-06에는 Roblox의 기본 채팅 창 · 입력줄 · 채널 탭을 켜고 색과 이름만 맞췄다(그때 사용자: "우리가 자체 채팅을 구현하는게 아니라 로블록스 채팅이 있어요 …").
--  글이 오가는 길은 그대로 Roblox의 채팅(TextChatService)이다 — 공식 문서(create.roblox.com/docs/chat/in-experience-text-chat)의 「기본 화면을 끄고 제 화면을 그리는」 방식:
--    · 기본 창 · 입력줄 · 채널 탭을 끈다(ChatWindowConfiguration · ChatInputBarConfiguration · ChannelTabsConfiguration의 Enabled = false)
--    · 보내기 = TextChannel:SendAsync(일반 = RBXGeneral · 파티 = 서버가 만든 채널 chatUi.party.channel). 돌려받은 글의 Status가 Success가 아니면 까닭을 알림 한 줄로(chatUi.fail)
--    · 받기 = TextChatService.MessageReceived(받은 글은 Roblox가 이 사람에게 맞게 이미 거른 것 · 누구에게 가는지는 서버가 정한다 — server/lune/modules/chat.luau: 일반 = 같은 맵 · 파티 = 같은 파티)
--    · 글 거르기 · 채팅 제한(나이 · Roblox 설정) · 차단은 Roblox가 그대로 맡는다
--  화면(공방 basics.js의 HUD 「채팅」 · HUDTOUCH 「채팅」 · TOUCH 「채팅」, 치수와 글 = ui.js의 CHATUI → data/ui.generated.luau의 chatUi, 셈 = shared/lune/ui/chatLog.luau):
--    PC: 왼쪽 아래 체력 덩어리 위의 비치는 판(늘 보인다). 작게(처음) = 글 세 줄 + 입력줄 · 크게 = 위에 탭 줄(전체 · 일반 · 파티 · 알림) + 글 여덟 줄. 입력줄 오른쪽 끝의 「+ / −」로 바꾼다(이번 접속 동안).
--        Enter = 적는 칸으로 · 적고 Enter = 보내기(그리고 칸을 떠난다). 판의 아래 끝은 그대로 두고 위로 자란다.
--    폰: 위쪽의 「채팅」 단추(touch.luau)로 여닫는다 — 열면 왼쪽 위에 크게(글 열 줄), 판 안의 「×」로 닫는다. 닫혀 있는 동안 남의 글이 오면 단추에 노란 점(Chat.onUnread).
--    입력줄: 보낼 곳 「일반 · 파티」를 나란히(고른 것 = 민트) · 적는 칸(Roblox의 글자 입력 칸 — 글씨는 Roblox 것) · 「+ / −」(PC).
--    지난 글은 chatUi.keep개까지 — 마우스 휠 · 손가락(마우스)으로 끌어 올려 본다(오른쪽 끝의 가는 민트 막대). 올려 보는 동안 새 글이 와도 그 자리 그대로 · 보내면 맨 아래로.
--    한 줄 = 「이름: 글」(이름 = 캐릭터의 이름 — Roblox의 이름이 아니다: 사용자 2026-10-10). 일반 = 이름 민트 · 글 흰색 / 파티 = 「[파티] 이름: 글」 전체가 분홍 / 알림 = 노랑.
--    남이 친 글은 영문으로 바꾸지 않는다(글씨의 raw). 알림(Chat.note)은 게임의 말이라 그 사람의 언어로.
--  확인하지 못한 것: 실제 화면에서의 모습 · Roblox가 돌려주는 Status의 실제 값(Play를 하지 않았다).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Log = require(lune.ui.chatLog)
local Lang = require(lune.lang)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)

local K = UI.chatUi
local C = Ui.COLOR
local TAB_GAP = 10 -- 탭 글 사이
local WHEEL = 2 -- 휠 한 칸에 올리는 줄
local ENTER_AFTER = 0.25 -- 보내고(칸을 떠나고) 이만큼 안에 온 Enter는 다시 칸을 열지 않는다(보낼 때 누른 Enter가 뒤따라 들어온다)

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
local COLOR = {
	name = hex(K.nameColor),
	text = hex(K.textColor),
	note = hex(K.noteColor),
	party = hex(K.party.color),
}
local function headColor(kind: string?): Color3
	return if kind == "party" then COLOR.party elseif kind == "note" then COLOR.note else COLOR.name
end
local function bodyColor(kind: string?): Color3
	return if kind == "party" then COLOR.party elseif kind == "note" then COLOR.note else COLOR.text
end

local Chat = {}
Chat.log = Log.new()
Chat.tab = "all" -- 보는 탭(chatUi.tabs의 id)
Chat.sendTo = "near" -- 보낼 곳(chatUi.send의 id)
Chat.big = false -- PC: 크게(탭 줄 + 여덟 줄)인가
Chat.min = false -- PC: 최소화(가장 최근 글 한 줄 + 입력줄 — 2026-11-07 사용자 "채팅시스템 최소화도 가능해야한다 메이플 채팅이랑 똑같이")
Chat.touch = false -- 폰의 손가락 단추가 켜져 있다
Chat.open = false -- 폰: 판이 열려 있다
Chat.scroll = 0 -- 맨 아래에서 올려 본 줄 수
Chat.bottom = 0 -- (예전: Roblox 채팅 창의 아래 끝 — 이제 쓰지 않는다. 늘 0)
Chat.onUnread = nil :: ((boolean) -> ())? -- 폰: 닫혀 있는 동안 남의 글이 왔다 · 열어서 봤다(boot가 touch의 점에 잇는다)
Chat.onOpen = nil :: ((boolean) -> ())? -- 폰: 판이 열렸다 · 닫혔다(boot가 「채팅」 단추를 숨기고 보인다)
Chat.onPeek = nil :: ((kind: string, name: string?, text: string) -> ())? -- 폰: 닫혀 있는 동안 남의 글이 왔다 — 그 글(boot가 바로가기 배치의 한 줄 미리 보기에 잇는다 · chatPeek.luau · 2026-11-13)
Chat.hasParty = nil :: (() -> boolean)? -- 지금 파티가 있나(boot가 partyHud에 잇는다)

local root: Instance? = nil
local holder: Frame? = nil
local field: TextBox? = nil
local draft = "" -- 판을 다시 지을 때 적던 글을 옮긴다
local rows = {} -- 글 칸 { head, body, y, was }
local tabs = {} -- [id] = 탭
local chans = {} -- [id] = 보낼 곳 단추
local thumb: Frame? = nil
local lostAt = -99
local drag: InputObject? = nil
local dragY, dragAcc = 0, 0

-- 글 줄을 나누는 법: 테두리 두른 작은 글씨의 폭으로 · 언어는 그대로(raw)
local function wrapRaw(text: string, width: number): string
	return pixelText.Wrap(text, width, "small_o", true)
end

function Chat.mode(): string
	return if Chat.touch then "touch" elseif Chat.min then "min" elseif Chat.big then "big" else "small"
end
local function rect()
	return if Chat.touch then UI.hudTouch.chat else UI.hud.chat
end

-- 옮긴 자리(PC — 2026-11-09 사용자 "채팅창 최소화 기능이랑, 채팅창 위치 웹처럼 자유롭게 배치할수있는기능 추가해야해"):
--  Chat.pos = 처음 자리에서 옮긴 만큼 { x, y }(화면 틀의 점 · nil = 처음 자리) — 판 위 가운데의 손잡이(Grip)를 끌어 옮긴다 · 손잡이를 두 번 누르면 처음 자리로.
--  화면 밖으로는 나가지 않는다(손잡이까지 화면 안). 놓으면 Chat.onMoved(pos)로 알린다(boot가 계정의 화면 설정에 저장 — sim/account.luau sound.chat). 폰은 처음 자리 그대로
Chat.pos = nil :: { x: number, y: number }?
Chat.onMoved = nil :: ((any) -> ())?
local GRIP_W, GRIP_H = 36, 6
-- 판의 왼쪽 위(at 기준의 x, y)에 옮긴 만큼을 더하고 화면 안으로 묶는다 — 화면 위의 실제 자리(왼쪽 위)로 셈해 묶은 뒤 at 기준으로 되돌린다
local function placed(at: string, x: number, y: number, w: number, h: number, pos): (number, number)
	if not pos then
		return x, y
	end
	local fy = if at:sub(1, 1) == "b" then 1 else 0
	local side = at:sub(2, 2)
	local fx = if side == "r" then 1 elseif side == "c" then 0.5 else 0
	local sx = x + pos.x - Stage.REF_W * fx + Stage.uiW * fx
	local sy = y + pos.y - Stage.REF_H * fy + Stage.uiH * fy
	local cx = math.clamp(sx, 0, math.max(0, Stage.uiW - w))
	local cy = math.clamp(sy, GRIP_H, math.max(GRIP_H, Stage.uiH - h))
	return x + pos.x + (cx - sx), y + pos.y + (cy - sy)
end
function Chat.setPos(pos: any)
	if typeof(pos) == "table" and typeof(pos.x) == "number" and typeof(pos.y) == "number" then
		Chat.pos = { x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5) }
	else
		Chat.pos = nil
	end
	if Chat.build then
		Chat.build() -- (아래에서 채운다 — 판을 다시 짓는다)
	end
end

-- 글 칸을 채운다(아래 칸이 새 줄 · 바뀐 칸만 다시 그린다)
local function paint()
	if not holder then
		return
	end
	local Lc = Log.layout(Chat.mode())
	local all = Log.rows(Chat.log, Chat.tab, Lc.logW, wrapRaw, Lang.t(K.party.tag))
	local first, scroll = Log.view(#all, Lc.lines, Chat.scroll)
	Chat.scroll = scroll
	local count = math.min(Lc.lines, #all)
	for i = 1, Lc.lines do
		local row = rows[i]
		if row then
			local r = all[first + (i - 1) - (Lc.lines - count)]
			local head, body, kind = if r then r.head else "", if r then r.body else "", if r then r.kind else nil
			local was = row.was
			if was.head ~= head or was.kind ~= kind then
				row.head:set(head)
				row.head:color(headColor(kind))
			end
			if was.body ~= body or was.kind ~= kind or was.head ~= head then
				row.body:set(body)
				row.body:color(bodyColor(kind))
				local hw = if head ~= "" then (row.head:size()) else 0
				row.body:move(K.pad + 2 + hw, row.y)
			end
			was.head, was.body, was.kind = head, body, kind
		end
	end
	if thumb then
		local at, len = Log.thumb(#all, Lc.lines, Chat.scroll, Lc.lines * K.lineH)
		thumb.Visible = at ~= nil
		if at and len then
			thumb.Position = UDim2.fromOffset(0, at)
			thumb.Size = UDim2.fromOffset(K.bar, len)
		end
	end
end
Chat.paint = paint

local function scrollBy(lines: number)
	if lines ~= 0 then
		Chat.scroll = math.max(0, Chat.scroll + lines)
		paint()
	end
end

-- 글 하나를 더한다(mine = 내가 친 글 · 알림 — 폰의 점을 켜지 않는다)
local function add(kind: string, name: string?, text: string, mine: boolean?)
	local e = Log.add(Chat.log, kind, name, text)
	if not e then
		return
	end
	-- 올려 보는 중이면 보던 줄이 그 자리에 있게: 새 글의 줄 수만큼 더 올린다
	if Chat.scroll > 0 and Log.shows(Chat.tab, kind) then
		local Lc = Log.layout(Chat.mode())
		Chat.scroll += #Log.split(e, Lc.logW, wrapRaw, Lang.t(K.party.tag))
	end
	if Chat.touch and not Chat.open and not mine and kind ~= "note" and Chat.onUnread then
		Chat.onUnread(true)
	end
	if Chat.touch and not Chat.open and not mine and kind ~= "note" and Chat.onPeek then
		Chat.onPeek(kind, name, text)
	end
	paint()
end
Chat.add = add

-- 알림 글(이 사람의 화면에만 — 게임의 말이라 그 사람의 언어로)
function Chat.note(text: string)
	add("note", nil, Log.clean(Lang.t(text)), true)
end

-- 적는 칸에 글을 치는 중인가(그동안 게임의 키를 받지 않는다 — input.luau)
function Chat.focused(): boolean
	local ok, on = pcall(function()
		return field ~= nil and field:IsFocused()
	end)
	return ok and on == true
end

-- 보낸다(빈 글은 보내지 않는다). 돌려주는 것: 보냈나
function Chat.send(text: string): boolean
	text = Log.cut(Log.clean(text), K.maxLen)
	if text == "" then
		return false
	end
	Chat.scroll = 0
	local party = Chat.sendTo == "party"
	if party and Chat.hasParty and not Chat.hasParty() then
		Chat.note(K.noParty) -- 파티가 없으면 나에게만 보인다(서버: 같은 파티 = 나 자신도 — 그래도 보낸다)
	end
	task.spawn(function()
		local ok, why = pcall(function()
			local channels = TextChatService:WaitForChild("TextChannels", 5)
			local channel = channels and channels:FindFirstChild(if party then K.party.channel else "RBXGeneral")
			if not channel then
				return "other"
			end
			local msg = (channel :: any):SendAsync(text)
			local st = msg and msg.Status
			if st == nil or st == Enum.TextChatMessageStatus.Success or st == Enum.TextChatMessageStatus.Sending then
				return nil
			end
			return string.match(tostring(st), "([%w_]+)$") -- 「Enum.TextChatMessageStatus.Floodchecked」 → Floodchecked
		end)
		local reason = if ok then why else "other"
		if reason then
			Chat.note(Log.failText(reason))
		end
	end)
	paint()
	return true
end

-- 받은 글(Roblox가 이 사람에게 건넨 것)
local function onMessage(message: TextChatMessage)
	local status = (message :: any).Status
	if status ~= nil and status ~= Enum.TextChatMessageStatus.Success then
		return -- 보내지 못한 글(보낸 쪽은 Chat.send가 알린다)
	end
	local source = message.TextSource
	if source then
		local player = Players:GetPlayerByUserId(source.UserId)
		local name = if player then player:GetAttribute("LuneName") else nil
		if typeof(name) ~= "string" or name == "" then
			name = "?" -- 캐릭터의 이름을 모른다(Roblox의 이름은 쓰지 않는다)
		end
		local channel = message.TextChannel
		local kind = if channel and channel.Name == K.party.channel then "party" else "near"
		local me = Players.LocalPlayer
		add(kind, name, Log.clean(message.Text), me ~= nil and source.UserId == me.UserId)
	else
		add("note", nil, Log.clean(message.Text, true), true) -- Roblox의 알림(너무 빨리 보낸다 등 — 꾸밈 꼬리표를 지운다)
	end
end
Chat.onMessage = onMessage

function Chat.setTab(id: string)
	Chat.tab = id
	Chat.scroll = 0
	for key, t in tabs do
		t:setOn(key == id)
	end
	paint()
end

function Chat.setSend(id: string)
	Chat.sendTo = id
	for key, b in chans do
		b:setMain(key == id)
	end
end

local build
function Chat.setBig(on: boolean)
	if Chat.big ~= on then
		Chat.big = on
		build()
	end
end

-- 최소화한다 · 편다(PC — 편 판은 접기 전의 크기 그대로)
function Chat.setMin(on: boolean)
	if Chat.min ~= on then
		Chat.min = on
		Chat.scroll = 0
		build()
	end
end

-- 폰: 판을 연다 · 닫는다
function Chat.setOpen(on: boolean)
	Chat.open = on
	if holder then
		holder.Visible = not Chat.touch or on
	end
	if not on and field and Chat.focused() then
		pcall(function()
			(field :: TextBox):ReleaseFocus()
		end)
	end
	if on and Chat.onUnread then
		Chat.onUnread(false)
	end
	if Chat.onOpen then
		Chat.onOpen(on)
	end
end
function Chat.toggle()
	Chat.setOpen(not Chat.open)
end

-- 폰의 손가락 단추가 켜졌다 · 꺼졌다: 자리와 꼴을 바꾼다(폰은 닫힌 채로 시작)
function Chat.setTouch(on: boolean)
	if Chat.touch == on then
		return
	end
	Chat.touch = on
	build()
	Chat.setOpen(false)
end

-- 「+ / −」(PC): 크게 · 작게 — 퀘스트 알리미의 단추와 같은 그림(가는 막대)
local function toggleButton(parent: Instance, Lc)
	local b = Ui.box(parent, Lc.toggleX, Lc.inputY, K.toggleW, K.inputH, C.panel2)
	b.Name = "Size"
	local cx, cy = math.floor(K.toggleW / 2), math.floor(K.inputH / 2)
	Ui.box(b, cx - 3, cy, 7, 1, C.text).Name = "Bar"
	if not Chat.big then
		Ui.box(b, cx, cy - 3, 1, 7, C.text).Name = "Bar"
	end
	Ui.hit(b).Activated:Connect(function()
		Chat.setBig(not Chat.big)
	end)
	return b
end

-- 「_ / □」 단추(2026-11-07): 접혀 있지 않으면 「_」(누르면 접는다) · 접혀 있으면 「□」(누르면 편다) — 공방 paint.js chatPanel과 같은 그림
local function minButton(parent: Instance, Lc)
	local b = Ui.box(parent, Lc.minX, Lc.inputY, K.toggleW, K.inputH, C.panel2)
	b.Name = "Min"
	local cx, cy = math.floor(K.toggleW / 2), math.floor(K.inputH / 2)
	if Chat.min then
		Ui.box(b, cx - 3, cy - 3, 7, 1, C.text).Name = "Bar"
		Ui.box(b, cx - 3, cy + 3, 7, 1, C.text).Name = "Bar"
		Ui.box(b, cx - 3, cy - 3, 1, 7, C.text).Name = "Bar"
		Ui.box(b, cx + 3, cy - 3, 1, 7, C.text).Name = "Bar"
	else
		Ui.box(b, cx - 3, cy + 3, 7, 1, C.text).Name = "Bar"
	end
	Ui.hit(b).Activated:Connect(function()
		Chat.setMin(not Chat.min)
	end)
	return b
end

-- 판을 (다시) 짓는다: 크기 · 폰으로 바뀔 때
build = function()
	if not root then
		return
	end
	if field then
		draft = field.Text
	end
	if holder then
		holder:Destroy()
	end
	table.clear(rows)
	table.clear(tabs)
	table.clear(chans)
	local r = rect()
	local Lc = Log.layout(Chat.mode())
	local y = if Chat.touch then r.y else r.y + r.h - Lc.h -- PC: 아래 끝은 그대로 · 폰: 위 끝은 그대로
	local bx, by = placed(r.at, r.x, y, r.w, Lc.h, Chat.pos) -- (옮긴 자리 — 위 Chat.pos · 2026-11-12부터 폰도: 「화면 배치」 ui/arrange.luau로 옮긴다 — 자리는 기기 종류마다 따로 저장)
	local box = Stage.place(root, "Chat", r.at, bx, by, r.w, Lc.h)
	holder = box
	box.Visible = not Chat.touch or Chat.open
	Ui.box(box, 0, 0, r.w, Lc.h, hex(K.back), K.alpha).Name = "Back"
	-- 탭(크게일 때 · 폰)
	if Lc.tabs then
		local x = K.pad + 2
		for _, t in K.tabs do
			local item = Ui.tab(box, t.name, x, Lc.tabY, function()
				Chat.setTab(t.id)
			end)
			item:setOn(t.id == Chat.tab)
			tabs[t.id] = item
			x += item.width + TAB_GAP
		end
		if Lc.close then
			Ui.closeButton(box, Lc.closeX, Lc.tabY - 2, function()
				Chat.setOpen(false)
			end)
		end
	end
	-- 글 칸(아래가 새 줄). 앞머리(이름)와 글을 따로 — 색이 다르다
	for i = 1, Lc.lines do
		local ry = Lc.logY + (i - 1) * K.lineH + 2
		rows[i] = {
			head = Ui.text(box, "", K.pad + 2, ry, Lc.logW, { outline = true, raw = true }),
			body = Ui.text(box, "", K.pad + 2, ry, Lc.logW, { outline = true, raw = true }),
			y = ry,
			was = {},
		}
	end
	-- 스크롤 막대(오른쪽 끝)와 끌어 올리는 자리
	local track = Ui.box(box, Lc.barX, Lc.logY, K.bar, Lc.lines * K.lineH, C.line, 0.6)
	track.Name = "Track"
	thumb = Ui.box(track, 0, 0, K.bar, 6, C.accent)
	local area = Ui.group(box, 0, Lc.logY, r.w, Lc.lines * K.lineH, "LogArea")
	area.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			scrollBy(if input.Position.Z > 0 then WHEEL else -WHEEL)
		end
	end)
	area.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			drag, dragY, dragAcc = input, input.Position.Y, 0
		end
	end)
	-- 입력줄: 보낼 곳 둘 · 적는 칸 · 「+ / −」
	for i, s in K.send do
		chans[s.id] = Ui.button(box, s.name, Lc.chanX[i], Lc.inputY, K.chanW, function()
			Chat.setSend(s.id)
		end, { h = K.inputH, main = s.id == Chat.sendTo })
	end
	local input = Ui.field(box, Lc.fieldX, Lc.inputY, Lc.fieldW, K.inputH, if Chat.touch then K.hintTouch else K.hint)
	-- 한글의 마지막 글자(2026-11-06 사용자: "안녕하세요 치고 엔터치면 안녕하세 까지 나와" · 11-07 "한글만 커서가 한칸전에서된다고"):
	--  Roblox의 글자 입력 칸은 조합 중인 글자를 화면에만 그리고 Text에는 아직 넣지 않는다(그래서 커서가 한 칸 앞에 선다) — Enter 순간 그 글자가 버려진다.
	--  Roblox 개발자 포럼에 같은 보고가 있다(devforum.roblox.com/t/chat-bug-when-entering-korean/4327205 · /t/korean-chat-write-bug/3908990) — 고친 소식은 없다.
	--  해 본 것(Studio Output으로 확인): ① Enter를 줄바꿈으로 받고 두 장면 뒤에 보내기 ② 글이 0.35초 더 바뀌지 않을 때까지 기다리기 ③ 커서를 끝으로 옮기기 · 칸을 놓기
	--   ④ 칸을 Roblox 채팅에 맡기기(ChatInputBarConfiguration.TextBox) — 모두 마지막 글자가 돌아오지 않았다(④는 Roblox가 보내도 「아니아직도이러잖」).
	--   ④는 맡긴 칸을 스크립트로 잡을 수 없어(「Cannot use :CaptureFocus() on a TextBox that is reserved …」) Enter로 칸이 열리지 않았다 → 걷었다.
	--   한글로 칠 때 Roblox가 받는 키는 거의 늘 None이라 키로 글자를 맞춰 붙일 수도 없다.
	--   ⑤ 칸이 잡혀 있는 동안 「보이는 글」(ContentText)을 지켜보기 — 조합 중인 글자는 ContentText에도 없고 글의 폭(TextBounds)에만 잡혔다(「아니」 + 「야」 조합 중 = 폭 24).
	--  결론(2026-11-07): Roblox는 조합 중인 글자가 무엇인지 스크립트에 알려 주지 않는다 — 게임 코드로는 되살릴 수 없는 Roblox의 버그(Roblox가 직접 보내도 빠진다).
	--   플레이어가 마지막 글자 뒤에 스페이스를 치면 확정되어 다 간다. 그래서 처음처럼: Enter = 칸을 떠나며 바로 보낸다.
	input.MultiLine = false
	input.TextWrapped = false
	input.Text = draft
	field = input
	input:GetPropertyChangedSignal("Text"):Connect(function()
		local text = input.Text
		local len = utf8.len(text)
		if len and len > K.maxLen then
			input.Text = Log.cut(text, K.maxLen)
		end
	end)
	input.FocusLost:Connect(function(enter: boolean)
		lostAt = os.clock()
		local text = string.gsub(input.Text, "[\r\n]", "") -- (Enter가 남기는 \r — Roblox의 입력 칸)
		if enter then
			input.Text = ""
			draft = ""
			Chat.send(text)
		else
			draft = text
		end
	end)
	-- 손잡이(PC — 판 위 가운데의 작은 탭 · 입력줄의 단추들보다 먼저 짓는다): 끌어서 옮긴다 · 두 번 누르면 처음 자리(위 Chat.pos)
	if not Chat.touch then
		local grip = Ui.box(box, math.floor((r.w - GRIP_W) / 2), -GRIP_H, GRIP_W, GRIP_H, hex(K.back), K.alpha)
		grip.Name = "Grip"
		for i = -1, 1 do
			Ui.box(grip, math.floor(GRIP_W / 2) + i * 5 - 1, 2, 2, 2, C.dim).Name = "Dot"
		end
		pcall(function() -- (끌기에 쓰는 이벤트가 없는 곳 — 시험의 가짜 화면 — 에서는 손잡이만 그린다)
			local hit = Ui.hit(grip)
			local start, base, lastDown = nil, nil, -9
			hit.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end
				if os.clock() - lastDown < 0.35 then -- 두 번 눌렀다: 처음 자리로
					lastDown = -9
					start = nil
					Chat.setPos(nil)
					if Chat.onMoved then
						Chat.onMoved(nil)
					end
					return
				end
				lastDown = os.clock()
				start = Vector2.new(input.Position.X, input.Position.Y)
				base = Chat.pos or { x = 0, y = 0 }
			end)
			local moveConn, endConn
			moveConn = UserInputService.InputChanged:Connect(function(input)
				if not start or input.UserInputType ~= Enum.UserInputType.MouseMovement or holder ~= box then
					return
				end
				local us = math.max(1, Stage.uiScale or 1)
				local want = { x = base.x + (input.Position.X - start.X) / us, y = base.y + (input.Position.Y - start.Y) / us }
				local nx, ny = placed(r.at, r.x, y, r.w, Lc.h, want)
				box.Position = Stage.atPosition(r.at, nx, ny)
				Chat.pos = { x = math.floor(want.x + (nx - (r.x + want.x)) + 0.5), y = math.floor(want.y + (ny - (y + want.y)) + 0.5) }
			end)
			endConn = UserInputService.InputEnded:Connect(function(input)
				if not start or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end
				start = nil
				if Chat.onMoved then
					Chat.onMoved(Chat.pos)
				end
			end)
			box.Destroying:Connect(function()
				moveConn:Disconnect()
				endConn:Disconnect()
			end)
		end)
	end
	if Lc.toggle then
		toggleButton(box, Lc)
	end
	if Lc.minBtn and Lc.minX then
		minButton(box, Lc)
	end
	paint()
end
Chat.build = function()
	build()
end

-- Roblox의 기본 채팅 화면을 끈다(나중에 생겨도)
local OFF = { ChatWindowConfiguration = true, ChatInputBarConfiguration = true, ChannelTabsConfiguration = true }
local function hide(d: Instance)
	if OFF[d.ClassName] then
		pcall(function()
			(d :: any).Enabled = false
		end)
	end
end

function Chat.init(parent: Instance?)
	root = parent
	pcall(function()
		for _, d in TextChatService:GetDescendants() do
			hide(d)
		end
		TextChatService.DescendantAdded:Connect(hide)
	end)
	pcall(function()
		TextChatService.MessageReceived:Connect(onMessage)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.Return and input.KeyCode ~= Enum.KeyCode.KeypadEnter then
			return
		end
		if Chat.touch or not field or not holder or os.clock() - lostAt < ENTER_AFTER or UserInputService:GetFocusedTextBox() then
			return
		end
		local shown = holder.Visible and (root == nil or not root:IsA("GuiObject") or (root :: GuiObject).Visible)
		if shown then
			local f = field
			task.defer(function()
				pcall(function()
					f:CaptureFocus()
				end)
			end)
		end
	end)
	-- 끌어 올리기(손가락 · 마우스): 위로 끌면 새 글 쪽 · 아래로 끌면 지난 글 쪽
	UserInputService.InputChanged:Connect(function(input)
		if not drag then
			return
		end
		local same = input == drag or (drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
		if same then
			local dy = (input.Position.Y - dragY) / math.max(1, Stage.uiScale or 1)
			dragY = input.Position.Y
			dragAcc += dy
			local lines = if dragAcc >= 0 then math.floor(dragAcc / K.lineH) else -math.floor(-dragAcc / K.lineH)
			if lines ~= 0 then
				dragAcc -= lines * K.lineH
				scrollBy(lines)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if drag and (input == drag or input.UserInputType == Enum.UserInputType.MouseButton1) then
			drag = nil
		end
	end)
	if root then
		build()
		-- 폰의 판은 왼쪽 위(Roblox 단추의 띠 아래)에 붙는다 — 띠의 높이 · 격자가 바뀌면 다시 놓는다(그대로면 · 글을 치는 중이면 그대로 — 폰의 글자판이 뜰 때 다시 지어 칸을 잃지 않게)
		local was = ""
		Stage.onResize(function()
			local now = ("%s/%s/%s"):format(tostring(Stage.uiW), tostring(Stage.uiH), tostring(Stage.insetTop))
			if now ~= was and not Chat.focused() then
				was = now
				build()
			end
		end)
	end
end

return Chat
