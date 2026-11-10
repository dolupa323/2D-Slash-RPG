-- 맵의 움직이는 장식(2026-11-10 — 공방 design/ambient.js · 셈은 js/lune/ambientSim.js와 같다).
--  사용자: "codixel 이랑 pixel bolt 활용해서 신지역이랑 신지역 몬스터를 더 멋지게 만들고, 마을도 좀더 즐길거리나 구경할거리 신기한 연출같은게 많았으면좋겠어"
--  반딧불 · 풍등 · 별똥별 · 새 떼 · 굴뚝 연기 · 불티 · 물안개 · 물 위 달빛 · 물결 + 마을의 축제 불꽃놀이(서버 시각으로 every초마다 len초 — 모두 같은 때).
--  맞지도 치지도 않는 그림일 뿐이다(서버는 모른다 · 화면마다 따로). 셋 다 주민 · 캐릭터 뒤(「맵의 것은 캐릭터 앞에 그리지 않는다」 — 10-08):
--   sky = 장면 틀(root)의 9 — 배경 그림(Layer 1~) 위 · 맵 틀(World 10 — 뒤 소품 · 집) 아래 · 화면의 점(카메라를 f만큼만 따라간다)
--   mid = 맵 틀의 15 — 뒤 소품(10) 위 · 땅(20) 아래 · water = 맵 틀의 21 — 땅 위 · 포탈(22) · 주민(30) · 캐릭터(50) 아래
--  그림 = 공방 tools/build_lune_ambient.mjs(Codixel · Pixelbolt) → CHARS의 amb_* (동작 idle 하나)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local SCENES = require(lune.data["scenes.generated"])
local CHARS = require(lune.data["chars.generated"])
local Stage = require(script.Parent.stage)
local Sprite = require(script.Parent.sprite)

local Ambient = {}
Ambient.SKY_Z, Ambient.MID_Z, Ambient.WATER_Z = 9, 15, 21
Ambient.PREWARM = 8 -- 들어서자마자 비어 보이지 않게 미리 흘려 두는 초
Ambient.forceShow = false -- 축제를 억지로 켠다(관리 · 자동 검사)
Ambient.onShow = nil -- 축제가 시작될 때(그 맵에 있는 사람) — boot가 대화창에 한 줄
Ambient.clock = function(): number -- 서버 시각(초 — 모두 같은 때 축제가 열린다 · 자동 검사가 바꾼다)
	return workspace:GetServerTimeNow()
end

local SHOW = SCENES.ambShow
local LAUNCH = SCENES.ambLaunch -- 마을의 축포 상자(↑ = 불꽃 — 서버가 같은 맵 모두에게 Fireworks)
local now = nil

local function R(rng, q): number
	return rng:NextNumber(q[1], q[2])
end

local function artOf(id: string)
	local c = CHARS.chars[id]
	local clip = c and c.clips.idle
	return if clip then { fps = clip.fps, n = #clip.frames } else nil
end

function Ambient.leave()
	if now then
		for _, p in now.list do
			if p.sprite then
				p.sprite:destroy()
			end
		end
		for _, g in { now.sky, now.mid, now.water } do
			g:Destroy()
		end
		now = nil
	end
end

-- 장면에 들어섰다(맵 틀이 새로 지어졌다): view = SceneView(root · world · camX)
function Ambient.enter(view, scene)
	Ambient.leave()
	local amb = scene and scene.amb
	if not view or not amb then
		return
	end
	now = {
		view = view,
		amb = amb,
		list = {},
		timers = {},
		arts = {},
		rng = Random.new(),
		started = false,
		showWas = false,
		showT = 0.5,
		lanT = 1,
		sky = Stage.group(view.root, "AmbSky", Ambient.SKY_Z),
		mid = Stage.group(view.world, "AmbMid", Ambient.MID_Z),
		water = Stage.group(view.world, "AmbWater", Ambient.WATER_Z),
	}
	local function art(id)
		if now.arts[id] == nil then
			now.arts[id] = artOf(id) or false
		end
		return now.arts[id]
	end
	for _, id in SHOW.arts do
		art(id)
	end
	art("amb_lantern")
	art("amb_rocket")
	local rng = now.rng
	for _, q in amb.list do
		art(q.art)
		if q.k == "loop" then
			for i, pt in q.pts do
				table.insert(now.list, { art = q.art, z = q.z, x = pt[1], y = pt[2], t = rng:NextNumber(0, 4) + i * 0.37, a = q.alpha, dir = 1, sp = if q.screen then "screen" else "world", f = q.f or 0, loop = true })
			end
		elseif q.k == "mote" then
			for _, ar in q.areas do
				for _ = 1, q.n do
					local hx, hy = rng:NextNumber(ar[1], ar[2]), rng:NextNumber(ar[3], ar[4])
					table.insert(now.list, {
						art = q.art,
						z = "mid",
						x = hx,
						y = hy,
						hx = hx,
						hy = hy,
						rx = math.min(14, (ar[2] - ar[1]) / 2),
						ry = math.min(7, (ar[4] - ar[3]) / 2),
						ph = { rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28) },
						t = rng:NextNumber(0, 4),
						a = 1,
						dir = 1,
						sp = "world",
						mote = true,
						loop = true,
					})
				end
			end
		else
			table.insert(now.timers, { q = q, wait = R(rng, q.every or { 1, 2 }) * 0.5 })
		end
	end
end

local function spawn(n, q, camX: number): number
	local rng = n.rng
	if not n.arts[q.art] then
		return 0
	end
	if q.k == "rise" then
		table.insert(n.list, { art = q.art, z = "sky", x = camX * q.f + R(rng, q.sx), y = q.from, vy = -R(rng, q.speed), sway = q.sway, ph = rng:NextNumber(0, 6.28), t = rng:NextNumber(0, 2), a = 0, dir = 1, sp = "sky", f = q.f, rise = q, loop = true })
		return 1
	elseif q.k == "cross" then
		local dir = if rng:NextNumber() < 0.5 then 1 else -1
		local count = if q.flock then math.floor(R(rng, q.flock) + 0.5) else 1
		local y0, speed = R(rng, q.sy), R(rng, q.speed)
		local life = if q.life then R(rng, q.life) else nil
		-- 별똥별은 화면 위 아무 데서나 나타난다(잠깐) · 새 떼는 화면 밖에서 들어와 가로지른다
		local x0 = if life then camX * q.f + rng:NextNumber(60, 324) else camX * q.f + (if dir > 0 then -20 else 404)
		for i = 0, count - 1 do
			table.insert(n.list, {
				art = q.art,
				z = "sky",
				x = x0 - dir * (i * 11 + rng:NextNumber(0, 6)),
				y = y0 + (if i > 0 then rng:NextNumber(-7, 7) else 0),
				vx = dir * speed * (1 + rng:NextNumber(-0.04, 0.04)),
				vy = speed * q.fall,
				bob = q.bob,
				ph = rng:NextNumber(0, 6.28),
				t = rng:NextNumber(),
				a = 1,
				dir = dir,
				sp = "sky",
				f = q.f,
				life = life,
				age = 0,
				loop = true,
				cross = q,
				first = i == 0,
			})
		end
		return count
	elseif q.k == "pop" then
		table.insert(n.list, { art = q.art, z = "water", x = R(rng, { q.area[1], q.area[2] }), y = math.floor(R(rng, { q.area[3], q.area[4] }) + 0.5), t = 0, a = 1, dir = 1, sp = "world", once = true })
		return 1
	elseif q.k == "ember" then
		for _, pt in q.pts do
			table.insert(n.list, { art = q.art, z = "mid", x = pt[1] + rng:NextNumber(-3, 3), y = pt[2], vx = rng:NextNumber(-0.5, 0.5) * q.drift, vy = -R(rng, q.rise), t = 0, a = 1, dir = 1, sp = "world", life = R(rng, q.life), age = 0, ember = true, loop = true })
		end
		return #q.pts
	end
	return 0
end

local function drop(n, i: number)
	local p = n.list[i]
	if p.sprite then
		p.sprite:destroy()
	end
	table.remove(n.list, i)
end

-- 셈(그리지 않는다): 공방 ambientSim.js의 ambStep과 같다
local function step(n, dt: number, camX: number, at: number?, force: boolean, camY: number?)
	local rng = n.rng
	for _, tm in n.timers do
		tm.wait -= dt
		if tm.wait <= 0 then
			tm.wait = R(rng, tm.q.every)
			local live = 0
			for _, p in n.list do
				if p.rise == tm.q or (p.cross == tm.q and p.first) then
					live += 1
				end
			end
			if tm.q.max == nil or live < tm.q.max then
				spawn(n, tm.q, camX)
			end
		end
	end
	-- 축제의 불꽃놀이: 서버 시각으로 every초마다 len초 동안
	local on = n.amb.show == true and (force or (at ~= nil and at % SHOW.every < SHOW.len))
	n.showStarted = on and not n.showWas
	n.showWas = on
	if on then
		n.showT -= dt
		if n.showT <= 0 then
			n.showT = R(rng, SHOW.rate)
			local art = SHOW.arts[rng:NextInteger(1, #SHOW.arts)]
			if n.arts[art] then
				table.insert(n.list, { art = art, z = "sky", x = camX * SHOW.f + R(rng, SHOW.sx), y = R(rng, SHOW.sy), t = 0, a = 1, dir = 1, sp = "sky", f = SHOW.f, once = true })
			end
		end
		n.lanT -= dt
		if n.lanT <= 0 then
			n.lanT = R(rng, SHOW.lantern)
			n.showRise = n.showRise or { k = "rise", art = "amb_lantern", sx = { 16, 368 }, from = 168, to = -16, speed = { 7, 11 }, sway = 3, f = 0.3 }
			spawn(n, n.showRise, camX)
		end
	end
	for i = #n.list, 1, -1 do
		local p = n.list[i]
		local a = n.arts[p.art]
		p.t += dt
		if not a then
			drop(n, i)
		elseif p.once then
			if p.t * a.fps >= a.n then
				drop(n, i)
			end
		elseif p.mote then
			p.x = p.hx + p.rx * (math.sin(p.t * 0.53 + p.ph[1]) * 0.7 + math.sin(p.t * 1.31 + p.ph[2]) * 0.3)
			p.y = p.hy + p.ry * math.sin(p.t * 0.71 + p.ph[3])
		elseif p.rise then
			p.y += p.vy * dt
			p.x += math.sin(p.t * 0.8 + p.ph) * p.sway * dt
			local q = p.rise
			local done = (q.from - p.y) / (q.from - q.to)
			p.a = math.min(1, done / 0.08, (1 - done) / 0.25)
			if done >= 1 then
				drop(n, i)
			end
		elseif p.cross then
			p.age += dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			local sx = p.x - camX * p.f
			if p.life then
				p.a = math.min(1, (p.life - p.age) / 0.25, p.age / 0.06)
				if p.age >= p.life then
					drop(n, i)
				end
			elseif (p.dir > 0 and sx > 420) or (p.dir < 0 and sx < -40) then
				drop(n, i)
			end
		elseif p.rocket then
			-- 축포 상자의 불꽃: 기다렸다가(t < 0) rise초 동안 솟아 하늘(화면 위 sy점)에서 터진다
			if p.t < 0 then
				p.a = 0
			else
				p.a = 1
				local u = math.min(1, p.t / LAUNCH.rise)
				local e = 1 - (1 - u) * (1 - u)
				local ty = (camY or 26) + p.sy
				p.x = p.x0 + p.dx * e
				p.y = p.y0 + (ty - p.y0) * e
				if u >= 1 then
					local bx, sy, boom = p.x, p.sy, p.boom
					drop(n, i)
					if n.arts[boom] then
						table.insert(n.list, { art = boom, z = "sky", x = camX * SHOW.f + (bx - camX), y = sy, t = 0, a = 1, dir = 1, sp = "sky", f = SHOW.f, once = true })
					end
				end
			end
		elseif p.ember then
			p.age += dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			p.a = math.max(0, 1 - p.age / p.life)
			if p.age >= p.life then
				drop(n, i)
			end
		end
	end
end

-- 매 화면(BindToRenderStep 안 — 화면의 그림은 그때만 고친다 · 카메라를 맞춘 뒤): 셈하고 그린다
function Ambient.update(dt: number)
	local n = now
	if not n or not n.mid.Parent then
		return
	end
	local camX = n.view.camX or 0
	local at = Ambient.clock()
	if not n.started then
		n.started = true
		for _ = 1, Ambient.PREWARM * 10 do
			step(n, 0.1, camX, nil, false)
		end
	end
	step(n, math.min(dt, 0.1), camX, at, Ambient.forceShow, n.view.camY)
	if n.showStarted and Ambient.onShow then
		Ambient.onShow(SHOW.say)
	end
	for _, p in n.list do
		local a = n.arts[p.art]
		local group = if p.z == "sky" then n.sky elseif p.z == "water" then n.water else n.mid
		if not p.sprite then
			local ok, sp = pcall(Sprite.new, group, p.art)
			if not ok then
				continue -- (그림이 아직 실리지 않았다)
			end
			p.sprite = sp
		end
		local x, y = p.x, p.y
		if p.sp == "sky" then
			x = p.x - camX * p.f
			if p.bob and p.bob ~= 0 then
				y = p.y + math.sin(p.t * 9 + p.ph) * p.bob
			end
		elseif p.sp == "screen" then
			x = camX + p.x - math.floor(camX * p.f + 0.5)
		end
		local f = math.floor(p.t * a.fps)
		local frame = if p.once then math.min(a.n, f + 1) else (f % a.n) + 1
		p.sprite:set("idle", frame, x, y, p.dir)
		local tr = 1 - math.clamp(p.a or 1, 0, 1)
		if p.tr ~= tr then
			p.tr = tr
			p.sprite.label.ImageTransparency = tr
		end
	end
end

-- 축포 상자의 불꽃(서버의 Fireworks — 같은 맵 모두가 같은 씨앗): (x, y) = 상자의 발밑 → bursts개가 stagger초 사이로 솟는다(공방 ambientSim.js의 ambBurst와 같은 셈)
function Ambient.burst(x: number, y: number, seed: number?)
	local n = now
	if not n or not LAUNCH then
		return
	end
	local rng = Random.new(seed or 1)
	for i = 0, LAUNCH.bursts - 1 do
		local k = i - (LAUNCH.bursts - 1) / 2
		table.insert(n.list, {
			art = "amb_rocket",
			z = "mid",
			x = x + k * 4,
			y = y - 14,
			x0 = x + k * 4,
			y0 = y - 14,
			dx = k * LAUNCH.spread * (0.7 + rng:NextNumber() * 0.6) + (rng:NextNumber() - 0.5) * 10,
			sy = LAUNCH.sy[1] + rng:NextNumber() * (LAUNCH.sy[2] - LAUNCH.sy[1]),
			t = -i * LAUNCH.stagger,
			a = 0,
			dir = 1,
			sp = "world",
			rocket = true,
			loop = true,
			boom = SHOW.arts[rng:NextInteger(1, #SHOW.arts)],
		})
	end
end

-- 지금 그리고 있는 것(자동 검사가 본다)
function Ambient.list(): { any }
	return if now then now.list else {}
end

return Ambient
