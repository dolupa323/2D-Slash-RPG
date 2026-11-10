-- 「달의 계승자」 — 맵의 움직이는 장식(2026-11-10 사용자: "codixel 이랑 pixel bolt 활용해서 신지역이랑 신지역 몬스터를 더 멋지게 만들고, 마을도 좀더 즐길거리나 구경할거리 신기한 연출같은게 많았으면좋겠어"). 보는 것:
--  ① 자료: 신지역 다섯 맵(r5t · r5a1 · r5a2 · r5a3 · r5s)과 마을 일곱(town · r1bv · r2bs · port · r3t · seat · ct)에 장식 · 마을과 물별 마을은 축제가 있다 · 사냥터에는 축제가 없다
--     모든 장식 그림이 캐릭터 그림판에 있고 그 판이 로블록스에 올라가 있다 · 축제의 불꽃 셋 · 풍등도
--     굴뚝 연기 · 불티는 그 소품 위(소품 그림의 칸 안) · 반딧불의 구역은 맵 안
--  ② client/lune/ambient.luau(화면 없이): 들어서면 층 셋(하늘 = 장면 틀 9 · 소품 위 = 맵 틀 15 · 물 위 = 맵 틀 21) · 미리 흘려 두어 처음부터 그림이 있다 ·
--     층마다 맞는 것(풍등 · 별똥별 = 하늘 · 반딧불 · 연기 = 소품 위 · 달빛 · 물결 = 물 위) · 오르는 풍등은 위로 간다 · 축제 시각이면 불꽃이 하늘에 뜨고 대화창 한 줄(한 번) ·
--     축제 시각이 아니면 불꽃이 없다 · 떠나면 다 걷는다 · 장식이 없는 맵(사냥터 r1a1)에는 아무것도 없다
--  ③ 축포 상자(즐길거리): 축제가 있는 마을마다 그림 없는 주민 fwcrate(fire) 하나 · 문 · 다른 주민과 떨어진 땅 위 · 상자 그림(amb_crate) · Ambient.burst = 불꽃 셋이 솟아 하늘에서 터진다
--     서버(world.luau의 Firework): 상자 앞에서만 · 한 사람 gap초에 한 번 · 한 맵 roomGap초에 한 번 → 같은 맵 사람에게 Fireworks(장면 · 상자 자리 · 씨앗)
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local ASSETS = req("ReplicatedStorage/shared/lune/data/assets.generated")

-- ① 자료
local SHOW = SCENES.ambShow
expect(SHOW ~= nil and SHOW.every > SHOW.len and SHOW.len > 0, "축제의 불꽃놀이: every초마다 len초")
expect(type(SHOW.say) == "string" and #SHOW.say > 0, "축제가 시작될 때의 한 줄")
local function uploaded(id)
	local c = CHARS.chars[id]
	local ok = c ~= nil and c.clips.idle ~= nil and #c.clips.idle.frames > 0
	for _, f in (c and c.clips.idle.frames or {}) do
		if f then
			local file = CHARS.pages[f[1]]
			ok = ok and ASSETS[file] ~= nil and ASSETS[file] ~= ""
		end
	end
	return ok
end
for _, id in SHOW.arts do
	expect(uploaded(id), "축제의 불꽃 그림 " .. id .. "이 올라가 있다")
end
expect(uploaded("amb_lantern"), "풍등 그림이 올라가 있다")
local R5 = { "r5t", "r5a1", "r5a2", "r5a3", "r5s" }
local TOWNS = { "town", "r1bv", "r2bs", "port", "r3t", "seat", "ct" }
for _, key in R5 do
	local sc = SCENES.scenes[key]
	expect(sc ~= nil and sc.amb ~= nil and #sc.amb.list >= 3, key .. ": 신지역 맵에 장식(셋 이상)")
end
for _, key in TOWNS do
	local sc = SCENES.scenes[key]
	expect(sc ~= nil and sc.amb ~= nil and sc.amb.show == true, key .. ": 마을에 장식 + 축제")
end
expect(SCENES.scenes.r5t.amb.show == true, "물별 마을(r5t)에도 축제")
for _, key in { "r5a1", "r5a2", "r5a3" } do
	expect(SCENES.scenes[key].amb.show ~= true, key .. ": 사냥터에는 축제가 없다")
end
for key, sc in SCENES.scenes do
	if sc.amb then
		local W, H = sc.w * SCENES.tile, sc.h * SCENES.tile
		for _, q in sc.amb.list do
			expect(uploaded(q.art), ("%s: 장식 그림 %s이 올라가 있다"):format(key, q.art))
			local zOk = (q.k == "rise" or q.k == "cross") and q.z == "sky" or (q.k ~= "rise" and q.k ~= "cross" and (q.z == "mid" or q.z == "water"))
			expect(zOk, ("%s: %s(%s)의 층 %s"):format(key, q.art, q.k, tostring(q.z)))
			for _, pt in q.pts or {} do
				if not q.screen then
					expect(pt[1] >= 0 and pt[1] <= W and pt[2] >= 0 and pt[2] <= H, ("%s: %s의 자리 (%d, %d)가 맵 안"):format(key, q.art, pt[1], pt[2]))
				end
			end
			for _, ar in q.areas or {} do
				expect(ar[1] < ar[2] and ar[3] < ar[4] and ar[1] >= -20 and ar[2] <= W + 20 and ar[4] <= H, ("%s: %s의 구역이 맵 안"):format(key, q.art))
			end
		end
	end
end
-- 굴뚝 연기 · 불티는 그 소품의 그림 칸 안(지붕 · 굴뚝 · 모닥불 위)에서 시작한다
for key, sc in SCENES.scenes do
	for _, q in (sc.amb and sc.amb.list or {}) do
		if (q.art == "amb_smoke" or q.k == "ember") and not q.screen then
			for _, pt in q.pts do
				local inside = false
				for _, p in sc.back do
					local r = sc.rects[p.id]
					if r and pt[1] >= p.x - r.w / 2 and pt[1] <= p.x + r.w / 2 and pt[2] >= p.y - r.h - 1 and pt[2] <= p.y then
						inside = true
					end
				end
				expect(inside, ("%s: %s (%d, %d)가 소품 위"):format(key, q.art, pt[1], pt[2]))
			end
		end
	end
end

-- ② 게임에서(화면 없이)
local made = {}
MOCK("Client/lune/sprite", {
	new = function(parent, who)
		local sp = { who = who, parent = parent, label = { ImageTransparency = 0 } }
		function sp.set(_, clip, f, x, y, dir)
			sp.clip, sp.f, sp.x, sp.y, sp.dir = clip, f, x, y, dir
			sp.shown = (sp.shown or 0) + 1
		end
		function sp.destroy()
			sp.gone = true
		end
		table.insert(made, sp)
		return sp
	end,
})
MOCK("Client/lune/stage", {
	group = function(parent, name, z)
		local f = { Name = name, z = z, owner = parent, Parent = true }
		function f.Destroy()
			f.gone = true
			f.Parent = nil
		end
		return f
	end,
})
local Ambient = req("Client/lune/ambient")
local said = {}
Ambient.onShow = function(text)
	table.insert(said, text)
end
local T = 1000 * SHOW.every + SHOW.len + 30 -- 축제가 아닌 때
Ambient.clock = function()
	return T
end
local root, world = { Name = "root" }, { Name = "world" }
local view = { root = root, world = world, camX = 200 }

local function live(z)
	local out = {}
	for _, p in Ambient.list() do
		if (z == nil or p.z == z) and p.sprite and not p.sprite.gone then
			table.insert(out, p)
		end
	end
	return out
end
-- 물별 마을: 들어서면 층 셋 · 처음부터 그림이 있다
Ambient.enter(view, SCENES.scenes.r5t)
Ambient.update(1 / 60)
local groups = {}
for _, sp in made do
	groups[sp.parent] = true
end
local sky, mid, water = live("sky"), live("mid"), live("water")
expect(#mid >= 10, ("물별 마을: 들어서자마자 반딧불이 보인다(%d)"):format(#mid))
expect(#sky >= 1, ("물별 마을: 들어서자마자 하늘에 풍등(%d)"):format(#sky))
expect(#water >= 1, ("물별 마을: 물 위 달빛(%d)"):format(#water))
local layer = {}
for _, p in Ambient.list() do
	if p.sprite then
		layer[p.z] = p.sprite.parent
	end
end
expect(layer.sky and layer.sky.owner == root and layer.sky.z == Ambient.SKY_Z, "하늘의 장식 = 장면 틀(배경 그림 위 · 맵 틀 아래)")
expect(layer.mid and layer.mid.owner == world and layer.mid.z == Ambient.MID_Z and Ambient.MID_Z > 10 and Ambient.MID_Z < 20, "반딧불 · 연기 = 맵 틀의 뒤 소품(10) 위 · 땅(20) 아래")
expect(layer.water and layer.water.owner == world and layer.water.z == Ambient.WATER_Z and Ambient.WATER_Z > 20 and Ambient.WATER_Z < 22, "물 위 = 땅(20) 위 · 포탈(22) · 주민 · 캐릭터 아래")
local _ = groups
-- 풍등은 위로 오른다 · 반딧불은 제자리 둘레를 떠돈다
local lantern = nil
for _, p in live("sky") do
	if p.art == "amb_lantern" then
		lantern = p
	end
end
expect(lantern ~= nil, "하늘의 풍등")
local y0 = lantern and lantern.y or 0
local fly = live("mid")[1]
local fx0, fy0 = fly.x, fly.y
for _ = 1, 60 do
	Ambient.update(1 / 30)
end
expect(lantern == nil or lantern.y < y0 or lantern.sprite.gone, "풍등이 위로 올랐다")
expect(math.abs(fly.x - fly.hx) <= fly.rx + 0.01 and math.abs(fly.y - fly.hy) <= fly.ry + 0.01 and (fly.x ~= fx0 or fly.y ~= fy0), "반딧불이 제자리 둘레를 떠돈다")
-- 축제가 아닌 때: 불꽃이 없다
local function fireworks()
	local n = 0
	for _, p in live("sky") do
		if string.sub(p.art, 1, 7) == "amb_fw_" then
			n += 1
		end
	end
	return n
end
eq(fireworks(), 0, "축제가 아닌 때는 불꽃이 없다")
eq(#said, 0, "축제가 아닌 때는 한 줄도 없다")
-- 축제 시각: 불꽃이 뜨고 한 줄(한 번)
T = 1001 * SHOW.every + 1
local seen = 0
for _ = 1, 90 do
	T += 1 / 30
	Ambient.update(1 / 30)
	seen = math.max(seen, fireworks())
end
expect(seen >= 1, ("축제 시각: 하늘에 불꽃(가장 많을 때 %d)"):format(seen))
eq(#said, 1, "축제가 시작되면 대화창에 한 줄(한 번)")
eq(said[1], SHOW.say, "그 한 줄")
-- 떠나면 다 걷는다
Ambient.leave()
local left = 0
for _, sp in made do
	if not sp.gone then
		left += 1
	end
end
eq(left, 0, "떠나면 장식을 다 걷는다")
eq(#Ambient.list(), 0, "떠난 뒤 셈할 것이 없다")
-- 장식이 없는 맵
local before = #made
Ambient.enter(view, SCENES.scenes.r1a1)
Ambient.update(1 / 60)
eq(#made, before, "장식이 없는 사냥터(r1a1)에는 아무것도 없다")
-- 마을(굴뚝 연기 셋 · 새 떼가 화면을 가로지르면 걷는다)
Ambient.enter(view, SCENES.scenes.town)
T = 1002 * SHOW.every + SHOW.len + 30
Ambient.update(1 / 60)
local smoke = 0
for _, p in live("mid") do
	if p.art == "amb_smoke" then
		smoke += 1
	end
end
eq(smoke, 3, "마을: 굴뚝 연기 셋(촌장의 집 · 상점 · 대장간)")
local n0 = #Ambient.list()
for _ = 1, 30 * 40 do
	Ambient.update(1 / 30)
end
expect(#Ambient.list() < n0 + 40, ("마을: 40초 뒤에도 장식이 쌓이지 않는다(%d → %d)"):format(n0, #Ambient.list()))
Ambient.leave()

-- ③ 축포 상자
local L = SCENES.ambLaunch
expect(L ~= nil and L.gap >= 3 and L.roomGap > 0 and L.bursts >= 1, "축포 상자의 값")
for key, sc in SCENES.scenes do
	local crates = {}
	for _, n in sc.npcs or {} do
		if n.id == L.id then
			table.insert(crates, n)
		end
	end
	if sc.amb and sc.amb.show then
		eq(#crates, 1, key .. ": 축제가 있는 마을에 축포 상자 하나")
		local c = crates[1]
		if c then
			expect(c.stone == true and c.fire == true, key .. ": 그림 없는 주민(이름표만) · ↑ = 불꽃")
			expect(sc.amb.launch and sc.amb.launch.x == c.x and sc.amb.launch.y == c.y, key .. ": 장식의 상자 자리 = 주민 자리")
			local drawn = false
			for _, q in sc.amb.list do
				if q.art == L.art and q.pts[1][1] == c.x and q.pts[1][2] == c.y then
					drawn = true
				end
			end
			expect(drawn, key .. ": 상자 그림(amb_crate)을 그 자리에")
			for _, p in sc.portals or {} do
				expect(not (math.abs(p.x - c.x) < 32 and math.abs(p.y - c.y) < 4), ("%s: 상자가 문(%s)에서 32점 밖"):format(key, tostring(p.to)))
			end
			for _, n in sc.npcs do
				if n ~= c and math.abs(n.y - c.y) < 24 then
					expect(math.abs(n.x - c.x) >= 30, ("%s: 상자가 주민 %s에서 30점 밖"):format(key, n.id))
				end
			end
		end
	else
		eq(#crates, 0, key .. ": 축제가 없는 맵에는 축포 상자가 없다")
	end
end
expect(uploaded(L.art) and uploaded("amb_rocket"), "상자 · 솟는 불꽃 그림이 올라가 있다")
-- 클라이언트: burst → 셋이 솟고(위로) → 하늘에서 터진다
do
	table.clear(made)
	local town = SCENES.scenes.town
	Ambient.enter(view, town)
	T = 1003 * SHOW.every + SHOW.len + 30
	Ambient.update(1 / 60)
	local c = town.amb.launch
	Ambient.burst(c.x, c.y, 12345)
	local rockets = {}
	for _, p in Ambient.list() do
		if p.rocket then
			table.insert(rockets, p)
		end
	end
	eq(#rockets, L.bursts, "불꽃 bursts개")
	local y0 = rockets[1].y
	for _ = 1, 9 do
		Ambient.update(1 / 30)
	end
	expect(rockets[1].y < y0 - 20, ("첫 불꽃이 솟는다(%d → %d)"):format(y0, rockets[1].y))
	local fw0 = fireworks()
	for _ = 1, 40 do
		Ambient.update(1 / 30)
	end
	local still = 0
	for _, p in Ambient.list() do
		if p.rocket then
			still += 1
		end
	end
	eq(still, 0, "솟은 불꽃은 다 터졌다")
	expect(fireworks() > fw0 or fireworks() >= 1, "하늘에서 터졌다")
	Ambient.leave()
end
-- 서버: 상자 앞 · 한 사람 gap · 한 맵 roomGap
do
	local keep = clock.now
	RESET()
	clock.now = keep
	local handlers, sent = {}, {}
	MOCK("ReplicatedStorage/shared/lune/net/net", {
		FireClient = function(name, player, ...)
			if name == "Fireworks" then
				table.insert(sent, { player = player, args = { ... } })
			end
		end,
		OnServer = function(name, fn)
			handlers[name] = fn
		end,
	})
	SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
	local function signal()
		return { Connect = function() end }
	end
	SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
	SERVICE("RunService", { Heartbeat = signal() })
	SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
	local disk = {}
	MOCK("ServerScriptService/server/lune/modules/store", setmetatable({
		lock = function() return true end,
		loadAccount = function(id) return disk[id] end,
		saveAccount = function(id, v) disk[id] = v return true end,
		loadOld = function() return nil end,
		nameOwner = function() return nil end,
		claimName = function() return true end,
		rankTop = function() return {} end,
		rankInfoGet = function() return nil end,
		isOffline = function() return false end,
	}, { __index = function() return function() return nil end end }))
	local World = req("ServerScriptService/server/lune/modules/world")
	World.start()
	local function join(id, name)
		local p = { UserId = id, Name = name, DisplayName = name, attrs = {} }
		p.SetAttribute = function(self, k, v) self.attrs[k] = v end
		p.Kick = function() end
		local r = handlers.Ready(p)
		local cid = r and r.select and r.select.chars[1] and r.select.chars[1].id
		if not cid then
			local m = handlers.Chars(p, "create", name, "axion")
			cid = m and m.id
		end
		handlers.Chars(p, "enter", cid)
		local s = World.session(p)
		s.scene = "town"
		return p, s
	end
	local pa, sa = join(9101, "축포가")
	local pb, sb = join(9102, "축포나")
	local crate = SCENES.scenes.town.amb.launch
	expect(handlers.Firework ~= nil, "서버가 Firework를 받는다")
	sa.hero.x, sa.hero.y = crate.x + 200, crate.y
	sb.hero.x, sb.hero.y = crate.x - 300, crate.y
	handlers.Firework(pa)
	eq(#sent, 0, "상자 앞이 아니면 쏘지 않는다")
	sa.hero.x = crate.x + 6
	handlers.Firework(pa)
	eq(#sent, 2, "상자 앞에서 ↑ → 같은 맵 두 사람에게")
	local a = sent[1] and sent[1].args or {}
	expect(a[1] == "town" and a[2] == crate.x and a[3] == crate.y and typeof(a[4]) == "number", "장면 · 상자 자리 · 씨앗")
	sb.hero.x = crate.x - 4
	clock.now += L.roomGap * 0.5
	handlers.Firework(pb)
	eq(#sent, 2, "한 맵 roomGap초 안에는 다른 사람도 기다린다")
	clock.now += L.roomGap * 0.2
	handlers.Firework(pa)
	eq(#sent, 2, "한 사람 gap초 안에는 다시 쏘지 않는다")
	clock.now += L.roomGap
	handlers.Firework(pb)
	eq(#sent, 4, "roomGap초 뒤에는 다른 사람이 쏜다")
	clock.now += L.gap
	handlers.Firework(pa)
	eq(#sent, 6, "gap초 뒤에는 다시 쏜다")
	sa.scene = "r1a1"
	clock.now += L.gap
	handlers.Firework(pa)
	eq(#sent, 6, "다른 맵(상자가 없는 사냥터)에서는 쏘지 않는다")
	World.removePlayer(pa)
	World.removePlayer(pb)
end
