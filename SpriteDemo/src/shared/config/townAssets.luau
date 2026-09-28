-- 탑다운 만두 마을("town" 씬) 이미지 에셋.
-- 원본: SpriteDemo/assets/bunvillage/*.png — 에셋 공방(C:/YJS/Roblox/dino-workshop)의
-- tools/export_roblox.mjs가 만든다. 다시 내보내면 이미지가 바뀌므로 다시 업로드하고 여기 id를 갈아끼운다.
-- 맵 좌표/아틀라스 위치는 shared/data/townMap.generated.luau(같이 생성됨)에 있다.
return {
	-- 도트 1칸을 화면 몇 px로 그릴지(모든 town 그림 공통).
	SCALE = 4,
	-- 캐릭터·몬스터만 작게(도트 1칸 = 화면 2px, 맵은 4px). 정수라 도트가 고르게 유지된다.
	CHAR_SCALE = 2,
	GROUND = "rbxassetid://76695281295139", -- 바닥 전체 768x544
	OBJECTS = "rbxassetid://120898895182802", -- 오브젝트 아틀라스 512x101
	MONSTERS = "rbxassetid://111715006576215", -- 몬스터 시트 512x720(종마다 한 줄: 대기R4 걷기R4 대기L4 걷기L4)
	PLAYER = "rbxassetid://111238952859606", -- 도트 아이 48x96(줄: 아래·위·왼·오, 칸: 서기·걸음1·걸음2)
}
