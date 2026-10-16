-- 졸개 그리기. 서버가 초당 열 번 보내는 모습(자리 · 보는 쪽 · 상태 · 상태가 된 뒤 흐른 시간 · 체력)을 받아, 그 사이를 이어 그린다.
--  졸개가 무엇을 하는지는 서버가 정한다 — 여기서는 보이는 것만 맞춘다.
--  다친 졸개에게만 머리 위에 체력 띠, 발밑에 이름표(「Lv.1 수습 검병」)가 뜬다 — 다 띄우면 화면이 이름표로 덮인다.
--  체력 띠와 이름표는 글씨의 층(화면 틀의 고운 격자 — overlay.luau)에 그리고, 자리만 졸개를 따라간다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local COMBAT = require(lune.data["combat.generated"])
local RiftData = require(lune.data["city.generated"]).rift -- 토벌의 정예의 겉모습(2026-10-16)
local BossFx = require(lune.bossfx) -- 스토리 보스: 동작 그림이 없을 때 대기 그림을 움직여 대신한다(pose)
local BossPat = require(lune.sim.bosspat) -- 스토리 보스: 연속기의 시간 · 도약의 높이(서버와 같은 셈)
local Sprite = require(script.Parent.sprite)
local Stage = require(script.Parent.stage) -- 불티(한 점짜리 틀)
local Ui = require(script.Parent.ui.ui)
local HpBar = require(script.Parent.ui.hpBar) -- 체력 띠의 효과(닳은 자리가 밝게 남았다 줄어든다 · 번쩍임 — 플레이어의 체력 바와 같은 셈)
local Overlay = require(script.Parent.overlay)
local Layout = require(lune.ui.layout)

local C = Ui.COLOR
local LERP = 0.1 -- 모습이 오는 간격(초) — 이 시간에 걸쳐 앞 자리에서 새 자리로 옮긴다
local BAR_W, BAR_H = Layout.MOBBAR.w, Layout.MOBBAR.h -- 체력 띠의 크기(화면 틀의 점)
local BAR_UP = Layout.MOBBAR.up -- 체력 띠: 발밑에서 이만큼 위(게임의 도트)
local TAG_DOWN = Layout.TAG.down -- 이름표: 발밑에서 이만큼 아래(화면 틀의 점)
-- 새 몬스터(def.bare): 맞음 · 나타남 · 쓰러짐 그림이 없다(사용자 2026-10-09: "death는 필요없어요 hurt 도 필요없습니다. 스폰도 필요없어요" · "박쥐처럼입니다") — 공방 시험 탭과 같게 보인다:
--  맞으면 하얗게 번쩍(FLASH초) · 나타날 때 서서히 보임(FADE초) · 쓰러지면 서서히 사라짐(FADE초)
local FLASH, FADE = 0.12, 0.45

local MobsView = {}
MobsView.__index = MobsView

function MobsView.tagText(lv: number, name: string): string
	return ("Lv.%d %s"):format(lv, name)
end

-- layer = 졸개 그림의 층(게임 세계) · room = 서버가 준 방의 모습 · tagLayer = 이름표와 체력 띠의 층(화면 틀 — overlay)
function MobsView.new(layer: Frame, room, tagLayer: Frame)
	local self = setmetatable({}, MobsView)
	self.layer = layer
	self.mobs = {}
	local top = tagLayer
	for _, info in room.mobs do
		local bar = Ui.bar(top, 0, 0, BAR_W, BAR_H, C.hp)
		bar.frame.Name = "HpBar"
		bar.frame.ZIndex = 5
		bar.frame.Visible = false
		-- 토벌의 정예(2026-10-16): 같은 그림에 정예 병사와 같은 분홍 윤곽의 빛 · 불티(Rift.DATA.elite.look) · 이름표에 「정예」
		local def = COMBAT.mobs[info.kind]
		if info.elite then
			def = setmetatable({ look = RiftData.elite.look }, { __index = def })
		end
		local name = info.name or COMBAT.mobs[info.kind].name
		local tag = Ui.tag(top, MobsView.tagText(info.lv or 1, if info.elite then RiftData.elite.name .. " " .. name else name), C.text, 260)
		tag.Frame.Visible = false
		self.mobs[info.id] = {
			info = info,
			def = def,
			sprite = Sprite.new(layer, COMBAT.mobs[info.kind].sprite, 2), -- 그림을 빌려 쓰는 졸개가 있다(수습 검병 = 검병의 그림)
			white = Sprite.new(layer, COMBAT.mobs[info.kind].sprite, 3, true), -- 맞을 때의 흰 번쩍임(같은 자리의 흰 실루엣) — 모든 몬스터(시험 탭의 flashT. 전에는 제 맞는 그림이 없는 몬스터만 번쩍였다)
			-- 터뜨리는 몬스터(폭탄병 · 포자 주머니): 터지는 그림에는 몸이 없다 — 터진 뒤의 장들에는 서 있는 몸을 밑에 그린다(터뜨려도 사라지지 않는다)
			under = if COMBAT.mobs[info.kind].atk and COMBAT.mobs[info.kind].atk.burst then Sprite.new(layer, COMBAT.mobs[info.kind].sprite, 1) else nil,
			-- 그림을 빌려 쓰는 몬스터(정예 검병 = 검병의 그림)를 가르는 겉모습(공방 combat.js의 look — 사용자 2026-10-11): 윤곽의 빛 = 흰 실루엣 넷을 한 점씩 비껴 몸 뒤에 · 불티 = 작은 점 셋
			glow = MobsView.glowOf(layer, def),
			embers = MobsView.embersOf(layer, def),
			warn = MobsView.warnOf(layer, COMBAT.mobs[info.kind]), -- 스토리 보스: 예고하는 동안 깜박이는 분홍 윤곽
			pat = 0, -- 스토리 보스가 지금 하는 패턴의 차례(서버가 보낸다 — 없으면 0)
			alt = 0, -- 지금 땅에서 뜬 높이(나는 몬스터)
			bar = bar,
			barFx = HpBar.attach(bar, BAR_W, BAR_H), -- 사용자 2026-10-13: "몬스터 체력바도  유저 체력바처럼 고도화 되어야합니다."
			fresh = false, -- 띠를 처음으로 돌려 두었는가(다시 나타날 때 한 번)
			tag = tag,
			x = 0,
			fromX = 0,
			toX = 0,
			at = 0,
			dir = 1,
			state = "gone",
			t = 0,
			hp = info.maxHp,
			shownHp = -1,
		}
	end
	if room.snap then
		self:apply(room.snap, 0)
		for _, m in self.mobs do
			m.fromX = m.toX
		end
	end
	return self
end

-- ---------- 그림을 빌려 쓰는 몬스터의 겉모습(look) ----------
local GLOW_AT = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } -- 윤곽의 빛: 한 점씩 비낀 네 자리
local EMBER_X = { -9, -4, 1, 6, 10 } -- 불티 다섯이 피어오르는 자리(몸의 가운데에서 옆으로)
local EMBER_BIG = 0.45 -- 피어오르는 길의 이만큼까지는 두 점, 그 뒤로는 한 점(한 점짜리 셋은 화면에서 보이지 않았다 — 2026-10-11 Play)
local function rgbOf(c): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
-- 윤곽의 빛(흰 실루엣 넷) — look.aura가 있을 때만
function MobsView.glowOf(layer: Instance, def)
	if not (def.look and def.look.aura) then
		return nil
	end
	local list = {}
	for i = 1, #GLOW_AT do
		local sp = Sprite.new(layer, def.sprite, 1, true)
		sp.label.ImageColor3 = rgbOf(def.look.aura)
		list[i] = sp
	end
	return list
end
-- 스토리 보스의 예고 윤곽(분홍 실루엣 넷 — 예고하는 동안만 보인다. 끝으로 갈수록 빨리 깜박인다): 공방 시험 탭의 drawStory와 같다
local WARN = Color3.fromRGB(255, 62, 159)
function MobsView.warnOf(layer: Instance, def)
	if not def.story then
		return nil
	end
	local list = {}
	for i = 1, #GLOW_AT do
		local sp = Sprite.new(layer, def.sprite, 1, true)
		sp.label.ImageColor3 = WARN
		list[i] = sp
	end
	return list
end
-- 불티(다섯) — look.embers가 있을 때만
function MobsView.embersOf(layer: Instance, def)
	if not (def.look and def.look.embers) then
		return nil
	end
	local list = {}
	for i = 1, #EMBER_X do
		local e = Stage.image(layer, "Ember", "", 1, 1)
		e.BackgroundColor3 = rgbOf(def.look.embers)
		e.BackgroundTransparency = 0
		e.ZIndex = 4
		e.Visible = false
		list[i] = e
	end
	return list
end
-- 그 장의 겉모습을 그린다: 몸의 그림에 색을 곱하고(눈 · 뿔 · 날이 그 색이 된다), 윤곽의 빛은 숨 쉬듯 밝아졌다 어두워지고, 불티는 1.3초에 걸쳐 스무 점 떠오르며 사라진다
function MobsView.drawLook(m, show: boolean, clip: string, frame: number, now: number)
	local look = m.def.look
	if not look then
		return
	end
	if look.tint and not m.tinted then
		m.tinted = true
		m.sprite.label.ImageColor3 = rgbOf(look.tint)
	end
	local y = m.info.y - m.alt
	if m.glow then
		local fade = 0.45 + 0.25 * math.sin(now * 4 + m.info.id)
		for i, sp in m.glow do
			if show then
				sp:set(clip, frame, (m.px or m.x) + GLOW_AT[i][1], y + GLOW_AT[i][2], m.dir)
				sp.label.ImageTransparency = fade
			else
				sp.label.Visible = false
			end
		end
	end
	if m.embers then
		for i, e in m.embers do
			local k = (now / 1.3 + i / #m.embers + m.info.id * 0.37) % 1
			e.Visible = show
			if show then
				local size = if k < EMBER_BIG then 2 else 1
				e.Size = UDim2.fromOffset(size, size)
				e.Position = UDim2.fromOffset(math.floor(m.x + EMBER_X[i] + math.sin(k * 6.28 + i) * 1.5), math.floor(y - 4 - k * 20))
				e.BackgroundTransparency = k
			end
		end
	end
end

-- 맞았다(타격감 — 공방 combat.js의 hit): 하얗게 번쩍이고, 때린 쪽의 반대(dir)로 조금 밀렸다가 돌아온다(그림만 — 자리와 판정은 서버의 것 그대로). now = 화면의 시계
local HIT = COMBAT.rules.hit
function MobsView.hit(m, now: number, dir: number)
	m.hitAt, m.pushDir = now, dir
end

-- 서버가 보낸 모습을 받아 적는다. now = 받은 때(클라이언트 시계)
function MobsView:apply(list, now: number)
	for _, row in list do
		local m = self.mobs[row[1]]
		if m then
			m.fromX = if m.state == "gone" then row[2] else m.x
			m.toX, m.dir, m.at = row[2], row[3], now
			m.state, m.t, m.hp = row[4], row[5], row[6]
			m.pat = row[9] or 0
			m.aim, m.chain, m.quick = row[10] or 0, row[11] or 0, row[12] == 1 -- 스토리 보스: 겨눈 자리(도약 · 불씨) · 연속기의 차례(0이면 아니다) · 지금 패턴이 연속기의 빠른 것인가
			-- 묶인 · 넘어진 시간(서버의 것). 화면이 방금 어림으로 묶은 직후(cast.luau의 g.bind)에는 그보다 먼저 떠난 0을 받지 않는다
			if (row[7] or 0) > 0 or os.clock() - (m.bindAt or -9) > 0.6 then
				m.bind = row[7] or 0
			end
			m.stun = row[8] or 0
		end
	end
end

function MobsView:get(id: number)
	return self.mobs[id]
end

-- 스토리 보스가 지금 하는 패턴: 연속기(chain)의 둘째부터는 예고 · 굳는 시간이 그 quick배로 줄어든 것을 돌려준다(화면의 그림 · 동작의 박자가 서버의 시간과 맞게). 없으면 nil
local QUICK = {} :: { [any]: { [number]: any } }
function MobsView.patOf(m)
	local S = m.def.story
	local p = S.patterns[m.pat or 0]
	local c = S.patterns[m.chain or 0]
	if not p or not m.quick or not c or not c.quick or c.quick == 1 then
		return p
	end
	local cache = QUICK[p]
	if not cache then
		cache = {}
		QUICK[p] = cache
	end
	local q = cache[c.quick]
	if not q then
		q = table.clone(p)
		q.tell, q.act = BossPat.tell(p, c.quick), BossPat.act(p, c.quick)
		cache[c.quick] = q
	end
	return q
end

-- 그 졸개의 머리 위 높이(발밑에서 위로, 게임의 도트): 병사 16 · 새 몬스터 = 뜬 높이 + 몸의 높이 + 2. 피해 숫자가 뜨는 자리
function MobsView.topOf(m): number
	local def = m.def
	if def.body then
		return (def.lift or 0) + (m.alt or 0) + def.body[2] + 2
	end
	return if def.boss then 30 else 16
end

-- 나는 몬스터의 지금 높이: 서버(sim/room.luau)와 같은 식 — 덮칠 때는 내려왔다 올라가고, 그 밖에는 제 높이에서 조금씩 오르내린다(오르내림은 보이기만 한다)
local function altOf(m, t: number, now: number): number
	local fly = m.def.fly
	if not fly then
		return 0
	end
	if m.state == "atk" then
		local atk = m.def.atk
		local k = if t < atk.windup then t / atk.windup else math.max(0, 1 - (t - atk.windup) / (atk.time - atk.windup))
		return fly.alt - (fly.alt - fly.low) * (k * k * (3 - 2 * k))
	end
	return fly.alt + math.sin(now * 3 + m.info.id) * fly.bob
end

function MobsView:update(now: number)
	local dt = math.clamp(now - (self.now or now), 0, 0.1)
	self.now = now
	for _, m in self.mobs do
		local k = math.clamp((now - m.at) / LERP, 0, 1)
		m.x = m.fromX + (m.toX - m.fromX) * k
		local t = m.t + (now - m.at)
		local char = m.sprite.char
		local clip, frame = "idle", 1
		local show = true
		local bare = m.def.bare == true
		local fade, flash = 0, false -- 그림 없는 동작: 투명한 정도(0 = 또렷) · 흰 번쩍임
		local poseX, poseY = 0, 0 -- 스토리 보스: 대기 그림을 움직이는 만큼(앞으로 · 위로)
		m.tNow = t -- 지금 상태가 된 뒤 흐른 시간(보스의 예고가 얼마나 찼는가 — bossView가 읽는다)
		m.alt = altOf(m, t, now)
		if m.state == "gone" then
			show = false
		elseif m.state == "dead" and m.def.story and char.clips.death and m.def.story.anim.fall then
			-- 스토리 보스가 쓰러진다(쓰러지는 동작 그림이 있는 보스): 그 동작을 한 번 틀고 누운 채 잠깐 있다가 사라진다(BossFx.fall) — 그동안 서버는 보스를 치우지 않는다(story.fall초)
			local c, f, a = BossFx.fall(t, char.clips, m.def.story.anim)
			clip, frame = c :: string, f
			fade = 1 - a
			show = a > 0
			m.tail = nil
		elseif bare and m.state == "dead" then
			frame = Sprite.frameAt(char, "idle", now + m.info.id * 0.3, false)
			fade = math.clamp(t / FADE, 0, 1)
			show = fade < 1
		elseif bare and m.state == "spawn" then
			frame = Sprite.frameAt(char, "idle", now + m.info.id * 0.3, false)
			fade = 1 - math.clamp(t / FADE, 0, 1)
		elseif m.def.story then
			-- 스토리 보스: 받은 동작 그림(idle · run · attack — 사용자가 만든다)을 패턴의 시간에 맞춰 튼다(BossFx.body). 그림이 없는 동작(sweep · shout)은 대기 그림을 움직여 대신한다
			local S = m.def.story
			local p = MobsView.patOf(m) -- 지금 하는 패턴(연속기 안에서는 예고 · 굳는 시간이 줄어든 것)
			m.jump = if p and m.state == "act" then BossPat.leapAlt(p, t) else 0 -- 도약: 뛰어오른 높이(서버와 같은 식)
			-- 친 뒤에 남은 장: 굳어 있는 동안(act)의 동작을 적어 두었다가, 그 뒤 서 있는 동안 이어서 끝까지 튼다(걷거나 다음 패턴을 예고하면 그만둔다)
			if m.state == "act" and p and not p.dash then
				m.tail = { clip = p.clip, act = p.act, t = t }
			elseif m.state == "idle" and m.tail then
				m.tail.t = m.tail.act + t
			else
				m.tail = nil
			end
			local stand
			clip, frame, stand = BossFx.body(m.state, p, t, now, char.clips, S.anim, m.tail)
			if stand then
				poseX, poseY = BossFx.pose(m.state, p, t)
			end
		elseif bare and m.state == "hit" then
			frame = Sprite.frameAt(char, "idle", now + m.info.id * 0.3, false)
			flash = t < FLASH
		elseif m.state == "dead" then
			clip = "death"
			frame = math.min(#char.clips.death.frames, math.floor(t * char.clips.death.fps) + 1)
		elseif m.state == "spawn" then
			clip = "spawn"
			frame = math.min(#char.clips.spawn.frames, math.floor(t * char.clips.spawn.fps) + 1)
		elseif m.state == "atk" then
			clip = "atk"
			frame = math.min(#char.clips.atk.frames, math.floor(t * m.def.atk.fps) + 1)
		elseif m.state == "hit" then
			clip = "hit"
			frame = math.min(#char.clips.hit.frames, math.floor(t * char.clips.hit.fps) + 1)
		elseif m.state == "run" then
			clip = "run"
			frame = Sprite.frameAt(char, "run", now, false)
		else
			frame = Sprite.frameAt(char, "idle", now + m.info.id * 0.3, false)
		end
		-- 타격감: 방금 맞았으면 하얗게 번쩍이고(HIT.flash초), 때린 쪽의 반대로 밀렸다가 돌아온다(HIT.pushT초 — 처음에 크게, 끝으로 갈수록 작게). 그리는 자리(px)만 옮긴다
		local hitAge = now - (m.hitAt or -9)
		if hitAge >= 0 and hitAge < HIT.flash and m.state ~= "gone" and m.state ~= "spawn" then
			flash = true
		end
		local px = m.x
		if hitAge >= 0 and hitAge < HIT.pushT and m.state ~= "gone" then
			local k = 1 - hitAge / HIT.pushT
			px += math.floor((m.pushDir or 0) * (if m.def.boss or m.info.boss then HIT.pushBoss else HIT.push) * k * k + 0.5)
		end
		px += m.dir * poseX
		local py = m.info.y - m.alt - poseY - math.floor((m.jump or 0) + 0.5)
		m.px = px
		if m.under then
			-- 터진 장부터(atk.frame 다음)는 서 있는 몸을 밑에 그린다
			if show and m.state == "atk" and clip == "atk" and frame > m.def.atk.frame then
				m.under:set("idle", 1, px, m.info.y - m.alt, m.dir)
			else
				m.under.label.Visible = false
			end
		end
		MobsView.drawLook(m, show and m.state ~= "dead" and m.state ~= "spawn", clip, frame, now)
		if show then
			m.sprite:set(clip, frame, px, py, m.dir)
			if bare then
				m.sprite.label.ImageTransparency = fade
			end
		else
			m.sprite.label.Visible = false
		end
		if m.white then
			if show and flash then
				m.white:set(clip, frame, px, py, m.dir)
			else
				m.white.label.Visible = false
			end
		end
		if m.warn then
			local p = m.def.story.patterns[m.pat]
			local on = show and m.state == "tell" and p ~= nil
			local see = if on then 1 - (0.35 + 0.45 * math.abs(math.sin(t * (6 + 14 * t / p.tell)))) else 1
			for i, sp in m.warn do
				if on then
					sp:set(clip, frame, px + GLOW_AT[i][1], py + GLOW_AT[i][2], m.dir)
					sp.label.ImageTransparency = see
				else
					sp.label.Visible = false
				end
			end
		end
		-- 체력 띠와 이름표: 다친 졸개에게만
		local alive = m.state ~= "gone" and m.state ~= "dead" and m.state ~= "spawn"
		m.hurt = alive and m.hp < m.info.maxHp and not m.def.story -- 스토리 보스의 체력은 화면 위 가운데의 넓은 바에 뜬다(bossView.luau) — 머리 위의 띠 · 발밑의 이름표는 없다
		-- 띠의 효과: 맞으면 닳은 자리가 밝게 남았다가 따라 줄어들고 띠가 희게 번쩍인다(플레이어의 체력 바와 같다).
		--  없는 동안 · 나타나는 동안에는 처음으로 돌려 둔다(가득 찬 채로 — 다시 나타났을 때 「차오르는」 효과가 뜨지 않게, 첫 타에도 닳은 자리가 보이게)
		if m.state == "gone" or m.state == "spawn" then
			if not m.fresh then
				m.fresh = true
				m.barFx:reset()
				m.barFx:set(1, m.info.maxHp)
				m.shownHp = m.info.maxHp
			end
		else
			m.fresh = false
			if m.shownHp ~= m.hp then
				if m.shownHp == -1 then
					m.barFx:reset() -- 처음 본 몬스터(이미 다쳐 있을 수 있다): 효과 없이 그대로
				end
				m.shownHp = m.hp
				m.barFx:set(math.max(0, m.hp) / m.info.maxHp, math.max(0, m.hp))
			end
			m.barFx:step(dt)
		end
		-- 쓰러뜨린 마지막 타: 띠가 비워지는 것이 보이게, 효과가 끝날 때까지는 띠를 남겨 둔다(쓰러지는 동안)
		local last = m.state == "dead" and not m.def.story and m.barFx:busy()
		m.bar.frame.Visible = m.hurt or last
		m.tag.Frame.Visible = m.hurt -- 자리는 boot가 정한다(이름표끼리 겹치지 않게 쌓는다 — tags())
		if m.hurt or last then
			m.bar.frame.Position = UDim2.fromOffset(Overlay.x(m.x) - BAR_W / 2, Overlay.y(m.info.y - math.max(BAR_UP, MobsView.topOf(m) + 7))) -- 큰 몬스터 · 떠 있는 몬스터는 머리 위로 올린다
		end
	end
end

-- 떠 있는 이름표들: { x(왼쪽), y(위), w, frame } — 화면 틀의 점. 번호 차례(늘 같은 차례로 쌓이게)
function MobsView:tags()
	local out = {}
	for id, m in self.mobs do
		if m.hurt then
			table.insert(out, { id = id, x = Overlay.x(m.x) - math.floor(m.tag.Width / 2), y = Overlay.y(m.info.y) + TAG_DOWN, w = m.tag.Width, frame = m.tag.Frame })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function MobsView:destroy()
	for _, m in self.mobs do
		m.sprite:destroy()
		if m.white then
			m.white:destroy()
		end
		for _, sp in m.warn or {} do
			sp:destroy()
		end
		m.bar.frame:Destroy()
		m.tag:Destroy()
	end
	table.clear(self.mobs)
end

return MobsView
