-- 만렙 최초 달성(2026-10-24 사용자: "150만렙 맨 처음 찍는 유저 나타나면 바로 전서버에 축하알림뜨면서 레벨 랭킹 1위 실시간 박제되게 이벤트 만들고").
--  ① 어느 서버에서든 캐릭터가 만렙(N.MAX_LEVEL = 150)에 오르면 저장소의 세계 기록(store.luau의 firstMax — UpdateAsync)에 적어 본다. 비어 있을 때만 적혀서 한 사람만 남는다.
--  ② 내가 처음이면 이 서버의 모두에게 바로 알리고, MessagingService로 지금 돌아가는 다른 모든 서버에 보낸다 → 서버마다 그 서버의 모두에게 축하 알림.
--  ③ 기록은 그 뒤로 레벨 순위판의 1위에 고정된다(world.luau의 rankBoards — Rank.pinFirst). 서버가 켜질 때 저장소에서 읽어 두고, 알림을 받으면 바로 바꾼다.
--  관리자 · 확인용 임시 계정 · 시험 봇의 캐릭터는 적지 않는다(명예의 전당과 같다 — 부르는 쪽 world.luau가 가린다).
local MessagingService = game:GetService("MessagingService")
local Store = require(script.Parent.store)

local FirstMax = {}
FirstMax.TOPIC = "LuneFirstMax"
FirstMax.RETRY = 60 -- 적지 못했을 때(저장소 탈) 다시 해 보기까지(초)

local record = nil -- { key, name, class, at } — 처음 만렙에 오른 캐릭터(없으면 nil)
local deliver: (any) -> () = function() end
local busy, failAt = false, -math.huge

local function valid(rec): boolean
	return typeof(rec) == "table" and typeof(rec.key) == "string" and typeof(rec.name) == "string" and rec.name ~= ""
end

-- 듣기 시작한다(서버가 켜질 때 한 번). fn(기록) = 이 서버의 모두에게 축하 알림 · 순위판을 다시 읽게 한다
function FirstMax.start(fn: (any) -> ())
	deliver = fn
	task.spawn(function()
		local ok, rec = pcall(Store.firstMaxGet)
		if ok and valid(rec) and not record then
			record = rec -- 이미 있던 기록(알림은 다시 띄우지 않는다 — 순위판에만)
		end
		pcall(function()
			MessagingService:SubscribeAsync(FirstMax.TOPIC, function(msg)
				local d = msg and msg.Data
				if valid(d) and not record then
					record = d
					deliver(d)
				end
			end)
		end)
	end)
end

-- 지금 아는 기록(없으면 nil)
function FirstMax.get()
	return record
end

-- 만렙에 오른 캐릭터를 적어 본다(이미 기록이 있거나 적는 중이면 아무것도 하지 않는다). rec = { key, name, class }
function FirstMax.try(rec, now: number)
	if record or busy or now - failAt < FirstMax.RETRY or not valid(rec) then
		return
	end
	busy = true
	task.spawn(function()
		local entry = { key = rec.key, name = rec.name, class = rec.class, at = os.time() }
		local ok, mine, have = pcall(Store.firstMaxClaim, entry)
		busy = false
		if not ok or mine == nil then
			failAt = now
			return
		end
		if mine then
			if record then
				return -- 그새 다른 서버의 알림이 먼저 왔다(같은 기록)
			end
			record = entry
			deliver(entry) -- 이 서버는 바로
			pcall(function()
				MessagingService:PublishAsync(FirstMax.TOPIC, entry)
			end)
		elseif valid(have) and not record then
			record = have -- 다른 서버에서 먼저 적혔다(그 서버가 알림을 보낸다)
		end
	end)
end

return FirstMax
