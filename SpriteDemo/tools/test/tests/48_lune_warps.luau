-- 「달의 계승자」 — 간이 포탈(2026-10-15): 사냥터 안에서 끝 ↔ 끝으로 옮겨 주는 거의 투명한 포탈.
--  사용자: "사냥터마다 사냥터에서 다른 사냥터로 이동하는 포탈 말고 사냥터 안에서 끝에서 끝으로 이동하는 간이 포탈 거의 투명하게 만들어야합니다. 이 간이 포탈 기능도 사냥터 내에서 이동하는 기능이 메이플에 있습니다."
--  자료: 공방 js/lune/design/maps.js의 warpsFor → scenes.generated의 warps · 서버 world.luau의 Hop(옮기고 Warp로 알린다) · 화면 sceneView.luau(그리기 · warpNear)
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")

-- ---- 1) 자료: 몬스터가 사는 맵마다 한 쌍 · 짝이 서로를 가리킨다 · 딛는 자리 · 문과 겹치지 않는다 ----
local hunting, withWarps = 0, 0
for key, sc in SCENES.scenes do
	local mobs = #(sc.mobs or {}) > 0
	if mobs and key ~= "in_cellar" and key ~= "dream" and not sc.rift and not sc.dojo then -- rift = 수정 틈 토벌(한 화면의 던전 — 간이 포탈 없음, 2026-10-16) · dojo = 개인 연무장(한 화면의 방 — 2026-10-26)
		hunting += 1
		local w = sc.warps or {}
		eq(#w, 2, "사냥터마다 간이 포탈 한 쌍 " .. key)
		if #w == 2 then
			withWarps += 1
			eq(w[1].at, w[2].id, "짝을 가리킨다 " .. key)
			eq(w[2].at, w[1].id, "짝이 되돌아 가리킨다 " .. key)
			for _, p in w do
				local col, row = math.floor(p.x / SCENES.tile), math.floor(p.y / SCENES.tile + 0.5)
				local cell = string.sub(sc.rows[row + 1] or "", col + 1, col + 1)
				local above = string.sub(sc.rows[row] or "", col + 1, col + 1)
				expect((cell == "#" or cell == "=") and above == ".", ("딛는 자리에 선다 %s %s(%d칸 %d줄)"):format(key, p.id, col, row))
				for _, g in sc.portals do
					expect(math.abs(g.x - p.x) >= 32 or math.abs(g.y - p.y) >= 32, ("다른 맵으로 가는 문과 겹치지 않는다 %s %s"):format(key, p.id))
				end
				expect(typeof(p.label) == "string" and #p.label > 0, "앞에 서면 뜨는 글 " .. key)
			end
			local far = math.max(math.abs(w[1].x - w[2].x), math.abs(w[1].y - w[2].y))
			expect(far >= 8 * SCENES.tile, ("끝에서 끝으로 — 서로 멀다 %s(%d점)"):format(key, far))
		end
	elseif not mobs then
		eq(#(sc.warps or {}), 0, "몬스터가 없는 맵에는 간이 포탈이 없다 " .. key)
	end
	expect(typeof(sc.warpAlpha) == "number" and sc.warpAlpha > 0 and sc.warpAlpha < 0.5, "거의 투명하다 " .. key)
end
expect(hunting >= 40 and withWarps == hunting, ("사냥터 %d곳에 모두(%d)"):format(hunting, withWarps))
-- 다른 맵으로 가는 문(portals)에는 섞이지 않는다 — 길찾기 · 월드맵은 문만 본다
for key, sc in SCENES.scenes do
	for _, p in sc.portals do
		expect(p.to ~= key, "문은 다른 맵으로 간다 " .. key)
	end
end

-- ---- 2) 서버: 그 앞에 서서 ↑ → 짝의 자리로 · 멀리서는 안 된다 · 화면에 알린다 ----
local handlers, sent = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
expect(handlers.Hop ~= nil, "서버가 간이 포탈(Hop)을 듣는다")
local p = { UserId = 4801, Name = "길손4801", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "길손4801", "axion")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
World.wake(p)
for _, key in { "r1a1", "r1c1" } do -- 가로 맵 · 층이 있는 맵
	expect(World.jump(p, key), key .. "로 간다")
	local w = SCENES.scenes[key].warps
	s.hero.x, s.hero.y = w[1].x + 4, w[1].y
	table.clear(sent)
	handlers.Hop(p, w[1].id)
	eq(s.hero.x, w[2].x, key .. ": 짝의 자리로(가로)")
	eq(s.hero.y, w[2].y, key .. ": 짝의 자리로(세로)")
	eq(s.scene, key, key .. ": 같은 맵 그대로")
	local told = false
	for _, m in sent do
		told = told or (m.name == "Warp" and m.args[1] == w[2].x and m.args[2] == w[2].y)
	end
	expect(told, key .. ": 화면에 새 자리를 알린다(Warp)")
	-- 되돌아온다
	handlers.Hop(p, w[2].id)
	eq(s.hero.x, w[1].x, key .. ": 짝에서 다시 처음 자리로")
	-- 멀리서는 안 된다
	s.hero.x = w[1].x + 200
	handlers.Hop(p, w[1].id)
	eq(s.hero.x, w[1].x + 200, key .. ": 포탈 앞이 아니면 옮기지 않는다")
	handlers.Hop(p, "없는 포탈")
	eq(s.hero.x, w[1].x + 200, key .. ": 없는 포탈은 아무 일도 없다")
end
