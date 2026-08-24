-- "Ancient Forest 1.6" 에셋팩(C:\YJS\Roblox\Assets\Ancient Forest 1.6)에서 요소별로 잘라
-- 업로드한 카탈로그. 사용자가 mapData.luau의 decor 배열에 직접 항목을 추가해서 배치/구성한다.
--
-- 사용법 (mapData.luau의 decor 배열에 추가):
--   { x = 100, y = 200, tileset = "forestPine1", tile = "sprite", zIndex = 0 },
-- x/y는 스프라이트 "중심" 좌표(tiles.luau/hero.luau와 동일 규칙). zIndex로 앞뒤 순서 조절
-- (숫자가 작을수록 뒤, 바닥 타일은 zIndex=1, 캐릭터는 10). canCollide=true를 주면 밟고 설 수
-- 있는 판정이 생긴다(기본은 false, 순수 장식).
--
-- 원본 시트에서 인접 요소가 서로 붙어있는 경우가 많아 자동 경계 인식 + 수동 보정으로 잘랐다 —
-- 일부(cave_floor, platform_rock 등)는 경계의 다른 요소가 아주 약간 섞여 들어갔을 수 있다.
--
-- 카테고리:
--   나무/자연: forestPine1~5, forestAncientTreeGreen/Autumn, forestMushroomTree,
--              forestMushroomRed/White, forestBushSmall, forestTreeBushSmall, forestHangingVine
--   지형/바닥: forestPlatformGrass, forestPlatformRock, forestCaveFloor, forestStalagmites,
--              forestSwampReeds, forestBoulderPink, forestCrystalBlue/Orange, forestBridgeRope,
--              forestFence
--   건물/벽/문/창문: forestWallBuilding, forestWallBrick, forestTowerBuilding, forestDoorArch,
--                    forestDoorDarkA/B, forestWindowLit/Dark, forestChimney
--   소품/장식: forestChestGold, forestBarrelPile/Single, forestTableBench, forestSignBoard,
--              forestPotShelf
--   배경 레이어: forestBg1~5 (Deep Forest 팔레트, 뒤에서 앞 순서로 대략 1→5 — 필요하면
--                눈으로 직접 확인하고 zIndex로 쌓으면 된다. 화면 전체를 덮는 배경용 이미지라
--                displayWidth/Height를 크게 늘려 써도 된다)
return {
	-- 나무 / 자연
	forestPine1 = { assetId = "rbxassetid://101538799847613", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine2 = { assetId = "rbxassetid://106239771322272", cellWidth = 63, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine3 = { assetId = "rbxassetid://101724186631095", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine4 = { assetId = "rbxassetid://137367447874912", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine5 = { assetId = "rbxassetid://120563853983797", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestAncientTreeGreen = { assetId = "rbxassetid://77408033268905", cellWidth = 412, cellHeight = 272, tiles = { sprite = 0 } },
	forestAncientTreeAutumn = { assetId = "rbxassetid://96937375115985", cellWidth = 408, cellHeight = 272, tiles = { sprite = 0 } },
	forestMushroomTree = { assetId = "rbxassetid://98654261026419", cellWidth = 68, cellHeight = 63, tiles = { sprite = 0 } },
	forestMushroomRed = { assetId = "rbxassetid://105723147451019", cellWidth = 62, cellHeight = 62, tiles = { sprite = 0 } },
	forestMushroomWhite = { assetId = "rbxassetid://138997612097642", cellWidth = 90, cellHeight = 27, tiles = { sprite = 0 } },
	forestBushSmall = { assetId = "rbxassetid://74512507077996", cellWidth = 90, cellHeight = 50, tiles = { sprite = 0 } },
	forestTreeBushSmall = { assetId = "rbxassetid://79281532096446", cellWidth = 110, cellHeight = 68, tiles = { sprite = 0 } },
	forestHangingVine = { assetId = "rbxassetid://112408000288991", cellWidth = 142, cellHeight = 62, tiles = { sprite = 0 } },

	-- 지형 / 바닥
	forestPlatformGrass = { assetId = "rbxassetid://119951842573946", cellWidth = 92, cellHeight = 84, tiles = { sprite = 0 } },
	forestPlatformRock = { assetId = "rbxassetid://106846387780763", cellWidth = 90, cellHeight = 50, tiles = { sprite = 0 } },
	forestCaveFloor = { assetId = "rbxassetid://77733024438211", cellWidth = 137, cellHeight = 65, tiles = { sprite = 0 } },
	forestStalagmites = { assetId = "rbxassetid://71922745581657", cellWidth = 69, cellHeight = 50, tiles = { sprite = 0 } },
	forestSwampReeds = { assetId = "rbxassetid://104236041795372", cellWidth = 26, cellHeight = 24, tiles = { sprite = 0 } },
	forestBoulderPink = { assetId = "rbxassetid://124398516521276", cellWidth = 64, cellHeight = 78, tiles = { sprite = 0 } },
	forestCrystalBlue = { assetId = "rbxassetid://106759591226085", cellWidth = 38, cellHeight = 38, tiles = { sprite = 0 } },
	forestCrystalOrange = { assetId = "rbxassetid://91459787610728", cellWidth = 44, cellHeight = 38, tiles = { sprite = 0 } },
	forestBridgeRope = { assetId = "rbxassetid://88247286726018", cellWidth = 104, cellHeight = 51, tiles = { sprite = 0 } },
	forestFence = { assetId = "rbxassetid://98223551838458", cellWidth = 104, cellHeight = 39, tiles = { sprite = 0 } },

	-- 건물 / 벽 / 문 / 창문
	forestWallBuilding = { assetId = "rbxassetid://120459922389060", cellWidth = 144, cellHeight = 128, tiles = { sprite = 0 } },
	forestWallBrick = { assetId = "rbxassetid://102570837630858", cellWidth = 52, cellHeight = 47, tiles = { sprite = 0 } },
	forestTowerBuilding = { assetId = "rbxassetid://73850476341008", cellWidth = 224, cellHeight = 163, tiles = { sprite = 0 } },
	forestDoorArch = { assetId = "rbxassetid://97412655821156", cellWidth = 59, cellHeight = 72, tiles = { sprite = 0 } },
	forestDoorDarkA = { assetId = "rbxassetid://83924202562051", cellWidth = 63, cellHeight = 120, tiles = { sprite = 0 } },
	forestDoorDarkB = { assetId = "rbxassetid://126102825377809", cellWidth = 63, cellHeight = 120, tiles = { sprite = 0 } },
	forestWindowLit = { assetId = "rbxassetid://138937791458185", cellWidth = 42, cellHeight = 43, tiles = { sprite = 0 } },
	forestWindowDark = { assetId = "rbxassetid://82888283195408", cellWidth = 42, cellHeight = 78, tiles = { sprite = 0 } },
	forestChimney = { assetId = "rbxassetid://136477923057514", cellWidth = 40, cellHeight = 49, tiles = { sprite = 0 } },

	-- 소품 / 장식
	forestChestGold = { assetId = "rbxassetid://88169965143361", cellWidth = 53, cellHeight = 55, tiles = { sprite = 0 } },
	forestBarrelPile = { assetId = "rbxassetid://83944852475981", cellWidth = 68, cellHeight = 67, tiles = { sprite = 0 } },
	forestBarrelSingle = { assetId = "rbxassetid://96595118781218", cellWidth = 22, cellHeight = 24, tiles = { sprite = 0 } },
	forestTableBench = { assetId = "rbxassetid://81871492175821", cellWidth = 67, cellHeight = 48, tiles = { sprite = 0 } },
	forestSignBoard = { assetId = "rbxassetid://120264402979717", cellWidth = 47, cellHeight = 35, tiles = { sprite = 0 } },
	forestPotShelf = { assetId = "rbxassetid://73475436882845", cellWidth = 54, cellHeight = 64, tiles = { sprite = 0 } },

	-- 배경 레이어 (Deep Forest, 416x256 원본)
	forestBg1 = { assetId = "rbxassetid://82463977703179", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg2 = { assetId = "rbxassetid://90350991499279", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg3 = { assetId = "rbxassetid://80936933503236", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg4 = { assetId = "rbxassetid://106016778544915", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg5 = { assetId = "rbxassetid://118787477225495", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
}
