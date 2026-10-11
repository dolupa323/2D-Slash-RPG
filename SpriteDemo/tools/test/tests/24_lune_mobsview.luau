-- 「달의 계승자」 — 화면 쪽의 몬스터 그리기를 화면 없이 돌려 본다(mobsView · sprite · effects의 화살과 마법 그림).
--  화면 모듈은 GUI가 있어야 해서 지금까지 컴파일만 검사했다 — 2026-10-08에 없는 이름 하나가 6만 개의 검사를 지나 Play에서 화면을 멈췄다.
--  2026-10-09 새 몬스터(맞음 · 나타남 · 쓰러짐 그림이 없는 것 · 나는 것 · 쏘는 것 · 마법)를 넣으면서, 그 그리는 코드만은 가짜 화면 틀을 끼워 실제로 돌린다:
--   모든 종류 × 모든 상태에서 오류 없이 그려지는가 · 그림 없는 동작의 번쩍임과 사라짐 · 나는 높이 · 머리 위 높이 · 날아가는 그림 · 마법 그림
--  가짜로 끼우는 것: 화면 틀(stage) · 글씨의 층(overlay) · UI 부품(ui · kit · itemCell · pixelText). 그림을 자르는 sprite와 그리는 mobsView · effects는 진짜다.
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")

local made = {} -- 만들어진 그림 딱지들
local function label(name)
	local l = { Name = name, Visible = false, ZIndex = 1, ImageTransparency = 0, Image = "" }
	function l:Destroy()
		self.destroyed = true
	end
	table.insert(made, l)
	return l
end
local any = setmetatable({}, { __index = function() return "c" end })
MOCK("Client/lune/stage", { image = function(_, name) return label(name) end })
MOCK("Client/lune/overlay", { x = function(v) return v end, y = function(v) return v end, len = function(v) return v end })
MOCK("Client/lune/ui/ui", {
	COLOR = any,
	bar = function() return { frame = label("bar"), set = function() end } end,
	tag = function() local t = { Frame = label("tag"), Width = 40 } function t:Destroy() end return t end,
})
MOCK("Client/lune/ui/kit", { COLOR = any, box = function() return label("box") end })
MOCK("Client/lune/ui/itemCell", {})
MOCK("Client/modules/ui/pixelText", {})

local Sprite = req("Client/lune/sprite")
local MobsView = req("Client/lune/mobsView")
local Effects = req("Client/lune/effects")

-- ---- 1) 모든 종류 × 모든 상태: 오류 없이 그려진다 ----
local kinds = {}
for kind in COMBAT.mobs do
	table.insert(kinds, kind)
end
table.sort(kinds)
local room = { mobs = {}, snap = {} }
for i, kind in kinds do
	table.insert(room.mobs, { id = i, kind = kind, lv = 5, y = 200, maxHp = 100, name = COMBAT.mobs[kind].name })
	table.insert(room.snap, { i, 100 + i * 40, 1, "idle", 0, 100, 0, 0 })
end
local view = MobsView.new({}, room, {})
local now = 10
local function show(state, t, hp, dir)
	local rows = {}
	for i in kinds do
		table.insert(rows, { i, 100 + i * 40, dir or 1, state, t, hp or 100, 0, 0 })
	end
	view:apply(rows, now)
	view:update(now)
	now += 0.05
	view:update(now)
end
for _, state in { "spawn", "idle", "run", "atk", "hit", "dead", "gone" } do
	for _, t in { 0, 0.05, 0.2, 0.5, 1.0, 3.0 } do
		for _, dir in { 1, -1 } do
			show(state, t, 60, dir)
			for i, kind in kinds do
				local m = view:get(i)
				local def = COMBAT.mobs[kind]
				if state == "gone" then
					expect(m.sprite.label.Visible == false, ("%s: 사라진 것은 보이지 않는다"):format(kind))
				elseif state == "idle" or state == "run" then
					expect(m.sprite.label.Visible == true, ("%s %s: 보인다"):format(kind, state))
					expect(m.sprite.label.Image ~= "", ("%s: 그림 판이 있다"):format(kind))
				end
				expect(MobsView.topOf(m) >= (if def.body then def.body[2] else 16), ("%s: 머리 위 높이"):format(kind))
			end
			view:tags()
		end
	end
end

-- ---- 2) 그림 없는 동작(새 몬스터): 맞으면 번쩍 · 나타날 때 서서히 보임 · 쓰러지면 서서히 사라짐 ----
local function idOf(kind)
	for i, k in kinds do
		if k == kind then
			return i
		end
	end
	error("없는 종류 " .. kind)
end
local function one(kind, state, t, hp)
	local id = idOf(kind)
	view:apply({ { id, 300, 1, state, t, hp or 60, 0, 0 } }, now)
	view:update(now)
	return view:get(id)
end
for _, kind in kinds do
	local def = COMBAT.mobs[kind]
	if def.story then
		-- 스토리 보스(2026-10-11): 예고하는 동안 분홍 윤곽이 깜박이고, 동작 그림이 없어 대기 그림을 움직여 대신한다. 머리 위의 체력 띠 · 이름표는 없다(화면 위의 넓은 바)
		local id = idOf(kind)
		local function boss(state, t, pat)
			view:apply({ { id, 300, 1, state, t, 60, 0, 0, pat } }, now)
			view:update(now)
			return view:get(id)
		end
		local m = boss("idle", 0, 0)
		expect(m.warn ~= nil and #m.warn == 4, kind .. ": 예고 윤곽의 그림이 있다")
		expect(m.sprite.label.Visible == true and m.warn[1].label.Visible == false, kind .. ": 서 있을 때는 윤곽이 없다")
		expect(m.hurt == false, kind .. ": 다쳐도 머리 위의 체력 띠 · 이름표는 띄우지 않는다")
		eq(m.px, 300, kind .. ": 서 있을 때는 제자리")
		for i, p in def.story.patterns do
			m = boss("tell", p.tell * 0.9, i)
			expect(m.pat == i and m.warn[1].label.Visible == true, ("%s %s: 예고하는 동안 윤곽이 보인다"):format(kind, p.id))
			expect(m.sprite.label.Visible == true and m.tNow >= p.tell * 0.9, ("%s %s: 몸이 보이고, 예고가 얼마나 찼는지 안다"):format(kind, p.id))
			m = boss("act", 0, i)
			expect(m.warn[1].label.Visible == false, ("%s %s: 치는 순간에는 윤곽이 없다"):format(kind, p.id))
			m = boss("dash", 0.1, i)
			expect(m.sprite.label.Visible == true, ("%s %s: 내달리는 모습도 오류 없이 그려진다"):format(kind, p.id))
		end
		-- 받은 동작 그림(2026-10-11 — 사용자가 넣은 idle · walk · attack): 그 동작의 그림이 있는 패턴은 그림을 패턴의 시간에 맞춰 틀고(몸을 옮기지 않는다), 없는 패턴은 대기 그림을 움직여 대신한다
		local BossFx = req("ReplicatedStorage/shared/lune/bossfx")
		local clips, anim = CHARS.chars[def.sprite].clips, def.story.anim
		expect(anim ~= nil and anim.fps > 0, kind .. ": 동작을 패턴의 시간에 맞추는 자료가 있다")
		local played = 0
		for i, p in def.story.patterns do
			local a = if not p.dash and clips[p.clip] then anim[p.clip] else nil
			local c, f, stand = BossFx.body("tell", p, p.tell, 0, clips, anim, nil)
			if a then
				played += 1
				expect(a.hit >= 1 and a.to > a.hit and a.to < #clips[p.clip].frames, ("%s %s: 닿는 장 · 끝 장이 그 동작의 장 안에 있다"):format(kind, p.id))
				expect(c == p.clip and f == a.hit and stand == false, ("%s %s: 예고의 끝 = 치기 바로 앞의 장(%s %d)"):format(kind, p.id, c, f))
				c, f = BossFx.body("tell", p, 0, 0, clips, anim, nil)
				eq(f, 1, ("%s %s: 예고의 처음 = 첫 장"):format(kind, p.id))
				c, f = BossFx.body("tell", p, p.tell - 0.12, 0, clips, anim, nil)
				eq(f, a.hit - 1, ("%s %s: 예고의 끝 가까이 = 다 치켜든 자세에서 멈춰 있다(휘두르는 도중의 장에서 멈추지 않는다)"):format(kind, p.id))
				c, f = BossFx.body("act", p, 0, 0, clips, anim, nil)
				eq(f, a.hit + 1, ("%s %s: 치는 순간 = 무기가 닿는 장"):format(kind, p.id))
				c, f = BossFx.body("act", p, p.act, 0, clips, anim, nil)
				expect(f > a.hit + 1 and f <= a.to + 1, ("%s %s: 굳어 있는 동안 그 뒤의 장이 흐른다"):format(kind, p.id))
				local c2, f2 = BossFx.body("idle", nil, 0, 0, clips, anim, { clip = p.clip, t = p.act })
				expect(c2 == p.clip and f2 == f, ("%s %s: 굳은 것이 풀린 뒤에도 서 있으면 남은 장을 이어서 튼다"):format(kind, p.id))
				c2 = BossFx.body("idle", nil, 0, 0, clips, anim, { clip = p.clip, t = 99 })
				eq(c2, "idle", ("%s %s: 다 틀면 대기 그림으로 돌아온다"):format(kind, p.id))
				c2 = BossFx.body("run", nil, 0, 0, clips, anim, { clip = p.clip, t = p.act })
				eq(c2, "run", ("%s %s: 걷기 시작하면 걷는 그림으로 넘어간다"):format(kind, p.id))
				m = boss("tell", p.tell, i)
				eq(m.px, 300, ("%s %s: 그림이 있으면 몸을 옮기지 않는다"):format(kind, p.id))
				m = boss("act", 0, i)
				expect(m.tail ~= nil and m.tail.clip == p.clip, ("%s %s: 친 동작을 적어 둔다"):format(kind, p.id))
				m = boss("idle", 0.1, 0)
				expect(m.tail ~= nil and math.abs(m.tail.t - (p.act + 0.1)) < 0.05, ("%s %s: 서 있는 동안 친 뒤 흐른 시간을 잰다"):format(kind, p.id))
				m = boss("run", 0, 0)
				expect(m.tail == nil, ("%s %s: 걸으면 남은 장을 버린다"):format(kind, p.id))
			elseif not (p.dash and clips.run) then
				expect(c == "idle" and stand == true, ("%s %s: 그림이 없는 패턴은 대기 그림을 움직여 대신한다"):format(kind, p.id))
			end
			if p.dash and clips.run then
				c, f, stand = BossFx.body("dash", p, 0.1, 0.1, clips, anim, nil)
				expect(c == "run" and stand == false, ("%s %s: 내달릴 때는 걷는 그림을 돌린다"):format(kind, p.id))
			end
		end
		expect(played >= 1, kind .. ": 받은 공격 그림을 쓰는 패턴이 있다")
		expect(clips.idle ~= nil and #clips.idle.frames >= 2 and clips.run ~= nil, kind .. ": 대기 · 걷는 그림이 있다")
		m = boss("run", 0, 0)
		expect(m.sprite.label.Visible == true and m.px == 300, kind .. ": 걷는 모습이 그려진다")
		m = boss("spawn", 0, 0)
		expect(m.sprite.label.ImageTransparency > 0.9, kind .. ": 나타날 때 처음에는 안 보인다")
		m = boss("dead", 0.8, 0)
		expect(m.sprite.label.Visible == false, kind .. ": 쓰러지면 사라진다")
		m = boss("gone", 0, 0)
		expect(m.sprite.label.Visible == false and m.warn[1].label.Visible == false, kind .. ": 없을 때는 아무것도 안 보인다")
	elseif def.bare then
		local m = one(kind, "hit", 0)
		expect(m.white ~= nil, kind .. ": 흰 번쩍임의 그림이 있다")
		expect(m.white.label.Visible == true, kind .. ": 맞은 순간 번쩍인다")
		expect(m.sprite.label.Visible == true and m.sprite.label.ImageTransparency == 0, kind .. ": 맞을 때 몸은 또렷하다")
		m = one(kind, "hit", 0.2)
		expect(m.white.label.Visible == false, kind .. ": 번쩍임은 잠깐이다")
		m = one(kind, "spawn", 0)
		expect(m.sprite.label.ImageTransparency > 0.9, kind .. ": 나타날 때 처음에는 안 보인다")
		m = one(kind, "spawn", 0.6)
		expect(m.sprite.label.ImageTransparency == 0, kind .. ": 나타난 뒤에는 또렷하다")
		m = one(kind, "dead", 0.2, 0)
		expect(m.sprite.label.Visible == true and m.sprite.label.ImageTransparency > 0.2, kind .. ": 쓰러지면 흐려진다")
		m = one(kind, "dead", 0.8, 0)
		expect(m.sprite.label.Visible == false, kind .. ": 다 사라진다")
		m = one(kind, "idle", 0)
		expect(m.sprite.label.ImageTransparency == 0 and m.white.label.Visible == false, kind .. ": 서 있을 때는 그대로다")
	else
		local m = one(kind, "hit", 0)
		expect(m.white ~= nil and m.white.label.Visible == false, kind .. ": 병사는 제 맞는 그림을 쓴다(서버가 알린 모습만으로는 번쩍이지 않는다 — 번쩍임은 맞은 알림이 건다)")
		expect(m.sprite.label.Visible == true, kind .. ": 병사의 맞는 그림")
	end
end

-- ---- 타격감(2026-10-11 — 사용자: "타격감이 너무 없음 어느정도는 구현해야할듯") ----
--  맞은 알림(MobsView.hit)이 오면: 모든 몬스터가 하얗게 번쩍이고(HIT.flash초), 때린 쪽의 반대로 밀렸다가(HIT.push점 — 그림만) HIT.pushT초에 걸쳐 돌아온다
do
	local MV = req("Client/lune/mobsView")
	local HIT = COMBAT.rules.hit
	expect(HIT.flash > 0 and HIT.flash <= 0.15 and HIT.push >= 1 and HIT.push <= 5 and HIT.pushT > HIT.flash, "타격감의 숫자")
	expect(HIT.hold > 0 and HIT.hold <= 0.06 and HIT.holdBig >= HIT.hold and HIT.holdBig <= 0.1 and HIT.gap >= 0.15, "멈칫은 짧고(연타가 굼떠지지 않게) 틈을 둔다")
	for _, kind in kinds do
		local m = one(kind, "idle", 0)
		view:update(now + 1)
		expect(m.white ~= nil and m.white.label.Visible == false, kind .. ": 맞기 전에는 번쩍이지 않는다")
		eq(m.px, m.x, kind .. ": 맞기 전에는 제자리에 그린다")
		for _, dir in { 1, -1 } do
			local t0 = now + 2 + (if dir > 0 then 0 else 1)
			MV.hit(m, t0, dir)
			view:update(t0)
			expect(m.white.label.Visible == true, kind .. ": 맞은 순간 하얗게 번쩍인다")
			local far = if m.def.boss or m.info.boss then HIT.pushBoss else HIT.push
			eq(m.px - m.x, dir * far, kind .. ": 맞은 순간 때린 쪽의 반대로 밀린다")
			view:update(t0 + HIT.flash + 0.01)
			expect(m.white.label.Visible == false, kind .. ": 번쩍임은 잠깐이다")
			local mid = math.abs(m.px - m.x)
			expect(mid <= far, kind .. ": 밀린 것이 돌아오는 중")
			view:update(t0 + HIT.pushT + 0.01)
			eq(m.px, m.x, kind .. ": 제자리로 돌아온다")
			expect(m.sprite.label.Visible == true, kind .. ": 몸은 그대로 보인다")
		end
	end
end

-- ---- 3) 터뜨리는 것(폭탄병 · 포자 주머니): 터진 뒤의 장들에는 서 있는 몸을 밑에 그린다(터뜨려도 사라지지 않는다 — 사용자 2026-10-11) ----
for _, kind in { "bomber", "puff" } do
	local def = COMBAT.mobs[kind]
	local m = one(kind, "atk", 0)
	expect(m.under ~= nil, kind .. ": 밑에 그리는 몸이 있다")
	expect(m.sprite.label.Visible == true and m.under.label.Visible == false, kind .. ": 터지기 전에는 터뜨리는 그림만")
	m = one(kind, "atk", (def.atk.frame + 1) / def.atk.fps)
	expect(m.sprite.label.Visible == true and m.under.label.Visible == true, kind .. ": 터진 뒤에는 그 밑에 서 있는 몸이 보인다")
	m = one(kind, "idle", 0)
	expect(m.sprite.label.Visible == true and m.under.label.Visible == false, kind .. ": 동작이 끝나면 그냥 서 있다")
end

-- ---- 3-1) 그림을 빌려 쓰는 몬스터의 겉모습(2026-10-11 — 사용자: "정예검병 이런 그냥 검병이랑 같은 몬스터 디자인을 돌려쓰는 경우에 … 주위에 화려한 이펙트라던가 좀 구분되어지게") ----
for kind, def in COMBAT.mobs do
	if def.sprite ~= kind then
		expect(def.look ~= nil and (def.look.tint ~= nil or def.look.aura ~= nil), kind .. ": 그림을 빌려 쓰면 가르는 겉모습이 있다")
	end
end
for _, kind in { "ewarrior", "espearman", "earcher" } do
	local def = COMBAT.mobs[kind]
	expect(def.look.aura ~= nil and def.look.embers ~= nil and def.look.tint ~= nil, kind .. ": 정예는 윤곽의 빛 · 불티 · 물든 색")
	local m = one(kind, "idle", 0)
	expect(m.glow ~= nil and #m.glow == 4 and m.embers ~= nil and #m.embers == 5, kind .. ": 빛 넷과 불티 다섯")
	do
		-- 불티는 피어오를 때 두 점, 올라가며 한 점이다(시간을 흘려 보며 둘 다 나온다)
		local big, small = false, false
		for step = 0, 12 do
			local mm = one(kind, "idle", step * 0.1)
			for _, e in mm.embers do
				local s = e.Size.X.Offset
				expect(s == 1 or s == 2, kind .. ": 불티의 크기는 한 점이나 두 점")
				big = big or s == 2
				small = small or s == 1
			end
		end
		expect(big and small, kind .. ": 불티가 두 점으로 피어 한 점으로 잦아든다")
	end
	expect(m.tinted == true, kind .. ": 몸의 그림에 색을 곱했다")
	for _, g in m.glow do
		expect(g.label.Visible == true and g.label.ImageTransparency >= 0.15 and g.label.ImageTransparency <= 0.75, kind .. ": 윤곽의 빛이 보인다")
	end
	for _, e in m.embers do
		expect(e.Visible == true, kind .. ": 불티가 보인다")
	end
	-- 걷고 치고 맞을 때에도 빛이 몸을 따라간다 · 쓰러지면 꺼진다
	for _, state in { "run", "atk", "hit" } do
		m = one(kind, state, 0.1)
		expect(m.glow[1].label.Visible == true, kind .. ": " .. state .. "에도 빛이 있다")
	end
	m = one(kind, "dead", 0.2)
	expect(m.glow[1].label.Visible == false and m.embers[1].Visible == false, kind .. ": 쓰러지면 빛과 불티가 꺼진다")
end
do
	local m = one("trainee", "idle", 0)
	expect(m.tinted == true and m.glow == nil and m.embers == nil, "수습 검병: 색만 다르다(빛나는 것은 없다)")
	m = one("warrior", "idle", 0)
	expect(m.tinted == nil and m.glow == nil and m.embers == nil, "검병: 본디 그림 그대로")
end

-- ---- 4) 나는 몬스터: 떠 있고(오르내림), 덮칠 때 내려왔다 올라간다 — 서버(sim/room.luau)와 같은 식 ----
do
	local def = COMBAT.mobs.bat
	local m = one("bat", "idle", 0)
	expect(math.abs(m.alt - def.fly.alt) <= def.fly.bob + 0.01, "박쥐: 제 높이에서 조금 오르내린다")
	local yIdle = m.sprite.label.Position.Y.Offset
	m = one("bat", "atk", def.atk.windup)
	expect(math.abs(m.alt - def.fly.low) < 0.01, ("박쥐: 덮치는 순간 가장 낮다(%.2f)"):format(m.alt))
	expect(m.sprite.label.Position.Y.Offset > yIdle, "박쥐: 덮칠 때 그림이 내려온다")
	m = one("bat", "atk", def.atk.time)
	expect(math.abs(m.alt - def.fly.alt) < 0.01, "박쥐: 다 올라오면 제 높이")
	expect(MobsView.topOf(m) > def.body[2], "박쥐: 머리 위 높이에 뜬 높이가 든다")
	local w = one("warrior", "idle", 0)
	eq(w.alt, 0, "병사는 뜨지 않는다")
	eq(MobsView.topOf(w), 16, "병사의 머리 위 높이는 그대로다")
end

-- ---- 5) 제 기준점이 있는 그림(마법 = 발밑 가운데 · 날아가는 것 = 한가운데) ----
do
	local s = Sprite.new({}, "torch", 1)
	s:set("cast", 5, 100, 200, 1)
	local clip = CHARS.chars.torch.clips.cast
	local f = clip.frames[5]
	expect(s.label.Visible == true, "마법 그림이 보인다")
	eq(s.label.Position.X.Offset, 100 - (clip.ox - f[6]), "마법 그림: 가운데가 그 자리에")
	eq(s.label.Position.Y.Offset, 200 - (clip.oy - f[7]), "마법 그림: 발밑이 땅에")
	eq(s.label.Position.Y.Offset + f[5], 200, "마법 그림: 맞는 장(불기둥)의 아래 끝이 땅에 닿는다")
	local h = Sprite.new({}, "helm", 1)
	h:set("shot", 1, 50, 80, 1)
	local sc = CHARS.chars.helm.clips.shot
	expect(math.abs((h.label.Position.X.Offset + sc.frames[1][4] / 2) - 50) <= 1.5, "날아가는 그림: 가운데가 그 자리에")
	h:set("shot", 1, 50, 80, -1)
	expect(math.abs((h.label.Position.X.Offset + sc.frames[1][4] / 2) - 50) <= 1.5, "날아가는 그림: 뒤집어도 가운데")
end

-- ---- 6) 효과: 제 그림으로 날아가는 것 · 흰 줄 화살 · 마법 그림 ----
do
	local fx = Effects.new({}, {}, {})
	fx:addShot({ id = 1, x = 10, y = 20, dir = 1, speed = 110, range = 150, kind = "helm" }, 0)
	fx:addShot({ id = 2, x = 10, y = 20, dir = -1, speed = 170, range = 140, kind = "archer" }, 0)
	fx:addShot({ id = 3, x = 10, y = 20, dir = 1, speed = 170, range = 140 }, 0) -- 종류가 없던 때의 화살도 그대로
	expect(fx.shots[1].sprite ~= nil, "빈 투구의 덩어리는 제 그림으로 난다")
	expect(fx.shots[2].frame ~= nil and fx.shots[2].sprite == nil, "궁병의 화살은 흰 줄이다")
	expect(fx.shots[3].frame ~= nil, "종류가 없는 화살")
	fx:update(0.5, 0.05)
	expect(fx.shots[1].sprite.label.Visible == true, "덩어리가 보인다")
	expect(fx.shots[1].sprite.label.Position.X.Offset > 10, "덩어리가 앞으로 간다")
	fx:endShot(1)
	fx:endShot(2)
	expect(fx.shots[1] == nil and fx.shots[2] == nil, "끝난 화살은 지운다")
	fx:update(9, 0.05)
	expect(fx.shots[3] == nil, "멀리 간 화살은 사라진다")

	local cast = COMBAT.mobs.torch.atk.cast
	fx:addMobCast("torch", 120, 200)
	eq(#fx.sprites, 1, "마법 그림이 뜬다")
	local sp = fx.sprites[1]
	local t, seen = 9, 0
	while #fx.sprites > 0 and t < 20 do
		t += 0.05
		fx:update(t, 0.05)
		if sp.sprite.label.Visible then
			seen += 1
		end
	end
	expect(seen >= 5, "마법 그림이 장마다 보인다 " .. seen)
	expect(sp.sprite.label.destroyed == true, "다 돈 마법 그림은 지운다")
	expect(math.abs((t - 9) - cast.life) <= 0.11, ("마법 그림의 길이(%.2f초)"):format(t - 9))
	fx:addMobCast("warrior", 0, 0) -- 마법이 없는 종류는 아무 일도 없다
	eq(#fx.sprites, 0, "마법이 없는 종류")
end

-- ---- 7) 치우기 ----
view:destroy()
for _, kind in kinds do
	if COMBAT.mobs[kind].bare then
		expect(true, kind)
	end
end

-- ---- 스토리 보스의 화면(bossView.luau — 2026-10-11): 서버가 보낸 모습이 바뀌는 때에 예고 · 이펙트 · 물결을 건다 ----
do
	local BossView = req("Client/lune/bossView")
	local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local scene = SCENES.scenes.r1c4
	local room2 = { mobs = {}, snap = {} }
	for i, b in scene.bosses do
		room2.mobs[i] = { id = i, kind = b.kind, lv = b.lv, y = b.y, maxHp = 1000, name = COMBAT.mobs[b.kind].name, boss = true }
		room2.snap[i] = { i, b.x, -1, "gone", 0, 1000, 0, 0, 0 }
	end
	local v2 = MobsView.new({}, room2, {})
	local calls = {}
	local fx = setmetatable({}, {
		__index = function(_, name)
			return function(...)
				table.insert(calls, { name = name, args = { ... } })
			end
		end,
	})
	local castFake = { fx = fx, shakeA = 0, shakeT = 0 }
	local ghosts = 0
	local bv = BossView.new(v2, castFake, { ghost = function() ghosts += 1 end }, scene)
	eq(#bv.list, 2, "그 방의 보스 둘을 본다")
	expect(bv.lo == 32 and bv.hi == scene.w * 16 - 32, ("방의 양 끝(벽 안쪽) %s ~ %s"):format(tostring(bv.lo), tostring(bv.hi)))
	local t = 50
	local function snap(id, state, st, pat)
		v2:apply({ { id, 400, -1, state, st, 900, 0, 0, pat } }, t)
		v2:update(t)
		bv:update(0.016)
	end
	local function count(name)
		local n = 0
		for _, c in calls do
			n += if c.name == name then 1 else 0
		end
		return n
	end
	local function adds()
		local list = {}
		for _, c in calls do
			if c.name == "add" then
				table.insert(list, c)
			end
		end
		return list
	end
	local function patOf(kind, id)
		for i, p in COMBAT.mobs[kind].story.patterns do
			if p.id == id then
				return i, p
			end
		end
		error("없는 패턴 " .. id)
	end
	local drawn = 0
	local ctx = setmetatable({}, {
		__index = function()
			return function()
				drawn += 1
			end
		end,
	})
	snap(1, "idle", 0, 0)
	eq(#calls, 0, "서 있을 때는 아무것도 걸지 않는다")
	local qi, q = patOf("towerlieutenant", "quake")
	snap(1, "tell", 0.1, qi)
	eq(count("add"), 1, "예고가 시작되면 맞을 자리를 한 번 건다")
	snap(1, "tell", 0.5, qi)
	eq(count("add"), 1, "같은 예고에는 다시 걸지 않는다")
	adds()[1].args[2](ctx, 0.5)
	expect(drawn > 5, "예고하는 동안 맞을 자리를 그린다")
	snap(1, "act", 0.05, qi)
	expect(count("beam") == 1 and count("ring") == 2 and count("spike") == 7 and count("shards") == 1 and count("rise") == 1 and castFake.shakeT > 0 and castFake.shakeA >= 2, "치는 순간: 고리 · 솟는 가시 다섯 · 파편")
	eq(count("add"), 3, "땅 울림: 물결 둘을 건다")
	drawn = 0
	adds()[1].args[2](ctx, 0.9)
	eq(drawn, 0, "치고 난 뒤에는 예고를 그리지 않는다")
	-- 물결: 방 안에서는 그리고, 벽 밖으로는 그리지 않는다(왼쪽으로 가는 것은 400 - 40 = 360에서 250을 간다 → 110까지. 오른쪽은 610까지 — 둘 다 방 안)
	for i = 2, 3 do
		drawn = 0
		adds()[i].args[2](ctx, 0.5)
		expect(drawn > 0, "물결을 그린다")
	end
	snap(1, "idle", 0, 0)
	local n0 = #adds()
	snap(1, "tell", 0.1, qi)
	snap(1, "idle", 0, 0) -- 묶여서 끊겼다
	eq(count("ring"), 2, "예고가 끊기면(묶임) 치는 이펙트가 없다")
	drawn = 0
	adds()[n0 + 1].args[2](ctx, 0.3)
	eq(drawn, 0, "끊긴 예고는 그리지 않는다")
	-- 벽 가까이에서 친 물결은 벽 밖을 그리지 않는다
	v2:apply({ { 1, 60, -1, "idle", 0, 900, 0, 0, 0 } }, t)
	v2:update(t)
	bv:update(0.016)
	n0 = #calls
	v2:apply({ { 1, 60, -1, "tell", 0.1, 900, 0, 0, qi } }, t)
	v2:update(t)
	bv:update(0.016)
	v2:apply({ { 1, 60, -1, "act", 0.02, 900, 0, 0, qi } }, t)
	v2:update(t)
	bv:update(0.016)
	local left
	for i = n0 + 1, #calls do
		if calls[i].name == "add" and calls[i].args[1] == q.wave.range / q.wave.speed and left == nil then
			left = calls[i]
		end
	end
	expect(left ~= nil, "벽 곁에서도 물결을 건다")
	drawn = 0
	left.args[2](ctx, 0.9) -- 왼쪽으로 간 물결: 60 - 40 - 225 = 벽 밖
	eq(drawn, 0, "벽 밖으로 나간 물결은 그리지 않는다")
	-- 정찰대장: 호령(빛기둥 둘) · 내달리기(달리는 동안 속도선)
	snap(1, "gone", 0, 0)
	local ci = patOf("scoutcaptain", "call")
	snap(2, "tell", 0.1, ci)
	n0 = count("beam")
	snap(2, "act", 0.05, ci)
	eq(count("beam") - n0, 2, "호령: 졸개가 나오는 두 자리에 빛기둥")
	snap(2, "idle", 0, 0)
	local di = patOf("scoutcaptain", "charge")
	snap(2, "tell", 0.1, di)
	n0 = count("streaks")
	snap(2, "dash", 0.02, di)
	expect(count("streaks") - n0 >= 2, "내달리기: 박차는 순간과 달리는 동안의 속도선")
	local n1 = count("streaks")
	for _ = 1, 10 do
		bv:update(0.02)
	end
	expect(count("streaks") - n1 >= 3, "달리는 동안 속도선이 이어진다")
	expect(ghosts >= 2, "내달리는 동안 잔상이 남는다 " .. ghosts)
	local r0 = count("ring")
	castFake.shakeT = 0
	snap(2, "idle", 0, 0)
	expect(count("ring") == r0 + 1 and castFake.shakeT > 0, "내달리기가 끝나면(벽) 터지고 화면이 흔들린다")
	eq(BossView.hpLabel(1234.2, 53640, 288, function(t) return #t * 6 end), "1235/53640", "체력의 숫자: 지금/최대")
	eq(BossView.hpLabel(-5, 53640, 288, function(t) return #t * 6 end), "0/53640", "체력이 다하면 0")
	expect(BossView.hpLabel(53640, 53640, 30, function(t) return #t * 6 end) ~= "53640/53640", "칸이 좁으면 짧게 적는다")
	bv:destroy()
	eq(#bv.list, 0, "장면이 바뀌면 치운다")
end
