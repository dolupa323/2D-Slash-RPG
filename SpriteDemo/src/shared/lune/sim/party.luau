-- 파티 — 넷까지(사용자 결정). 초대 → 받기 / 거절, 나가기, 파티장 넘기기(파티장이 나가면 먼저 들어온 사람에게), 둘 아래로 줄면 흩어진다.
--  누가 어느 파티인지만 다루는 순수한 셈이다(사람 = 번호). 경험치를 나누는 몫도 여기서 낸다:
--   같은 맵에서 함께 잡으면 몬스터의 경험치 x (1 + 보너스)를 사람 수로 고르게 나눈다(보너스: 둘 10% · 셋 15% · 넷 20% — 공방 「성장 · 장비」 탭의 XPRULE).
--   예: 둘이면 한 사람이 55%씩 — 둘이 잡으면 두 배 빨리 잡으니 혼자일 때의 110%다. 레벨 차이가 20을 넘는 파티원과는 나누지 않는다.
local N = require(script.Parent.Parent.config.numbers)

local RULE = N.data.XPRULE

local Party = {}
Party.MAX = RULE.partyMax
Party.ASK_LIFE = 30 -- 초대가 살아 있는 시간(초)
Party.LEVEL_GAP = 20 -- 이보다 레벨 차이가 크면 경험치를 나누지 않는다

-- 장부: parties[번호] = { id, leader, members = { 들어온 차례대로 } } · of[사람] = 파티 번호 · asks[받은 사람] = { from, at }
function Party.newBook()
	return { parties = {}, of = {}, asks = {}, nextId = 1 }
end

function Party.of(book, who: any)
	local id = book.of[who]
	return if id then book.parties[id] else nil
end

-- 그 사람의 파티원들(자기도 든다). 파티가 없으면 혼자
function Party.members(book, who: any): { any }
	local party = Party.of(book, who)
	return if party then table.clone(party.members) else { who }
end

function Party.same(book, a: any, b: any): boolean
	return a == b or (book.of[a] ~= nil and book.of[a] == book.of[b])
end

-- 살아 있는 초대(시간이 지난 것은 지운다)
function Party.ask(book, to: any, now: number)
	local ask = book.asks[to]
	if ask and now - ask.at > Party.ASK_LIFE then
		book.asks[to] = nil
		return nil
	end
	return ask
end

-- 초대한다. 파티가 없는 사람이 초대하면 받는 순간 파티가 생기고 초대한 사람이 파티장이 된다
function Party.invite(book, from: any, to: any, now: number): (boolean?, string?)
	if from == to then
		return nil, "자기 자신은 초대할 수 없다"
	elseif book.of[to] then
		return nil, "이미 파티가 있는 사람이다"
	end
	local party = Party.of(book, from)
	if party then
		if party.leader ~= from then
			return nil, "파티장만 초대한다"
		elseif #party.members >= Party.MAX then
			return nil, "파티가 가득 찼다"
		end
	end
	if Party.ask(book, to, now) then
		return nil, "이미 초대를 받고 있는 사람이다"
	end
	book.asks[to] = { from = from, at = now }
	return true
end

-- 초대를 받는다. 들어간 파티를 돌려준다
function Party.accept(book, to: any, now: number)
	local ask = Party.ask(book, to, now)
	if not ask then
		return nil, "받은 초대가 없다"
	end
	book.asks[to] = nil
	if book.of[to] then
		return nil, "이미 파티가 있다"
	end
	local party = Party.of(book, ask.from)
	if not party then
		party = { id = book.nextId, leader = ask.from, members = { ask.from } }
		book.nextId += 1
		book.parties[party.id] = party
		book.of[ask.from] = party.id
	end
	if #party.members >= Party.MAX then
		return nil, "파티가 가득 찼다"
	end
	table.insert(party.members, to)
	book.of[to] = party.id
	return party
end

-- 초대를 거절한다. 초대한 사람을 돌려준다(초대가 없었으면 nil)
function Party.decline(book, to: any): any
	local ask = book.asks[to]
	book.asks[to] = nil
	return if ask then ask.from else nil
end

-- 나간다(접속을 끊었을 때도). 돌려주는 것: 남은 사람들(흩어졌으면 그 마지막 한 사람까지), 흩어졌는가
function Party.leave(book, who: any): ({ any }, boolean)
	book.asks[who] = nil
	local party = Party.of(book, who)
	if not party then
		return {}, false
	end
	local index = table.find(party.members, who)
	table.remove(party.members, index)
	book.of[who] = nil
	local left = table.clone(party.members)
	if #party.members < 2 then
		for _, m in party.members do
			book.of[m] = nil
		end
		book.parties[party.id] = nil
		return left, true
	end
	if party.leader == who then
		party.leader = party.members[1]
	end
	return left, false
end

-- 함께 잡은 사람 수에 따른 보너스 %
function Party.bonus(n: number): number
	local bonus = 0
	for _, row in RULE.party do
		if n >= row.n then
			bonus = row.bonus
		end
	end
	return bonus
end

-- 함께 잡은 사람이 n이면 한 사람이 몬스터 경험치의 몇 배를 받나(혼자면 1)
function Party.share(n: number): number
	if n <= 1 then
		return 1
	end
	return (1 + Party.bonus(n) / 100) / n
end

-- 경험치를 나눌 사람들: killer의 파티원 가운데 here(같은 맵에 있는 살아 있는 사람들 { [번호] = { level } })에 있고 레벨 차이가 20 안쪽인 사람(killer도 든다)
function Party.mates(book, killer: any, here): { any }
	local me = here[killer]
	local list = {}
	for _, m in Party.members(book, killer) do
		local other = here[m]
		if m == killer or (other and me and math.abs(other.level - me.level) <= Party.LEVEL_GAP) then
			table.insert(list, m)
		end
	end
	return list
end

return Party
