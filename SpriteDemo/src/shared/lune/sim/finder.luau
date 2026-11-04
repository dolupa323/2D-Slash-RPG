-- 파티 찾기(2026-11-05 — 사용자 "파티 보스라서 파티구하고 방만들고 막 이런 UI도 있어야해 파티를 구해서 가는거라서" ·
--  고르심: 같은 서버만 · 방장이 수락 · 방장 출발 → 바로 보스 방). 로스트아크 · WoW의 파티 찾기 꼴: 「모집 중인 방」 목록 · 「방 만들기」 · 신청 → 방장이 수락.
--  방의 사람 = 방장의 파티 그대로(sim/party.luau — 서버가 수락할 때 그 사람을 방장의 파티에 넣는다 · 방을 나가면 파티를 나간다). 그래서 이 셈은 방의 것(보스 · 난이도 · 조건 · 준비 · 신청)만 적고
--  누가 같은 파티인지는 P(서버가 주는 셈 — P.members(사람) = 그 파티원들(자기도) · P.leader(사람) = 그 파티장(혼자면 자기))로 본다.
--  방 = rooms[방장] = { leader, boss, mode, minLv, ready = { [사람] = true }, apps = { 신청한 사람… }, at } · app[신청한 사람] = 그 방(방장 — 한 사람은 한 방에만 신청한다: 로스트아크와 같다)
local Party = require(script.Parent.party)

local Finder = {}
Finder.MAX = Party.MAX
Finder.APPS = 6 -- 한 방에 걸려 있는 신청(넘으면 「신청이 많다」 — 제가 정한 것)
Finder.LV_STEPS = { 0, 10, 20 } -- 조건 레벨 = 그 보스의 입장 레벨 + 이것(방 만들기의 「조건」 단추가 돌린다)

function Finder.new()
	return { rooms = {}, app = {}, serial = 0 }
end

-- 그 사람이 든 방(방장이면 제 방 · 파티원이면 파티장의 방)
function Finder.roomOf(book, P, uid: any)
	return book.rooms[P.leader(uid)]
end

-- 신청을 거둔다(다른 방에 신청 · 방을 만든다 · 수락 · 거절 · 나간다)
function Finder.withdraw(book, uid: any)
	local at = book.app[uid]
	book.app[uid] = nil
	local r = at and book.rooms[at]
	if r then
		local i = table.find(r.apps, uid)
		if i then
			table.remove(r.apps, i)
		end
	end
end

-- 방을 닫는다(방장이 닫는다 · 방장이 나갔다 · 출발했다)
function Finder.close(book, leader: any)
	local r = book.rooms[leader]
	if not r then
		return nil
	end
	for _, uid in r.apps do
		book.app[uid] = nil
	end
	book.rooms[leader] = nil
	return r
end

-- 방을 만든다: 파티장(혼자면 자기)만 · 지금의 파티원은 그대로 방에 든다
function Finder.make(book, P, uid: any, boss: string, mode: string, minLv: number)
	if P.leader(uid) ~= uid then
		return nil, "파티장만 방을 만든다"
	elseif book.rooms[uid] then
		return nil, "이미 방이 있다"
	end
	for _, m in P.members(uid) do
		Finder.withdraw(book, m)
	end
	book.serial += 1
	local r = { leader = uid, boss = boss, mode = mode, minLv = minLv, ready = {}, apps = {}, at = book.serial }
	book.rooms[uid] = r
	return r
end

-- 신청한다: 혼자인 사람만(파티가 있으면 나와서) · 조건 레벨 · 방이 가득 차지 않았을 때
function Finder.apply(book, P, uid: any, leader: any, level: number)
	local r = book.rooms[leader]
	if not r then
		return nil, "없는 방이다"
	elseif #P.members(uid) > 1 then
		return nil, "파티를 나와야 신청한다"
	elseif book.rooms[uid] then
		return nil, "내 방이 있다 — 닫고 신청한다"
	elseif #P.members(leader) >= Finder.MAX then
		return nil, "방이 가득 찼다"
	elseif level < r.minLv then
		return nil, ("Lv.%d부터 신청한다"):format(r.minLv)
	elseif book.app[uid] == leader then
		return nil, "이미 신청했다"
	elseif #r.apps >= Finder.APPS then
		return nil, "신청이 많다 — 잠시 뒤에"
	end
	Finder.withdraw(book, uid)
	table.insert(r.apps, uid)
	book.app[uid] = leader
	return r
end

-- 방장이 수락한다(서버가 그 사람을 방장의 파티에 넣는다) · 거절한다
function Finder.accept(book, P, leader: any, uid: any)
	local r = book.rooms[leader]
	if not r then
		return nil, "방이 없다"
	elseif not table.find(r.apps, uid) then
		return nil, "신청이 없다"
	elseif #P.members(leader) >= Finder.MAX then
		return nil, "방이 가득 찼다"
	end
	Finder.withdraw(book, uid)
	return r
end
function Finder.deny(book, leader: any, uid: any)
	local r = book.rooms[leader]
	if not r or not table.find(r.apps, uid) then
		return nil, "신청이 없다"
	end
	Finder.withdraw(book, uid)
	return r
end

-- 준비 · 준비 취소(파티원 — 방장은 늘 준비)
function Finder.setReady(book, P, uid: any, on: boolean)
	local r = Finder.roomOf(book, P, uid)
	if not r then
		return nil, "방이 없다"
	end
	r.ready[uid] = if on then true else nil
	return r
end

-- 출발할 수 있나: 방장 · 둘 이상 · 방장 밖의 모두가 준비
function Finder.check(book, P, uid: any)
	local r = book.rooms[uid]
	if not r then
		return nil, "방장만 출발한다"
	end
	local members = P.members(uid)
	if #members < 2 then
		return nil, "둘 이상이 모여야 출발한다"
	end
	local wait = 0
	for _, m in members do
		if m ~= uid and not r.ready[m] then
			wait += 1
		end
	end
	if wait > 0 then
		return nil, ("%d명이 아직 준비하지 않았다"):format(wait)
	end
	return r, members
end

-- 파티가 바뀐 뒤 맞춘다: 방장이 이제 파티장이 아니면(파티가 흩어졌다 · 넘겨졌다) 방을 닫고 · 방을 떠난 사람의 준비를 지운다. 닫은 방들을 돌려준다
function Finder.sweep(book, P)
	local closed = {}
	for leader, r in book.rooms do
		if P.leader(leader) ~= leader then
			table.insert(closed, Finder.close(book, leader))
		else
			local members = P.members(leader)
			for uid in r.ready do
				if not table.find(members, uid) then
					r.ready[uid] = nil
				end
			end
		end
	end
	return closed
end

-- 모집 중인 방들(새 방이 위): { leader, boss, mode, minLv, n }
function Finder.list(book, P)
	local out = {}
	for leader, r in book.rooms do
		table.insert(out, { leader = leader, boss = r.boss, mode = r.mode, minLv = r.minLv, n = #P.members(leader), at = r.at })
	end
	table.sort(out, function(a, b)
		return a.at > b.at
	end)
	return out
end

return Finder
