-- 탑다운 씬 이미지 에셋 + 화면 배율.
-- 원본 이미지: SpriteDemo/assets/bunvillage/*.png — 에셋 공방(C:/YJS/Roblox/dino-workshop)의
-- tools/export_roblox.mjs가 만들고, 업로드한 id는 tools/write_asset_ids.mjs가 townAssets.generated.luau에 쓴다.
-- 배율(바닥·오브젝트·몬스터·캐릭터)도 공방 규칙(js/world.js)에서 내보낸 값을 그대로 쓴다 — 여기서 따로 고치지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ids = require(script.Parent["townAssets.generated"])
local world = require(ReplicatedStorage.shared.data["townWorld.generated"])

return {
	SCALE = world.scale, -- 바닥 1도트 = 화면 px
	CHAR_SCALE = world.charScale, -- 캐릭터 1도트 = 화면 px
	MONSTER_SCALE = world.monsterScale, -- 몬스터 1도트 = 화면 px
	OBJECTS = ids.OBJECTS, -- 오브젝트 아틀라스
	MONSTERS = ids.MONSTERS, -- 몬스터 시트 1장째(종마다 대기R4 걷기R4 대기L4 걷기L4)
	MONSTER_SHEETS = ids.MONSTER_SHEETS or { ids.MONSTERS }, -- 몬스터 시트 전부(1024px 한계로 여러 장) — townWorld.MonsterSheet(row)로 고른다
	PLAYER = ids.PLAYER, -- 플레이어(줄: 아래·위·왼·오, 칸: 걷기4 + 공격4)
	NPCS = ids.NPCS, -- NPC 시트(역할마다 한 줄, 대기 2장)
	UI = ids.UI or "", -- UI 키트 아틀라스(shared/data/uiKit.generated.luau)
	FX = ids.FX or "", -- 인술 이펙트 시트(shared/data/ninjaFx.generated.luau) — 업로드 전이면 빈 글자(이펙트를 안 그림)
	GROUNDS = ids.GROUNDS, -- 씬 키 → 바닥 이미지
}
