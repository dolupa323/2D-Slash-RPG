-- 「달의 계승자」 — 스킬 창의 % 피해 · 스마트폰의 단추(칸 1의 단추가 없다) · 스마트폰 메뉴의 스크롤.
--  사용자 2026-10-13(폰에서 해 보고): "모바일에서 상호작용 버튼 아래에 있는 버튼 없애고 메뉴탭 열었을때 스크롤이 되어야해 모든메뉴를 접근할수가 없다
--                     그리고 스킬 퍼뎀같은거 스킬 창에 설명에 나와있어야해  메이플처럼 / 스킬레벨 추가로 찍으면 퍼뎀올라가는것도 보여야하고"
--  보는 것: ① 스킬 창에 적히는 %가 서버가 주는 피해 그대로인가(전투력 x % x 피해 숫자의 배율 x 쓰임의 보정) — 1차의 사냥기 · 보스기와 2~4차의 쓰는 스킬 모두
--           ② 레벨마다 글이 있고, 한 레벨을 찍을 때마다 적힌 수가 달라지는가 ③ 공방이 만든 글 = 게임의 수로 만든 글
--           ④ 폰의 단추에 칸 1이 없고 상호작용 단추 아래가 비어 있는가 · 새 캐릭터의 물약이 단추가 있는 칸에 놓이는가 · 전에 칸 1에 놓아 둔 것이 옮겨지는가
--           ⑤ 폰의 메뉴가 가장 작은 화면 틀에서도 화면 안에 서고, 넘치는 단추는 밀어서 다 닿는가
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local Quick = req("ReplicatedStorage/shared/lune/ui/quick")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local SkillDamage = req("ReplicatedStorage/shared/lune/ui/skillDamage")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})
local _ = Room
local RULES = COMBAT.rules
local CAST = COMBAT.cast
local SUB = 1 / 60
local X, Y = 2000, 176

-- 흩어짐 · 치명타 없이 잰다(끝에서 되돌린다)
local keepSpread, keepCrit = RULES.spread, RULES.critChance
RULES.spread, RULES.critChance = 0, 0

local function near(a, b, tol, msg)
	expect(math.abs(a - b) <= tol * math.max(1, math.abs(b)), ("%s (기대 %s, 실제 %s)"):format(msg, tostring(b), tostring(a)))
end
local function same(a, b)
	for i = 1, Quick.N do
		if (a[i] or false) ~= (b[i] or false) then
			return false
		end
	end
	return true
end
local function hero(class: string, skills)
	local h = Hero.new(1, class)
	h.level = 60
	h.dmgBoost = 50 -- (2026-10-15: 새 스펙에서 Lv.1 차림의 피해 숫자가 작아 반올림이 커서 키워 잰다 — 관리자의 시험용 배율과 같은 것)
	h.skills = {}
	for id, lv in skills do
		h.skills[id] = lv
	end
	Hero.recalc(h)
	h.hp = h.maxHp
	h.x, h.y, h.dir = X, Y, 1
	return h
end
local function numbers(text: string)
	local out = {}
	for n in text:gmatch("(%d+)%%") do
		table.insert(out, tonumber(n))
	end
	return out
end

-- ---- 1) 1차의 사냥기 · 보스기 ----
do
	local seen = 0
	for class, c in CLASSES.classes do
		for _, sk in c.tiers[1].skills do
			if sk.type ~= "mob" and sk.type ~= "boss" then
				expect(COMBAT.skills[sk.id] == nil or SkillDamage.firstParts(sk.id, 1) == nil, "공격 스킬이 아닌 것에는 % 피해가 없다 " .. sk.id)
				continue
			end
			seen += 1
			local def = COMBAT.skills[sk.id]
			eq(#COMBAT.kitEffects[sk.id], def.max, "레벨마다 글이 있다 " .. sk.id)
			local before = nil
			for lv = 1, def.max do
				local text = SkillDamage.text(sk.id, lv)
				-- 공방이 만든 글(공방의 시험 탭이 보는 글)과 게임의 수로 만든 글이 같다
				eq(SkillDamage.firstText(sk.id, lv), text, ("공방의 글 = 게임의 셈 %s Lv.%d"):format(sk.id, lv))
				expect(text ~= nil and #numbers(text) >= 1, ("%%가 적혀 있다 %s Lv.%d"):format(sk.id, lv))
				expect(text ~= before, ("한 레벨을 찍으면 적힌 수가 달라진다 %s Lv.%d — %s"):format(sk.id, lv, tostring(text)))
				before = text
				expect(pixelText.Measure(text, "small") <= Layout.SKILL.detailW * 3, ("세 줄 안에 든다 %s Lv.%d"):format(sk.id, lv))
			end
			expect(SkillDamage.text(sk.id, 1):find(("쓰는 시간 %.1f초"):format(math.floor(def.time * 10 + 0.5) / 10), 1, true) ~= nil, "쓰는 시간이 적혀 있다 " .. sk.id)
			eq(SkillDamage.text(sk.id, 0), nil, "배우기 전(Lv.0)의 「지금」은 없다 " .. sk.id)
			eq(SkillDamage.text(sk.id, def.max + 1), nil, "마스터의 「다음」은 없다 " .. sk.id)
			-- 서버가 주는 피해: 붙어 있는 졸개 한 마리에게 타마다 — 전투력 x % x 피해 숫자의 배율 x 쓰임의 보정(사냥기는 일반 몬스터에게 +50%)
			for _, lv in { 1, 2, 11, def.max } do
				local h = hero(class, { [sk.id] = lv })
				local room, foe = Caster.makeDry(X + 14, Y)
				local parts = SkillDamage.firstParts(sk.id, lv)
				local fit = if sk.type == "boss" then 1 else 1 + RULES.targetBonus / 100
				local got, want, n = 0, 0, 0
				for i, hit in def.hits do
					if parts[i].side then
						continue -- 가운데 타의 범위 밖의 적만 맞는 타: 붙어 있는 적은 맞지 않는다
					end
					local res = room:skillHit(h, hit, h.x, h.y, 1, Hero.skillScale(lv, def.max), nil, sk.type, nil)
					eq(#res.hits, 1, ("붙어 있는 졸개가 그 타에 맞는다 %s %d번째"):format(sk.id, i))
					for _, e in res.hits do
						expect(e.mob == foe.id, "맞은 것은 그 졸개다")
						got += e.dmg
					end
					want += Hero.powerRaw(h) * parts[i].pct / 100 * RULES.dmgScale * fit
					n += 1
				end
				expect(math.abs(got - want) <= n * 0.51, ("적힌 %% = 서버의 피해 %s Lv.%d (적힌 대로면 %.1f, 실제 %d)"):format(sk.id, lv, want, got))
				-- 글에 적힌 합(정수)도 그 피해와 반올림 안에서 맞는다
				local list = numbers(SkillDamage.text(sk.id, lv))
				local text = SkillDamage.text(sk.id, lv)
				local shown = if text:find("번에 나눠", 1, true) then list[1] elseif #list == 1 and n > 1 then list[1] * n else list[1] -- 「n번에 나눠 모두 x%」는 합 · 「x%의 피해로 n번」은 한 타의 것
				near(got / (Hero.powerRaw(h) * RULES.dmgScale * fit) * 100, shown, 0.02, ("글에 적힌 수 = 실제 피해 %s Lv.%d"):format(sk.id, lv))
			end
		end
	end
	eq(seen, 10, "다섯 직업의 1차 사냥기 · 보스기 열 개")
	-- 양옆으로 번지는 타(대지 강타): 가운데 타의 범위 밖에 선 졸개는 그 타만 맞는다 — 적힌 「번진 타」의 %
	do
		local def = COMBAT.skills.ax_slam
		local h = hero("axion", { ax_slam = 20 })
		local room, foe = Caster.makeDry(X + 70, Y)
		local parts = SkillDamage.firstParts("ax_slam", 20)
		local got, side = 0, 0
		for i, hit in def.hits do
			local res = room:skillHit(h, hit, h.x, h.y, 1, 1, nil, "mob", nil)
			for _, e in res.hits do
				got += e.dmg
			end
			if parts[i].side then
				side += parts[i].pct
			end
		end
		expect(side > 0 and foe ~= nil, "대지 강타에는 번지는 타가 있다")
		near(got, Hero.powerRaw(h) * side / 100 * RULES.dmgScale * (1 + RULES.targetBonus / 100), 0.01, "범위 밖의 졸개는 번진 타만큼만 맞는다")
		expect(SkillDamage.text("ax_slam", 20):find("번진 타", 1, true) ~= nil, "글에 번진 타가 적혀 있다")
	end
end

-- ---- 2) 2~4차의 쓰는 스킬: 잰 값으로 적는다 ----
do
	local shown, kinds = 0, { one = 0, sum = 0, avg = 0, full = 0 }
	for id, def in CAST do
		local p = Caster.profile(id, 0)
		local c1 = SkillDamage.cast(id, 1)
		if p.measured <= 0 or def.rate <= 0 then
			eq(c1, nil, "피해가 없는 스킬(묶기 · 회복)에는 적지 않는다 " .. id)
			eq(SkillDamage.text(id, 1), if COMBAT.kitEffects[id] then COMBAT.kitEffects[id][1] else nil, "효과 글만 " .. id)
			continue
		end
		if COMBAT.kitEffects[id] then
			continue -- 효과 글이 따로 있는 스킬은 그 글을 그대로 적는다
		end
		shown += 1
		expect(c1 ~= nil, "그 스킬의 % 피해가 있다 " .. id)
		kinds[c1.kind] += 1
		local before = nil
		for lv = 1, def.max do
			local text = SkillDamage.text(id, lv)
			expect(text ~= nil and #numbers(text) == 1, ("%%가 하나 적혀 있다 %s Lv.%d — %s"):format(id, lv, tostring(text)))
			expect(text ~= before, ("한 레벨을 찍으면 적힌 수가 달라진다 %s Lv.%d — %s"):format(id, lv, tostring(text)))
			before = text
			expect(pixelText.Measure(text, "small") <= Layout.SKILL.detailW * 2, ("두 줄 안에 든다 %s Lv.%d"):format(id, lv))
		end
		expect((p.time > 0) == (SkillDamage.text(id, 1):find("쓰는 시간", 1, true) ~= nil), "쓰는 시간은 동작이 있는 스킬에만 적힌다 " .. id)
		eq(SkillDamage.text(id, 0), nil, "Lv.0 " .. id)
		eq(SkillDamage.text(id, def.max + 1), nil, "마스터 다음 " .. id)
		near(SkillDamage.cast(id, def.max).pct, def.rate * (p.time + def.cdTime) * 100, 1e-6, "마스터의 % = 초당 피해 x (쓰는 시간 + 다시 쓰기의 몫) " .. id)
		near(c1.pct / SkillDamage.cast(id, def.max).pct, COMBAT.castRule.floor, 1e-6, "레벨 1은 마스터의 78.6% " .. id)
		-- 진짜 피해로: 붙어 있는 졸개에게 열 번 쓴 합 = 적힌 % x 10(장치를 다 갖췄을 때가 기준인 것은 빈 방에서 잰 몫만큼)
		for _, lv in { 1, def.max } do
			local h = hero(def.who, { [id] = lv })
			h.level = 120
			Hero.recalc(h)
			local room, foe = Caster.makeDry(X + (def.at or 14), Y)
			local c = Caster.new(room)
			c.dry = true
			local function tick()
				room.time += SUB
				foe.rend = 0
				c:sub(SUB)
			end
			local a = c:actor(h)
			for _ = 1, 10 do
				h.x, h.y, h.dir = X, Y, 1
				foe.x, foe.stun, foe.bind, foe.bindImm = X + (def.at or 14), 0, 0, 0
				if id == "sl_vent" then
					h.kit.heat = 0
				end
				c:dryCast(h, id, 0, tick)
			end
			local guard = 0
			while (#c.timers > 0 or #c.shots > 0) and guard < 20 do
				tick()
				guard += SUB
			end
			local got = 0
			for _, e in a.out.hits do
				got += e.dmg
			end
			local fit = if def.type == "boss" then 1 else 1 + RULES.targetBonus / 100
			local want = Hero.powerRaw(h) * SkillDamage.cast(id, lv).pct / 100 * RULES.dmgScale * fit * 10 * (p.measured / p.w)
			near(got, want, 0.05, ("적힌 %% = 서버의 피해 %s Lv.%d"):format(id, lv))
		end
	end
	expect(shown >= 35, "쓰는 스킬 서른다섯 넘게 % 피해가 적힌다 — " .. shown)
	expect(kinds.sum > 0, "여러 타(줄)짜리가 있다 — 타수 나누기(2026-10-14)로 한 타짜리도 여러 줄로 적힌다")
	eq(kinds.full, 2, "장치를 다 갖췄을 때가 기준인 스킬 둘(공명 폭발 · 열 방출)")
	-- 2차 레벨 1은 1차 마스터보다 세다는 것이 적힌 수로도 보인다(같은 시간으로 견준다 — 사용자 2026-10-08)
	for class, c in CLASSES.classes do
		for _, kind in { "mob", "boss" } do
			local first, second = nil, nil
			for _, sk in c.tiers[1].skills do
				if sk.type == kind then
					first = sk
				end
			end
			for _, sk in c.tiers[2].skills do
				if sk.type == kind then
					second = sk
				end
			end
			local d1 = COMBAT.skills[first.id]
			local sum = 0
			for _, p in SkillDamage.firstParts(first.id, d1.max) do
				if not p.side then
					sum += p.pct
				end
			end
			local c2 = SkillDamage.cast(second.id, 1)
			local p2 = Caster.profile(second.id, 0)
			expect(c2.pct / (p2.time + CAST[second.id].cdTime) > sum / d1.time, ("%s: 2차 %s Lv.1의 초당 %%가 1차 %s 마스터보다 크다"):format(class, second.id, first.id))
		end
	end
end

-- ---- 3) 스마트폰의 단추: 칸 1의 단추가 없다 ----
do
	local slots, act = {}, nil
	for _, t in UI.touch do
		if t.slot then
			slots[t.slot] = t
		end
		if t.act == "interact" then
			act = t
		end
	end
	expect(slots[1] == nil, "칸 1의 단추는 없다(상호작용 단추 아래에 있던 것)")
	for i = 2, 12 do
		expect(slots[i] ~= nil, "칸 " .. i .. "의 단추가 있다")
	end
	-- 2026-10-21에 늘린 칸 13 · 14는 PC의 퀵슬롯에만(스마트폰은 사용자가 정한 단추 열하나 그대로 — 펫 · 탈것은 가방의 캐시 탭에서)
	expect(slots[13] == nil and slots[14] == nil, "칸 13 · 14의 단추는 없다")
	eq(#Quick.TOUCH, 11, "단추가 있는 칸은 열하나")
	for _, t in UI.touch do
		if t ~= act and t.kind ~= "hud" then
			local under = t.y >= act.y + act.h and t.y < act.y + act.h + 40 and t.x < act.x + act.w and t.x + t.w > act.x
			expect(not under, "상호작용 단추 바로 아래에 다른 단추가 없다 — " .. t.name)
		end
	end
	-- 공방의 셈으로 손본 본보기와 같다
	for i, row in UI.quick.touchCheck do
		expect(same(Quick.touchFix(row[1]), row[2]), "공방의 셈과 같다 " .. i)
	end
	for class, c in CLASSES.classes do
		local start = Quick.touchStart(c.skills)
		local pc = Quick.start(c.skills)
		expect(start[1] == false and start[5] == Quick.START_POTION, class .. ": 새 캐릭터의 물약은 칸 5의 단추에")
		expect(start[2] == pc[2] and start[3] == pc[3] and start[4] == pc[4], class .. ": 사냥기 · 보스기 · 이동기는 큰 단추 그대로")
		local h = Hero.new(1, class)
		expect(same(h.tslots, start), class .. ": 새 캐릭터의 폰 배치")
		expect(same(h.slots, pc) and h.slots[1] == Quick.START_POTION, class .. ": PC의 퀵슬롯은 그대로(물약은 첫 칸)")
		for i = 1, Quick.N do
			expect(not h.tslots[i] or slots[i] ~= nil, class .. ": 놓인 것은 모두 단추가 있는 칸에 있다 " .. i)
		end
	end
	-- 전에 칸 1에 놓아 둔 것: 들어올 때 단추가 있는 첫 빈 칸으로 옮겨진다
	local h = Hero.new(1, "axion")
	local sk = h.slots[2]
	local saved = Hero.pack(h)
	saved.tslots = { "potion1", sk, false, false, false, false, false, false, false, false, false, false }
	local back = Hero.unpack(1, saved)
	expect(back ~= nil and back.tslots[1] == false and back.tslots[3] == "potion1" and back.tslots[2] == sk, "전에 칸 1에 놓아 둔 물약은 단추가 있는 첫 빈 칸(칸 3)으로")
	-- 자리가 없으면 빠진다 · 이미 맞는 배치는 그대로
	local full = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" }
	local fixed = Quick.touchFix(full)
	expect(fixed[1] == false and fixed[2] == "b" and fixed[12] == "l", "단추가 다 찼으면 칸 1의 것은 빠진다")
	expect(same(Quick.touchFix(fixed), fixed), "한 번 손본 것은 다시 손봐도 그대로")
	-- 클라이언트가 칸 1에 놓아 보내도 서버가 옮겨 둔다
	local h2 = Hero.new(2, "riven")
	local sent = table.clone(h2.tslots)
	sent[1], sent[5] = sent[5], false
	expect(Hero.setSlots(h2, sent, true) and h2.tslots[1] == false and h2.tslots[5] == Quick.START_POTION, "칸 1로 보낸 것은 단추가 있는 칸으로 돌아온다")
end

-- ---- 4) 스마트폰의 메뉴: 화면에 들어가고, 넘치면 민다 ----
do
	local K = Layout.TOUCHMENU
	local minH, refH, maxH = UI.grid.min.h, UI.grid.h, UI.grid.max.h
	for _, uiH in { minH, refH, maxH } do
		for n = 1, 20 do
			local m = Layout.touchMenu(n, uiH)
			expect(m.top + m.h + K.bottom <= uiH, ("판이 화면 안에 선다 — 단추 %d개 · 높이 %d"):format(n, uiH))
			eq(m.contentH, n * K.row - (K.row - K.btnH), "단추들의 높이 " .. n)
			eq(m.scroll, m.contentH > m.viewH, "넘칠 때만 민다 " .. n)
			expect(m.viewH >= K.btnH, "단추 하나는 온전히 보인다")
			expect(m.btnW + (if m.scroll then K.bar + K.pad else 0) + K.pad * 2 == m.w, "단추와 막대가 판의 폭에 든다")
			-- 끝까지 밀면 마지막 단추가 다 보인다
			local lastTop = (n - 1) * K.row
			expect(lastTop + K.btnH - math.max(0, m.contentH - m.viewH) <= m.viewH, "끝까지 밀면 마지막 단추가 보인다 " .. n)
		end
	end
	-- 지금의 메뉴(창 열 개쯤 + 단추 배치 · 캐릭터 선택 · 소리 설정 = 열셋): 폰의 화면 틀에서는 민다
	local phone = Layout.touchMenu(13, minH)
	expect(phone.scroll and phone.viewH >= K.row * 6, "폰에서 열셋은 밀어서 본다 · 한 번에 여섯 넘게 보인다")
	expect(pixelText.Measure("캐릭터 선택", "body") <= phone.btnW - 12, "가장 긴 단추의 글이 막대를 뺀 폭에 든다")
	expect(K.btnH >= 32 and K.row > K.btnH, "손가락으로 누를 만한 높이 · 단추 사이가 떨어져 있다")
end

-- ---- 5) 채팅 = Roblox의 기본 채팅(client/lune/chat.luau) ----
--  사용자 2026-10-13: "우리가 자체 채팅을 구현하는게 아니라 로블록스 채팅이 있어요 로블록스 공식문서좀 확인해보고 ,  그걸 어떻게 로블록스 채팅을 우리게임에 자연스럽게 사용하게 연결할수있는지"
--  화면은 Roblox의 것이라 여기서 볼 수 있는 것은 우리가 정하는 것뿐이다: 글의 앞머리(캐릭터의 이름 · 파티의 꼬리표) · 파티원 칸을 채팅 창 아래로 내리는 셈.
do
	local CU = UI.chatUi
	-- 가짜 Roblox 채팅 설정: 걸리는 속성을 적어 두고, 진짜처럼 수 속성에 nil을 넣으면 오류를 낸다
	--  (2026-10-13: 자료에 없는 값(stroke)을 TextStrokeTransparency에 걸려던 줄이 남아 Studio의 Output에 "value of type nil cannot be converted to a number"가 떴다 — 화면 코드를 돌려 보지 않아 놓쳤다)
	local bad = {}
	local function fake(class: string)
		local store, got = {}, {}
		local o = setmetatable({}, {
			__index = function(_, k)
				if k == "ClassName" then
					return class
				elseif k == "set" then
					return got
				elseif k == "GetPropertyChangedSignal" then
					return function() return { Connect = function() end } end
				end
				return store[k]
			end,
			__newindex = function(_, k, v)
				if v == nil then
					table.insert(bad, class .. "." .. tostring(k))
					error("value of type nil cannot be converted to a number")
				end
				store[k] = v
				got[k] = true
			end,
		})
		return o
	end
	local configs = { ChatWindowConfiguration = fake("ChatWindowConfiguration"), ChatInputBarConfiguration = fake("ChatInputBarConfiguration"), ChannelTabsConfiguration = fake("ChannelTabsConfiguration") }
	local TCS = { FindFirstChildOfClass = function(_, class) return configs[class] end, GetDescendants = function() return {} end }
	SERVICE("TextChatService", TCS)
	SERVICE("Players", { GetPlayerByUserId = function(_, id) return if id == 7 then { GetAttribute = function() return "달토끼" end } elseif id == 8 then { GetAttribute = function() return nil end } else nil end })
	local resized = 0
	MOCK("Client/lune/stage", {
		uiScale = 2,
		uiH = 540,
		ui = nil,
		onResize = function() resized += 1 end,
		atPosition = function(_, x, y) return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } } end,
		placeRect = function() return { Visible = true } end,
	})
	MOCK("Client/lune/ui/ui", { COLOR = setmetatable({}, { __index = function() return "c" end }) })
	local Chat = req("Client/lune/chat")
	eq(Chat.prefix("달토끼", false), ("<font color='%s'>달토끼:</font>"):format(CU.nameColor), "둘레의 글: 캐릭터의 이름")
	eq(Chat.prefix("달토끼", true), ("<font color='%s'>[파티]</font> <font color='%s'>달토끼:</font>"):format(CU.party.color, CU.party.color), "파티의 글: 꼬리표와 이름이 파티의 색")
	eq(Chat.prefix(nil, false), nil, "캐릭터를 고르기 전인 사람은 Roblox의 기본 앞머리 그대로")
	eq(Chat.prefix("", true), nil, "빈 이름")
	eq(Chat.prefix(42, false), nil, "글이 아닌 것")
	eq(Chat.plain("<b>&'\""), "&lt;b&gt;&amp;&apos;&quot;", "이름이 글자 꾸밈 꼬리표로 읽히지 않는다")
	eq(Chat.focused(), false, "입력줄을 아직 모르면 글을 치는 중이 아니다")
	eq(Chat.bottom, 0, "채팅 창의 자리를 모르면 0")
	-- 실제로 건다: 오류 없이 · nil을 넣으려 한 속성이 없고 · 걸어야 하는 속성이 모두 걸린다
	local warned = #warnings
	Chat.init()
	eq(#bad, 0, "수 속성에 nil을 넣으려 한 것이 없다 — " .. table.concat(bad, ", "))
	eq(#warnings, warned, "자료에 없는 값을 걸려는 줄이 없다 — " .. tostring(warnings[#warnings]))
	local WANT = {
		ChatWindowConfiguration = { "Enabled", "BackgroundColor3", "BackgroundTransparency", "TextColor3", "WidthScale", "HeightScale" },
		ChatInputBarConfiguration = { "Enabled", "BackgroundColor3", "BackgroundTransparency", "TextColor3", "PlaceholderColor3" },
		ChannelTabsConfiguration = { "Enabled", "BackgroundColor3", "BackgroundTransparency", "TextColor3", "SelectedTabTextColor3" },
	}
	for class, keys in WANT do
		for _, k in keys do
			expect(configs[class].set[k] == true and configs[class][k] ~= nil, ("%s.%s가 걸린다"):format(class, k))
		end
	end
	eq(configs.ChatWindowConfiguration.Enabled, true, "Roblox의 채팅 창을 켠다")
	eq(configs.ChatInputBarConfiguration.Enabled, true, "입력줄을 켠다")
	eq(configs.ChannelTabsConfiguration.Enabled, true, "채널 탭을 켠다(「파티」에 쓰려면 있어야 한다)")
	eq(configs.ChatWindowConfiguration.BackgroundColor3.hex, CU.window.back, "창의 바탕색은 자료의 것")
	eq(configs.ChatWindowConfiguration.BackgroundTransparency, CU.window.alpha, "바탕의 비침")
	eq(configs.ChatWindowConfiguration.WidthScale, CU.window.width, "창의 폭")
	eq(Chat.focused(), false, "글을 치는 중이 아니다")
	configs.ChatInputBarConfiguration.IsFocused = true
	eq(Chat.focused(), true, "입력줄에 글을 치는 중이면 게임의 키를 받지 않는다")
	configs.ChatInputBarConfiguration.IsFocused = false
	-- 받은 글의 앞머리: 캐릭터의 이름으로(파티 채널이면 꼬리표)
	expect(typeof(TCS.OnIncomingMessage) == "function", "받은 글을 손보는 함수가 걸려 있다")
	local near = TCS.OnIncomingMessage({ TextSource = { UserId = 7 }, TextChannel = { Name = "RBXGeneral" } })
	eq(near.PrefixText, Chat.prefix("달토끼", false), "둘레의 글의 앞머리")
	local party = TCS.OnIncomingMessage({ TextSource = { UserId = 7 }, TextChannel = { Name = CU.party.channel } })
	eq(party.PrefixText, Chat.prefix("달토끼", true), "파티의 글의 앞머리")
	eq(TCS.OnIncomingMessage({ TextSource = { UserId = 8 }, TextChannel = { Name = "RBXGeneral" } }).PrefixText, nil, "캐릭터의 이름이 없는 사람은 Roblox의 앞머리 그대로")
	eq(TCS.OnIncomingMessage({ TextSource = nil, TextChannel = { Name = "RBXSystem" } }).PrefixText, nil, "알림 글은 손대지 않는다")
	-- 파티원 칸: PC에서는 채팅 창의 아래로(폰 · 모를 때는 제자리)
	local PartyHud = req("Client/lune/partyHud")
	PartyHud.init({}, function() end)
	local r = UI.hud.party
	PartyHud.setTop(0)
	eq(PartyHud.box.Position.Y.Offset, r.y, "채팅 창의 자리를 모르면 제자리")
	PartyHud.setTop(150)
	eq(PartyHud.box.Position.Y.Offset, 150 + CU.gap, "채팅 창의 아래 끝에서 조금 띄워 그 아래에")
	eq(PartyHud.box.Position.X.Offset, r.x, "옆 자리는 그대로")
	PartyHud.setTop(4)
	eq(PartyHud.box.Position.Y.Offset, r.y, "창이 파티원 칸보다 위에서 끝나면 제자리")
	PartyHud.setTop(540 - CU.keep - r.h - CU.gap + 1)
	eq(PartyHud.box.Position.Y.Offset, r.y, "창이 너무 길면(체력 덩어리 쪽으로 밀리면) 제자리에 둔다")
	PartyHud.setTop(540 - CU.keep - r.h - CU.gap)
	eq(PartyHud.box.Position.Y.Offset, 540 - CU.keep - r.h, "딱 들어가는 데까지는 내린다")
end

RULES.spread, RULES.critChance = keepSpread, keepCrit
