--!native
--!optimize 2
-- 점 그림판 — 공방 시험 탭의 이펙트(dino-workshop/js/lune/fx.js · kits/*.js)는 캔버스에 점을 하나씩 찍어 그린다.
--  사용자 2026-10-08: "시험탭의 이펙트를 게임으로 옮기세요" — 게임도 같은 식으로 찍는다: 게임 화면 크기(384x216)의 EditableImage 두 장(캐릭터 뒤 · 앞)에
--  장마다 지우고 다시 찍는다. 그리는 쪽(client/lune/fx.luau · shared/lune/kits)은 시험 탭의 코드를 줄마다 옮긴 것이라, 캔버스의 2D 문맥에서 쓰던 것만 흉내 낸다:
--    ctx.fillStyle = c      → ctx:style(c)   (c = 0xRRGGBB)
--    ctx.globalAlpha = a    → ctx:alpha(a)   (0~1)
--    ctx.fillRect(x, y, w, h) → ctx:rect(x, y, w, h)   (게임 세계의 좌표 — 카메라만큼 밀어 찍는다. 화면 밖은 잘린다)
--  그림판은 맵 틀(world) 안에 카메라 자리로 놓여 화면에 붙어 있다(화면을 흔들면 같이 흔들린다).
--  EditableImage를 만들지 못하는 기기에서는 아무것도 찍지 않는다(게임은 그대로 돈다 — 이펙트만 안 보인다).
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage.shared.lune.config.game)

local W, H = G.VIEW_W, G.VIEW_H
local SIZE = Vector2.new(W, H)

local Ctx = {}
Ctx.__index = Ctx

local function newCtx(name: string)
	local self = setmetatable({}, Ctx)
	self.buf = buffer.create(W * H * 4)
	self.ox, self.oy = 0, 0 -- 카메라(게임 세계의 좌표에서 뺀다)
	self.r, self.g, self.b, self.a = 255, 255, 255, 255
	self.packed = 0xffffffff
	self.used = false -- 이번 장에 찍은 것이 있다
	self.shown = false -- 화면에 지난 장의 그림이 남아 있다
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.ScaleType = Enum.ScaleType.Stretch
	label.Size = UDim2.fromOffset(W, H)
	label.Active = false
	self.label = label
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = SIZE })
	end)
	if ok and image then
		self.image = image
		label.ImageContent = Content.fromObject(image)
	else
		warn("[lune] 점 그림판을 만들지 못했다 — 이펙트를 그리지 않는다: " .. tostring(image))
	end
	return self
end

function Ctx:style(c: number)
	local r, g, b = bit32.band(bit32.rshift(c, 16), 255), bit32.band(bit32.rshift(c, 8), 255), bit32.band(c, 255)
	self.r, self.g, self.b = r, g, b
	self.packed = r + g * 256 + b * 65536 + 255 * 16777216
end

function Ctx:alpha(a: number)
	self.a = math.clamp(math.floor(a * 255 + 0.5), 0, 255)
end

-- 네모를 채운다. 좌표와 크기는 가장 가까운 점으로 맞춘다
function Ctx:rect(x: number, y: number, w: number, h: number)
	local x0 = math.floor(x + 0.5) - self.ox
	local y0 = math.floor(y + 0.5) - self.oy
	local x1 = x0 + math.floor(w + 0.5)
	local y1 = y0 + math.floor(h + 0.5)
	if x0 < 0 then
		x0 = 0
	end
	if y0 < 0 then
		y0 = 0
	end
	if x1 > W then
		x1 = W
	end
	if y1 > H then
		y1 = H
	end
	local a = self.a
	if x1 <= x0 or y1 <= y0 or a <= 0 then
		return
	end
	self.used = true
	local buf = self.buf
	if a >= 255 then
		local v = self.packed
		for yy = y0, y1 - 1 do
			local i = (yy * W + x0) * 4
			for _ = x0, x1 - 1 do
				buffer.writeu32(buf, i, v)
				i += 4
			end
		end
		return
	end
	-- 비치는 점: 먼저 찍힌 점 위에 얹는다
	local r, g, b = self.r, self.g, self.b
	local inv = 255 - a
	for yy = y0, y1 - 1 do
		local i = (yy * W + x0) * 4
		for _ = x0, x1 - 1 do
			local da = buffer.readu8(buf, i + 3)
			if da == 0 then
				buffer.writeu8(buf, i, r)
				buffer.writeu8(buf, i + 1, g)
				buffer.writeu8(buf, i + 2, b)
				buffer.writeu8(buf, i + 3, a)
			else
				local rest = da * inv / 255
				local oa = a + rest
				buffer.writeu8(buf, i, math.floor((r * a + buffer.readu8(buf, i) * rest) / oa + 0.5))
				buffer.writeu8(buf, i + 1, math.floor((g * a + buffer.readu8(buf, i + 1) * rest) / oa + 0.5))
				buffer.writeu8(buf, i + 2, math.floor((b * a + buffer.readu8(buf, i + 2) * rest) / oa + 0.5))
				buffer.writeu8(buf, i + 3, math.floor(oa + 0.5))
			end
			i += 4
		end
	end
end

-- 그림(점 자료 { w, h, buf })의 한 조각을 찍는다 — 캔버스의 translate · scale · drawImage 대신.
--  자르는 네모 (sx, sy, w, h) · (x, y) = 기준점(게임 세계의 좌표) · (lx, ly) = 기준점에서 조각의 왼쪽 위까지 · flip = 기준점에서 좌우로 뒤집는다 · sc = 배(1 · 2) · mul = 불투명도의 배수
function Ctx:blit(src, sx: number, sy: number, w: number, h: number, x: number, y: number, lx: number, ly: number, flip: boolean?, sc: number?, mul: number?)
	local keepA, keepR, keepG, keepB, keepP = self.a, self.r, self.g, self.b, self.packed
	local base = keepA * (mul or 1)
	if base <= 0 then
		return
	end
	local s = sc or 1
	local data, sw = src.buf, src.w
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local at = ((sy + j) * sw + sx + i) * 4
			local sa = buffer.readu8(data, at + 3)
			if sa > 0 then
				local r, g, b = buffer.readu8(data, at), buffer.readu8(data, at + 1), buffer.readu8(data, at + 2)
				self.r, self.g, self.b = r, g, b
				self.packed = r + g * 256 + b * 65536 + 255 * 16777216
				self.a = math.floor(sa * base / 255 + 0.5)
				local px = lx + i
				self:rect(x + (if flip then -(px + 1) else px) * s, y + (ly + j) * s, s, s)
			end
		end
	end
	self.a, self.r, self.g, self.b, self.packed = keepA, keepR, keepG, keepB, keepP
end

-- 한 장을 시작한다: 지난 장을 지우고 카메라를 받는다
function Ctx:begin(camX: number, camY: number)
	if self.used then
		buffer.fill(self.buf, 0, 0)
		self.used = false
	end
	self.ox, self.oy = camX, camY
	self.r, self.g, self.b, self.a, self.packed = 255, 255, 255, 255, 0xffffffff
	self.label.Position = UDim2.fromOffset(camX, camY)
end

-- 찍은 것을 화면에 올린다(찍은 것도 남은 것도 없으면 아무것도 하지 않는다)
function Ctx:present()
	if self.image and (self.used or self.shown) then
		self.image:WritePixelsBuffer(Vector2.zero, SIZE, self.buf)
	end
	self.shown = self.used
end

local Canvas = {}
Canvas.W, Canvas.H = W, H

local back: any, front: any = nil, nil

-- 맵 틀에 붙인다(장면이 바뀔 때마다 — 그림판은 한 번만 만들어 다시 쓴다). 캐릭터 뒤의 것 · 앞의 것
function Canvas.attach(world: Instance, zBack: number, zFront: number)
	if not back then
		back, front = newCtx("FxBack"), newCtx("FxFront")
	end
	back.label.ZIndex, front.label.ZIndex = zBack, zFront
	back.label.Parent, front.label.Parent = world, world
	return back, front
end

-- 장면을 치울 때: 그림판을 떼어 둔다(없애지 않는다)
function Canvas.detach()
	if back then
		back.label.Parent, front.label.Parent = nil, nil
	end
end

return Canvas
