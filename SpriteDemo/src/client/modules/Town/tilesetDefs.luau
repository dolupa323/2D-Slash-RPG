-- Tile Palette 플러그인을 거치지 않고 코드에서 직접 타일을 그리기 위한 타일셋 정의.
-- 각 시트는 한 번 업로드해둔 스프라이트시트 rbxassetid이고, tiles 테이블의 index는
-- 그 시트 안에서 왼쪽부터 몇 번째 칸인지(0부터 시작)를 뜻한다. 실제 표시는
-- Instance.ImageRectOffset = Vector2.new(index * cellSize, 0)로 잘라서 쓴다.
return {
	ninja = {
		assetId = "rbxassetid://129250509070949",
		cellSize = 16,
		displaySize = 64,
		tiles = {
			grass = 0,
			path = 1,
			dark_grass = 2,
			pink_ground = 3,
			snow_ground = 4,
			rock = 5,
			rock_white = 6,
			boulder = 7,
			flower_sunflower = 8,
			flower_rose = 9,
			bush = 10,
			bush_spiky = 11,
			gem_orange = 12,
			gem_blue = 13,
			gem_purple = 14,
			gem_green = 15,
			twig = 16,
		},
	},
	villageProps = {
		assetId = "rbxassetid://134959819808100",
		cellSize = 68,
		displaySize = 96,
		tiles = {
			torii = 0,
			well = 1,
			fence = 2,
		},
	},
	villageGen = {
		assetId = "rbxassetid://94540380141996",
		cellSize = 112,
		displaySize = 128,
		tiles = {
			tree = 0,
			stump = 1,
			kiln = 2,
			workbench = 3,
			fence = 4,
		},
	},
	groundDetail = {
		assetId = "rbxassetid://118115108764221",
		cellSize = 16,
		displaySize = 48,
		tiles = {
			path = 0,
			crack1 = 1,
			crack2 = 2,
			sprout = 3,
		},
	},
}
