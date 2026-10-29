-- 관리자의 선물(2026-10-29 사용자: "나 어드민 호박사탕 지급 탭 만들어주고") — 관리 창 「이벤트」 탭이 부른다(world.luau의 onAdmin "candy").
--  닉네임 → 이름 장부의 계정 번호(정지 탭과 같은 길 — ban.luau Ban.find) → 이 서버에 그 캐릭터로 있으면 바로 가방에 ·
--  아니면 세계 기록 gift_<계정 번호>(store.luau Store.giftAdd)에 적어 두고 모든 서버에 알린다(MessagingService) →
--   지금 그 캐릭터로 있는 서버가 바로 꺼내 주고 · 접속하지 않았으면 다음에 그 캐릭터로 들어올 때 받는다(들어온 뒤 첫 1초 — world.luau의 사람마다의 일).
--  받는 사람에게는 화면 위 큰 알림 + 채팅(확성기와 같은 길 — 그 사람에게만). 가방이 모자라면 들어가는 만큼만 넣고 나머지는 상자에 남긴다(다음 접속에).
--  관리자인지는 부르는 쪽(world.luau onAdmin)이 계정 번호로 가린다. 이름 · 수 · 길은 모두 제가 정한 것
local MessagingService = game:GetService("MessagingService")
local Store = require(script.Parent.store)

local Gifts = {}
Gifts.TOPIC = "LuneGift"
Gifts.MAX = 9999 -- 한 번에 보내는 수(호박 사탕 한 묶음)
Gifts.WORDS = { got = "운영자의 선물 — {what}", kept = "가방이 모자라 남은 것은 다음 접속 때 받는다" } -- 받는 사람의 화면 위 큰 알림 · 채팅

local ping: (number) -> () = function() end

-- 듣기 시작한다. onPing(계정 번호) = 그 계정이 이 서버에 있으면 상자를 열어 본다
function Gifts.start(onPing: (number) -> ())
	ping = onPing
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(Gifts.TOPIC, function(msg)
				local d = msg and msg.Data
				if typeof(d) == "table" and typeof(d.uid) == "number" then
					ping(d.uid)
				end
			end)
		end)
	end)
end

-- 상자에 넣고 모든 서버에 알린다 → 상자에 적었는가 · 다른 서버에 알렸는가
function Gifts.send(uid: number, name: string, id: string, n: number, now: number): (boolean, boolean)
	local ok = Store.giftAdd(uid, { name = name, id = id, n = n, at = now })
	if not ok then
		return false, false
	end
	local told = pcall(function()
		MessagingService:PublishAsync(Gifts.TOPIC, { uid = uid })
	end)
	return true, told
end

-- 그 캐릭터의 선물을 꺼내 가방에 넣는다. give(id, n) → 넣은 수 · 돌려주는 것: { { id, n } … }(넣은 것 — 알림에 쓴다) · 남겨 둔 것이 있는가
function Gifts.take(uid: number, name: string, give: (string, number) -> number, now: number): ({ any }, boolean)
	if not Store.giftTake then
		return {}, false -- (저장소가 없다 — 자동 검사의 가짜 저장소)
	end
	local ok, list = Store.giftTake(uid, name)
	if not ok then
		return {}, false
	end
	local got, kept = {}, false
	for _, g in list do
		local put = give(g.id, g.n)
		if put > 0 then
			table.insert(got, { id = g.id, n = put })
		end
		if put < g.n then
			Store.giftAdd(uid, { name = name, id = g.id, n = g.n - put, at = g.at or now }) -- (가방이 모자랐다 — 다음 접속에)
			kept = true
		end
	end
	return got, kept
end

return Gifts
