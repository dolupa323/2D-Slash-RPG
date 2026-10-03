-- 펫 패시브 스킬(M4, 서버) — 수치·패턴은 shared/config/petSkills.luau, 종별 스킬은 petSkills.generated(공방 내보내기).
--  플레이어가 공격할 때마다(townMonsters.OnPlayerAttack — 헛손질 포함) 함께 다니는 펫마다:
--   쿨타임(PET_COOLDOWN) 지났고 확률(패턴 proc)에 걸리면 → 같은 씬 모두에게 PetSkill(연출) → 피해/회복.
--  피해는 townMonsters.Damage(source "pet:<종 id>") — 주인 기여도에 합산, 반격·처치 규칙도 같다.
--  패턴:
--   bolt  — 발에서 BOLT_RANGE 안 가장 가까운 몬스터 한 마리, BOLT_FLIGHT초 뒤 맞음
--   burst — BURST_DELAY초 뒤 (그때의) 플레이어 둘레 BURST_RADIUS 안 모두
--   orbit — ORBIT_TIME초 동안 ORBIT_TICK초마다 둘레 ORBIT_RADIUS+ORBIT_BAND 안 모두
--   drop  — 이번에 맞힌 몬스터(없으면 DROP_RANGE 안 가장 가까운) 자리에 DROP_DELAY초 뒤, 그 둘레 DROP_RADIUS 안 모두
--   buff  — 체력이 덜 찼을 때만, 최대 체력의 HEAL_RATIO 회복
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local petSkills = require(ReplicatedStorage.shared.config.petSkills)
local features = require(ReplicatedStorage.shared.config.features)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local townMonsters = require(script.Parent.townMonsters)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)

local world = townWorld.data
local exports = {}
local rng = Random.new()
local ready = {} -- [userId] = { [파티 칸] = 다시 쓸 수 있는 시각 }

local function toScene(key: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient("PetSkill", player, key, ...)
	end
end

local function feetOf(player: Player): Vector2?
	local position = heroTracking.GetPosition(player.UserId)
	return position and position / world.scale
end

local function nearest(key: string, at: Vector2, range: number)
	local best, bestD = nil, range
	for _, m in townMonsters.Living(key) do
		local d = (Vector2.new(m.x, m.y) - at).Magnitude
		if d <= bestD then
			best, bestD = m, d
		end
	end
	return best
end

local function hitAround(key: string, player: Player, at: Vector2, radius: number, amount: number, source: string)
	for _, m in townMonsters.Living(key) do
		if (Vector2.new(m.x, m.y) - at).Magnitude <= radius then
			townMonsters.Damage(key, m.id, player, amount, source)
		end
	end
end

local function stillHere(player: Player, key: string): boolean
	return player.Parent ~= nil and townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId)) == key
end

-- 한 펫의 스킬 실행. 대상이 없어 못 쓰면 false(쿨타임을 쓰지 않음).
local function cast(player: Player, key: string, feet: Vector2, hitIds, slot: number, pet, skill): boolean
	local pattern = skill.pattern
	local amount = petSkills.Damage(pattern, pet.L or 1)
	local source = "pet:" .. pet.S -- 맞은 몬스터 위 연출을 그 펫 이펙트로(클라 town/petFx)
	local uid = player.UserId
	if pattern == "bolt" then
		local m = nearest(key, feet, petSkills.BOLT_RANGE)
		if not m then
			return false
		end
		toScene(key, uid, slot, pet.S, pattern, m.id, m.x, m.y)
		task.delay(petSkills.BOLT_FLIGHT, townMonsters.Damage, key, m.id, player, amount, source)
	elseif pattern == "burst" then
		toScene(key, uid, slot, pet.S, pattern, 0, feet.X, feet.Y)
		task.delay(petSkills.BURST_DELAY, function()
			local now = feetOf(player)
			if now and stillHere(player, key) then
				hitAround(key, player, now, petSkills.BURST_RADIUS, amount, source)
			end
		end)
	elseif pattern == "orbit" then
		toScene(key, uid, slot, pet.S, pattern, 0, feet.X, feet.Y)
		task.spawn(function()
			local t = 0
			while t < petSkills.ORBIT_TIME do
				t += task.wait(petSkills.ORBIT_TICK)
				local now = feetOf(player)
				if not now or not stillHere(player, key) then
					return
				end
				hitAround(key, player, now, petSkills.ORBIT_RADIUS + petSkills.ORBIT_BAND, amount, source)
			end
		end)
	elseif pattern == "drop" then
		local living = townMonsters.Living(key)
		local m = nil
		for _, c in living do
			if table.find(hitIds, c.id) then
				m = c
				break
			end
		end
		m = m or nearest(key, feet, petSkills.DROP_RANGE)
		if not m then
			return false
		end
		toScene(key, uid, slot, pet.S, pattern, m.id, m.x, m.y)
		local at = Vector2.new(m.x, m.y)
		task.delay(petSkills.DROP_DELAY, function()
			if stillHere(player, key) then
				hitAround(key, player, if m.dead then at else Vector2.new(m.x, m.y), petSkills.DROP_RADIUS, amount, source)
			end
		end)
	elseif pattern == "buff" then
		local data = persistence.Get(player)
		local maxHealth = data and balance.maxHealthFor(data.Level)
		if not data or (data.Health or maxHealth) >= maxHealth then
			return false -- 이미 가득이면 안 쓴다(연출만 나오는 걸 막음)
		end
		toScene(key, uid, slot, pet.S, pattern, 0, feet.X, feet.Y)
		progressionService.Heal(player, math.max(1, math.round(maxHealth * petSkills.HEAL_RATIO)))
	else
		return false
	end
	return true
end

local function onAttack(player: Player, key: string, feet: Vector2, _facing: string, hitIds)
	local data = persistence.Get(player)
	local p = data and data.Pets
	if not p or #p.Party == 0 then
		return
	end
	local now = os.clock()
	local mine = ready[player.UserId] or {}
	ready[player.UserId] = mine
	for slot, index in p.Party do
		local pet = p.Box[index]
		local skill = pet and petSkills.SkillOf(pet.S)
		local pattern = skill and petSkills.PATTERNS[skill.pattern]
		if not pattern or now < (mine[slot] or 0) or rng:NextNumber() >= pattern.proc then
			continue
		end
		if cast(player, key, feet, hitIds, slot, pet, skill) then
			mine[slot] = now + petSkills.PET_COOLDOWN
		end
	end
end

function exports.load()
	if not features.PETS then
		return -- 펫은 지금 꺼 둠(shared/config/features.luau)
	end
	townMonsters.OnPlayerAttack(onAttack)
	Players.PlayerRemoving:Connect(function(player)
		ready[player.UserId] = nil
	end)
end

function exports.start() end
function exports.unload() end

return exports
