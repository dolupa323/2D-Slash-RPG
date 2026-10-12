-- 잠깐 떴다 사라지는 것들 — 피해 숫자 · 얻은 것 알림 · 화살 · 떨어진 물건 · 대쉬의 잔상과 속도선. 모두 맵 좌표(도트)에 놓여 카메라와 함께 움직인다.
--  대쉬의 잔상 · 속도선은 공방 「횡스크롤 시험」 탭의 것 그대로다(값은 data/combat.generated.luau의 fx — dino-workshop/js/lune/fx.js의 DASHFX).
--   사용자 2026-10-07: "대쉬 이펙트가 바뀐거같은데" — 게임에는 이 효과가 없었다. 시험 탭과 같게 넣었다.
--  피해 숫자 · 화살 · 떨어진 것은 게임 세계의 그림(굵은 도트)이고, 알림 글(「+12」 · 「레벨 업!」)은 글씨의 층(화면 틀의 고운 격자 — overlay.luau)에 테두리 두른 작은 글씨로 뜬다.
--  피해 숫자는 공방 「횡스크롤 시험」 탭과 똑같이 뜬다(ui/kit.luau의 dmg — 3x5 점 숫자 · 0.7초 · 16도트 떠오름), 그 밖의 글은 작은 글씨(갈무리9)로 그린다.
--  떨어진 달돈 · 달가루는 작은 그림(8x8), 장비는 그 장비의 아이콘 그대로 떨어진다.
--  1차의 사출기 · 장치(shared/lune/sim/kit.luau)가 보이는 것도 여기서 그린다 — 작은 네모 몇 개로 찍은 점 그림(직업 색)이다:
--   따로 나가는 타(proc): 달빛 도끼가 머리 위에서 떨어진다 · 표창 · 도깨비불 · 수정 조각 · 불티가 날아간다 · 달아오름의 불꽃이 솟는다 · 수정이 번쩍인다
--   달 수정(무니) · 졸개 머리 위의 표식(리븐) · 몸 둘레를 도는 영혼(리퍼) · 머리 위의 힘 모으기 단계(액시온)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local COMBAT = require(ReplicatedStorage.shared.lune.data["combat.generated"])
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)
local Sprite = require(script.Parent.sprite)
local Kit = require(script.Parent.ui.kit)
local Ui = require(script.Parent.ui.ui)
local Overlay = require(script.Parent.overlay)
local ItemCell = require(script.Parent.ui.itemCell)

local C = Kit.COLOR -- 피해 숫자의 색
local U = Ui.COLOR -- 글의 색

local Effects = {}
Effects.__index = Effects
Effects.WHITE, Effects.MINT, Effects.PINK, Effects.GOLD = U.text, U.accent, U.pink, U.gold
-- 피해 숫자의 색(시험 탭 그대로): 보통 = 흰색 · 센 타격 = 때린 사람 직업의 밝은 색(민트 · 분홍) · 사라지기 직전 = 흐린 청회색.
--  내가 받은 피해만 붉게 한다(시험 탭에는 없는 것 — 시험 탭의 캐릭터는 맞지 않는다)
Effects.DEAL, Effects.HURT, Effects.FADE = C.dmg, U.red, C.dmgFade
Effects.BIG = { mint = C.dmgBig, pink = C.dmgBigPink }
local NUM_LIFE, NUM_RISE, NUM_JITTER, NUM_POP, NUM_POP_T, NUM_FADE = 0.7, 16, 4, 2, 0.15, 0.8 -- dino-workshop/js/lune/fx.js의 num과 같은 값
local GHOST, STREAK = COMBAT.fx.dash.ghost, COMBAT.fx.dash.streak
-- 직업 색(mint · pink): n = 직업 색 · l = 밝은 색
Effects.TONE = {}
for name, t in COMBAT.fx.tones do
	Effects.TONE[name] = { n = Color3.fromRGB(t.n[1], t.n[2], t.n[3]), l = Color3.fromRGB(t.l[1], t.l[2], t.l[3]) }
end

-- layer = 게임 세계의 맨 위 층 · textLayer = 글씨의 층(화면 틀 — overlay) · heroLayer = 캐릭터들의 층(잔상은 캐릭터 뒤에 깔린다)
function Effects.new(layer: Frame, textLayer: Frame, heroLayer: Frame?)
	local self = setmetatable({}, Effects)
	self.layer = layer
	self.textLayer = textLayer
	self.heroLayer = heroLayer or layer
	self.ghosts = {} -- 잔상
	self.lines = {} -- 속도선
	self.floats = {} -- 떠오르는 글씨 · 숫자
	self.shots = {} -- [번호] = 화살
	self.drops = {} -- [번호] = 떨어진 것
	self.sprites = {} -- 잠깐 틀고 사라지는 그림(기술의 광선 등)
	self.puffs = {} -- 2단 점프의 흩어지는 점
	return self
end

-- 같은 자리에 겹치지 않게 조금씩 어긋나게 올린다(h = 게임의 도트)
function Effects:_push(item, h: number)
	for _, other in self.floats do
		if math.abs(other.x - item.x) < 60 and other.t < 0.25 then
			item.y -= h
		end
	end
	table.insert(self.floats, item)
end

-- (x, y) 위로 떠오르는 글씨
function Effects:float(text: string, x: number, y: number, color: Color3, life: number?)
	local label = pixelText.new(self.textLayer, { Text = text, Font = "small_o", Color = color, Align = "center" })
	label.Frame.ZIndex = 10
	self:_push({ frame = label.Frame, text = true, width = label.Width, x = x, y = y, t = 0, life = life or 0.7 }, 6)
end

-- 피해 숫자. (x, y) = 숫자들의 가운데 · 윗줄이 처음 뜨는 자리. big = 센 타격(처음 잠깐 두 점 더 높이 뜬다)
--  시험 탭처럼 좌우로 조금씩 흩어져 뜬다(겹쳐도 밀어 올리지 않는다).
function Effects:number(value: number, x: number, y: number, color: Color3, big: boolean?)
	local num = Kit.dmg(self.layer, tostring(math.max(0, math.floor(value + 0.5))), color)
	num.frame.ZIndex = 11
	table.insert(self.floats, {
		frame = num.frame,
		num = num,
		big = big == true,
		faded = false,
		width = num.width - 2, -- 테두리를 뺀 숫자의 폭(가운데를 맞출 때 쓴다)
		x = x + (math.random() - 0.5) * NUM_JITTER * 2,
		y = y,
		t = 0,
		life = NUM_LIFE,
	})
end

-- 캐릭터 판의 동작 하나를 (x, y)에 한 번 튼다(화염 광선처럼 기술에 딸린 그림)
function Effects:addSprite(who: string, clip: string, x: number, y: number, dir: number, life: number, fps: number)
	local sprite = Sprite.new(self.layer, who, 6)
	table.insert(self.sprites, { sprite = sprite, clip = clip, x = x, y = y, dir = dir, t = 0, life = life, fps = fps })
end

-- 캐릭터 판의 동작 하나를 그 동작의 빠르기로 튼다(보스 패턴의 이펙트 그림 — shared/lune/bossfx.luau). 공방 시험 탭의 fx.sprite와 같은 셈
--  opts: delay 늦게(음수면 그만큼 이미 흐른 데서) · back 몸들의 뒤(캐릭터들의 층 맨 아래) · loop 돌려 트는 시간(초 — 없으면 한 번 튼다) · vx 가는 빠르기(점/초)
--        lo · hi 그 밖에서는 보이지 않는다(방의 벽) · fade 끝에서 사라지는 몫(0~1)
function Effects:play(who: string, clip: string, x: number, y: number, dir: number, opts)
	opts = opts or {}
	local sprite = Sprite.new(if opts.back then self.heroLayer else self.layer, who, if opts.back then 0 else 6)
	local c = sprite.char.clips[clip]
	if not c then
		sprite:destroy() -- 그 그림이 없다(아직 싣지 않은 이펙트)
		return
	end
	sprite.label.Name = "BossFx"
	table.insert(self.sprites, {
		sprite = sprite,
		clip = clip,
		x = x,
		y = y,
		dir = dir,
		t = -(opts.delay or 0),
		life = opts.loop or (#c.frames / c.fps),
		fps = c.fps,
		loop = opts.loop ~= nil,
		vx = opts.vx or 0,
		lo = opts.lo,
		hi = opts.hi,
		fade = opts.fade or 0,
	})
end

-- 잔상: 그 캐릭터의 그 장을 한 색 실루엣으로 남긴다. 처음의 불투명도에서 곧게 옅어져 사라진다(시험 탭의 ghost)
function Effects:ghost(who: string, clip: string, frame: number, x: number, y: number, dir: number, color: Color3)
	local sprite = Sprite.new(self.heroLayer, who, 0, true)
	sprite.label.Name = "Ghost"
	sprite.label.ImageColor3 = color
	sprite.label.ImageTransparency = 1 - GHOST.alpha
	sprite:set(clip, frame, x, y, dir)
	table.insert(self.ghosts, { sprite = sprite, t = 0 })
end

-- 대쉬를 하는 동안 every초마다 잔상을 남긴다. o = 그 사람의 상태(o.ghostT에 시간을 쌓는다). 남겼으면 true
function Effects:trail(o, dt: number, who: string, clip: string, frame: number, x: number, y: number, dir: number, tone: string): boolean
	o.ghostT = (o.ghostT or 0) + dt
	if o.ghostT <= GHOST.every then
		return false
	end
	o.ghostT = 0
	self:ghost(who, clip, frame, x, y, dir, Effects.TONE[tone].n)
	return true
end

-- 속도선: 대쉬를 시작할 때 한 번. (x, y) = 발밑 · speed = 대쉬의 속도(점/초 — 빠를수록 줄이 많고 길다) · tone = 직업 색의 이름(시험 탭의 streaks)
function Effects:streaks(x: number, y: number, speed: number, dir: number, tone: string)
	local n = math.floor(STREAK.base + speed / STREAK.perSpeed + 0.5)
	local len = STREAK.len + speed / STREAK.lenPerSpeed
	for _ = 1, n do
		local frame = Kit.box(self.layer, 0, 0, 1, 1, Effects.TONE[tone].l)
		frame.Name = "Streak"
		frame.ZIndex = 5
		frame.Visible = false
		table.insert(self.lines, {
			frame = frame,
			x = x + (math.random() - 0.5) * STREAK.w,
			y = y - STREAK.up - math.random() * STREAK.h,
			len = len * (0.5 + math.random()),
			life = STREAK.life * (0.6 + math.random() * 0.6),
			t = -math.random() * STREAK.delay, -- 제각기 조금씩 늦게 뜬다
			dir = dir,
			tone = Effects.TONE[tone],
			late = false,
		})
	end
end

-- 2단 점프: 발밑에서 좌우로 흩어지며 가라앉는 밝은 점 여섯(0.3초) — 공중에서 발을 구른 자리가 보인다
local HOP = { n = 6, life = 0.3, speed = 34, drop = 14, color = Color3.fromRGB(238, 246, 246) }
function Effects:hop(x: number, y: number)
	for i = 1, HOP.n do
		local frame = Kit.box(self.layer, 0, 0, if i <= 2 then 2 else 1, 1, HOP.color)
		frame.Name = "Hop"
		frame.ZIndex = 5
		local side = if i % 2 == 0 then 1 else -1
		table.insert(self.puffs, { frame = frame, x = x + side * 2, y = y - 1, vx = side * HOP.speed * (0.35 + 0.22 * math.ceil(i / 2)), t = 0 })
	end
end

-- 화살. 쏜 졸개의 종류(s.kind)에 제 날아가는 그림(shot)이 있으면 그 그림이 날아간다(빈 투구의 덩어리) — 없으면 흰 줄(궁병의 화살)
function Effects:addShot(s, now: number)
	local def = s.kind and COMBAT.mobs[s.kind]
	if def and def.atk.shot and def.atk.shot.clip then
		local sprite = Sprite.new(self.layer, def.sprite, 8)
		self.shots[s.id] = { sprite = sprite, clip = def.atk.shot.clip, x = s.x, y = s.y, dir = s.dir, speed = s.speed, born = now, range = s.range }
		return
	end
	local frame = Kit.box(self.layer, 0, 0, 7, 1, C.white)
	frame.Name = "Arrow"
	frame.ZIndex = 8
	self.shots[s.id] = { frame = frame, x = s.x, y = s.y, dir = s.dir, speed = s.speed, born = now, range = s.range }
end

function Effects:endShot(id: number)
	local s = self.shots[id]
	if s then
		if s.sprite then
			s.sprite:destroy()
		else
			s.frame:Destroy()
		end
		self.shots[id] = nil
	end
end

-- 몬스터의 마법(몸 동작과 따로 뜨는 그림): 그 종류의 마법 그림(cast)을 (x, y)에서 한 번 튼다 — 사람들의 앞에 그린다(맞는 것은 서버가 예고 뒤에 알린다)
function Effects:addMobCast(kind: string, x: number, y: number, dir: number?)
	local def = COMBAT.mobs[kind]
	local cast = def and def.atk.cast
	if not cast then
		return
	end
	local sprite = Sprite.new(self.layer, def.sprite, 7)
	local clip = sprite.char.clips[cast.clip]
	-- 앞으로 뻗는 마법(front — 등불 해파리의 번개 줄기)은 쓴 몬스터가 보던 쪽으로 뒤집어 그린다. 나머지(발밑 · 몸)는 뒤집지 않는다
	table.insert(self.sprites, { sprite = sprite, clip = cast.clip, x = x, y = y, dir = if cast.place == "front" then dir or 1 else 1, t = 0, life = cast.life, fps = clip.fps })
end

-- 떨어진 것: 달돈 · 달가루 = 작은 그림 · 장비 = 그 장비의 아이콘(성능 단이 보통이 아니면 귀퉁이에 세모)
--  땅에 놓이는 크기: 가방의 그림(18점)을 그대로 놓으면 캐릭터(키 17점)만 하다 — DROP_SCALE배로 줄여 놓는다(18 → 11점쯤).
--   사용자 2026-10-11: "드랍되는 아이템들 크기가 너무 큽니다. 다들 평균적으로". 달돈 · 달가루는 처음부터 8점으로 그린 그림을 그대로 쓴다(줄이면 뭉개진다)
Effects.DROP_SCALE = 0.6
Effects.COIN = { frames = 4, fps = 7, scale = 0.45 } -- 떨어진 달돈이 도는 그림의 장 수 · 빠르기(1초에 몇 장 — 한 바퀴에 0.57초)
function Effects:addDrop(d)
	local frame, w, h
	if d.kind == "gear" or d.kind == "quest" or d.kind == "goods" then
		w, h = Kit.ICON, Kit.ICON
		frame = Kit.group(self.layer, 0, 0, w, h)
		if d.kind == "gear" then
			Kit.icon(frame, ItemCell.icon(d.item), 0, 0)
			local tier = ItemCell.tier(d.item)
			if tier then
				Kit.part(frame, tier, 0, 0)
			end
		else
			-- 퀘스트의 물건 · 재료 · 물약 같은 가방의 아이템: 그 물건의 그림(공방의 그림 이름 — quests.generated · items.generated의 icon)
			Kit.icon(frame, d.icon, 0, 0)
		end
		local scale = Instance.new("UIScale")
		scale.Scale = Effects.DROP_SCALE
		scale.Parent = frame
		w, h = w * Effects.DROP_SCALE, h * Effects.DROP_SCALE
	else
		-- 달돈 = 도는 주화(부품 dropCoin1~4 — Codex의 그림을 칸 그대로 옮긴 것: 테두리 · 초승달 각인 · 빛) · 달가루 = 8x8 수정(부품 dropDust). 공방 tools/build_lune_coin.mjs · build_lune_ui.mjs.
		--  달돈이 지나온 길: 손으로 찍은 어두운 금색 8x8("돈처럼 안보이고 무슨 똥같이보입니다" — 2026-10-07) → 가방의 그림 18x18("돈너무 이미지 크기가 크게나온다") → 그것을 줄인 12x12("달돈 생긴거 너무 못생겼음" — 2026-10-11: 줄이며 뭉개졌다)
		--  → 손으로 찍은 밝은 민무늬 8x8("전혀 돈 같지 않고 그냥 노랑 동그란 과자같은데" — 같은 날: 테두리도 각인도 없었다) → Codex가 그린 주화를 손대지 않고 그대로. 달돈은 내가 손으로 그리지 않는다
		frame = Kit.part(self.layer, if d.kind == "dust" then "dropDust" else "dropCoin1", 0, 0)
		w, h = frame.Size.X.Offset, frame.Size.Y.Offset
		if d.kind ~= "dust" then
			-- 주화의 그림은 가로 19 · 세로 21점으로 그려져 있다(Codex의 칸 그대로 — 테두리와 초승달 각인이 들어가려면 그만한 칸이 든다). 땅에는 COIN.scale배로 놓는다(세로 9.5점쯤 — 캐릭터 키의 절반 남짓).
			--  화면의 점은 게임 세계의 도트보다 곱절 넘게 잘아서(세계 배율 3 이상) 줄여 놓아도 그림의 칸이 빠지지 않는다
			local scale = Instance.new("UIScale")
			scale.Scale = Effects.COIN.scale
			scale.Parent = frame
			w, h = w * Effects.COIN.scale, h * Effects.COIN.scale
		end
	end
	frame.Name = "Drop" .. d.id
	frame.ZIndex = 7
	-- 달돈은 빙글 돈다(spin — 부품 dropCoin1~4를 차례로: 앞 → 비스듬히 → 옆 → 비스듬히). 주화라는 것이 한눈에 보인다
	self.drops[d.id] = { frame = frame, x = d.x, y = d.y, w = w, h = h, amount = d.amount, kind = d.kind, item = d.item, name = d.name, phase = d.id * 0.7, spin = d.kind ~= "dust" and d.kind ~= "gear" and d.kind ~= "quest" and d.kind ~= "goods" }
end

function Effects:removeDrop(id: number)
	local d = self.drops[id]
	if d then
		d.frame:Destroy()
		self.drops[id] = nil
	end
	return d
end

-- 주울 수 있는 거리 안에서 가장 가까운 것의 번호
function Effects:dropNear(x: number, y: number, reach: number): number?
	local best, bestD = nil, reach
	for id, d in self.drops do
		local dist = math.abs(d.x - x)
		if dist <= bestD and math.abs(d.y - y) <= reach + 12 then
			best, bestD = id, dist
		end
	end
	return best
end

function Effects:update(now: number, dt: number)
	for i = #self.floats, 1, -1 do
		local f = self.floats[i]
		f.t += dt
		if f.t >= f.life then
			f.frame:Destroy()
			table.remove(self.floats, i)
		else
			local k = f.t / f.life
			if f.num then
				-- 시험 탭의 num과 같은 식: 16도트를 처음엔 빠르게 · 끝에선 느리게 오르고, 마지막 20%는 흐린 색
				local rise = NUM_RISE * (1 - (1 - k) * (1 - k)) + (if f.big and k < NUM_POP_T then NUM_POP else 0)
				f.frame.Position = UDim2.fromOffset(math.floor(f.x - f.width / 2 + 0.5) - 1, math.floor(f.y - rise + 0.5) - 1)
				if k > NUM_FADE and not f.faded then
					f.faded = true
					f.num:color(Effects.FADE)
				end
			else
				-- 알림 글: 게임의 도트로 6쯤 떠오른다(화면 틀의 점으로 자리를 잡는다)
				local rise = 6 * (1 - (1 - k) * (1 - k))
				f.frame.Position = UDim2.fromOffset(Overlay.x(f.x) - math.floor(f.width / 2), Overlay.y(f.y - rise))
			end
		end
	end
	for i = #self.sprites, 1, -1 do
		local sp = self.sprites[i]
		sp.t += dt
		if sp.t >= sp.life then
			sp.sprite:destroy()
			table.remove(self.sprites, i)
		elseif sp.t < 0 then
			sp.sprite.label.Visible = false -- 아직 제 때가 아니다(늦게 뜨는 것)
		else
			local n = #sp.sprite.char.clips[sp.clip].frames
			local f = math.floor(sp.t * sp.fps)
			local x = sp.x + (sp.vx or 0) * sp.t
			if (sp.lo and x < sp.lo) or (sp.hi and x > sp.hi) then
				sp.sprite.label.Visible = false -- 방의 벽 밖
			else
				sp.sprite:set(sp.clip, if sp.loop then f % n + 1 else math.min(n, f + 1), x, sp.y, sp.dir)
				if sp.fade and sp.fade > 0 then
					local k = sp.t / sp.life
					sp.sprite.label.ImageTransparency = if k > 1 - sp.fade then 1 - math.max(0, (1 - k) / sp.fade) else 0
				end
			end
		end
	end
	for i = #self.ghosts, 1, -1 do
		local g = self.ghosts[i]
		g.t += dt
		if g.t > GHOST.life then
			g.sprite:destroy()
			table.remove(self.ghosts, i)
		else
			g.sprite.label.ImageTransparency = 1 - GHOST.alpha * (1 - g.t / GHOST.life)
		end
	end
	for i = #self.lines, 1, -1 do
		local s = self.lines[i]
		s.t += dt
		local k = s.t / s.life
		if k >= 1 then
			s.frame:Destroy()
			table.remove(self.lines, i)
		elseif k >= 0 then
			-- 뒤로 밀리며 짧아진다. 앞의 절반은 밝은 색, 뒤의 절반은 직업 색
			local l = s.len * (1 - k)
			s.frame.Position = UDim2.fromOffset(math.floor(s.x - s.dir * k * STREAK.slide - (if s.dir > 0 then l else 0) + 0.5), math.floor(s.y + 0.5))
			s.frame.Size = UDim2.fromOffset(math.max(1, math.floor(l + 0.5)), 1)
			s.frame.Visible = true
			if k >= 0.5 and not s.late then
				s.late = true
				s.frame.BackgroundColor3 = s.tone.n
			end
		end
	end
	for i = #self.puffs, 1, -1 do
		local p = self.puffs[i]
		p.t += dt
		local k = p.t / HOP.life
		if k >= 1 then
			p.frame:Destroy()
			table.remove(self.puffs, i)
		else
			-- 처음엔 빠르게, 끝에선 느리게 옆으로 퍼지며 조금 가라앉고 흐려진다
			local out = 1 - (1 - k) * (1 - k)
			p.frame.Position = UDim2.fromOffset(math.floor(p.x + p.vx * HOP.life * out + 0.5), math.floor(p.y + HOP.drop * k * k + 0.5))
			p.frame.BackgroundTransparency = k
		end
	end
	for id, s in self.shots do
		local gone = (now - s.born) * s.speed
		if gone > s.range + 20 then
			self:endShot(id)
		else
			local x = s.x + s.dir * gone
			if s.sprite then
				s.sprite:set(s.clip, Sprite.frameAt(s.sprite.char, s.clip, now - s.born, false), x, s.y, s.dir)
			else
				s.frame.Position = UDim2.fromOffset(math.floor(x - 3 + 0.5), math.floor(s.y))
			end
		end
	end
	-- 떨어진 것은 땅 바로 위에서 천천히 오르내린다
	for _, d in self.drops do
		local bob = math.floor(math.sin(now * 4 + d.phase) * 1.5 + 0.5)
		d.frame.Position = UDim2.fromOffset(math.floor(d.x - d.w / 2 + 0.5), math.floor(d.y - d.h - 2 + bob + 0.5))
		if d.spin then
			local f = math.floor(now * Effects.COIN.fps + d.phase) % Effects.COIN.frames + 1
			if f ~= d.spinAt then
				d.spinAt = f
				Kit.swap(d.frame, "dropCoin" .. f)
			end
		end
	end
end

function Effects:destroy()
	for _, f in self.floats do
		f.frame:Destroy()
	end
	-- 날아가는 것: 흰 줄(frame)이거나 제 그림으로 나는 것(sprite — 빈 투구의 덩어리)이다. 둘 다 지운다
	--  (2026-10-13 — 전에는 모두 frame이라고 보고 지워서, 그림으로 나는 것이 떠 있는 동안 문을 지나면 여기서 오류가 났고 새 장면이 그려지지 않았다)
	for _, s in self.shots do
		if s.sprite then
			s.sprite:destroy()
		else
			s.frame:Destroy()
		end
	end
	for _, d in self.drops do
		d.frame:Destroy()
	end
	for _, sp in self.sprites do
		sp.sprite:destroy()
	end
	for _, g in self.ghosts do
		g.sprite:destroy()
	end
	for _, s in self.lines do
		s.frame:Destroy()
	end
	for _, p in self.puffs do
		p.frame:Destroy()
	end
	table.clear(self.puffs)
	table.clear(self.ghosts)
	table.clear(self.lines)
	table.clear(self.sprites)
	table.clear(self.floats)
	table.clear(self.shots)
	table.clear(self.drops)
end

return Effects
