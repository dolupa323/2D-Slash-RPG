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
	bar = function()
		local b = { frame = label("bar"), fill = label("fill"), ratio = nil }
		function b.set(_, r) b.ratio = r end
		return b
	end,
	box = function(parent, x, y, w, h, color)
		local l = label("box")
		l.Size = { X = { Offset = w }, Y = { Offset = h } }
		l.BackgroundTransparency = 0
		return l
	end,
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
			if p.chain then
				continue -- 연속기: 그 자체는 예고도 판정도 없다(적힌 패턴들을 차례로 쓴다 — 화면에는 그 패턴의 차례가 온다)
			end
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
			if p.chain then
				continue
			end
			local a = if not p.dash and clips[p.clip] then anim[p.clip] else nil
			local c, f, stand = BossFx.body("tell", p, p.tell, 0, clips, anim, nil)
			if a then
				played += 1
				expect(a.hit >= 1 and a.to > a.hit and a.to < #clips[p.clip].frames, ("%s %s: 닿는 장 · 끝 장이 그 동작의 장 안에 있다"):format(kind, p.id))
				expect(c == p.clip and f == a.hit and stand == false, ("%s %s: 예고의 끝 = 치기 바로 앞의 장(%s %d)"):format(kind, p.id, c, f))
				c, f = BossFx.body("tell", p, 0, 0, clips, anim, nil)
				eq(f, 1, ("%s %s: 예고의 처음 = 첫 장"):format(kind, p.id))
				-- swing = 예고의 끝에 차례로 보여 주는 휘두르는 도중의 장 수(공방 bosses.js의 BOSS_SHEET — 2026-10-15 성벽 거인 · 쇠사슬 간수의 내려치기는 둘). 없으면 하나
				local s = a.swing or 1
				c, f = BossFx.body("tell", p, p.tell - s / anim.fps - 0.02, 0, clips, anim, nil)
				eq(f, a.hit - s, ("%s %s: 예고의 끝 가까이 = 다 치켜든 자세에서 멈춰 있다(휘두르는 도중의 장에서 멈추지 않는다)"):format(kind, p.id))
				c, f = BossFx.body("tell", p, p.tell - s / anim.fps + 0.001, 0, clips, anim, nil)
				eq(f, a.hit - s + 1, ("%s %s: 휘두르는 도중의 첫 장이 예고의 마지막 %d장 시간에 온다"):format(kind, p.id, s))
				c, f = BossFx.body("act", p, 0, 0, clips, anim, nil)
				eq(f, a.hit + 1, ("%s %s: 치는 순간 = 무기가 닿는 장"):format(kind, p.id))
				c, f = BossFx.body("act", p, p.act, 0, clips, anim, nil)
				expect(f > a.hit + 1 and f <= a.to + 1, ("%s %s: 굳어 있는 동안 그 뒤의 장이 흐른다"):format(kind, p.id))
				-- 굳은 것이 풀린 뒤: 동작이 아직 남았으면(굳어 있는 시간보다 긴 동작) 서 있는 동안 이어서 틀고, 다 틀었으면 대기로 돌아온다
				local left = a.hit + math.floor(p.act * anim.fps) <= a.to
				local c2, f2 = BossFx.body("idle", nil, 0, 0, clips, anim, { clip = p.clip, t = p.act })
				expect(if left then c2 == p.clip and f2 == f else c2 == "idle", ("%s %s: 굳은 것이 풀린 뒤 — 남은 장이 있으면 이어서, 없으면 대기"):format(kind, p.id))
				c2 = BossFx.body("idle", nil, 0, 0, clips, anim, { clip = p.clip, t = 0.05 })
				eq(c2, p.clip, ("%s %s: 친 직후에 서 있으면 그 동작을 이어서 튼다"):format(kind, p.id))
				c2 = BossFx.body("idle", nil, 0, 0, clips, anim, { clip = p.clip, t = 99 })
				eq(c2, "idle", ("%s %s: 다 틀면 대기 그림으로 돌아온다"):format(kind, p.id))
				c2 = BossFx.body("run", nil, 0, 0, clips, anim, { clip = p.clip, t = p.act })
				eq(c2, if clips.run then "run" else "idle", ("%s %s: 걷기 시작하면 그 동작을 그만둔다(걷는 그림이 있으면 그것으로)"):format(kind, p.id))
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
		expect(played >= 1 or anim.attack == nil, kind .. ": 공격 그림이 있으면 그것을 쓰는 패턴이 있다")
		-- 쓰러지는 동작 그림이 있는 보스(2026-10-12): 쓰러지면 그 동작을 한 번 틀고(마지막 장 = 쓰러져 누운 장) 누워 있다가 서서히 사라진다. 없는 보스는 선 채로 서서히 사라진다
		if clips.death and anim.fall then
			local n, fps = #clips.death.frames, clips.death.fps
			local c, f, a = BossFx.fall(0, clips, anim)
			expect(c == "death" and f == 1 and a == 1, kind .. ": 쓰러지는 순간 = 그 동작의 첫 장")
			c, f, a = BossFx.fall(n / fps + anim.fall.hold * 0.5, clips, anim)
			expect(f == n and a == 1, kind .. ": 다 틀면 쓰러져 누운 장에서 또렷이 멈춰 있다")
			c, f, a = BossFx.fall(n / fps + anim.fall.hold + anim.fall.fade * 0.5, clips, anim)
			expect(f == n and a > 0.4 and a < 0.6, kind .. ": 그 뒤 서서히 사라진다")
			expect(math.abs(def.story.fall - (n / fps + anim.fall.hold + anim.fall.fade)) < 0.011, kind .. ": 서버가 치우기까지의 시간 = 동작 + 누워 있는 시간 + 사라지는 시간")
			m = boss("dead", 0, 0)
			expect(m.sprite.label.Visible == true and m.sprite.label.ImageTransparency == 0, kind .. ": 쓰러지는 동안 몸이 또렷이 보인다")
			m = boss("dead", def.story.fall - anim.fall.fade * 0.5, 0)
			expect(m.sprite.label.Visible == true and m.sprite.label.ImageTransparency > 0.3, kind .. ": 누운 뒤 서서히 사라진다")
			m = boss("dead", def.story.fall + 0.1, 0)
			expect(m.sprite.label.Visible == false, kind .. ": 다 사라지면 보이지 않는다")
		else
			expect(BossFx.fall(0, clips, anim) == nil, kind .. ": 쓰러지는 동작 그림이 없으면 선 채로 사라진다(전처럼)")
			expect(def.story.fall == nil, kind .. ": 그런 보스는 서버도 전처럼 0.9초 뒤에 치운다")
		end
		-- 게임에서 그리는 크기(2026-10-11 — 사용자: "게임에서 표현되어지는 크기를 줄이라는거에요 스프라이트를 건드리라는게아니라"): 받은 그림은 화소 그대로 싣고(동작의 k) 작게 · 부드럽게 줄여 그린다
		do
			local c = clips.idle
			expect(def.story.show ~= nil and def.story.show <= 1, kind .. ": 그리는 크기가 적혀 있다")
			m = boss("idle", 0, 0)
			local lab = m.sprite.label
			if not c.k then
				-- 2026-10-12부터: 보스의 동작은 Codex로 만든 도트 그림 — 한 점 = 세계의 한 점으로 또렷하게 그린다(k 없음)
				expect(lab.ResampleMode ~= Enum.ResamplerMode.Default and lab.Size.X.Offset == math.abs(lab.ImageRectSize.X), kind .. ": 도트 그림은 점 그대로 또렷하게 그린다")
				c = { k = 1 }
			else
			local fw, fh = math.abs(lab.ImageRectSize.X), lab.ImageRectSize.Y -- 지금 그려진 장의 화소(판에서 자른 크기)
			expect(math.abs(lab.Size.X.Offset - fw * c.k) < 0.01 and math.abs(lab.Size.Y.Offset - fh * c.k) < 0.01, ("%s: 그리는 크기 = 그림의 화소 x %.3f(%.1f x %.1f)"):format(kind, c.k, lab.Size.X.Offset, lab.Size.Y.Offset))
			expect(lab.ResampleMode == Enum.ResamplerMode.Default, kind .. ": 고운 그림은 부드럽게 줄여 그린다")
			local was = Sprite.preview
			Sprite.preview = 0.5
			m = boss("idle", 0, 0)
			expect(math.abs(m.sprite.label.Size.X.Offset - math.abs(m.sprite.label.ImageRectSize.X) * c.k * 0.5) < 0.01, kind .. ": 관리 창의 미리보기 배율만큼 더 줄여 그린다")
			Sprite.preview = was
			end
			expect(CHARS.chars[def.sprite].fh <= def.body[2] * 2, kind .. ": 몸의 판정이 그림의 크기와 맞는다")
		end
		expect(clips.idle ~= nil and #clips.idle.frames >= 2, kind .. ": 대기 그림이 있다")
		m = boss("run", 0, 0)
		expect(m.sprite.label.Visible == true and m.px == 300, kind .. ": 걷는 모습이 그려진다")
		m = boss("spawn", 0, 0)
		expect(m.sprite.label.ImageTransparency > 0.9, kind .. ": 나타날 때 처음에는 안 보인다")
		m = boss("dead", (def.story.fall or 0.8) + 0.05, 0) -- 쓰러지는 동작 그림이 있는 보스는 그 그림이 다 보인 뒤에(story.fall초), 없는 보스는 0.45초에 걸쳐 사라진다
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
	-- 날아가는 것이 떠 있는 채로 장면을 떠난다(문을 지난다): 그림으로 나는 것도 흰 줄도 오류 없이 치운다
	--  사용자 2026-10-13: "장면을 그리지 못했다 r1c2: … effects:406: attempt to index nil with 'Destroy'" — 빈 투구의 덩어리가 날아가는 동안 문을 지나면 났다
	do
		local leave = Effects.new({}, {}, {})
		leave:addShot({ id = 1, x = 10, y = 20, dir = 1, speed = 110, range = 150, kind = "helm" }, 0)
		leave:addShot({ id = 2, x = 10, y = 20, dir = -1, speed = 170, range = 140, kind = "archer" }, 0)
		leave:update(0.2, 0.05)
		local ok, err = pcall(leave.destroy, leave)
		expect(ok, "날아가는 것이 떠 있어도 이펙트를 치울 수 있다 — " .. tostring(err))
		expect(next(leave.shots) == nil, "날아가던 것이 남지 않는다")
		-- 날아가는 것을 쏘는 몬스터 모두(제 그림으로 나는 것): 떠 있는 채로 치워도 된다
		local n = 0
		for kind, def in COMBAT.mobs do
			if def.atk and def.atk.shot then
				local one = Effects.new({}, {}, {})
				one:addShot({ id = 7, x = 30, y = 40, dir = 1, speed = 100, range = 120, kind = kind }, 0)
				one:update(0.1, 0.05)
				local fine, why = pcall(one.destroy, one)
				expect(fine and next(one.shots) == nil, ("%s의 날아가는 것이 떠 있어도 치운다 — %s"):format(kind, tostring(why)))
				n += 1
			end
		end
		expect(n >= 2, "날아가는 것을 쏘는 몬스터들을 보았다 " .. n)
	end

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
	-- 장면의 효과(가짜): 잔상을 세고, 패턴의 이펙트 그림(스프라이트)을 트는 것을 받아 적는다 — calls에 이름 "sprite" · { 누구의, 동작, x, y, 보는 쪽, opts }
	local effectsFake = {
		ghost = function() ghosts += 1 end,
		play = function(_, who, clip, x, y, dir, opts)
			table.insert(calls, { name = "sprite", args = { who, clip, x, y, dir, opts or {} } })
		end,
	}
	local bv = BossView.new(v2, castFake, effectsFake, scene)
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
	-- 그 동작(이펙트 그림)을 튼 것들
	local function sprs(clip)
		local list = {}
		for _, c in calls do
			if c.name == "sprite" and c.args[2] == clip then
				table.insert(list, c)
			end
		end
		return list
	end
	local function spr(clip)
		return #sprs(clip)
	end
	local OLD = { "beam", "ring", "spike", "shards", "rise", "cut", "slash", "pop", "streaks" } -- 캐릭터 기술의 이펙트 부품 — 보스의 패턴은 이제 쓰지 않는다
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
	-- 치는 순간: 그 패턴의 이펙트 그림(공방 design/bosses.js의 BOSS_FX)을 튼다 — 사용자 2026-10-12 밤: "패턴 이팩트들 스킬이펙트 재사용하지말고 새로 만드세요"
	expect(#q.fx >= 1 and q.wave.fx ~= nil, "땅 울림의 자료에 이펙트 그림이 적혀 있다")
	local hit = sprs(q.fx[1].clip)
	expect(#hit == 1 and castFake.shakeT > 0 and castFake.shakeA >= 2, "치는 순간: 내려찍는 이펙트 그림 하나 + 화면 흔들림")
	eq(hit[1].args[1], "towerlieutenant", "그림은 그 보스의 동작 묶음에서")
	expect(CHARS.chars.towerlieutenant.clips[q.fx[1].clip] ~= nil, "그 그림이 캐릭터 판에 실려 있다")
	eq(hit[1].args[3], 400 + hit[1].args[5] * q.fx[1].dx, "돌망치가 떨어지는 자리(보는 쪽으로 dx)에")
	local wv = sprs(q.wave.fx)
	eq(#wv, 2, "땅 울림: 물결 둘(양쪽)을 튼다")
	expect(wv[1].args[5] == -wv[2].args[5], "물결은 서로 반대쪽으로")
	for _, w in wv do
		local o = w.args[6]
		expect(o.loop == q.wave.range / q.wave.speed and o.vx == w.args[5] * q.wave.speed, "물결: 가는 동안 돌려 틀고(거리 / 빠르기) 그 빠르기로 간다")
		expect(o.lo == bv.lo and o.hi == bv.hi, "물결: 방의 벽 밖으로는 그리지 않는다")
	end
	for _, name in OLD do
		eq(count(name), 0, "기술의 이펙트 부품(" .. name .. ")은 쓰지 않는다")
	end
	eq(count("add"), 1, "판에 거는 것은 예고뿐이다")
	drawn = 0
	adds()[1].args[2](ctx, 0.9)
	eq(drawn, 0, "치고 난 뒤에는 예고를 그리지 않는다")
	snap(1, "idle", 0, 0)
	local n0 = #adds()
	snap(1, "tell", 0.1, qi)
	snap(1, "idle", 0, 0) -- 묶여서 끊겼다
	eq(spr(q.fx[1].clip), 1, "예고가 끊기면(묶임) 치는 이펙트가 없다")
	drawn = 0
	adds()[n0 + 1].args[2](ctx, 0.3)
	eq(drawn, 0, "끊긴 예고는 그리지 않는다")
	-- 이펙트 그림을 트는 것(effects.luau의 play — 진짜): 한 번 틀고 사라진다 · 가는 것은 방의 벽 밖에서 보이지 않는다 · 늦게 뜨는 것은 그때까지 안 보인다
	do
		local ef = Effects.new({}, {}, {})
		local clip = CHARS.chars.towerlieutenant.clips[q.fx[1].clip]
		ef:play("towerlieutenant", q.fx[1].clip, 300, 200, -1)
		eq(#ef.sprites, 1, "이펙트 그림이 뜬다")
		local sp = ef.sprites[1]
		expect(math.abs(sp.life - #clip.frames / clip.fps) < 1e-6, "그 동작의 길이만큼(장 수 / 빠르기)")
		ef:update(0, 0.01)
		expect(sp.sprite.label.Visible == true, "첫 장이 보인다")
		local tt = 0
		while #ef.sprites > 0 and tt < 5 do
			tt += 0.05
			ef:update(tt, 0.05)
		end
		expect(#ef.sprites == 0 and tt < #clip.frames / clip.fps + 0.11, "다 틀면 사라진다")
		-- 물결: 벽(lo = 32) 곁 60 - 40 = 20에서 왼쪽으로 떠나면 처음부터 벽 밖이다 → 보이지 않는다. 오른쪽으로 가는 것은 보인다
		ef:play("towerlieutenant", q.wave.fx, 20, 200, -1, { loop = q.wave.range / q.wave.speed, vx = -q.wave.speed, lo = 32, hi = 700, fade = 0.15 })
		ef:play("towerlieutenant", q.wave.fx, 100, 200, 1, { loop = q.wave.range / q.wave.speed, vx = q.wave.speed, lo = 32, hi = 700, fade = 0.15 })
		ef:update(0, 0.1)
		expect(ef.sprites[1].sprite.label.Visible == false, "벽 밖으로 나간 물결은 보이지 않는다")
		expect(ef.sprites[2].sprite.label.Visible == true, "방 안의 물결은 보인다")
		local x0 = ef.sprites[2].sprite.label.Position.X.Offset
		ef:update(0, 0.5)
		expect(ef.sprites[2].sprite.label.Position.X.Offset - x0 >= q.wave.speed * 0.5 - 2, "물결이 제 빠르기로 간다")
		for _ = 1, 60 do
			ef:update(0, 0.05)
		end
		eq(#ef.sprites, 0, "끝까지 가면 사라진다")
		-- 늦게 뜨는 것(연속 검기의 둘째 · 셋째)
		ef:play("towerlieutenant", q.wave.fx, 100, 200, 1, { loop = 1, vx = 10, delay = 0.4 })
		ef:update(0, 0.2)
		expect(ef.sprites[1].sprite.label.Visible == false, "제 때가 되기 전에는 보이지 않는다")
		ef:update(0, 0.3)
		expect(ef.sprites[1].sprite.label.Visible == true, "제 때가 되면 뜬다")
		-- 없는 그림은 아무 일도 없다
		ef:play("towerlieutenant", "fx_none", 0, 0, 1)
		eq(#ef.sprites, 1, "없는 그림을 틀라고 하면 아무것도 뜨지 않는다")
		ef:destroy()
	end
	-- 정찰대장: 호령(뿔나팔의 소리 + 졸개가 나오는 두 자리의 빛기둥) · 내달리기(박차는 먼지 · 달리는 동안의 먼지 · 벽에 부딪침)
	snap(1, "gone", 0, 0)
	local ci, cp = patOf("scoutcaptain", "call")
	snap(2, "tell", 0.1, ci)
	snap(2, "act", 0.05, ci)
	eq(spr(cp.summon.fx), #cp.summon.at, "호령: 졸개가 나오는 두 자리에 빛기둥")
	eq(spr(cp.fx[1].clip), 1, "호령: 뿔나팔의 소리")
	expect(sprs(cp.summon.fx)[1].args[3] == cp.summon.at[1] and sprs(cp.summon.fx)[2].args[3] == cp.summon.at[2], "빛기둥은 졸개가 나오는 자리에")
	snap(2, "idle", 0, 0)
	local di, dp = patOf("scoutcaptain", "charge")
	snap(2, "tell", 0.1, di)
	n0 = spr(dp.dash.trail.clip)
	snap(2, "dash", 0.02, di)
	expect(spr(dp.dash.trail.clip) - n0 >= 2, "내달리기: 박차는 순간과 달리기 시작할 때의 먼지")
	local n1 = spr(dp.dash.trail.clip)
	for _ = 1, 20 do
		bv:update(0.02)
	end
	local more = spr(dp.dash.trail.clip) - n1
	expect(more >= 2 and more <= 3, ("달리는 동안 먼지가 %.2f초마다 이어진다(0.4초에 %d번)"):format(dp.dash.trail.every, more))
	expect(ghosts >= 2, "내달리는 동안 잔상이 남는다 " .. ghosts)
	castFake.shakeT = 0
	snap(2, "idle", 0, 0)
	expect(spr(dp.dash.crash.clip) == 1 and castFake.shakeT > 0, "내달리기가 끝나면(벽) 부딪치는 그림이 뜨고 화면이 흔들린다")
	eq(BossView.hpLabel(1234.2, 53640, 288, function(t) return #t * 6 end), "1235/53640", "체력의 숫자: 지금/최대")
	eq(BossView.hpLabel(-5, 53640, 288, function(t) return #t * 6 end), "0/53640", "체력이 다하면 0")
	expect(BossView.hpLabel(53640, 53640, 30, function(t) return #t * 6 end) ~= "53640/53640", "칸이 좁으면 짧게 적는다")
	-- ---- 새 패턴(2026-10-12 밤 — 공방 STORYBOSS_NEXT): 표시된 자리 · 도약 · 포효 · 검기 · 연속기 ----
	local BossPat = req("ReplicatedStorage/shared/lune/sim/bosspat")
	local BossFx = req("ReplicatedStorage/shared/lune/bossfx")
	local pushed = nil
	bv:destroy()
	local tracks = {} -- 보스의 곡을 바꾸라는 알림(이름표 또는 false = 맵의 곡으로)
	bv = BossView.new(v2, castFake, effectsFake, scene, { push = function(x, dist) pushed = { x, dist } end, music = function(track) table.insert(tracks, track or false) end })
	local function snap2(id, x, state, st, pat, aim, chain, quick)
		v2:apply({ { id, x, -1, state, st, 900, 0, 0, pat, aim or 0, chain or 0, quick or 0 } }, t)
		v2:update(t)
		bv:update(0.016)
	end
	snap2(2, 400, "gone", 0, 0)
	eq(#tracks, 0, "보스가 없으면 곡을 바꾸지 않는다")
	snap2(1, 600, "idle", 0, 0)
	expect(#tracks == 1 and tracks[1] == COMBAT.mobs.towerlieutenant.story.music and tracks[1] ~= nil, "보스가 나타나면 그 보스의 곡으로 바꾸라고 알린다(한 번)")
	snap2(1, 600, "idle", 0, 0)
	eq(#tracks, 1, "같은 보스가 서 있는 동안에는 다시 알리지 않는다")
	-- 불씨 뿌리기: 예고가 시작되면 맞을 자리(느낌표) + 표시된 자리 넷을 건다. 자리는 서버와 같은 식 — 겨눈 사람의 발밑과 그 좌우
	local ei, e = patOf("towerlieutenant", "embers")
	n0 = count("add")
	snap2(1, 600, "tell", 0.05, ei, 300)
	eq(count("add") - n0, 1 + e.spots.n, "불씨: 예고 + 표시된 자리 넷")
	eq(#bv.spots, e.spots.n, "표시된 자리를 적어 둔다")
	local want = BossPat.spots(e, 300, bv.roomLo, bv.roomHi)
	for i, sp in bv.spots do
		eq(sp.x, want[i][1], "불씨의 자리(서버와 같은 식)")
	end
	eq(bv.spots[1].x, 300, "첫 자리 = 겨눈 사람의 발밑")
	drawn = 0
	adds()[#adds()].args[2](ctx, 0.5)
	expect(drawn > 5, "표시된 자리를 그린다")
	local blast0 = spr(e.spots.fx)
	snap2(1, 600, "act", 0.05, ei, 300)
	eq(spr(e.spots.fx), blast0, "예고가 끝난 순간에는 아직 솟지 않는다(자리마다 제 때에)")
	eq(spr(e.fx[1].clip), 1, "불씨를 뿌리는 순간: 등의 화로가 타오른다")
	for _, sp in bv.spots do
		sp.at -= 5 -- 시간이 흘렀다
	end
	bv:update(0.016)
	eq(spr(e.spots.fx) - blast0, e.spots.n, "때가 되면 자리마다 불씨가 터진다")
	local at300 = false
	for _, c in sprs(e.spots.fx) do
		at300 = at300 or c.args[3] == 300
	end
	expect(at300, "불씨는 표시된 그 자리에서 터진다")
	eq(#bv.spots, 0, "솟고 나면 자리가 사라진다")
	-- 예고하던 중에 끊기면(묶임) 자리도 사라지고 솟지 않는다
	snap2(1, 600, "idle", 0, 0)
	snap2(1, 600, "tell", 0.05, ei, 300)
	local live = bv.spots[1]
	snap2(1, 600, "idle", 0, 0)
	blast0 = spr(e.spots.fx)
	expect(#bv.spots == 0 and live.live == false, "예고가 끊기면 표시된 자리도 사라진다")
	bv:update(0.016)
	eq(spr(e.spots.fx), blast0, "끊긴 자리는 솟지 않는다")
	-- 봉화 불기둥: 방 전체에 깔린다(두 번에 나눠 솟는다)
	local bi, bp = patOf("towerlieutenant", "beacon")
	snap2(1, 400, "tell", 0.05, bi, 300)
	expect(#bv.spots >= 8, ("불기둥의 자리가 방 전체에 깔린다(%d곳)"):format(#bv.spots))
	local early, lateN = 0, 0
	for _, sp in bv.spots do
		if sp.T > bp.tell + 0.01 then
			lateN += 1
		else
			early += 1
		end
	end
	expect(early >= 4 and lateN >= 4 and math.abs(early - lateN) <= 1, "먼저 솟는 칸과 나중 칸이 번갈아 있다")
	snap2(1, 400, "act", 0.05, bi, 300)
	snap2(1, 400, "idle", 0, 0)
	expect(#bv.spots >= 8, "예고가 끝난 뒤에는 보스가 다른 것을 해도 자리가 남는다(제 때에 솟는다)")
	snap2(1, 400, "dead", 0, 0)
	eq(#bv.spots, 0, "보스가 쓰러지면 표시된 자리도 사라진다")
	expect(tracks[#tracks] == false, "보스가 쓰러지면 맵의 곡으로 돌아가라고 알린다")
	-- 도약 찍기: 뛰어오를 때는 박차는 고리만, 내려앉을 때 치는 이펙트 · 몸은 공중에 뜬다(서버와 같은 식)
	snap2(1, 600, "idle", 0, 0)
	local li, lp = patOf("towerlieutenant", "leap")
	snap2(1, 600, "tell", 0.05, li, 300)
	drawn = 0
	adds()[#adds()].args[2](ctx, 0.5)
	expect(drawn > 5, "도약: 내려앉을 자리를 그린다")
	local beam0, ring0 = spr(lp.fx[1].clip), spr(lp.leap.fx)
	snap2(1, 600, "act", 0.05, li, 300)
	expect(spr(lp.fx[1].clip) == beam0 and spr(lp.leap.fx) == ring0 + 1, "도약: 뛰어오르는 순간에는 박차는 먼지만(아직 치지 않는다)")
	snap2(1, 480, "act", lp.leap.time / 2, li, 300)
	local mm = v2:get(1)
	expect(mm.jump > lp.leap.peak * 0.9, ("도약: 몸이 공중에 떠 있다(%.0f점)"):format(mm.jump))
	drawn = 0
	adds()[#adds()].args[2](ctx, 0.5)
	expect(drawn > 5, "도약: 날아가는 동안에도 내려앉을 자리가 보인다")
	snap2(1, 366, "act", lp.leap.time + 0.02, li, 300)
	expect(spr(lp.fx[1].clip) == beam0 + 1 and v2:get(1).jump == 0, "도약: 내려앉으면 치는 이펙트 · 몸은 바닥에")
	snap2(1, 366, "act", lp.leap.time + 0.1, li, 300)
	eq(spr(lp.fx[1].clip), beam0 + 1, "한 번만 친다")
	-- 포효(체력 구간): 큰 고리 · 긴 흔들림 · 가까운 사람을 밀어낸다(boot가 받는다) · 바 아래에 그 이름
	snap2(1, 366, "idle", 0, 0)
	local ph = COMBAT.mobs.towerlieutenant.story.phase
	ring0 = spr(ph.fx)
	castFake.shakeT = 0
	snap2(1, 366, "roar", 0.02, 0)
	expect(spr(ph.fx) - ring0 == 1 and castFake.shakeT >= 0.3, "포효: 그 그림 하나와 긴 흔들림")
	expect(sprs(ph.fx)[1].args[6].back == true and sprs(ph.fx)[1].args[3] == 366, "포효의 그림은 몸의 뒤에 · 보스의 자리에")
	expect(pushed ~= nil and pushed[1] == 366 and pushed[2] == ph.push, "포효: 밀어내라고 알린다(보스의 자리 · 거리)")
	local c1, f1 = BossFx.body("roar", nil, 0, 0, CHARS.chars.towerlieutenant.clips, COMBAT.mobs.towerlieutenant.story.anim, nil)
	expect(c1 == "roar" and f1 == 1, "포효하는 동안 그 동작을 튼다")
	snap2(1, 366, "roar", 0.5, 0)
	eq(spr(ph.fx) - ring0 == 1 and pushed[1], 366, "포효의 이펙트는 한 번")
	-- 연속기: 둘째부터는 예고가 quick배로 짧다(화면의 그림 · 동작의 박자가 서버의 시간과 맞게)
	local combI, comb = patOf("towerlieutenant", "combo")
	local si, sm = patOf("towerlieutenant", "smash")
	snap2(1, 366, "idle", 0, 0)
	snap2(1, 366, "tell", 0.05, si, 300, combI, 0)
	eq(MobsView.patOf(v2:get(1)).tell, sm.tell, "연속기의 첫 번째는 제 예고대로")
	snap2(1, 366, "act", 0.05, si, 300, combI, 0)
	snap2(1, 366, "tell", 0.05, si, 300, combI, 1)
	expect(math.abs(MobsView.patOf(v2:get(1)).tell - sm.tell * comb.quick) < 1e-6, "연속기의 둘째부터는 예고가 quick배")
	expect(MobsView.patOf(v2:get(1)) ~= sm and sm.tell == COMBAT.mobs.towerlieutenant.story.patterns[si].tell, "설계의 패턴은 건드리지 않는다(줄인 것은 따로 만든 것)")
	-- 정찰대장의 검기: 보는 쪽으로 물결 하나 · 연속 검기는 셋(뒤의 둘은 늦게 떠난다)
	snap2(1, 366, "gone", 0, 0)
	local wi, wp = patOf("scoutcaptain", "bladewave")
	snap2(2, 600, "idle", 0, 0)
	snap2(2, 600, "tell", 0.05, wi, 300)
	drawn = 0
	adds()[#adds()].args[2](ctx, 0.5)
	expect(drawn > 5, "검기: 날아갈 길을 그린다")
	n0 = spr(wp.wave.fx)
	local a0 = count("add")
	snap2(2, 600, "act", 0.02, wi, 300)
	eq(spr(wp.wave.fx) - n0, 1, "검기: 제 그림 하나가 날아간다")
	eq(count("add"), a0, "검기를 판에 그리지 않는다(그림을 튼다)")
	local bw = sprs(wp.wave.fx)[spr(wp.wave.fx)]
	expect(bw.args[5] == -1 and bw.args[6].vx == -wp.wave.speed and bw.args[3] == 600 - wp.wave.at, "검기는 보는 쪽으로(왼쪽) 제 빠르기로 · 칼끝에서 떠난다")
	eq(spr(wp.fx[1].clip), 1, "검기를 날리는 순간: 칼을 내리긋는 그림")
	snap2(2, 600, "idle", 0, 0)
	local sti, stp = patOf("scoutcaptain", "storm")
	snap2(2, 600, "tell", 0.05, sti, 300)
	n0 = spr(stp.wave.fx)
	snap2(2, 600, "act", 0.02, sti, 300)
	eq(spr(stp.wave.fx) - n0, stp.wave.n, "연속 검기: 검기 셋")
	local delays = {}
	local all = sprs(stp.wave.fx)
	for i = #all - stp.wave.n + 1, #all do
		table.insert(delays, all[i].args[6].delay)
	end
	table.sort(delays)
	expect(delays[1] <= 0 and math.abs(delays[2] - delays[1] - stp.wave.gap) < 1e-6 and math.abs(delays[3] - delays[1] - stp.wave.gap * 2) < 1e-6, "뒤의 둘은 gap초씩 늦게 떠난다")
	bv:destroy()
	eq(#bv.list, 0, "장면이 바뀌면 치운다")
end

-- ---- 체력 띠의 효과(client/lune/ui/hpBar.luau — 플레이어의 체력 바와 같은 셈) ----
--  사용자 2026-10-13: "몬스터 체력바도  유저 체력바처럼 고도화 되어야합니다."
do
	local HpFx = req("ReplicatedStorage/shared/lune/ui/hpFx")
	local F = HpFx.F
	local kind = nil
	for k, def in COMBAT.mobs do
		if not def.story and not kind then
			kind = k
		end
	end
	local function newView(hp)
		local rm = { mobs = { { id = 1, kind = kind, lv = 5, y = 200, maxHp = 100, name = "시험" } }, snap = {} }
		local v = MobsView.new({}, rm, {})
		return v, v:get(1)
	end
	local t = 100
	local function feed(v, state, hp, dt)
		v:apply({ { 1, 200, 1, state, 0, hp, 0, 0 } }, t)
		v:update(t)
		t += dt or 1 / 60
	end
	-- 없다가 나타난 몬스터: 띠는 가득 찬 채로 준비돼 있다(차오르는 효과 없이)
	local v, m = newView()
	feed(v, "gone", 100)
	feed(v, "spawn", 100)
	feed(v, "idle", 100)
	local st = m.barFx.st
	expect(st.fill == 1 and HpFx.idle(st) and m.bar.frame.Visible == false, "다치지 않은 몬스터: 띠가 없다 · 효과도 없다")
	-- 첫 타: 빨간 띠는 바로 줄고, 닳은 자리(가득 찼던 데까지)가 밝게 남는다 · 희게 번쩍인다
	feed(v, "hit", 60)
	st = m.barFx.st
	expect(m.bar.frame.Visible == true and st.fill == 0.6 and st.lag == 1 and st.kind == "hurt" and st.flash > 0, "첫 타에도 닳은 자리가 남는다")
	eq(m.bar.ratio, 0.6, "빨간 띠는 바로 줄어든다")
	expect(m.barFx.lag.Size.X.Offset > 0 and m.barFx.flash.BackgroundTransparency < 1, "닳은 자리의 띠와 번쩍임이 그려진다")
	-- 잠깐 남아 있다가 따라 줄어든다
	for _ = 1, math.ceil(F.hold * 60 * 0.5) do
		feed(v, "idle", 60)
	end
	expect(m.barFx.st.lag == 1, "잠깐은 그대로 남아 있다")
	for _ = 1, 120 do
		feed(v, "idle", 60)
	end
	expect(HpFx.idle(m.barFx.st) and m.barFx.st.lag == 0.6 and m.barFx.lag.Size.X.Offset == 0 and m.barFx.flash.BackgroundTransparency == 1, "조금 뒤에는 효과가 끝난다(띠만 남는다)")
	expect(m.bar.frame.Visible == true, "다친 몬스터의 띠는 그대로 보인다")
	-- 마지막 타: 쓰러지는 동안에도 띠가 비워지는 것이 보인다 → 효과가 끝나면 사라진다
	feed(v, "dead", 0)
	expect(m.bar.frame.Visible == true and m.barFx.st.fill == 0 and m.barFx.st.lag == 0.6 and m.bar.ratio == 0, "쓰러뜨린 타: 띠가 비고 닳은 자리가 남아 보인다")
	for _ = 1, 150 do
		feed(v, "dead", 0)
	end
	expect(m.bar.frame.Visible == false, "효과가 끝나면 띠가 사라진다")
	-- 다시 나타난다: 가득 찬 채로(차오르는 효과 없이) · 다시 맞으면 또 효과
	feed(v, "gone", 0)
	feed(v, "spawn", 100)
	feed(v, "idle", 100)
	expect(m.barFx.st.fill == 1 and HpFx.idle(m.barFx.st) and m.bar.frame.Visible == false, "다시 나타난 몬스터: 차오르는 효과가 없다")
	feed(v, "hit", 80)
	expect(m.barFx.st.fill == 0.8 and m.barFx.st.lag == 1, "다시 맞으면 또 닳은 자리가 남는다")
	-- 잇달아 맞으면: 닳은 자리는 처음 높이에서 이어진다
	feed(v, "hit", 50)
	expect(m.barFx.st.fill == 0.5 and m.barFx.st.lag == 1, "잇달아 맞으면 닳은 자리가 이어진다")
	-- 이미 다친 몬스터를 처음 봤을 때(다른 사람이 치던 것): 효과 없이 그대로
	local v2, m2 = newView()
	feed(v2, "idle", 40)
	expect(m2.barFx.st.fill == 0.4 and HpFx.idle(m2.barFx.st) and m2.bar.frame.Visible == true, "이미 다친 몬스터: 효과 없이 그 체력으로")
	-- 스토리 보스: 머리 위의 띠는 없다(화면 위의 넓은 바에 뜬다) — 쓰러질 때도
	for k, def in COMBAT.mobs do
		if def.story then
			local rm = { mobs = { { id = 1, kind = k, lv = 5, y = 200, maxHp = 100, name = "보스" } }, snap = {} }
			local vb = MobsView.new({}, rm, {})
			vb:apply({ { 1, 200, 1, "idle", 0, 100, 0, 0 } }, t)
			vb:update(t)
			vb:apply({ { 1, 200, 1, "dead", 0, 0, 0, 0 } }, t + 0.02)
			vb:update(t + 0.02)
			expect(vb:get(1).bar.frame.Visible == false, "스토리 보스는 머리 위의 띠가 없다 " .. k)
			break
		end
	end
end
