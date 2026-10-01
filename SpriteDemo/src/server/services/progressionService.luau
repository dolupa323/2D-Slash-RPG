-- 성장/체력 서비스: 경험치·레벨업·피해·사망. 플레이어 진행 상황의 진실은 서버 세션 데이터(persistence)이고, 이 서비스가
-- 규칙(shared/config/balance.luau)에 따라 그 데이터를 바꾸고 결과를 클라이언트에 통지한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local persistence = require(script.Parent.persistence)
local scenes = require(ReplicatedStorage.shared.config.scenes)
local heroTracking = require(script.Parent.Parent.modules.heroTracking)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

local exports = {}

-- 서버 모듈(몬스터 처치 등)이 경험치를 줄 때 쓴다. 레벨업이 여러 번 겹쳐도 처리하고,
-- 바뀐 값은 클라이언트에 밀어주며 오토세이브 대상으로 표시한다.
function exports.AddExperience(player: Player, amount: number)
	local data = persistence.Get(player)
	if not data or amount <= 0 then
		return
	end

	data.Experience += amount
	local leveledUp = false
	while data.Experience >= data.MaxExperience do
		data.Experience -= data.MaxExperience
		data.Level += 1
		data.MaxExperience = balance.maxExperienceFor(data.Level)
		leveledUp = true
	end

	persistence.MarkDirty(player)
	if leveledUp then
		-- 레벨업은 잃어버리면 가장 아픈 이벤트라 30초 오토세이브를 기다리지 않고 바로 저장.
		task.spawn(persistence.Save, player, false)
	end
	Net.FireClient("StatsUpdated", player, data.Level, data.Experience, data.MaxExperience, leveledUp)
	if leveledUp then
		-- 레벨업하면 체력을 가득 채운다(최대 체력도 늘어남) — 서버가 정하고 클라이언트에 알린다.
		local maxHealth = balance.maxHealthFor(data.Level)
		data.Health = maxHealth
		Net.FireClient("PlayerHealthChanged", player, maxHealth, maxHealth, 0, false)
	end
end

-- 체력 회복(물약·치료사). 실제로 오른 양을 돌려준다(이미 가득이면 0).
function exports.Heal(player: Player, amount: number): number
	local data = persistence.Get(player)
	if not data or amount <= 0 then
		return 0
	end
	local maxHealth = balance.maxHealthFor(data.Level)
	local before = data.Health or maxHealth
	data.Health = math.min(before + amount, maxHealth)
	local healed = data.Health - before
	if healed > 0 then
		persistence.MarkDirty(player)
		Net.FireClient("PlayerHealthChanged", player, data.Health, maxHealth, 0, false)
	end
	return healed
end

-- 플레이어가 피해를 입는다(몬스터 공격 등). 체력의 진실은 서버 세션이다 — 계산 결과만 클라이언트에 알린다.
-- 체력이 0이 되면 사망 처리: 서버가 체력을 가득 채워 리스폰 상태로 만들고, 클라이언트에는 died=true로 알려
-- 클라이언트가 리스폰 연출(이동)을 수행하게 한다(리스폰 위치/씬 결정도 C3에서 서버로 옮길 예정).
function exports.DamagePlayer(player: Player, amount: number)
	local data = persistence.Get(player)
	if not data or amount <= 0 then
		return
	end
	local maxHealth = balance.maxHealthFor(data.Level)
	local newHealth = math.max((data.Health or maxHealth) - amount, 0)
	local died = newHealth <= 0
	data.Health = if died then maxHealth else newHealth
	persistence.MarkDirty(player)
	if died then
		-- 사망 페널티(GAME_DESIGN §7): 지금 레벨 필요 경험치의 5% + 가진 골드의 5%. 레벨은 내려가지 않는다.
		local lostExp = math.min(data.Experience, math.floor(data.MaxExperience * balance.DEATH_EXP_LOSS))
		data.Experience -= lostExp
		local lostGold = math.floor((data.Gold or 0) * balance.DEATH_GOLD_LOSS)
		data.Gold = (data.Gold or 0) - lostGold
		Net.FireClient("StatsUpdated", player, data.Level, data.Experience, data.MaxExperience, false)
		Net.FireClient("GoldUpdated", player, data.Gold)
		Net.FireClient("Notify", player, ("쓰러졌어요… 경험치 %d, 골드 %d를 잃었어요"):format(lostExp, lostGold))
		-- 리스폰 씬을 서버가 정한다: 탑다운 씬이면 시작 씬(회복소가 있는 마을), 예전 사이드뷰 씬이면 예전 마을.
		-- 클라이언트는 died 신호를 받고 그 씬의 시작 위치(⭐)로 옮긴다.
		local current = heroTracking.GetPlayerScene(player.UserId)
		local respawn = if townWorld.KeyOf(current) then townWorld.StartSceneName() else scenes.TOWN
		heroTracking.SetPlayerScene(player.UserId, respawn)
		NetworkingService:ResyncClient(player)
	end
	Net.FireClient("PlayerHealthChanged", player, data.Health, maxHealth, amount, died)
end

return exports
