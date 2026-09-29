-- 씬 이름의 "단 하나의 출처". 문자열이 여러 파일에 흩어져 있으면 이름을 바꿀 때 어긋나므로 여기서만 정의한다.
-- (씬 폴더 이름 client/modules/<이름>과 플러그인 씬 이름은 이 값과 같아야 한다.)
local townWorld = require(script.Parent.Parent.data.townWorld)

local scenes = {
	-- 게임 시작 씬이자 사망 시 돌아오는 곳.
	-- (2026-09-28) 게임 전체를 탑다운으로 전환 — 씬은 에셋 공방 맵 탭에서 만들고(여러 개 가능),
	-- tools/export_roblox.mjs가 shared/data/townWorld.generated.luau로 내보낸다. 로블록스 씬 이름은
	-- "town_<씬 키>"이고 모듈은 전부 client/modules/town을 같이 쓴다. 공방에서 ⭐로 고른 시작 씬이 TOWN이다.
	-- 예전 횡스크롤 씬 "village"/"Backfield"와 그 모듈 폴더는 지우지 않고 남겨둔다(현재 미사용).
	TOWN = townWorld.StartSceneName(),
	OLD_VILLAGE = "village",
	-- 예전 횡스크롤 사냥터(현재 미사용).
	HUNTING_GROUND = "Backfield",
}

return scenes
