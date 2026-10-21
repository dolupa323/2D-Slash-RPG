-- 펫 · 탈것을 그린다(2026-10-20 — 사용자: "탈것, 펫 애니메이션 만들고, 게임에 적용하고"). 나 · 같은 맵의 다른 사람이 하나씩 갖는다(boot · othersView).
--  그림 = chars.generated의 펫 · 탈것(공방 tools/build_lune_ride_made.mjs — 시안의 도트를 그대로 옮기고 부위를 옮겨 짠 서기 · 뛰기 · 점프).
--  펫(수치 · 까닭 · 출처는 공방 design/ride.js의 RIDE.pet):
--   10-20 사용자 "플레이어랑 펫이 거리가 좀 있어야하고 좀멀리서 쫓아오는 느낌이야 아이템주우면서" → 영웅의 뒤 behind점(44)에 선다 · 빠르기 = base + per x 남은 거리(멀면 빨라진다)
--    · 영웅이 서 있으면 펫은 제가 있던 쪽에 남는다(돌아설 때마다 영웅을 넘어 반대쪽으로 달려가지 않게)
--   10-21 사용자 "펫도 지형에 걸려야해요 지금 펫 지형 다뚫고 다니는데 지형에 걸려서 플레이어에게 가지 못하는 거리가 되어버리면 그때는 텔레포트 해서 붙는방식으로
--    메이플스토리에서 일반펫이 어떻게 작동하는지를 파악하고" → 펫은 영웅과 같은 땅 셈(shared sim/physics.luau)으로 1/60초씩 걷는다:
--    막힌 칸 · 발판 위에 서고 벽에 막힌다 · 벽 · 턱에 막히면 windup초 웅크렸다 뛴다 · 영웅이 위 발판에 있어도 따라 오르지 않는다(메이플의 일반 펫) · 영웅이 아래에 있으면
--    낭떠러지를 걸어 떨어지고 얇은 발판은 하단 점프로 내려간다 · 같은 높이의 건너편이면 뛰어 건넌다 · 사다리는 타지 않는다
--    순간 이동(영웅의 발밑 땅으로): 영웅이 땅에 서 있을 때 가로 warpX · 세로 warpY보다 멀면 · 가려는데 stuck초 동안 못 가고 영웅이 behind점보다 멀면 · 맵 아래로 떨어지면
--   줍기: 내 펫만(drops · onPick을 받은 것) — 영웅에게서 reach점 안 · 펫의 높이에서 위아래 magnet점 안의 떨어진 것에 달려가(chase) 펫에서 원 magnet점 안이면 onPick(번호, x, y)(자석 — 10-21)
--    → 서버(world.luau의 onPetPick)가 확인하고 줍는다. 한 번 해 본 것 · 가다가 막힌 것은 3초 동안 다시 보지 않는다
--  탈것: 탄 동안 영웅의 발밑에 탈것을 그리고, 영웅은 서기 모습으로 앉는 자리(seat)에 · 탈것의 등(<동작>_front)을 영웅 앞에 다시 그린다(다리가 몸에 묻혀 앉은 것으로 보인다).
--   사다리 위 · 기술을 쓰는 동안은 탈것을 감춘다(사용자 10-20 「탈것은 사다리에서 감추기 좋습니다」) — 영웅은 제 동작 그대로.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RIDE = require(ReplicatedStorage.shared.lune.data["ride.generated"])
local G = require(ReplicatedStorage.shared.lune.config.game)
local Physics = require(ReplicatedStorage.shared.lune.sim.physics)
local Sprite = require(script.Parent.sprite)

local RideView = {}
RideView.__index = RideView
local MOUNT = {}
for _, m in RIDE.mounts do
	MOUNT[m.id] = m
end
RideView.MOUNT = MOUNT
local P = RIDE.pet
local STEP = 1 / 60 -- 펫의 걸음(영웅과 같은 1/60초)
local T = G.TILE
local HALF = G.BOX_W / 2

-- layer = 영웅을 그리는 층 · z = 영웅의 ZIndex(탈것 · 펫은 그 뒤, 탈것의 등은 그 앞) · scene = 이 맵의 칸(shared data의 scenes — 펫이 걷는 땅)
function RideView.new(layer: Instance, z: number, scene: any)
	return setmetatable({
		layer = layer, z = z, scene = scene, petId = nil, pet = nil, rideId = nil, mount = nil, front = nil,
		body = nil, acc = 0, pdir = 1, goal = nil, tried = {}, nextPick = 0, windT = nil, prog = nil, warps = 0,
	}, RideView)
end

function RideView:setPet(id: any)
	id = if typeof(id) == "string" then id else nil
	if id == self.petId then
		return
	end
	if self.pet then
		self.pet:destroy()
		self.pet = nil
	end
	self.petId, self.body = id, nil
	if id then
		self.pet = Sprite.new(self.layer, id, self.z - 1)
	end
end

function RideView:setRide(id: any)
	id = if typeof(id) == "string" and MOUNT[id] then id else nil
	if id == self.rideId then
		return
	end
	for _, k in { "mount", "front" } do
		if self[k] then
			self[k]:destroy()
			self[k] = nil
		end
	end
	self.rideId = id
	if id then
		self.mount = Sprite.new(self.layer, id, self.z - 1)
		self.front = Sprite.new(self.layer, id, self.z + 1)
	end
end

function RideView:riding(): boolean
	return self.rideId ~= nil
end

-- (x, y)에서 아래로 maxDown점 안의 첫 땅(막힌 칸 · 얇은 발판의 윗면)이 있는 높이 — 몸 상자가 들어갈 자리만
local function groundBelow(scene, x: number, y: number, maxDown: number): number?
	for ty = math.floor(y / T), math.floor((y + maxDown) / T) do
		local surf = ty * T
		if surf >= y - 0.01 then
			for tx = math.floor((x - HALF) / T), math.floor((x + HALF - 1) / T) do
				local k = Physics.cell(scene, tx, ty)
				if (k == "#" or k == "=") and not Physics.solidBox(scene, x, surf) then
					return surf
				end
			end
		end
	end
	return nil
end
RideView.groundBelow = groundBelow

-- 영웅 곁의 x에 펫이 설 수 있는가: 영웅과 같은 높이의 땅이 있고 · 영웅과 그 자리 사이에 막힌 칸이 없다
local function spotOK(scene, hx: number, hy: number, x: number): boolean
	local sy = groundBelow(scene, x, hy - 4, 12)
	if not sy or math.abs(sy - hy) > 4 then
		return false
	end
	local s = if x > hx then 1 else -1
	for xx = hx, x, s * 6 do
		if Physics.solidBox(scene, xx, hy) then
			return false
		end
	end
	return not Physics.solidBox(scene, x, hy)
end
-- 펫이 설 자리: 영웅의 뒤(side 쪽) behind점 → 그 반 → 반대쪽 behind점 → 그 반 가운데 설 수 있는 첫 곳 · 없으면 영웅의 자리(벽 곁 · 좁은 발판 — 그 자리가 벽 속이면 벽 앞에서 뛰기만 했다)
local function spotFor(scene, hx: number, hy: number, side: number): number
	for _, off in { side * P.behind, side * P.behind / 2, -side * P.behind, -side * P.behind / 2 } do
		if spotOK(scene, hx, hy, hx + off) then
			return hx + off
		end
	end
	return hx
end

-- 영웅의 발밑 땅으로 옮긴다(메이플: 「lands on the ground under you」): 그 땅에서 영웅의 뒤 behind점(spotFor — 설 수 있는 곳)
function RideView:warp(x: number, y: number, dir: number)
	local scene = self.scene
	local b = self.body or { x = x, y = y, vx = 0, vy = 0, ground = false, air = 0 }
	self.body = b
	local gy = groundBelow(scene, x, y, 240) or y -- 영웅의 발밑 땅(사다리 · 공중이면 그 아래)
	local gx = spotFor(scene, x, gy, -dir)
	if Physics.solidBox(scene, gx, gy) then
		gx, gy = x, y -- 그 자리가 막힌 칸이면 영웅이 선 자리(영웅의 발밑은 늘 비어 있다)
	end
	b.x, b.y, b.vx, b.vy, b.ground, b.air, b.climb = gx, gy, 0, 0, true, 0, nil
	self.goal, self.windT, self.prog = nil, nil, nil
	self.warps += 1
end

-- 펫의 한 걸음(1/60초). hero = { x, y, dir, moving, air }
function RideView:petStep(now: number, hero, drops: any?, onPick: ((number, number, number) -> ())?)
	local scene, b = self.scene, self.body
	-- 순간 이동: 영웅이 땅에 서 있을 때 멀면(사다리 · 공중에서는 기다린다 — 영웅의 발밑 땅이 아직 정해지지 않았다)
	if not hero.air and (math.abs(hero.x - b.x) > P.warpX or math.abs(hero.y - b.y) > P.warpY) then
		self:warp(hero.x, hero.y, hero.dir)
		return
	end
	-- 주우러 갈 것: 영웅에게서 reach점 안 · 펫의 높이에서 위아래 magnet점 안(턱 · 발판 위에 놓여 펫이 오르지 못해도 원 안이면 줍는다) · 펫에게서 가장 가까운 것
	local goal = if self.goal and drops then drops[self.goal] else nil
	if goal and (math.abs(goal.x - hero.x) > P.reach + P.slack or math.abs(goal.y - b.y) > P.magnet) then
		goal = nil -- 영웅이 멀어졌다 · 펫이 다른 높이로 갔다
	end
	self.goal = if goal then self.goal else nil
	if not goal and drops and onPick and b.ground and now >= self.nextPick then
		local bd = math.huge
		for id, d in drops do
			if math.abs(d.x - hero.x) <= P.reach and math.abs(d.y - b.y) <= P.magnet and (self.tried[id] or 0) <= now then
				local dd = math.abs(d.x - b.x)
				if dd < bd then
					self.goal, goal, bd = id, d, dd
				end
			end
		end
	end
	-- 갈 곳 · 빠르기: 주우러 가면 그것 · 아니면 영웅이 움직이면 그 뒤로, 서 있으면 펫이 있던 쪽에
	local tx, speed
	if goal then
		tx, speed = goal.x, P.chase
	else
		local side = if hero.moving then -hero.dir elseif b.x < hero.x then -1 else 1
		-- 영웅이 달리는 동안은 늘 영웅의 뒤(2026-10-21 — 뒤에 설 땅이 없으면 영웅의 앞으로 갈 곳이 바뀌어 곧게 달리는데도 펫이 앞뒤로 튀었다) · 서 있으면 설 수 있는 곳
		tx = if hero.air or hero.moving then hero.x + side * P.behind else spotFor(scene, hero.x, hero.y, side)
		speed = math.min(P.max, P.base + P.per * math.abs(tx - b.x))
	end
	local d = tx - b.x
	local mx = if math.abs(d) <= (if goal then 1 else 2) then 0 elseif d > 0 then 1 else -1
	local input = { mx = mx, speed = speed / G.RUN }
	local heroBelow = not hero.air and hero.y > b.y + 8
	local wantJump = false
	if b.ground and mx ~= 0 then
		if Physics.solidBox(scene, b.x + mx * 2, b.y) then
			wantJump = true -- 벽 · 턱
		elseif not groundBelow(scene, b.x + mx * (HALF + 2), b.y, 2) then
			-- 낭떠러지: 영웅이 아래면 걸어 떨어진다 · 같은 높이의 건너편이면 뛰어 건넌다 · 위면 멈춘다(메이플의 일반 펫은 다른 발판으로 오르지 않는다)
			if heroBelow then
				-- 그대로 걷는다
			elseif not hero.air and math.abs(hero.y - b.y) <= 8 then
				wantJump = true
			else
				input.mx = 0 -- 선다(걸림은 아래에서 잰다)
			end
		end
	end
	-- 하단 점프: 영웅이 아래에 있고 펫이 얇은 발판 위면(영웅 쪽으로 가까울 때)
	if b.ground and heroBelow and Physics.onPlatform(scene, b) and math.abs(hero.x - b.x) <= P.behind + 24 then
		input.down, input.jump = true, true
	elseif wantJump then
		if not self.windT then
			self.windT = now + P.windup -- 웅크린다(그 자리에 선다)
		end
		if now >= self.windT then
			input.jump, self.windT = true, nil
		else
			input.mx = 0
		end
	elseif b.ground then
		self.windT = nil
	end
	local x0 = b.x
	if Physics.step(scene, b, input, STEP) == "respawn" then
		self:warp(hero.x, hero.y, hero.dir) -- 맵 아래로 떨어졌다
		return
	end
	-- 걸림: 가려는데(mx ~= 0) stuck초 동안 가려는 쪽으로 4점도 움직이지 못했다 — 벽 앞에서 뛰기를 되풀이하는 것 · 낭떠러지 앞에서 선 것 모두
	--  (한 걸음씩 세면 웅크림 · 뛰기 사이에 끊겨 키보다 높은 벽에서 영영 세지 못한다)
	--  2026-10-21 사용자 "마을을 일자로 달리면 계속 팅기듯이 프레임드랍 일어나는것처럼 보여요": 전에는 「갈 곳까지의 거리가 4점 줄었나」로 쟀다 —
	--   영웅이 달리면 펫은 갈 곳에서 같은 거리를 두고 따라가므로 거리가 줄지 않아 1.2초마다 「걸렸다」며 영웅 뒤로 순간 이동했다 → 펫이 실제로 움직인 만큼으로 잰다
	if mx == 0 then
		self.prog = nil
	elseif not self.prog or (b.x - self.prog.x) * mx >= 4 then
		self.prog = { x = b.x, t = now }
	elseif now - self.prog.t >= P.stuck then
		self.prog = nil
		if self.goal then
			self.tried[self.goal] = now + 3 -- 막혀 못 가는 것: 3초 동안 빼고 영웅에게 돌아간다
			self.goal = nil
		elseif not hero.air and math.abs(hero.x - b.x) > P.behind then
			self:warp(hero.x, hero.y, hero.dir) -- 지형에 걸려 영웅에게 가지 못한다(영웅이 바로 위의 발판 · behind점 안이면 기다린다 — 메이플의 일반 펫)
			return
		end
	end
	if math.abs(b.x - x0) > 0.01 then
		self.pdir = if b.x > x0 then 1 else -1
	elseif math.abs(hero.x - b.x) > 1 then
		self.pdir = if hero.x > b.x then 1 else -1 -- 멈추면 영웅 쪽을 본다
	end
	-- 닿았다: 펫(몸의 가운데)에서 원 magnet점 안이면 줍는다 — 자석처럼(2026-10-21 사용자 "펫의 줍기판정이 살짝 자석처럼 되어야합니다. 원형판정으로 지형이 좀 안좋거나 ,
	--  펫이 잘 올라가지 못하더라도 주워지게") · 원 안의 것은 갈 곳이 아니어도 지나가며 줍는다(가장 가까운 것 하나 — every초마다)
	if drops and onPick and now >= self.nextPick then
		local cy = b.y - 6 -- 펫 몸의 가운데쯤(발밑에서 6점 위)
		local pick, pd = nil, math.huge
		for id, d in drops do
			local ddx, ddy = d.x - b.x, d.y - 4 - cy
			local dist = math.sqrt(ddx * ddx + ddy * ddy)
			if dist <= P.magnet and dist < pd and (self.tried[id] or 0) <= now and math.abs(d.x - hero.x) <= P.reach + P.slack then
				pick, pd = id, dist
			end
		end
		if pick then
			self.tried[pick] = now + 3
			if self.goal == pick then
				self.goal = nil
			end
			self.nextPick = now + P.every
			onPick(pick, b.x, cy)
		end
	end
end

-- 한 장 그린다. (x, y) = 영웅의 발밑 · dir = 보는 쪽 · moving · air = 옆으로 움직이는 중 · 공중(사다리 위도) · hide = 사다리 위 · 기술 중 · 쓰러짐(탈것을 감춘다)
--  drops = 땅에 떨어진 것들({ [번호] = { x, y } } — effects.luau의 drops) · onPick(번호) = 펫이 닿았다(내 펫만 — 남의 펫은 nil: 따라다니기만)
--  돌려주는 것: 탄 동안 영웅을 그릴 자리(x, y) · 크기(서기 그림을 줄여 그리는 배 — ride.generated의 riderSize를 화면 화소에 맞춘 것) — 그 밖에는 nil(영웅은 제자리에 제 동작으로)
--   2026-10-21 사용자 "캐릭터가 탑승한모습이 자연스럽지않아요" · "탑승할때 플레이어도 idle 재생하면될듯 그 위치에서" → 탄 동안 영웅은 서기 그림 그대로 작게 · 안장 자리의 등 위에(장마다 잰 높이)
function RideView:update(now: number, dt: number, x: number, y: number, dir: number, moving: boolean, air: boolean, hide: boolean, drops: any?, onPick: ((number, number, number) -> ())?): (number?, number?, number?)
	if self.pet and self.scene then
		if not self.body then
			self:warp(x, y, dir) -- 처음 · 펫을 꺼낸 때: 영웅의 뒤
		end
		local hero = { x = x, y = y, dir = dir, moving = moving, air = air }
		-- 1/60초씩 걷는다(웅크림 · 다시 줍기의 초는 화면의 시각 now로 잰다) · 끊겼다 이어진 화면에서 한꺼번에 몰아 걷지 않게 여덟 걸음까지
		self.acc = math.min(self.acc + dt, STEP * 8)
		while self.acc >= STEP do
			self.acc -= STEP
			self:petStep(now, hero, drops, onPick)
		end
		local b = self.body
		local char = self.pet.char
		-- 펫의 그림 = 서기 하나(사용자 10-21 "펫은 idle 제외하고 그냥 움직이기만하면되지") — 걸어도 · 뛰어도 그 그림이 자리만 옮긴다
		--  자리 = 영웅이 그려지는 점(반올림) + 영웅과의 간격(반올림): 펫의 자리를 따로 반올림하면 같은 빠르기로 따라와도 영웅(과 화면)에 대해 장마다 한 점씩 떨렸다(2026-10-21)
		local hx, hy = math.floor(x + 0.5), math.floor(y + 0.5)
		self.pet:set("idle", Sprite.frameAt(char, "idle", now, false), hx + math.floor(b.x - x + 0.5), hy + math.floor(b.y - y + 0.5), self.pdir)
	end
	if not self.mount then
		return nil, nil
	end
	local show = not hide
	if not show then
		self.mount.label.Visible = false
		self.front.label.Visible = false
		return nil, nil
	end
	local m = MOUNT[self.rideId]
	local clip = if air then "jump" elseif moving then "run" else "idle"
	local f = Sprite.frameAt(self.mount.char, clip, now, clip == "jump")
	self.mount:set(clip, f, x, y, dir)
	self.front:set(clip .. "_front", f, x, y, dir)
	local bob = (m.bob[clip] and m.bob[clip][f]) or 0
	local bobx = (m.bobx and m.bobx[clip] and m.bobx[clip][f]) or 0 -- 어깨를 따라 앞뒤로(질주에서 어깨가 서 있는 그림보다 뒤 — 2026-10-21 사용자 "늑대 탑승위치가 갑자기 앞쪽으로가서")
	-- 탈것은 char.size배로 그린다(사용자 "탈것들의 크기가 좀더 커야하고" — 화면 화소에 맞춘 배) → 탈것 그림의 점으로 적힌 영웅의 자리도 그 배
	local ms = Sprite.sizeOn(self.mount.char.size or 1)
	return x + (m.seat.dx + bobx) * ms * dir, y + (m.seat.dy + bob) * ms, Sprite.sizeOn(RIDE.riderSize or 1)
end

function RideView:destroy()
	self:setPet(nil)
	self:setRide(nil)
end

return RideView
