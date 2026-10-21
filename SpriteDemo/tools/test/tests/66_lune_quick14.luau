-- 「달의 계승자」 — 퀵슬롯 14칸 · 펫 · 탈것을 퀵슬롯에(2026-10-21 사용자: "중앙에 퀵슬롯도 몇개 늘어나야합니다" · 가방의 캐시 탭에서 펫 · 탈것).
--  보는 것: 칸 14 · 예전 칸 1~12의 키는 그대로(Ctrl Q A Shift W S / E D R F 1 2) · 새 칸 13 = X(아랫줄 끝) · 14 = 3(윗줄 끝) ·
--   예전에 저장된 12칸 배치가 그대로 읽힌다 · 펫 · 탈것의 이름표를 칸에 놓을 수 있다(서버의 Hero.setSlots) · 그림 = 달빛 상점의 그림(ride_<이름표>) · 윗줄이 쓰이는지는 줄의 표로
local Quick = req("ReplicatedStorage/shared/lune/ui/quick")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")

eq(Quick.N, 14, "퀵슬롯 14칸")
local old = { "LeftControl", "Q", "A", "LeftShift", "W", "S", "E", "D", "R", "F", "One", "Two" }
for i, k in old do
	eq(Quick.DATA.keys[i], k, "예전 칸 " .. i .. "의 키는 그대로")
end
eq(Quick.DATA.keys[13], "X", "칸 13 = X")
eq(Quick.DATA.keys[14], "Three", "칸 14 = 3")
expect(table.find(Quick.DATA.rows[1], 13) == 7 and table.find(Quick.DATA.rows[2], 14) == 7, "새 칸은 아랫줄 · 윗줄의 끝")

-- 펫 · 탈것
eq(Quick.ride("pet_silver"), "pet", "펫의 이름표")
eq(Quick.ride("mount_wolf"), "mount", "탈것의 이름표")
eq(Quick.ride("ax_slam"), nil, "스킬은 아니다")
eq(Quick.pic("pet_scarf"), "ride_pet_scarf", "칸의 그림 = 달빛 상점의 펫 그림")
eq(Quick.item("pet_scarf"), nil, "펫은 소비 아이템이 아니다(수를 적지 않는다)")

local h = Hero.new(1, "axion")
local saved = table.clone(h.slots)
local list = table.clone(h.slots)
list[13], list[14] = RIDE.pets[1].id, RIDE.mounts[1].id
expect(Hero.setSlots(h, list), "펫 · 탈것을 칸 13 · 14에 놓는다(서버가 받는다)")
eq(h.slots[13], RIDE.pets[1].id, "칸 13 = 펫")
eq(h.slots[14], RIDE.mounts[1].id, "칸 14 = 탈것")
expect(Quick.usesTop(h.slots), "칸 14(윗줄)에 놓이면 윗줄이 쓰인다")
local bad = table.clone(list)
bad[13] = "pet_nobody"
expect(not Hero.setSlots(h, bad), "없는 펫의 이름표는 받지 않는다")
-- 예전 저장(12칸)
local twelve = {}
for i = 1, 12 do
	twelve[i] = saved[i] or false
end
expect(Hero.setSlots(h, twelve), "예전 12칸 배치가 그대로 들어온다")
eq(h.slots[13], false, "늘어난 칸은 비어 있다")
eq(#h.slots, 14, "칸 수 = 14")

-- 스마트폰(2026-10-21 점검 — 사용자 "지금 추가한 모든 작업들 달빛상점이나 다른요소들 모바일에서도 정상동작하게"):
--  ① 폰의 칸 단추(tslots)에도 펫 · 탈것을 놓는다(서버의 TouchSlots = Hero.setSlots(…, true))
--  ② 단추 배치의 목록(touch.luau openChooser · Layout.touchChooser)에 가진 펫 · 탈것이 더해져도: 이름은 칸 아래 글자리(44+6 = 50점 · 두 줄)에 잘리지 않고,
--   판은 폰의 화면 틀(높이 432 — 왼쪽 위의 Roblox 단추가 가리는 만큼 뺀 것) 안에 서며(넘치는 줄은 민다) · 오른쪽 아래의 칸 단추를 덮지 않는다
local tl = table.clone(h.tslots)
tl[2], tl[3] = RIDE.pets[1].id, RIDE.mounts[1].id
expect(Hero.setSlots(h, tl, true), "폰의 단추에도 펫 · 탈것을 놓는다")
eq(h.tslots[2], RIDE.pets[1].id, "단추 2 = 펫")
eq(h.tslots[3], RIDE.mounts[1].id, "단추 3 = 탈것")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small_o", KIT.font.small_o, {}) -- 게임에서는 client/lune/ui/ui.luau가 등록한다
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local names = {}
for _, p in BM.products or BM.items or BM do
	if typeof(p) == "table" and p.id and Quick.ride(p.id) then
		names[p.id] = p.name
	end
end
for _, list in { RIDE.pets, RIDE.mounts } do
	for _, r in list do
		local name = names[r.id] or (r.free and r.name) -- 쿠폰으로만 받는 펫(까망 동글이 — 상품이 아니다 · 2026-10-21)은 펫 표의 이름
		expect(name ~= nil, r.id .. ": 상품의 이름이 있다(쿠폰 펫은 펫 표의 이름)")
		if name then
			local fit = pixelText.Fit(name, 50, 2)
			expect((string.gsub(fit, "\n", " ")) == name,("%s 「%s」: 폰 단추 목록의 이름이 두 줄(50점)에 잘리지 않는다 — 「%s」"):format(r.id, name, fit))
		end
	end
end
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local K = Layout.TOUCHCHOOSER
local leftmost = math.huge -- 칸 단추 가운데 가장 왼쪽(화면 틀의 점 — 게임 도트 x 2)
for _, t in UI.touch do
	if t.slot then
		leftmost = math.min(leftmost, t.x * 2)
	end
end
local few = Layout.touchChooser(7, 432)
expect(not few.scroll and few.viewH == 2 * few.rowH, "놓을 것이 일곱이면 두 줄 · 밀지 않는다")
local uses = 0
for _, g in Items.data.GOODS do
	if g.tab == "use" then
		uses += 1
	end
end
for who, c in CLASSES.classes do
	local ids = {}
	for _, t in c.tiers do
		for _, sk in t.skills do
			ids[sk.id] = true
		end
	end
	for _, sk in c.skills or {} do
		ids[sk.id] = true
	end
	local n = uses + #RIDE.pets + #RIDE.mounts
	for _ in ids do
		n += 1
	end
	for _, inset in { 0, 40 } do
		local m = Layout.touchChooser(n, 432 - inset)
		expect(K.top + m.h <= 432 - inset - K.bottom, ("%s: 놓을 것 %d개 — 판의 아래 끝 %d(화면 틀 %d 안)"):format(who, n, inset + K.top + m.h, 432))
		expect(m.scroll and m.viewH < m.contentH, who .. ": 다 보이지 않는 줄은 밀어서 본다")
		expect(K.x + m.w < leftmost, ("%s: 판의 오른쪽 끝 %d — 칸 단추(왼쪽 끝 %d)를 덮지 않는다"):format(who, K.x + m.w, leftmost))
	end
end
