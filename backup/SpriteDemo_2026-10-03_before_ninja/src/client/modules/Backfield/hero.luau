-- 실제 구현은 여러 씬(village, Backfield 등)이 공유하는 modules/heroController.luau에
-- 있다 — 이 파일은 sceneLoader.luau가 "Backfield" 씬 폴더를 스캔할 때 찾을 수 있도록
-- 그 공용 모듈을 그대로 반환하는 얇은 래퍼다.
return require(script.Parent.Parent.heroController)
