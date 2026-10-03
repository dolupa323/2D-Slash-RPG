-- 인술 연출(클라, 「오문 닌자전」 N2) — 서버 NinjutsuCast(씀) · TownMonsterHit("nin:<인술 id>", 맞음)을 받아 팩 이펙트 시트로 그린다.
--  어떤 인술이 어떤 이펙트를 쓰는지는 shared/config/ninjutsu.luau의 fx, 시트 안 자리는 shared/data/ninjaFx.generated.luau,
--  시트 그림은 townAssets.FX(업로드 전이면 아무것도 안 그림). 공방 「닌자 맵」 탭의 인술 시연(js/ninja/ninjutsuDemo.js)과 같은 규칙:
--   shot  — 손 높이에서 바라보는 쪽으로 날아감(투사체: 서버가 알려 준 거리까지 skill.speed로 / 직선: delay초 동안 길이만큼)
--   burst — 도착 자리에서 한 번(둘레 인술은 쓴 사람 자리)
--   ring  — 쓴 자리 둘레에 ringCount개(여러 번 치는 인술은 칠 때마다 자리를 돌려서)
--   row   — 바라보는 쪽 한 줄에 rowCount개(바닥에서 솟음 — 그림 아래쪽이 땅)
--   self  — 쓴 사람 몸(따라다님, loop면 지속 시간 동안 되풀이)
--   hit   — 맞은 몬스터 몸 위(TownMonsterHit). 불붙어 타는 피해("nin:burn")는 ninjutsu.BURN_FX
--  크기: 이펙트 그림 1도트 = 바닥 1도트(화면 map.S px) — 캐릭터·몬스터와 같은 밀도.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local Net = require(ReplicatedStorage.shared.net.net)
local config = require(ReplicatedStorage.shared.config.ninjutsu)
local map = require(script.Parent.map)
local monsters = require(script.Parent.monsters)
local packFx = require(script.Parent.Parent.packFx)

local S = map.S

local exports = {}
local gameFrame = nil

-- 이펙트 하나 재생(공용 재생기 modules/packFx.luau). where(t) → 가운데 자리(화면 px Vector2) 또는 nil(그만).
local function play(name: string?, where, opt)
	packFx.Play(gameFrame, name, where, opt)
end

-- 쓴 사람 발(화면 px) — 내 캐릭터 또는 복제된 다른 사람
local function ownerFeet(userId: number): Vector2?
	if userId == Players.LocalPlayer.UserId then
		local hero = require(script.Parent.Parent.topDownHero)
		return hero.pos and hero.pos * S
	end
	for _, object in NetworkingService.PlayersData[userId] or {} do
		local instance = object.Instance
		if instance and gameFrame and instance:IsDescendantOf(gameFrame) then
			return Vector2.new(instance.Position.X.Offset, instance.Position.Y.Offset)
		end
	end
	return nil
end

-- 대쉬 연출(공방 js/ninja/dashDemo.js와 같은 규칙): start = 떠난 자리 · path = 지나가는 대로 pathStep마다 · finish = 닿은 자리.
--  길에 남는 그림은 바닥에 깔리므로 캐릭터 아래에 그린다(불길처럼 서 있는 것은 그 자리의 깊이 순서).
local function dashFx(id: string, x: number, y: number, dx: number, dy: number, distance: number)
	local dash = config.DASH[id]
	local fx = dash and dash.fx
	if not fx then
		return
	end
	local feet = Vector2.new(x, y)
	local dir = Vector2.new(dx, dy)
	local body = feet - Vector2.new(0, config.BODY_Y)
	if fx.start then
		play(fx.start, function()
			return body * S
		end, { delay = dash.windup })
	end
	if fx.finish then
		play(fx.finish, function()
			return (body + dir * distance) * S
		end, { delay = dash.windup + dash.time })
	end
	if fx.path and distance > 0 then
		local d = fx.pathStep / 2
		while d < distance do
			local spot = feet + dir * d
			local at = (spot + Vector2.new(0, if fx.pathLoop then 2 else -2)) * S
			play(fx.path, function()
				return at
			end, {
				delay = dash.windup + dash.time * (d / distance),
				loop = fx.pathLoop ~= nil,
				duration = fx.pathLoop,
				hold = fx.pathHold,
				bottom = fx.pathLoop,
				rotation = if fx.pathLoop or dx ~= 0 then 0 else 90,
				zIndex = if fx.pathLoop then map.ZIndexFor(spot.Y + 2) else map.ZIndexFor(0),
			})
			d += fx.pathStep
		end
	end
end

local function cast(userId: number, skillId: string, x: number, y: number, dx: number, dy: number, distance: number)
	if string.sub(skillId, 1, 5) == "dash_" then
		dashFx(string.sub(skillId, 6), x, y, dx, dy, distance)
		return
	end
	local skill = config.SKILLS[skillId]
	local fx = skill and skill.fx
	if not fx then
		return
	end
	local feet = Vector2.new(x, y) -- 도트
	local dir = Vector2.new(dx, dy)
	local hand = feet - Vector2.new(0, config.HAND_Y)
	local body = feet - Vector2.new(0, config.BODY_Y)
	local kind = skill.kind
	if kind == "projectile" or kind == "seed" then
		local flight = distance / skill.speed
		play(fx.shot, function(t)
			return (hand + dir * skill.speed * t) * S
		end, { loop = true, duration = flight })
		local stop = (hand + dir * distance) * S
		play(fx.burst, function()
			return stop
		end, { delay = flight })
	elseif kind == "line" then
		local delay = math.max(skill.delay or 0, 0.01)
		play(fx.shot, function(t)
			return (hand + dir * skill.length * math.min(1, t / delay)) * S
		end, { loop = true, duration = delay + 0.05, rotation = math.deg(math.atan2(dy, dx)) })
		local count = fx.rowCount or 1
		for i = 1, if fx.row then count else 0 do
			local at = (feet + dir * skill.length * (i / count) * 0.9 + Vector2.new(0, 3)) * S
			play(fx.row, function()
				return at
			end, { delay = (i - 1) * 0.07, bottom = true })
		end
	elseif kind == "circle" then
		local count = fx.ringCount or 4
		for h = 0, (skill.hits or 1) - 1 do
			local t0 = (skill.delay or 0) + h * (skill.interval or 0)
			if h == 0 then
				play(fx.burst, function()
					return body * S
				end, { delay = math.max(0, t0 - 0.1) })
			end
			for i = 0, if fx.ring then count - 1 else -1 do
				local a = i / count * math.pi * 2 + h * 0.9
				local at = (body + Vector2.new(math.cos(a), math.sin(a)) * skill.radius * 0.66) * S
				play(fx.ring, function()
					return at
				end, { delay = math.max(0, t0 - 0.12) + i * 0.02 })
			end
		end
	elseif fx.self then
		-- 회복 · 방어: 쓴 사람 몸을 따라다닌다(방어는 서버가 알려 준 지속 시간 동안 되풀이)
		play(fx.self, function()
			local now = ownerFeet(userId) or feet * S
			return now - Vector2.new(0, 8 * S)
		end, { loop = fx.loop == true, duration = if fx.loop then distance else nil })
	end
	-- chain(번개)은 따로 그릴 것이 없다 — 맞은 몬스터마다 hit 이펙트(TownMonsterHit)
end

function exports.load(scene: Scene)
	local d = map.Use(scene)
	if not d then
		return
	end
	gameFrame = scene.Instance.GameFrame
	local key = map.key
	exports.conns = {
		Net.OnClient("NinjutsuCast", function(sceneKey, userId, skillId, x, y, dx, dy, distance)
			if sceneKey == key and gameFrame then
				cast(userId, skillId, x, y, dx, dy, distance)
			end
		end),
		-- 인술로 맞은 몬스터 몸 위에 그 인술의 맞음 이펙트
		Net.OnClient("TownMonsterHit", function(sceneKey, id, _hp, _damage, _attacker, source)
			if sceneKey ~= key or typeof(source) ~= "string" or string.sub(source, 1, 4) ~= "nin:" then
				return
			end
			local skillId = string.sub(source, 5)
			local burst = string.sub(skillId, -6) == ":burst" -- 씨앗이 터질 때("<id>:burst")
			if burst then
				skillId = string.sub(skillId, 1, -7)
			end
			local skill = config.SKILLS[skillId]
			local name = if skillId == "burn" then config.BURN_FX else skill and skill.fx and (if burst then skill.fx.burstHit else skill.fx.hit)
			local feet = monsters.Feet(id)
			if not name or not feet then
				return
			end
			local at = feet - Vector2.new(0, monsters.BODY_PX)
			play(name, function()
				return at
			end)
		end),
	}
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	for _, c in exports.conns or {} do
		c:Disconnect()
	end
	exports.conns = nil
	packFx.Clear(gameFrame)
	gameFrame = nil
end

return exports
