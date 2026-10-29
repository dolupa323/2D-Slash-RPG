-- 「달의 계승자」 — 경매장을 여럿이 · 서버 둘에서 · 같은 때에 · 아무렇게나 써 본다(2026-10-27 사용자: "지금 경매장 버그있다는데 확인해봐 수령해야하는 물건을 못받는다거나 뭐 훔쳐갈수있다던가").
--  41_lune_market은 길마다 하나씩 고장을 내서 본다. 여기서는 그 길들을 섞는다: 네 사람이 서버 둘을 오가며 올리기 · 사기 · 대금 수령 · 반환 · 재등록 · 수령 · 모두 받기 · 나가기를
--  저장소가 느린 채로(같은 때에 겹친다) 아무 차례로 하고, 가끔 저장소가 쓰지 못하거나 · 써 놓고 답하지 않거나 · 읽지 못하게 한다.
--  끝에 모두가 받을 것을 다 받으면: 처음 나눠 준 물건이 하나도 늘거나 줄지 않았는가(복사 · 훔치기 · 사라짐) · 달돈이 생겨나지 않았는가 · 받지 못하고 남은 것이 없는가.
--  서버가 저장하지 못한 채 꺼지는 것은 넣지 않는다(41이 따로 본다 — 값을 치른 뒤 저장하기 전에 꺼지는 한 곳은 설계가 알고 둔 틈이다).
local function json(v)
	if typeof(v) ~= "table" then
		return v
	end
	local n = 0
	for _ in v do
		n += 1
	end
	local array = n > 0 and #v == n
	local out = {}
	for k, x in v do
		out[if array then k else tostring(k)] = json(x)
	end
	return out
end

local disk, boards, names = {}, {}, {}
local fail = { save = false, update = false :: any, read = false }
local SLOW = 0.4 -- 저장소의 한 번의 읽기 · 쓰기에 걸리는 시간(초) — 이 사이에 다른 사람의 일이 끼어든다
local function fakeStore()
	-- 로블록스의 GetAsync는 한 서버에서 4초 동안 같은 값(옛 값일 수 있다)을 준다 — UseCache = false(fresh)로 읽으면 지금의 값(공식 문서: data-stores/versioning-listing-and-caching)
	local cache = {}
	return {
		lock = function() return true end,
		unlock = function() end,
		loadAccount = function(id) return json(disk[id]) end,
		saveAccount = function(id, value)
			if fail.save then
				return false
			end
			disk[id] = json(value)
			return true
		end,
		loadOld = function() return nil end,
		nameOwner = function(key) return names[key] end,
		claimName = function(key, id)
			if names[key] ~= nil and names[key] ~= id then
				return false
			end
			names[key] = id
			return true
		end,
		freeName = function(key) names[key] = nil end,
		rankSet = function() end,
		rankRaise = function() end,
		rankRemove = function() end,
		rankTop = function() return {} end,
		rankInfoSet = function() end,
		rankInfoGet = function() return nil end,
		rankInfoRemove = function() end,
		isOffline = function() return false end,
		marketRead = function(key, fresh)
			task.wait(SLOW)
			if fail.read then
				return false, nil
			end
			local c = cache[key]
			if not fresh and c and clock.now - c.at < 4 then
				return true, json(c.v)
			end
			cache[key] = { at = clock.now, v = json(boards[key]) }
			return true, json(boards[key])
		end,
		marketUpdate = function(key, fn)
			task.wait(SLOW)
			if fail.update == "before" then
				return false, nil, nil, nil
			end
			local new, a, b = fn(json(boards[key]))
			if new ~= nil then
				boards[key] = json(new)
			end
			if fail.update == "after" then
				return false, nil, nil, nil
			end
			return true, a, b, json(boards[key])
		end,
	}
end

-- 서버 하나(모듈을 새로 읽는다 — 앞서 띄운 서버는 제 모듈을 쥔 채 그대로 돈다: 서버 둘이 같은 저장소를 같이 쓴다)
local function server()
	local keep = clock.now
	RESET()
	clock.now = keep
	local handlers = {}
	MOCK("ReplicatedStorage/shared/lune/net/net", {
		FireClient = function() end,
		OnServer = function(name, fn)
			handlers[name] = fn
		end,
	})
	SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
	local function signal()
		return { Connect = function() end }
	end
	SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
	SERVICE("RunService", { Heartbeat = signal() })
	SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
	MOCK("ServerScriptService/server/lune/modules/store", fakeStore())
	local sv = { World = req("ServerScriptService/server/lune/modules/world"), h = handlers }
	sv.World.start()
	return sv
end

local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local M = Items.data.MARKET
local potion, other = Items.potionFor(1), Items.potionFor(30)

-- 가방 속의 것을 센다: 장비는 생김새(부위 · 단계 · 성능 · 별 · 직업)마다 · 묶음은 이름표마다
local function countBag(h, into)
	for i = 1, Bag.size(h) do
		local g = h.gear[i]
		if g then
			local key = ("%s/%d/%d/%d/%s"):format(g.slot, g.stage, g.q, g.star, tostring(g.who))
			into[key] = (into[key] or 0) + 1
		end
		for _, tab in { "use", "etc" } do
			local s = h[tab][i]
			if s then
				into[s.item] = (into[s.item] or 0) + s.n
			end
		end
	end
	return into
end

local function runSeed(seed: number, steps: number)
	table.clear(disk)
	table.clear(boards)
	table.clear(names)
	fail.save, fail.update, fail.read = false, false, false
	local rng = Random.new(seed)
	local servers = { server(), server() }
	local USERS = 4
	local users = {}
	local stats = { list = 0, buy = 0, gross = 0, relist = 0, ok = 0, calls = 0, errors = 0 }
	local initial, moneyStart = {}, 0

	local function join(u, k: number)
		local sv = servers[k]
		local p = { UserId = u.id, Name = "user" .. u.id, DisplayName = "user" .. u.id, attrs = {} }
		p.SetAttribute = function(self, key, v) self.attrs[key] = v end
		p.Kick = function() end
		local r = sv.h.Ready(p)
		local cid = r and r.select and r.select.chars[1] and r.select.chars[1].id
		if not cid then
			local made = sv.h.Chars(p, "create", u.name, u.class)
			cid = made and made.id
		end
		sv.h.Chars(p, "enter", cid)
		local s = sv.World.session(p)
		s.scene = "town"
		u.p, u.sv, u.s, u.at = p, sv, s, k
	end
	local function leave(u)
		local sv, p = u.sv, u.p
		u.p, u.sv, u.s = nil, nil, nil
		u.leaving = true
		task.spawn(function()
			sv.World.removePlayer(p)
			u.leaving = false
		end)
	end
	-- 경매장에 부탁한다(같은 때에 여럿이 — 저장소를 기다리는 사이에 다른 일이 끼어든다)
	local function ask(u, action: string, a: any, b: any, c: any, d: any, after: ((any) -> ())?)
		local sv, p = u.sv, u.p
		if not sv or not p then
			return -- (그 사이에 나갔다)
		end
		stats.calls += 1
		task.spawn(function()
			local ok, res = pcall(sv.h.Market, p, action, a, b, c, d)
			if not ok then
				stats.errors += 1
				expect(false, ("경매장의 처리가 오류 없이 끝난다(%s) — %s"):format(action, tostring(res)))
				return
			end
			if res and res.ok then
				stats.ok += 1
			end
			if after then
				after(res)
			end
		end)
	end

	-- 처음: 사람마다 장비 셋(생김새가 모두 다르다) · 물약 둘 · 달돈
	for i = 1, USERS do
		local u = { id = 9500 + seed * 10 + i, name = "경매" .. ({ "가람", "나래", "다솜", "라온" })[i], class = CLASSES.order[(i - 1) % #CLASSES.order + 1], busyUntil = 0 }
		users[i] = u
		join(u, (i % 2) + 1)
		local h = u.s.hero
		for t = 1, Bag.size(h) do
			h.gear[t], h.use[t], h.etc[t] = false, false, false
		end
		h.money = 100000
		Bag.add(h, Items.make("weapon", 10, 3, u.class))
		local hat = Items.make("hat", 20, 2)
		hat.star = i
		Bag.add(h, hat)
		local shoes = Items.make("shoes", 30, 4)
		shoes.star = i + 4
		Bag.add(h, shoes)
		Bag.give(h, potion.id, 30)
		Bag.give(h, other.id, 12)
		moneyStart += h.money
		countBag(h, initial)
	end

	local function pickBag(h)
		local opts = {}
		for t = 1, Bag.size(h) do
			if h.gear[t] then
				table.insert(opts, { "gear", t })
			end
			if h.use[t] then
				table.insert(opts, { "use", t })
			end
		end
		return if #opts > 0 then opts[rng:NextInteger(1, #opts)] else nil
	end
	local function boardsFor(u)
		local list = { "u", "a_hat", "a_shoes" }
		for _, id in CLASSES.order do
			table.insert(list, "w_" .. id)
		end
		return list
	end

	for step = 1, steps do
		-- 저장소의 고장을 가끔(한 걸음 동안). 저장하지 못하는 고장은 나가는 사람이 없을 때만(나가며 저장하지 못하는 것 = 꺼지는 것 — 여기서는 보지 않는다)
		local roll = rng:NextNumber()
		local anyLeaving = false
		for _, u in users do
			anyLeaving = anyLeaving or u.leaving == true
		end
		fail.update = if roll < 0.04 then "before" elseif roll < 0.08 then "after" else false
		fail.read = roll >= 0.08 and roll < 0.11
		fail.save = roll >= 0.11 and roll < 0.14 and not anyLeaving
		for _ = 1, rng:NextInteger(1, 3) do
			local u = users[rng:NextInteger(1, USERS)]
			if not u.p then
				if not u.leaving and not fail.save then
					join(u, rng:NextInteger(1, 2))
				end
			else
				local h = u.s.hero
				local r = rng:NextNumber()
				if r < 0.28 then
					local pick = pickBag(h)
					if pick then
						local held = h[pick[1]][pick[2]]
						local n = if pick[1] == "gear" then nil else rng:NextInteger(1, held.n)
						ask(u, "list", pick[1], pick[2], n, { rng:NextInteger(1, 60), M.hours[1] }, function(res)
							if res and res.ok then
								stats.list += 1
							end
						end)
					end
				elseif r < 0.55 then
					local list = boardsFor(u)
					local board = list[rng:NextInteger(1, #list)]
					ask(u, "browse", board, rng:NextNumber() < 0.3, nil, nil, function(res)
						local rows = res and res.rows or {}
						local mine = u.p and u.sv and u.sv.World.session(u.p)
						if #rows > 0 and mine then
							local row = rows[rng:NextInteger(1, #rows)]
							local c = rng:NextInteger(1, row.l)
							-- 본 뒤에 바로 산다(그 사이에 다른 사람이 사거나 닫았을 수 있다)
							ask(u, "buy", board, row.id, c, row.p, function(res2)
								if res2 and res2.ok then
									stats.buy += 1
									stats.gross += row.p * c
								end
							end)
						end
					end)
				elseif r < 0.8 then
					ask(u, "mine", rng:NextNumber() < 0.3, nil, nil, nil, function(res)
						local mine = res and res.mine or {}
						if #mine > 0 and u.p then
							local m = mine[rng:NextInteger(1, #mine)]
							local whats = { "take", "collect", "back", "relist" }
							local what = whats[rng:NextInteger(1, #whats)]
							ask(u, "settle", m.id, what, nil, nil, function(res2)
								if res2 and res2.ok and what == "relist" then
									stats.relist += 1
								end
							end)
						end
					end)
				elseif r < 0.9 then
					ask(u, "all")
				elseif r < 0.95 then
					if not fail.save then
						leave(u)
					end
				else
					-- 하루가 넘게 지난다(올린 것의 기간이 끝난다)
					advance(rng:NextInteger(1, 26) * 3600)
				end
			end
		end
		advance(rng:NextNumber(0.1, 1.5))
		fail.save, fail.update, fail.read = false, false, false
	end

	-- 끝: 고장 없이 모두 마친다 — 판매 중인 것은 반환하고, 받을 것은 다 받는다(여러 번 — 저장소를 기다린다)
	advance(5)
	for _, u in users do
		if u.leaving then
			advance(5)
		end
		if not u.p then
			join(u, 1)
		end
	end
	for _ = 1, 6 do
		for _, u in users do
			ask(u, "mine", true, nil, nil, nil, function(res)
				for _, m in (res and res.mine) or {} do
					if m.state == "selling" then
						ask(u, "settle", m.id, "back")
					end
				end
			end)
			advance(3)
			ask(u, "all")
			advance(12) -- (새로 고침의 10초 한도를 넘긴다)
		end
	end
	-- 남은 것이 없다 · 모두 나가 저장한 뒤 새 서버에서 다시 읽어 센다
	for _, u in users do
		local left = 0
		for _ in u.s.acct.market.list do
			left += 1
		end
		eq(left, 0, ("[seed %d] 받을 것을 다 받았다 — %s의 맡긴 것"):format(seed, u.name))
		leave(u)
	end
	advance(10)
	local final, moneyEnd = {}, 0
	local sv3 = server()
	servers[3] = sv3
	for _, u in users do
		join(u, 3)
		countBag(u.s.hero, final)
		moneyEnd += u.s.hero.money
	end
	-- 물건이 하나도 늘거나 줄지 않았다
	for key, n in initial do
		eq(final[key] or 0, n, ("[seed %d] 물건이 그대로다 — %s"):format(seed, key))
	end
	for key, n in final do
		if initial[key] == nil then
			expect(false, ("[seed %d] 처음에 없던 물건이 생겼다 — %s x%d"):format(seed, key, n))
		end
	end
	-- 달돈은 생겨나지 않는다(수수료 · 돌려받지 못한 보증금만큼 줄 수는 있다 — 그보다 더 줄면 누군가 받지 못한 것)
	local lostMost = math.ceil(stats.gross * M.fee / 100) + (stats.list + stats.relist) * M.deposit
	expect(moneyEnd <= moneyStart, ("[seed %d] 달돈이 생겨나지 않는다 (%d → %d)"):format(seed, moneyStart, moneyEnd))
	expect(moneyStart - moneyEnd <= lostMost, ("[seed %d] 달돈이 수수료 · 보증금보다 더 사라지지 않는다 (줄어든 것 %d · 많아야 %d)"):format(seed, moneyStart - moneyEnd, lostMost))
	-- 장부에 판매 중으로 남은 줄이 없다(판 사람이 반환했다)
	local now = 1700000000 + math.floor(clock.now)
	local selling = 0
	for _, doc in boards do
		for _, e in (doc.list or {}) do
			if e.l > 0 and e.c ~= 1 and now < e.e then
				selling += 1
			end
		end
	end
	eq(selling, 0, ("[seed %d] 판매 중으로 남은 줄이 없다"):format(seed))
	eq(stats.errors, 0, ("[seed %d] 처리 중 오류"):format(seed))
	expect(stats.buy >= 3 and stats.list >= 5, ("[seed %d] 실제로 많이 사고팔았다(올림 %d · 삼 %d · 다시 올림 %d · 부탁 %d · 된 것 %d)"):format(seed, stats.list, stats.buy, stats.relist, stats.calls, stats.ok))
	for _, u in users do
		leave(u)
	end
	advance(10)
	return stats
end

local total = { list = 0, buy = 0, relist = 0, calls = 0 }
for seed = 1, 4 do -- (씨앗 넷 · 걸음 220 — 2026-10-27 일부러 넣은 고장(판 사람이 받을 대금이 줄어드는 셈)을 씨앗마다 잡았다)
	local st = runSeed(seed, 220)
	total.list += st.list
	total.buy += st.buy
	total.relist += st.relist
	total.calls += st.calls
end
print(("  [경매장 무작위] 올림 %d · 삼 %d · 다시 올림 %d · 부탁 %d"):format(total.list, total.buy, total.relist, total.calls))

-- 정해진 차례로 한 번 더(2026-10-27 — 위의 무작위가 잡은 것): 산 사람이 장부를 읽어 둔 직후(로블록스의 4초 캐시에 옛 장부) 사는데,
--  사는 쓰기는 장부에 적혔지만 답이 오지 않는다 → 서버가 다시 읽어 「적혔는가」를 본다. 옛 값을 읽으면 「못 샀다」로 돈을 돌려주고 물건은 아무에게도 가지 않았다
do
	table.clear(disk)
	table.clear(boards)
	table.clear(names)
	fail.save, fail.update, fail.read = false, false, false
	local sv = server()
	local function come(id: number, name: string, class: string)
		local p = { UserId = id, Name = "user" .. id, DisplayName = "user" .. id, attrs = {} }
		p.SetAttribute = function(self, key, v) self.attrs[key] = v end
		p.Kick = function() end
		sv.h.Ready(p)
		local made = sv.h.Chars(p, "create", name, class)
		sv.h.Chars(p, "enter", made and made.id)
		local s = sv.World.session(p)
		s.scene = "town"
		for t = 1, Bag.size(s.hero) do
			s.hero.gear[t], s.hero.use[t], s.hero.etc[t] = false, false, false
		end
		s.hero.money = 10000
		return p, s
	end
	local pa, sa = come(9801, "캐시판매", "axion")
	local pb, sb = come(9802, "캐시구매", "riven")
	local hat = Items.make("hat", 20, 4)
	hat.star = 7
	local slot = Bag.add(sa.hero, hat)
	local res
	task.spawn(function() res = sv.h.Market(pa, "list", "gear", slot, nil, { 500, M.hours[1] }) end)
	advance(5)
	expect(res and res.ok, "판매자가 올린다")
	local rows
	task.spawn(function() rows = sv.h.Market(pb, "browse", "a_hat", true) end) -- 지금의 장부를 읽는다(그 값이 4초 동안 캐시에 남는다)
	advance(1)
	local row = rows and rows.rows and rows.rows[1]
	expect(row ~= nil, "산 사람이 그 모자를 본다")
	-- 다른 서버에서 누가 장부를 바꿔 이 서버의 캐시가 옛 것이 되게(판매자의 다른 줄 하나 더)
	fail.update = "after" -- 사는 쓰기는 적히고 답만 오지 않는다
	task.spawn(function() res = sv.h.Market(pb, "buy", "a_hat", row and row.id, 1, row and row.p) end)
	advance(0.5)
	fail.update = false
	advance(5)
	expect(res and res.ok, "적힌 구매는 산 것이다(지금의 장부를 다시 읽어 확인한다) — " .. tostring(res and res.why))
	local holds = 0
	for _, hd in sb.acct.market.list do
		if hd.hold then
			holds += 1
		end
	end
	eq(holds, 1, "산 모자가 「완료」에 들어왔다")
	eq(sb.hero.money, 10000 - 500, "값을 한 번 치렀다(돌려받지 않았다)")
	sv.World.removePlayer(pa)
	sv.World.removePlayer(pb)
	advance(5)
end
