-- 「달의 계승자」 — 빼빼로 데이 접속 선물(2026-11-10 — 공방 design/event.js EVENTS.gifts · sim/event.luau Event.giveGifts · 서버 world.luau 1초 걸음).
--  사용자: "11월 11일에 그냥 접속하는 유저들한테 기타아이템에다가 빼빼로 아이템 지급하고 못받은 유저들을 위한 빼빼로다. 이렇게 설명적히게해서 아이템 추가해줘"
--  보는 것: ① 물건(기타 탭 · 이름 · 설명 그대로 · 경매장 불가 갈래) ② 날(한국 시간 11월 11일 0시 ~ 23:59:59) ③ 계정마다 해마다 한 번 · 다음 해 다시
--   ④ 가방 「기타」 탭이 가득하면 못 받고 자리가 나면 받는다 ⑤ 받은 해가 계정 저장에 남는다
local Event = req("ReplicatedStorage/shared/lune/sim/event")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Account = req("ReplicatedStorage/shared/lune/sim/account")

-- ① 물건
local g = nil
for _, x in Event.GIFTS do
	if x.id == "pepero" then
		g = x
	end
end
expect(g ~= nil and g.on[1] == 11 and g.on[2] == 11 and g.tz == 9 and g.n == 1, "빼빼로 데이: 11월 11일(한국 시간) · 하나")
local def = Items.goods("etc_pepero")
expect(def ~= nil and def.tab == "etc" and def.name == "빼빼로", "기타 탭의 「빼빼로」")
eq(def and def.text, "못받은 유저들을 위한 빼빼로다.", "설명 = 사용자의 말 그대로")
eq(def and def.kind, "event", "기간 이벤트의 물건(경매장에 올리지 못한다 — 호박 사탕과 같다)")

-- ② 날: 2026-11-11 0시(한국) = 2026-11-10 15:00(세계 표준시)
local function utc(y, mo, d, h, mi, s)
	return os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s }) + (os.time() - os.time(os.date("!*t", os.time())))
end
local start = utc(2026, 11, 10, 15, 0, 0)
eq(os.date("!%Y-%m-%d %H:%M", start), "2026-11-10 15:00", "셈의 기준 시각(세계 표준시)")
expect(not (Event.giftDay(g, start - 1)), "11월 10일 23:59:59(한국)에는 아니다")
expect((Event.giftDay(g, start)), "11월 11일 0시(한국)부터")
expect((Event.giftDay(g, start + 86399)), "11월 11일 23:59:59(한국)까지")
expect(not (Event.giftDay(g, start + 86400)), "11월 12일 0시(한국)부터는 아니다")

-- ③ 계정마다 해마다 한 번
local acct = Account.new()
local h = Hero.new(1, "riven")
Hero.setLevel(h, 30)
local given, full = Event.giveGifts(acct, h, start + 3600)
eq(#given, 1, "그날 처음: 받는다")
eq(#full, 0, "가방에 자리가 있다")
eq(Bag.count(h, "etc_pepero"), 1, "가방에 빼빼로 하나")
local again = Event.giveGifts(acct, h, start + 7200)
eq(#again, 0, "같은 날 다시는 아니다(계정마다 한 번)")
local h2 = Hero.new(2, "axion")
eq(#Event.giveGifts(acct, h2, start + 9000), 0, "같은 계정의 다른 캐릭터도 아니다")
eq(#Event.giveGifts(acct, h, start + 86400 * 2), 0, "날이 지나면 없다")
local nextYear = utc(2027, 11, 10, 15, 30, 0)
eq(#Event.giveGifts(acct, h, nextYear), 1, "다음 해 11월 11일에는 다시")

-- ④ 가방 「기타」 탭이 가득하면 못 받고, 자리가 나면 받는다
do
	local a2 = Account.new()
	local hb = Hero.new(3, "mooni")
	Hero.setLevel(hb, 30)
	local guard = 0
	while Bag.room(hb, "etc_pepero") > 0 and guard < 500 do
		guard += 1
		Bag.give(hb, "etc_candy", Items.goods("etc_candy").stack)
	end
	eq(Bag.room(hb, "etc_pepero"), 0, "기타 탭을 가득 채웠다")
	local g1, f1 = Event.giveGifts(a2, hb, start + 60)
	expect(#g1 == 0 and #f1 == 1, "가득: 못 받는다(다음에 다시)")
	eq(a2.evGift.pepero, nil, "받은 해를 적지 않는다")
	-- 한 칸 비운다
	local stack = Items.goods("etc_candy").stack
	Bag.take(hb, "etc_candy", stack)
	local g2 = Event.giveGifts(a2, hb, start + 120)
	eq(#g2, 1, "자리가 나면 받는다")
	eq(Bag.count(hb, "etc_pepero"), 1, "빼빼로 하나")
end

-- ⑤ 저장
do
	local back = Account.unpack(Account.pack(acct))
	expect(back ~= nil and back.evGift.pepero == 2027, "받은 해가 계정 저장에 남는다")
	local old = Account.pack(Account.new())
	old.evGift = nil
	local b2 = Account.unpack(old)
	expect(b2 ~= nil and next(b2.evGift) == nil, "그 전의 저장 = 아직 안 받음")
	local bad = Account.pack(Account.new())
	bad.evGift = { pepero = "x", [string.rep("a", 30)] = 2026 }
	local b3 = Account.unpack(bad)
	expect(b3 ~= nil and next(b3.evGift) == nil, "이상한 값은 버린다")
end
