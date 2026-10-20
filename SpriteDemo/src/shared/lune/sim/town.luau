-- 마을인가(2026-10-21 사용자: "캐시샵은 마을에서만 갈수있구요 경매장도 마을에서만 갈수있어야하구요").
--  마을 = 쓰러지면 돌아가는 곳(scenes.generated의 homes — 초승달 마을 · 작은 마을 · 은달 항구 …)과 그 마을 안의 건물(indoor · 쉼터 · 배가 아니고 돌아갈 곳이 그 마을인 방).
--   사냥터 곁의 쉼터 · 몬스터가 있는 지하(쉼터가 아니다) · 배 · 꿈은 마을이 아니다 — 제가 정한 것. 서버(world.luau)와 화면(boot · cashShop)이 같이 쓴다.
local SCENES = require(script.Parent.Parent.data["scenes.generated"])

local Town = {}

function Town.is(key: string?): boolean
	if typeof(key) ~= "string" then
		return false
	end
	if SCENES.homes[key] then
		return true
	end
	local sc = SCENES.scenes[key]
	return sc ~= nil and sc.indoor == true and sc.rest == true and sc.ship ~= true and typeof(sc.ret) == "string" and SCENES.homes[sc.ret] == true
end

return Town
