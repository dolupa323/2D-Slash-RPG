-- "Ancient Forest 1.6" 에셋팩(C:\YJS\Roblox\Assets\Ancient Forest 1.6)에서 요소별로 잘라
-- 업로드한 카탈로그. 사용자가 mapData.luau의 decor 배열에 직접 항목을 추가해서 배치/구성한다.
--
-- v2: 원본 스프라이트시트를 연결-성분(connected-component) 알고리즘으로 자동 경계 인식해서
-- 잘랐다 — 서로 안 붙어있는 요소는 절대 안 섞이도록(v1에서 눈대중으로 잘라서 옆 요소가
-- 섞여 들어가던 문제 해결). 원본 그림에서 실제로 서로 붙어 그려진 것들(예: 종 모양 등불+기둥,
-- 보석+받침대)만 하나로 유지했다 — 이건 잘못 자른 게 아니라 원화 자체가 그렇게 그려져 있다.
--
-- 사용법 (mapData.luau의 decor 배열에 추가):
--   { x = 100, y = 200, tileset = "forestPine1", tile = "sprite", zIndex = 0 },
-- x/y는 스프라이트 "중심" 좌표. zIndex로 앞뒤 순서 조절(숫자가 작을수록 뒤, 바닥 타일은
-- zIndex=1, 캐릭터는 10). canCollide=true를 주면 밟고 설 수 있는 판정이 생긴다(기본 false).
--
-- 카테고리:
--   나무/자연: forestPine1~5, forestTreePineBig, forestTreeAppleBig, forestTreeBushSmall,
--              forestMushroomRed/Red2, forestMushroomClusterSmall/Tiny, forestHangingVine,
--              forestVineCreature
--   지형/바닥: forestPlatformGrass/Grass2/Rock, forestCaveFloor, forestStalagmites,
--              forestSwampReeds, forestBoulderPink, forestCrystalBlue/Orange, forestBridgeRope,
--              forestWoodPlankBridge, forestFence
--   건물/벽/문/창문: forestWallBuilding, forestWallBrick/BrickFlower, forestTowerBuilding,
--                    forestTowerTop, forestFurnaceTower, forestDoorArchA/B, forestDoorDarkA/B,
--                    forestWindowLit/Dark/Square/Decorated, forestChimney
--   소품/장식: forestChestGold, forestBarrelPile/Single, forestCrateWood, forestTableBench,
--              forestSignBoard, forestPotShelf, forestLanternPost, forestCampfire, forestBed,
--              forestWellBridgePost, forestLog
return {
	-- 나무 / 자연
	forestPine1 = { assetId = "rbxassetid://101538799847613", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine2 = { assetId = "rbxassetid://106239771322272", cellWidth = 63, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine3 = { assetId = "rbxassetid://101724186631095", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine4 = { assetId = "rbxassetid://137367447874912", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestPine5 = { assetId = "rbxassetid://120563853983797", cellWidth = 64, cellHeight = 168, tiles = { sprite = 0 } },
	forestTreePineBig = { assetId = "rbxassetid://93778015837039", cellWidth = 255, cellHeight = 201, tiles = { sprite = 0 } },
	forestTreeAppleBig = { assetId = "rbxassetid://73449893654515", cellWidth = 255, cellHeight = 201, tiles = { sprite = 0 } },
	forestTreeBushSmall = { assetId = "rbxassetid://122034095645559", cellWidth = 57, cellHeight = 44, tiles = { sprite = 0 } },
	forestMushroomRed = { assetId = "rbxassetid://138582363342226", cellWidth = 28, cellHeight = 31, tiles = { sprite = 0 } },
	forestMushroomRed2 = { assetId = "rbxassetid://82240024664987", cellWidth = 28, cellHeight = 28, tiles = { sprite = 0 } },
	forestMushroomClusterSmall = { assetId = "rbxassetid://94949820667015", cellWidth = 37, cellHeight = 45, tiles = { sprite = 0 } },
	forestMushroomClusterTiny = { assetId = "rbxassetid://104023463468070", cellWidth = 23, cellHeight = 36, tiles = { sprite = 0 } },
	forestHangingVine = { assetId = "rbxassetid://105474350759453", cellWidth = 60, cellHeight = 45, tiles = { sprite = 0 } },
	forestVineCreature = { assetId = "rbxassetid://82479243795399", cellWidth = 26, cellHeight = 62, tiles = { sprite = 0 } },

	-- 지형 / 바닥
	forestPlatformGrass = { assetId = "rbxassetid://78625364398619", cellWidth = 68, cellHeight = 88, tiles = { sprite = 0 } },
	forestPlatformGrass2 = { assetId = "rbxassetid://99576230966439", cellWidth = 80, cellHeight = 72, tiles = { sprite = 0 } },
	forestPlatformRock = { assetId = "rbxassetid://98407522786962", cellWidth = 79, cellHeight = 70, tiles = { sprite = 0 } },
	forestCaveFloor = { assetId = "rbxassetid://80149307679857", cellWidth = 125, cellHeight = 98, tiles = { sprite = 0 } },
	forestStalagmites = { assetId = "rbxassetid://87399567206693", cellWidth = 58, cellHeight = 51, tiles = { sprite = 0 } },
	forestSwampReeds = { assetId = "rbxassetid://100028684072587", cellWidth = 48, cellHeight = 24, tiles = { sprite = 0 } },
	forestBoulderPink = { assetId = "rbxassetid://122504375583702", cellWidth = 45, cellHeight = 96, tiles = { sprite = 0 } },
	forestCrystalBlue = { assetId = "rbxassetid://73033867474854", cellWidth = 32, cellHeight = 50, tiles = { sprite = 0 } },
	forestCrystalOrange = { assetId = "rbxassetid://81650670854353", cellWidth = 43, cellHeight = 52, tiles = { sprite = 0 } },
	forestBridgeRope = { assetId = "rbxassetid://79986322193359", cellWidth = 90, cellHeight = 85, tiles = { sprite = 0 } },
	forestWoodPlankBridge = { assetId = "rbxassetid://109576405332588", cellWidth = 62, cellHeight = 32, tiles = { sprite = 0 } },
	forestFence = { assetId = "rbxassetid://90852543265001", cellWidth = 106, cellHeight = 26, tiles = { sprite = 0 } },

	-- 건물 / 벽 / 문 / 창문
	forestWallBuilding = { assetId = "rbxassetid://120459922389060", cellWidth = 144, cellHeight = 128, tiles = { sprite = 0 } },
	forestWallBrick = { assetId = "rbxassetid://102570837630858", cellWidth = 52, cellHeight = 47, tiles = { sprite = 0 } },
	forestWallBrickFlower = { assetId = "rbxassetid://109584642228765", cellWidth = 52, cellHeight = 47, tiles = { sprite = 0 } },
	forestTowerBuilding = { assetId = "rbxassetid://73850476341008", cellWidth = 224, cellHeight = 163, tiles = { sprite = 0 } },
	forestTowerTop = { assetId = "rbxassetid://86363970522429", cellWidth = 48, cellHeight = 29, tiles = { sprite = 0 } },
	forestFurnaceTower = { assetId = "rbxassetid://97734679990727", cellWidth = 52, cellHeight = 84, tiles = { sprite = 0 } },
	forestDoorArchA = { assetId = "rbxassetid://97412655821156", cellWidth = 59, cellHeight = 72, tiles = { sprite = 0 } },
	forestDoorArchB = { assetId = "rbxassetid://130509503216602", cellWidth = 59, cellHeight = 72, tiles = { sprite = 0 } },
	forestDoorDarkA = { assetId = "rbxassetid://76319894027644", cellWidth = 59, cellHeight = 72, tiles = { sprite = 0 } },
	forestDoorDarkB = { assetId = "rbxassetid://102954160341915", cellWidth = 59, cellHeight = 72, tiles = { sprite = 0 } },
	forestWindowLit = { assetId = "rbxassetid://138937791458185", cellWidth = 42, cellHeight = 43, tiles = { sprite = 0 } },
	forestWindowDark = { assetId = "rbxassetid://103765175250582", cellWidth = 42, cellHeight = 43, tiles = { sprite = 0 } },
	forestWindowSquare = { assetId = "rbxassetid://110277153482871", cellWidth = 42, cellHeight = 43, tiles = { sprite = 0 } },
	forestWindowDecorated = { assetId = "rbxassetid://99891391709913", cellWidth = 42, cellHeight = 32, tiles = { sprite = 0 } },
	forestChimney = { assetId = "rbxassetid://136477923057514", cellWidth = 40, cellHeight = 49, tiles = { sprite = 0 } },

	-- 소품 / 장식
	forestChestGold = { assetId = "rbxassetid://102739104520045", cellWidth = 32, cellHeight = 25, tiles = { sprite = 0 } },
	forestBarrelPile = { assetId = "rbxassetid://131400384412799", cellWidth = 64, cellHeight = 74, tiles = { sprite = 0 } },
	forestBarrelSingle = { assetId = "rbxassetid://96595118781218", cellWidth = 22, cellHeight = 24, tiles = { sprite = 0 } },
	forestCrateWood = { assetId = "rbxassetid://124142595534470", cellWidth = 32, cellHeight = 35, tiles = { sprite = 0 } },
	forestTableBench = { assetId = "rbxassetid://132800884983635", cellWidth = 74, cellHeight = 48, tiles = { sprite = 0 } },
	forestSignBoard = { assetId = "rbxassetid://120264402979717", cellWidth = 47, cellHeight = 35, tiles = { sprite = 0 } },
	forestPotShelf = { assetId = "rbxassetid://129870706806979", cellWidth = 32, cellHeight = 20, tiles = { sprite = 0 } },
	forestLanternPost = { assetId = "rbxassetid://73475436882845", cellWidth = 54, cellHeight = 64, tiles = { sprite = 0 } },
	forestCampfire = { assetId = "rbxassetid://134241993146095", cellWidth = 31, cellHeight = 20, tiles = { sprite = 0 } },
	forestBed = { assetId = "rbxassetid://105616044795653", cellWidth = 76, cellHeight = 46, tiles = { sprite = 0 } },
	forestWellBridgePost = { assetId = "rbxassetid://92255667301869", cellWidth = 96, cellHeight = 80, tiles = { sprite = 0 } },
	forestLog = { assetId = "rbxassetid://97751195873934", cellWidth = 138, cellHeight = 31, tiles = { sprite = 0 } },

	-- 배경 레이어 (Deep Forest, 416x256 원본)
	forestBg1 = { assetId = "rbxassetid://82463977703179", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg2 = { assetId = "rbxassetid://90350991499279", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg3 = { assetId = "rbxassetid://80936933503236", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg4 = { assetId = "rbxassetid://106016778544915", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
	forestBg5 = { assetId = "rbxassetid://118787477225495", cellWidth = 416, cellHeight = 256, tiles = { sprite = 0 } },
}
