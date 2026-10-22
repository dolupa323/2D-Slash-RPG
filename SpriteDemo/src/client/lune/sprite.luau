-- 캐릭터 · 졸개 한 몸의 그림. 동작(clip)과 장 번호를 주면 캐릭터 판에서 그 장을 잘라 발밑 가운데 (x, y)에 맞춰 놓는다.
--  판의 그림은 오른쪽을 본다. 왼쪽을 볼 때는 자르는 폭을 음수로 줘서 뒤집는다(그림을 따로 두지 않는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local data = ReplicatedStorage.shared.lune.data
local CHARS = require(data["chars.generated"])
local ASSETS = require(data["assets.generated"])
local DYE = require(data["dye.generated"])
local Stage = require(script.Parent.stage)

-- 무기 · 로브 색(염색 — 2026-10-22 · 공방 design/dye.js): 영웅의 장에는 염색 판에서의 자리(8 · 9번째 수)가 있다.
--  로브 = 몸의 점만 흰색으로 담은 판(DYE.body)에 그 색을 입혀 · 무기 = 그 색의 판(DYE.point[].page)을 그대로, 캐릭터 그림의 아이로 겹친다(자리 · 크기 · 보이기를 따른다)
local DYE_POINT, DYE_ROBE = {}, {}
for _, q in DYE.point do
	DYE_POINT[q.id] = q.page
end
for _, q in DYE.robe do
	DYE_ROBE[q.id] = Color3.fromRGB(bit32.rshift(q.rgb, 16), bit32.band(bit32.rshift(q.rgb, 8), 255), bit32.band(q.rgb, 255))
end
local OVER = { "robeL", "pointL" } -- 겹치는 차례(로브 위에 무기 — 서로 겹치는 점은 없다)
local WHITE = Color3.new(1, 1, 1)

local Sprite = {}
Sprite.__index = Sprite
-- 고운 그림의 미리보기 배율(관리 창 「전투 → 보스 크기」): 동작에 k가 적힌 그림(스토리 보스)을 이 배만큼 더 크게 · 작게 그려 본다. 그림만 바뀐다(맞는 자리 · 몸의 판정은 설계값 그대로)
Sprite.preview = 1

-- mask = true면 같은 자리의 흰 실루엣 판(CHARS.masks)으로 그린다 — label.ImageColor3로 색을 입혀 한 색 실루엣을 만든다(대쉬의 잔상)
function Sprite.new(parent: Instance, who: string, z: number?, mask: boolean?)
	local char = CHARS.chars[who]
	assert(char, "없는 캐릭터 " .. tostring(who))
	local self = setmetatable({}, Sprite)
	self.who = who
	self.char = char
	self.pages = if mask then CHARS.masks else CHARS.pages
	self.masked = mask == true
	self.label = Stage.image(parent, who, "", 1, 1)
	self.label.ZIndex = z or 1
	self.label.Visible = false
	self.page = 0
	return self
end

-- 동작의 장 번호(1부터). once = 한 번만 틀고 마지막 장에서 멈춘다
function Sprite.frameAt(char, clip: string, t: number, once: boolean?): number
	local c = char.clips[clip]
	local n = #c.frames
	local i = math.floor(t * c.fps)
	return (if once then math.min(n - 1, i) else i % n) + 1
end

-- 줄여 그리는 캐릭터(char.size — 펫)의 크기를 지금 화면에서 한 점이 정수 화소가 되게 맞춘다(2026-10-21 사용자 "펫이 해상도가 딱 맞는 크기가 있을거야").
--  화면 화소 / 게임 도트 = Stage.scale(1080p 5 · 1440p 6 · 720p 3). 한 점 = Stage.scale x size 화소 — 소수면 점마다 2 · 3화소가 섞여 눈 · 무늬가 찌그러진다.
--  그래서 Stage.scale x size를 반올림한 화소로(0.6이면 1080p 3화소 = 0.6 · 1440p 4화소 = 0.67 · 720p 2화소 = 0.67). 화면에 꽉 차게 키우는 폰(소수 배율)은 그대로
function Sprite.sizeOn(size: number): number
	local k = Stage.scale
	if size == 1 or k < 2 or k ~= math.floor(k) then
		return size
	end
	return math.max(1, math.floor(k * size + 0.5)) / k
end

-- 염색 판의 한 겹(없으면 지운다)
local function layer(self, key: string, image: string?, color: Color3?)
	local o = self[key]
	if not image then
		if o then
			o:Destroy()
			self[key] = nil
		end
		return
	end
	if not o then
		o = Instance.new("ImageLabel")
		o.Name = key
		o.BackgroundTransparency = 1
		o.BorderSizePixel = 0
		o.ResampleMode = Enum.ResamplerMode.Pixelated
		o.ScaleType = Enum.ScaleType.Stretch
		o.Size = UDim2.fromScale(1, 1)
		o.Parent = self.label
		self[key] = o
	end
	o.Image = ASSETS[image] or ""
	self[key .. "C"] = color or WHITE
	self.tint = nil -- 색 · 투명도를 다시 맞춘다
end

-- 무기 · 로브 색: look = { point = 색?, robe = 색? }(sim/dye.luau) — 없거나 모르는 색이면 원래 색. 흰 실루엣(mask)에는 겹치지 않는다
function Sprite:setLook(look: any)
	if self.masked then
		return
	end
	local point = if typeof(look) == "table" then DYE_POINT[look.point] else nil
	local robe = if typeof(look) == "table" then DYE_ROBE[look.robe] else nil
	local key = (point or "-") .. "/" .. (if robe then tostring(robe) else "-")
	if key == self.lookKey then
		return
	end
	self.lookKey = key
	layer(self, "robeL", if robe then DYE.body else nil, robe)
	layer(self, "pointL", point, nil)
	self.lastF = nil -- 다음 set에서 겹을 그 장에 맞춘다
end

-- 겹의 색 · 투명도를 캐릭터 그림에 맞춘다(부르는 쪽이 그림을 흐리게 · 어둡게 하는 때 — 캐릭터 고르기 · 연출)
local function tone(self)
	local l = self.label
	local t, c = l.ImageTransparency, l.ImageColor3
	if self.tint == c and self.alpha == t then
		return
	end
	self.tint, self.alpha = c, t
	for _, key in OVER do
		local o = self[key]
		if o then
			local k = self[key .. "C"]
			o.ImageColor3 = Color3.new(k.R * c.R, k.G * c.G, k.B * c.B)
			o.ImageTransparency = t
		end
	end
end

-- 겹을 그 장의 염색 판 자리에(뒤집기도 같이). 염색 판에 없는 장이면 감춘다
local function cut(self, f, flip: boolean)
	for _, key in OVER do
		local o = self[key]
		if o then
			local ux = f[8]
			o.Visible = ux ~= nil
			if ux then
				local w, h = f[4], f[5]
				if flip then
					o.ImageRectOffset = Vector2.new(ux, f[9])
					o.ImageRectSize = Vector2.new(w, h)
				else
					o.ImageRectOffset = Vector2.new(ux + w, f[9])
					o.ImageRectSize = Vector2.new(-w, h)
				end
			end
		end
	end
end

-- scale = 몸의 크기(거신의 두 배 — 발밑 가운데를 그대로 두고 커진다. 없으면 1)
function Sprite:set(clip: string, frame: number, x: number, y: number, dir: number, scale: number?)
	local char = self.char
	local c = char.clips[clip]
	local f = c and c.frames[frame]
	local label = self.label
	if not f then
		label.Visible = false -- 빈 장
		self.lastF = nil
		return
	end
	if self.page ~= f[1] then
		self.page = f[1]
		label.Image = ASSETS[self.pages[f[1]]] or ""
	end
	local w, h, dx, dy = f[4], f[5], f[6], f[7]
	local px, py = math.floor(x + 0.5), math.floor(y + 0.5)
	-- 기준점: 캐릭터 동작은 발밑 가운데(ox, oy). 칸 크기가 따로인 동작(날아가는 그림)은 왼쪽 가운데다
	-- 제 기준점이 적힌 동작(몬스터의 마법 그림 = 발밑 가운데 · 날아가는 그림 = 한가운데)은 그것을 쓴다
	local ox, oy = char.ox, char.oy
	if c.ox then
		ox, oy = c.ox, c.oy
	elseif c.fw then
		ox, oy = 0, c.fh / 2
	end
	-- 고운 그림(c.k — 스토리 보스: 사용자가 만든 동작 그림을 받은 화소 그대로 싣고 작게 그린다. k = 그림 한 화소가 세계의 몇 점인가):
	--  부드럽게 줄여 그리고(도트 그림은 점이 또렷하게 — Pixelated) 자리와 크기를 점의 소수 자리까지 둔다. 사용자 2026-10-11: "게임에서 표현되어지는 크기를 줄이라는거에요 스프라이트를 건드리라는게아니라"
	local fine = c.k ~= nil
	-- char.size = 그 캐릭터를 그리는 크기(펫 0.5 — 2026-10-20 사용자 "펫은 유저보다 작아야합니다" · 승인된 그림의 점은 그대로 두고 작게 그린다. 점은 또렷하게(Pixelated))
	local s = (scale or 1) * (if fine then c.k * Sprite.preview else 1) * Sprite.sizeOn(char.size or 1)
	local exact = fine or (char.size ~= nil and char.size ~= 1) or (scale ~= nil and scale % 1 ~= 0) -- 줄여 그리는 것(펫 · 탄 영웅)은 자리 · 크기를 점의 소수 자리까지(반 점을 버리면 점의 크기가 고르지 않다)
	if self.fine ~= fine then
		self.fine = fine
		label.ResampleMode = if fine then Enum.ResamplerMode.Default else Enum.ResamplerMode.Pixelated
	end
	-- 지난번과 같은 장 · 같은 자리 · 같은 쪽 · 같은 크기면 다시 쓰지 않는다(폰에서 매 장면 몬스터 · 사람마다 다섯 값을 새로 쓰던 것 — 2026-10-18 검토).
	--  보이기만은 늘 맞춘다(부르는 쪽이 잠깐 숨겼다가 다시 그릴 때)
	local flip = dir >= 0
	if self.lookKey then
		tone(self)
	end
	if self.lastF == f and self.lastX == px and self.lastY == py and self.lastFlip == flip and self.lastS == s and self.lastOx == ox and self.lastOy == oy then
		if not label.Visible then
			label.Visible = true
		end
		return
	end
	self.lastF, self.lastX, self.lastY, self.lastFlip, self.lastS, self.lastOx, self.lastOy = f, px, py, flip, s, ox, oy
	local function R(v: number): number
		return if exact then v else math.floor(v + 0.5)
	end
	label.Size = UDim2.fromOffset(R(w * s), R(h * s))
	if dir >= 0 then
		label.ImageRectOffset = Vector2.new(f[2], f[3])
		label.ImageRectSize = Vector2.new(w, h)
		label.Position = UDim2.fromOffset(px - R((ox - dx) * s), py - R((oy - dy) * s))
	else
		label.ImageRectOffset = Vector2.new(f[2] + w, f[3])
		label.ImageRectSize = Vector2.new(-w, h)
		label.Position = UDim2.fromOffset(px + R((ox - dx - w) * s), py - R((oy - dy) * s))
	end
	if self.lookKey then
		cut(self, f, flip)
	end
	label.Visible = true
end

function Sprite:destroy()
	self.label:Destroy()
end

return Sprite
