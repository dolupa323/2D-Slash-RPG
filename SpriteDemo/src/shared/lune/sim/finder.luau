-- 파티 찾기(2026-11-05 — 사용자 "파티 보스라서 파티구하고 방만들고 막 이런 UI도 있어야해 파티를 구해서 가는거라서" · 고르심: 같은 서버만 · 방장이 수락).
--  같은 날 다시(사용자: "메뉴탭에서 접근하는게 아니라 해당 던전에서 파티방을 만드는거야 그 던전 갈사람을 구할수있는 구인구직 ui 를 만드는거고 로스트아크 파티모집 어떻게하는지 … 공부하고만들어"):
--   로스트아크의 레이드 파티 찾기 꼴 — 보스(레이드)마다 따로 운영한다(그 보스의 문 → 보스 창의 [파티 찾기]) · [모집 글 등록](제목 · 난이도 · 최소 레벨 · 같은 직업 받기) → 파티 대기실 ·
--   [참가 신청](한 사람 한 방 — 다른 방에 신청하면 앞의 것은 거둬진다 · 수락 전에는 [참가 취소]) → 방장이 수락 · 거절 · 모집이 끝나면 남은 신청은 사라진다 · 입장은 모두 그 문 앞에 있어야(서버가 본다).
--  방의 사람 = 방장의 파티 그대로(sim/party.luau — 서버가 수락할 때 그 사람을 방장의 파티에 넣는다 · 방을 나가면 파티를 나간다). 그래서 이 셈은 방의 것(보스 · 난이도 · 제목 · 조건 · 신청)만 적고
--  누가 같은 파티인지는 P(서버가 주는 셈 — P.members(사람) = 그 파티원들(자기도) · P.leader(사람) = 그 파티장(혼자면 자기) · P.classOf(사람) = 그 직업)로 본다.
--  방 = rooms[방장] = { leader, boss, mode, title, minLv, sameClass, apps = { 신청한 사람… }, at } · app[신청한 사람] = 그 방(방장)
local Party = require(script.Parent.party)

local Finder = {}
Finder.MAX = Party.MAX
Finder.APPS = 8 -- 한 방에 걸려 있는 신청(넘으면 「신청이 많다」 — 제가 정한 것)
Finder.LV_STEPS = { 0, 5, 10, 20 } -- 최소 레벨 = 그 보스의 입장 레벨 + 이것(모집 글 등록의 「최소 레벨」 단추 줄)
Finder.TITLE_MAX = 20 -- 제목의 글자 수
Finder.NEAR = 120 -- 「문 앞」 = 그 보스의 문과 같은 맵에서 가로로 이 점 안(입장 · 신청 · 등록)

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

-- 방을 닫는다(방장이 모집 취소 · 방장이 나갔다 · 입장했다): 남은 신청은 사라진다
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

-- 모집 글을 등록한다: 파티장(혼자면 자기)만 · 지금의 파티원은 그대로 대기실에 든다. info = { boss, mode, title, minLv, sameClass }
function Finder.make(book, P, uid: any, info)
	if P.leader(uid) ~= uid then
		return nil, "파티장만 모집 글을 등록한다"
	elseif book.rooms[uid] then
		return nil, "이미 모집 중이다"
	elseif #P.members(uid) >= Finder.MAX then
		return nil, "파티가 가득 찼다"
	end
	for _, m in P.members(uid) do
		Finder.withdraw(book, m)
	end
	book.serial += 1
	local r = { leader = uid, boss = info.boss, mode = info.mode, title = info.title, minLv = info.minLv, sameClass = info.sameClass == true, apps = {}, at = book.serial }
	book.rooms[uid] = r
	return r
end

-- 이 사람이 그 방에 신청할 수 있나(신청 단추를 켜고 끄는 것도 이것): me = { level, class }
function Finder.canApply(book, P, uid: any, leader: any, me): string?
	local r = book.rooms[leader]
	if not r then
		return "없는 방이다"
	elseif P.leader(uid) == leader then
		return "내 방이다"
	elseif #P.members(uid) > 1 then
		return "파티를 나와야 신청한다"
	elseif book.rooms[uid] then
		return "모집 중인 방이 있다 — 취소하고 신청한다"
	elseif #P.members(leader) >= Finder.MAX then
		return "방이 가득 찼다"
	elseif me.level < r.minLv then
		return ("Lv.%d부터 신청한다"):format(r.minLv)
	elseif not r.sameClass then
		for _, m in P.members(leader) do
			if P.classOf(m) == me.class then
				return "같은 직업은 받지 않는 방이다"
			end
		end
	end
	return nil
end

-- 참가 신청: 한 사람은 한 방에만(다른 방에 신청하면 앞의 것은 거둬진다)
function Finder.apply(book, P, uid: any, leader: any, me)
	local why = Finder.canApply(book, P, uid, leader, me)
	if why then
		return nil, why
	end
	local r = book.rooms[leader]
	if book.app[uid] == leader then
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
		return nil, "모집 중이 아니다"
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

-- 입장할 수 있나(방장 · 둘 이상 — 문 앞에 모였는지는 서버가 본다)
function Finder.check(book, P, uid: any)
	local r = book.rooms[uid]
	if not r then
		return nil, "방장만 입장한다"
	end
	local members = P.members(uid)
	if #members < 2 then
		return nil, "둘 이상이 모여야 입장한다"
	end
	return r, members
end

-- 파티가 바뀐 뒤 맞춘다: 방장이 이제 파티장이 아니면(파티가 흩어졌다 · 넘겨졌다) 방을 닫는다. 닫은 방들을 돌려준다
function Finder.sweep(book, P)
	local closed = {}
	for leader in book.rooms do
		if P.leader(leader) ~= leader then
			table.insert(closed, Finder.close(book, leader))
		end
	end
	return closed
end

-- 그 보스의 모집 중인 방들(새 방이 위): { leader, mode, title, minLv, sameClass, n }
function Finder.list(book, P, boss: string)
	local out = {}
	for leader, r in book.rooms do
		if r.boss == boss then
			table.insert(out, { leader = leader, mode = r.mode, title = r.title, minLv = r.minLv, sameClass = r.sameClass, n = #P.members(leader), at = r.at })
		end
	end
	table.sort(out, function(a, b)
		return a.at > b.at
	end)
	return out
end

-- 제목을 다듬는다(앞뒤 빈칸 · 줄바꿈을 없애고 TITLE_MAX자까지 — 거르기는 서버가 Roblox의 TextService로)
function Finder.cleanTitle(text: any): string
	if typeof(text) ~= "string" then
		return ""
	end
	local t = string.gsub(text, "[%c]", " ")
	t = string.gsub(t, "^%s+", "")
	t = string.gsub(t, "%s+$", "")
	t = string.gsub(t, "%s%s+", " ")
	local n = utf8.len(t)
	if n and n > Finder.TITLE_MAX then
		t = string.sub(t, 1, (utf8.offset(t, Finder.TITLE_MAX + 1) or (#t + 1)) - 1)
	elseif not n then
		return ""
	end
	return t
end

return Finder
