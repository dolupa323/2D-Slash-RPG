-- 관리자의 즉시 조치 · 모든 서버의 접속자(2026-11-12 사용자: "매크로 점수 내가 같은서버인유저밖에 못봐 모든유저를 확인하고 즉시 경고메시지보내고 이렇게 할수있어야해
--  경험치 쿠폰도 지급할수있어야하고 제재도 즉시할수있어야하고 깜빵에 바로 넣을수도있어야하고 날파리를 날릴수도 있어야해" · "룬의 저주 걸려있는사람 내가 풀어줄수있는기능도 있어야하고").
--  ① 모든 서버의 접속자: MemoryStore 정렬 지도 LuneOnline_v1(열쇠 = UserId · 정렬 = 종합 점수) — 서버마다 PUSH초에 한 번 제 사람들을 적는다 · TTL초 지나면 저절로 사라진다(꺼진 서버의 사람)
--     관리 창 「매크로 → 모든 서버」가 점수 높은 차례로 읽는다. MemoryStore를 못 쓰면(Studio · 장애) 부르는 쪽이 이 서버의 사람만 보인다.
--  ② 조치(warn 경고 · jail 감옥(a = 분) · unjail 풀기 · fly 날파리 · uncurse 룬의 저주 풀기): 그 사람이 이 서버에 있으면 world.luau가 바로 한다 ·
--     아니면 DataStore 상자(store.luau Store.adminQAdd — admq_<UserId>)에 적고 모든 서버에 알린다(MessagingService LuneAdminCmd) →
--     그 사람이 있는 서버가 상자를 꺼내 바로 한다(World.adminDrain) · 접속하지 않았으면 다음에 들어올 때. 날파리는 FLY_TTL초 안에 못 하면 버린다(들어오자마자 날파리는 이상하다).
--  경험치 쿠폰은 선물 상자(gifts.luau)로 · 정지는 정지 탭과 같은 길(ban.luau — Roblox BanAsync가 모든 서버에서 바로 내보낸다). 관리자인지는 부르는 쪽(world.luau onAdmin)이 본다.
--  [제가 정한 것] PUSH 30 · TTL 120 · 읽는 수 200 · FLY_TTL 120
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local Store = require(script.Parent.store)

local AdminCmd = {}
AdminCmd.TOPIC = "LuneAdminCmd"
AdminCmd.MAP = "LuneOnline_v1"
AdminCmd.PUSH, AdminCmd.TTL, AdminCmd.READ, AdminCmd.FLY_TTL = 30, 120, 200, 120

local map: any = nil
local mapFailed = false
local function sm()
	if map or mapFailed then
		return map
	end
	local ok, m = pcall(function()
		return MemoryStoreService:GetSortedMap(AdminCmd.MAP)
	end)
	if ok and m then
		map = m
	else
		mapFailed = true
	end
	return map
end

-- 이 서버의 사람들을 적는다(rows = { { uid, info, score } … }) — 서버의 틱 밖에서(task.spawn) 부른다
function AdminCmd.publish(rows)
	local m = sm()
	if not m then
		return
	end
	for _, r in rows do
		pcall(function()
			m:SetAsync(tostring(r.uid), r.info, AdminCmd.TTL, math.floor(r.score or 0))
		end)
	end
end
-- 나갔다
function AdminCmd.gone(uid: number)
	local m = sm()
	if m then
		pcall(function()
			m:RemoveAsync(tostring(uid))
		end)
	end
end
-- 모든 서버의 접속자(점수 높은 차례) → { { uid, …info } … } 또는 nil(읽지 못했다)
function AdminCmd.list(): { any }?
	local m = sm()
	if not m then
		return nil
	end
	local ok, items = pcall(function()
		return m:GetRangeAsync(Enum.SortDirection.Descending, AdminCmd.READ)
	end)
	if not ok or typeof(items) ~= "table" then
		return nil
	end
	local out = {}
	for _, it in items do
		local v = it.value
		if typeof(v) == "table" then
			local row = table.clone(v)
			row.uid = tonumber(it.key)
			table.insert(out, row)
		end
	end
	return out
end

-- 다른 서버에 있거나 접속하지 않은 사람에게: 상자에 적고 모든 서버에 알린다 → 적었는가
function AdminCmd.queue(uid: number, k: string, a: number?, by: number): boolean
	local okId, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	local id = if okId and typeof(guid) == "string" then guid else ("%d-%d"):format(os.time(), math.random(1, 1e9))
	local ok = Store.adminQAdd and Store.adminQAdd(uid, { id = id, k = k, a = a, t = os.time(), by = by })
	if not ok then
		return false
	end
	pcall(function()
		MessagingService:PublishAsync(AdminCmd.TOPIC, { uid = uid })
	end)
	return true
end
-- 그 사람의 상자를 꺼낸다(그 사람이 이 서버에 있을 때) → 할 일들(날파리는 FLY_TTL초 지난 것을 버린다)
function AdminCmd.take(uid: number, now: number): { any }
	if not Store.adminQTake then
		return {}
	end
	local ok, list = Store.adminQTake(uid)
	if not ok then
		return {}
	end
	local out = {}
	for _, e in list do
		if not (e.k == "fly" and now - e.t > AdminCmd.FLY_TTL) then
			table.insert(out, e)
		end
	end
	return out
end
-- 듣기 시작한다(서버가 켜질 때 한 번): onPing(UserId) = 그 사람이 이 서버에 있으면 상자를 꺼내 한다
function AdminCmd.start(onPing: (number) -> ())
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(AdminCmd.TOPIC, function(msg)
				local d = msg and msg.Data
				if typeof(d) == "table" and typeof(d.uid) == "number" then
					onPing(d.uid)
				end
			end)
		end)
	end)
end

return AdminCmd
