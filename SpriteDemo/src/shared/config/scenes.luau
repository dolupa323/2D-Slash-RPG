-- 씬 이름의 "단 하나의 출처". 문자열이 여러 파일에 흩어져 있으면 이름을 바꿀 때 어긋나므로 여기서만 정의한다.
-- 씬은 전부 탑다운 씬이고 공방(js/ninja/maps.js → tools/export_ninja.mjs)이 shared/data/townWorld.generated.luau로 내보낸다.
-- 로블록스 씬 이름은 "town_<씬 키>", 씬 모듈은 전부 client/modules/town을 같이 쓴다.
local townWorld = require(script.Parent.Parent.data.townWorld)

return {
	-- 게임 시작 씬이자 쓰러졌을 때 돌아오는 곳(공방에서 정한 시작 씬 — 닌자 마을).
	TOWN = townWorld.StartSceneName(),
}
