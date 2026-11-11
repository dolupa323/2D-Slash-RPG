-- 「달의 계승자」 — 아이템 잠금(2026-11-11 사용자: "아이템 잠금기능 만들어줘 잠근거는 판매, 분해 이런거 적용안되게 인벤토리에서 잠글수있는기능을만들어줘").
--  sim/bag.luau(Bag.lock · sell · discard · dismantle · dismantleGoods · dismantleMany · sellMany · split · countFree · takeFree · 저장 · 화면) · sim/cash.luau(꺼낸 것의 선물).
--  보는 것: ① 잠그고 풀기 ② 잠긴 장비 = 팔기 · 분해 · 여러 개(건너뛴다) 안 됨 · 장착 · 옮기기는 됨 ③ 잠긴 묶음 = 팔기 · 버리기 · 분해 안 됨 · 쓰기(Bag.take)는 됨 · 나누면 나눈 것도 잠김
--   ④ 저장했다가 읽어도 잠금(장비 줄 10째 · 묶음 줄 3째 · 창고) ⑤ 화면에 보내는 꼴에 lock ⑥ 꺼낸 상자 결과물의 선물은 잠기지 않은 것에서만 ⑦ 글이 칸에 든다
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")

local h = Hero.new(1, "axion")
h.level = 30
local sword = Items.make("weapon", 10, 3, "axion")
local hat = Items.make("hat", 20, 2)
local shoes = Items.make("shoes", 20, 2)
local sSlot = Bag.add(h, sword)
local hSlot = Bag.add(h, hat)
Bag.add(h, shoes)
expect(sSlot and hSlot, "장비 셋을 넣었다")

-- ① 잠그고 풀기
expect(Bag.lock(h, "gear", sSlot, true), "장비를 잠근다")
expect(h.gear[sSlot].lock == true, "잠겼다")
expect(not Bag.lock(h, "gear", 99, true), "빈 칸 · 이상한 칸은 안 된다")
expect(not Bag.lock(h, "nope", 1, true), "없는 탭은 안 된다")

-- ② 잠긴 장비
local before = h.money
local r, why = Bag.sell(h, "gear", sSlot)
expect(r == nil and why == Bag.LOCKED and h.gear[sSlot] == sword and h.money == before, "잠긴 장비는 팔지 못한다")
local d, why2 = Bag.dismantle(h, sword.id)
expect(d == nil and why2 == Bag.LOCKED and h.gear[sSlot] == sword, "잠긴 장비는 분해하지 못한다")
local dustBefore = h.dust
local got, _, n = Bag.dismantleMany(h, { sword.id, hat.id })
expect(got and n == 1 and h.gear[sSlot] == sword and h.gear[hSlot] == false and h.dust > dustBefore, "여러 개 분해: 잠긴 것은 건너뛰고 나머지만")
local onlyLocked, whyOnly = Bag.dismantleMany(h, { sword.id })
expect(onlyLocked == nil and whyOnly == Bag.LOCKED, "잠긴 것뿐이면 「잠긴 물건이다」")
local sold, _, sn = Bag.sellMany(h, { sword.id, shoes.id })
expect(sold and sn == 1 and h.gear[sSlot] == sword, "여러 개 판매: 잠긴 것은 건너뛴다")
-- 옮기기 · 장착은 된다(잠금이 따라간다)
expect(Bag.move(h, "gear", sSlot, 20), "잠긴 장비도 옮긴다")
expect(h.gear[20] == sword and sword.lock == true, "옮겨도 잠김")
expect(Bag.equip(h, sword.id), "잠긴 장비도 낀다")
expect(h.equip.weapon == sword and sword.lock == true, "껴도 잠김")
expect(Bag.unequip(h, "weapon"), "벗는다")
local found, where, at = Bag.find(h, sword.id)
expect(found == sword and where == "gear" and sword.lock == true, "벗어도 잠김")
-- 풀면 판다
expect(Bag.lock(h, "gear", at, false) and sword.lock == nil, "잠금을 푼다")
expect(Bag.sell(h, "gear", at) ~= nil, "풀면 판다")

-- ③ 잠긴 묶음
local p0 = Bag.count(h, "potion1") -- (새 캐릭터는 물약을 들고 시작한다)
Bag.give(h, "potion1", 50)
local pSlot
for i = 1, Bag.size(h) do
	if h.use[i] and h.use[i].item == "potion1" then
		pSlot = i
	end
end
expect(Bag.lock(h, "use", pSlot, true), "물약 묶음을 잠근다")
expect(Bag.sell(h, "use", pSlot, 1) == nil, "잠긴 묶음은 팔지 못한다")
expect(Bag.discard(h, "use", pSlot, 1) == nil, "잠긴 묶음은 버리지 못한다")
local dg, whyDg = Bag.dismantleGoods(h, "use", pSlot, 50)
expect(dg == nil and whyDg == Bag.LOCKED, "잠긴 묶음은 분해하지 못한다")
eq(Bag.count(h, "potion1"), p0 + 50, "그대로(하나도 줄지 않았다)")
expect(Bag.take(h, "potion1", 1), "쓰기(덜어 내기)는 된다")
expect(Bag.split(h, "use", pSlot, 10), "나눈다")
local splitLocked = 0
for i = 1, Bag.size(h) do
	local s = h.use[i]
	if s and s.item == "potion1" and s.lock then
		splitLocked += s.n
	end
end
eq(splitLocked, p0 + 49, "나눈 것도 잠김(쓴 하나를 뺀 모두)")
eq(Bag.countFree(h, "potion1"), 0, "잠기지 않은 수 0")
expect(not Bag.takeFree(h, "potion1", 1), "잠긴 것에서는 덜어 내지 않는다(선물 같은 일)")

-- ④ 저장
local hat2 = Items.make("hat", 30, 3)
local h2Slot = Bag.add(h, hat2)
Bag.lock(h, "gear", h2Slot, true)
local row = Items.packRow(hat2)
eq(row[10], 1, "장비 줄 10째 = 잠금")
local data = Bag.pack(h)
local h3 = Hero.new(1, "axion")
h3.level = 30
Bag.unpack(h3, data) -- (돌려주는 값 = 옛 꼴이었나 — 성공 여부가 아니다)
local back = h3.gear[h2Slot]
expect(back and back.lock == true and back.q == hat2.q and back.stage == hat2.stage, "장비의 잠금이 저장된다")
local lockedStacks = 0
for i = 1, Bag.size(h3) do
	local s = h3.use[i]
	if s and s.item == "potion1" and s.lock then
		lockedStacks += 1
	end
end
eq(lockedStacks, 2, "묶음의 잠금이 저장된다")
local unlocked = Items.packRow(Items.make("hat", 30, 3))
eq(unlocked[10], nil, "잠기지 않은 장비의 줄은 그대로(10째 없음)")

-- ⑤ 화면에 보내는 꼴
local v = Bag.view(h3)
expect(v.gear[h2Slot].lock == true, "화면의 장비에 lock")
local sawStack = false
for i = 1, Bag.size(h3) do
	local s = v.use[i]
	if s and s.item == "potion1" and s.lock then
		sawStack = true
	end
end
expect(sawStack, "화면의 묶음에 lock")

-- ⑥ 꺼낸 상자 결과물의 선물: 잠기지 않은 것에서만
local acct = { bm = Cash.unpack(nil, 6) }
local hg = Hero.new(2, "riven")
Bag.give(hg, "bm_cos_pet_fox", 1)
local cSlot
for i = 1, Bag.size(hg) do
	if hg.use[i] and hg.use[i].item == "bm_cos_pet_fox" then
		cSlot = i
	end
end
Bag.lock(hg, "use", cSlot, true)
local okG, whyG = Cash.giftItemOut(acct, hg, "bm_cos_pet_fox", 9, "나", "R1", 1)
expect(not okG and whyG == Bag.LOCKED and Bag.count(hg, "bm_cos_pet_fox") == 1, "잠긴 것뿐이면 선물하지 못한다")
Bag.lock(hg, "use", cSlot, false)
expect(Cash.giftItemOut(acct, hg, "bm_cos_pet_fox", 9, "나", "R2", 1) and Bag.count(hg, "bm_cos_pet_fox") == 0, "풀면 보낸다")

-- ⑦ 글이 칸에 든다(상세 판의 단추 · 알림 — 한국어 · 영문)
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})
local L = req("ReplicatedStorage/shared/lune/ui/layout")
local Lang = req("ReplicatedStorage/shared/lune/lang")
local WORDS = req("ReplicatedStorage/shared/lune/data/ui.generated").words
for _, code in { "ko", "en" } do
	Lang.set(code)
	local tr = function(t)
		return if code == "en" then Lang.t(t) else t
	end
	for _, w in { WORDS.lock, WORDS.unlock } do
		local bw = (pixelText.Measure(tr(w), "body"))
		expect(bw <= L.detailButtonW(L.DETAIL.btnCols) - 6, ("%s: 단추 「%s」(폭 %d)"):format(code, tr(w), bw))
	end
	local lines = #string.split(pixelText.Wrap(tr(WORDS.lockNote), L.detailInner(), "small"), "\n")
	expect(lines <= L.DETAIL.noteLines, ("%s: 알림 「%s」이 %d줄 안에"):format(code, tr(WORDS.lockNote), L.DETAIL.noteLines))
end
Lang.set("ko")
