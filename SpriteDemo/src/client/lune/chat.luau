-- 채팅 — Roblox의 기본 채팅(TextChatService의 채팅 창 · 입력줄 · 채널 탭)을 그대로 쓴다. 우리가 그리는 채팅 화면은 없다.
--  사용자 2026-10-13: "우리가 자체 채팅을 구현하는게 아니라 로블록스 채팅이 있어요 로블록스 공식문서좀 확인해보고 ,  그걸 어떻게 로블록스 채팅을 우리게임에 자연스럽게 사용하게 연결할수있는지
--                     불가능하다면 그냥 채팅 없어도됩니다."
--  전에는 글만 Roblox의 채팅으로 보내고(TextChannel:SendAsync) 창과 쓰는 칸은 우리 것이었다(기본 창 · 입력줄은 꺼 두었다). 이제 창 · 입력줄 · 폰의 채팅 단추까지 Roblox의 것이다:
--    글 거르기 · 신고 · 한글 입력 · 폰의 글자판 · 채팅 제한(나이 확인 등)이 걸린 사람에게 뜨는 안내를 Roblox가 맡는다 — 우리가 따라 만들 것이 없다.
--  공식 문서(create.roblox.com/docs/chat/in-experience-text-chat · chat-window · reference의 ChatWindowConfiguration · ChatInputBarConfiguration · ChannelTabsConfiguration)에서 확인한 것:
--    · 기본 화면은 셋: 채팅 창(ChatWindowConfiguration) · 입력줄(ChatInputBarConfiguration) · 채널 탭(ChannelTabsConfiguration — 기본은 꺼져 있다). Enabled를 끄면 그 부분이 숨는다.
--    · 창의 자리는 HorizontalAlignment(기본 Left) · VerticalAlignment(기본 Top), 크기는 WidthScale · HeightScale, 모습은 BackgroundColor3 · BackgroundTransparency · TextColor3 · TextSize · FontFace.
--    · 입력줄은 그것을 누르거나 KeyboardKeyCode(기본 Slash — 「/」)로 연다. 폰에서는 화면 위의 Roblox 채팅 단추로 창을 여닫는다.
--    · 채널 탭을 켜면 RBXGeneral이 「General」 탭이 되고, 따로 만든 TextChannel은 그 Name으로 탭이 생긴다 — 우리의 「파티」 채널.
--    · 글의 앞머리(이름)는 TextChatService.OnIncomingMessage에서 TextChatMessageProperties.PrefixText로 바꾼다(글자색 꼬리표를 쓸 수 있다).
--    · 알림 글은 TextChannel:DisplaySystemMessage(그 사람의 화면에만 뜬다).
--    · 창 · 입력줄의 화면에서의 자리는 AbsolutePosition · AbsoluteSize로 읽는다(문서의 본보기 「Get Total Chat UI Bounds」) · 글을 치는 중인지는 ChatInputBarConfiguration.IsFocused.
--  누구에게 가는지는 그대로 서버가 정한다(server/lune/modules/chat.luau): 둘레(RBXGeneral) = 같은 맵의 사람 · 「파티」 = 같은 파티.
--  여기서 하는 일: ① 기본 창 · 입력줄 · 채널 탭을 켜고 게임의 색에 맞춘다(data/ui.generated.luau의 chatUi) ② 이름을 그 사람의 캐릭터 이름으로(Roblox의 이름을 쓰지 않는다 — 사용자 2026-10-10)
--                 ③ 글을 치는 동안 게임의 키를 받지 않게 알려 준다(Chat.focused) ④ 창이 차지한 자리의 아래 끝을 알려 준다(Chat.bottom — PC에서 파티원 칸을 그 아래로 내린다)
--  Roblox 캐릭터가 없는 게임이라(2D 화면) 머리 위 말풍선은 뜨지 않는다.
--  확인하지 못한 것: 실제 화면에서의 모습(Play를 하지 않았다). 속성은 모두 문서에 있는 것이고, 하나가 안 먹어도 나머지와 게임은 그대로 돈다(pcall).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Stage = require(script.Parent.stage)

local K = UI.chatUi -- 공방 js/lune/design/ui.js의 CHATUI

local Chat = {}
Chat.bottom = 0 -- Roblox 채팅 화면(창 + 입력줄)의 아래 끝 — 화면 틀의 점(위에서부터). 아직 모르면 0
Chat.onMoved = nil :: (() -> ())? -- 그 자리가 바뀌었을 때(boot가 파티원 칸을 다시 놓는다)

local window: Instance? = nil
local bar: Instance? = nil

local function config(class: string): Instance?
	local found = TextChatService:FindFirstChildOfClass(class)
	if found then
		return found
	end
	-- 설정들은 TextChatService 바로 아래나 그 아래의 묶음에 있다
	for _, d in TextChatService:GetDescendants() do
		if d.ClassName == class then
			return d
		end
	end
	return nil
end

local function color(hex: string): Color3
	return Color3.fromHex(hex)
end

-- 속성 하나를 건다(그 속성이 없거나 막혀 있어도 나머지는 그대로 건다).
--  값이 없으면(자료에 그 값이 없다) 걸지 않는다 — 2026-10-13: 자료에서 뺀 값(stroke)을 걸려던 줄이 남아, nil을 수 속성에 넣다가
--  Studio의 Output에 "value of type nil cannot be converted to a number"가 떴다(pcall 안이라 게임은 그대로 돌았다). 걸어야 하는 값이 다 걸리는지는 테스트 40이 본다
local function set(target: Instance?, key: string, value: any)
	if value == nil then
		warn("[lune] 채팅: 걸 값이 자료(ui.generated의 chatUi)에 없다 — " .. key)
		return
	end
	if target then
		pcall(function()
			(target :: any)[key] = value
		end)
	end
end

-- 글에 넣는 이름: 글자 꾸밈 꼬리표로 읽히지 않게
local function plain(text: string): string
	return (text:gsub("[&<>\"']", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }))
end
Chat.plain = plain

-- 그 글의 앞머리: 「[파티] 이름:」 — 이름은 그 사람이 하고 있는 캐릭터의 이름(서버가 사람에게 적어 둔 LuneName). 아직 캐릭터를 고르지 않은 사람이면 nil(Roblox의 기본 앞머리 그대로)
function Chat.prefix(charName: any, party: boolean): string?
	if typeof(charName) ~= "string" or charName == "" then
		return nil
	end
	local head = if party then ("<font color='%s'>%s</font> "):format(K.party.color, plain(require(game:GetService("ReplicatedStorage").shared.lune.lang).t(K.party.tag))) else "" -- (꼬리표는 영문으로 — 이름은 그대로)
	return ("%s<font color='%s'>%s:</font>"):format(head, if party then K.party.color else K.nameColor, plain(charName))
end

-- 입력줄에 글을 치는 중인가(그동안 게임의 키를 받지 않는다 — input.luau)
function Chat.focused(): boolean
	local ok, on = pcall(function()
		return bar ~= nil and (bar :: any).IsFocused == true
	end)
	return ok and on == true
end

-- 알림 글(내 화면에만 뜬다)
function Chat.note(text: string)
	task.spawn(function()
		pcall(function()
			local channels = TextChatService:WaitForChild("TextChannels", 5)
			local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
			if channel then
				(channel :: any):DisplaySystemMessage(require(game:GetService("ReplicatedStorage").shared.lune.lang).t(text)) -- (영문 — 2026-10-27)
			end
		end)
	end)
end

-- 채팅 화면이 차지한 자리의 아래 끝을 다시 잰다(창과 입력줄을 합친 네모 — 문서의 본보기와 같은 법). 화면 틀의 점으로
local function measure()
	local ok, y = pcall(function()
		local low = 0
		for _, c in { window, bar } do
			if c and (c :: any).Enabled then
				local pos, size = (c :: any).AbsolutePosition, (c :: any).AbsoluteSize
				if size.Y > 0 then
					low = math.max(low, pos.Y + size.Y)
				end
			end
		end
		if low <= 0 or not Stage.ui then
			return 0
		end
		return math.max(0, math.ceil((low - Stage.ui.AbsolutePosition.Y) / Stage.uiScale))
	end)
	local now = if ok then y else 0
	if now ~= Chat.bottom then
		Chat.bottom = now
		if Chat.onMoved then
			Chat.onMoved()
		end
	end
end
Chat.measure = measure

function Chat.init()
	window = config("ChatWindowConfiguration")
	bar = config("ChatInputBarConfiguration")
	local tabs = config("ChannelTabsConfiguration")

	-- ① 기본 화면을 켜고 게임의 색에 맞춘다
	local W = K.window
	set(window, "Enabled", true)
	set(window, "BackgroundColor3", color(W.back))
	set(window, "BackgroundTransparency", W.alpha)
	set(window, "TextColor3", color(W.text))
	set(window, "WidthScale", W.width)
	set(window, "HeightScale", W.height)
	set(bar, "Enabled", true)
	set(bar, "BackgroundColor3", color(W.back))
	set(bar, "BackgroundTransparency", W.alpha)
	set(bar, "TextColor3", color(W.text))
	set(bar, "PlaceholderColor3", color(W.dim))
	-- 채널 탭: 「General」(둘레 — 같은 맵) · 「파티」
	set(tabs, "Enabled", K.tabs)
	set(tabs, "BackgroundColor3", color(W.back))
	set(tabs, "BackgroundTransparency", W.alpha)
	set(tabs, "TextColor3", color(W.dim))
	set(tabs, "SelectedTabTextColor3", color(K.nameColor))

	-- ② 이름은 캐릭터의 이름으로(이 함수는 기다리지 않는다 — 문서: 콜백은 멈추지 않아야 한다)
	pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local props = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			if source then
				local player = Players:GetPlayerByUserId(source.UserId)
				local channel = message.TextChannel
				local prefix = Chat.prefix(if player then player:GetAttribute("LuneName") else nil, channel ~= nil and channel.Name == K.party.channel)
				if prefix then
					props.PrefixText = prefix
				end
			end
			return props
		end
	end)

	-- ④ 창이 차지한 자리(바뀔 때마다 다시 잰다 — 창 크기 · 창을 여닫을 때)
	for _, c in { window, bar } do
		if c then
			pcall(function()
				c:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
				c:GetPropertyChangedSignal("AbsolutePosition"):Connect(measure)
				c:GetPropertyChangedSignal("Enabled"):Connect(measure)
			end)
		end
	end
	Stage.onResize(measure)
	task.delay(2, measure) -- 채팅 화면이 뜬 뒤(문서의 본보기도 잠깐 기다렸다가 잰다)
	measure()
end

return Chat
