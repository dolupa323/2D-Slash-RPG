-- 채팅 — 화면 왼쪽 아래의 채팅 칸(공방 「기본 · UI」 탭의 확정 배치 6번, data/ui.generated.luau의 hud.chat).
--  글은 Roblox의 채팅(TextChatService)을 거쳐 오간다: 글 거르기 · 신고가 그쪽에 들어 있다. 여기서는 보이는 것과 쓰는 칸만 우리 것으로 바꾼다
--  (Roblox 기본 채팅 창과 입력줄은 끈다 — 기본 것은 Enter로 열리지 않고 도트 화면과 어울리지 않는다).
--  평소: 새 글이 오면 세 줄이 흐린 바탕 위에 잠깐(12초) 보였다가 사라진다. Enter: 쓰는 칸이 열리고 지난 글이 보인다. 한 번 더 Enter로 보내고 닫는다.
--  평소의 글은 공방에서 잡은 칸(폭 116)보다 넓게, 상태바 바로 위에 그린다 — 116에는 이름을 빼면 한글 여덟 자쯤밖에 안 들어간다.
--  폭 168: 화면 가운데에 서 있는 내 캐릭터를 가리지 않는 데까지. 바탕은 비치는 어두운 판, 글씨는 작은 글씨.
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
local Kit = require(script.Parent.ui.kit)
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)

local C = Kit.COLOR
local KEEP = 40 -- 지난 글을 몇 개까지 갖고 있나
local LINE = Kit.LINE
local OPEN = { x = 2, w = 230, lines = 6 } -- 쓰는 중의 넓은 칸(높이는 줄 수에서)
local QUIET = { w = 168, lines = 3, life = 12 } -- 평소: 폭 · 세 줄 · 새 글이 온 뒤 보이는 시간(초)
local BOTTOM = UI.hud.vitals.y - 1 -- 채팅 칸의 아래 끝: 상태바 바로 위
local CHANNEL = { { id = "near", name = "둘레", channel = "RBXGeneral", color = C.white }, { id = "party", name = "파티", channel = "파티", color = C.mint } }

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
		fill(panelLines, OPEN.w - 10, 3)
	else
		fill(quietLines, QUIET.w - 8, 2) -- 평소: 한 글에 두 줄까지
	end
end

-- 글 한 줄을 지난 글에 더한다
function Chat.add(channelId: string, name: string?, text: string)
	local color = C.white
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
	root = Kit.group(parent, 0, 0, 1, 1)
	root.Name = "Chat"
	root.ZIndex = 20

	-- 평소: 새 글 세 줄(비치는 바탕)
	local qh = QUIET.lines * LINE + 3
	quiet = Kit.group(root, r.x, BOTTOM - qh, QUIET.w, qh)
	quiet.Name = "Quiet"
	Kit.part(quiet, "veil", 0, 0, QUIET.w, qh).ImageTransparency = 0.15 -- 뒤의 이름표가 글에 섞여 보이지 않을 만큼 짙게
	for i = 1, QUIET.lines do
		quietLines[i] = Kit.text(quiet, "", 4, 2 + (i - 1) * LINE, QUIET.w - 8)
	end

	-- 쓰는 중: 지난 글 여섯 줄 + 채널 단추 + 쓰는 칸. 아래 끝을 평소 칸의 아래 끝에 맞춘다
	local h = OPEN.lines * LINE + 6 + 16
	panel = Kit.group(root, OPEN.x, BOTTOM - h, OPEN.w, h)
	panel.Name = "Open"
	Kit.part(panel, "panel", 0, 0, OPEN.w, h)
	for i = 1, OPEN.lines do
		panelLines[i] = Kit.text(panel, "", 5, 4 + (i - 1) * LINE, OPEN.w - 10)
	end
	local inputY = OPEN.lines * LINE + 5
	Kit.box(panel, 3, inputY - 2, OPEN.w - 6, 1, C.edgeDim)
	channelButton = Kit.button(panel, CHANNEL[1].name, 4, inputY, 30, 13, function()
		setChannel(Chat.channel % #CHANNEL + 1)
		if box then
			box:CaptureFocus()
		end
	end)
	local field = Kit.group(panel, 36, inputY, OPEN.w - 40, 13)
	Kit.part(field, "field", 0, 0, OPEN.w - 40, 13)
	box = Instance.new("TextBox")
	box.Name = "Input"
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(3, 0)
	box.Size = UDim2.new(1, -6, 1, 0)
	box.Font = Enum.Font.SourceSans
	box.TextSize = 10
	box.TextColor3 = C.white
	box.PlaceholderText = "Enter로 보낸다"
	box.PlaceholderColor3 = C.gray
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
