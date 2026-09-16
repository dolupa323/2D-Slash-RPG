-- 서버(playerData.luau)가 로드해둔 저장 데이터(레벨/경험치)를 내 캐릭터(hero) 오브젝트에
-- 채워 넣는다. Level/Experience/MaxExperience를 hero의 평범한 필드로 설정해두면, 이미
-- 붙여둔 NetworkingService 리플리케이션이 Health/WalkSpeed처럼 자동으로 다른 플레이어에게
-- 복제해준다 — 별도 배선 필요 없음.
-- hero.luau가 캐릭터를 만드는 타이밍(씬 로드 시점)과 이 모듈의 로드 타이밍이 어긋날 수
-- 있어서, CrossPlatformService.Character가 생길 때까지 기다렸다가 서버에 요청한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local exports = {}

function exports.load(scene: Scene)
	if exports.started then
		return
	end
	exports.started = true

	task.spawn(function()
		local character = CrossPlatformService.Character
		while not character do
			task.wait()
			character = CrossPlatformService.Character
		end

		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local getPlayerData = remotes:WaitForChild("GetPlayerData")

		local ok, data = pcall(function()
			return getPlayerData:InvokeServer()
		end)

		if not ok or typeof(data) ~= "table" then
			warn("playerStats: GetPlayerData 요청 실패, 기본값 유지 - " .. tostring(data))
			return
		end

		character.Level = data.Level
		character.Experience = data.Experience
		character.MaxExperience = data.MaxExperience
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene) end

return exports
