-- 스토리 보스의 화면 — 예고(바닥에 칠해지는 맞을 자리 · 머리 위의 느낌표) · 치는 순간의 이펙트 그림과 화면 흔들림 · 땅 울림의 물결 · 내달리기의 잔상과 먼지 ·
--  화면 위 가운데의 체력 바(이름 · 숫자 · 지금 쓰는 패턴의 이름).
--  보스가 무엇을 하는지는 서버가 정한다(sim/room.luau의 stepBoss) — 여기서는 서버가 보내는 모습(상태 · 패턴의 차례 · 흐른 시간: mobsView가 받아 적는다)이
--  바뀌는 때를 보고 그림을 띄운다. 그리는 것은 shared/lune/bossfx.luau(공방 시험 탭의 bossfx.js를 옮긴 것), 자료는 COMBAT.mobs[보스].story(공방 design/bosses.js의 STORYBOSS).
--  몸의 그림(대기 그림을 움직여 대신하는 것 · 예고 때의 분홍 윤곽)은 mobsView.luau가 그린다.
--  사용자 2026-10-11(해 보고): "뭐 보스 패턴도 없고 이펙트도없고 체력 몇인지도 숫자로안보이고 …" → 체력 바 안에 숫자(지금/최대)를 적고, 패턴을 쓸 때 그 이름을 바 아래에 띄우고, 예고와 이펙트를 크게 했다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local BossFx = require(lune.bossfx)
local BossPat = require(lune.sim.bosspat) -- 표시된 자리 · 도약 · 물결의 자리와 시간(서버와 같은 셈)
local MobsView = require(script.Parent.mobsView)
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)
local HpBar = require(script.Parent.ui.hpBar) -- 체력 바의 효과(플레이어의 체력 바와 같은 셈)

local C = Ui.COLOR
local M = Ui.M
local TRAIL = 0.05 -- 내달리는 동안 발밑의 먼지를 내는 간격(초 — 그 패턴에 적힌 것이 없을 때)
local GHOST = 0.07 -- 내달리는 동안 잔상을 남기는 간격(초)
local PINK = Color3.fromRGB(255, 126, 162) -- 패턴의 이름 · 잔상(적의 분홍)

local BossView = {}
BossView.__index = BossView

-- 화면 위 가운데의 체력 바(한 번 만든다): 이름(금색) · 넓은 바(안에 지금/최대 숫자) · 그 아래에 지금 쓰는 패턴의 이름(분홍)
--  공방 「기본 · UI」의 UILAYOUT.boss · 시험 탭의 P.bossBar와 같은 자리 · 크기
function BossView.init(root: Frame)
	local B = Layout.BOSS
	local box = Stage.place(root, "Boss", "tc", math.floor((Stage.REF_W - B.w) / 2), B.y, B.w, B.patY + 16)
	box.Visible = false
	BossView.box = box
	BossView.name = Ui.text(box, "", 0, 0, B.w, { font = "body", color = C.gold, align = "center", outline = true })
	BossView.bar = Ui.bar(box, 0, B.barY, B.w, B.h, C.hp)
	BossView.barFx = HpBar.attach(BossView.bar, B.w, B.h) -- 닳은 자리가 밝게 남았다 줄어든다 · 번쩍임(사용자 2026-10-13: "몬스터 체력바도  유저 체력바처럼 고도화 되어야합니다.")
	BossView.hpText = Ui.text(box, "", B.pad, B.barY + math.floor((B.h - M.small) / 2), B.w - B.pad * 2, { align = "center", outline = true, z = 6 })
	BossView.pat = Ui.text(box, "", 0, B.patY, B.w, { font = "body", color = PINK, align = "center", outline = true })
	-- 주간 보스의 방(2026-10-24): 이름 줄의 오른쪽 끝에 「노말 · 14:59」(난이도의 색 · 남은 시간). 그 밖의 방에서는 비어 있다
	BossView.week = Ui.text(box, "", 0, Layout.WEEKLY.timeY, B.w, { align = "right", color = C.dim, outline = true })
	-- 데스 카운트(2026-10-27): 같은 줄의 왼쪽 끝에 「데스 카운트 5」(내 것 — 1이 남으면 빨갛게). 그 밖의 방에서는 비어 있다
	BossView.lives = Ui.text(box, "", 0, Layout.WEEKLY.timeY, B.w, { align = "left", color = C.dim, outline = true })
	BossView.shownName, BossView.shownHp, BossView.shownPat = nil, nil, nil
end

-- 주간 보스의 방의 상태(서버의 WeekView · 방에 들어설 때의 room.weekly — sim/weekly.luau의 roomView): 남은 시간을 받은 뒤로 흐르게 한다. nil = 주간의 방이 아니다
function BossView.setWeekly(view)
	BossView.weekly = view
	BossView.weeklyAt = os.clock()
	BossView.shownWeek = nil
	if BossView.week and not view then
		BossView.week:set("")
	end
	BossView.shownLives = nil
	if BossView.lives and not view then
		BossView.lives:set("")
	end
end
-- 내 남은 데스 카운트(주간 보스의 방에서 싸우는 동안만 — 아니면 nil). 쓰러졌을 때의 상자(boot.luau)도 이것을 본다
function BossView.livesLeft(): number?
	local v = BossView.weekly
	if not v or v.state ~= "fight" or not v.livesMax then
		return nil
	end
	local lp = game:GetService("Players").LocalPlayer
	local n = if lp and v.lives then v.lives[tostring(lp.UserId)] else nil
	return if n then n else v.livesMax
end
local function weekText(): string?
	local v = BossView.weekly
	if not v then
		return nil
	end
	local W = require(ReplicatedStorage.shared.lune.sim.weekly).DATA
	local mode = W.modes[v.mode]
	local left = if v.state == "fight" then math.max(0, (v.left or 0) - (os.clock() - (BossView.weeklyAt or os.clock()))) else 0
	return (if mode then mode.name else "") .. " · " .. string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
end

-- 체력 글: "지금 / 최대"(칸에 안 들어가면 짧게 — shared/lune/ui/format.luau의 hp)
function BossView.hpLabel(hp: number, maxHp: number, width: number, measure): string
	return Format.hp(math.max(0, math.ceil(hp)), maxHp, width, measure)
end

-- mobs = 그 장면의 졸개 그림(mobsView) · cast = 기술의 이펙트를 돌리는 것(cast.fx = 이펙트 한 벌 · 화면 흔들기) · effects = 장면의 효과(잔상) · scene = 장면 자료(bosses의 range = 내달리기의 끝)
--  hooks = { push(x, dist) } — 보스가 포효할 때 부른다(x = 보스의 자리 · dist = 밀어내는 거리): 내 캐릭터가 가까이 있으면 밀려난다(boot.luau)
--   · sfx(이름) — 보스의 소리(2026-10-28 — 사용자: "모든 보스가 소리가없어서 심심해"): 치는 순간(패턴의 sfx) · 표시된 자리가 터질 때(spots.sfx) · 포효 · 벽에 부딪침 · 쓰러짐
--     이름은 공방 design/bosses.js의 BOSS_SFX · 소리 파일은 design/music.js의 boss_*
--          music(곡의 이름표 또는 nil) — 보스가 나타나 그 곡으로 바꿀 때 · 쓰러지거나 사라져 맵의 곡으로 돌아갈 때(nil)
-- 보스의 소리 하나(hooks.sfx가 없으면 조용하다 — 시험)
function BossView:sound(k: string?)
	if k and self.hooks.sfx then
		self.hooks.sfx(k)
	end
end

function BossView.new(mobs, cast, effects, scene, hooks)
	local self = setmetatable({ cast = cast, effects = effects, list = {}, hooks = hooks or {}, spots = {} }, BossView)
	-- 이펙트 한 벌: 예고(맞을 자리 · 느낌표)는 기술의 이펙트와 같은 판(cast.fx)에 그리고, 패턴의 이펙트 그림(스프라이트)은 장면의 효과(effects:play)가 튼다
	self.fx = setmetatable({
		sprite = function(who: string, clip: string, x: number, y: number, dir: number, opts)
			if effects and effects.play then
				return effects:play(who, clip, x, y, dir, opts)
			end
			return nil
		end,
	}, { __index = cast.fx })
	self.roomLo, self.roomHi = BossPat.bounds(scene) -- 표시된 자리들이 놓이는 범위(서버와 같다)
	self.shake = function(amount: number, t: number)
		cast.shakeA, cast.shakeT = math.max(cast.shakeA or 0, amount), math.max(cast.shakeT or 0, t)
	end
	-- 방의 양 끝(보스가 선 바닥 바로 위의 줄에서 막힌 칸이 아닌 첫 칸 · 끝 칸): 땅 울림의 물결을 그 밖으로는 그리지 않는다(서버의 판정도 벽에서 멈춘다)
	self.lo, self.hi = 0, scene.w * 16
	local first = (scene.bosses or {})[1]
	if first then
		local row = scene.rows[math.floor((first.y - 1) / 16) + 1]
		local mid = math.floor(first.x / 16)
		local a, b = mid, mid
		while a > 0 and string.sub(row, a, a) ~= "#" do
			a -= 1
		end
		while b < scene.w - 1 and string.sub(row, b + 2, b + 2) ~= "#" do
			b += 1
		end
		self.lo, self.hi = a * 16, (b + 1) * 16
	end
	local range = {}
	for _, b in scene.bosses or {} do
		range[b.kind] = b.range
	end
	for _, m in mobs.mobs do
		if m.def.story then
			local r = range[m.info.kind] or { 0, scene.w * 16 }
			table.insert(self.list, { m = m, state = m.state, pat = m.pat or 0, a = r[1], b = r[2], trail = 0, ghost = 0, x = nil :: number? })
		end
	end
	table.sort(self.list, function(p, q)
		return p.m.info.id < q.m.info.id
	end)
	return self
end

function BossView:update(dt: number)
	local shown, shownPat = nil, ""
	local now = os.clock()
	for _, b in self.list do
		local m = b.m
		local pat = m.pat or 0
		local S = m.def.story
		local p = MobsView.patOf(m) -- 연속기 안에서는 예고 · 굳는 시간이 줄어든 것
		local y = m.info.y
		local top = m.sprite.char.fh -- 그림의 높이(뿔 · 깃발까지) — 느낌표를 그 위에 띄운다
		local who = m.sprite.who -- 패턴의 이펙트 그림은 그 보스의 동작 묶음에 있다
		if m.state == "tell" and p and (b.state ~= "tell" or b.pat ~= pat) then
			-- 예고가 시작됐다: 그 자리에(보스는 예고하는 동안 서 있다 — 연속기는 한 걸음 다가서며) 맞을 자리와 머리 위의 느낌표를 그린다 — 끊기면(묶임) 그리지 않는다
			--  도약 찍기: 내려앉을 자리는 겨눈 사람을 따라오고(m.aim), 날아가는 동안에도 보인다
			b.x = m.toX
			self.fx.add(p.tell + (if p.leap then p.leap.time else 0) + 0.5, function(ctx)
				if m.state == "tell" and m.pat == pat then
					BossFx.tell(ctx, m.x, y, m.dir, p, math.clamp((m.tNow or 0) / p.tell, 0, 1), b.a, b.b, top, m.aim, S.mark)
				elseif p.leap and m.state == "act" and m.pat == pat and (m.tNow or 0) < p.leap.time then
					BossFx.tell(ctx, b.leapX or m.x, y, b.leapDir or m.dir, p, 1, b.a, b.b, nil, m.aim, S.mark)
				end
			end, { back = true })
			if p.spots then
				-- 표시된 자리들(불씨 뿌리기 · 봉화 불기둥): 지금 정해진다 — 예고가 끝나면(자리마다 더 기다린 뒤) 솟는다. 자리는 서버와 같은 식으로 센다
				local fromX, fromY = nil, nil
				if p.spots.aim ~= "grid" and S.mark == nil then -- (제 표시가 있는 보스는 불씨가 날아오지 않는다 — 그림자 사수의 조준경 · 타락한 부단장의 떨어지는 종이)
					fromX, fromY = m.toX - m.dir * 10, y - m.def.body[2] - 16 -- 등의 화로에서 불씨가 날아온다
				end
				for _, sp in BossPat.spots(p, m.aim or m.toX, self.roomLo, self.roomHi, m.toX or m.x, m.dir) do -- (from · dir = 폭탄 깔기의 줄 — 보스의 자리와 보는 쪽)
					local spot = { m = m, who = who, pat = pat, x = sp[1], at = now, T = p.tell + sp[2], def = p.spots, live = true, armed = false }
					table.insert(self.spots, spot)
					self.fx.add(spot.T + 0.1, function(ctx)
						if spot.live then
							BossFx.spot(ctx, spot.x, y, spot.def.r, spot.def.up, (os.clock() - spot.at) / spot.T, fromX, fromY, S.mark, spot.def.aim == "grid")
						end
					end, { back = true })
				end
			end
		elseif (m.state == "act" or m.state == "dash") and p and b.state == "tell" then
			local x = m.toX
			if p.leap then
				-- 도약: 뛰어오른다 — 이펙트와 물결은 내려앉을 때
				BossFx.jump(self.fx, who, p, b.x or x, y)
				b.leapX, b.leapDir, b.leapPat = b.x or x, m.dir, pat
			else
				-- 친다: 그 순간의 이펙트(화면이 흔들린다) · 물결(화면이 조금 늦게 알았으면 그만큼 간 자리에서 시작한다)
				BossFx.strike(self.fx, who, p, x, y, m.dir, self.shake)
				self:sound(p.sfx)
				for _, spot in self.spots do
					if spot.m == m and spot.pat == pat then
						spot.armed = true -- 예고가 끝까지 갔다: 표시된 자리는 이제 보스가 무엇을 하든 제 때에 솟는다
					end
				end
				if p.wave then
					for _, w in BossPat.waves(p, m.dir) do
						BossFx.wave(self.fx, who, x + m.dir * p.wave.at, y, w[1], p.wave, (m.tNow or 0) - w[2], self.lo, self.hi)
					end
				end
			end
			b.trail, b.ghost = 0, 0
			b.dashP = if p.dash then p else nil -- 내달리기가 끝날 때(그때는 패턴이 이미 바뀌어 있다) 그 패턴의 그림으로 터진다
		elseif b.state == "dash" and m.state ~= "dash" and m.state ~= "gone" and m.state ~= "dead" then
			-- 내달리기가 끝났다(벽에 닿았다)
			BossFx.crash(self.fx, who, b.dashP, m.toX, y, m.dir, self.shake)
			self:sound("boss_slam")
		elseif m.state == "roar" and b.state ~= "roar" then
			-- 체력 구간의 포효: 큰 고리와 긴 흔들림 — 가까이 있는 내 캐릭터는 밀려난다
			BossFx.roar(self.fx, who, S, m.toX, y, self.shake)
			self:sound("boss_roar")
			if self.hooks.push and S.phase then
				self.hooks.push(m.toX, S.phase.push)
			end
		end
		if b.leapPat and (m.state ~= "act" or m.pat ~= b.leapPat) then
			b.leapPat = nil -- 뛰어오른 것이 끊겼다(묶임)
		elseif b.leapPat and p and p.leap and (m.tNow or 0) >= p.leap.time then
			-- 도약: 내려앉았다 — 그 자리에서 친다
			b.leapPat = nil
			BossFx.strike(self.fx, who, p, m.toX, y, m.dir, self.shake)
			self:sound(p.sfx)
			if p.wave then
				for _, w in BossPat.waves(p, m.dir) do
					BossFx.wave(self.fx, who, m.toX + m.dir * p.wave.at, y, w[1], p.wave, (m.tNow or 0) - p.leap.time - w[2], self.lo, self.hi)
				end
			end
		end
		if m.state == "dash" then
			b.trail -= dt
			if b.trail <= 0 then
				local dp = if p and p.dash then p else b.dashP
				b.trail = (dp and dp.dash.trail and dp.dash.trail.every) or TRAIL
				BossFx.dashTrail(self.fx, who, dp, m.x, y, m.dir)
			end
			b.ghost -= dt
			if b.ghost <= 0 and self.effects then
				b.ghost = GHOST
				self.effects:ghost(m.def.sprite, "idle", 1, m.x, y, m.dir, PINK) -- 달리는 몸의 잔상(분홍)
			end
		end
		if (b.state ~= m.state or b.pat ~= pat) and BossView.box then
			-- 확인용: 지금 보스가 하는 것을 체력 바의 틀에 적어 둔다(PlayerGui.LuneStage.Holder.Ui.Hud.Boss의 속성 State · Pattern · Chain)
			if m.state ~= "gone" then
				BossView.box:SetAttribute("State", m.state)
				BossView.box:SetAttribute("Pattern", if p then p.id else "")
				BossView.box:SetAttribute("Chain", if S.patterns[m.chain or 0] then S.patterns[m.chain].id else "")
			end
		end
		if m.state == "dead" and b.state ~= "dead" and b.state ~= nil then
			self:sound("boss_down") -- 쓰러졌다
		end
		b.state, b.pat = m.state, pat
		if m.state ~= "gone" and m.state ~= "dead" then
			shown = m
			-- 바 아래의 이름: 포효 = 그 이름 · 연속기 = 연속기의 이름 · 그 밖에는 패턴의 이름
			local chain = S.patterns[m.chain or 0]
			shownPat = if m.state == "roar" and S.phase then S.phase.name elseif p and (m.state == "tell" or m.state == "act" or m.state == "dash") then (if chain then chain.name else p.name) else ""
		end
	end
	-- 표시된 자리들: 때가 되면 솟는다. 예고하던 중에 끊기거나(묶임) 보스가 쓰러지면 사라진다(서버와 같다)
	for i = #self.spots, 1, -1 do
		local spot = self.spots[i]
		local m = spot.m
		local age = now - spot.at
		if m.state == "dead" or m.state == "gone" or (not spot.armed and not (m.state == "tell" and m.pat == spot.pat)) then
			spot.live = false
			table.remove(self.spots, i)
		elseif age >= spot.T then
			spot.live = false
			table.remove(self.spots, i)
			BossFx.blast(self.fx, spot.who, spot.x, m.info.y, spot.def, self.shake)
			self:sound(spot.def.sfx)
		end
	end
	-- 보스의 곡: 보스가 나타나 있는 동안은 그 보스의 곡을(없으면 그 맵의 곡 그대로), 쓰러지거나 사라지면 맵의 곡으로 — 바뀔 때만 알린다(boot.luau가 튼다)
	local track = if shown then shown.def.story.music else nil
	if track ~= self.track then
		self.track = track
		if self.hooks.music then
			self.hooks.music(track)
		end
	end
	local box = BossView.box
	if not box then
		return
	end
	box.Visible = shown ~= nil
	if shown then
		if BossView.shownName ~= shown.info.name then
			BossView.shownName = shown.info.name
			BossView.name:set(shown.info.name)
		end
		if BossView.shownMob ~= shown then
			BossView.shownMob = shown -- 다른 보스 · 다시 나타난 보스: 효과 없이 그대로 놓는다
			BossView.shownHp = nil
			BossView.barFx:reset()
		end
		if BossView.shownHp ~= shown.hp then
			BossView.shownHp = shown.hp
			BossView.barFx:set(math.max(0, shown.hp) / shown.info.maxHp, math.max(0, shown.hp))
			BossView.hpText:set(BossView.hpLabel(shown.hp, shown.info.maxHp, Layout.BOSS.w - Layout.BOSS.pad * 2, Ui.measure))
		end
		if BossView.shownPat ~= shownPat then
			BossView.shownPat = shownPat
			BossView.pat:set(shownPat)
		end
		local wt = weekText()
		if BossView.week and BossView.shownWeek ~= wt then
			BossView.shownWeek = wt
			BossView.week:set(wt or "")
			local v = BossView.weekly
			if v and v.mode == "hard" then
				BossView.week:color(Color3.fromRGB(217, 48, 107)) -- 하드의 색(design/weekboss.js의 modes)
			else
				BossView.week:color(Color3.fromRGB(47, 127, 168))
			end
		end
		local left = BossView.livesLeft()
		if BossView.lives and BossView.shownLives ~= left then
			BossView.shownLives = left
			local W = require(ReplicatedStorage.shared.lune.sim.weekly).DATA
			BossView.lives:set(if left then (string.gsub(W.words.lives, "{n}", tostring(left))) else "")
			BossView.lives:color(if left and left <= 1 then C.red else C.dim)
		end
		BossView.barFx:step(dt)
	else
		BossView.shownMob = nil
	end
end

function BossView:destroy()
	table.clear(self.list)
	for _, spot in self.spots do
		spot.live = false
	end
	table.clear(self.spots)
	if BossView.box then
		BossView.box.Visible = false
	end
	BossView.shownHp, BossView.shownPat = nil, nil
end

return BossView
