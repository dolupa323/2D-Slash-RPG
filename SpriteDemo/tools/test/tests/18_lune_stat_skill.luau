-- 「달의 계승자」 — 능력치의 설명(마우스를 올리면 뜨는 것) · 스킬 창의 차수 탭 · 스킬마다의 그림 · 대쉬 효과의 값.
--  사용자 2026-10-07: "능력치에 각각 스텟별로 마우스 올리면 호버로 스텟 효과를 보여줘야합니다" · "1,2,3,4 차 스킬 탭이있어야지" · "패시브든 뭐든 다 아이콘이 있는거에요" · "대쉬 이펙트가 바뀐거같은데"
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 따로 본다(22_lune_passives.luau의 치명타 검사) — 이 파일은 치명타 없이 피해를 그대로 잰다
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
			-- 주 · 부 능력치(2026-10-15 스펙): 1점 = 스탯 공격력 +4 · +1 x 공격력 / 100(지금 낀 무기로). 전투력은 거기에 패시브 · 크리티컬의 기댓값(k)을 곱한다
			--  그 레벨의 점수를 다 주스탯에 넣은 것에서 50점을 덜어 냈다가 다시 넣으면 전투력이 50 x 설명의 값 x k만큼 오른다(반올림 1 안에서)
			local h = Hero.new(1, class)
			h.level = lv
			local sp0 = Hero.specView(h)
			local gain = N.statGain(class, lv, sp0.atk)
			gain = { main = gain.main * sp0.k, sub = gain.sub * sp0.k, hp = gain.hp }
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
		eq(h.slots[1], Quick.START_POTION, "첫 칸은 물약(작은 달빛 물약) " .. class)
		expect(Quick.item(h.slots[1]) ~= nil and Quick.item(h.slots[1]).tab == "use" and Quick.item(h.slots[2]) == nil, "칸에 놓인 것이 소비 아이템인지 스킬인지 안다")
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
		local again = Quick.place(h.slots, "potion1", 9)
		expect(again ~= nil and Hero.setSlots(h, again) and h.slots[9] == "potion1", "가방에서 끌어다 다른 칸에 다시 놓는다")
		-- 소비 아이템은 저마다 따로 놓는다(사용자 2026-10-08): 다른 물약은 다른 칸에 — 가진 것이 없어도 놓아 둘 수 있다
		local two = Quick.place(h.slots, "potion3", 10)
		expect(two ~= nil and Hero.setSlots(h, two) and h.slots[9] == "potion1" and h.slots[10] == "potion3", "다른 물약은 다른 칸에 놓인다")
		expect(Hero.setSlots(h, keep), "처음 배치로 되돌린다")
		local bad = table.clone(keep)
		bad[12] = keep[1]
		expect(not Hero.setSlots(h, bad), "같은 물약을 두 칸에 놓은 것은 받지 않는다")
		bad = table.clone(keep)
		bad[12] = "etc_plate"
		expect(not Hero.setSlots(h, bad), "기타 아이템은 칸에 놓지 못한다")
		bad = table.clone(keep)
		bad[12] = "potion"
		expect(not Hero.setSlots(h, bad), "예전의 이름표(potion)는 받지 않는다")
		bad = table.clone(keep)
		bad[3] = "no_such_skill"
		expect(not Hero.setSlots(h, bad), "없는 스킬은 받지 않는다")
		bad = table.clone(keep)
		bad[5] = keep[4]
		expect(not Hero.setSlots(h, bad), "같은 스킬을 두 칸에 놓은 것은 받지 않는다")
		bad = table.clone(keep)
		bad[Quick.N + 1] = "potion1"
		expect(not Hero.setSlots(h, bad), "칸이 더 많은 것은 받지 않는다")
		expect(not Hero.setSlots(h, "potion1") and not Hero.setSlots(h, nil), "꼴이 다른 것은 받지 않는다")
		for other, def in COMBAT.skills do
			if def.who ~= class then
				bad = table.clone(keep)
				bad[6] = other
				expect(not Hero.setSlots(h, bad), "다른 직업의 스킬은 받지 않는다")
				break
			end
		end
		expect(same(h.slots, keep), "받지 않은 뒤에도 칸들이 그대로다 " .. class)
		-- 스마트폰의 단추 배치(tslots): PC의 퀵슬롯과 따로 저장한다 — 한쪽을 바꿔도 다른 쪽은 그대로다.
		--  처음 차림: 폰에는 칸 1의 단추가 없어(사용자 2026-10-13: "모바일에서 상호작용 버튼 아래에 있는 버튼 없애고") 물약이 칸 5에 놓인다 — 나머지는 PC와 같다
		expect(same(h.tslots, Quick.touchStart(CLASSES.classes[class].skills)) and h.tslots[1] == false and h.tslots[5] == "potion1" and h.tslots[2] == Quick.start(CLASSES.classes[class].skills)[2], "스마트폰 배치의 처음 차림 " .. class)
		local tmoved = Quick.place(h.tslots, h.tslots[2], 9)
		expect(Hero.setSlots(h, tmoved, true) and h.tslots[9] == tmoved[9] and h.tslots[2] == false, "스마트폰 배치를 바꾼 것을 받는다 " .. class)
		expect(same(h.slots, keep), "스마트폰 배치를 바꿔도 PC의 퀵슬롯은 그대로다 " .. class)
		expect(not Hero.setSlots(h, { "potion1", "no_such_skill" }, true) and same(h.tslots, tmoved), "스마트폰 배치도 없는 스킬은 받지 않는다 " .. class)
		local tback = Hero.unpack(1, Hero.pack(h))
		expect(tback ~= nil and same(tback.tslots, h.tslots) and same(tback.slots, h.slots), "두 배치가 따로 저장되고 되살아난다 " .. class)
		eq(Hero.view(h).tslots, h.tslots, "스마트폰 배치가 내 상태에 실려 간다 " .. class)
	end
	-- 퀵슬롯이 생기기 전에 저장된 캐릭터는 처음 차림을 받는다
	local old = Hero.pack(Hero.new(1, "axion"))
	old.slots = nil
	local revived = Hero.unpack(1, old)
	expect(revived ~= nil and revived.slots[1] == "potion1" and COMBAT.skills[revived.slots[2]] ~= nil, "칸이 없던 저장도 처음 차림으로 되살아난다")
	old.slots = { "potion1", "no_such_skill" }
	revived = Hero.unpack(1, old)
	-- 깨진 칸은 그 칸만 비운다(2026-10-18 검토 — 전에는 칸 하나 때문에 배치 전체가 처음 차림으로 돌아갔다)
	expect(revived ~= nil and revived.slots[1] == "potion1" and revived.slots[2] == false, "깨진 칸만 비우고 나머지는 지킨다")
	-- 예전 저장의 물약 칸("potion" — 물약이 한 가지였을 때): 놓아 둔 자리 그대로, 그때 마시던 물약(내 레벨의 것)의 칸이 된다. PC · 스마트폰 배치 모두
	do
		local was = Hero.new(1, "axion")
		local saved = Hero.pack(was)
		local sk = was.slots[2]
		saved.slots = { false, sk, false, false, false, false, false, "potion" }
		saved.tslots = { "potion", sk }
		local now = Hero.unpack(1, saved)
		expect(now ~= nil and now.slots[8] == "potion1" and now.slots[2] == sk and now.slots[1] == false, "예전 물약 칸이 그 자리에 남는다(PC)")
		expect(now.tslots[1] == false and now.tslots[3] == "potion1" and now.tslots[2] == sk, "예전 물약 칸은 지금의 이름표로 — 폰에는 칸 1의 단추가 없어 단추가 있는 첫 빈 칸(칸 3)으로 옮겨진다")
		saved.level = 45
		now = Hero.unpack(1, saved)
		expect(now ~= nil and now.slots[8] == "potion2", "Lv.45였다면 그때 마시던 것은 달빛 물약이다")
	end
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
			local want = 1 / CLASSES.skillRule.floor -- 1레벨의 세기가 floor(70%)이니 마스터는 그 역수(1.43배)
			expect(prev / first > want * 0.9 and prev / first < want * 1.1, ("%s Lv.%d: 마스터의 피해가 Lv.1의 %.2f배쯤(%.2f배)"):format(class, lv, want, prev / first))
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
			expect(mob ~= nil or step.type == "use" or step.type == "visit" or step.type == "meet", "할 일의 졸개가 있다 " .. def.id) -- ↑를 누르는 일 · 들르는 일 · 만나기(2026-10-16)에는 졸개가 없다
			if step.type == "use" then
				expect(hint:find(step.place, 1, true) ~= nil and hint:find("↑", 1, true) ~= nil, "어느 자리에서 ↑를 누르는지 적는다: " .. hint)
				expect(small(Q9.trackText(step, step.n)) <= UI.hud.quest.w, "알리미의 줄이 칸 안: " .. Q9.trackText(step, step.n))
			end
			if step.type == "visit" then
				expect(hint:find(step.name, 1, true) ~= nil, "들를 맵을 적는다: " .. hint)
			elseif step.type == "meet" then
				expect(hint:find(step.name, 1, true) ~= nil, "만날 사람을 적는다: " .. hint) -- 그 사람이 선 방(대장간 · 의뢰소 …)의 이름과 함께
			elseif def.scene then
				expect(hint:find(SCENES9.scenes[def.scene].name, 1, true) ~= nil, "어디인지 적는다: " .. hint)
			end
			if step.type == "gather" then
				seen += 1
				expect(hint:find(mob.name, 1, true) ~= nil and hint:find("에게서 떨어진다", 1, true) ~= nil, "무엇을 잡아야 하는지 적는다: " .. hint) -- (「…을 잡으면」 → 「…에게서 떨어진다」: 2026-10-27 영문 — 조사를 고르지 않는 말)
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

-- ---- 차수: 레벨로 열린다 · 스킬 포인트는 차수마다 따로 · 먼저 배워야 하는 스킬 ----
do
	local Hero2 = req("ReplicatedStorage/shared/lune/sim/hero")
	local N2 = req("ReplicatedStorage/shared/lune/config/numbers")
	local CL = req("ReplicatedStorage/shared/lune/data/classes.generated")
	eq(Hero2.jobAt(1), 1, "Lv.1은 1차")
	eq(Hero2.jobAt(29), 1, "Lv.29까지 1차")
	eq(Hero2.jobAt(30), 2, "Lv.30에 2차")
	eq(Hero2.jobAt(60), 3, "Lv.60에 3차")
	eq(Hero2.jobAt(100), 4, "Lv.100에 4차")
	eq(Hero2.skillJob("axion", "ax_echo2"), 2, "겹 메아리는 2차")
	eq(Hero2.skillJob("axion", "c_hero"), 4, "공용 스킬은 4차")
	-- 차수마다의 포인트: 다 더하면 그 레벨까지 받은 것과 같다
	for _, lv in { 1, 2, 29, 30, 31, 60, 100, 140, 150 } do
		local sum = 0
		for job = 1, 4 do
			sum += Hero2.spEarnedIn(lv, job)
		end
		eq(sum, Hero2.spEarned(lv), "차수마다 받은 포인트의 합 = 받은 포인트 Lv." .. lv)
	end
	-- 1차 캐릭터는 2차 스킬을 못 올린다
	local h = Hero2.new(71, "axion")
	h.level = 29
	h.sp = Hero2.spEarned(29)
	eq(Hero2.skillUp(h, "ax_crescent"), false, "열리지 않은 차수의 스킬은 못 올린다")
	eq(h.skills.ax_crescent, nil, "2차의 사냥기도 아직 없다")
	-- Lv.30이 되어도 전직하기 전에는 2차가 열리지 않는다(2026-10-10 — 전직 퀘스트를 돌려줘야 오른다). 대신 전직 퀘스트를 저절로 받는다
	Hero2.gainXp(h, N2.xpNeed(29) - h.xp)
	eq(h.level, 30, "Lv.30")
	eq(h.job, 1, "Lv.30이 됐어도 아직 1차다")
	eq(h.skills.ax_crescent, nil, "전직하기 전에는 2차의 사냥기가 없다")
	eq(Hero2.skillUp(h, "ax_crescent"), false, "전직하기 전에는 2차의 스킬을 못 올린다")
	eq(h.quests.job2, nil, "Lv.30이 되어도 전직 퀘스트를 저절로 받지 않는다(사제에게 가서 받는다)")
	eq(Hero2.advance(h, 3), false, "차수를 건너뛰어 전직하지 못한다")
	-- 전직하면: 2차의 사냥기 · 보스기가 레벨 1로 생기고(게임에 들어와 있는 것만 — 아직 없는 것은 주지 않는다), Lv.30부터 받은 포인트는 2차의 것이다
	local slotWas = table.find(h.slots, "ax_slam")
	expect(Hero2.advance(h, 2), "Lv.30에 2차로 전직한다")
	eq(h.job, 2, "2차")
	eq(Hero2.advance(h, 2), false, "같은 차수로 두 번 전직하지 못한다")
	expect(slotWas ~= nil and h.slots[slotWas] == "ax_crescent", "1차의 사냥기가 놓여 있던 칸에 2차의 사냥기가 들어온다")
	eq(table.find(h.slots, "ax_slam"), nil, "1차의 사냥기는 칸에서 빠진다(스킬 창에서 다시 놓을 수 있다)")
	for _, sk in CL.classes.axion.tiers[2].skills do
		if table.find(CL.skillRule.start, sk.type) then
			eq(h.skills[sk.id], if Hero2.ready(sk.id) then 1 else nil, "2차의 사냥기 · 보스기: 게임에 있는 것만 레벨 1로 생긴다 " .. sk.id)
		end
	end
	eq(Hero2.spLeft(h, 2), N2.spAt(30), "Lv.30에 받은 포인트는 2차의 것")
	eq(Hero2.spLeft(h, 1), Hero2.spEarnedIn(29, 1, h.class), "1차에서 남긴 포인트는 그대로 1차의 것")
	-- 먼저 배워야 하는 스킬: 겹 메아리 ← 메아리 도끼
	eq(Hero2.skillUp(h, "ax_echo2"), false, "메아리 도끼를 배우기 전에는 겹 메아리를 못 올린다")
	expect(Hero2.skillUp(h, "ax_echo"), "메아리 도끼(1차의 포인트로)")
	eq(Hero2.spLeft(h, 1), Hero2.spEarnedIn(29, 1, h.class) - 1, "1차의 포인트가 줄었다")
	expect(Hero2.skillUp(h, "ax_echo2"), "이제 겹 메아리를 올린다(2차의 포인트로)")
	eq(Hero2.spLeft(h, 2), N2.spAt(30) - 1, "2차의 포인트가 줄었다")
	-- 2차의 포인트가 떨어지면 1차의 포인트가 남아 있어도 2차 스킬은 못 올린다
	for _ = 1, 10 do
		Hero2.skillUp(h, "ax_echo2")
	end
	eq(Hero2.spLeft(h, 2), 0, "2차의 포인트를 다 썼다")
	expect(Hero2.spLeft(h, 1) > 0, "1차의 포인트는 남아 있다")
	eq(Hero2.skillUp(h, "ax_breath"), false, "2차의 포인트가 없으면 2차 스킬은 못 올린다")
	-- 화면에 보내는 것 · 저장하고 되살리기
	local view = Hero2.view(h)
	eq(view.job, 2, "지금의 차수")
	eq(view.sps[1], Hero2.spLeft(h, 1), "차수마다 남은 포인트(1차)")
	eq(view.sps[2], 0, "차수마다 남은 포인트(2차)")
	local back = Hero2.unpack(71, Hero2.pack(h))
	eq(back.skills.ax_echo2, h.skills.ax_echo2, "다시 들어와도 2차 스킬이 그대로")
	eq(Hero2.spLeft(back, 1), Hero2.spLeft(h, 1), "남은 포인트도 그대로")
	-- 말이 안 되는 저장(1차 레벨인데 2차 스킬 · 그 차수에 받은 것보다 많이 쓴 것)은 처음 차림으로
	local bad = Hero2.pack(h)
	bad.level = 20
	local fixed = Hero2.unpack(71, bad)
	eq(fixed.skills.ax_echo2, nil, "레벨이 안 되는데 2차 스킬이 있으면 처음 차림으로")
	-- 「추천대로 찍기」: 차수마다 제 포인트를 쓴다. Lv.140이면 4차까지 거의 다 찍힌다
	local top = Hero2.new(72, "riven")
	while top.level < 140 do
		Hero2.gainXp(top, N2.xpNeed(top.level) - top.xp)
	end
	Hero2.advanceAll(top) -- 전직을 다 한 것으로(전직 퀘스트는 13_lune_world가 본다)
	eq(top.job, 4, "Lv.140이면 4차까지")
	Hero2.autoSkill(top)
	for job = 1, 4 do
		local pool, cost = Hero2.spEarnedIn(140, job, "riven"), 0
		for _, sk in CL.classes.riven.tiers[job].skills do
			if Hero2.ready(sk.id) then -- 게임에 아직 없는 스킬에는 찍히지 않는다
				cost += sk.max - (if table.find(CL.skillRule.start, sk.type) then 1 else 0)
			else
				eq(top.skills[sk.id], nil, "게임에 아직 없는 스킬은 추천대로 찍기로도 찍히지 않는다 " .. sk.id)
			end
		end
		eq(Hero2.spLeft(top, job), math.max(0, pool - cost), ("%d차: 남은 포인트(받은 %d · 게임에 있는 것을 다 찍는 데 %d)"):format(job, pool, cost))
	end
end

-- ---- 게임에 아직 없는 스킬에는 포인트가 찍히지 않는다(사용자 2026-10-08: 찍히는데 효과가 없던 일) ----
do
	local Hero2 = req("ReplicatedStorage/shared/lune/sim/hero")
	local N2 = req("ReplicatedStorage/shared/lune/config/numbers")
	local CL = req("ReplicatedStorage/shared/lune/data/classes.generated")
	local CB = req("ReplicatedStorage/shared/lune/data/combat.generated")
	-- 게임에 있는 것: 기술 · 1차의 사출기 · 장치 · 패시브 · 수치가 있는 버프 · 사출기 강화 · 설치 · 소환
	for id in CB.skills do
		expect(Hero2.ready(id), "기술은 게임에 있다 " .. id)
	end
	for id in CB.kitSkill do
		expect(Hero2.ready(id), "1차의 사출기 · 장치 · 패시브는 게임에 있다 " .. id)
	end
	for id in CB.placed do
		expect(Hero2.ready(id), "설치 · 소환은 게임에 있다 " .. id)
	end
	for id, b in CB.buffs do
		eq(Hero2.ready(id), next(b.fx) ~= nil or CB.placed[id] ~= nil, "버프는 수치가 있을 때만 게임에 있다 " .. id)
	end
	for _, ups in CB.kitUp do
		for _, def in ups do
			expect(Hero2.ready(def.id), "사출기 강화는 게임에 있다 " .. def.id)
		end
	end
	eq(Hero2.ready("nope"), false, "없는 스킬")
	-- 1차는 모두 게임에 있다(새 캐릭터가 찍지 못하는 스킬이 없다)
	for class, c in CL.classes do
		for _, sk in c.tiers[1].skills do
			expect(Hero2.ready(sk.id), ("1차 스킬은 모두 게임에 있다 %s %s"):format(class, sk.id))
		end
	end
	-- 아직 없는 스킬: 차수가 열리고 포인트가 있어도 찍히지 않는다 · 포인트도 줄지 않는다
	for class, c in CL.classes do
		local h = Hero2.new(81, class)
		while h.level < 120 do
			Hero2.gainXp(h, N2.xpNeed(h.level) - h.xp)
		end
		Hero2.advanceAll(h)
		local seen = 0
		for _, t in c.tiers do
			for _, sk in t.skills do
				if not Hero2.ready(sk.id) then
					seen += 1
					local before = Hero2.spLeft(h, t.job)
					eq(Hero2.skillUp(h, sk.id), false, ("아직 없는 스킬은 찍히지 않는다 %s %s"):format(class, sk.id))
					eq(h.skills[sk.id], nil, "레벨도 생기지 않는다 " .. sk.id)
					eq(Hero2.spLeft(h, t.job), before, "포인트가 줄지 않는다 " .. sk.id)
				end
			end
		end
		expect(seen > 0, "아직 옮기지 않은 스킬이 있다(다 옮기면 이 검사를 고친다) " .. class)
		-- 게임에 있는 스킬은 모두 찍을 수 있다(먼저 배워야 하는 스킬이 아직 없는 것이면 그 조건은 보지 않는다)
		Hero2.autoSkill(h)
		for _, t in c.tiers do
			for _, sk in t.skills do
				if Hero2.ready(sk.id) and Hero2.spLeft(h, t.job) > 0 then
					eq(h.skills[sk.id], sk.max, ("포인트가 남았으면 게임에 있는 스킬은 마스터까지 찍힌다 %s %s"):format(class, sk.id))
				end
			end
		end
	end
	-- 만월(4차)은 깊은 호흡(먼저 배워야 하는 스킬 — 아직 게임에 없다)을 배우지 않아도 찍힌다
	do
		local h = Hero2.new(82, "axion")
		while h.level < 100 do
			Hero2.gainXp(h, N2.xpNeed(h.level) - h.xp)
		end
		Hero2.advanceAll(h)
		local def = Hero2.skillDef("axion", "ax_fullmoon")
		if def.needs and not Hero2.ready(def.needs) then
			expect(Hero2.skillUp(h, "ax_fullmoon"), "먼저 배워야 하는 스킬이 게임에 아직 없으면 그 조건은 보지 않는다")
		end
		-- 게임에 있는 것이 먼저 배워야 하는 스킬이면 그대로 본다: 겹 메아리 ← 메아리 도끼
		eq(Hero2.skillUp(h, "ax_echo2"), false, "메아리 도끼를 배우기 전에는 겹 메아리를 못 올린다")
	end
	-- 아직 없는 스킬에 찍혀 있던 저장(막기 전의 것): 그 포인트를 돌려받는다 · 다른 스킬은 그대로
	do
		local h = Hero2.new(83, "axion")
		while h.level < 110 do
			Hero2.gainXp(h, N2.xpNeed(h.level) - h.xp)
		end
		Hero2.advanceAll(h)
		expect(Hero2.skillUp(h, "ax_breath"), "전투 호흡을 찍는다")
		local left = Hero2.spLeft(h, 4)
		local data = Hero2.pack(h)
		local gone = nil
		for _, sk in CL.classes.axion.tiers[4].skills do
			if not Hero2.ready(sk.id) then
				gone = sk.id
				break
			end
		end
		expect(gone ~= nil, "4차에 아직 없는 스킬이 있다(용사의 의지 — 다 옮기면 이 검사를 고친다)")
		if gone then
			data.skills[gone] = 3
			local back = Hero2.unpack(83, data)
			eq(back.skills[gone], nil, "아직 없는 스킬은 되살리지 않는다 " .. gone)
			eq(back.skills.ax_breath, 1, "다른 스킬은 그대로")
			eq(Hero2.spLeft(back, 4), left, "그 포인트는 돌려받는다")
		end
	end
end

-- ---- 스킬 포인트는 그 차수에 드는 만큼만 받는다(2026-10-11 — 사용자: "스킬 전부 마스터했는데 왜 1차에 남는 스킬포인트가 12 가있는건지?") ----
do
	local Hero2 = req("ReplicatedStorage/shared/lune/sim/hero")
	local N2 = req("ReplicatedStorage/shared/lune/config/numbers")
	local CL = req("ReplicatedStorage/shared/lune/data/classes.generated")
	for class, c in CL.classes do
		for _, t in c.tiers do
			local j = CL.jobs[t.job]
			local need = 0
			for _, sk in t.skills do
				need += sk.max - (if Hero2.ready(sk.id) and table.find(CL.skillRule.start, sk.type) then 1 else 0)
			end
			eq(Hero2.spNeed(class, t.job), need, ("%s %d차: 다 마스터하는 데 드는 포인트"):format(class, t.job))
			local raw = Hero2.spEarnedIn(j["until"], t.job)
			expect(raw >= need, ("%s %d차: 레벨업마다 받는 양(%d)이 드는 양(%d)보다 모자라지 않는다"):format(class, t.job, raw, need))
			eq(Hero2.spEarnedIn(j["until"], t.job, class), need, ("%s %d차: 그 차수 동안 받는 포인트 = 드는 포인트(남지 않는다)"):format(class, t.job))
			-- 레벨마다: 드는 만큼을 다 받을 때까지는 레벨업마다의 양 그대로, 그 뒤로는 0. 한 번도 줄어들지 않는다
			local sum = 0
			for L = math.max(2, j.lv), j["until"] do
				local gain = Hero2.spGain(class, L)
				expect(gain >= 0 and gain <= N2.spAt(L), ("%s Lv.%d: 받는 포인트 %d"):format(class, L, gain))
				expect(gain == N2.spAt(L) or sum + gain == need, ("%s Lv.%d: 덜 받는 것은 다 받은 때뿐"):format(class, L))
				sum += gain
			end
			eq(sum, need, ("%s %d차: 레벨마다 받은 것의 합"):format(class, t.job))
		end
	end
	-- 1차: 72점 — 레벨업마다 3점씩 Lv.25에 다 받고, Lv.26~29에는 받지 않는다. Lv.30부터는 2차의 것
	eq(Hero2.spGain("axion", 25), 3, "Lv.25까지 3점씩")
	eq(Hero2.spGain("axion", 26), 0, "Lv.26에는 받지 않는다(1차의 것을 다 받았다)")
	eq(Hero2.spGain("axion", 29), 0, "Lv.29에도")
	eq(Hero2.spGain("axion", 30), 3, "Lv.30부터는 2차의 포인트")
	-- 처음부터 키운 캐릭터: 레벨이 오를 때마다 추천대로 찍으면 Lv.25에 1차를 모두 마스터하고 남는 포인트가 없다
	for class in CL.classes do
		local h = Hero2.new(900, class)
		h.auto = false
		while h.level < 29 do
			Hero2.gainXp(h, N2.xpNeed(h.level) - h.xp)
			Hero2.autoSkill(h)
			if h.level == 24 then
				expect(Hero2.spLeft(h, 1) == 0 and Hero2.spEarnedIn(24, 1, class) < Hero2.spNeed(class, 1), class .. ": Lv.24에는 아직 다 찍지 못했다")
			end
		end
		eq(Hero2.spLeft(h, 1), 0, class .. ": 1차를 다 찍으면 남는 포인트가 없다")
		eq(h.sp, 0, class .. ": 가진 포인트도 0")
		for _, sk in CL.classes[class].tiers[1].skills do
			if Hero2.ready(sk.id) then
				eq(h.skills[sk.id], sk.max, ("%s: 1차 스킬 %s 마스터"):format(class, sk.id))
			end
		end
		-- 저장했다가 다시 들어와도 같다
		local back = Hero2.unpack(900, Hero2.pack(h))
		eq(Hero2.spLeft(back, 1), 0, class .. ": 다시 들어와도 남는 포인트가 없다")
		eq(back.sp, 0, class .. ": 다시 들어와도 0")
	end
end

-- ---- 스킬 · 능력치 초기화는 공짜 · 몇 번이든(2026-10-21 사용자: "스텟, 스킬 초기화 완전무료로 풀겠습니다" — 전에는 전직할 때마다 한 번 · 능력치는 상인의 주문서) ----
do
	local Hero2 = req("ReplicatedStorage/shared/lune/sim/hero")
	local N2 = req("ReplicatedStorage/shared/lune/config/numbers")
	local CL = req("ReplicatedStorage/shared/lune/data/classes.generated")
	local h = Hero2.new(950, "axion")
	h.auto = false
	eq(Hero2.freeReset(h), false, "찍은 스킬이 없으면 되돌릴 것이 없다")
	while h.level < 30 do
		Hero2.gainXp(h, N2.xpNeed(h.level) - h.xp)
		Hero2.autoSkill(h)
	end
	eq(Hero2.spLeft(h, 1), 0, "tier 1 mastered before the job change")
	expect(Hero2.freeReset(h), "1차에서도 공짜로 되돌린다(전직하지 않아도)")
	eq(Hero2.spLeft(h, 1), Hero2.spNeed("axion", 1), "1차의 점수가 모두 돌아온다")
	Hero2.autoSkill(h)
	expect(Hero2.advance(h, 2), "advance to job 2")
	Hero2.autoSkill(h)
	local slamMax = h.skills.ax_slam
	expect(slamMax ~= nil and slamMax > 1, "skills were raised")
	expect(Hero2.freeReset(h), "다시 되돌린다(몇 번이든)")
	eq(Hero2.spLeft(h, 1), Hero2.spNeed("axion", 1), "tier 1 points all back")
	eq(Hero2.spLeft(h, 2), Hero2.spEarnedIn(h.level, 2, "axion"), "tier 2 points all back")
	eq(h.sp, Hero2.spEarned(h.level, "axion"), "total points all back")
	for _, t in CL.classes.axion.tiers do
		if t.job <= 2 then
			for _, sk in t.skills do
				local start = Hero2.ready(sk.id) and table.find(CL.skillRule.start, sk.type) ~= nil
				eq(h.skills[sk.id], if start then 1 else nil, "after reset only the granted level 1 remains " .. sk.id)
			end
		end
	end
	eq(Hero2.freeReset(h), false, "되돌린 바로 뒤에는 되돌릴 것이 없다")
	Hero2.autoSkill(h)
	expect(Hero2.freeReset(h), "다시 찍으면 또 되돌린다")
	-- 능력치
	local h3 = Hero2.new(952, "riven")
	eq(Hero2.statsSpent(h3), false, "찍은 능력치가 없다")
	Hero2.setLevel(h3, 20)
	local ap0 = h3.ap
	Hero2.autoStat(h3)
	expect(Hero2.statsSpent(h3) and h3.ap < ap0, "자동으로 찍었다")
	Hero2.resetStats(h3)
	expect(not Hero2.statsSpent(h3) and h3.ap == ap0, "되돌리면 점수가 모두 돌아온다")
	-- 저장의 꼴(resets — 쓰지 않지만 예전 저장을 그대로 읽는다)
	h.resets = 1
	eq(Hero2.unpack(950, Hero2.pack(h)).resets, 1, "saved")
	local old = Hero2.pack(h)
	old.resets = 7
	eq(Hero2.unpack(950, old).resets, 0, "bad value is dropped")
	local fresh = Hero2.pack(Hero2.new(951, "riven"))
	fresh.resets = nil
	eq(Hero2.unpack(951, fresh).resets, 0, "a job-1 character gets none")
end
