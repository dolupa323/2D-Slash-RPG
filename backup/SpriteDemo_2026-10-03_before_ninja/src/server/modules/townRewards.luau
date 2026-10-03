-- 탑다운 씬(공방에서 만든 씬) 치료사 회복(RequestHeal): 지금 씬에 치료사 NPC가 있고 서버가 아는 플레이어 발 위치가
-- 그 근처일 때만 체력을 가득 채운다. (몬스터 처치 경험치는 서버 권위 몬스터 townMonsters.luau가 직접 준다.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local persistence = require(script.Parent.Parent.services.persistence)

local HEAL_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)

local exports = {}

local function currentTownScene(player: Player)
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	return key and townWorld.Get(key)
end

function exports.load()
	Net.OnServer("RequestHeal", function(player: Player)
		local d = currentTownScene(player)
		local position = heroTracking.GetPosition(player.UserId)
		local data = persistence.Get(player)
		if not d or not position or not data then
			return
		end
		local feet = position / townWorld.data.scale
		for _, n in d.npcs do
			if n.type == "healer" and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + HEAL_PAD then
				local maxHealth = balance.maxHealthFor(data.Level)
				data.Health = maxHealth
				persistence.MarkDirty(player)
				Net.FireClient("PlayerHealthChanged", player, maxHealth, maxHealth, 0, false)
				return
			end
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports
