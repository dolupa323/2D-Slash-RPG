-- 「달의 계승자」 — 상자 결과물을 경매장에 올리는 물건으로 꺼내고 · 써서 넣는다(2026-11-11 사용자: "뽑기상자에서 나온 부산물을 그냥 경매장에서 거래가능하도록하게해").
--  보는 것: ① 가진 수 -1(더 받은 수부터) · 가방 소비 탭에 bm_cos_<이름> ② 꺼내 둔 펫 · 끼고 있는 마지막 하나는 안 된다 ③ 가방이 차면 안 된다
--   ④ 쓰면 가진 수 +1(없던 것이면 계정에 · 낀 것이 없으면 바로 낀다) ⑤ 결제의 기록(log)에 cosout · cosin ⑥ 상자 다섯의 모든 것에 물건이 있다
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Gacha = req("ReplicatedStorage/shared/lune/sim/gacha")

local acct = { bm = Cash.unpack(nil, 6) }
local c = acct.bm
local h = Hero.new(1, "riven")

-- ⑥ 상자 다섯의 모든 것에 물건(bm_cos_<이름>)이 있다
local total = 0
for bid, b in Gacha.BOXES do
	for _, e in b.pool do
		local def = Items.goods("bm_cos_" .. e[1])
		expect(def ~= nil and def.kind == "bmCos" and def.box == bid and def.random == true, "물건이 있다: " .. e[1])
		total += 1
	end
end
eq(total, 34, "상자 다섯의 서른넷")

-- 펫 둘(하나 더 받은 것 1)
c.pets.pet_fox = true
c.extra = { pet_fox = 1 }
Cash.petOne(acct, "pet_fox", true)
eq(Cash.count(c, "pet_fox"), 2, "가진 수 2")
eq(Cash.petOutCount(c, "pet_fox"), 1, "하나를 꺼내 두었다")
local ok, why = Cash.cosOut(c, h, "pet_fox")
expect(ok == true, "꺼내 둔 것보다 많이 가졌으면 꺼낸다 " .. tostring(why))
eq(Cash.count(c, "pet_fox"), 1, "가진 수 1(더 받은 수부터 줄었다)")
expect(c.extra.pet_fox == nil and c.pets.pet_fox == true, "더 받은 수가 0이 되면 지운다 · 계정에는 남았다")
eq(Bag.count(h, "bm_cos_pet_fox"), 1, "가방 소비 탭에 하나")
ok, why = Cash.cosOut(c, h, "pet_fox")
expect(not ok and why == "꺼내 둔 펫이다 — 먼저 넣는다", "마지막 하나가 꺼내 둔 펫이면 안 된다")
Cash.setPet(acct, false)
ok = Cash.cosOut(c, h, "pet_fox")
expect(ok == true and Cash.count(c, "pet_fox") == 0 and not c.pets.pet_fox and Bag.count(h, "bm_cos_pet_fox") == 2, "넣은 뒤에는 마지막 하나도 꺼낸다 — 계정에서 빠졌다")
expect(not Cash.cosOut(c, h, "pet_fox"), "가진 것이 없으면 안 된다")

-- ④ 쓰면 들어간다
local def = Items.goods("bm_cos_pet_fox")
ok = Cash.use(h, acct, def)
expect(ok == true and c.pets.pet_fox == true and Cash.count(c, "pet_fox") == 1, "쓰면 계정에(가진 수 1)")
ok = Cash.use(h, acct, def)
expect(ok == true and Cash.count(c, "pet_fox") == 2, "가진 것이면 가진 수 +1")

-- ② 끼고 있는 마지막 하나(데미지 스킨)
c.dskins.dsk_aurora = true
c.dskin = "dsk_aurora"
ok, why = Cash.cosOut(c, h, "dsk_aurora")
expect(not ok and why == "끼고 있는 것이다 — 먼저 뺀다", "끼고 있는 마지막 하나는 안 된다")
c.extra.dsk_aurora = 1
ok = Cash.cosOut(c, h, "dsk_aurora")
expect(ok == true and Cash.count(c, "dsk_aurora") == 1 and c.dskin == "dsk_aurora", "둘이면 하나는 꺼낸다(낀 것 그대로)")

-- ③ 가방이 차면 안 된다
for i = 1, Bag.size(h) do
	if not h.use[i] then
		h.use[i] = { item = "potion1", n = 1 }
	end
end
c.mounts.mount_whale = true
ok, why = Cash.cosOut(c, h, "mount_whale")
expect(not ok and why == "가방에 자리가 없다" and c.mounts.mount_whale == true, "가방이 찼으면 안 된다(계정 그대로)")

-- ⑤ 결제의 기록
local outs, ins = 0, 0
for _, l in c.log or {} do
	if string.sub(l.k, 1, 7) == "cosout:" then
		outs += 1
	elseif string.sub(l.k, 1, 6) == "cosin:" then
		ins += 1
	end
end
eq(outs, 3, "기록 cosout 셋")
eq(ins, 2, "기록 cosin 둘")
expect(not Cash.cosOut(c, h, "pet_silver_nope"), "모르는 것은 안 된다")

-- ⑦ 글이 칸에 든다(한국어 · 영문): 가방 캐시 탭의 상세 판(client/lune/ui/bagWindow.luau의 알림 — 한 줄 · 쓰는 법 · 「꺼내 팔기」 안내)과 물건의 설명(상세 판 알림)
--  한 알림 두 줄까지 · 모두 여섯 줄까지(겹침 보상 안내 한 줄의 자리를 남겨 다섯) · 단추 「꺼내 팔기」가 셋씩 놓인 단추의 칸에(같은 펫 여럿 = 단추 넷 → 셋씩)
do
	local pixelText = req("Client/ui/pixelText")
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	pixelText.Register("small", KIT.font.small, {})
	pixelText.Register("body", KIT.font.body, {})
	local L = req("ReplicatedStorage/shared/lune/ui/layout")
	local Lang = req("ReplicatedStorage/shared/lune/lang")
	local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
	local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
	local BMW = BM.shop.words
	local K, W = L.DETAIL, L.detailInner()
	local function lines(t: string): number
		return if t == "" then 0 else #string.split(pixelText.Wrap(t, W, "small"), "\n")
	end
	local function lineOf(kind: string, id: string): string
		local lists = if kind == "pet" or kind == "mount" then { RIDE.pets, RIDE.mounts } elseif kind == "dskin" then { BM.dskins.list } elseif kind == "ntag" then { BM.nametags.list } else { BM.bubbles.list or {} }
		for _, list in lists do
			for _, q in list do
				if q.id == id then
					return q.line or ""
				end
			end
		end
		return ""
	end
	local HINT = { pet = BMW.bagHint, mount = BMW.rideHint, dskin = BMW.dskinHint, bubble = BM.bubbles.words.hint, ntag = BM.nametags.words.hint }
	for _, code in { "ko", "en" } do
		Lang.set(code)
		local tr = function(t: string): string
			return if code == "en" and t ~= "" then Lang.t(t) else t
		end
		for _, b in Gacha.BOXES do
			for _, e in b.pool do
				local total = 0
				for _, t in { lineOf(b.kind, e[1]), HINT[b.kind] or "", BMW.cosHint } do
					local n = lines(tr(t))
					total += n
					expect(n <= K.noteLines, ("%s %s: 캐시 탭 알림 「%s」이 %d줄 안에"):format(code, e[1], tr(t), K.noteLines))
				end
				expect(total <= 5, ("%s %s: 캐시 탭 알림이 모두 다섯 줄까지(%d)"):format(code, e[1], total))
				local def = Items.goods("bm_cos_" .. e[1])
				expect(lines(tr(def.text)) <= K.noteLines, ("%s %s: 물건의 설명 「%s」이 %d줄 안에"):format(code, e[1], tr(def.text), K.noteLines))
			end
		end
		local w = (pixelText.Measure(tr(BMW.cosOut), "body"))
		expect(w <= L.detailButtonW(K.btnCols) - 6, ("%s: 단추 「%s」(폭 %d)이 셋씩 놓인 단추의 칸(%d)에"):format(code, tr(BMW.cosOut), w, L.detailButtonW(K.btnCols) - 6))
	end
	Lang.set("ko")
end

-- ⑧ 꺼낸 것을 선물한다(2026-11-11 사용자: "꺼내팔기 한다음에 경매장에 거래가능하게만들면된다 선물하기도 가능하게") — 셈:
--  보내는 쪽 = 가방에서 하나를 빼고 「보낼 선물」(cos:<이름>) · 기록 / 받는 쪽 = 보관함에 그 물건 하나 · 같은 선물은 한 번 / 단추 「선물하기」가 칸에 든다
do
	local acct2 = { bm = Cash.unpack(nil, 6) }
	local h2 = Hero.new(2, "riven")
	expect(not Cash.giftItemOut(acct2, h2, "bm_cos_pet_fox", 9, "나", "R1", 1), "가방에 없으면 안 된다")
	expect(not Cash.giftItemOut(acct2, h2, "potion1", 9, "나", "R1", 1), "상자 결과물이 아니면 안 된다")
	Bag.give(h2, "bm_cos_pet_fox", 1)
	local ok = Cash.giftItemOut(acct2, h2, "bm_cos_pet_fox", 9, "나", "R1", 1)
	expect(ok and Bag.count(h2, "bm_cos_pet_fox") == 0 and acct2.bm.giftOut.k == "cos:pet_fox" and acct2.bm.giftOut.uid == 9, "가방에서 빼고 보낼 선물")
	local lg = acct2.bm.log[#acct2.bm.log]
	expect(lg and lg.k == "giftcos:pet_fox" and lg.r == "R1", "기록 giftcos")
	Bag.give(h2, "bm_cos_pet_fox", 1)
	expect(not Cash.giftItemOut(acct2, h2, "bm_cos_pet_fox", 9, "나", "R2", 1) and Bag.count(h2, "bm_cos_pet_fox") == 1, "앞의 선물을 넣는 중이면 안 된다(가방 그대로)")
	local rc = { bm = Cash.unpack(nil, 6) }
	expect(Cash.grant(rc, "cos:pet_fox", "gR1", 1, 6), "받는다")
	eq(rc.bm.box[1] and rc.bm.box[1].id, "bm_cos_pet_fox", "보관함에 그 물건")
	expect(not Cash.grant(rc, "cos:pet_fox", "gR1", 1, 6) and rc.bm.box[1].n == 1, "같은 선물은 한 번")
	expect(not Cash.grant(rc, "cos:nope", "gR2", 1, 6), "모르는 것은 받지 않는다")
	-- 단추 「선물하기」(가방 상세 판 — 셋씩 놓인 단추의 칸)
	local pixelText = req("Client/ui/pixelText")
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	pixelText.Register("body", KIT.font.body, {})
	pixelText.Register("small", KIT.font.small, {})
	local L = req("ReplicatedStorage/shared/lune/ui/layout")
	local Lang = req("ReplicatedStorage/shared/lune/lang")
	local BMW = req("ReplicatedStorage/shared/lune/data/bm.generated").shop.words
	for _, code in { "ko", "en" } do
		Lang.set(code)
		-- 뽑기 제한 계정의 선물하기 아래 줄(2026-11-11): 상점 창의 「모두 받기」 오른쪽 칸에 한 줄로
		local rn = if code == "en" then Lang.t(BMW.giftRandomNote) else BMW.giftRandomNote
		local rw = (pixelText.Measure(rn, "small"))
		expect(rw <= L.CASH.w - L.CASH.allW - 10, ("%s: 「%s」(폭 %d)이 아래 줄(%d)에"):format(code, rn, rw, L.CASH.w - L.CASH.allW - 10))
		local t = if code == "en" then Lang.t(BMW.giftItem) else BMW.giftItem
		local w = (pixelText.Measure(t, "body"))
		expect(w <= L.detailButtonW(L.DETAIL.btnCols) - 6, ("%s: 단추 「%s」(폭 %d)이 칸에"):format(code, t, w))
	end
	Lang.set("ko")
end
