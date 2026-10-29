-- 「달의 계승자」 — 대장장이 창(client/lune/ui/forgeWindow.luau — 2026-10-15)을 화면 없이 돌려 본다.
--  사용자: "대장장이에 상점이 있는게 문제임 상점 없어야함 제작, 강화만 하는곳임" · "강화에 드래그앤 드랍으로 둘수가 없음" · "제작 리스트에서 아이템 아이콘쪽 누르면 아이템 옵션이 나와야함" ·
--   "장착중인건 바로 강화할수가 없음" · "별을 옮겨올 장비는 … 없애고" · "강화가 아무런 연출없이 그냥 띡띡띡띢 이렇게 되면 안됩니다." · "아이템 이름 위에 별이 표기되는겁니다."
--  보는 것: 창이 폰 화면에 든다 · 탭 둘 · 제작의 그림을 누르면 상세(옵션 · 성능의 확률) · 「제작」 · 강화할 장비를 창 안에서 고른다(장착 중인 것 먼저 · 「장착」 표시) ·
--   강화 줄의 글(별 · 확률 · 오르는 옵션 · 실패하면 · 달가루)이 칸에 든다 · 「강화」 → 연출(망치 → 결과를 기다림 → 보임 → 끝) · 칸을 누르면 건너뛴다 · 끌어다 놓는 자리 ·
--   부서진 장비는 「되살리기」 · 별 옮기기는 없다 · 별 그림(이름 위)
local D = req("ReplicatedStorage/shared/lune/data/items.generated")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})

local made, buttons, tabs, starSets, hits = {}, {}, {}, {}, {}
local function frame(name)
	local f = { Name = name, Visible = true, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }
	function f:Destroy() end
	return f
end
local COLOR = setmetatable({}, { __index = function(_, k) return k end })
local function text(parent, value, x, y, width, opts)
	local t = { kind = "text", parent = parent, value = value, x = x, y = y, w = width, font = opts and opts.font or "small", shown = true, tint = opts and opts.color }
	function t.set(_, v) t.value = v end
	function t.color(_, c) t.tint = c end
	function t.move(_, nx, ny) t.x, t.y = nx, ny end
	function t.show(_, on) t.shown = on end
	t.label = { SetMaxWidth = function() end }
	table.insert(made, t)
	return t
end
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	M = Layout.M,
	measure = function(s, font) return (pixelText.Measure(s, font or "small")) end,
	group = function(parent, x, y, w, h, name) local f = frame(name); f.parent = parent; return f end,
	box = function() return frame("Box") end,
	line = function() return frame("Line") end,
	hit = function(parent) local h = { parent = parent, Activated = { Connect = function(_, fn) table.insert(hits, { parent = parent, fn = fn }) end } }; return h end,
	tab = function(parent, label, x, y, fn)
		local t = { frame = frame("Tab"), label = label, click = fn, width = pixelText.Measure(label, "small"), on = false }
		function t.setOn(_, on) t.on = on end
		tabs[label] = t
		return t
	end,
	text = text,
	button = function(parent, label, x, y, w, fn, opts)
		local b = { frame = frame("Button"), parent = parent, value = label, x = x, y = y, w = w, click = fn, enabled = true, main = opts and opts.main }
		function b.setEnabled(_, on) b.enabled = on end
		function b.setText(_, v) b.value = v end
		function b.setMain(_, on) b.main = on end
		table.insert(buttons, b)
		return b
	end,
	slot = function(parent, x, y, s)
		local it = { frame = frame("Slot"), x = x, y = y }
		it.frame.parent = parent
		function it.setOn() end
		return it
	end,
	smallIcon = function(parent, name, x, y) local f = frame("Icon"); f.icon = name; return f end,
	setWorldIcon = function(label, name) label.icon = name; label.Visible = name ~= nil end,
	scroll = function(parent, x, y, w, h, contentH, barW) local s = frame("Scroll"); s.CanvasSize = UDim2.fromOffset(0, contentH); s.ScrollBarThickness = barW; return s end,
	stars = function(parent, x, y, w)
		local s = { n = nil, max = nil }
		function s.set(_, n, max) s.n, s.max = n, max; table.insert(starSets, { n = n, max = max }) end
		return s
	end,
})
local cells = {}
MOCK("Client/lune/ui/itemCell", {
	size = function() return 50 end,
	icon = function(it) return "w_axe" end,
	color = function() return "tier2" end,
	label = function(it) return Items.name(it) end,
	starMark = function(n) return if n > 0 then "★" .. n else "" end,
	over = function(f, at) return at.X < 100 end,
	new = function(parent, x, y, onClick, s)
		local c = { frame = frame("Cell"), parent = parent, x = x, y = y, click = onClick }
		function c.set(_, it, o) c.item, c.o = it, o end
		table.insert(cells, c)
		return c
	end,
})
local shownDetail = nil
MOCK("Client/lune/ui/itemDetail", {
	show = function(owner, spec) shownDetail = { owner = owner, spec = spec } end,
	hide = function() shownDetail = nil end,
})

local Forge = req("Client/lune/ui/forgeWindow")
local w, h = Forge.size()
eq(w, Forge.W, "폭")
expect(w + 36 <= 768 and h + 64 <= 432, ("대장장이 창이 스마트폰의 화면 틀(768x432)에 들어간다 — %dx%d"):format(w, h))

-- 사람: Lv.30 액시온 · 장착한 차림(처음 받은 것) · 가방에 장비 둘 · 달가루 넉넉히 · 재료 넉넉히
local hero = Hero.new(1, "axion")
hero.level = 30
hero.dust, hero.money = 100000, 100000
local spare = Items.make("weapon", 20, 4, "axion")
Bag.add(hero, spare)
local hat = Items.make("hat", 20, 3)
Bag.add(hero, hat)
for _, r in D.RECIPES do
	for _, need in r.needs do
		if Bag.count(hero, need.item) == 0 then
			Bag.give(hero, need.item, 999)
		end
	end
end
local bag = Bag.view(hero)
local me = Hero.view(hero)
local sent = {}
local ui = { forgeSeq = 0 }
local ctx = {
	ui = ui,
	bag = function() return bag end,
	me = function() return me end,
	send = function(...) table.insert(sent, { ... }) end,
}
local body = frame("Body")
body.Parent = frame("Panel")
local view = Forge.build(body, ctx, w, h, "enhance")

-- ---- 1) 탭 둘 · 상점이 없다 ----
expect(tabs["제작"] ~= nil and tabs["강화"] ~= nil, "탭: 제작 · 강화")
for _, b in buttons do
	expect(b.value ~= "상점" and b.value ~= "별 옮기기", "상점 · 별 옮기기 단추가 없다 — " .. tostring(b.value))
end

-- ---- 2) 강화: 장착 중인 것이 먼저(「장착」) · 그 다음 가방 ----
local choices = Forge.choices(bag)
eq(#choices, 5 + 2, "장착한 다섯 + 가방의 둘")
for i = 1, 5 do
	expect(choices[i].worn, "앞의 다섯은 장착 중인 것")
end
expect(not choices[6].worn and not choices[7].worn, "그 뒤가 가방의 것")
-- 창 안의 칸들(스크롤 안): 「장착」 표시
local pickCells = {}
for _, c in cells do
	if c.parent and c.parent.Name == "Choices" then
		table.insert(pickCells, c)
	end
end
expect(#pickCells >= 7, "고를 칸이 모두 있다")
eq(pickCells[1].item, choices[1].it, "첫 칸 = 장착한 첫 장비")
-- 장착한 무기를 바로 고른다(장비 창을 열지 않아도 된다 — 사용자: "장착중인건 바로 강화할수가 없음")
local weapon = bag.equip.weapon
for i, c in pickCells do
	if c.item == weapon then
		c.click(c.item)
	end
end
eq(ui.forgeTarget, weapon.id, "장착한 무기가 올라갔다")
local function textAt(prefix)
	for _, t in made do
		if t.shown and typeof(t.value) == "string" and string.sub(t.value, 1, #prefix) == prefix then
			return t
		end
	end
	return nil
end
local line1 = textAt("★0 → ★1")
expect(line1 ~= nil, "「★0 → ★1」 — 별로 적는다(「+n」이 아니다)")
local now = Items.options(weapon).total.atk
local nextW = table.clone(weapon)
nextW.star = 1
local after = Items.options(nextW).total.atk
expect(textAt(("공격력 %d → %d"):format(now, after)) ~= nil, "오르는 옵션: 공격력 " .. now .. " → " .. after)
expect(textAt("달가루 ") ~= nil, "드는 달가루")
local last = starSets[#starSets]
expect(last and last.n == 0 and last.max == D.ENHANCE.max, "이름 위의 별: 0 / 22")
-- 강화 → 서버로
local go
for _, b in buttons do
	if b.value == "강화" and b.main then
		go = b
	end
end
expect(go and go.enabled, "「강화」를 누를 수 있다")
go.click()
local msg = sent[#sent]
expect(msg[1] == "Item" and msg[2] == "enhance" and msg[3] == weapon.id and msg[4] == false, "서버에 강화를 묻는다(장착한 무기 그대로)")
expect(view.animating(), "연출이 시작된다")
expect(not go.enabled, "연출 중에는 단추가 잠긴다")
-- 서버가 바로 정한다: 가방의 무기는 1성이 됐다 — 화면은 결과가 뜰 때까지 0성을 보인다
local real = table.clone(weapon)
real.star = 1
bag.equip.weapon = real
ui.forgeResult, ui.forgeSeq = "ok", ui.forgeSeq + 1
view.refresh()
expect(textAt("★0 → ★1") ~= nil, "결과가 뜨기 전에는 누르기 전의 별")
-- 첫 내려치기(0.05초) 전의 장(2026-10-21 퍼블리시한 게임의 오류 보고: forgeWindow:417 — STRIKES[0]으로 빼서 장마다 오류였다)
local okEarly, errEarly = pcall(view.step, 0.02)
expect(okEarly, "첫 내려치기 전의 장도 오류 없이 — " .. tostring(errEarly))
view.step(0.48)
expect(view.animating() and textAt("★0 → ★1") ~= nil, "망치를 내려치는 중")
view.step(0.6)
expect(textAt("★1 → ★2") ~= nil, "결과가 뜨면 새 별")
expect(textAt(Forge.RESULT.ok[1]) ~= nil, "결과 줄: " .. Forge.RESULT.ok[1])
local bigShown = false
for _, t in made do
	bigShown = bigShown or (t.shown and t.value == Forge.BIG.ok[1])
end
expect(bigShown, "칸 위에 크게 「강화 성공」")
view.step(1)
expect(not view.animating(), "연출이 끝난다")
expect(go.enabled, "끝나면 다시 누를 수 있다")
-- 건너뛰기: 칸을 누르면 결과로
go.click()
ui.forgeResult, ui.forgeSeq = "fail", ui.forgeSeq + 1
view.step(0.1)
local target
for _, c in cells do
	if c.parent and c.parent.Name == "Enhance" then
		target = c
	end
end
expect(target ~= nil, "올린 장비의 칸")
target.click(target.item)
view.step(0.01)
expect(textAt(Forge.RESULT.fail[1]) ~= nil, "칸을 누르면 건너뛰어 결과가 보인다")
view.step(1)
expect(not view.animating(), "건너뛴 뒤 끝난다")

-- ---- 3) 끌어다 놓는 자리 ----
expect(typeof(ui.forgeDrop) == "function", "가방의 장비를 끌어다 놓는 자리가 있다")
expect(ui.forgeDrop(Vector2.new(10, 10)) == true and ui.forgeDrop(Vector2.new(500, 10)) == false, "창 위에서만 받는다")
Forge.put(ui, spare.id, bag)
eq(ui.forgeTarget, spare.id, "놓은 장비가 올라간다")
eq(ui.forgeTab, "enhance", "강화 탭으로")

-- ---- 4) 부서진 장비: 되살리기(같은 장비를 하나 더) ----
local broken = Items.make("weapon", 20, 4, "axion")
broken.star, broken.broken = 12, true
Bag.add(hero, broken)
local twin = Items.make("weapon", 20, 2, "axion")
Bag.add(hero, twin)
bag = Bag.view(hero)
Forge.put(ui, broken.id, bag)
view.refresh()
eq(go.value, "되살리기", "부서진 장비는 「되살리기」")
expect(not go.enabled, "같은 장비를 고르기 전에는 누를 수 없다")
Forge.put(ui, twin.id, bag)
eq(ui.forgeMat, twin.id, "같은 장비를 고르면 재료로")
eq(ui.forgeTarget, broken.id, "부서진 것은 그대로")
view.refresh()
expect(go.enabled, "되살릴 수 있다")
go.click()
msg = sent[#sent]
expect(msg[2] == "restore" and msg[3] == broken.id and msg[4] == twin.id, "되살리기를 묻는다")
for _, m in sent do
	expect(m[2] ~= "transfer", "별 옮기기는 보내지 않는다")
end

-- ---- 5) 제작: 그림을 누르면 상세(옵션 · 성능의 확률) · 「제작」 ----
tabs["제작"].click()
view.refresh()
local craftHits = {}
for _, hh in hits do
	if hh.parent and hh.parent.Name == "Icon" then
		table.insert(craftHits, hh)
	end
end
expect(#craftHits >= 5, "제작 줄마다 그림을 누르는 자리")
craftHits[1].fn()
expect(shownDetail ~= nil and shownDetail.owner == "forge", "그림을 누르면 창 옆에 상세 판")
local info = shownDetail.spec.info
expect(string.find(info.notes[1][1], "만들면 성능", 1, true) == 1, "만들면 나오는 성능의 확률 — " .. tostring(info.notes[1][1]))
local hasOpt = false
for _, row in info.rows do
	hasOpt = hasOpt or row[1] == D.WORDS.atk or row[1] == D.WORDS.stat
end
expect(hasOpt, "옵션 줄(공격력 · 올스탯)")
eq(info.stars, 0, "만들 장비는 별이 없다")
table.clear(sent)
for _, b in buttons do
	if b.value == "제작" and b.frame.Visible then
		b.click()
	end
end
expect(#sent >= 1 and sent[1][2] == "craft", "「제작」은 레시피를 보낸다")

-- ---- 6) 강화 줄의 글이 칸에 든다(단계 · 별 · 파괴 방지) ----
local widest = 0
for _, stage in { 1, 10, 20, 30, 60, 100, 150, 180 } do
	for _, slot in { "weapon", "hat", "ring" } do -- (장신구 — 2026-10-28 방어구 · 장신구에도 공격력이 붙어 옵션 줄이 길어졌다)
		for star = 0, 22 do
			local it = Items.make(slot, stage, 5, "axion")
			it.star = star
			for _, guard in { false, true } do
				local info2 = Items.enhanceInfo(it, guard, false)
				for _, t in Forge.lines(it, info2, { dust = 99999999 }) do
					local tw = pixelText.Measure(t, "small")
					widest = math.max(widest, tw)
					expect(tw <= w, ("강화 줄이 칸에 든다 「%s」(%d)"):format(t, tw))
				end
			end
		end
	end
end
expect(widest > 100, "글을 재 보았다")
-- 모든 장비가 22성까지(장비별 상한이 없다)
local low = Items.make("weapon", 1, 3, "axion")
low.star = 21
expect(Items.enhanceInfo(low, false, false).can, "Lv.1 장비도 22성까지 붙일 수 있다")
low.star = 22
expect(not Items.enhanceInfo(low, false, false).can, "22성이 끝")
view.destroy()
eq(ui.forgeDrop, nil, "창을 닫으면 놓는 자리도 없어진다")

-- 공방(design/items.js 4-4 — 시험 탭의 대장장이 창)과 같은 글인가: 별 · 확률 · 오르는 옵션 · 실패하면 · 달가루(2026-10-15)
for _, c in D.checks.forge do
	local it = { slot = c[1].slot, stage = c[1].stage, q = c[1].q, star = c[1].star, who = c[1].who, broken = c[1].broken, fails = c[1].fails }
	local got = Forge.lines(it, Items.enhanceInfo(it, c[2], c[3]), { dust = c[4] })
	for i = 1, 4 do
		eq(got[i], c[5][i], ("강화 줄 %d이 공방과 같다(%s Lv.%d %d성)"):format(i, it.slot, it.stage, it.star))
	end
end
