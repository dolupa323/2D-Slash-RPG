-- 씬 이름의 "단 하나의 출처". 문자열이 여러 파일에 흩어져 있으면 이름을 바꿀 때 어긋나므로 여기서만 정의한다.
-- (씬 폴더 이름 client/modules/<이름>과 플러그인 씬 이름은 이 값과 같아야 한다.)
local scenes = {
	-- 게임 시작 씬이자 사망 시 돌아오는 마을.
	-- (2026-09-28) 게임 전체를 탑다운으로 전환 — 플러그인으로 만든 횡스크롤 마을("village")
	-- 대신, 에셋 공방에서 내보낸 탑다운 만두 마을을 코드로 만든다(client/sceneLoader.luau, modules/town).
	-- 예전 씬 "village"/"Backfield"와 그 모듈 폴더는 지우지 않고 남겨둔다(현재 미사용).
	TOWN = "town",
	OLD_VILLAGE = "village",
	-- 몬스터가 있는 사냥터.
	HUNTING_GROUND = "Backfield",
}

return scenes
