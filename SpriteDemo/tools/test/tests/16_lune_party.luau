-- 「달의 계승자」 — 파티(shared/lune/sim/party.luau): 초대 · 받기 · 거절 · 나가기 · 파티장 넘기기 · 경험치 나누기 · 떨어진 것 같이 줍기 · 이름표에 적는 이름
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Party = req("ReplicatedStorage/shared/lune/sim/party")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local F = req("ReplicatedStorage/shared/lune/ui/format")
local RULES = COMBAT.rules

-- ---- 1) 초대와 받기 ----
local book = Party.newBook()
eq(#Party.members(book, 1), 1, "파티가 없으면 혼자")
eq(Party.same(book, 1, 2), false, "파티가 없으면 남남")
eq(Party.same(book, 1, 1), true, "자기 자신과는 같다")
local ok, why = Party.invite(book, 1, 1, 0)
expect(not ok and why == "자기 자신은 초대할 수 없다", "자기 자신은 초대하지 못한다")
expect(Party.invite(book, 1, 2, 0), "1이 2를 초대한다")
eq(Party.of(book, 1), nil, "받기 전에는 파티가 없다")
ok, why = Party.invite(book, 3, 2, 1)
expect(not ok and why == "이미 초대를 받고 있는 사람이다", "초대를 받고 있는 사람은 또 초대하지 못한다")
local party = Party.accept(book, 2, 2)
expect(party ~= nil and party.leader == 1 and #party.members == 2, "받으면 파티가 생기고 초대한 사람이 파티장")
eq(Party.same(book, 1, 2), true, "같은 파티")
eq(Party.accept(book, 2, 3), nil, "초대가 없으면 받을 수 없다")
ok, why = Party.invite(book, 3, 1, 3)
expect(not ok and why == "이미 파티가 있는 사람이다", "파티가 있는 사람은 초대하지 못한다")
ok, why = Party.invite(book, 2, 3, 3)
expect(not ok and why == "파티장만 초대한다", "파티원은 초대하지 못한다")
-- 넷까지
expect(Party.invite(book, 1, 3, 4) and Party.accept(book, 3, 5) ~= nil, "셋째")
expect(Party.invite(book, 1, 4, 6) and Party.accept(book, 4, 7) ~= nil, "넷째")
eq(#Party.members(book, 1), Party.MAX, "넷")
ok, why = Party.invite(book, 1, 5, 8)
expect(not ok and why == "파티가 가득 찼다", "다섯째는 못 들어온다")
-- 초대는 30초 뒤에 사라진다 · 거절
local b2 = Party.newBook()
Party.invite(b2, 10, 11, 0)
eq(Party.ask(b2, 11, 10) ~= nil, true, "초대가 살아 있다")
eq(Party.ask(b2, 11, Party.ASK_LIFE + 1), nil, "시간이 지나면 사라진다")
eq(Party.accept(b2, 11, Party.ASK_LIFE + 2), nil, "사라진 초대는 받을 수 없다")
Party.invite(b2, 10, 11, 100)
eq(Party.decline(b2, 11), 10, "거절하면 초대한 사람을 안다")
eq(Party.accept(b2, 11, 101), nil, "거절한 초대는 받을 수 없다")
expect(Party.invite(b2, 12, 11, 102), "거절한 뒤에는 다른 초대를 받을 수 있다")
-- 초대한 사람이 그사이 다른 파티에 들어가 가득 찼으면
local b3 = Party.newBook()
Party.invite(b3, 1, 2, 0)
Party.accept(b3, 2, 0)
Party.invite(b3, 1, 3, 0)
Party.invite(b3, 1, 4, 0)
Party.invite(b3, 1, 5, 0)
expect(Party.accept(b3, 3, 1) ~= nil and Party.accept(b3, 4, 1) ~= nil, "둘이 받는다")
local late, lateWhy = Party.accept(b3, 5, 1)
expect(late == nil and lateWhy == "파티가 가득 찼다", "늦게 받은 사람은 못 들어간다")
eq(Party.of(b3, 5), nil, "못 들어간 사람은 파티가 없다")

-- ---- 2) 나가기 ----
local left, gone = Party.leave(book, 3)
eq(#left, 3, "남은 셋")
eq(gone, false, "흩어지지 않는다")
eq(Party.of(book, 3), nil, "나간 사람은 파티가 없다")
left, gone = Party.leave(book, 1)
eq(Party.of(book, 2).leader, 2, "파티장이 나가면 먼저 들어온 사람이 파티장")
eq(#left, 2, "남은 둘")
left, gone = Party.leave(book, 4)
eq(gone, true, "둘 아래로 줄면 흩어진다")
eq(#left, 1, "마지막 한 사람에게도 알린다")
eq(Party.of(book, 2), nil, "남은 한 사람도 파티가 없다")
left, gone = Party.leave(book, 99)
eq(#left, 0, "파티가 없는 사람이 나가도 아무 일 없다")
expect(Party.invite(book, 2, 4, 50), "흩어진 뒤에는 다시 맺을 수 있다")

-- ---- 3) 경험치를 나누는 몫 ----
eq(Party.share(1), 1, "혼자면 그대로")
local rule = N.data.XPRULE.party
for _, row in rule do
	expect(math.abs(Party.share(row.n) * row.n - (1 + row.bonus / 100)) < 1e-9, ("%d명이면 모두 합쳐 %d%%"):format(row.n, 100 + row.bonus))
	expect(Party.share(row.n) < 1, "한 사람 몫은 혼자일 때보다 적다 " .. row.n)
	expect(Party.share(row.n) * row.n > 1, "모두 합치면 혼자일 때보다 많다 " .. row.n)
end
-- 레벨 차이가 20을 넘는 파티원과는 나누지 않는다 · 같은 맵에 없는 사람과도
local b4 = Party.newBook()
Party.invite(b4, 1, 2, 0)
Party.accept(b4, 2, 0)
Party.invite(b4, 1, 3, 0)
Party.accept(b4, 3, 0)
local mates = Party.mates(b4, 1, { [1] = { level = 30 }, [2] = { level = 50 }, [3] = { level = 51 } })
eq(#mates, 2, "레벨 차이 20까지만 나눈다(30과 50은 되고 51은 안 된다)")
mates = Party.mates(b4, 1, { [1] = { level = 30 }, [3] = { level = 30 } })
eq(#mates, 2, "같은 맵에 없는 사람은 뺀다")
mates = Party.mates(b4, 9, { [9] = { level = 5 } })
eq(#mates, 1, "파티가 없으면 혼자")

-- ---- 4) 방에서: 함께 잡으면 경험치가 나뉘고, 떨어진 것을 같이 줍는다 ----
local function solo(seed)
	local scene = table.clone(SCENES.scenes.hunt)
	scene.mobs = { scene.mobs[1] }
	return Room.new("hunt", scene, Random.new(seed))
end
local function hit()
	return { box = { -400, 400, 200, 200 }, mul = 9999, seg = 1, at = 0 }
end
do
	local room = solo(1)
	local a, b = Hero.new(1, "axion"), Hero.new(2, "riven")
	local mob = room.mobs[1]
	a.x, a.y, b.x, b.y = mob.x, mob.y, mob.x, mob.y
	for _ = 1, 40 do
		room:step({ [1] = a, [2] = b }, 1 / 20)
		if mob.state ~= "spawn" then
			break
		end
	end
	a.invuln, b.invuln = 99, 99
	local aloneXp = Hero.killXp(a, mob.lv, mob.def.hp)
	local xa, xb = a.xp, b.xp
	local out = room:skillHit(a, hit(), a.x, a.y, 1, 1, { a, b })
	eq(#out.kills, 1, "잡았다")
	local kill = out.kills[1]
	eq(#kill.gains, 2, "두 사람이 받는다")
	local want = math.max(1, math.floor(aloneXp * Party.share(2) + 0.5))
	eq(a.xp - xa + (if kill.gains[1].ups > 0 then N.xpNeed(1) else 0), want, "잡은 사람의 몫(55%)")
	expect(b.xp > xb or b.level > 1, "파티원도 받는다")
	eq(kill.xp, want, "잡은 사람에게 알릴 값")
	-- 떨어진 것: 파티원은 바로 줍고, 남은 기다려야 한다
	local d = kill.drop or kill.loot[1]
	if not d then
		d = room:addDrop({ kind = "money", amount = 5 }, mob.x, mob.y, a.id)
		d.friends = { [1] = true, [2] = true }
	end
	local c = Hero.new(3, "mooni")
	c.x, c.y = d.x, d.y
	b.x, b.y = d.x, d.y
	local got, whyNot = room:pickup(c, d.id)
	expect(got == nil and whyNot == "남의 것", "파티가 아닌 사람은 바로 줍지 못한다")
	expect(room:pickup(b, d.id) ~= nil, "파티원은 바로 줍는다")
end
do
	-- 혼자 잡으면 예전과 같다
	local room = solo(2)
	local a = Hero.new(1, "axion")
	local mob = room.mobs[1]
	a.x, a.y = mob.x, mob.y
	for _ = 1, 40 do
		room:step({ [1] = a }, 1 / 20)
		if mob.state ~= "spawn" then
			break
		end
	end
	local aloneXp = Hero.killXp(a, mob.lv, mob.def.hp)
	local out = room:skillHit(a, hit(), a.x, a.y, 1, 1)
	eq(out.kills[1].xp, aloneXp, "혼자 잡으면 다 받는다")
	eq(#out.kills[1].gains, 1, "받는 사람은 하나")
	local d = out.kills[1].drop
	if d then
		eq(d.friends, nil, "혼자 잡은 것에는 같이 주울 사람이 없다")
	end
end

-- ---- 5) 이름표에 적는 이름 ----
eq(F.safeName("달토끼", "user1"), "달토끼", "한글 이름은 그대로")
eq(F.safeName("Moon_Rabbit7", "user1"), "Moon_Rabbit7", "영문 · 숫자 이름은 그대로")
eq(F.safeName("月うさぎ", "user1"), "user1", "글꼴에 없는 글자가 섞이면 아이디를 쓴다")
eq(F.safeName("", "user1"), "user1", "빈 이름이면 아이디")
eq(F.safeName(nil, "user1"), "user1", "이름이 없으면 아이디")
eq(F.safeName("가나다라마바사아자차카타파하", "user1"), "가나다라마바사아자차카타", "길면 열두 자에서 자른다")
eq(F.safeName("\255\254", "user1"), "user1", "깨진 글이면 아이디")
local _ = RULES
