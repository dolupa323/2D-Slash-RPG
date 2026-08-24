-- 횡스크롤 MVP: 캐릭터가 설 수 있는 평평한 바닥 하나만 깐다.
-- ground 타일은 canCollide=false다 — 엔진 물리(PhysicalObject) 충돌로 처리하지 않는다.
-- 이유(엔진 소스에 직접 진단 코드를 심어서 실측 확인): 이 엔진의 서브스텝 충돌 클램프
-- 알고리즘(Physics.luau)이 CanCollide 여부와 무관하게, 캐릭터가 바닥에 접촉해 쉬고 있다는
-- 사실 자체를 매 프레임 "충돌 중"으로 감지해서 속도를 방향과 무관하게 거의 0으로 뭉갠다
-- (직접 값을 찍어서 확인: velocity가 (0.004, 0.06)처럼 클램프됨). 그래서 접촉 유지가
-- 필요한 "바닥" 용도로는 이 충돌 시스템을 쓸 수 없다 — 좌우 이동이 100% 막힌다(점프처럼
-- 접촉이 바로 풀리는 움직임만 정상 작동). hero.luau에서 바닥 고정을 직접 구현한다.
-- x/y는 GameFrame 기준 픽셀 오프셋. 96px 격자, y=240 한 줄.
return {
	ground = {
		{ x = -576, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = -480, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = -384, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = -288, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = -192, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = -96, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = 0, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = 96, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = 192, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = 288, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = 384, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = 480, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
		{ x = 576, y = 240, tileset = "platformer", tile = "ground", canCollide = false },
	},
	-- 시작 마을 꾸미기. GandalfHardcore FREE Platformer Assets의 초록 계열(집/나무/동상/텐트/
	-- 잔디)을 그대로 업로드해서 썼다. x/y는 스프라이트 "중심" 좌표(엔진/hero.luau와 동일 규칙).
	-- 바닥 위에 얹는 소품은 y = GROUND_TOP_Y(191) - 세로크기/2로 계산해서 발이 바닥에 닿게
	-- 맞췄다. 나무는 zIndex=0(바닥보다 뒤)으로 둬서 "바닥 뒤에서 자란" 배경 느낌을 낸다.
	decor = {
		{ x = -560, y = 90, tileset = "treePine", tile = "sprite", zIndex = 0 },
		{ x = 560, y = 90, tileset = "treeApple", tile = "sprite", zIndex = 0 },
		{ x = -200, y = 79, tileset = "house", tile = "sprite", zIndex = 2 },
		{ x = 20, y = 159, tileset = "statue", tile = "sprite", zIndex = 5 },
		{ x = 260, y = 159, tileset = "tent", tile = "sprite", zIndex = 5 },
		{ x = -460, y = 175, tileset = "tallGrass", tile = "sprite", zIndex = 6 },
		{ x = -330, y = 175, tileset = "tallGrass", tile = "sprite", zIndex = 6 },
		{ x = -100, y = 175, tileset = "tallGrass", tile = "sprite", zIndex = 6 },
		{ x = 130, y = 175, tileset = "tallGrass", tile = "sprite", zIndex = 6 },
		{ x = 400, y = 175, tileset = "tallGrass", tile = "sprite", zIndex = 6 },
		{ x = 490, y = 175, tileset = "tallGrass", tile = "sprite", zIndex = 6 },

		-- 여기서부터 "Ancient Forest 1.6" 카탈로그(forestTilesetDefs.luau, 43종 —
		-- 나무/지형/건물·벽·문·창문/소품/배경 5개 카테고리) 배치용 공간. 원하는 요소를
		-- 아래처럼 이 배열에 추가하면 된다 — tileset 이름은 forestTilesetDefs.luau 맨
		-- 위 카테고리 목록 참고. x/y는 스프라이트 "중심" 좌표, canCollide 생략 시 순수
		-- 장식(밟을 수 없음). 예시(주석 해제해서 바로 테스트 가능):
		-- { x = -700, y = 100, tileset = "forestPine1", tile = "sprite", zIndex = 0 },
		-- { x = 700, y = 79, tileset = "forestWallBuilding", tile = "sprite", zIndex = 2 },
	},
}
