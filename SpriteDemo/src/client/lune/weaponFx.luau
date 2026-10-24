-- 캐시 무기의 피어오르는 점(2026-10-23 — 공방 design/wskin.js · 사용자 "캐쉬 무기를 만들어보자 멋지게 가능해?" → "1,2 적용").
--  캐시 무기를 입은 영웅의 그림(sprite.luau — sprite.skin · sprite.box = 지금 그린 장의 자리)마다, 그 장의 무기 자리
--  (dye.generated의 spots — 염색 판의 칸 "ux,uy"마다 장 안의 x, y를 고르게 고른 것) 가운데 한 곳에서 작은 점이 생겨
--  테마의 fx대로 움직인다: rate = 초당 생기는 수 · life = 사는 초 · vy = 위아래 빠르기(점/초 — 위 = 음수) · drift = 옆 흔들림(점) · size · colors · alpha(처음 투명도) · twinkle(깜빡임)
--   · plus(+ 모양 별 — 가운데 점의 위아래 · 옆에 한 점씩, 가운데의 0.55만큼 또렷). 흐려짐 = 사는 시간의 세제곱(끝에서만 흐려진다).
--  한 영웅 둘레에 skinMax개까지. 점 = 테두리 없는 작은 네모(영웅과 같은 층 · 영웅 바로 위). 다른 사람의 영웅도 같다(othersView의 그림).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DYE = require(ReplicatedStorage.shared.lune.data["dye.generated"])

local SKIN = {}
for _, q in DYE.skins do
	SKIN[q.id] = q
end
local function rgb(n: number): Color3
	return Color3.fromRGB(bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end

local WeaponFx = {}
WeaponFx.__index = WeaponFx

function WeaponFx.new()
	return setmetatable({ owners = {} }, WeaponFx) -- owners[그림] = { acc = 쌓인 생길 몫, parts = 떠 있는 점, pool = 쉬는 점 }
end

local function newDot(): Frame
	local f = Instance.new("Frame")
	f.Name = "WeaponDot"
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	return f
end

-- + 모양 별의 네 팔(점의 자식 — 처음 쓸 때 만든다 · 쉬는 점은 팔도 끈다)
local ARMS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function setArms(d: Frame, on: boolean, s: number, col: Color3?): { Frame }?
	local arms = d:GetChildren()
	if on and #arms == 0 then
		for _ = 1, 4 do
			local a = Instance.new("Frame")
			a.Name = "Arm"
			a.BorderSizePixel = 0
			a.BackgroundTransparency = 1
			a.Parent = d
		end
		arms = d:GetChildren()
	end
	for i, a in arms do
		a.Visible = on
		if on then
			a.Size = UDim2.fromOffset(s, s)
			a.Position = UDim2.fromOffset(ARMS[i][1] * s, ARMS[i][2] * s)
			a.BackgroundColor3 = col :: Color3
		end
	end
	return if on then arms :: { Frame } else nil
end

local function hide(d: Frame)
	d.BackgroundTransparency = 1
	for _, a in d:GetChildren() do
		(a :: Frame).Visible = false
	end
end

local function release(o)
	for _, p in o.parts do
		hide(p.d)
		table.insert(o.pool, p.d)
	end
	table.clear(o.parts)
end

-- 한 장 돌린다: sprites = 이번 장에 그린 영웅의 그림들(Sprite — 그린 뒤에 부른다) · dt = 지난 장부터의 초
function WeaponFx:step(sprites: { any }, dt: number)
	local seen = {}
	for _, sp in sprites do
		local skin = sp and sp.skin and SKIN[sp.skin]
		local label = sp and sp.label
		local box = sp and sp.box
		if skin and label and label.Parent and label.Visible and box and box.f then
			seen[sp] = true
			local o = self.owners[sp]
			if not o then
				o = { acc = 2.5, parts = {}, pool = {} } -- (입자마자 두세 개가 바로 보이게 — 공방 탭과 같다)
				self.owners[sp] = o
			end
			local fx = skin.fx
			local f = box.f
			local spots = f[8] and DYE.spots[f[8] .. "," .. f[9]]
			o.acc += dt * fx.rate
			while o.acc >= 1 do
				o.acc -= 1
				if spots and #spots >= 2 and #o.parts < DYE.skinMax then
					local k = math.random(1, #spots // 2)
					local sx, sy = spots[k * 2 - 1], spots[k * 2]
					local x = if box.right then box.x + (sx + 0.5) * box.s else box.x + (f[4] - sx - 0.5) * box.s
					local y = box.y + (sy + 0.5) * box.s
					local d = table.remove(o.pool) or newDot()
					d.Parent = label.Parent
					d.ZIndex = label.ZIndex + 1
					local size = (fx.size or 1) * box.s
					d.Size = UDim2.fromOffset(size, size)
					local col = rgb(fx.colors[math.random(1, #fx.colors)])
					d.BackgroundColor3 = col
					local arms = setArms(d, fx.plus == true, box.s, col)
					table.insert(o.parts, { d = d, arms = arms, x = x, y = y, t = 0, life = fx.life * (0.75 + math.random() * 0.5), ph = math.random() * 6.28, size = size })
				end
			end
			local a0 = fx.alpha or 0
			for i = #o.parts, 1, -1 do
				local p = o.parts[i]
				p.t += dt
				local k = p.t / p.life
				if k >= 1 or p.d.Parent ~= label.Parent then
					hide(p.d)
					table.insert(o.pool, p.d)
					table.remove(o.parts, i)
				else
					local px = p.x + math.sin(p.t * 4 + p.ph) * (fx.drift or 0) * 0.5
					local py = p.y + (fx.vy or 0) * p.t
					p.d.Position = UDim2.fromOffset(math.floor(px - p.size / 2 + 0.5), math.floor(py - p.size / 2 + 0.5))
					local tr = a0 + (1 - a0) * k * k * k -- 끝에서만 흐려진다
					if fx.twinkle and math.floor((p.t + p.ph) * 10) % 3 == 0 then
						tr = 1 -- 반짝 — 잠깐 꺼진다
					end
					p.d.BackgroundTransparency = tr
					if p.arms then
						for _, a in p.arms do
							a.BackgroundTransparency = 1 - (1 - tr) * 0.55
						end
					end
				end
			end
		end
	end
	-- 이번 장에 없는 그림(캐시 무기를 벗었다 · 숨었다 · 없어졌다): 점을 거둔다 · 없어진 그림은 잊는다
	for sp, o in self.owners do
		if not seen[sp] then
			release(o)
			if not (sp.label and sp.label.Parent) then
				for _, d in o.pool do
					d:Destroy()
				end
				self.owners[sp] = nil
			end
		end
	end
end

function WeaponFx:destroy()
	for _, o in self.owners do
		release(o)
		for _, d in o.pool do
			d:Destroy()
		end
	end
	table.clear(self.owners)
end

return WeaponFx
