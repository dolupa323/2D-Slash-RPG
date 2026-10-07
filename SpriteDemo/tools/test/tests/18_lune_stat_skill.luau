-- 「달의 계승자」 — 능력치의 설명(마우스를 올리면 뜨는 것) · 스킬 창의 차수 탭 · 스킬마다의 그림 · 대쉬 효과의 값.
--  사용자 2026-10-07: "능력치에 각각 스텟별로 마우스 올리면 호버로 스텟 효과를 보여줘야합니다" · "1,2,3,4 차 스킬 탭이있어야지" · "패시브든 뭐든 다 아이콘이 있는거에요" · "대쉬 이펙트가 바뀐거같은데"
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local ASSETS = req("ReplicatedStorage/shared/lune/data/assets.generated")
local F = req("ReplicatedStorage/shared/lune/ui/format")
local L = req("ReplicatedStorage/shared/lune/ui/layout")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local pixelText = req("Client/ui/pixelText")
pixelText.Register("small", KIT.font.small, {})

local STATS = N.data.STATS
local M = KIT.ui.metric
local G = UI.grid
local function small(text)
	return (pixelText.Measure(text, "small"))
end
local function bodyW(text)
	return (pixelText.Measure(text, "body"))
end

-- ---- 1) 능력치의 설명: 공방의 글과 같다 ----
do
	eq(F.fill("Lv.{lv}에 {job}차", { lv = 30, job = 2 }), "Lv.30에 2차", "글 채우기")
	eq(F.fill("{none}!", {}), "!", "없는 이름은 빈 글")
	eq(F.gain(0.1126), "0.11", "작은 값은 소수 두 자리")
	eq(F.gain(12.34), "12.3", "10부터는 소수 한 자리")
	eq(F.gain(345.6), "346", "100부터는 정수")
	expect(#UI.statTipCheck >= 8, "공방의 본보기가 있다")
	for _, row in UI.statTipCheck do
		local class, id, lv, kind, title, tag = row[1], row[2], row[3], row[4], row[5], row[6]
		local t = F.statTip(class, id, lv)
		local what = ("%s %s Lv.%d"):format(class, id, lv)
		eq(t.kind, kind, "갈래 " .. what)
		eq(t.title, title, "이름 " .. what)
		eq(t.tag, tag, "꼬리표 " .. what)
		eq(#t.lines, #row - 6, "줄 수 " .. what)
		for i, line in t.lines do
			eq(line, row[6 + i], ("%d째 줄 %s"):format(i, what))
		end
	end
end

-- ---- 2) 설명의 숫자가 실제 셈과 맞는다 ----
do
	for _, class in CLASSES.order do
		local pair = STATS.classes[class]
		for _, lv in { 1, 12, 30, 61, 100, 150 } do
			local gain = N.statGain(class, lv)
			-- 주 · 부 능력치: 그 레벨의 점수를 다 주 능력치에 넣은 것에서 50점을 덜어 냈다가 다시 넣으면 전투력이 50 x 설명의 값만큼 오른다(반올림 1 안에서)
			local h = Hero.new(1, class)
			h.level = lv
			local all = N.apAt(lv)
			if all >= 50 then
				h.stats[pair[1]] = all - 50
				local before = Hero.power(h)
				h.stats[pair[1]] = all
				expect(math.abs((Hero.power(h) - before) - 50 * gain.main) <= 1.01, ("%s Lv.%d: 주 능력치 50점 = 전투력 +%.2f"):format(class, lv, 50 * gain.main))
				h.stats[pair[1]] = all - 50
				h.stats[pair[2]] = 50
				expect(math.abs((Hero.power(h) - before) - 50 * gain.sub) <= 1.01, ("%s Lv.%d: 부 능력치 50점 = 전투력 +%.2f"):format(class, lv, 50 * gain.sub))
				-- 안 쓰는 능력치는 전투력을 바꾸지 않는다
				h.stats[pair[2]] = 0
				for _, id in STATS.order do
					if id ~= "hp" and id ~= pair[1] and id ~= pair[2] then
						h.stats[id] = 50
						eq(Hero.power(h), before, ("%s Lv.%d: 안 쓰는 능력치 %s는 전투력을 바꾸지 않는다"):format(class, lv, id))
						h.stats[id] = 0
					end
				end
			end
			-- 체력: 100점 = 최대 체력 + 100 x 설명의 값(반올림 1 안에서)
			expect(math.abs((N.hpOf(class, lv, 100) - N.hpOf(class, lv, 0)) - 100 * gain.hp) <= 1.01, ("%s Lv.%d: 체력 100점 = 최대 체력 +%.1f"):format(class, lv, 100 * gain.hp))
			expect(gain.main > gain.sub and gain.sub > 0 and gain.hp > 0, ("%s Lv.%d: 주 > 부 > 0"):format(class, lv))
		end
	end
end

-- ---- 3) 능력치 창과 설명 판의 자리 · 글이 칸 안에 ----
do
	local S, T = L.STAT, L.STAT.tip
	local bw, bh = L.statBody(#STATS.order)
	local winW, winH = bw + L.WIN.pad * 2, bh + L.WIN.head + L.WIN.foot
	local inner = T.w - T.pad * 2
	for _, g in { { "1080p", G.w, G.h }, { "가장 작은 격자", G.min.w, G.min.h } } do
		expect(L.WIN.top + winH <= g[3], "능력치 창이 화면 안(높이) " .. g[1])
		-- 설명 판은 창의 왼쪽에 붙는다: 화면 왼쪽 끝을 넘지 않는다
		expect(g[2] - L.WIN.edge - winW - T.gap - T.w >= 4, "설명 판이 화면 안(왼쪽) " .. g[1])
	end
	for _, id in STATS.order do
		expect(bodyW(STATS.names[id]) <= S.tagX - 4, "능력치 이름이 꼬리표 앞에서 끝난다 " .. id)
	end
	expect(S.plusW + 10 <= S.valueRight, "값과 + 단추 사이가 떨어져 있다")
	local tallest = 0
	for _, class in CLASSES.order do
		for _, id in STATS.order do
			for _, lv in { 1, 150 } do
				local t = F.statTip(class, id, lv)
				expect(bodyW(t.title) + 8 + small(t.tag) <= inner, ("제목과 꼬리표가 설명 판 안 %s %s"):format(class, id))
				local rows = 0
				for _, line in t.lines do
					local fitted = pixelText.Fit(line, inner, T.lines, "small")
					expect(not fitted:find("…", 1, true), ("설명이 잘리지 않는다 %s %s: %s"):format(class, id, line))
					for _, part in string.split(fitted, "\n") do
						rows += 1
						expect(small(part) <= inner, ("설명 줄이 판 안 %s %s"):format(class, id))
					end
				end
				tallest = math.max(tallest, T.pad * 2 + T.title + rows * T.line)
			end
		end
	end
	expect(L.WIN.top + L.WIN.head + S.top + (#STATS.order - 1) * S.row + tallest <= G.min.h, "맨 아랫줄의 설명 판도 가장 작은 화면 안")
end

-- ---- 4) 스킬 창: 차수 탭 넷 · 스킬마다 그림 · 글이 칸 안에 ----
do
	local K = L.SKILL
	local bw, bh, listW = L.skillBody()
	local winW, winH = bw + L.WIN.pad * 2, bh + L.WIN.head + L.WIN.foot
	expect(winW + L.WIN.edge * 2 <= G.min.w, "스킬 창이 가장 작은 화면 안(폭)")
	expect(L.WIN.top + winH <= G.min.h, "스킬 창이 가장 작은 화면 안(높이)")
	local nameW = K.colW - K.slot - 8 - K.plusW - 4
	local pics = KIT.parts.pics.icons
	local W = UI.skillWords
	-- 차수 탭: 로마 숫자(I · II · III · IV — "차"라는 말 없이. 사용자 2026-10-07)를 같은 폭의 칸에
	local tabsW = 0
	eq(#W.tabs, #CLASSES.jobs, "차수 탭의 글이 차수마다 하나")
	for _, j in CLASSES.jobs do
		local text = W.tabs[j.job]
		expect(text:match("^[IVX]+$") ~= nil, "차수 탭은 로마 숫자 " .. text)
		expect(bodyW(text) <= K.tabW - 4, "탭의 글이 탭의 칸 안 " .. text)
		tabsW += K.tabW + K.tabGap
	end
	expect(K.tabW >= 24, "탭이 누르기 쉬운 폭")
	expect(tabsW + small(F.fill(W.points, { n = 999 })) <= listW, "차수 탭과 스킬 포인트가 한 줄에")
	expect(small(W.auto) + 6 <= K.autoW, "「추천대로 찍기」가 단추 안")
	local total = 0
	for _, class in CLASSES.order do
		local c = CLASSES.classes[class]
		eq(#c.tiers, 4, "차수 넷 " .. class)
		local names = {}
		for i, t in c.tiers do
			eq(t.job, i, "차수의 차례 " .. class)
			eq(t.lv, CLASSES.jobs[i].lv, "차수가 열리는 레벨 " .. class)
			expect(#t.skills >= 6 and #t.skills <= K.cols * K.rows, ("%s %d차: 스킬 %d개가 칸(%d) 안"):format(class, i, #t.skills, K.cols * K.rows))
			for _, text in { F.fill(W.open, { job = t.job, lv = t.lv, n = #t.skills }), F.fill(W.locked, { job = t.job, lv = t.lv }) } do
				expect(small(text) <= listW - K.autoW - 8, "안내 줄이 단추 앞에서 끝난다: " .. text)
			end
			for _, sk in t.skills do
				total += 1
				names[sk.id] = sk.name
				expect(pics["skill_" .. sk.id] ~= nil, ("스킬마다 제 그림이 있다: %s %s(%s)"):format(class, sk.name, sk.id))
				expect(CLASSES.types[sk.type] ~= nil, "갈래의 이름이 있다: " .. sk.type)
				expect(bodyW(sk.name) <= nameW, ("스킬 이름이 칸 안: %s(%d > %d)"):format(sk.name, bodyW(sk.name), nameW))
				expect(small(("%s · Lv.%d / %d"):format(CLASSES.types[sk.type], sk.max, sk.max)) <= K.detailW - K.slot - 10, "갈래와 레벨이 설명 칸 안: " .. sk.name)
				local fitted = pixelText.Fit(sk.text, K.detailW, K.textLines, "small")
				expect(not fitted:find("…", 1, true), "스킬 설명이 잘리지 않는다: " .. sk.name)
				local rows = #string.split(fitted, "\n")
				expect(K.slot + 14 + rows * K.textLine + 6 + M.small <= bh, "설명과 그 아래 한 줄이 창 안: " .. sk.name)
				if sk.replaces then
					expect(names[sk.replaces] ~= nil, "잇는 기술이 앞 차수에 있다: " .. sk.name)
					expect(small(F.fill(W.replaces, { name = names[sk.replaces] })) <= K.detailW, "잇는 기술의 글이 설명 칸 안: " .. sk.name)
				end
			end
		end
		-- 1차 탭의 스킬 = 게임이 지금 쓰는 스킬 목록
		eq(#c.tiers[1].skills, #c.skills, "1차 탭 = 1차 스킬 " .. class)
		for i, sk in c.skills do
			eq(c.tiers[1].skills[i].id, sk.id, "1차 스킬의 차례 " .. class)
		end
	end
	expect(total >= 150, ("스킬 %d개에 모두 그림이 있다"):format(total))
	for _, name in { "menu_bag", "menu_equip", "menu_stat", "menu_skill", "menu_quest", "menu_gear", "slot_potion" } do
		expect(pics[name] ~= nil, "늘 보이는 화면의 그림 " .. name)
	end
	expect(KIT.parts.uTip ~= nil, "설명 판의 부품")
end

-- ---- 5) 대쉬의 효과: 값과 그림이 있다 ----
do
	local D = COMBAT.fx.dash
	expect(D.ghost.every > 0 and D.ghost.life > D.ghost.every and D.ghost.alpha > 0 and D.ghost.alpha <= 1, "잔상의 값")
	expect(D.streak.life > 0 and D.streak.w > 0 and D.streak.h > 0 and D.streak.perSpeed > 0 and D.streak.lenPerSpeed > 0, "속도선의 값")
	eq(#CHARS.masks, #CHARS.pages, "실루엣 판이 캐릭터 판마다 하나")
	for _, name in CHARS.masks do
		expect((ASSETS[name] or "") ~= "", "실루엣 판을 올렸다 " .. name)
	end
	local moves = 0
	for id, def in COMBAT.skills do
		if def.type == "move" then
			moves += 1
			local tone = CLASSES.classes[def.who].tone
			expect(COMBAT.fx.tones[tone] ~= nil and #COMBAT.fx.tones[tone].n == 3 and #COMBAT.fx.tones[tone].l == 3, "직업 색이 있다 " .. id)
			-- 가는 동안 잔상이 적어도 둘은 남는다 · 속도선은 셋 이상
			expect(def.dist / def.speed / D.ghost.every >= 2, ("대쉬 %s: 잔상이 둘 이상(%.1f)"):format(id, def.dist / def.speed / D.ghost.every))
			expect(math.floor(D.streak.base + def.speed / D.streak.perSpeed + 0.5) >= 3, "속도선이 셋 이상 " .. id)
		end
	end
	eq(moves, #CLASSES.order, "직업마다 대쉬 하나")
end

-- ---- 6) 퀵슬롯: 칸에 놓는 셈 · 서버가 받는 꼴 · 저장 ----
--  사용자 2026-10-07: "스킬키를 단축키에 등록하기 쉬워야합니다 … 드래그앤 드랍으로 배치도 되어야하고 … 퀵슬롯을 누르면 배치된다던가"
do
	local Quick = req("ReplicatedStorage/shared/lune/ui/quick")
	local QD = UI.quick
	eq(Quick.N, L.SKILLS.cols * L.SKILLS.rows, "퀵슬롯의 수 = 스킬 칸의 수")
	eq(#QD.keys, Quick.N, "칸마다 기본 키 하나")
	eq(#QD.labels, Quick.N, "칸마다 딱지의 글 하나")
	local seenKey = {}
	for i, name in QD.keys do
		expect(not seenKey[name], "칸의 기본 키가 겹치지 않는다 " .. name)
		seenKey[name] = true
		expect(small(F.keyShort(name)) + 8 <= L.SKILLS.slot + L.SKILLS.gap - 2, "키 딱지가 옆 칸의 딱지와 붙지 않는다 " .. name)
		eq(F.keyShort(name), QD.labels[i], "딱지에 적히는 글이 공방의 것과 같다 " .. name)
	end
	-- 창을 여는 키 · 줍기와 겹치지 않는다
	for _, w in UI.windows do
		expect(not w.key or not seenKey[w.key], "퀵슬롯의 키가 창의 키와 겹치지 않는다 " .. tostring(w.key))
	end
	expect(not seenKey.Z and not seenKey.Space and not seenKey.Up, "퀵슬롯의 키가 기본 동작의 키와 겹치지 않는다")
	-- 열두 칸의 자리가 스킬 칸 틀 안이고 서로 겹치지 않는다
	local sw, sh = UI.hud.skills.w, UI.hud.skills.h
	local spots = {}
	for i = 1, Quick.N do
		local x, y = L.slotPlace(i, Quick.N)
		expect(x >= 0 and x + L.SKILLS.slot <= sw and y - L.SKILLS.keyUp >= 0 and y + L.SKILLS.slot <= sh, "칸과 키 딱지가 스킬 칸 틀 안 " .. i)
		for _, o in spots do
			expect(math.abs(o.x - x) >= L.SKILLS.slot or math.abs(o.y - y) >= L.SKILLS.slot + L.SKILLS.keyUp, "칸끼리 겹치지 않는다 " .. i)
		end
		table.insert(spots, { x = x, y = y })
	end
	expect(small(QD.words.pick) <= sw, "안내 글이 스킬 칸 틀 안")
	for _, key in { "hint", "armed", "none", "passive", "unlearned", "later" } do
		expect(small(QD.words[key]) <= L.SKILL.detailW, "퀵슬롯의 글이 설명 칸 안: " .. QD.words[key])
	end
	expect(small(F.fill(QD.words.at, { key = "Shift" })) <= L.SKILL.detailW, "「퀵슬롯 Shift」가 설명 칸 안")

	-- 공방의 셈과 같다(공방이 놓아 본 본보기)
	local function same(a, b): boolean
		if a == false or b == nil or a == nil then
			return (a == false or a == nil) and (b == nil or b == false)
		end
		for i = 1, Quick.N do
			if (a[i] or false) ~= (b[i] or false) then
				return false
			end
		end
		return true
	end
	expect(#QD.check >= 10, "공방의 본보기가 있다")
	for n, row in QD.check do
		local from, op, what, j, want = row[1], row[2], row[3], row[4], row[5]
		local got = if op == "place" then Quick.place(from, what, j) else Quick.clear(from, j)
		expect(same(want, got), ("공방의 본보기 %d(%s %s → %d)와 같다"):format(n, op, what, j))
	end

	-- 새 캐릭터: 물약 · 사냥기 · 보스기 · 이동기가 첫 네 칸에
	for _, class in CLASSES.order do
		local h = Hero.new(1, class)
		eq(#h.slots, Quick.N, "칸의 수 " .. class)
		eq(h.slots[1], "potion", "첫 칸은 물약 " .. class)
		for k = 2, 4 do
			local def = COMBAT.skills[h.slots[k]]
			expect(def ~= nil and def.who == class and def.type == QD.start[k], ("%d째 칸은 %s %s"):format(k, QD.start[k], class))
		end
		for k = 5, Quick.N do
			eq(h.slots[k], false, "나머지는 빈 칸 " .. class)
		end
		-- 자리를 바꾸는 것은 받는다
		local moved = Quick.place(h.slots, h.slots[2], 7)
		expect(Hero.setSlots(h, moved) and h.slots[7] == moved[7] and h.slots[2] == false, "칸을 옮긴 것을 받는다 " .. class)
		-- 저장했다가 되살리면 그대로다
		local back = Hero.unpack(1, Hero.pack(h))
		expect(back ~= nil and same(back.slots, h.slots), "저장한 칸들이 되살아난다 " .. class)
		-- 말이 안 되는 것은 받지 않는다(예전 칸들이 그대로다)
		local keep = table.clone(h.slots)
		-- 물약도 칸에서 뺄 수 있다(가방의 소비 탭에서 다시 끌어다 놓는다 — 사용자 2026-10-07). 두 칸에 놓을 수는 없다
		local noPotion = Quick.clear(h.slots, 1)
		expect(noPotion ~= nil and Hero.setSlots(h, noPotion) and h.slots[1] == false, "물약을 뺀 칸들도 받는다")
		local again = Quick.place(h.slots, "potion", 9)
		expect(again ~= nil and Hero.setSlots(h, again) and h.slots[9] == "potion", "가방에서 끌어다 다른 칸에 다시 놓는다")
		expect(Hero.setSlots(h, keep), "처음 배치로 되돌린다")
		local bad = table.clone(keep)
		bad[12] = "potion"
		expect(not Hero.setSlots(h, bad), "물약을 두 칸에 놓은 것은 받지 않는다")
		bad = table.clone(keep)
		bad[3] = "no_such_skill"
		expect(not Hero.setSlots(h, bad), "없는 스킬은 받지 않는다")
		bad = table.clone(keep)
		bad[5] = keep[4]
		expect(not Hero.setSlots(h, bad), "같은 스킬을 두 칸에 놓은 것은 받지 않는다")
		bad = table.clone(keep)
		bad[Quick.N + 1] = "potion"
		expect(not Hero.setSlots(h, bad), "칸이 더 많은 것은 받지 않는다")
		expect(not Hero.setSlots(h, "potion") and not Hero.setSlots(h, nil), "꼴이 다른 것은 받지 않는다")
		for other, def in COMBAT.skills do
			if def.who ~= class then
				bad = table.clone(keep)
				bad[6] = other
				expect(not Hero.setSlots(h, bad), "다른 직업의 스킬은 받지 않는다")
				break
			end
		end
		expect(same(h.slots, keep), "받지 않은 뒤에도 칸들이 그대로다 " .. class)
		-- 스마트폰의 단추 배치(tslots): PC의 퀵슬롯과 따로 저장한다 — 처음 차림은 같고, 한쪽을 바꿔도 다른 쪽은 그대로다
		expect(same(h.tslots, Quick.start(CLASSES.classes[class].skills)), "스마트폰 배치의 처음 차림 " .. class)
		local tmoved = Quick.place(h.tslots, h.tslots[2], 9)
		expect(Hero.setSlots(h, tmoved, true) and h.tslots[9] == tmoved[9] and h.tslots[2] == false, "스마트폰 배치를 바꾼 것을 받는다 " .. class)
		expect(same(h.slots, keep), "스마트폰 배치를 바꿔도 PC의 퀵슬롯은 그대로다 " .. class)
		expect(not Hero.setSlots(h, { "potion", "no_such_skill" }, true) and same(h.tslots, tmoved), "스마트폰 배치도 없는 스킬은 받지 않는다 " .. class)
		local tback = Hero.unpack(1, Hero.pack(h))
		expect(tback ~= nil and same(tback.tslots, h.tslots) and same(tback.slots, h.slots), "두 배치가 따로 저장되고 되살아난다 " .. class)
		eq(Hero.view(h).tslots, h.tslots, "스마트폰 배치가 내 상태에 실려 간다 " .. class)
	end
	-- 퀵슬롯이 생기기 전에 저장된 캐릭터는 처음 차림을 받는다
	local old = Hero.pack(Hero.new(1, "axion"))
	old.slots = nil
	local revived = Hero.unpack(1, old)
	expect(revived ~= nil and revived.slots[1] == "potion" and COMBAT.skills[revived.slots[2]] ~= nil, "칸이 없던 저장도 처음 차림으로 되살아난다")
	old.slots = { "potion", "no_such_skill" }
	revived = Hero.unpack(1, old)
	expect(revived ~= nil and revived.slots[1] == "potion" and COMBAT.skills[revived.slots[2]] ~= nil, "깨진 칸들도 처음 차림으로 되살아난다")
end

-- ---- 7) 스킬을 올리거나 능력치를 찍으면 실제 한 타의 피해가 오른다 ----
--  사용자 2026-10-07: "스킬을찍거나, 스텟이 증가했을때 데미지가 증가하고있는지 확인하세요"
--  진짜 싸움의 셈(Room:skillHit)으로 여러 번 때려 평균을 본다. 피해 = 전투력(반올림 전) x 그 타의 배수 x 스킬 레벨의 세기(Lv.1에서 0.4, 마스터에서 1) x 흔들림(±10%)
do
	local SCENES7 = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local function average(h, id: string, n: number): number
		local room = Room.new("hunt", SCENES7.scenes.hunt, Random.new(3))
		local mob = nil
		for _, m in room.mobs do
			mob = m
			break
		end
		local def = COMBAT.skills[id]
		local sum, count = 0, 0
		for _ = 1, n do
			mob.hp, mob.maxHp, mob.state = 1e9, 1e9, "idle"
			for _, hit in room:skillHit(h, def.hits[1], mob.x - 10, mob.y, 1, Hero.scale(h, id)).hits do
				sum += hit.dmg
				count += 1
			end
		end
		expect(count == n, "때릴 때마다 맞는다 " .. id)
		return sum / math.max(1, count)
	end
	for _, class in CLASSES.order do
		local pair = STATS.classes[class]
		-- 그 직업의 사냥기
		local mobSkill = nil
		for id, def in COMBAT.skills do
			if def.who == class and def.type == "mob" then
				mobSkill = id
			end
		end
		expect(mobSkill ~= nil, "사냥기가 있다 " .. class)
		local max = Hero.skillDef(class, mobSkill).max
		for _, lv in { 2, 12, 30 } do
			local h = Hero.new(1, class)
			h.level = lv
			-- 스킬 레벨: 한 레벨마다 평균 피해가 오른다. 마스터는 Lv.1의 2.5배(0.4 → 1)
			local prev, first = 0, 0
			for sl = 1, max do
				h.skills[mobSkill] = sl
				local a = average(h, mobSkill, 400)
				expect(a > prev, ("%s Lv.%d: %s Lv.%d의 평균 피해 %.2f가 Lv.%d의 %.2f보다 크다"):format(class, lv, mobSkill, sl, a, sl - 1, prev))
				prev = a
				if sl == 1 then
					first = a
				end
			end
			expect(prev / first > 2.2 and prev / first < 2.8, ("%s Lv.%d: 마스터의 피해가 Lv.1의 2.5배쯤(%.2f배)"):format(class, lv, prev / first))
			-- 능력치: 주 능력치를 1점씩 찍을 때마다 평균 피해가 오른다(반올림에 묻히지 않는다). 부 능력치도 오르고, 안 쓰는 능력치는 그대로다
			h.skills[mobSkill] = max
			local base = average(h, mobSkill, 1500)
			local last = base
			for pts = 1, 5 do
				h.stats[pair[1]] = pts
				local a = average(h, mobSkill, 1500)
				expect(a > last, ("%s Lv.%d: 주 능력치 %d점째에도 평균 피해가 오른다(%.2f → %.2f)"):format(class, lv, pts, last, a))
				last = a
			end
			h.stats[pair[1]] = 0
			h.stats[pair[2]] = 5
			expect(average(h, mobSkill, 1500) > base, ("%s Lv.%d: 부 능력치 5점에도 평균 피해가 오른다"):format(class, lv))
			h.stats[pair[2]] = 0
			for _, id in STATS.order do
				if id ~= "hp" and id ~= pair[1] and id ~= pair[2] then
					h.stats[id] = 50
					eq(average(h, mobSkill, 300), average(Hero.new(1, class) and (function()
						local z = Hero.new(1, class)
						z.level = lv
						z.skills[mobSkill] = max
						return z
					end)(), mobSkill, 300), ("%s Lv.%d: 안 쓰는 능력치 %s는 피해를 바꾸지 않는다"):format(class, lv, id))
					h.stats[id] = 0
				end
			end
		end
	end
end

-- ---- 8) 사냥기는 일반 몬스터에게, 보스기는 보스에게 제 힘을 낸다 ----
--  사용자 2026-10-07: "보스기는 보스 공격시 추가데미지, 사냥기는 일반 몹 공격시 추가 데미지 이런식이라도 있어야지 지금 그냥 보스기로 사냥하는게 더빠른현상이 생깁니다"
do
	local SCENES8 = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local RULES = COMBAT.rules
	expect(RULES.targetBonus > 0, "쓰임의 보정이 있다")
	local off = 1 / (1 + RULES.targetBonus / 100)
	-- 한 타: 같은 타를 일반 몬스터 · 보스(시험용으로 그 졸개를 보스로 친다)에게 갈래를 바꿔 가며 때려 평균을 본다
	local function average(h, hit, kind: string?, boss: boolean): number
		local room = Room.new("hunt", SCENES8.scenes.hunt, Random.new(9))
		local mob = nil
		for _, m in room.mobs do
			mob = m
			break
		end
		mob.def = setmetatable({ boss = boss }, { __index = mob.def })
		local sum, n = 0, 600
		for _ = 1, n do
			mob.hp, mob.maxHp, mob.state = 1e9, 1e9, "idle"
			sum += room:skillHit(h, hit, mob.x - 10, mob.y, 1, 1, nil, kind).hits[1].dmg
		end
		return sum / n
	end
	local h = Hero.new(1, "axion")
	h.level = 30
	h.stats.str = N.apAt(30)
	local hit = { box = { -40, 40, 60, 10 }, mul = 1 }
	local plain = average(h, hit, nil, false)
	local function near(a: number, b: number): boolean
		return math.abs(a / b - 1) < 0.02
	end
	expect(near(average(h, hit, "mob", false), plain), "사냥기는 일반 몬스터에게 제 피해")
	expect(near(average(h, hit, "mob", true), plain * off), "사냥기는 보스에게 덜 든다")
	expect(near(average(h, hit, "boss", true), plain), "보스기는 보스에게 제 피해")
	expect(near(average(h, hit, "boss", false), plain * off), "보스기는 일반 몬스터에게 덜 든다")
	expect(near(average(h, hit, "move", false), plain) and near(average(h, hit, "move", true), plain), "다른 갈래는 그대로")
	-- 일반 몬스터 한 마리를 칠 때: 사냥기가 보스기보다 느리지 않다(같은 시간의 피해 — 사냥기 mobShare vs 보스기 1 / (1 + 보정))
	expect(RULES.mobShare >= off, ("일반 몬스터는 사냥기로 잡는 것이 느리지 않다(%.2f ≥ %.2f)"):format(RULES.mobShare, off))
	-- 스킬 창에 적는 글
	local K8 = L.SKILL
	for _, key in { "mob", "boss" } do
		expect(small(F.fill(UI.skillWords.bonus[key], { pct = RULES.targetBonus })) <= K8.detailW, "쓰임의 글이 설명 칸 안 " .. key)
	end
	-- 설명 · 그 아래 한 줄 · 퀵슬롯의 두 줄이 서로 겹치지 않는다(가장 긴 설명으로)
	local _, bh = L.skillBody()
	for _, class in CLASSES.order do
		for _, t in CLASSES.classes[class].tiers do
			for _, sk in t.skills do
				local rows = #string.split(pixelText.Fit(sk.text, K8.detailW, K8.textLines, "small"), "\n")
				local top = K8.slot + 14 + (if UI.skillWords.bonus[sk.type] then K8.textLine else 0)
				expect(top + rows * K8.textLine + 6 + M.small <= bh - M.small - 16 - 4, "설명이 퀵슬롯의 줄과 겹치지 않는다: " .. sk.name)
			end
		end
	end
end

-- ---- 9) 퀘스트: 무엇을 어디서 잡아야 하는지 적는다 ----
--  사용자 2026-10-07: "뭘잡아야 갑옷조각이 나오는지를 자연스럽게 적어둬야 퀘스트를 진행할거아닙니까"
do
	local Q9 = req("ReplicatedStorage/shared/lune/sim/quests")
	local SCENES9 = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	eq(Q9.josa("검병", "을", "를"), "을", "받침이 있으면 을")
	eq(Q9.josa("박쥐", "을", "를"), "를", "받침이 없으면 를")
	eq(Q9.josa("Boss", "을", "를"), "을", "한글이 아니면 을")
	local seen = 0
	for _, def in Q9.list do
		for _, step in def.steps do
			local hint = Q9.stepHint(def, step)
			local mob = COMBAT.mobs[step.mob]
			expect(mob ~= nil, "할 일의 졸개가 있다 " .. def.id)
			if def.scene then
				expect(hint:find(SCENES9.scenes[def.scene].name, 1, true) ~= nil, "어디인지 적는다: " .. hint)
			end
			if step.type == "gather" then
				seen += 1
				expect(hint:find(mob.name, 1, true) ~= nil and hint:find("잡으면", 1, true) ~= nil, "무엇을 잡아야 하는지 적는다: " .. hint)
				expect(Q9.trackText(step, 0):find(mob.name, 1, true) ~= nil, "알리미에도 졸개의 이름이 있다: " .. Q9.trackText(step, 0))
				expect(small(Q9.trackText(step, step.n)) <= UI.hud.quest.w, "알리미의 줄이 칸 안: " .. Q9.trackText(step, step.n))
			end
			expect(small(hint) <= 300, "길잡이가 퀘스트 창의 폭 안: " .. hint)
		end
	end
	expect(seen >= 3, "모으는 일마다 길잡이가 있다")
	local def = Q9.def("r1m3")
	eq(#Q9.hints({ r1m3 = { done = false, c = {} } }, "r1m3"), #def.steps, "하지 못한 일마다 한 줄")
	eq(#Q9.hints({ r1m3 = { done = false, c = { def.steps[1].n } } }, "r1m3"), 0, "다 한 일의 길잡이는 빠진다")
end

-- ---- 10) 딜레이 · 타수 · 퍼뎀: 붙어 있는 적 한 마리가 설계한 피해를 다 받는가, 사냥기와 보스기의 빠르기 ----
--  사용자 2026-10-07: "공속 딜레이랑 타수랑 퍼뎀 정확히 계산해야지 … 대지강타로 몬스터 잡는거보다 삼단베기로 잡는게 훨씬빠른데?"
--  (대지 강타의 가시가 바로 앞의 적을 못 맞혀 설계의 70%만 들어가던 것을 이 검사가 잡는다)
do
	local SCENES10 = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local RULES = COMBAT.rules
	local DPS = N.data.POWER.dps
	local bonus = 1 + RULES.targetBonus / 100
	-- 진짜 싸움의 셈으로 기술 한 번(모든 타)을 d만큼 앞에 선 일반 몬스터 한 마리에게 쓴다 → 전투력 1에 대한 피해의 합(흔들림 · 배율을 걷어 낸 값)
	local function cast(h, id: string, d: number): (number, number)
		local def = COMBAT.skills[id]
		local sum, landed, n = 0, 0, 200
		for trial = 1, n do
			local room = Room.new("hunt", SCENES10.scenes.hunt, Random.new(trial))
			local mob = nil
			for _, m in room.mobs do
				mob = m
				break
			end
			for _, other in room.mobs do
				if other ~= mob then
					other.state = "gone" -- 한 마리만 남긴다
				end
			end
			mob.hp, mob.maxHp = 1e9, 1e9
			local hits = 0
			for _, hit in def.hits do
				mob.state = "idle"
				for _, r in room:skillHit(h, hit, mob.x - d, mob.y, 1, 1, nil, def.type).hits do
					sum += r.dmg
					hits += 1
				end
			end
			landed = hits
		end
		return sum / n / (Hero.powerRaw(h) * RULES.dmgScale), landed
	end
	for _, class in CLASSES.order do
		local h = Hero.new(1, class)
		h.level = 30
		h.stats[STATS.classes[class][1]] = N.apAt(30)
		local mobId, bossId = nil, nil
		for id, def in COMBAT.skills do
			if def.who == class and def.type == "mob" then
				mobId = id
			elseif def.who == class and def.type == "boss" then
				bossId = id
			end
		end
		local mobDef, bossDef = COMBAT.skills[mobId], COMBAT.skills[bossId]
		-- 붙어 있는 적(20도트 앞)은 설계한 한 번의 피해를 다 받는다: 사냥기 = 초당 피해 x 딜레이 x mobShare(x 보정), 보스기 = 초당 피해 x 딜레이(일반 몬스터에게는 보정 없음)
		local mobGot, mobHits = cast(h, mobId, 20)
		local bossGot, bossHits = cast(h, bossId, 20)
		local mobWant, bossWant = DPS * mobDef.time * RULES.mobShare * bonus, DPS * bossDef.time
		expect(math.abs(mobGot / mobWant - 1) < 0.02, ("%s 사냥기 %s: 붙은 적 한 마리에게 설계한 피해가 다 들어간다(딜레이 %.2f초 · %d타 · 합 %.0f%% — 기대 %.0f%%)"):format(class, mobId, mobDef.time, mobHits, mobGot * 100, mobWant * 100))
		expect(math.abs(bossGot / bossWant - 1) < 0.02, ("%s 보스기 %s: 붙은 적 한 마리에게 설계한 피해가 다 들어간다(딜레이 %.2f초 · %d타 · 합 %.0f%% — 기대 %.0f%%)"):format(class, bossId, bossDef.time, bossHits, bossGot * 100, bossWant * 100))
		-- 같은 시간에 주는 피해: 일반 몬스터 한 마리는 사냥기가 보스기보다 느리지 않다
		local mobRate, bossRate = mobGot / mobDef.time, bossGot / bossDef.time
		expect(mobRate >= bossRate, ("%s: 일반 몬스터 한 마리 — 사냥기 초당 %.0f%% ≥ 보스기 초당 %.0f%%"):format(class, mobRate * 100, bossRate * 100))
	end
end

