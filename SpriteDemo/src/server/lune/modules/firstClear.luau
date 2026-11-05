-- 보스의 최초 격파(2026-11-05 사용자: "퍼클 이벤트도 들어가야해 최초 격파 3 파티까지야 3인이 아니고 3파티 퍼클 칭호 깨자마자 바로 지급되어야하고,
--  전 서버에 메시지 송출된다 누구,누구, 누구가 잡았다고"). 만렙 최초 달성(firstMax.luau)과 같은 길:
--  ① 어느 서버에서든 그 보스(공방 design/weekboss.js의 first — 지금은 용암 거인)를 격파하면 world.luau가 그 방의 사람들로 claim을 부른다 →
--     저장소의 세계 기록(store.luau firstClearAdd — UpdateAsync)에 파티를 더해 본다(first.parties 파티까지 · 이미 기록에 있는 사람이 섞인 파티는 아니다 — sim/firstClear.luau).
--  ② 자리를 얻으면 그 자리에서 칭호(achieve.js TITLES의 rule firstClear)를 주고(world.luau의 onRank) · 이 서버의 모두에게 바로 알리고 · MessagingService로 다른 모든 서버에 보낸다
--     → 서버마다 그 서버의 모두에게 화면 위 큰 알림 「최초 격파 1/3 — 용암 거인」 + 이름들 · 채팅 알림 글.
--  ③ 기록은 서버가 켜질 때 읽어 둔다 — 칭호를 주고 빼는 셈(titles.luau의 grant)이 본다.
--  시험(Studio): 저장소에 적지 않고 이 서버의 기억에만(관리자 · 퍼블리시하지 않는 보스도 — Studio Play에서 알림 · 칭호를 볼 수 있게) · 다른 서버로 보내지 않는다.
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FirstClear = require(ReplicatedStorage.shared.lune.sim.firstClear)
local Weekly = require(ReplicatedStorage.shared.lune.sim.weekly)
local Store = require(script.Parent.store)

local FC = {}
FC.TOPIC = "LuneFirstClear"
FC.RETRY = 10 -- 적지 못했을 때 다시 해 보기까지(초)
FC.TRIES = 6 -- 한 격파에 적어 보는 번(저장소 탈 — 한 분쯤)

local records = {} -- [보스] = 목록(읽었다) · nil(아직 못 읽었다)
local deliver: (any) -> () = function() end
local seen, order = {}, {} -- 이미 띄운 소식의 번호(MessagingService는 보낸 서버에도 온다)

local function remember(id: string)
	seen[id] = true
	table.insert(order, id)
	while #order > 50 do
		seen[table.remove(order, 1)] = nil
	end
end

-- 최초 격파가 있는 보스들
local function bosses(): { any }
	local out = {}
	for _, b in Weekly.DATA.bosses do
		if b.first then
			table.insert(out, b)
		end
	end
	return out
end

local function load(b)
	task.spawn(function()
		local ok, got, list = pcall(Store.firstClearGet, b.id)
		if ok and got and typeof(list) == "table" then
			records[b.id] = list
		end
	end)
end

-- 듣기 시작한다(서버가 켜질 때 한 번). fn(소식 { boss, n, max, names, id }) = 이 서버의 모두에게 알린다
function FC.start(fn: (any) -> ())
	deliver = fn
	for _, b in bosses() do
		load(b)
	end
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(FC.TOPIC, function(msg)
				local d = msg and msg.Data
				if typeof(d) == "table" and typeof(d.id) == "string" and typeof(d.boss) == "string" and not seen[d.id] then
					remember(d.id)
					if Weekly.boss(d.boss) then
						load(Weekly.boss(d.boss)) -- 기록을 다시 읽는다(칭호의 셈이 본다)
					end
					deliver(d)
				end
			end)
		end)
	end)
end

-- 지금 아는 그 보스의 기록(못 읽었으면 nil)
function FC.get(boss: string)
	return records[boss]
end

-- 격파한 파티를 적어 본다. entry = { at, members = { { key, name, class } … } } · test = 시험(Studio — 기억에만) ·
--  onRank(차례, 기록) = 자리를 얻었다(칭호를 준다 — world.luau). 알림은 여기서 이 서버와 다른 서버에.
function FC.claim(b, entry, test: boolean, onRank: (number, any) -> ())
	if not b.first or not FirstClear.valid(entry) then
		return
	end
	local cap = b.first.parties
	local function won(rank: number)
		onRank(rank, entry)
		local news = { id = ("%s-%d-%d"):format(b.id, os.time(), math.random(1, 1e9)), boss = b.id, n = rank, max = cap, names = FirstClear.names(entry), test = test or nil }
		remember(news.id)
		deliver(news) -- 이 서버는 바로
		if not test then
			pcall(function()
				MessagingService:PublishAsync(FC.TOPIC, news)
			end)
		end
	end
	if test then
		local new, rank = FirstClear.add(records[b.id], entry, cap)
		if new and rank then
			records[b.id] = new
			won(rank)
		end
		return
	end
	task.spawn(function()
		for _ = 1, FC.TRIES do
			local ok, rank, have = pcall(Store.firstClearAdd, b.id, entry, cap)
			if ok and have ~= nil then
				records[b.id] = have
				if rank then
					won(rank)
				end
				return -- (자리를 얻었거나 · 다 찼거나 · 이미 기록에 있는 사람이 섞였다)
			end
			task.wait(FC.RETRY)
		end
	end)
end

-- (자동 검사: 기록을 비운다 · 넣는다)
function FC.reset(list)
	records = list or {}
	seen, order = {}, {}
end

return FC
