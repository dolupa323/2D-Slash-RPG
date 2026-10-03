-- 포탈로 씬을 넘어갈 때 "어디서 왔는지"를 다음 씬의 스폰 계산(heroController.luau)까지
-- 들고 가기 위한 아주 작은 공유 상태 — 이 모듈은 sceneLoader.luau가 자동 스캔하는
-- modules/globals나 modules/<씬 이름> 폴더 밖(modules/ 루트)에 있어서 자동으로
-- load/start/unload가 호출되지 않는다. portalController.luau와 heroController.luau가
-- require해서 같은 테이블을 공유한다(Luau의 require 캐싱 덕분에 항상 같은 인스턴스).
--
-- portalController.luau가 씬을 넘어가기 직전에 fromScene을 현재 씬 이름으로 채우고,
-- heroController.luau가 새 씬을 로드하면서 그 값을 읽어 "돌아가는 포탈" 위치를 스폰
-- 지점으로 쓴 뒤 nil로 지운다(소비) — 그래야 그다음 번 씬 로드(예: 다시 죽었다 살아나는
-- 경우처럼 포탈을 안 타고 들어가는 경우)에 이전 값이 잘못 남아있지 않는다.
local travelState = {
	fromScene = nil :: string?,
}

return travelState
