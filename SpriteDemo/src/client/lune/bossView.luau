-- 스토리 보스의 화면 — 예고(바닥에 칠해지는 맞을 자리 · 머리 위의 느낌표) · 치는 순간의 이펙트와 화면 흔들림 · 땅 울림의 물결 · 내달리기의 잔상과 속도선 ·
--  화면 위 가운데의 체력 바(이름 · 숫자 · 지금 쓰는 패턴의 이름).
--  보스가 무엇을 하는지는 서버가 정한다(sim/room.luau의 stepBoss) — 여기서는 서버가 보내는 모습(상태 · 패턴의 차례 · 흐른 시간: mobsView가 받아 적는다)이
--  바뀌는 때를 보고 그림을 띄운다. 그리는 것은 shared/lune/bossfx.luau(공방 시험 탭의 bossfx.js를 옮긴 것), 자료는 COMBAT.mobs[보스].story(공방 design/bosses.js의 STORYBOSS).
--  몸의 그림(대기 그림을 움직여 대신하는 것 · 예고 때의 분홍 윤곽)은 mobsView.luau가 그린다.
--  사용자 2026-10-11(해 보고): "뭐 보스 패턴도 없고 이펙트도없고 체력 몇인지도 숫자로안보이고 …" → 체력 바 안에 숫자(지금/최대)를 적고, 패턴을 쓸 때 그 이름을 바 아래에 띄우고, 예고와 이펙트를 크게 했다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local BossFx = require(lune.bossfx)
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local M = Ui.M
local TRAIL = 0.05 -- 내달리는 동안 속도선을 내는 간격(초)
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
	BossView.hpText = Ui.text(box, "", B.pad, B.barY + math.floor((B.h - M.small) / 2), B.w - B.pad * 2, { align = "center", outline = true, z = 6 })
	BossView.pat = Ui.text(box, "", 0, B.patY, B.w, { font = "body", color = PINK, align = "center", outline = true })
	BossView.shownName, BossView.shownHp, BossView.shownPat = nil, nil, nil
end

-- 체력 글: "지금 / 최대"(칸에 안 들어가면 짧게 — shared/lune/ui/format.luau의 hp)
function BossView.hpLabel(hp: number, maxHp: number, width: number, measure): string
	return Format.hp(math.max(0, math.ceil(hp)), maxHp, width, measure)
end

-- mobs = 그 장면의 졸개 그림(mobsView) · cast = 기술의 이펙트를 돌리는 것(cast.fx = 이펙트 한 벌 · 화면 흔들기) · effects = 장면의 효과(잔상) · scene = 장면 자료(bosses의 range = 내달리기의 끝)
function BossView.new(mobs, cast, effects, scene)
	local self = setmetatable({ cast = cast, fx = cast.fx, effects = effects, list = {} }, BossView)
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
	for _, b in self.list do
		local m = b.m
		local pat = m.pat or 0
		local p = m.def.story.patterns[pat]
		local y = m.info.y
		local top = m.sprite.char.fh -- 그림의 높이(뿔 · 깃발까지) — 느낌표를 그 위에 띄운다
		if m.state == "tell" and p and (b.state ~= "tell" or b.pat ~= pat) then
			-- 예고가 시작됐다: 그 자리에(보스는 예고하는 동안 서 있다) 맞을 자리와 머리 위의 느낌표를 그린다 — 끊기면(묶임) 그리지 않는다
			local x, dir = m.toX, m.dir
			b.x = x
			self.fx.add(p.tell + 0.5, function(ctx)
				if m.state == "tell" and m.pat == pat then
					BossFx.tell(ctx, x, y, dir, p, math.clamp((m.tNow or 0) / p.tell, 0, 1), b.a, b.b, top)
				end
			end, { back = true })
		elseif (m.state == "act" or m.state == "dash") and p and b.state == "tell" then
			-- 친다: 그 순간의 이펙트(화면이 흔들린다) · 땅 울림의 물결 둘(화면이 조금 늦게 알았으면 그만큼 간 자리에서 시작한다)
			local x = b.x or m.toX
			BossFx.strike(self.fx, p, x, y, m.dir, self.shake)
			if p.wave then
				for _, d in { -1, 1 } do
					BossFx.wave(self.fx, x + m.dir * p.wave.at, y, d, p.wave, m.tNow or 0, self.lo, self.hi)
				end
			end
			b.trail, b.ghost = 0, 0
		elseif b.state == "dash" and m.state ~= "dash" and m.state ~= "gone" and m.state ~= "dead" then
			-- 내달리기가 끝났다(벽에 닿았다)
			BossFx.crash(self.fx, m.toX, y, m.dir, self.shake)
		end
		if m.state == "dash" then
			b.trail -= dt
			if b.trail <= 0 then
				b.trail = TRAIL
				BossFx.dashTrail(self.fx, m.x, y, m.dir)
			end
			b.ghost -= dt
			if b.ghost <= 0 and self.effects then
				b.ghost = GHOST
				self.effects:ghost(m.def.sprite, "idle", 1, m.x, y, m.dir, PINK) -- 달리는 몸의 잔상(분홍)
			end
		end
		if (b.state ~= m.state or b.pat ~= pat) and BossView.box then
			-- 확인용: 지금 보스가 하는 것을 체력 바의 틀에 적어 둔다(PlayerGui.LuneStage.Holder.Ui.Hud.Boss의 속성 State · Pattern)
			if m.state ~= "gone" then
				BossView.box:SetAttribute("State", m.state)
				BossView.box:SetAttribute("Pattern", if p then p.id else "")
			end
		end
		b.state, b.pat = m.state, pat
		if m.state ~= "gone" and m.state ~= "dead" then
			shown = m
			shownPat = if p and (m.state == "tell" or m.state == "act" or m.state == "dash") then p.name else ""
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
		if BossView.shownHp ~= shown.hp then
			BossView.shownHp = shown.hp
			BossView.bar:set(shown.hp / shown.info.maxHp)
			BossView.hpText:set(BossView.hpLabel(shown.hp, shown.info.maxHp, Layout.BOSS.w - Layout.BOSS.pad * 2, Ui.measure))
		end
		if BossView.shownPat ~= shownPat then
			BossView.shownPat = shownPat
			BossView.pat:set(shownPat)
		end
	end
end

function BossView:destroy()
	table.clear(self.list)
	if BossView.box then
		BossView.box.Visible = false
	end
	BossView.shownHp, BossView.shownPat = nil, nil
end

return BossView
