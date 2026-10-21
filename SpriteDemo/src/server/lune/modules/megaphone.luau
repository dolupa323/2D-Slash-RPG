-- 확성기(관리자 — 2026-10-21 사용자: "로블록스는 서버가 여러개가 돌아가는 구조잖아 내가 모든 서버에 확성기로 말할수있나? 어드민기능으로 확성기같은게 필요한데").
--  관리 창(메뉴 → 「관리」 → 「계정」)의 「확성기」 칸에 적고 「보내기」 → 이 서버가 글을 거른 뒤(Roblox의 TextService — 다른 사람에게 보이는 글은 반드시 거른다)
--  이 서버의 모두에게 바로 띄우고, MessagingService로 지금 돌아가는 다른 모든 서버에 보낸다 → 각 서버가 그 서버의 모두에게(화면 위 큰 알림 「공지」 + 채팅 알림 글).
--  보낸 서버도 MessagingService의 소식을 받는다 — 소식마다 번호(id)를 붙여, 이미 띄운 것은 다시 띄우지 않는다.
--  관리자인지는 부르는 쪽(world.luau onAdmin)이 계정 번호로 가린다.
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local Megaphone = {}
Megaphone.TOPIC = "LuneMegaphone"
Megaphone.MAX = 80 -- 보낼 수 있는 글자 수(채팅에는 다 보이고 · 큰 알림에는 두 줄까지)
Megaphone.GAP = 5 -- 한 번 보낸 뒤 다음을 보낼 수 있을 때까지(초)

local deliver: (string) -> () = function() end
local seen, order = {}, {} -- 이미 띄운 소식의 번호(가장 최근 50개)
local lastAt = -math.huge

local function remember(id: string)
	seen[id] = true
	table.insert(order, id)
	while #order > 50 do
		seen[table.remove(order, 1)] = nil
	end
end

-- 듣기 시작한다. fn(글) = 이 서버의 모두에게 띄운다
function Megaphone.start(fn: (string) -> ())
	deliver = fn
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(Megaphone.TOPIC, function(msg)
				local d = msg and msg.Data
				if typeof(d) == "table" and typeof(d.id) == "string" and typeof(d.text) == "string" and not seen[d.id] then
					remember(d.id)
					deliver(d.text)
				end
			end)
		end)
	end)
end

-- 적은 글 → 보낼 글(앞뒤 빈칸을 빼고 줄바꿈 · 탭은 빈칸으로) 또는 nil과 까닭
function Megaphone.clean(text: any): (string?, string?)
	if typeof(text) ~= "string" then
		return nil, "보낼 글을 적어 주세요"
	end
	text = string.gsub(text, "[\t\r\n]", " ")
	text = string.gsub(text, "^ +", "")
	text = string.gsub(text, " +$", "")
	if text == "" then
		return nil, "보낼 글을 적어 주세요"
	end
	local n = utf8.len(text)
	if not n then
		return nil, "글자가 깨졌다 — 다시 적어 주세요"
	end
	if n > Megaphone.MAX then
		return nil, ("%d자까지 보낸다(지금 %d자)"):format(Megaphone.MAX, n)
	end
	return text, nil
end

-- 보낸다: player = 보내는 관리자 · now = 지금(초). 돌려주는 것: 됐는가 · 알릴 글
function Megaphone.send(player, text: any, now: number): (boolean, string)
	local clean, why = Megaphone.clean(text)
	if not clean then
		return false, why :: string
	end
	if now - lastAt < Megaphone.GAP then
		return false, ("%d초 뒤에 다시 보낼 수 있다"):format(math.ceil(Megaphone.GAP - (now - lastAt)))
	end
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(clean, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(filtered) ~= "string" or filtered == "" then
		return false, "글을 거르지 못했다 — 다시 보내 주세요"
	end
	lastAt = now
	local id = HttpService:GenerateGUID(false)
	remember(id)
	deliver(filtered) -- 이 서버는 바로
	local sent = pcall(function()
		MessagingService:PublishAsync(Megaphone.TOPIC, { id = id, text = filtered })
	end)
	return true, if sent then "모든 서버에 보냈다" else "이 서버에만 띄웠다(다른 서버로 보내지 못했다 — 잠시 뒤에 다시)"
end

return Megaphone
