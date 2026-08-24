-- 횡스크롤 개편(GandalfHardcore FREE Platformer Assets 사용)으로 이전 탑다운 타일셋 정의를
-- 전부 교체했다. 시트 안 index는 왼쪽부터 몇 번째 칸인지(0부터).
-- 마을 소품(집/나무/동상/텐트/잔디)은 GandalfHardcore FREE Platformer Assets의 초록 계열
-- 원본 PNG를 그대로(또는 여백만 트리밍) 업로드한 단일 이미지라 격자가 아니다 — cellWidth/
-- cellHeight로 원본 픽셀 크기를 지정하고 tiles.sprite=0 하나만 쓴다(가로 스트립 인덱싱 재사용,
-- index=0이라 오프셋은 항상 0,0). displayWidth/Height를 안 주면 tiles.luau가 원본 크기 그대로
-- 그린다 — 96px 바닥 그리드와 같은 팩 소스라 스케일이 서로 맞는다.
local forestTilesetDefs = require(script.Parent.forestTilesetDefs)

local defs = {
	platformer = {
		assetId = "rbxassetid://117577572195700",
		cellSize = 96,
		displaySize = 96,
		tiles = {
			ground = 0,
		},
	},
	house = {
		assetId = "rbxassetid://117188002902354",
		cellWidth = 184,
		cellHeight = 224,
		tiles = { sprite = 0 },
	},
	treePine = {
		assetId = "rbxassetid://108038629877772",
		cellWidth = 255,
		cellHeight = 201,
		tiles = { sprite = 0 },
	},
	treeApple = {
		assetId = "rbxassetid://73449893654515",
		cellWidth = 255,
		cellHeight = 201,
		tiles = { sprite = 0 },
	},
	tallGrass = {
		assetId = "rbxassetid://71895812296115",
		cellWidth = 96,
		cellHeight = 32,
		tiles = { sprite = 0 },
	},
	statue = {
		assetId = "rbxassetid://70502093178468",
		cellWidth = 48,
		cellHeight = 64,
		tiles = { sprite = 0 },
	},
	tent = {
		assetId = "rbxassetid://75978400474079",
		cellWidth = 64,
		cellHeight = 64,
		tiles = { sprite = 0 },
	},
}

for name, def in forestTilesetDefs do
	defs[name] = def
end

return defs
