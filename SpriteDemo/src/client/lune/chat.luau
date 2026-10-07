-- 채팅 — 화면 왼쪽 아래, 체력 덩어리 바로 위(공방 「기본 · UI」 탭의 화면 배치, data/ui.generated.luau의 hud.chat).
--  글은 Roblox의 채팅(TextChatService)을 거쳐 오간다: 글 거르기 · 신고가 그쪽에 들어 있다. 여기서는 보이는 것과 쓰는 칸만 우리 것으로 바꾼다
--  (Roblox 기본 채팅 창과 입력줄은 끈다 — 기본 것은 Enter로 열리지 않고 도트 화면과 어울리지 않는다).
--  평소: 새 글이 오면 마지막 세 줄이 판 없이(어두운 테두리를 두른 작은 글씨로) 잠깐(12초) 보였다가 사라진다.
--  Enter: 어두운 판이 뜨고 지난 글 여섯 줄과 쓰는 칸이 보인다. 한 번 더 Enter로 보내고 닫는다.
--  채널: 둘레(같은 맵의 사람) · 파티. 쓰는 칸 왼쪽의 단추로 바꾼다. 누구에게 가는지는 서버가 정한다(server/lune/modules/chat.luau).
--  쓰는 칸은 Roblox의 글자 입력 칸(TextBox)이라 그 글꼴은 Roblox 것이다(도트 글꼴은 입력 칸에 쓸 수 없다). 받은 글은 도트 글꼴로 그린다 —
--  한글 · 영문 · 숫자가 아닌 글자(한자 · 이모지 등)는 "?"로 보인다.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Format = require(lune.ui.format)
local Tags = require(lune.ui.tags)
local Layout = require(lune.ui.layout)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)

local C = Ui.COLOR
local KEEP = 40 -- 지난 글을 몇 개까지 갖고 있나
local LINE = Layout.CHAT.line
local FIELD = Layout.CHAT.field -- 쓰는 칸 · 채널 단추의 높이
local OPEN = Layout.CHAT.open -- 쓰는 중의 넓은 판(높이는 줄 수에서)
local QUIET = { w = UI.hud.chat.w, lines = math.floor(UI.hud.chat.h / LINE), life = Layout.CHAT.life } -- 평소: 폭 · 세 줄 · 새 글이 온 뒤 보이는 시간(초)
local CHANNEL = { { id = "near", name = "둘레", channel = "RBXGeneral", color = C.text }, { id = "party", name = "파티", channel = "파티", color = C.pink } }

local Chat = {}
Chat.OPEN = OPEN
Chat.QUIET = QUIET
Chat.lastAt = -99 -- 마지막으로 새 글이 온 때
Chat.log = {} -- { text(그릴 한 줄), color }
Chat.channel = 1
Chat.typing = false
Chat.closedAt = 0

local root: Frame
local quiet: Frame -- 평소의 칸
local quietLines = {}
local panel: Frame -- 쓰는 중의 칸
local panelLines = {}
local box: TextBox
local channelButton

-- 줄들을 아래부터 채운다: 새 글이 맨 아래에 오고, 긴 글은 칸의 폭에서 줄을 바꾼다(한 글에 perMessage줄까지 — 넘으면 …)
local function fill(rows, width: number, perMessage: number)
	local row = #rows
	for i = #Chat.log, 1, -1 do
		if row < 1 then
			break
		end
		local item = Chat.log[i]
		local lines = string.split(pixelText.Fit(item.text, width, perMessage, "small"), "\n")
		for k = #lines, 1, -1 do
			if row < 1 then
				break
			end
			rows[row]:set(lines[k])
			rows[row]:color(item.color)
			row -= 1
		end
	end
	for i = row, 1, -1 do
		rows[i]:set("")
	end
end

local function draw()
	quiet.Visible = not Chat.typing and #Chat.log > 0 and os.clock() - Chat.lastAt < QUIET.life
	panel.Visible = Chat.typing
	if Chat.typing then
		fill(panelLines, OPEN.w - OPEN.pad * 2, 3)
	else
		fill(quietLines, QUIET.w, 2) -- 평소: 한 글에 두 줄까지
	end
end

-- 글 한 줄을 지난 글에 더한다
function Chat.add(channelId: string, name: string?, text: string)
	local color = C.text
	for _, ch in CHANNEL do
		if ch.id == channelId then
			color = ch.color
		end
	end
	table.insert(Chat.log, { text = Tags.chatLine(channelId, name, text), color = color })
	while #Chat.log > KEEP do
		table.remove(Chat.log, 1)
	end
	Chat.lastAt = os.clock()
	if root then
		draw()
		-- 조금 뒤에 저절로 사라진다(그사이 새 글이 왔으면 그 글의 때에 맞춰 다시 본다)
		task.delay(QUIET.life + 0.1, function()
			if root then
				draw()
			end
		end)
	end
end

-- 알림 글(서버나 게임이 알리는 것)
function Chat.note(text: string)
	table.insert(Chat.log, { text = text, color = C.gold })
	if root then
		draw()
	end
end

local function setChannel(index: number)
	Chat.channel = index
	channelButton:setText(CHANNEL[index].name)
end

function Chat.open()
	-- 보내거나 닫은 바로 그 Enter가 다시 여는 일이 없게, 닫은 직후에는 열지 않는다
	if Chat.typing or not box or os.clock() - Chat.closedAt < 0.25 then
		return
	end
	Chat.typing = true
	draw()
	box.Text = ""
	box:CaptureFocus()
end

function Chat.close()
	Chat.typing = false
	Chat.closedAt = os.clock()
	if box then
		box.Text = ""
		box:ReleaseFocus()
	end
	draw()
end

local function send(text: string)
	local clean = Tags.chatClean(text)
	if not clean then
		return
	end
	local def = CHANNEL[Chat.channel]
	task.spawn(function()
		local ok = pcall(function()
			local channels = TextChatService:WaitForChild("TextChannels", 5)
			local channel = channels and channels:FindFirstChild(def.channel)
			assert(channel, "채널 없음")
			channel:SendAsync(clean)
		end)
		if not ok then
			Chat.note("글을 보내지 못했다")
		end
	end)
end

-- 스마트폰 단추가 켜지면 채팅 줄을 왼쪽 위로 옮긴다(왼쪽 아래에는 이동 패드가 온다 — data/ui.generated.luau의 hudTouch).
--  쓰는 판도 위에 뜬다: 화면 아래 절반은 글자판이 덮는다.
function Chat.setTouch(on: boolean)
	if not quiet or not panel then
		return
	end
	local r = UI.hud.chat
	local t = UI.hudTouch.chat
	local o = Layout.chatOpen()
	if on and t then
		quiet.Position = Stage.atPosition(t.at, t.x, t.y)
		panel.Position = Stage.atPosition(t.at, t.x, t.y)
	else
		quiet.Position = Stage.atPosition(r.at, r.x, r.y)
		panel.Position = Stage.atPosition(o.at, o.x, o.y)
	end
end

function Chat.init(parent: Frame)
	-- Roblox 기본 채팅 창과 입력줄은 끈다(채널과 글 거르기는 그대로 쓴다)
	pcall(function()
		local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if window then
			window.Enabled = false
		end
		local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if bar then
			bar.Enabled = false
		end
	end)

	local r = UI.hud.chat
	root = Stage.group(parent, "Chat", 20)

	-- 평소: 새 글 세 줄(판 없이 — 테두리를 두른 글)
	quiet = Stage.placeRect(root, "Quiet", r)
	for i = 1, QUIET.lines do
		quietLines[i] = Ui.text(quiet, "", 0, (i - 1) * LINE, QUIET.w, { outline = true })
	end

	-- 쓰는 중: 어두운 판에 지난 글 여섯 줄 + 채널 단추 + 쓰는 칸. 아래 끝을 평소 칸의 아래 끝에 맞춘다
	local o = Layout.chatOpen()
	local h = o.h
	local holder = Stage.placeRect(root, "Open", o)
	panel = holder
	Ui.panel(holder, 0, 0, OPEN.w, h)
	for i = 1, OPEN.lines do
		panelLines[i] = Ui.text(holder, "", OPEN.pad, OPEN.pad + (i - 1) * LINE, OPEN.w - OPEN.pad * 2)
	end
	local inputY = OPEN.pad + OPEN.lines * LINE + 4
	channelButton = Ui.button(holder, CHANNEL[1].name, OPEN.pad, inputY, OPEN.channelW, function()
		setChannel(Chat.channel % #CHANNEL + 1)
		if box then
			box:CaptureFocus()
		end
	end, { h = FIELD })
	local fieldW = OPEN.w - OPEN.pad * 2 - OPEN.channelW - 6
	local field = Ui.group(holder, OPEN.pad + OPEN.channelW + 6, inputY, fieldW, FIELD, "Field")
	Ui.part(field, "uField", 0, 0, fieldW, FIELD)
	box = Instance.new("TextBox")
	box.Name = "Input"
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(6, 0)
	box.Size = UDim2.new(1, -12, 1, 0)
	box.Font = Enum.Font.SourceSans
	box.TextSize = 12
	box.TextColor3 = C.text
	box.PlaceholderText = "Enter로 보낸다"
	box.PlaceholderColor3 = C.off
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Text = ""
	box.ZIndex = 6
	box.Parent = field
	box.FocusLost:Connect(function(enter: boolean)
		if not Chat.typing then
			return
		end
		local text = box.Text
		if enter and Tags.chatClean(text) then
			send(text)
		end
		Chat.close()
	end)

	-- 받은 글: 이름은 이름표에 적는 꼴로(글꼴에 없는 글자가 섞인 이름은 아이디로)
	TextChatService.MessageReceived:Connect(function(message)
		if message.Status ~= Enum.TextChatMessageStatus.Success then
			return -- 내가 보낸 글도 서버가 받아 준 뒤에 한 번만 넣는다
		end
		local channel = message.TextChannel
		local id = "near"
		for _, ch in CHANNEL do
			if channel and channel.Name == ch.channel then
				id = ch.id
			end
		end
		local source = message.TextSource
		local name = nil
		if source then
			local player = Players:GetPlayerByUserId(source.UserId)
			name = if player then Format.safeName(player.DisplayName, player.Name) else source.Name
		elseif channel and channel.Name ~= "RBXGeneral" and channel.Name ~= "파티" then
			return -- 시스템 채널의 글은 넣지 않는다
		end
		Chat.add(id, name, message.Text)
	end)
	draw()
end

return Chat
