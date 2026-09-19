-- 서버(playerData.luau)가 로드해둔 저장 데이터(레벨/경험치)를 내 캐릭터(hero) 오브젝트에
-- 채워 넣는다. Level/Experience/MaxExperience를 hero의 평범한 필드로 설정해두면, 이미
-- 붙여둔 NetworkingService 리플리케이션이 Health/WalkSpeed처럼 자동으로 다른 플레이어에게
-- 복제해준다 — 별도 배선 필요 없음.
--
-- (실측 버그 이력) 게임 시작 직후엔 레벨이 1로 보이다가 포탈을 타면 저장된 레벨로 바뀌었다.
-- globals 모듈이 씬 모듈(hero 생성)보다 먼저 load되는데, 그 시점에 이미
-- CrossPlatformService.Character에 엔진 기본 캐릭터가 들어있어서 "캐릭터가 생겼다"고
-- 착각하고 그 임시 캐릭터에 값을 채웠고, 곧이어 heroController가 진짜 hero를 만들어
-- 교체하면서 값이 날아갔다. 그래서 값을 한 번만 채우지 않고, 서버 값을 캐시해둔 뒤
-- 매 프레임 "현재 Character가 마지막으로 채운 것과 다르면" 다시 채운다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local levelUpEffect = require(script.Parent.Parent.levelUpEffect)
local camera = require(script.Parent.camera)

local exports = {}

local currentStats = nil
local lastAppliedCharacter = nil

-- 로딩 화면(loadingScreen.luau)이 "저장된 레벨이 지금 hero에 적용됐는가"를 확인하는 용도.
function exports.isReady(): boolean
	local character = CrossPlatformService.Character
	return currentStats ~= nil and character ~= nil and character == lastAppliedCharacter
end

local function apply(character, stats, isNewCharacter)
	-- (아래 stats는 항상 { Level, Experience, MaxExperience, Health? } 형태)
	character.Level = stats.Level
	character.Experience = stats.Experience
	character.MaxExperience = stats.MaxExperience
	character.MaxHealth = balance.maxHealthFor(stats.Level)
	if isNewCharacter then
		-- 저장된 체력을 이어받는다(씬을 옮기거나 재접속해도 체력이 회복되면 안 됨 — 나중에
		-- 포션이 회복 수단이 될 예정). 저장된 값이 없거나(첫 접속) 0 이하(죽은 채로 저장)면
		-- 가득 채운다.
		local saved = stats.Health
		if typeof(saved) == "number" and saved > 0 then
			character.Health = math.min(saved, character.MaxHealth)
		else
			character.Health = character.MaxHealth
		end
	end
end

function exports.load(scene: Scene)
	if exports.started then
		return
	end
	exports.started = true

	local stats = nil
	currentStats = nil
	lastAppliedCharacter = nil

	exports.applyConnection = RunService.Heartbeat:Connect(function()
		local character = CrossPlatformService.Character
		if stats and character and character ~= lastAppliedCharacter then
			lastAppliedCharacter = character
			apply(character, stats, true)
		end

	end)

	task.spawn(function()
		local ok, data = pcall(function()
			return Net.Invoke("GetPlayerData")
		end)

		if not ok or typeof(data) ~= "table" then
			warn("playerStats: GetPlayerData 요청 실패, 기본값 유지 - " .. tostring(data))
			return
		end

		stats = { Level = data.Level, Experience = data.Experience, MaxExperience = data.MaxExperience, Health = data.Health }
		currentStats = stats

		-- 서버가 경험치/레벨을 바꿀 때마다(몬스터 처치) 캐시와 내 hero 필드에 반영.
		-- 레벨업하면 체력을 가득 채워준다.
		exports.statsConnection = Net.OnClient(
			"StatsUpdated",
			function(level, experience, maxExperience, leveledUp)
				stats = { Level = level, Experience = experience, MaxExperience = maxExperience }
				currentStats = stats
				local hero = CrossPlatformService.Character
				if not hero then
					return
				end
				apply(hero, stats)
				if leveledUp then
					-- 체력 회복은 서버가 정해서 PlayerHealthChanged로 따로 알려준다 — 여기선 연출만.
					levelUpEffect.Play(hero.Instance)
					camera.Shake(0.25, 4)
				end
			end
		)
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.applyConnection then
		exports.applyConnection:Disconnect()
		exports.applyConnection = nil
	end
	if exports.statsConnection then
		exports.statsConnection:Disconnect()
		exports.statsConnection = nil
	end
	exports.started = nil
end

return exports
