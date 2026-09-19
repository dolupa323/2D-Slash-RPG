-- 플레이어 저장 데이터의 형태(스키마)와 버전 마이그레이션. 저장 데이터에는 SchemaVersion이 들어가고, 불러올 때마다 저장된
-- 버전에서 CURRENT_VERSION까지 마이그레이션을 순서대로 적용한다 — 필드를 추가/변경할 때 예전 저장 데이터가 깨지지 않게
-- 하는 단 하나의 통로다(예전에는 필드를 추가할 때마다 로드 코드에 `or {}` 같은 임기응변을 끼워 넣었다).
--
-- 새 필드/변경을 넣는 법: CURRENT_VERSION을 1 올리고, migrations[새 버전] = function(data) ... end 를 추가한다.
-- default()는 "가장 최신 버전의 신규 플레이어" 형태여야 한다(SchemaVersion = CURRENT_VERSION).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)

local exports = {}

exports.CURRENT_VERSION = 1

function exports.default()
	return {
		SchemaVersion = exports.CURRENT_VERSION,
		Level = 1,
		Experience = 0,
		MaxExperience = balance.maxExperienceFor(1),
		Health = balance.maxHealthFor(1),
		Gold = 0,
		-- { { Slot = number, ItemId = string, Count = number }, ... } — 빈 칸이 있는 숫자 키 테이블은 DataStore가
		-- 안전하게 저장하지 못해서 슬롯 번호를 값 안에 넣은 촘촘한 배열로 둔다.
		Inventory = {},
		-- { Weapon = ItemId?, Armor = ItemId? } — 착용 중인 장비(비어 있으면 키 없음).
		Equipment = {},
	}
end

-- 각 함수는 "이전 버전 데이터를 그 번호 버전으로 올린다".
local migrations = {
	-- v0(버전 필드가 없던 초기 저장 데이터) → v1: 뼈대 시절 이후 추가된 필드들을 채운다.
	[1] = function(data)
		data.Level = data.Level or 1
		data.Experience = data.Experience or 0
		data.MaxExperience = data.MaxExperience or balance.maxExperienceFor(data.Level)
		data.Gold = data.Gold or 0
		data.Inventory = data.Inventory or {}
		data.Equipment = data.Equipment or {}
	end,
}

-- 저장 데이터를 최신 버전으로 올리고 값 범위를 정리한다. 이미 최신이면 마이그레이션은 건너뛴다.
function exports.migrate(data)
	local version = data.SchemaVersion or 0
	if version > exports.CURRENT_VERSION then
		warn(("playerSchema: 저장 데이터 버전(%d)이 이 서버(%d)보다 새 버전이다 — 그대로 사용하지만 필드 호환이 안 될 수 있다"):format(
			version, exports.CURRENT_VERSION
		))
		return data
	end
	while version < exports.CURRENT_VERSION do
		version += 1
		migrations[version](data)
	end
	data.SchemaVersion = exports.CURRENT_VERSION

	-- 체력은 서버가 소유한다: 저장된 값이 없거나(첫 접속) 0 이하(죽은 채 저장)면 가득 채운 상태로, 최대 체력을 넘으면 잘라낸다.
	local maxHealth = balance.maxHealthFor(data.Level)
	if typeof(data.Health) ~= "number" or data.Health <= 0 then
		data.Health = maxHealth
	end
	data.Health = math.min(data.Health, maxHealth)

	return data
end

return exports
