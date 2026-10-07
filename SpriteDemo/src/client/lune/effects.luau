-- 잠깐 떴다 사라지는 것들 — 피해 숫자 · 얻은 것 알림 · 화살 · 떨어진 물건 · 대쉬의 잔상과 속도선. 모두 맵 좌표(도트)에 놓여 카메라와 함께 움직인다.
--  대쉬의 잔상 · 속도선은 공방 「횡스크롤 시험」 탭의 것 그대로다(값은 data/combat.generated.luau의 fx — dino-workshop/js/lune/fx.js의 DASHFX).
--   사용자 2026-10-07: "대쉬 이펙트가 바뀐거같은데" — 게임에는 이 효과가 없었다. 시험 탭과 같게 넣었다.
--  피해 숫자 · 화살 · 떨어진 것은 게임 세계의 그림(굵은 도트)이고, 알림 글(「+12」 · 「레벨 업!」)은 글씨의 층(화면 틀의 고운 격자 — overlay.luau)에 테두리 두른 작은 글씨로 뜬다.
--  피해 숫자는 공방 「횡스크롤 시험」 탭과 똑같이 뜬다(ui/kit.luau의 dmg — 3x5 점 숫자 · 0.7초 · 16도트 떠오름), 그 밖의 글은 작은 글씨(갈무리9)로 그린다.
--  떨어진 달돈 · 달가루는 작은 그림(8x8), 장비는 그 장비의 아이콘 그대로 떨어진다.
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

function Effects:addShot(s, now: number)
	local frame = Kit.box(self.layer, 0, 0, 7, 1, C.white)
	frame.Name = "Arrow"
	frame.ZIndex = 8
	self.shots[s.id] = { frame = frame, x = s.x, y = s.y, dir = s.dir, speed = s.speed, born = now, range = s.range }
end

function Effects:endShot(id: number)
	local s = self.shots[id]
	if s then
		s.frame:Destroy()
		self.shots[id] = nil
	end
end

-- 떨어진 것: 달돈 · 달가루 = 작은 그림 · 장비 = 그 장비의 아이콘(성능 단이 보통이 아니면 귀퉁이에 세모)
function Effects:addDrop(d)
	local frame, w, h
	if d.kind == "gear" then
		w, h = Kit.ICON, Kit.ICON
		frame = Kit.group(self.layer, 0, 0, w, h)
		Kit.icon(frame, ItemCell.icon(d.item), 0, 0)
		local tier = ItemCell.tier(d.item)
		if tier then
			Kit.part(frame, tier, 0, 0)
		end
	elseif d.kind == "quest" then
		-- 퀘스트의 물건: 그 물건의 그림 그대로(공방의 그림 이름 — quests.generated의 icon)
		w, h = Kit.ICON, Kit.ICON
		frame = Kit.group(self.layer, 0, 0, w, h)
		Kit.icon(frame, d.icon, 0, 0)
	else
		-- 달돈 · 달가루: 동전 · 수정 그림(12x12 — 부품 dropCoin · dropDust). 손으로 찍은 8x8 덩어리는 돈으로 보이지 않았고, 가방의 그림(18x18)은 너무 컸다
		--  (사용자 2026-10-07: "돈처럼 안보이고 무슨 똥같이보입니다" → "돈너무 이미지 크기가 크게나온다")
		frame = Kit.part(self.layer, if d.kind == "dust" then "dropDust" else "dropCoin", 0, 0)
		w, h = frame.Size.X.Offset, frame.Size.Y.Offset
	end
	frame.Name = "Drop" .. d.id
	frame.ZIndex = 7
	self.drops[d.id] = { frame = frame, x = d.x, y = d.y, w = w, h = h, amount = d.amount, kind = d.kind, item = d.item, name = d.name, phase = d.id * 0.7 }
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
		else
			local n = #sp.sprite.char.clips[sp.clip].frames
			sp.sprite:set(sp.clip, math.min(n, math.floor(sp.t * sp.fps) + 1), sp.x, sp.y, sp.dir)
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
	for id, s in self.shots do
		local gone = (now - s.born) * s.speed
		if gone > s.range + 20 then
			self:endShot(id)
		else
			local x = s.x + s.dir * gone
			s.frame.Position = UDim2.fromOffset(math.floor(x - 3 + 0.5), math.floor(s.y))
		end
	end
	-- 떨어진 것은 땅 바로 위에서 천천히 오르내린다
	for _, d in self.drops do
		local bob = math.floor(math.sin(now * 4 + d.phase) * 1.5 + 0.5)
		d.frame.Position = UDim2.fromOffset(math.floor(d.x - d.w / 2 + 0.5), d.y - d.h - 2 + bob)
	end
end

function Effects:destroy()
	for _, f in self.floats do
		f.frame:Destroy()
	end
	for _, s in self.shots do
		s.frame:Destroy()
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
	table.clear(self.ghosts)
	table.clear(self.lines)
	table.clear(self.sprites)
	table.clear(self.floats)
	table.clear(self.shots)
	table.clear(self.drops)
end

return Effects
