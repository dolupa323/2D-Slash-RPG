-- 몬스터 생성기(서버 모듈 진입점). shared/data/monsters.luau에 정의된 모든 몬스터 종류마다 공용 AI 서비스(monsterAI)를 하나씩
-- 만들어 돌린다. 새 몬스터는 정의(스탯/시트/판정 범위)를 추가하고 lootTables에 같은 키의 드롭 표만 넣으면 이 코드는 고칠 필요가 없다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local monsters = require(ReplicatedStorage.shared.data.monsters)
local monsterAI = require(script.Parent.Parent.services.monsterAI)

local exports = {}
local instances = {}

function exports.load()
	for typeName, def in monsters do
		-- monsters 표에는 몬스터 정의(Sheets를 가진 표) 외에 공용 상수/함수도 들어 있어 정의만 골라낸다.
		if type(def) == "table" and def.Sheets then
			local instance = monsterAI.new(typeName, def)
			table.insert(instances, instance)
			instance.load()
		end
	end
end

function exports.start()
	for _, instance in instances do
		instance.start()
	end
end

function exports.unload()
	for _, instance in instances do
		instance.unload()
	end
	table.clear(instances)
end

return exports
