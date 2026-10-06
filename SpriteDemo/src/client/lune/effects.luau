-- 잠깐 떴다 사라지는 것들 — 피해 숫자 · 얻은 것 알림 · 화살 · 떨어진 물건. 모두 맵 좌표(도트)에 놓여 카메라와 함께 움직인다.
--  피해 숫자는 큰 숫자 그림(ui/kit.luau의 big — 테두리를 두른 두 단 색), 그 밖의 글은 작은 글씨(갈무리9)로 그린다.
--  떨어진 달돈 · 달가루는 작은 그림(8x8), 장비는 그 장비의 아이콘 그대로 떨어진다.
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)
local Sprite = require(script.Parent.sprite)
local Kit = require(script.Parent.ui.kit)
local ItemCell = require(script.Parent.ui.itemCell)

local C = Kit.COLOR

local Effects = {}
Effects.__index = Effects
Effects.WHITE, Effects.MINT, Effects.PINK, Effects.GOLD = C.white, C.mint, C.red, C.yellow
Effects.DEAL, Effects.HURT = C.dmg, C.red -- 큰 숫자의 색: 내가 준 피해(주황) · 내가 받은 피해(빨강)

function Effects.new(layer: Frame)
	local self = setmetatable({}, Effects)
	self.layer = layer
	self.floats = {} -- 떠오르는 글씨 · 숫자
	self.shots = {} -- [번호] = 화살
	self.drops = {} -- [번호] = 떨어진 것
	self.sprites = {} -- 잠깐 틀고 사라지는 그림(기술의 광선 등)
	return self
end

-- 같은 자리에 겹치지 않게 조금씩 어긋나게 올린다
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
	local label = pixelText.new(self.layer, { Text = text, Font = "small", Color = color, Shadow = C.line, Align = "center" })
	label.Frame.ZIndex = 10
	self:_push({ frame = label.Frame, width = label.Width, x = x, y = y, t = 0, life = life or 0.7 }, 11)
end

-- (x, y) 위로 떠오르는 큰 숫자(피해)
function Effects:number(value: number, x: number, y: number, color: Color3)
	local big = Kit.big(self.layer, tostring(math.max(0, math.floor(value + 0.5))), color)
	big.frame.ZIndex = 11
	self:_push({ frame = big.frame, width = big.width, x = x, y = y - big.height + 9, t = 0, life = 0.8 }, big.height - 1)
end

-- 캐릭터 판의 동작 하나를 (x, y)에 한 번 튼다(화염 광선처럼 기술에 딸린 그림)
function Effects:addSprite(who: string, clip: string, x: number, y: number, dir: number, life: number, fps: number)
	local sprite = Sprite.new(self.layer, who, 6)
	table.insert(self.sprites, { sprite = sprite, clip = clip, x = x, y = y, dir = dir, t = 0, life = life, fps = fps })
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
	else
		local part = if d.kind == "dust" then "dropDust" else "dropCoin"
		frame = Kit.part(self.layer, part, 0, 0)
		w, h = frame.Size.X.Offset, frame.Size.Y.Offset
	end
	frame.Name = "Drop" .. d.id
	frame.ZIndex = 7
	self.drops[d.id] = { frame = frame, x = d.x, y = d.y, w = w, h = h, amount = d.amount, kind = d.kind, item = d.item, phase = d.id * 0.7 }
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
			local rise = 14 * (1 - (1 - k) * (1 - k))
			f.frame.Position = UDim2.fromOffset(math.floor(f.x - f.width / 2 + 0.5), math.floor(f.y - rise + 0.5))
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
	table.clear(self.sprites)
	table.clear(self.floats)
	table.clear(self.shots)
	table.clear(self.drops)
end

return Effects
