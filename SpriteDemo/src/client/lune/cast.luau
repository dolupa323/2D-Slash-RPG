-- 기술의 이펙트를 돌린다 — 공방 시험 탭(dino-workshop/js/lune/luneTab.js)에서 화면에 보이는 쪽만 옮긴 것:
--  "스킬이 쓰는 손잡이 g" · 스킬 진행(구간의 장 번호에 맞춰 일을 터뜨린다) · 날아가는 것 · 늦게 터지는 것 · 화면 효과(흔들림 · 어두워짐 · 번쩍 · 멈칫) · 그리는 차례.
--  사용자 2026-10-08: "시험탭의 이펙트를 게임으로 옮기세요". 직업 묶음(shared/lune/kits)은 시험 탭의 것을 줄마다 옮긴 것이고, 여기서는 그것을 "보이기만" 돌린다:
--    g.hit · g.hitAt = 그 범위에 있는 졸개를 돌려줄 뿐 피해를 주지 않는다(피해 · 숫자는 서버가 정해 보낸다) · g.hurt · g.buff · g.call … = 아무 일도 하지 않는다.
--  그리는 차례(시험 탭의 draw와 같다): [뒤 그림판] 어두워짐 → 뒤의 날아가는 것 → 뒤의 이펙트 → 직업의 drawBack → 졸개에 남은 표시의 뒤쪽 반
--                                    [앞 그림판] 모은 단계 → 앞의 날아가는 것 → 직업의 draw → 앞의 이펙트 → 졸개에 남은 표시의 앞쪽 반 · 표식
--  사람 = actor(나 · 다른 사람). 나: boot.luau가 자리와 상태를 장마다 넣어 준다. 다른 사람: 서버가 알린 기술(Act)을 그 사람의 자리에서 돌린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local G = require(lune.config.game)
local P = require(lune.sim.physics)
local Fx = require(lune.fx)
local Kitset = require(lune.kitset)
local CHARS = require(lune.data["chars.generated"])
local COMBAT = require(lune.data["combat.generated"])
local FxArt = require(script.Parent.fxart)
local Sprite = require(script.Parent.sprite)

local floor, max, min, abs, random, sin, cos, sqrt = math.floor, math.max, math.min, math.abs, math.random, math.sin, math.cos, math.sqrt
local function R(v: number): number
	return floor(v + 0.5)
end

local Cast = {}
Cast.__index = Cast
Cast.speed = 1 -- 이펙트의 빠르기(확인용 — 느리게 돌려 화면을 찍는다)

-- 직업 색의 이름("mint" · "pink") → 색 한 벌
function Cast.tone(name: string)
	return Fx.TONE[name] or Fx.TONE.mint
end

-- view = 장면(SceneView — fxBack · fxFront · camX · camY · root) · scene = 장면의 자료(벽을 본다) · effects = 잔상을 남기는 것 · mobs = 졸개들(MobsView)
function Cast.new(view, scene, effects, mobs)
	local self = setmetatable({}, Cast)
	self.view, self.scene, self.effects, self.mobView = view, scene, effects, mobs
	self.fx = Fx.new()
	self.timers, self.shots, self.actors = {}, {}, {}
	self.clock = 0
	self.shakeA, self.shakeT, self.stopT, self.invertT, self.dimA, self.dimT, self.dimLife = 0, 0, 0, 0, 0, 0, 1
	self.sx, self.sy = 0, 0 -- 이번 장의 흔들림(장면이 맵 틀을 이만큼 민다)
	self.own = nil -- 나
	self.sprites, self.spriteN = {}, 0 -- 몸의 실루엣을 덧그리는 그림들(장마다 쓴 만큼만 보인다)
	-- 화면 반전(시험 탭은 한두 장 색을 뒤집는다 — 게임은 뒤집지 못해 흰빛으로 번쩍인다)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.45
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 90
	flash.Visible = false
	flash.Parent = view.root
	self.flash = flash
	return self
end

-- ---------- 졸개 ----------
local function aliveMob(m): boolean
	return m.state ~= "dead" and m.state ~= "gone" and m.state ~= "spawn"
end

-- 직업 묶음이 읽는 값을 졸개에 얹는다(시험 탭의 졸개와 같은 이름): y 발밑 · h 뜬 높이(게임에는 없다 — 0) · boss · dead(쓰러졌으면 0 이상) · 표시들
function Cast:syncMobs(dt: number)
	for _, m in self.mobView.mobs do
		m.id = m.info.id
		m.y = m.info.y
		m.h = m.alt or 0 -- 나는 몬스터는 떠 있는 높이(mobsView가 셈한다)
		m.boss = m.def.boss == true
		m.dead = if aliveMob(m) then -1 else 0
		m.max = m.info.maxHp
		m.mark = m.mark or 0
		m.markT = m.markT or 0
		m.bind = max(0, (m.bind or 0) - dt)
		m.bindImm = max(0, (m.bindImm or 0) - dt)
		m.stun = max(0, (m.stun or 0) - dt)
		m.rend = max(0, (m.rend or 0) - dt)
		m.cracks = m.cracks or 0
		if m.mark > 0 then
			m.markT -= dt
			if m.markT <= 0 or m.dead >= 0 then
				m.mark = 0
			end
		end
		if m.dead >= 0 then
			m.cracks, m.bind, m.rend, m.stun = 0, 0, 0, 0
		end
	end
end

function Cast:alive()
	local out = {}
	for _, m in self.mobView.mobs do
		if aliveMob(m) then
			out[#out + 1] = m
		end
	end
	return out
end

-- 그 네모 안의 졸개들(시험 탭의 hitBox와 같은 몸 크기). 피해는 주지 않는다
function Cast:box(xa: number, xb: number, ya: number, yb: number)
	local out = {}
	for _, m in self.mobView.mobs do
		if aliveMob(m) then
			local hh, hw = if m.boss then 26 else 12, if m.boss then 12 else 7
			local y = m.info.y
			if m.def.body then -- 새 몬스터: 종류마다의 몸(서버의 room.luau bodyOf와 같다)
				hw, hh = m.def.body[1] / 2 + 1, m.def.body[2]
				y -= (m.def.lift or 0) + (m.alt or 0)
			end
			if m.x + hw > xa and m.x - hw < xb and y > ya and y - hh < yb then
				out[#out + 1] = m
			end
		end
	end
	return out
end

-- ---------- 사람 ----------
local function makeG(self, a)
	-- art = Aseprite로 그린 그림(점 자료) · authority = 판정을 정하는 쪽인가(화면은 아니다 — 서버가 정한 값을 받아 그린다)
	local g = { fx = self.fx, rnd = random, s = {}, PW = self.view.width, art = FxArt, authority = false }
	local GET = {
		x = function()
			return a.x
		end,
		y = function()
			return a.y
		end,
		dir = function()
			return a.dir
		end,
		tone = function()
			return a.tone
		end,
		ground = function()
			return a.ground
		end,
		big = function()
			return if a.scale > 1 then 1.5 else 1
		end,
		lv = function()
			return if a.skill then a.skill.lv else 0
		end,
		held = function()
			return if a.skill then a.skill.t else 0
		end,
		clock = function()
			return self.clock
		end,
		toggle = function()
			return a.toggle
		end,
		hero = function()
			return a
		end,
		pose = function()
			return a.pose
		end,
		riding = function() -- 탈것을 탄 동안(boot · othersView가 안장 위에 작게 그리는 배를 넣는다 — 리븐의 그림자 분신이 따로 걷는다: 2026-10-26)
			return a.rideSize ~= nil
		end,
		cam = function()
			return { x = self.view.camX, y = self.view.camY }
		end,
	}
	setmetatable(g, {
		__index = function(_, key)
			local get = GET[key]
			return if get then get() else nil
		end,
	})
	function g.fwd(d: number): number
		return a.x + a.dir * d
	end
	function g.hit(from: number, to: number, up: number, down: number, _dmg: number, o)
		local k = if a.scale > 1 then 1.5 else 1
		local x0, x1 = a.x + a.dir * from * k, a.x + a.dir * to * k
		local out = self:box(min(x0, x1), max(x0, x1), a.y - up * k, a.y + down)
		if #out > 0 and o and o.stop and a.own then
			self.stopT = max(self.stopT, o.stop) -- 멈칫: 내 타가 닿은 순간 잠깐 선다
		end
		return out
	end
	function g.hitAt(x: number, y: number, hw: number, h: number, _dmg: number, o)
		local out = self:box(x - hw, x + hw, y - h, y + 6)
		if #out > 0 and o and o.stop and a.own then
			self.stopT = max(self.stopT, o.stop)
		end
		return out
	end
	function g.hurt(_m, _dmg, _o)
		return true -- 피해는 서버가 준다
	end
	function g.mobs()
		return self:alive()
	end
	function g.nearest(range: number, o)
		local from, not_, front = (o and o.from) or a.x, o and o["not"], o and o.front
		local best, bd = nil, range
		for _, m in self:alive() do
			if m == not_ or abs(m.y - a.y) > 60 or (front and (m.x - a.x) * a.dir < -8) then
				continue
			end
			local d = abs(m.x - from)
			if d <= bd then
				bd, best = d, m
			end
		end
		return best
	end
	function g.boss()
		local best = nil
		for _, m in self:alive() do
			if abs(m.x - a.x) < 280 and (not best or m.max > best.max) then
				best = m
			end
		end
		return best
	end
	-- 화면 효과는 내가 쓴 기술에만 붙는다(남의 기술이 내 화면을 흔들지 않는다)
	function g.shake(amount: number, t: number)
		if a.own then
			self.shakeA, self.shakeT = max(self.shakeA, amount), max(self.shakeT, t)
		end
	end
	function g.stop(t: number)
		if a.own then
			self.stopT = max(self.stopT, t)
		end
	end
	function g.invert(t: number)
		if a.own then
			self.invertT = t
		end
	end
	-- 화면 가르기(위 Cast:split — 내 기술만): y = 자르는 높이(게임 세계의 점) · dir = 아래 조각이 어긋나는 쪽
	function g.split(y: number, dir: number)
		if a.own then
			self:split(y, dir, a.tone)
		end
	end
	function g.dim(amount: number, t: number)
		if a.own then
			self.dimA, self.dimT, self.dimLife = amount, t, t
		end
	end
	function g.after(d: number, fn)
		self.timers[#self.timers + 1] = { t = d, fn = fn }
	end
	function g.shot(o)
		local p = { t = 0, acc = 0, hitSet = {}, dir = a.dir, who = a.who, w = 0, h = 0, dmg = 0, life = 1 }
		for k, v in o do
			p[k] = v
		end
		self.shots[#self.shots + 1] = p
		return p
	end
	-- 몸을 옮기는 것(내 캐릭터만 — 다른 사람의 자리는 서버가 알려 준다). boot.luau가 control을 넣어 준다
	function g.move(v: number, t: number)
		if a.own and self.control then
			self.control.move(v, t)
		end
	end
	function g.hop(v: number)
		if a.own and self.control then
			self.control.hop(v)
		end
	end
	function g.face(d: number)
		a.dir = d
		if a.own and self.control then
			self.control.face(d)
		end
	end
	-- 순간이동: 내 몸은 바로 옮긴다(서버도 같은 스킬을 돌려 그 자리로 옮겨 적는다 — 어긋나면 서버가 Warp로 바로잡는다). 옮긴 자리를 이어지는 이펙트가 바로 읽는다
	function g.teleport(x: number): boolean
		if a.own and self.control then
			local nx = self.control.teleport(x)
			if nx then
				a.x = nx
				return true
			end
			return false
		end
		return true
	end
	-- 버프 · 스킬 레벨 · 졸개의 표시: 서버가 정한 것을 읽기만 한다
	function g.buff(_id, _dur) end
	function g.has(id: string): boolean
		local b = a.buffs[id]
		return b ~= nil and b.t > 0
	end
	function g.left(id: string): number
		local b = a.buffs[id]
		return if b then b.t else 0
	end
	function g.endBuff(_id) end
	function g.resetCd(_key) end
	function g.sk(id: string): number
		return a.skills[id] or 0
	end
	-- 바인드: 화면의 어림(묶는 것은 서버다 — 졸개의 묶인 시간이 Snap으로 와서 이것을 덮는다. mobsView.luau의 apply)
	function g.bind(m, t: number, kind: string?): boolean
		if (m.bindImm or 0) > 0 then
			return false
		end
		m.bind, m.bindKind, m.bindImm, m.bindAt = t, kind, t + 90, os.clock()
		return true
	end
	function g.call(_name, ...) end -- 서버가 정해 알린다(Cast:call로 온다)
	function g.drag(_m, _x) end -- 졸개를 끌어 옮기는 것은 서버가 한다
	function g.heal(_k) end
	function g.revive() end
	function g.chargeMax(): number
		return if a.kit and a.kit.chargeMax then a.kit.chargeMax(g) else 2
	end
	function g.ghost(color)
		local p = a.pose
		if p and self.effects then
			self.effects:ghost(a.who, p.clip, p.f + 1, a.x, a.y, a.dir, Color3.fromRGB(bit32.rshift(color or a.tone.n, 16), bit32.band(bit32.rshift(color or a.tone.n, 8), 255), bit32.band(color or a.tone.n, 255)))
		end
	end
	-- 잔상을 아무 자리에(리븐의 잔영 베기 — 2026-10-30): 그 동작의 f째 장(0부터)을 (x, y)에 한 색으로 남긴다(잔상처럼 옅어진다)
	function g.shade(clip: string, f: number, x: number, y: number, dir: number, color: number?)
		if self.effects then
			local c = color or a.tone.n
			self.effects:ghost(a.who, clip, f + 1, x, y, dir, Color3.fromRGB(bit32.rshift(c, 16), bit32.band(bit32.rshift(c, 8), 255), bit32.band(c, 255)))
		end
	end
	-- 몸의 한 색 실루엣을 덧그린다(분신 · 굳은 몸의 윤곽 · 사신의 그림자 · 망령): 그 동작의 f째 장(0부터)을 (x, y)에. o = { color, alpha } — 그리는 동안(draw)에만 부른다.
	--  캐릭터들의 층 맨 뒤에 놓인다(몸 뒤). o.scale = 크기(거신)
	-- 그 동작의 장 수(내 캐릭터 그림의 — 없으면 1)
	function g.frames(clip: string): number
		local char = CHARS.chars[a.who]
		local c = char and char.clips[clip]
		return if c then math.max(1, #c.frames) else 1
	end
	function g.sprite(clip: string, f: number, x: number, y: number, dir: number, o)
		self.spriteN += 1
		local sp = self.sprites[self.spriteN]
		if not sp or sp.who ~= a.who then
			if sp then
				sp:destroy()
			end
			sp = Sprite.new(self.view.heroLayer, a.who, 0, true)
			sp.label.Name = "Shade"
			self.sprites[self.spriteN] = sp
		end
		local c = (o and o.color) or a.tone.n
		sp.label.ImageColor3 = Color3.fromRGB(bit32.rshift(c, 16), bit32.band(bit32.rshift(c, 8), 255), bit32.band(c, 255))
		sp.label.ImageTransparency = 1 - ((o and o.alpha) or 1)
		sp:set(clip, f + 1, x, y, dir, o and o.scale)
	end
	return g
end

-- 사람을 올린다(이미 있으면 그대로). own = 나
function Cast:actor(id: any, who: string, own: boolean?)
	local a = self.actors[id]
	if a and a.who == who then
		return a
	end
	local kit = Kitset.of(who)
	a = { id = id, who = who, kit = kit, tone = Fx.TONE[(kit and kit.tone) or "mint"], x = 0, y = 0, dir = 1, ground = true, vx = 0, vy = 0, scale = 1, alpha = 1, sil = nil, skill = nil, buffs = {}, toggle = false, own = own == true, skills = {}, pose = nil, charge = 0 }
	a.g = makeG(self, a)
	if kit and kit.init then
		kit.init(a.g)
	end
	self.actors[id] = a
	if own then
		self.own = a
	end
	return a
end

function Cast:drop(id: any)
	local a = self.actors[id]
	if a and a.shades then
		for _, sp in a.shades do
			sp:destroy()
		end
	end
	self.actors[id] = nil
end

-- 그 사람의 몸을 그린다 — 버프가 입히는 모습까지(시험 탭이 몸을 그리는 그 줄들):
--   크기(거신의 두 배) · 비치는 몸(그림자 숨기 · 연막 · 저승 걸음) · 한 색 실루엣(sil) · 윤곽을 따라 도는 빛(직업 묶음의 heroGlow — 네 쪽으로 한 점씩 민 실루엣) · 몸에 얹는 색(heroTint)
--  body = 그 사람의 몸 그림(Sprite) · (clip, frame) = 지금의 동작과 장(1부터) · fade = 그 밖의 비침(맞은 직후의 깜빡임 — 0이면 또렷하다)
local GLOW = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local function rgb(c: number): Color3
	return Color3.fromRGB(bit32.rshift(c, 16), bit32.band(bit32.rshift(c, 8), 255), bit32.band(c, 255))
end
function Cast:look(a, body, clip: string, frame: number, x: number, y: number, dir: number, fade: number?)
	local kit, g = a.kit, a.g
	-- rideSize = 탄 동안 줄여 그리는 배(boot — rideView가 돌려준 것) · grow = 힘을 모은 단계마다 커지는 몫(액시온 — 2026-10-28 리마스터 · 그리기만)
	local sc = (a.scale or 1) * (a.rideSize or 1) * (1 + (if kit and kit.grow then kit.grow * (a.charge or 0) else 0))
	local alpha = max(fade or 0, 1 - (a.alpha or 1))
	body:set(clip, frame, x, y, dir, sc)
	body.label.ImageTransparency = alpha
	local glow = if kit and kit.heroGlow then kit.heroGlow(g) else nil
	local tint = if kit and kit.heroTint then kit.heroTint(g) else nil
	local sil = a.sil
	local sh = a.shades
	if not sh then
		if not (glow or tint or sil) then
			return
		end
		-- 덧그리는 실루엣들: 윤곽 빛 넷(몸 뒤) · 실루엣 하나(몸의 자리) · 얹는 색 하나(몸 앞)
		sh = {}
		local z = body.label.ZIndex
		for i = 1, 6 do
			sh[i] = Sprite.new(self.view.heroLayer, a.who, if i <= 4 then max(0, z - 1) elseif i == 5 then z else z + 1, true)
			sh[i].label.Name = "Look"
		end
		a.shades = sh
	end
	for i = 1, 4 do
		if glow then
			sh[i]:set(clip, frame, x + GLOW[i][1], y + GLOW[i][2], dir, sc)
			sh[i].label.ImageColor3 = rgb(glow)
		else
			sh[i].label.Visible = false
		end
	end
	if sil then
		sh[5]:set(clip, frame, x, y, dir, sc)
		sh[5].label.ImageColor3 = rgb(sil)
		sh[5].label.ImageTransparency = alpha
		body.label.Visible = false
	else
		sh[5].label.Visible = false
	end
	if tint then
		sh[6]:set(clip, frame, x, y, dir, sc)
		sh[6].label.ImageColor3 = rgb(tint[1])
		sh[6].label.ImageTransparency = 1 - tint[2]
	else
		sh[6].label.Visible = false
	end
end

-- 그 기술의 그 구간이 시작됐다. lv = 모은 단계
function Cast:start(a, id: string, seg: number, lv: number?)
	local def = a.kit and a.kit.byId[id]
	local s = def and def.segs and def.segs[seg]
	if not s then
		a.skill = nil
		return
	end
	-- 앞 구간에서 이어지는 것이면 그 구간을 닫는다: 다 틀고 넘어가는 구간은 아직 안 터진 장의 이펙트를 마저 내고, 끝날 때의 일을 부른다(몰아치기의 휘두른 시간 …)
	local prev = a.skill
	if prev and prev.def == def and prev.i == seg - 1 then
		local ps = prev.s
		if not (ps.hold or ps.charge or ps.till) then
			for _, e in ps.evs do
				if not prev.fired[e[1]] then
					prev.fired[e[1]] = true
					e[2](a.g)
				end
			end
		end
		if ps.finish then
			ps.finish(a.g)
		end
	end
	local clip = CHARS.chars[a.who].clips[s.clip]
	a.skill = { def = def, i = seg, s = s, t = 0, lv = lv or 0, fired = {}, acc = 0, last = s.to or (if clip then #clip.frames - 1 else 0) }
	a.charge = lv or 0 -- 모은 단계: 모아 친 구간 동안 커진 몸(액시온 — 다른 사람의 것은 서버가 Act로 알려 준 단계 · 2026-10-28)
	a.chargeP = nil -- 모으는 게이지(내 캐릭터만 — 모으는 구간 동안 boot가 채운다)
	if s.start then
		s.start(a.g)
	end
end

-- 바로 걸리는 것(버프 · 생존기 · 극딜 — 쓰는 동작이 없다): 걸리는 순간의 이펙트
function Cast:instant(a, id: string)
	local def = a.kit and a.kit.byId[id]
	if def and def.cast then
		def.cast(a.g)
	end
end

-- 그 사람에게 걸린 버프(서버가 알려 준 것)를 받아 적는다. list = { { id, t, dur, x, y } … }
-- 버프를 건 직업의 색(공용은 받은 사람의 색)
local function buffTone(a, id: string)
	local def = COMBAT.buffs[id]
	local kit = def and def.who ~= "all" and Kitset.of(def.who)
	return if kit and kit.tone then Cast.tone(kit.tone) else a.tone
end
function Cast:setBuffs(a, list)
	local old = a.buffs
	a.buffs = {}
	for _, b in list do
		a.buffs[b.id] = { t = b.t, dur = b.dur, x = b.x, y = b.y }
		-- 파티원이 걸어 준 버프가 막 걸렸다: 받은 사람의 몸에도 그 직업 색의 기운이 솟는다(2026-10-24 사용자 "파티케어 스킬 … 적용안되는 버그" —
		--  전에는 건 사람의 몸에만 기운이 보여, 받은 사람은 오른쪽 위 칸 말고는 걸린 줄 몰랐다). 건 자리가 내 자리와 멀거나 다른 직업의 버프면 남이 건 것
		local def = COMBAT.buffs[b.id]
		if def and not old[b.id] and b.dur - b.t < 1.5 and b.x and b.y then
			local byOther = (def.who ~= "all" and def.who ~= a.who) or abs(b.x - a.x) > 24 or abs(b.y - a.y) > 24
			if byOther then
				local tone = buffTone(a, b.id)
				self.fx.aura(a.x, a.y, tone, { r = 12, h = 30, life = 0.6 })
				self.fx.ring(a.x, a.y - 2, 4, 22, tone, { squash = 0.35, back = true, life = 0.5 })
			end
		end
	end
	for id, was in old do
		if not a.buffs[id] then
			-- 죽음의 가호가 쓰러질 피해를 버텨 주고 사라졌다(시간이 남아 있었다): 몸에서 그 색의 빛이 터진다 — 버텨 준 것이 보인다(2026-10-24)
			local def = COMBAT.buffs[id]
			if def and def.fx.ward and was.t > 0.5 then
				local tone = buffTone(a, id)
				self.fx.aura(a.x, a.y, tone, { r = 18, h = 40, life = 0.8 })
				self.fx.ring(a.x, a.y - 14, 6, 34, tone, { squash = 1, back = false, life = 0.45 })
				self.fx.shards(a.x, a.y - 14, 12, tone, { speed = 60, up = 70, kind = "dot", grav = -40, life = 0.7 })
			end
			-- 사라진 것: 끝났을 때의 이펙트(굳었던 빛이 깨져 흩어진다 · 돔이 깨진다)
			if a.kit and a.kit.onBuffEnd then
				a.kit.onBuffEnd(a.g, id)
			end
		end
	end
end

-- 힘이 한 단계 모였다(시험 탭: 단계가 오를 때마다 고리가 오므라든다). full = 키를 누르고 있어 끝까지 모였다(만월로 바로 찬 것은 아니다):
--  화면이 살짝 흔들리고 게이지가 잠깐 흰색으로 깜빡인 채 남는다(2026-10-28 사용자 "차징 풀차징시 살짝 흔들림이 있게" — 1점 · 0.15초 · 0.3초, 제가 정한 값)
function Cast:chargeUp(a, lv: number, full: boolean?)
	a.charge = lv
	self.fx.ring(a.x, a.y - 8, 26 + lv * 8, 4, a.tone, { squash = 1, back = false, life = 0.25 })
	self.fx.shards(a.x, a.y - 8, 4 + lv * 2, a.tone, { speed = 40, up = 60, kind = "dot", grav = -60, life = 0.4 })
	if full then
		a.g.shake(1, 0.15)
		a.gaugeFull = 0.3
	end
end

-- 레벨이 올랐다(2026-10-18 — 메이플스토리처럼 캐릭터 둘레로 빛이 솟는다. 전에는 머리 위의 글씨와 소리뿐이었다): 큰 기운 · 발밑의 넓은 고리 · 위로 흩어지는 점(직업 색)
--  시험 탭 js/lune/luneTab.js의 gainXp가 같은 값으로 그린다
function Cast:levelUp(a)
	self.fx.aura(a.x, a.y, a.tone, { r = 18, h = 46, life = 0.9 })
	self.fx.ring(a.x, a.y - 2, 4, 34, a.tone, { squash = 0.35, back = true, life = 0.7 })
	self.fx.shards(a.x, a.y - 10, 14, a.tone, { speed = 30, up = 90, kind = "dot", grav = -80, life = 0.9 })
end

-- 사냥터 정예가 나왔다(2026-10-18 — 시험 탭의 spawnElite와 같다): 그 자리에서 분홍 기운이 솟고 고리가 퍼지며 불티가 오른다
function Cast:eliteRise(x: number, y: number)
	local tone = Cast.tone("pink")
	self.fx.aura(x, y, tone, { r = 16, h = 40, life = 1.1 })
	self.fx.ring(x, y - 2, 4, 30, tone, { squash = 0.35, back = true, life = 0.8 })
	self.fx.shards(x, y - 8, 12, tone, { speed = 26, up = 80, kind = "dot", grav = -60, life = 1 })
end

-- 사출기를 켰다(시험 탭: 켜는 순간 작은 기운)
function Cast:toggled(a)
	self.fx.aura(a.x, a.y, a.tone, { r = 10, h = 16, life = 0.35 })
end

-- 졸개가 맞았다(시험 탭의 hurt): 파편이 튄다. 쓰러졌으면 세모 파편이 터진다. by = 때린 사람의 직업 색
--  dir = 때린 쪽의 반대(몬스터가 밀리는 쪽 — 1 · -1): 불꽃은 때린 쪽으로 조금 치우친 자리에서 퍼지고, 파편은 반대쪽으로 튄다(공방 combat.js의 hit)
function Cast:hurt(m, tone, big: boolean?, dead: boolean?, dir: number?)
	local y = m.info.y
	local H = COMBAT.rules.hit
	self.fx.pop(m.x - (dir or 0) * 3, y - 8, tone, { r = if big then H.sparkBig else H.spark, life = 0.14 })
	self.fx.shards(m.x, y - 7, if big then H.shardsBig else H.shards, tone, { speed = 70, up = 40, kind = "mix", life = 0.4, dir = dir or 0, spread = 1.2 })
	if dead then
		self.fx.shards(m.x, y - 6, 8, tone, { kind = "tri" })
	end
end

-- 서버가 알린 따로 나가는 타(지금의 1차 — 메아리 도끼 · 표창 · 도깨비불 …). 그 직업 묶음에 이펙트가 있으면 돌리고 true(land = 닿은 순간에 부를 것)
--  e = 그 타의 기록(i 몇째 것 · n 한 번에 나간 수 · hop 튕긴 것 · up 그 사람이 배운 사출기 강화 — 1 하나 더 · 2 셋째 갈래 · 4 넷째 갈래)
function Cast:proc(a, kind: string, m, sx: number, sy: number, land: () -> (), e): boolean
	local fn = a and a.kit and a.kit.procs and a.kit.procs[kind]
	if not fn then
		return false
	end
	-- 남의 것: 그 사람이 배운 강화를 받아 적어 그 모습(큰 도끼 · 불새 …)으로 그린다(내 것은 내 스킬 레벨을 그대로 읽는다)
	local ups = COMBAT.kitUp[a.who]
	if e and e.up and not a.own and ups then
		for role, def in ups do
			local bit = if role == "two" then 1 elseif role == "fast" then 4 else 2
			a.skills[def.id] = if bit32.band(e.up, bit) ~= 0 then 1 else 0
		end
	end
	fn(a.g, m, { sx = sx, sy = sy, land = land, i = e and e.i, n = e and e.n, hop = e and e.hop })
	return true
end

-- 화면 가르기(리븐 4차 천지 가르기 — 2026-10-24 사용자 "모니터 잘린다음에잘려야지 선만긋고 흔들리면어떡해"):
--  그 순간의 장면(view.root)을 통째로 둘 복사해 위 · 아래 두 조각(화면 틀의 잘린 틀)에 담고, 위는 등 뒤 · 위로 · 아래는 앞 · 아래로 어긋났다가 다시 붙는다.
--  그동안 진짜 장면은 숨긴다(복사한 조각은 그 순간에 멈춘 모습). 벌어진 틈은 검고 가운데에 빛나는 칼자국 줄. 시험 탭(luneTab.js의 split)과 같은 때 · 같은 폭
--  자르는 줄은 수평이다(Roblox의 화면 틀은 기울인 채로 잘라 내지 못한다 — 시험 탭도 같게 수평)
local SPLIT = { life = 0.45, open = 0.15, hold = 0.7, dx = 16, gap = 5 } -- 초 · 벌어지는 몫 · 붙기 시작하는 몫 · 앞뒤로 어긋나는 점 · 위아래로 벌어지는 점
function Cast:split(wy: number, dir: number, tone)
	local view = self.view
	local root = view.root
	local parent = root and root.Parent
	if self.splitFx or not parent then
		return
	end
	local W, H = G.VIEW_W, G.VIEW_H
	local cut = math.clamp(R(wy - view.camY), 40, H - 40)
	local box = Instance.new("Frame") -- 조각들을 담는 틀(장면이 바뀌면 SceneView:destroy가 같이 지운다)
	box.Name = "Split"
	box.BackgroundColor3 = Color3.fromRGB(5, 7, 10) -- 벌어진 틈의 빛깔
	box.BorderSizePixel = 0
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = root.ZIndex + 1
	box.Parent = parent
	view.splitBox = box
	local pieces = {}
	for i, part in { { 0, cut }, { cut, H - cut } } do
		local clip = Instance.new("Frame")
		clip.Name = "Piece" .. i
		clip.BackgroundTransparency = 1
		clip.BorderSizePixel = 0
		clip.ClipsDescendants = true
		clip.Position = UDim2.fromOffset(0, part[1])
		clip.Size = UDim2.fromOffset(W, part[2])
		clip.ZIndex = 2
		clip.Parent = box
		local copy = root:Clone()
		copy.Position = UDim2.fromOffset(0, -part[1])
		copy.Visible = true
		copy.Parent = clip
		pieces[i] = clip
	end
	local function bar(h: number, color: Color3, z: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, 0, 0, h)
		f.Position = UDim2.fromOffset(0, cut - h // 2)
		f.ZIndex = z
		f.Parent = box
		return f
	end
	local function rgb(c): Color3
		return Color3.fromRGB(bit32.rshift(c, 16) % 256, bit32.rshift(c, 8) % 256, c % 256)
	end
	local glow = bar(6, rgb(tone and tone.n or 0x3effd7), 1)
	local line = bar(2, Color3.new(1, 1, 1), 3)
	root.Visible = false
	self.splitFx = { t = 0, cut = cut, dir = if dir < 0 then -1 else 1, pieces = pieces, box = box, glow = glow, line = line, root = root }
end
local function endSplit(self)
	local s = self.splitFx
	self.splitFx = nil
	if s.box.Parent then
		s.box:Destroy()
	end
	if self.view.splitBox == s.box then
		self.view.splitBox = nil
	end
	if s.root.Parent then
		s.root.Visible = true
	end
end
function Cast:stepSplit(dt: number)
	local s = self.splitFx
	if not s then
		return
	end
	s.t += dt
	local k = s.t / SPLIT.life
	if k >= 1 or not s.root.Parent then
		endSplit(self)
		return
	end
	local open = if k < SPLIT.open then k / SPLIT.open elseif k < SPLIT.hold then 1 else max(0, 1 - (k - SPLIT.hold) / (1 - SPLIT.hold))
	local dx, gap = R(SPLIT.dx * open) * s.dir, R(SPLIT.gap * open)
	s.pieces[1].Position = UDim2.fromOffset(-dx, -gap)
	s.pieces[2].Position = UDim2.fromOffset(dx, s.cut + gap)
	s.line.BackgroundTransparency = 1 - open
	s.glow.BackgroundTransparency = 1 - 0.5 * open
end

function Cast:update(dt: number)
	self:stepSplit(dt) -- (멈칫과 상관없이 진짜 시간으로)
	dt *= Cast.speed
	self.shakeT = max(0, self.shakeT - dt)
	if self.shakeT == 0 then
		self.shakeA = 0
	end
	self.invertT = max(0, self.invertT - dt)
	self.dimT = max(0, self.dimT - dt)
	local sh = if self.shakeT > 0 then self.shakeA else 0
	self.sx, self.sy = R((random() * 2 - 1) * sh), R((random() * 2 - 1) * sh * 0.6)
	self:syncMobs(dt)
	if self.stopT > 0 then
		self.stopT -= dt -- 멈칫: 맞는 순간 이펙트가 잠깐 선다
		return
	end
	self.clock += dt
	local timers = self.timers
	for i = #timers, 1, -1 do
		local t = timers[i]
		t.t -= dt
		if t.t <= 0 then
			table.remove(timers, i)
			t.fn()
		end
	end
	for _, a in self.actors do
		local g = a.g
		if a.gaugeFull then
			a.gaugeFull = if a.gaugeFull > dt then a.gaugeFull - dt else nil
		end
		for _, b in a.buffs do
			b.t = max(0.01, b.t - dt) -- 끝나는 것은 서버가 알린다(그때까지는 걸려 있는 모습이다)
		end
		if a.kit and a.kit.tick then
			a.kit.tick(g, dt)
		end
		-- 스킬 진행: 구간의 장 번호에 맞춰 일을 터뜨린다
		local sk = a.skill
		if sk then
			local s = sk.s
			local haste = if s.charge then 1 else (a.haste or 1) -- 공격 속도 버프: 동작 · 타격 시점 · 되풀이 타격 간격이 빨라진다(힘 모으기 구간은 그대로)
			sk.t += dt * haste
			local f = (s.from or 0) + floor(sk.t * (s.fps or 14))
			for _, e in s.evs do
				if f >= e[1] and not sk.fired[e[1]] then
					sk.fired[e[1]] = true
					e[2](g)
				end
			end
			if s.every then
				sk.acc += dt * haste
				while sk.acc >= s.every[1] do
					sk.acc -= s.every[1]
					s.every[2](g)
				end
			end
			-- 끝: 보통 구간은 마지막 장을 넘기면. 누르고 있는 구간 · 모으는 구간 · 조건을 기다리는 구간은 다음 구간이 시작되면 바뀐다(안 오면 max에서 끝난다)
			local done
			if s.loop then
				done = sk.t >= s.dur
			elseif s.hold or s.charge or s.till then
				done = sk.t >= (s.max or 3)
			else
				done = f > sk.last
			end
			if done then
				if s.finish then
					s.finish(g)
				end
				if a.skill == sk then
					a.skill = nil
					a.charge = 0
					a.chargeP = nil
				end
			end
		end
	end
	-- 날아가는 것 · 놓인 것 · 따라다니는 것
	local shots = self.shots
	for i = #shots, 1, -1 do
		local p = shots[i]
		p.t += dt
		local gone = false
		if p.target then -- 쫓아가는 것: 닿으면 onReach
			local tm = p.target
			local tx, ty = tm.x, tm.y - tm.h - (if tm.boss then 14 else 7)
			local d = sqrt((tx - p.x) ^ 2 + (ty - p.y) ^ 2)
			if tm.dead >= 0 then
				table.remove(shots, i)
				continue
			end
			if d < 6 then
				if p.onReach then
					p.onReach(p)
				end
				table.remove(shots, i)
				continue
			end
			local sp = (p.speed or 200) * dt
			p.x += ((tx - p.x) / d) * sp
			p.y += ((ty - p.y) / d) * sp + (p.curl or 0) * sin(p.t * 12) * dt
		else
			if p.g then
				p.vy = (p.vy or 0) + p.g * dt
			end
			p.x += (p.vx or 0) * dt
			p.y += (p.vy or 0) * dt
		end
		if p.update then
			p.update(p, dt)
		end
		if p.every then
			p.acc += dt
			while p.acc >= p.every[1] do
				p.acc -= p.every[1]
				p.every[2](p)
			end
		end
		if p.dmg ~= 0 then
			for _, m in self.mobView.mobs do
				local hh = if m.boss then 26 else 12
				if m.dead >= 0 or abs(m.x - p.x) > p.w / 2 + 7 or m.y - m.h < p.y - p.h / 2 - 2 or m.y - m.h - hh > p.y + p.h / 2 then
					continue
				end
				local was = p.hitSet[m]
				if was ~= nil and not (p.tick and p.t - was >= p.tick) then
					continue
				end
				p.hitSet[m] = p.t
				if p.onHit then
					p.onHit(p, m)
				end
			end
		end
		local wall = ((p.vx or 0) ~= 0 or (p.vy or 0) ~= 0) and not p.ghost and P.cell(self.scene, floor(p.x / G.TILE), floor(p.y / G.TILE)) == "#"
		if p.dead or p.t >= p.life or wall or gone then
			if p.finish then
				p.finish(p, wall)
			end
			table.remove(shots, i)
		end
	end
	self.fx.update(dt)
end


function Cast:draw()
	local view = self.view
	local back, front = view.fxBack, view.fxFront
	local cx, cy = view.camX, view.camY
	back:begin(cx, cy)
	front:begin(cx, cy)
	self.spriteN = 0
	self.flash.Visible = self.invertT > 0
	local own = self.own
	-- 큰 기술 · 극딜: 배경을 어둡게 눌러 네온이 도드라지게
	local dim = if self.dimT > 0 then self.dimA * min(1, self.dimT / (self.dimLife * 0.25), (self.dimLife - self.dimT) / 0.12) else 0
	if own and own.kit and own.kit.dim then
		dim = max(dim, own.kit.dim(own.g) or 0)
	end
	if dim > 0 then
		back:alpha(dim)
		back:style(0x12161c)
		back:rect(cx - 8, cy - 8, G.VIEW_W + 16, G.VIEW_H + 16)
		back:alpha(1)
	end
	for _, p in self.shots do
		if p.back and p.draw then
			p.draw(back, p)
		end
	end
	self.fx.draw(back, true)
	for _, a in self.actors do
		if a.kit and a.kit.drawBack then
			a.kit.drawBack(back, a.g)
		end
	end
	local kit = own and own.kit
	if kit then
		for _, m in self.mobView.mobs do
			if m.dead and m.dead < 0 then
				local sc = if m.boss then 2 else 1
				if kit.drawMarks then
					kit.drawMarks(back, own.g, m, sc, false)
				end
				if m.bind > 0 and kit.drawBind then
					kit.drawBind(back, own.g, m, sc, false) -- 바인드: 휘감는 기운의 뒤쪽 반
				end
			end
		end
	end
	-- 모으는 게이지(내 캐릭터 — 2026-10-28 사용자 "점으로 1,2,3 단계로 하는게아니라 게이지로 차오르는게 보이게"): 머리 위에 20 x 4점 —
	--  어두운 테두리 안에 모은 만큼 밝은 색이 차오른다(단계로 칸을 나누지 않는다). 끝까지 차면 흰색으로 깜빡이며 잠깐 남는다(gaugeFull — 위 chargeUp)
	for _, a in self.actors do
		local p = if a.gaugeFull then 1 else a.chargeP
		if p then
			local sc = (a.scale or 1) * (1 + (if a.kit and a.kit.grow then a.kit.grow * a.charge else 0)) -- 커진 몸의 머리 위
			local x, y = R(a.x) - 10, R(a.y) - R(20 * sc) - 4 -- 머리(몸 키 17점쯤) 위로 7 ~ 9점(공방 시험 탭의 그림으로 맞춘 자리)
			front:alpha(1)
			front:style(a.tone.d)
			front:rect(x, y, 20, 4)
			local w = floor(18 * math.clamp(p, 0, 1) + 0.5)
			if w > 0 then
				front:style(if p >= 1 and floor(self.clock * 12) % 2 == 0 then a.tone.w else a.tone.l)
				front:rect(x + 1, y + 1, w, 2)
			end
		end
	end
	for _, p in self.shots do
		if not p.back and p.draw then
			p.draw(front, p)
		end
	end
	for _, a in self.actors do
		if a.kit and a.kit.draw then
			a.kit.draw(front, a.g)
		end
	end
	self.fx.draw(front, false)
	for _, m in self.mobView.mobs do
		if not (m.dead and m.dead < 0) then
			continue
		end
		local sc = if m.boss then 2 else 1
		local top, mx = R(m.y - m.h) - 13 * sc, R(m.x)
		if kit then
			if kit.drawMarks then
				kit.drawMarks(front, own.g, m, sc, true, top) -- (top = 머리 위 — 리븐의 표식이 쓴다 · 2026-10-30)
			end
			if m.bind > 0 and kit.drawBind then
				kit.drawBind(front, own.g, m, sc, true) -- 앞쪽 반
			end
		end
		if m.stun > 0 then
			front:style(0xeef6f6)
			for i = 0, 2 do
				local a = self.clock * 6 + i * 2.1
				front:rect(R(mx + cos(a) * 6), R(top - 3 + sin(a) * 2), 1, 1)
			end
		end
		-- (표식은 리븐 묶음의 drawMarks가 그린다 — 머리 위 민트 초승달 · 2026-10-30. 전에는 여기서 작은 + 셋)
	end
	for i = self.spriteN + 1, #self.sprites do
		self.sprites[i].label.Visible = false
	end
	back:present()
	front:present()
end

return Cast
