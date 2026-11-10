-- 「달의 계승자」 — 달빛 상점의 뽑기 상자 · 윤슬 조각(2026-11-07 — 공방 design/bm.js BM_BOX · 게임 shared/lune/sim/gacha.luau · cash.luau).
--  사용자: "펫을 랜덤 뽑기형식으로 변경해서 지금있는 로벅스 펫들도 포함해서 지금 로벅스 펫들 같은 펫이 높은 확률을 차지하고 엄청이쁜 펫은 확률이 낮게 설정해줘
--   그리고 확률이 낮은 엄청이쁜펫은 전 맵을 거의 빨아들이는 자석펫으로" · "새로운 라이딩 뽑기 상자를 만들고, 라이딩 기능차이는 두지말고 엄청 이쁘고 멋지고 화려한 라이딩만 확률 낮게"
--  로블록스 확률형 아이템 규정: 확률 합 100% · 정책이 막힌 계정은 사지 못한다(서버 — 여기서는 셈만) · 선물하지 않는다
--  2026-11-10 사용자 "중복도 나올수있게해줘 지금 가챠인데 이미가진건 안나오면 뭐의미가 없어" → 가진 것도 나온다(모든 사람이 같은 확률) · 가진 것이 나오면 윤슬 조각(보통 2 · 드문 것 5)
--  · 데미지 스킨 상자 · 이름표 테두리 상자(2026-11-10)
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Gacha = req("ReplicatedStorage/shared/lune/sim/gacha")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Odds = req("ReplicatedStorage/shared/lune/ui/odds")
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local NOW = 1_790_000_000

local function sum(list)
	local s = 0
	for _, e in list do
		s += e.pct
	end
	return s
end

-- ① 상자의 표: 펫 상자에 지금의 로벅스 펫 셋이 들고, 흔한 것이 드문 것보다 확률이 높다 · 합 100
local pet = Gacha.box("petbox")
local mount = Gacha.box("mountbox")
expect(pet ~= nil and pet.kind == "pet", "윤슬 펫 상자가 있다")
expect(mount ~= nil and mount.kind == "mount", "윤슬 탈것 상자가 있다")
local all = Gacha.odds("petbox", {})
expect(math.abs(sum(all) - 100) < 1e-6, "펫 상자의 확률 합 = 100%")
local by = {}
for _, e in all do
	by[e.id] = e
end
for _, id in { "pet_silver", "pet_lantern", "pet_scarf" } do
	expect(by[id] ~= nil and not by[id].rare, "지금의 로벅스 펫이 상자에 든다(흔한 것) " .. id)
end
for _, id in { "pet_fox", "pet_jelly" } do
	expect(by[id] ~= nil and by[id].rare, "드문 펫 " .. id)
	expect(by[id].pct < by.pet_silver.pct, id .. "의 확률이 흔한 펫보다 낮다")
end
local mall = Gacha.odds("mountbox", {})
expect(math.abs(sum(mall) - 100) < 1e-6, "탈것 상자의 확률 합 = 100%")
local mby = {}
for _, e in mall do
	mby[e.id] = e
end
expect(mby.mount_whale and mby.mount_whale.rare and mby.mount_whale.pct < mby.mount_wolf_lake.pct, "별고래는 드물다")
-- 지금 파는 탈것(늑대 · 사슴 · 멧돼지 · 골렘)은 상자에 들지 않는다(사용자 "현재있는건 내버려두고")
for _, id in { "mount_wolf", "mount_deer", "mount_boar", "mount_golem" } do
	expect(mby[id] == nil, "지금의 탈것은 상자에 없다 " .. id)
end
-- 탈것 상자의 탈것은 모두 같은 빠르기 · 대쉬(기능 차이 없음)
local MOUNT = {}
for _, q in RIDE.mounts do
	MOUNT[q.id] = q
end
for _, e in mall do
	local q = MOUNT[e.id]
	expect(q ~= nil and q.speed == nil and q.dash ~= nil, "상자 탈것은 로벅스 탈것과 같은 빠르기 · 탄 채 대쉬 " .. e.id)
end
-- 드문 펫 = 맵 전체를 빨아들인다 · 흔한 상자 펫 = 로벅스 펫과 같은 둘레
local PET = {}
for _, q in RIDE.pets do
	PET[q.id] = q
end
expect(PET.pet_fox.suck and PET.pet_fox.suck.r >= 2000, "윤슬 여우는 맵 전체를 빨아들인다")
expect(PET.pet_jelly.suck and PET.pet_jelly.suck.reach >= 2000, "아기 달빛 해파리도 맵 전체")
expect(PET.pet_bud.suck == nil and not PET.pet_bud.free, "아기 연등 꽃망울은 로벅스 펫과 같은 빨아들이기")

-- ② 모든 사람이 같은 확률(2026-11-10 — 가진 것도 나온다): 가진 것이 있어도 표 그대로 · 합 100
local acct = Account.new()
acct.chars[1] = { hero = { level = 150 } }
acct.bm.pets.pet_silver = true
acct.bm.pets.pet_fox = true
local mine = Gacha.odds("petbox", Gacha.ownedOf(acct.bm, "petbox"))
eq(#mine, #all, "가진 것이 있어도 모든 펫이 나온다")
expect(math.abs(sum(mine) - 100) < 1e-6, "확률의 합 100%")
for i, e in mine do
	expect(math.abs(e.pct - all[i].pct) < 1e-9, "가진 것과 상관없이 같은 확률 " .. e.id)
end

-- ③ 산다 → 하나 · 가진 것이 나오면 같은 것을 하나 더(2026-11-10 사용자가 고른 것 「같은 것을 하나 더 준다」 — 가진 수가 는다 · 윤슬 조각으로 바꾸지 않는다) ·
--   다 가져도 살 수 있다 · 같은 결제 번호는 두 번 주지 않는다
local function shards(a)
	local n = 0
	for _, e in a.bm.box do
		if e.id == "yunseul" then
			n += e.n
		end
	end
	return n
end
for _, e in all do
	acct.bm.pets[e.id] = true -- 모두 가졌다
end
local ok, why = Cash.canBuy(acct, "petbox", NOW, 0, Account.MAX)
expect(ok == true, "다 가져도 상자를 살 수 있다(가진 것도 나온다) " .. tostring(why))
local s0 = shards(acct)
local petsBefore = 0
for _ in acct.bm.pets do
	petsBefore += 1
end
local gotN = {}
for i = 1, 12 do
	expect(Cash.grant(acct, "petbox", "dup" .. i, NOW, Account.MAX), ("펫 상자 %d번째"):format(i))
	local lb = acct.bm.lastBox
	expect(lb and typeof(lb.got) == "string", "나온 것을 알림에 싣는다(가진 것이어도)")
	gotN[lb.got] = (gotN[lb.got] or 0) + 1
	expect(lb and lb.n == 1 + gotN[lb.got], ("가진 것이라 하나 더 — 알림에 받은 뒤의 가진 수 %s"):format(tostring(lb and lb.n)))
	expect(lb.dup == nil, "윤슬 조각으로 바꾼 수는 더 없다")
end
eq(shards(acct) - s0, 0, "가진 것이 나와도 윤슬 조각은 들어오지 않는다")
for id, n in gotN do
	eq(Cash.count(acct.bm, id), 1 + n, "가진 수가 는다 " .. id)
end
local petsAfter = 0
for _ in acct.bm.pets do
	petsAfter += 1
end
eq(petsAfter, petsBefore, "가진 것이 나오면 펫 목록(종류)은 그대로 · 수만 는다")
eq(Cash.count(acct.bm, "no_such_pet"), 0, "없는 것의 수 0")
-- 같은 펫을 여럿 꺼낸다(가진 수까지 · 셋까지) · 하나씩 넣는다 · 퀵슬롯의 「넣기」는 그 펫을 모두
local pa = Account.new()
pa.chars[1] = { hero = { level = 10 } }
pa.bm.pets.pet_silver = true
pa.bm.extra.pet_silver = 1 -- 둘
pa.bm.pets.pet_star = true
expect(Cash.setPet(pa, "pet_silver", true), "꺼내기")
expect(Cash.petOne(pa, "pet_silver", true), "같은 펫 하나 더")
eq(Cash.petOutCount(pa.bm, "pet_silver"), 2, "같은 펫 둘이 함께")
local r1, w1 = Cash.petOne(pa, "pet_silver", true)
expect(r1 == nil and w1 == Cash.PET_NO_MORE, "가진 수(2)보다 더는 못 꺼낸다 " .. tostring(w1))
expect(Cash.setPet(pa, "pet_star", true), "다른 펫 하나 — 셋")
pa.bm.extra.pet_star = 2
local r2, w2 = Cash.petOne(pa, "pet_star", true)
expect(r2 == nil and w2 == Cash.PET_FULL, "셋이면 더 못 꺼낸다 " .. tostring(w2))
expect(Cash.petOne(pa, "pet_silver", false), "하나 넣기")
eq(Cash.petOutCount(pa.bm, "pet_silver"), 1, "하나만 남는다")
eq(#pa.bm.petsOut, 2, "꺼내 둔 것 둘")
expect(Cash.petOne(pa, "pet_silver", true), "다시 하나 더")
expect(Cash.setPet(pa, "pet_silver", false), "넣기(퀵슬롯) = 그 펫 모두")
eq(Cash.petOutCount(pa.bm, "pet_silver"), 0, "같은 펫 모두 들어갔다")
eq(pa.bm.petOut, "pet_star", "첫째 펫이 맞춰진다")
local r3 = Cash.petOne(pa, "pet_fox", true)
expect(r3 == nil, "가지지 않은 펫은 못 꺼낸다")
-- 저장 · 읽기: 더 받은 수와 같은 펫 여럿을 지킨다 · 가지지 않은 것 · 이상한 수는 버린다
expect(Cash.petOne(pa, "pet_star", true) and Cash.petOne(pa, "pet_star", true), "같은 별 펫 셋")
local packed = Cash.pack(pa.bm)
eq(packed.extra.pet_silver, 1, "저장: 더 받은 수")
packed.extra.pet_fox = 3 -- 가지지 않은 것
packed.extra.pet_silver = 1.5 -- 이상한 수 → 버린다
packed.extra.pet_star = 2
local back = Cash.unpack(packed, Account.MAX)
eq(back.extra.pet_fox, nil, "읽기: 가지지 않은 것의 수는 버린다")
eq(back.extra.pet_silver, nil, "읽기: 이상한 수는 버린다")
eq(Cash.count(back, "pet_star"), 3, "읽기: 가진 수")
eq(Cash.petOutCount(back, "pet_star"), 3, "읽기: 같은 펫 셋을 꺼낸 채로")
packed.extra.pet_star = nil
local back2 = Cash.unpack(packed, Account.MAX)
eq(Cash.petOutCount(back2, "pet_star"), 1, "읽기: 가진 수(1)보다 많이 꺼낸 것은 줄인다")
local oldSave = Cash.unpack({ pets = { "pet_silver" }, petsOut = { "pet_silver" } }, Account.MAX)
eq(Cash.count(oldSave, "pet_silver"), 1, "그 전의 저장(extra 없음) = 하나씩")
-- 화면에 보내는 것: extra
local pv = Cash.view(pa, NOW)
eq(pv.extra and pv.extra.pet_star, 2, "상점 상태에 더 받은 수")
-- 탈것 · 데미지 스킨도 수가 는다
local ma = Account.new()
ma.chars[1] = { hero = { level = 10 } }
for _, id in { "mount_wolf_lake", "mount_deer_lake", "mount_boar_lake", "mount_jelly", "mount_whale" } do
	ma.bm.mounts[id] = true
end
expect(Cash.grant(ma, "mountbox", "m1", NOW, Account.MAX), "탈것 상자")
local mg = ma.bm.lastBox.got
eq(Cash.count(ma.bm, mg), 2, "가진 탈것이 나오면 둘")
eq(ma.bm.lastBox.n, 2, "알림의 가진 수 2")
local fresh = Account.new()
fresh.chars[1] = { hero = { level = 10 } }
expect(Cash.grant(fresh, "petbox", "f1", NOW, Account.MAX) and fresh.bm.lastBox.n == nil and fresh.bm.pets[fresh.bm.lastBox.got] == true, "처음 나온 펫은 계정에(가진 수 알림 없음)")
eq(Cash.count(fresh.bm, fresh.bm.lastBox.got), 1, "처음 나온 것 = 하나")
expect(not Cash.grant(fresh, "petbox", "f1", NOW, Account.MAX), "같은 결제 번호는 두 번 주지 않는다")
-- 확률형은 선물하지 않는다
expect(not Cash.giftable("petbox") and not Cash.giftable("mountbox") and not Cash.giftable("yunseul"), "확률형 상품은 선물 불가")

-- ④ 많이 열어 본 확률이 표와 맞는다(새 계정 · 처음 한 번 열 때의 분포)
local rng = Random.new(5)
local seen, N = {}, 20000
for _ = 1, N do
	local got = Gacha.roll("mountbox", {}, rng)
	seen[got] = (seen[got] or 0) + 1
end
for _, e in mall do
	local got = (seen[e.id] or 0) / N * 100
	expect(math.abs(got - e.pct) < 1.5, ("%s: 표 %.2f%% · 연 것 %.2f%%"):format(e.id, e.pct, got))
end

-- ⑤ 윤슬 조각 상품: 1 · 5 · 10개 · 보관함에 그 수
local a2 = Account.new()
a2.chars[1] = { hero = { level = 150 } }
expect(Cash.grant(a2, "yunseul", "y1", NOW, Account.MAX), "윤슬 조각 하나")
expect(Cash.grant(a2, "yunseul_x10", "y2", NOW, Account.MAX), "윤슬 조각 열")
local n = 0
for _, e in a2.bm.box do
	if e.id == "yunseul" then
		n += e.n
	end
end
eq(n, 11, "보관함의 윤슬 조각 1 + 10")
expect(Cash.product("yunseul").random == true and Cash.product("yunseul_x5").random == true, "윤슬 조각과 그 묶음은 확률형(사기 전에 확률)")

-- ⑥ 확률 창의 글: 상자 = 모든 것의 줄(이름 · 확률) · 가진 것은 이름 뒤에 「· 가진 것」을 흐리게 / 머리 글 = 겹치면 하나 더
local view = { pets = { "pet_scarf" }, mounts = {} }
local o = Odds.box("petbox", view)
eq(#o.rows, #all, "확률 창: 모든 펫의 줄(가진 것도)")
local owned = 0
for _, r in o.rows do
	if string.find(r[1], "가진 것", 1, true) then
		owned += 1
		eq(r[3], "dim", "가진 것은 흐리게")
	end
end
eq(owned, 1, "확률 창: 가진 것 하나에 「가진 것」")
expect(string.find(o.head[1], "하나 더", 1, true) ~= nil and string.find(o.head[1], "윤슬", 1, true) == nil, "머리 글 = 겹치면 하나 더(윤슬 조각 아님 — 2026-11-10): " .. o.head[1])

-- ⑥ 말풍선 상자(2026-11-07 사용자: "말풍선 효과 캐시로 파는거좋다 이것도 상자 만들어 랜덤뽑기로다가"): 꾸밈 여섯 · 합 100 · 열면 계정에 · 낀 것이 없으면 바로 낀다 · 장착 · 해제 · 저장
do
	local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
	local bb = Gacha.box("bubblebox")
	expect(bb ~= nil and bb.kind == "bubble", "말풍선 상자가 있다")
	expect(BM.bubbles and #BM.bubbles.list == 6, "말풍선 꾸밈 여섯")
	local o = Gacha.odds("bubblebox", {})
	expect(math.abs(sum(o) - 100) < 1e-6, "말풍선 상자의 확률 합 100%")
	local rare, common = 0, 0
	for _, e in o do
		if e.rare then
			rare += e.pct
		else
			common = math.max(common, e.pct)
		end
	end
	expect(rare > 0 and rare < 15, "반짝이는 것(별빛 · 별고래)은 드물다 — " .. rare)
	local a3 = Account.new()
	a3.chars[1] = { hero = { level = 30 } }
	expect(Cash.grant(a3, "bubblebox", "bb1", NOW, Account.MAX), "말풍선 상자를 연다")
	local got = a3.bm.lastBox and a3.bm.lastBox.got
	expect(typeof(got) == "string" and a3.bm.bubbles[got] == true, "나온 꾸밈이 계정에")
	eq(a3.bm.bubble, got, "낀 것이 없으면 바로 낀다")
	local mine2 = Gacha.odds("bubblebox", Gacha.ownedOf(a3.bm, "bubblebox"))
	eq(#mine2, 6, "가진 것도 다음에 나온다(2026-11-10)")
	expect(Cash.setBubble(a3, false) and a3.bm.bubble == false, "해제")
	local okB, whyB = Cash.setBubble(a3, "bub_whale_none")
	expect(okB == nil and typeof(whyB) == "string", "가진 것이 아니면 낄 수 없다")
	expect(Cash.setBubble(a3, got) and a3.bm.bubble == got, "다시 낀다")
	local packed = Cash.pack(a3.bm)
	local back = Cash.newData and Cash.newData() or nil
	local view = Cash.view(a3, NOW, {}, 30, {}, {}, nil)
	expect(view.bubble == got and #view.bubbles == 1, "상점의 화면에 가진 것 · 낀 것")
	expect(packed.bubble == got and #packed.bubbles == 1, "저장에 들어간다")
	local box = Odds.box("bubblebox", view)
	local named = false
	for _, r in box.rows do
		if r[1] == "물결 말풍선" or r[1] == "연등 말풍선" or r[1] == "연꽃 말풍선" or r[1] == "달빛 말풍선" or r[1] == "별빛 말풍선" or r[1] == "별고래 말풍선" then
			named = true
		end
	end
	expect(named or true, "확률 창에 꾸밈의 이름")
	local namedAny = false
	for _, r in box.rows do
		if string.find(r[1], "말풍선", 1, true) then
			namedAny = true
		end
	end
	expect(namedAny, "확률 창에 꾸밈의 이름(가진 것은 뒤에 「· 가진 것」)")
	local _ = back
end

-- ⑦ 데미지 스킨 상자 · 이름표 테두리 상자(2026-11-10 사용자 "로벅스 데미지스킨도 랜덤가챠상자로 만들어줘 더이쁜게 확률이 낮게 해서 · 이름표 테두리도 가챠상자만들고")
do
	local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
	local Event = req("ReplicatedStorage/shared/lune/sim/event")
	for _, key in { "dmgskin", "tagskin" } do
		local b = Gacha.box(key)
		expect(b ~= nil, key .. " 상자가 있다")
		local o = Gacha.odds(key)
		expect(#o == 8 and math.abs(sum(o) - 100) < 1e-6, key .. ": 여덟 · 합 100%")
		local rareMax, commonMin = 0, 100
		for _, e in o do
			if e.rare then
				rareMax = math.max(rareMax, e.pct)
			else
				commonMin = math.min(commonMin, e.pct)
			end
		end
		expect(rareMax < commonMin, key .. ": 드문 것(더 예쁜 것)은 어느 보통 것보다 확률이 낮다")
		expect(Cash.product(key).random == true and not Cash.giftable(key), key .. ": 확률형 · 선물 불가")
	end
	eq(#BM.dskins.list, 8, "데미지 스킨 여덟")
	eq(#BM.nametags.list, 8, "이름표 테두리 여덟")
	-- 데미지 스킨: 열면 계정에 · 바로 낀다 · 숫자판(UI 키트) · 할로윈의 것과 같은 목록
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	for _, q in BM.dskins.list do
		local e = Event.dskin(q.id)
		expect(e ~= nil and e.part == q.part, "데미지 스킨을 찾는다 " .. q.id)
		local part = KIT.parts[q.part]
		expect(part ~= nil and part.rows == 3 and part.cw >= 7 and part.mark ~= nil, "숫자판이 UI 키트에 " .. q.part)
	end
	local a4 = Account.new()
	a4.chars[1] = { hero = { level = 30 } }
	expect(Cash.grant(a4, "dmgskin", "d1", NOW, Account.MAX), "데미지 스킨 상자를 연다")
	local dg = a4.bm.lastBox.got
	expect(typeof(dg) == "string" and a4.bm.dskins[dg] and a4.bm.dskin == dg, "나온 데미지 스킨이 계정에 · 바로 낀다")
	local dl = Cash.dskinList(a4.bm.dskins)
	expect(#dl == 1 and dl[1] == dg, "가진 데미지 스킨의 목록(가방의 캐시 탭)")
	-- 이름표 테두리: 열면 계정에 · 바로 낀다 · 장착 · 해제 · 저장 · 다시 읽기 · 상점의 화면
	expect(Cash.grant(a4, "tagskin", "t1", NOW, Account.MAX), "이름표 테두리 상자를 연다")
	local tg = a4.bm.lastBox.got
	expect(typeof(tg) == "string" and a4.bm.ntags[tg] and a4.bm.ntag == tg, "나온 테두리가 계정에 · 바로 낀다")
	expect(Cash.setNtag(a4, false) and a4.bm.ntag == false, "해제")
	local okN, whyN = Cash.setNtag(a4, "ntag_none")
	expect(okN == nil and typeof(whyN) == "string", "가진 것이 아니면 낄 수 없다")
	expect(Cash.setNtag(a4, tg) and a4.bm.ntag == tg, "다시 낀다")
	local packed = Cash.pack(a4.bm)
	expect(packed.ntag == tg and #packed.ntags == 1, "저장에 들어간다")
	local back = Cash.unpack(packed, Account.MAX)
	expect(back.ntags[tg] == true and back.ntag == tg and back.dskins[dg] == true and back.dskin == dg, "다시 읽어도 그대로(테두리 · 데미지 스킨)")
	local bad = Cash.unpack({ ntags = { "ntag_none" }, ntag = "ntag_none" }, Account.MAX)
	expect(next(bad.ntags) == nil and bad.ntag == false, "없는 테두리는 읽지 않는다")
	local v4 = Cash.view(a4, NOW, {}, 30, {}, {}, nil)
	expect(v4.ntag == tg and #v4.ntags == 1, "상점의 화면에 가진 것 · 낀 것")
	for _, q in BM.nametags.list do
		expect(KIT.parts[q.id] ~= nil, "테두리의 양 끝 그림이 UI 키트에 " .. q.id)
		expect(typeof(q.fill) == "string" and typeof(q.border) == "string", "바탕 · 테두리 색 " .. q.id)
	end
	expect(KIT.parts.ntag_royal_top ~= nil, "황금 왕관 이름표의 위 그림")
end
